import AVFoundation
import CoreGraphics
import ScreenCaptureKit
import AppKit
import BitnoteCore

@MainActor
final class PermissionsManager: ObservableObject {
    @Published var hasMicPermission: Bool = false
    @Published var hasScreenCapturePermission: Bool = true  // optimistic; real check on record attempt
    @Published var airPodsDevice: AVCaptureDevice? = nil

    init() {
        checkPermissions()
    }

    func checkPermissions() {
        hasMicPermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        detectAirPods()
    }

    func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                self?.hasMicPermission = granted
            }
        }
    }

    func requestScreenCapturePermission() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func detectAirPods() {
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
        airPodsDevice = session.devices.first { device in
            isAirPods(device.localizedName)
        }
    }

    var allPermissionsGranted: Bool {
        hasMicPermission
    }
}
