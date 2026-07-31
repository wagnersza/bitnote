import XCTest
@testable import BitnoteCore

final class AirPodsDetectorTests: XCTestCase {
    func testPositiveExact() {
        XCTAssertTrue(isAirPods("AirPods Pro"))
    }

    func testPositiveLowercase() {
        XCTAssertTrue(isAirPods("airpods max"))
    }

    func testPositiveMixedCase() {
        XCTAssertTrue(isAirPods("AIRPODS"))
    }

    func testPositiveEmbedded() {
        XCTAssertTrue(isAirPods("My AirPods (3rd generation)"))
    }

    func testNegativeBuiltIn() {
        XCTAssertFalse(isAirPods("MacBook Pro Microphone"))
    }

    func testNegativeEmpty() {
        XCTAssertFalse(isAirPods(""))
    }

    func testNegativeUnrelated() {
        XCTAssertFalse(isAirPods("Bose QC45"))
    }
}
