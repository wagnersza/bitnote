import XCTest
@testable import BitnoteCore

final class RingBufferTests: XCTestCase {
    func testBasicWriteRead() {
        var buf = RingBuffer(capacity: 4)
        buf.write([1, 2, 3])
        XCTAssertEqual(buf.count, 3)
        let out = buf.read(count: 3)
        XCTAssertEqual(out, [1, 2, 3])
        XCTAssertEqual(buf.count, 0)
    }

    func testWrapAround() {
        var buf = RingBuffer(capacity: 4)
        buf.write([1, 2, 3, 4])
        _ = buf.read(count: 2)           // consume 1,2 — readIndex = 2
        buf.write([5, 6])                // wraps around: slots 0,1
        let out = buf.read(count: 4)
        XCTAssertEqual(out, [3, 4, 5, 6])
    }

    func testOverwriteOldestWhenExactlyFull() {
        var buf = RingBuffer(capacity: 3)
        buf.write([1, 2, 3])             // exactly full
        buf.write([4])                   // overwrites 1
        XCTAssertEqual(buf.count, 3)
        let out = buf.read(count: 3)
        XCTAssertEqual(out, [2, 3, 4])
    }

    func testOverwriteOldestMultiple() {
        var buf = RingBuffer(capacity: 3)
        buf.write([1, 2, 3, 4, 5])      // 1,2 overwritten
        XCTAssertEqual(buf.count, 3)
        let out = buf.read(count: 3)
        XCTAssertEqual(out, [3, 4, 5])
    }

    func testPartialReadRequestGreaterThanAvailable() {
        var buf = RingBuffer(capacity: 8)
        buf.write([1, 2])
        let out = buf.read(count: 10)   // request > available
        XCTAssertEqual(out, [1, 2])
        XCTAssertEqual(buf.count, 0)
    }

    func testReadZeroFromEmpty() {
        var buf = RingBuffer(capacity: 4)
        let out = buf.read(count: 0)
        XCTAssertTrue(out.isEmpty)
        XCTAssertEqual(buf.count, 0)
    }

    func testCapacityProperty() {
        let buf = RingBuffer(capacity: 10)
        XCTAssertEqual(buf.capacity, 10)
    }
}

final class MixTests: XCTestCase {
    func testMixBelowClip() {
        let out = mix(mic: [0.3], sys: [0.4])
        XCTAssertEqual(out[0], 0.7, accuracy: 1e-6)
    }

    func testMixAtExactlyOne() {
        // |sum| == 1.0: no clipping
        let out = mix(mic: [0.5], sys: [0.5])
        XCTAssertEqual(out[0], 1.0, accuracy: 1e-6)
    }

    func testMixAboveClipPositive() {
        // sum = 1.5 → clipped to 1.0
        let out = mix(mic: [1.0], sys: [0.5])
        XCTAssertEqual(out[0], 1.0, accuracy: 1e-6)
    }

    func testMixAboveClipNegative() {
        // sum = -1.5 → clipped to -1.0
        let out = mix(mic: [-1.0], sys: [-0.5])
        XCTAssertEqual(out[0], -1.0, accuracy: 1e-6)
    }

    func testMixMicLongerThanSys() {
        let out = mix(mic: [0.2, 0.3], sys: [0.1])
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0], 0.3, accuracy: 1e-6)
        XCTAssertEqual(out[1], 0.3, accuracy: 1e-6)  // sys[1] = 0
    }

    func testMixSysLongerThanMic() {
        let out = mix(mic: [0.1], sys: [0.2, 0.3])
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0], 0.3, accuracy: 1e-6)
        XCTAssertEqual(out[1], 0.3, accuracy: 1e-6)  // mic[1] = 0
    }

    func testMixEmpty() {
        let out = mix(mic: [], sys: [])
        XCTAssertTrue(out.isEmpty)
    }
}
