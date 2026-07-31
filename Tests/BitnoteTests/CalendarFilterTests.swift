import XCTest
@testable import BitnoteCore

final class CalendarFilterTests: XCTestCase {
    private let available: Set<String> = ["cal-1", "cal-2", "cal-3"]

    func testEmptySelectionReturnsNil() {
        XCTAssertNil(calendarFilter(selectedIDs: [], availableIDs: available))
    }

    func testAllValidReturnsExactSet() {
        let result = calendarFilter(selectedIDs: ["cal-1", "cal-2"], availableIDs: available)
        XCTAssertEqual(Set(result!), ["cal-1", "cal-2"])
    }

    func testPartialStaleReturnsIntersection() {
        let result = calendarFilter(selectedIDs: ["cal-1", "stale-99"], availableIDs: available)
        XCTAssertEqual(result, ["cal-1"])
    }

    func testAllStaleReturnsNil() {
        XCTAssertNil(calendarFilter(selectedIDs: ["stale-1", "stale-2"], availableIDs: available))
    }
}
