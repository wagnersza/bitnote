import XCTest
@testable import BitnoteCore

final class RecordingLimitTests: XCTestCase {
    let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    // MARK: - recordingLimitStart

    func testFirstDeadlineIsThirtyMinutesAfterStart() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        XCTAssertEqual(state.deadline, start.addingTimeInterval(recordingLimitLongRoundInterval))
        XCTAssertNil(state.promptedAt)
        XCTAssertEqual(state.roundsDone, 0)
        XCTAssertNil(state.meetingEnd)
    }

    // MARK: - Tick before the deadline

    func testNoActionOneSecondAfterStart() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        let (next, action) = recordingLimitTick(state, now: start.addingTimeInterval(1))
        XCTAssertEqual(action, .none)
        XCTAssertEqual(next, state)
    }

    func testNoActionOneSecondBeforeTheDeadline() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        let (next, action) = recordingLimitTick(state, now: state.deadline.addingTimeInterval(-1))
        XCTAssertEqual(action, .none)
        XCTAssertEqual(next, state)
    }

    // MARK: - The prompt at the deadline

    func testPromptAtTheDeadline() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        let (next, action) = recordingLimitTick(state, now: state.deadline)
        XCTAssertEqual(action, .showPrompt)
        XCTAssertEqual(next.promptedAt, state.deadline)
        XCTAssertEqual(next.roundsDone, 0)
        XCTAssertEqual(next.deadline, state.deadline)
    }

    func testPromptShownOnceAndNotRepeatedOnLaterTicks() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        let (prompted, first) = recordingLimitTick(state, now: state.deadline)
        XCTAssertEqual(first, .showPrompt)

        let (afterOne, second) = recordingLimitTick(prompted, now: state.deadline.addingTimeInterval(1))
        XCTAssertEqual(second, .none)
        let (afterTwo, third) = recordingLimitTick(afterOne, now: state.deadline.addingTimeInterval(2))
        XCTAssertEqual(third, .none)
        XCTAssertEqual(afterTwo.promptedAt, state.deadline)
    }

    // MARK: - The grace period

    func testNoActionDuringTheGracePeriod() {
        let prompted = promptedState()
        for offset in [1.0, 30.0, 59.0] {
            let (next, action) = recordingLimitTick(prompted, now: prompted.promptedAt!.addingTimeInterval(offset))
            XCTAssertEqual(action, .none, "offset \(offset)")
            XCTAssertEqual(next, prompted, "offset \(offset)")
        }
    }

    func testStopWhenTheGracePeriodExpires() {
        let prompted = promptedState()
        let now = prompted.promptedAt!.addingTimeInterval(recordingLimitGracePeriod + 1)
        let (next, action) = recordingLimitTick(prompted, now: now)
        XCTAssertEqual(action, .stopRecording)
        XCTAssertEqual(next, prompted)
    }

    func testExactGraceBoundaryStops() {
        let prompted = promptedState()
        let boundary = prompted.promptedAt!.addingTimeInterval(recordingLimitGracePeriod)
        XCTAssertEqual(recordingLimitTick(prompted, now: boundary).1, .stopRecording)

        let justBefore = boundary.addingTimeInterval(-0.001)
        XCTAssertEqual(recordingLimitTick(prompted, now: justBefore).1, .none)
    }

    // MARK: - Keep recording

    func testKeepClearsThePromptAndSetsTheNextDeadline() {
        let prompted = promptedState()
        let clicked = prompted.promptedAt!.addingTimeInterval(10)
        let next = recordingLimitKeep(prompted, now: clicked)

        XCTAssertNil(next.promptedAt)
        XCTAssertEqual(next.roundsDone, 1)
        XCTAssertEqual(next.deadline, clicked.addingTimeInterval(recordingLimitLongRoundInterval))
    }

    func testKeepWithNoActivePromptChangesNothing() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        let next = recordingLimitKeep(state, now: start.addingTimeInterval(500))
        XCTAssertEqual(next, state)
    }

    func testEveryRoundEndsWithAFreshDeadlineSoARecordingIsNeverUnlimited() {
        var state = recordingLimitStart(meetingEnd: nil, now: start)
        var now = start
        for _ in 0..<5 {
            now = state.deadline
            let (prompted, action) = recordingLimitTick(state, now: now)
            XCTAssertEqual(action, .showPrompt)
            state = recordingLimitKeep(prompted, now: now)
            XCTAssertNil(state.promptedAt)
            XCTAssertGreaterThan(state.deadline, now)
        }
    }

    // MARK: - The 30 / 30 / 15 / 15 round ladder

    func testRoundLadderIntervals() {
        XCTAssertEqual(recordingLimitInterval(roundsDone: 0), recordingLimitLongRoundInterval)
        XCTAssertEqual(recordingLimitInterval(roundsDone: 1), recordingLimitLongRoundInterval)
        XCTAssertEqual(recordingLimitInterval(roundsDone: 2), recordingLimitShortRoundInterval)
        XCTAssertEqual(recordingLimitInterval(roundsDone: 3), recordingLimitShortRoundInterval)
        XCTAssertEqual(recordingLimitInterval(roundsDone: 9), recordingLimitShortRoundInterval)
    }

    func testRoundLadderAcrossFourKeepClicks() {
        var state = recordingLimitStart(meetingEnd: nil, now: start)
        var gaps: [TimeInterval] = []
        var now = start

        for _ in 0..<4 {
            gaps.append(state.deadline.timeIntervalSince(now))
            now = state.deadline
            let (prompted, action) = recordingLimitTick(state, now: now)
            XCTAssertEqual(action, .showPrompt)
            state = recordingLimitKeep(prompted, now: now)
        }

        XCTAssertEqual(gaps, [
            recordingLimitLongRoundInterval,   // round 1: 30 min
            recordingLimitLongRoundInterval,   // round 2: 30 min
            recordingLimitShortRoundInterval,  // round 3: 15 min
            recordingLimitShortRoundInterval   // round 4: 15 min
        ])
    }

    // MARK: - A large time jump (computer sleep)

    func testLargeTimeJumpGivesThePromptAndNeverAStop() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        let wake = start.addingTimeInterval(4 * 60 * 60) // slept four hours
        let (next, action) = recordingLimitTick(state, now: wake)

        XCTAssertEqual(action, .showPrompt)
        XCTAssertEqual(next.promptedAt, wake)
    }

    func testTheFullGracePeriodStartsAtTheWakePrompt() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        let wake = start.addingTimeInterval(4 * 60 * 60)
        let (prompted, _) = recordingLimitTick(state, now: wake)

        XCTAssertEqual(recordingLimitCountdown(prompted, now: wake), "1:00")
        XCTAssertEqual(recordingLimitTick(prompted, now: wake.addingTimeInterval(59)).1, .none)
        XCTAssertEqual(recordingLimitTick(prompted, now: wake.addingTimeInterval(60)).1, .stopRecording)
    }

    // MARK: - recordingLimitCountdown

    func testCountdownAtSeveralTimes() {
        let prompted = promptedState()
        let promptedAt = prompted.promptedAt!

        XCTAssertEqual(recordingLimitCountdown(prompted, now: promptedAt), "1:00")
        XCTAssertEqual(recordingLimitCountdown(prompted, now: promptedAt.addingTimeInterval(13)), "0:47")
        XCTAssertEqual(recordingLimitCountdown(prompted, now: promptedAt.addingTimeInterval(59)), "0:01")
        XCTAssertEqual(recordingLimitCountdown(prompted, now: promptedAt.addingTimeInterval(60)), "0:00")
        XCTAssertEqual(recordingLimitCountdown(prompted, now: promptedAt.addingTimeInterval(600)), "0:00")
    }

    func testCountdownClampsWhenTheClockRunsBackwards() {
        let prompted = promptedState()
        XCTAssertEqual(recordingLimitCountdown(prompted, now: prompted.promptedAt!.addingTimeInterval(-30)), "1:00")
    }

    func testCountdownIsEmptyWhenNoPromptIsActive() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        XCTAssertNil(recordingLimitCountdown(state, now: start))
        XCTAssertNil(recordingLimitCountdown(state, now: start.addingTimeInterval(10_000)))

        let keptState = recordingLimitKeep(promptedState(), now: start.addingTimeInterval(1_900))
        XCTAssertNil(recordingLimitCountdown(keptState, now: start.addingTimeInterval(1_901)))
    }

    // MARK: - recordingLimitPromptReason

    func testReasonIsLongRecordingWithNoMeeting() {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        XCTAssertEqual(recordingLimitPromptReason(state), .longRecording)
        XCTAssertEqual(recordingLimitPromptReason(state).text, "The recording is long.")
    }

    func testReasonIsMeetingEndedWhenAMeetingAnchorsTheRecording() {
        let state = recordingLimitStart(meetingEnd: start.addingTimeInterval(1_800), now: start)
        XCTAssertEqual(recordingLimitPromptReason(state), .meetingEnded)
        XCTAssertEqual(recordingLimitPromptReason(state).text, "The meeting ended.")
    }

    // MARK: - Helpers

    /// A state whose prompt is active, reached the way the app reaches it: start, then tick at the deadline.
    private func promptedState() -> RecordingLimitState {
        let state = recordingLimitStart(meetingEnd: nil, now: start)
        return recordingLimitTick(state, now: state.deadline).0
    }
}
