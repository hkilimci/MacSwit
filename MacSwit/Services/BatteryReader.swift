import Foundation
import IOKit.ps

/// Reads the Mac's current battery percentage.
///
/// Primarily reads via IOKit (`IOPSCopyPowerSourcesInfo`); falls back
/// to `pmset -g batt` if that fails.
struct BatteryReader {
    enum BatteryError: LocalizedError {
        case notAvailable

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Battery information is not available."
            }
        }
    }

    func readPercentage() throws -> Int {
        if let value = try readViaIOKit() {
            return value
        }
        if let fallback = try readViaPmset() {
            return fallback
        }
        throw BatteryError.notAvailable
    }

    private func readViaIOKit() throws -> Int? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey as String] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
                  maxCapacity > 0 else {
                continue
            }
            let percent = Int((Double(current) / Double(maxCapacity)) * 100)
            return min(100, Swift.max(0, percent))
        }
        return nil
    }

    private func readViaPmset() throws -> Int? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pmset", "-g", "batt"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        let pattern = #"(\d+)%\s*;?"#
        if let match = output.range(of: pattern, options: .regularExpression) {
            let valueString = String(output[match])
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: ";", with: "")
                .trimmingCharacters(in: .whitespaces)
            return Int(valueString)
        }
        return nil
    }
}
