import XCTest
@testable import BitnoteCore

final class CalendarSelectionSummaryTests: XCTestCase {
    func testZeroSelectedReadsAsAllCalendars() {
        XCTAssertEqual(calendarSelectionSummary(selectedCount: 0, totalCount: 19), "All calendars")
    }

    func testOneOfManySelected() {
        XCTAssertEqual(calendarSelectionSummary(selectedCount: 1, totalCount: 19), "1 of 19")
    }

    func testSeveralSelected() {
        XCTAssertEqual(calendarSelectionSummary(selectedCount: 3, totalCount: 19), "3 of 19")
    }

    func testSelectedEqualsTotalStillReportsNofM() {
        XCTAssertEqual(calendarSelectionSummary(selectedCount: 19, totalCount: 19), "19 of 19")
    }

    func testZeroTotalWithZeroSelectedHandledGracefully() {
        XCTAssertEqual(calendarSelectionSummary(selectedCount: 0, totalCount: 0), "All calendars")
    }

    func testEffectiveCountMatchesCalendarFilterAcrossStaleIDs() {
        let available: Set<String> = ["cal-1", "cal-2", "cal-3"]
        let selected: Set<String> = ["cal-1", "stale-99"]

        let filterResult = calendarFilter(selectedIDs: selected, availableIDs: available)
        let effectiveCount = filterResult?.count ?? 0

        XCTAssertEqual(effectiveCount, 1)
        XCTAssertEqual(calendarSelectionSummary(selectedCount: effectiveCount, totalCount: available.count), "1 of 3")
    }

    func testAllStaleSelectionSummarizesAsAllCalendars() {
        let available: Set<String> = ["cal-1", "cal-2", "cal-3"]
        let selected: Set<String> = ["stale-1", "stale-2"]

        let filterResult = calendarFilter(selectedIDs: selected, availableIDs: available)
        let effectiveCount = filterResult?.count ?? 0

        XCTAssertNil(filterResult)
        XCTAssertEqual(calendarSelectionSummary(selectedCount: effectiveCount, totalCount: available.count), "All calendars")
    }
}

final class GroupCalendarsByAccountTests: XCTestCase {
    func testEmptyInputYieldsNoGroups() {
        XCTAssertEqual(groupCalendarsByAccount([]), [])
    }

    func testSingleAccountYieldsOneGroup() {
        let calendars = [
            CalendarInfo(id: "1", title: "Work", accountName: "iCloud"),
            CalendarInfo(id: "2", title: "Home", accountName: "iCloud")
        ]
        let groups = groupCalendarsByAccount(calendars)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].accountName, "iCloud")
        XCTAssertEqual(groups[0].calendars.map(\.title), ["Home", "Work"])
    }

    func testMultipleAccountsOrderedDeterministicallyByAccountName() {
        let calendars = [
            CalendarInfo(id: "1", title: "Cal A", accountName: "Google"),
            CalendarInfo(id: "2", title: "Cal B", accountName: "Exchange"),
            CalendarInfo(id: "3", title: "Cal C", accountName: "iCloud")
        ]
        let groups = groupCalendarsByAccount(calendars)
        XCTAssertEqual(groups.map(\.accountName), ["Exchange", "Google", "iCloud"])
    }

    func testCalendarsSortedDeterministicallyByTitleWithinGroup() {
        let calendars = [
            CalendarInfo(id: "1", title: "Zebra", accountName: "iCloud"),
            CalendarInfo(id: "2", title: "Apple", accountName: "iCloud"),
            CalendarInfo(id: "3", title: "Mango", accountName: "iCloud")
        ]
        let groups = groupCalendarsByAccount(calendars)
        XCTAssertEqual(groups[0].calendars.map(\.title), ["Apple", "Mango", "Zebra"])
    }

    func testSameTitleDifferentAccountBothSurviveInOwnGroups() {
        let calendars = [
            CalendarInfo(id: "1", title: "Work", accountName: "Google"),
            CalendarInfo(id: "2", title: "Work", accountName: "iCloud")
        ]
        let groups = groupCalendarsByAccount(calendars)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.flatMap { $0.calendars.map(\.title) }, ["Work", "Work"])
        XCTAssertEqual(groups.map(\.accountName), ["Google", "iCloud"])
    }

    func testGroupingIsStableRegardlessOfInputOrder() {
        let calendars = [
            CalendarInfo(id: "1", title: "Cal A", accountName: "Google"),
            CalendarInfo(id: "2", title: "Cal B", accountName: "Exchange"),
            CalendarInfo(id: "3", title: "Cal C", accountName: "iCloud")
        ]
        let shuffled = [calendars[2], calendars[0], calendars[1]]

        XCTAssertEqual(groupCalendarsByAccount(calendars), groupCalendarsByAccount(shuffled))
    }
}
