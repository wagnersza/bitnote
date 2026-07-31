import EventKit
import Foundation
import BitnoteCore
import MeetingDetector
import UserNotifications

/// What the menu row renders while a Keep-recording prompt is active. Both strings come from the
/// pure limit helpers, so the row, the notification, and the accessibility label never drift apart.
struct RecordingLimitPrompt: Equatable {
    let reason: String
    let countdown: String
}

@MainActor
final class MeetingWatcher: ObservableObject {
    @Published var autoRecordingTitle: String? = nil
    @Published var autoRecordingMeetingID: String? = nil
    @Published var limitPrompt: RecordingLimitPrompt? = nil
    @Published var availableCalendars: [EKCalendar] = []
    @Published var hasCalendarAccess: Bool = false
    @Published var todayState: TodaySectionState = .noCalendarAccess
    @Published var selectedCalendarIDs: Set<String> {
        didSet {
            let arr = Array(selectedCalendarIDs)
            UserDefaults.standard.set(arr, forKey: Self.calendarIDsKey)
        }
    }

    private static let calendarIDsKey = "bitnote.selectedCalendarIDs"

    private let store = EKEventStore()
    private var pollTask: Task<Void, Never>?
    private var notifiedIDs: Set<String> = []

    /// The Recording Limit lives here because this type already holds the `audioEngine` and
    /// `recordings` references the tick needs. All its timing decisions come from `BitnoteCore`.
    private var limitState: RecordingLimitState?
    private var limitTask: Task<Void, Never>?
    private static let limitNotificationID = "recording-limit"

    private weak var audioEngine: AudioEngineManager?
    private weak var recordings: RecordingsManager?

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.calendarIDsKey) ?? []
        selectedCalendarIDs = Set(saved)
    }

    func start(audioEngine: AudioEngineManager, recordings: RecordingsManager) {
        self.audioEngine = audioEngine
        self.recordings = recordings
        requestAccessAndPoll()
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Private

    private func requestAccessAndPoll() {
        Task {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = (try? await store.requestFullAccessToEvents()) ?? false
            } else {
                granted = await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
                }
            }
            hasCalendarAccess = granted
            guard granted else {
                todayState = .noCalendarAccess
                return
            }
            refreshCalendars()
            schedulePollLoop()
        }
    }

    private func refreshCalendars() {
        availableCalendars = store.calendars(for: .event)
    }

    private func schedulePollLoop() {
        pollTask = Task {
            while !Task.isCancelled {
                poll()
                refreshToday()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60s
            }
        }
    }

    /// Shared candidate-building path: EventKit query, accepted-attendee mapping, and
    /// `candidateText` assembly, so the 5-minute Poll and the rest-of-day listing agree.
    private func candidateEvents(now: Date, end: Date) -> [CandidateEvent] {
        let availableIDs = Set(availableCalendars.map { $0.calendarIdentifier })
        let filterResult = calendarFilter(selectedIDs: selectedCalendarIDs, availableIDs: availableIDs)
        let calendarsToQuery: [EKCalendar]? = filterResult.map { ids in
            availableCalendars.filter { ids.contains($0.calendarIdentifier) }
        }

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendarsToQuery)
        let ekEvents = store.events(matching: predicate)

        return ekEvents.map { ek -> CandidateEvent in
            let accepted = ek.attendees?.contains {
                $0.isCurrentUser && $0.participantStatus == .accepted
            } ?? true

            let text = candidateText(
                title: ek.title ?? "Meeting",
                location: ek.location,
                notes: ek.notes,
                urlString: ek.url?.absoluteString
            )

            return CandidateEvent(
                id: ek.eventIdentifier ?? UUID().uuidString,
                title: ek.title ?? "Meeting",
                start: ek.startDate,
                accepted: accepted,
                text: text
            )
        }
    }

    private func poll() {
        let now = Date()
        let window: TimeInterval = 300
        let end = now.addingTimeInterval(window)

        let candidates = candidateEvents(now: now, end: end)
        let meetings = MeetingDetector.recordableMeetings(from: candidates, now: now, window: window)

        for meeting in meetings {
            guard shouldNotify(id: meeting.id, notifiedIDs: notifiedIDs) else { continue }
            notifiedIDs.insert(meeting.id)
            scheduleCountdownNotification(for: meeting)
        }
    }

    func refreshToday() {
        guard hasCalendarAccess else {
            todayState = .noCalendarAccess
            return
        }
        let now = Date()
        let calendar = Calendar.current
        let window = remainingDayWindow(now: now, calendar: calendar)
        let end = now.addingTimeInterval(window)

        let candidates = candidateEvents(now: now, end: end)
        let meetings = MeetingDetector.recordableMeetings(from: candidates, now: now, window: window)

        todayState = todaySectionState(
            meetings: meetings,
            calendar: calendar,
            autoRecordingMeetingID: autoRecordingMeetingID,
            hasCalendarAccess: hasCalendarAccess
        )
    }

    private func scheduleCountdownNotification(for meeting: Meeting) {
        let content = UNMutableNotificationContent()
        content.title = "Meeting starting soon"
        content.body = "\(meeting.title) – Bitnote will auto-record. Tap Cancel to skip."
        content.sound = .default
        content.categoryIdentifier = "MEETING_AUTORECORD"

        let delay = countdownFireDelay(start: meeting.start, now: Date())
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "meeting-\(meeting.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)

        let recordDelay = recordStartDelay(start: meeting.start, now: Date())
        Task {
            try? await Task.sleep(nanoseconds: UInt64(recordDelay * 1_000_000_000))
            await startAutoRecording(for: meeting)
        }
    }

    private func startAutoRecording(for meeting: Meeting) async {
        guard let engine = audioEngine, let recs = recordings else { return }
        guard !engine.isRecording else { return }

        let cancelKey = "bitnote.cancelledMeeting.\(meeting.id)"
        if UserDefaults.standard.bool(forKey: cancelKey) {
            UserDefaults.standard.removeObject(forKey: cancelKey)
            return
        }

        let url = recs.newRecordingURL(title: meeting.title)
        do {
            try await engine.startRecording(to: url)
            recordingDidStart()
            autoRecordingTitle = meeting.title
            autoRecordingMeetingID = meeting.id
            refreshToday()
        } catch {
            autoRecordingTitle = nil
            autoRecordingMeetingID = nil
        }
    }

    func recordingDidStop() {
        endLimit()
        if autoRecordingTitle != nil {
            autoRecordingTitle = nil
            autoRecordingMeetingID = nil
            refreshToday()
        }
    }

    // MARK: - Recording Limit

    /// Arms the Recording Limit. Called for every recording, whether the user started it or Auto-start
    /// did, so there is one rule. `meetingEnd` is always nil here; #7 supplies the meeting anchor.
    func recordingDidStart() {
        limitState = recordingLimitStart(meetingEnd: nil, now: Date())
        limitPrompt = nil
        startLimitLoop()
    }

    /// The user clicked **Keep recording**, in the menu row or on the notification banner.
    /// A click that arrives with no active prompt is a no-op: `recordingLimitKeep` returns the same state.
    func keepRecording() {
        guard let state = limitState else { return }
        limitState = recordingLimitKeep(state, now: Date())
        limitPrompt = nil
        removeLimitNotification()
    }

    /// The calendar Poll's 60-second period is too coarse for a countdown that must update each
    /// second, so the limit gets its own loop, and it exists only while a recording runs.
    private func startLimitLoop() {
        limitTask?.cancel()
        limitTask = Task {
            while !Task.isCancelled {
                await tickLimit()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func tickLimit() async {
        guard let state = limitState else { return }
        let now = Date()
        let (next, action) = recordingLimitTick(state, now: now)
        limitState = next

        switch action {
        case .none:
            break
        case .showPrompt:
            postLimitNotification(reason: recordingLimitPromptReason(next))
        case .stopRecording:
            await stopAndSaveRecording()
            return
        }

        limitPrompt = recordingLimitCountdown(next, now: now).map {
            RecordingLimitPrompt(reason: recordingLimitPromptReason(next).text, countdown: $0)
        }
    }

    private func endLimit() {
        limitTask?.cancel()
        limitTask = nil
        limitState = nil
        limitPrompt = nil
        removeLimitNotification()
    }

    private func postLimitNotification(reason: RecordingLimitReason) {
        let content = UNMutableNotificationContent()
        content.title = "Keep recording?"
        content.body = "\(reason.text) Bitnote stops and saves this recording in 1 minute."
        content.sound = .default
        content.categoryIdentifier = "RECORDING_LIMIT"

        let request = UNNotificationRequest(
            identifier: Self.limitNotificationID,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Clears the banner when the round ends, by keep or by stop, so a stale banner cannot be actioned.
    private func removeLimitNotification() {
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [Self.limitNotificationID])
    }

    /// Stops the active recording and adds the saved file to the recordings list.
    /// Owned here (rather than by the view) because `MeetingWatcher` already holds the
    /// `audioEngine`/`recordings` references and is where the Recording Limit tick (#36) will
    /// call this same sequence on a non-UI stop path.
    func stopAndSaveRecording() async {
        guard let engine = audioEngine, engine.isRecording else { return }
        await engine.stopRecording()
        // Disarmed here, on the one stop path both a Manual stop and a limit stop go through, so no
        // recording can leave its limit loop or its prompt row behind.
        endLimit()
        if let url = engine.outputURL {
            recordings?.addRecording(at: url)
        }
    }
}

// MARK: - Notification category setup

extension MeetingWatcher {
    static func registerNotificationCategory() {
        let cancel = UNNotificationAction(
            identifier: "CANCEL_AUTORECORD",
            title: "Cancel Auto-Record",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "MEETING_AUTORECORD",
            actions: [cancel],
            intentIdentifiers: [],
            options: []
        )

        let keep = UNNotificationAction(
            identifier: "KEEP_RECORDING",
            title: "Keep recording",
            options: []
        )
        let limitCategory = UNNotificationCategory(
            identifier: "RECORDING_LIMIT",
            actions: [keep],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category, limitCategory])
    }
}
