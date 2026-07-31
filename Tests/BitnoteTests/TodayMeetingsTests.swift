import XCTest
@testable import BitnoteCore
@testable import MeetingDetector

final class TodayMeetingsTests: XCTestCase {
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: - remainingDayWindow

    func testWindowStartsAtNowNotMidnight() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        let expectedEnd = date(2024, 3, 16, 0, 0, calendar: cal)
        XCTAssertEqual(window, expectedEnd.timeIntervalSince(now), accuracy: 0.001)
    }

    func testWindowLateEveningIsShort() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 23, 30, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        XCTAssertEqual(window, 1800, accuracy: 0.001)
    }

    func testWindowJustBeforeMidnightDoesNotSpillIntoTomorrow() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 23, 59, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        XCTAssertLessThanOrEqual(window, 60)
        XCTAssertGreaterThanOrEqual(window, 0)
    }

    func testWindowUnderNonUTCTimeZone() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let now = date(2024, 3, 15, 20, 0, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        let expectedEnd = date(2024, 3, 16, 0, 0, calendar: cal)
        XCTAssertEqual(window, expectedEnd.timeIntervalSince(now), accuracy: 0.001)
    }

    // MARK: - Listing filter (integration over MeetingDetector.recordableMeetings)

    private func candidate(
        id: String,
        title: String = "Standup",
        start: Date,
        accepted: Bool = true,
        text: String = "https://zoom.us/j/111"
    ) -> CandidateEvent {
        CandidateEvent(id: id, title: title, start: start, accepted: accepted, text: text)
    }

    func testAcceptedWithLinkAppears() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        let c = candidate(id: "1", start: now.addingTimeInterval(3600))
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: window)
        XCTAssertEqual(meetings.count, 1)
    }

    func testNoLinkExcluded() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        let c = candidate(id: "1", start: now.addingTimeInterval(3600), text: "no link here")
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: window)
        XCTAssertTrue(meetings.isEmpty)
    }

    func testLinkInNotesOrLocationStillAppears() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        let text = candidateText(title: "Review", location: nil, notes: "Join: https://meet.google.com/abc-defg-hij", urlString: nil)
        let c = candidate(id: "1", start: now.addingTimeInterval(3600), text: text)
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: window)
        XCTAssertEqual(meetings.count, 1)
    }

    func testDeclinedExcluded() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        let c = candidate(id: "1", start: now.addingTimeInterval(3600), accepted: false)
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: window)
        XCTAssertTrue(meetings.isEmpty)
    }

    func testAttendeeLessPersonalEventWithLinkAppears() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        // MeetingWatcher defaults `accepted = true` when there are no attendees at all.
        let c = candidate(id: "1", start: now.addingTimeInterval(3600), accepted: true)
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: window)
        XCTAssertEqual(meetings.count, 1)
    }

    func testEventStartingTomorrowExcluded() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        let tomorrow = date(2024, 3, 16, 9, 0, calendar: cal)
        let c = candidate(id: "1", start: tomorrow)
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: window)
        XCTAssertTrue(meetings.isEmpty)
    }

    func testEventAlreadyStartedExcluded() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let window = remainingDayWindow(now: now, calendar: cal)
        let past = now.addingTimeInterval(-60)
        let c = candidate(id: "1", start: past)
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: window)
        XCTAssertTrue(meetings.isEmpty)
    }

    // MARK: - Row presentation

    func testRowsSortedChronologicallyRegardlessOfInputOrder() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let later = Meeting(id: "later", title: "Later", start: now.addingTimeInterval(7200), joinURL: URL(string: "https://zoom.us/j/1")!)
        let earlier = Meeting(id: "earlier", title: "Earlier", start: now.addingTimeInterval(1800), joinURL: URL(string: "https://zoom.us/j/2")!)

        let state = todaySectionState(meetings: [later, earlier], calendar: cal, autoRecordingMeetingID: nil, hasCalendarAccess: true)
        guard case .meetings(let rows) = state else { return XCTFail("expected meetings") }
        XCTAssertEqual(rows.map(\.id), ["earlier", "later"])
    }

    func testStartTimeFormatted() {
        let cal = utcCalendar()
        let start = date(2024, 3, 15, 14, 30, calendar: cal)
        let meeting = Meeting(id: "1", title: "Sync", start: start, joinURL: URL(string: "https://zoom.us/j/1")!)

        let state = todaySectionState(meetings: [meeting], calendar: cal, autoRecordingMeetingID: nil, hasCalendarAccess: true)
        guard case .meetings(let rows) = state else { return XCTFail("expected meetings") }
        XCTAssertEqual(rows[0].startTime, "14:30")
    }

    func testAutoRecordingRowFlaggedAndOnlyThatOne() {
        let cal = utcCalendar()
        let now = date(2024, 3, 15, 9, 0, calendar: cal)
        let m1 = Meeting(id: "live", title: "Live", start: now.addingTimeInterval(60), joinURL: URL(string: "https://zoom.us/j/1")!)
        let m2 = Meeting(id: "other", title: "Other", start: now.addingTimeInterval(3600), joinURL: URL(string: "https://zoom.us/j/2")!)

        let state = todaySectionState(meetings: [m1, m2], calendar: cal, autoRecordingMeetingID: "live", hasCalendarAccess: true)
        guard case .meetings(let rows) = state else { return XCTFail("expected meetings") }
        let flagged = rows.filter(\.isAutoRecording)
        XCTAssertEqual(flagged.map(\.id), ["live"])
    }

    func testMeetingWithEmptyTitleYieldsUsableRow() {
        let cal = utcCalendar()
        let start = date(2024, 3, 15, 10, 0, calendar: cal)
        let meeting = Meeting(id: "1", title: "", start: start, joinURL: URL(string: "https://zoom.us/j/1")!)

        let state = todaySectionState(meetings: [meeting], calendar: cal, autoRecordingMeetingID: nil, hasCalendarAccess: true)
        guard case .meetings(let rows) = state else { return XCTFail("expected meetings") }
        XCTAssertEqual(rows[0].title, "")
        XCTAssertEqual(rows[0].startTime, "10:00")
    }

    // MARK: - Empty state

    func testNoCandidatesYieldsNoMeetingsToday() {
        let cal = utcCalendar()
        let state = todaySectionState(meetings: [], calendar: cal, autoRecordingMeetingID: nil, hasCalendarAccess: true)
        XCTAssertEqual(state, .noMeetingsToday)
    }

    func testNoCalendarAccessIsDistinguishableFromNoMeetings() {
        let cal = utcCalendar()
        let state = todaySectionState(meetings: [], calendar: cal, autoRecordingMeetingID: nil, hasCalendarAccess: false)
        XCTAssertEqual(state, .noCalendarAccess)
        XCTAssertNotEqual(state, .noMeetingsToday)
    }
}
