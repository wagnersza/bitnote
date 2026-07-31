import Foundation

// MARK: - Constants

/// Rounds 1 and 2 of a recording with no Meeting Event.
public let recordingLimitLongRoundInterval: TimeInterval = 30 * 60

/// Round 3 and every later round of a recording with no Meeting Event.
public let recordingLimitShortRoundInterval: TimeInterval = 15 * 60

/// Number of leading rounds that use `recordingLimitLongRoundInterval`.
public let recordingLimitLongRoundCount = 2

/// Time the user has to answer a Keep-recording prompt, measured from the moment the prompt appeared.
public let recordingLimitGracePeriod: TimeInterval = 60

// MARK: - State

public struct RecordingLimitState: Equatable, Sendable {
    var meetingEnd: Date?      // nil = the recording has no Meeting Event (always nil in this ticket)
    var deadline: Date         // when the next prompt fires
    var promptedAt: Date?      // when the current prompt appeared; nil = no prompt active
    var roundsDone: Int        // completed rounds; picks 30 vs 15 minutes
}

public enum RecordingLimitAction: Equatable, Sendable {
    case none
    case showPrompt        // post the notification + show the menu row
    case stopRecording     // the grace period expired
}

public enum RecordingLimitReason: Equatable, Sendable {
    case meetingEnded
    case longRecording

    /// One source for the prompt wording, so the menu row and the notification never drift apart.
    public var text: String {
        switch self {
        case .meetingEnded: return "The meeting ended."
        case .longRecording: return "The recording is long."
        }
    }
}

// MARK: - Entry points

/// Length of the round that follows `roundsDone` completed rounds.
public func recordingLimitInterval(roundsDone: Int) -> TimeInterval {
    roundsDone < recordingLimitLongRoundCount
        ? recordingLimitLongRoundInterval
        : recordingLimitShortRoundInterval
}

/// The first state, built when a recording starts. `meetingEnd` is carried but unused here (#7 anchors it).
public func recordingLimitStart(meetingEnd: Date?, now: Date) -> RecordingLimitState {
    RecordingLimitState(
        meetingEnd: meetingEnd,
        deadline: now.addingTimeInterval(recordingLimitInterval(roundsDone: 0)),
        promptedAt: nil,
        roundsDone: 0
    )
}

/// Run once a second while a recording is active. Compares absolute dates only, so a computer that
/// slept behaves the same as one that ran. A state with no prompt can only ever reach `.showPrompt`,
/// never `.stopRecording`, however large the time jump — the grace period starts at the prompt.
public func recordingLimitTick(
    _ state: RecordingLimitState,
    now: Date
) -> (RecordingLimitState, RecordingLimitAction) {
    if let promptedAt = state.promptedAt {
        let waited = now.timeIntervalSince(promptedAt)
        return (state, waited >= recordingLimitGracePeriod ? .stopRecording : .none)
    }
    guard now >= state.deadline else { return (state, .none) }

    var next = state
    next.promptedAt = now
    return (next, .showPrompt)
}

/// The user clicked **Keep recording**: clear the prompt, count the round, set the next deadline.
/// With no prompt active this changes nothing, which makes a stale notification action harmless.
public func recordingLimitKeep(_ state: RecordingLimitState, now: Date) -> RecordingLimitState {
    guard state.promptedAt != nil else { return state }

    var next = state
    next.promptedAt = nil
    next.roundsDone += 1
    next.deadline = now.addingTimeInterval(recordingLimitInterval(roundsDone: next.roundsDone))
    return next
}

// MARK: - View helpers

/// Time left to answer, as `"0:47"`. nil when no prompt is active, so the view has one thing to check.
public func recordingLimitCountdown(_ state: RecordingLimitState, now: Date) -> String? {
    guard let promptedAt = state.promptedAt else { return nil }

    let left = min(max(recordingLimitGracePeriod - now.timeIntervalSince(promptedAt), 0), recordingLimitGracePeriod)
    let seconds = Int(left)
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

/// Why Bitnote is asking, for the menu row and the notification body.
public func recordingLimitPromptReason(_ state: RecordingLimitState) -> RecordingLimitReason {
    state.meetingEnd == nil ? .longRecording : .meetingEnded
}
