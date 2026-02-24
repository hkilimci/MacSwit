import Foundation

/// A strategy that evaluates the current battery level and returns the desired plug state.
///
/// Returns `true` for plug ON, `false` for plug OFF, or `nil` for no action needed.
@MainActor
protocol PowerManagementStrategy {
    func evaluate(batteryPercent: Int) -> Bool?
}
