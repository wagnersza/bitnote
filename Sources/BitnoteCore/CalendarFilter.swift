import Foundation

/// nil = monitor all calendars (empty selection or all-stale fallback).
public func calendarFilter(selectedIDs: Set<String>, availableIDs: Set<String>) -> [String]? {
    guard !selectedIDs.isEmpty else { return nil }
    let valid = selectedIDs.intersection(availableIDs)
    return valid.isEmpty ? nil : Array(valid)
}
