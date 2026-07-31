import Foundation
import MeetingDetector

/// Seconds remaining in `now`'s local day, per the supplied calendar/time zone.
/// Anchored to `now` rather than midnight, so an already-started meeting is never "upcoming".
public func remainingDayWindow(now: Date, calendar: Calendar) -> TimeInterval {
    guard let dayEnd = calendar.dateInterval(of: .day, for: now)?.end else { return 0 }
    return max(dayEnd.timeIntervalSince(now), 0)
}

public struct TodayMeetingRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startTime: String
    public let isAutoRecording: Bool

    public init(id: String, title: String, startTime: String, isAutoRecording: Bool) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.isAutoRecording = isAutoRecording
    }
}

public enum TodaySectionState: Equatable, Sendable {
    case meetings([TodayMeetingRow])
    case noMeetingsToday
    case noCalendarAccess
}

/// Maps already-filtered Meeting Events (from `MeetingDetector.recordableMeetings`) to display rows,
/// sorted chronologically, plus the empty-state case as data so the view just renders what it's handed.
public func todaySectionState(
    meetings: [Meeting],
    calendar: Calendar,
    autoRecordingMeetingID: String?,
    hasCalendarAccess: Bool
) -> TodaySectionState {
    guard hasCalendarAccess else { return .noCalendarAccess }

    let sorted = meetings.sorted { $0.start < $1.start }
    guard !sorted.isEmpty else { return .noMeetingsToday }

    let rows = sorted.map { meeting in
        TodayMeetingRow(
            id: meeting.id,
            title: meeting.title,
            startTime: formattedStartTime(meeting.start, calendar: calendar),
            isAutoRecording: meeting.id == autoRecordingMeetingID
        )
    }
    return .meetings(rows)
}

private func formattedStartTime(_ date: Date, calendar: Calendar) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "HH:mm"
    fmt.timeZone = calendar.timeZone
    return fmt.string(from: date)
}
