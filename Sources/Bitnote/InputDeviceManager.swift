import AVFoundation
import BitnoteCore

@MainActor
final class InputDeviceManager: ObservableObject {
    @Published var availableDevices: [InputDevice] = []
    @Published var selectedUID: String? {
        didSet { UserDefaults.standard.set(selectedUID, forKey: "bitnote.preferredInputUID") }
    }
    @Published var fallbackNote: String? = nil

    private static let defaultsKey = "bitnote.preferredInputUID"

    init() {
        selectedUID = UserDefaults.standard.string(forKey: Self.defaultsKey)
        refreshDevices()
    }

    func refreshDevices() {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.microphone]
        } else {
            deviceTypes = [.builtInMicrophone]
        }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )
        availableDevices = session.devices.map { InputDevice(uid: $0.uniqueID, name: $0.localizedName) }
    }

    /// Resolve the device to record from. Sets fallbackNote if pinned device is offline.
    func resolveForRecording() -> InputDevice {
        let resolved = resolveInputDevice(preferredUID: selectedUID, available: availableDevices)
        if let uid = selectedUID, uid != InputDevice.systemDefault.uid, !uid.isEmpty {
            if resolved == .systemDefault {
                let pinnedName = availableDevices.first { $0.uid == uid }?.name ?? "pinned device"
                fallbackNote = "\(pinnedName) unavailable — using System Default"
            } else {
                fallbackNote = nil
            }
        } else {
            fallbackNote = nil
        }
        return resolved
    }
}
