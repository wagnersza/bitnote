import Foundation

/// Build the text blob MeetingDetector searches for join URLs.
/// Mirrors EKEvent field extraction in MeetingWatcher.poll().
public func candidateText(
    title: String,
    location: String?,
    notes: String?,
    urlString: String?
) -> String {
    [title, location, notes, urlString].compactMap { $0 }.joined(separator: " ")
}

/// True when `id` hasn't been seen yet; caller inserts it after scheduling.
public func shouldNotify(id: String, notifiedIDs: Set<String>) -> Bool {
    !notifiedIDs.contains(id)
}

/// Seconds to wait before firing the countdown notification.
/// Fires ~30s before `start`; clamped to ≥1 (UNTimeIntervalNotificationTrigger minimum).
public func countdownFireDelay(start: Date, now: Date) -> TimeInterval {
    let delay = max(start.addingTimeInterval(-30).timeIntervalSince(now), 0)
    return max(delay, 1)
}

/// Seconds to wait before starting the auto-recording (at `start`, or 0 if already past).
public func recordStartDelay(start: Date, now: Date) -> TimeInterval {
    max(start.timeIntervalSince(now), 0)
}

/// Strips the `"meeting-"` prefix from a notification identifier, returning the meeting ID.
/// Returns nil when the identifier doesn't have the expected prefix.
public func meetingID(fromNotificationIdentifier identifier: String) -> String? {
    let prefix = "meeting-"
    guard identifier.hasPrefix(prefix) else { return nil }
    return String(identifier.dropFirst(prefix.count))
}
