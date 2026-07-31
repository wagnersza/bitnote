import Foundation

public struct CalendarInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let accountName: String

    public init(id: String, title: String, accountName: String) {
        self.id = id
        self.title = title
        self.accountName = accountName
    }
}

public struct CalendarGroup: Identifiable, Equatable, Sendable {
    public let accountName: String
    public let calendars: [CalendarInfo]
    public var id: String { accountName }
}

/// Pure: collapsed-row summary text. Zero selected reads as "monitor everything", not "nothing configured".
public func calendarSelectionSummary(selectedCount: Int, totalCount: Int) -> String {
    guard selectedCount > 0 else { return "All calendars" }
    return "\(selectedCount) of \(totalCount)"
}

/// Pure: group calendars by account, sorted deterministically (account name, then title) so ordering
/// is stable across launches regardless of EventKit's return order.
public func groupCalendarsByAccount(_ calendars: [CalendarInfo]) -> [CalendarGroup] {
    let grouped = Dictionary(grouping: calendars, by: \.accountName)
    return grouped.keys.sorted().map { accountName in
        let sorted = grouped[accountName]!.sorted {
            $0.title == $1.title ? $0.id < $1.id : $0.title < $1.title
        }
        return CalendarGroup(accountName: accountName, calendars: sorted)
    }
}
