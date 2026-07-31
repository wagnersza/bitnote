import XCTest
@testable import BitnoteCore
@testable import MeetingDetector

final class MeetingWatcherDecisionTests: XCTestCase {
    let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    // MARK: - candidateText

    func testCandidateTextJoinsAllFields() {
        let text = candidateText(title: "Standup", location: "https://zoom.us/j/1", notes: "agenda", urlString: nil)
        XCTAssertEqual(text, "Standup https://zoom.us/j/1 agenda")
    }

    func testCandidateTextSkipsNils() {
        let text = candidateText(title: "Sync", location: nil, notes: nil, urlString: nil)
        XCTAssertEqual(text, "Sync")
    }

    func testCandidateTextIncludesURLString() {
        let text = candidateText(title: "T", location: nil, notes: nil, urlString: "https://meet.google.com/abc")
        XCTAssertTrue(text.contains("meet.google.com"))
    }

    // MARK: - shouldNotify (dedup)

    func testShouldNotifyNewID() {
        XCTAssertTrue(shouldNotify(id: "abc", notifiedIDs: []))
    }

    func testShouldNotifyAlreadySeen() {
        XCTAssertFalse(shouldNotify(id: "abc", notifiedIDs: ["abc"]))
    }

    func testShouldNotifyDifferentID() {
        XCTAssertTrue(shouldNotify(id: "xyz", notifiedIDs: ["abc"]))
    }

    // MARK: - countdownFireDelay

    func testFireDelayMorethan30sAway() {
        let start = now.addingTimeInterval(120) // 120s away → fire in 90s
        XCTAssertEqual(countdownFireDelay(start: start, now: now), 90, accuracy: 0.001)
    }

    func testFireDelayExactly30sAway() {
        let start = now.addingTimeInterval(30) // fire in 0s → clamped to 1
        XCTAssertEqual(countdownFireDelay(start: start, now: now), 1, accuracy: 0.001)
    }

    func testFireDelayImminent() {
        let start = now.addingTimeInterval(5) // < 30s → negative delay → clamped to 1
        XCTAssertEqual(countdownFireDelay(start: start, now: now), 1, accuracy: 0.001)
    }

    func testFireDelayPast() {
        let start = now.addingTimeInterval(-10) // already past → clamped to 1
        XCTAssertEqual(countdownFireDelay(start: start, now: now), 1, accuracy: 0.001)
    }

    func testFireDelayMinimumIsOne() {
        // Ensure result is always ≥1 regardless of how far in the future
        let delay = countdownFireDelay(start: now.addingTimeInterval(31), now: now)
        XCTAssertGreaterThanOrEqual(delay, 1)
    }

    // MARK: - recordStartDelay

    func testRecordDelayFuture() {
        let start = now.addingTimeInterval(60)
        XCTAssertEqual(recordStartDelay(start: start, now: now), 60, accuracy: 0.001)
    }

    func testRecordDelayZeroWhenPast() {
        let start = now.addingTimeInterval(-5)
        XCTAssertEqual(recordStartDelay(start: start, now: now), 0, accuracy: 0.001)
    }

    func testRecordDelayAtExactNow() {
        XCTAssertEqual(recordStartDelay(start: now, now: now), 0, accuracy: 0.001)
    }

    // MARK: - meetingID(fromNotificationIdentifier:)

    func testParseMeetingIDValid() {
        XCTAssertEqual(meetingID(fromNotificationIdentifier: "meeting-abc-123"), "abc-123")
    }

    func testParseMeetingIDNoPrefix() {
        XCTAssertNil(meetingID(fromNotificationIdentifier: "something-else"))
    }

    func testParseMeetingIDEmptySuffix() {
        XCTAssertEqual(meetingID(fromNotificationIdentifier: "meeting-"), "")
    }

    func testParseMeetingIDExactPrefix() {
        XCTAssertNil(meetingID(fromNotificationIdentifier: "meeting"))
    }

    // MARK: - Integration: candidateText feeds MeetingDetector

    func testLocationLinkDetectedViaCandidateText() {
        let text = candidateText(title: "Standup", location: "https://zoom.us/j/999", notes: nil, urlString: nil)
        let c = CandidateEvent(id: "1", title: "Standup", start: now.addingTimeInterval(60), accepted: true, text: text)
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: 300)
        XCTAssertEqual(meetings.count, 1)
        XCTAssertTrue(meetings[0].joinURL.absoluteString.contains("zoom.us"))
    }

    func testNotesLinkDetectedViaCandidateText() {
        let text = candidateText(title: "Review", location: nil, notes: "Join: https://meet.google.com/abc-defg-hij", urlString: nil)
        let c = CandidateEvent(id: "2", title: "Review", start: now.addingTimeInterval(60), accepted: true, text: text)
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: 300)
        XCTAssertEqual(meetings.count, 1)
    }

    func testDeclinedEventSkipped() {
        let text = candidateText(title: "Party", location: "https://zoom.us/j/777", notes: nil, urlString: nil)
        let c = CandidateEvent(id: "3", title: "Party", start: now.addingTimeInterval(60), accepted: false, text: text)
        let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: 300)
        XCTAssertTrue(meetings.isEmpty)
    }

    // MARK: - Dedup via shouldNotify + real meetings

    func testDedupPreventsDoubleNotification() {
        let text = candidateText(title: "Daily", location: "https://zoom.us/j/100", notes: nil, urlString: nil)
        let c = CandidateEvent(id: "dedup-1", title: "Daily", start: now.addingTimeInterval(60), accepted: true, text: text)

        var notifiedIDs: Set<String> = []
        var count = 0

        for _ in 0..<2 {
            let meetings = MeetingDetector.recordableMeetings(from: [c], now: now, window: 300)
            for m in meetings where shouldNotify(id: m.id, notifiedIDs: notifiedIDs) {
                notifiedIDs.insert(m.id)
                count += 1
            }
        }

        XCTAssertEqual(count, 1)
    }
}
