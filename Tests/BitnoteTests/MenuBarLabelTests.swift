import XCTest
@testable import BitnoteCore

final class MenuBarLabelTests: XCTestCase {
    func testIdleSymbolOnly() {
        let result = menuBarLabel(isRecording: false, elapsed: "00:00")
        XCTAssertEqual(result.symbol, "record.circle")
        XCTAssertNil(result.text)
    }

    func testRecordingTextAndSymbol() {
        let result = menuBarLabel(isRecording: true, elapsed: "02:14")
        XCTAssertEqual(result.symbol, "record.circle.fill")
        XCTAssertEqual(result.text, "REC 02:14")
    }

    func testRecordingElapsedZero() {
        let result = menuBarLabel(isRecording: true, elapsed: "00:00")
        XCTAssertEqual(result.text, "REC 00:00")
    }
}
