import Foundation

/// The active power management mode that determines how MacSwit controls the plug.
enum PowerManagementMode: String, CaseIterable, Identifiable {
    case threshold = "threshold"
    case event = "event"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .threshold: return "Threshold"
        case .event: return "Event-Based"
        }
    }

    var modeDescription: String {
        switch self {
        case .threshold: return "Automatically controls the plug based on battery percentage."
        case .event: return "Controls plug on startup and shutdown only. No battery monitoring."
        }
    }

    /// Whether this mode performs periodic battery monitoring.
    var usesBatteryMonitoring: Bool { self == .threshold }
}
