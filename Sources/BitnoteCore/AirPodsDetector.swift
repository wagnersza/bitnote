import Foundation

public func isAirPods(_ deviceName: String) -> Bool {
    deviceName.localizedCaseInsensitiveContains("AirPods")
}
