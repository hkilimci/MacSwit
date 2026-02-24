import Foundation
import IOKit

/// Turns the plug ON when battery drops to/below `onThreshold`,
/// and OFF when it reaches/exceeds `offThreshold`.
///
/// When `idleMinutes` is set, the OFF action is gated behind an idle check —
/// the system must have been idle for at least that many minutes.
@MainActor
final class ThresholdStrategy: PowerManagementStrategy {
    let onThreshold: Int
    let offThreshold: Int
    let idleMinutes: Int?

    init(onThreshold: Int, offThreshold: Int, idleMinutes: Int? = nil) {
        self.onThreshold = onThreshold
        self.offThreshold = offThreshold
        self.idleMinutes = idleMinutes
    }

    func evaluate(batteryPercent: Int) -> Bool? {
        if batteryPercent <= onThreshold { return true }
        if batteryPercent >= offThreshold {
            if let minutes = idleMinutes {
                return systemIdleSeconds() >= TimeInterval(minutes * 60) ? false : nil
            }
            return false
        }
        return nil
    }

    /// Returns seconds since the last keyboard or mouse input via IOHIDSystem.
    private func systemIdleSeconds() -> TimeInterval {
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOHIDSystem"),
                                           &iter) == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iter) }

        let entry = IOIteratorNext(iter)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties,
                                                kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any],
              let idleNanos = dict["HIDIdleTime"] as? UInt64 else { return 0 }

        return TimeInterval(idleNanos) / 1_000_000_000
    }
}
