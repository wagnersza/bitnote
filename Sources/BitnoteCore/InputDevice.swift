import Foundation

public struct InputDevice: Identifiable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public var id: String { uid }

    public init(uid: String, name: String) {
        self.uid = uid
        self.name = name
    }

    public static let systemDefault = InputDevice(uid: "__system_default__", name: "System Default")
}

/// Pure: given a preferred UID and available devices, return the device to record from.
/// nil or sentinel UID → systemDefault; known UID → that device; unknown UID → systemDefault.
public func resolveInputDevice(preferredUID: String?, available: [InputDevice]) -> InputDevice {
    guard let uid = preferredUID, uid != InputDevice.systemDefault.uid, !uid.isEmpty else {
        return .systemDefault
    }
    return available.first { $0.uid == uid } ?? .systemDefault
}
