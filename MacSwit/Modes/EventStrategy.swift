import Foundation

/// Event mode does not react to battery level.
/// The plug is controlled exclusively via system events (launch and shutdown).
@MainActor
final class EventStrategy: PowerManagementStrategy {
    func evaluate(batteryPercent: Int) -> Bool? { nil }
}
