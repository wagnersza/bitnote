import XCTest
@testable import MeetingDetector

final class MeetingDetectorTests: XCTestCase {
    let now = Date(timeIntervalSinceReferenceDate: 0)
    let window: TimeInterval = 300 // 5 minutes

    // MARK: - videoCallLink(in:)

    func testZoomLinkDetected() {
        let url = MeetingDetector.videoCallLink(in: "Join: https://zoom.us/j/123456789")
        XCTAssertEqual(url, URL(string: "https://zoom.us/j/123456789"))
    }

    func testZoomSubdomainLinkDetected() {
        let url = MeetingDetector.videoCallLink(in: "https://us02web.zoom.us/j/987654321?pwd=abc")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("zoom.us/j/"))
    }

    func testGoogleMeetLinkDetected() {
        let url = MeetingDetector.videoCallLink(in: "Meeting at https://meet.google.com/abc-defg-hij")
        XCTAssertEqual(url, URL(string: "https://meet.google.com/abc-defg-hij"))
    }

    func testTeamsMicrosoftLinkDetected() {
        let url = MeetingDetector.videoCallLink(in: "https://teams.microsoft.com/l/meetup-join/abc")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("teams.microsoft.com"))
    }

    func testTeamsLiveLinkDetected() {
        let url = MeetingDetector.videoCallLink(in: "https://teams.live.com/meet/9876543210")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("teams.live.com"))
    }

    func testNoLinkReturnsNil() {
        XCTAssertNil(MeetingDetector.videoCallLink(in: "Just a regular meeting, no link"))
    }

    func testNonVideoLinkReturnsNil() {
        XCTAssertNil(MeetingDetector.videoCallLink(in: "https://example.com/meeting"))
    }

    // MARK: - recordableMeetings

    private func event(
        id: String = "1",
        title: String = "Standup",
        start: Date? = nil,
        accepted: Bool = true,
        text: String = "https://zoom.us/j/111"
    ) -> CandidateEvent {
        CandidateEvent(
            id: id,
            title: title,
            start: start ?? now.addingTimeInterval(60),
            accepted: accepted,
            text: text
        )
    }

    func testAcceptedWithLinkInWindowReturned() {
        let meetings = MeetingDetector.recordableMeetings(from: [event()], now: now, window: window)
        XCTAssertEqual(meetings.count, 1)
        XCTAssertEqual(meetings[0].id, "1")
        XCTAssertEqual(meetings[0].joinURL, URL(string: "https://zoom.us/j/111"))
    }

    func testDeclinedExcluded() {
        let meetings = MeetingDetector.recordableMeetings(from: [event(accepted: false)], now: now, window: window)
        XCTAssertTrue(meetings.isEmpty)
    }

    func testAcceptedNoLinkExcluded() {
        let meetings = MeetingDetector.recordableMeetings(from: [event(text: "No video link here")], now: now, window: window)
        XCTAssertTrue(meetings.isEmpty)
    }

    func testOutsideWindowFutureExcluded() {
        let far = now.addingTimeInterval(window + 1)
        let meetings = MeetingDetector.recordableMeetings(from: [event(start: far)], now: now, window: window)
        XCTAssertTrue(meetings.isEmpty)
    }

    func testPastEventExcluded() {
        let past = now.addingTimeInterval(-1)
        let meetings = MeetingDetector.recordableMeetings(from: [event(start: past)], now: now, window: window)
        XCTAssertTrue(meetings.isEmpty)
    }

    func testEventAtWindowBoundaryIncluded() {
        let atBoundary = now.addingTimeInterval(window)
        let meetings = MeetingDetector.recordableMeetings(from: [event(start: atBoundary)], now: now, window: window)
        XCTAssertEqual(meetings.count, 1)
    }

    func testEventAtNowIncluded() {
        let meetings = MeetingDetector.recordableMeetings(from: [event(start: now)], now: now, window: window)
        XCTAssertEqual(meetings.count, 1)
    }

    func testLinkInLocationText() {
        let e = event(text: "Location: https://meet.google.com/xyz-abcd-efg")
        let meetings = MeetingDetector.recordableMeetings(from: [e], now: now, window: window)
        XCTAssertEqual(meetings.count, 1)
        XCTAssertEqual(meetings[0].joinURL, URL(string: "https://meet.google.com/xyz-abcd-efg"))
    }

    func testLinkInNotesText() {
        let e = event(text: "Notes: join via https://teams.microsoft.com/l/meetup-join/abc")
        let meetings = MeetingDetector.recordableMeetings(from: [e], now: now, window: window)
        XCTAssertEqual(meetings.count, 1)
        XCTAssertTrue(meetings[0].joinURL.absoluteString.contains("teams.microsoft.com"))
    }

    func testMultipleEventsFilteredCorrectly() {
        let events = [
            event(id: "accepted-zoom", text: "https://zoom.us/j/100"),
            event(id: "declined", accepted: false, text: "https://zoom.us/j/200"),
            event(id: "no-link", text: "no link"),
            event(id: "future", start: now.addingTimeInterval(window + 60), text: "https://zoom.us/j/300"),
            event(id: "meet", text: "https://meet.google.com/aaa-bbb-ccc"),
        ]
        let meetings = MeetingDetector.recordableMeetings(from: events, now: now, window: window)
        XCTAssertEqual(meetings.count, 2)
        XCTAssertEqual(Set(meetings.map(\.id)), ["accepted-zoom", "meet"])
    }
}
