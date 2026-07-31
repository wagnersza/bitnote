import XCTest
@testable import BitnoteCore

final class InputDeviceTests: XCTestCase {
    private let devices = [
        InputDevice(uid: "uid-1", name: "MacBook Mic"),
        InputDevice(uid: "uid-2", name: "AirPods"),
    ]

    func testNilPreferenceReturnsSystemDefault() {
        XCTAssertEqual(resolveInputDevice(preferredUID: nil, available: devices), .systemDefault)
    }

    func testSentinelUIDReturnsSystemDefault() {
        XCTAssertEqual(resolveInputDevice(preferredUID: InputDevice.systemDefault.uid, available: devices), .systemDefault)
    }

    func testEmptyStringReturnsSystemDefault() {
        XCTAssertEqual(resolveInputDevice(preferredUID: "", available: devices), .systemDefault)
    }

    func testPresentUIDReturnsDevice() {
        XCTAssertEqual(resolveInputDevice(preferredUID: "uid-2", available: devices), devices[1])
    }

    func testAbsentUIDFallsBackToSystemDefault() {
        XCTAssertEqual(resolveInputDevice(preferredUID: "uid-99", available: devices), .systemDefault)
    }
}
