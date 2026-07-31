import SwiftUI
import UserNotifications
import BitnoteCore

@main
struct BitNoteApp: App {
    @StateObject private var audioEngine = AudioEngineManager()
    @StateObject private var recordings = RecordingsManager()
    @StateObject private var permissions = PermissionsManager()
    @StateObject private var meetingWatcher = MeetingWatcher()
    @StateObject private var inputDevices = InputDeviceManager()

    private let notifDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notifDelegate
        MeetingWatcher.registerNotificationCategory()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(audioEngine)
                .environmentObject(recordings)
                .environmentObject(permissions)
                .environmentObject(meetingWatcher)
                .environmentObject(inputDevices)
                .onAppear {
                    meetingWatcher.start(audioEngine: audioEngine, recordings: recordings)
                    meetingWatcher.refreshToday()
                    notifDelegate.watcher = meetingWatcher
                }
                .onChange(of: audioEngine.isRecording) { isRecording in
                    if !isRecording {
                        meetingWatcher.recordingDidStop()
                    }
                }
        } label: {
            let label = menuBarLabel(isRecording: audioEngine.isRecording, elapsed: audioEngine.elapsedTimeString)
            if let text = label.text {
                Label(text, systemImage: label.symbol)
                    .foregroundColor(.red)
            } else {
                Image(systemName: label.symbol)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Notification delegate handles Cancel and Keep recording actions

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// The Keep-recording action must land inside the 60-second grace period, so it calls the watcher
    /// directly rather than leaving a flag for the next Poll to read.
    weak var watcher: MeetingWatcher?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "KEEP_RECORDING" {
            let watcher = self.watcher
            Task { @MainActor in
                watcher?.keepRecording()
                completionHandler()
            }
            return
        }
        if response.actionIdentifier == "CANCEL_AUTORECORD" {
            let notifID = response.notification.request.identifier
            if notifID.hasPrefix("meeting-") {
                let meetingID = String(notifID.dropFirst("meeting-".count))
                UserDefaults.standard.set(true, forKey: "bitnote.cancelledMeeting.\(meetingID)")
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
