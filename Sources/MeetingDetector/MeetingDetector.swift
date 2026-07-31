import Foundation

public struct CandidateEvent {
    public let id: String
    public let title: String
    public let start: Date
    public let accepted: Bool
    public let text: String

    public init(id: String, title: String, start: Date, accepted: Bool, text: String) {
        self.id = id
        self.title = title
        self.start = start
        self.accepted = accepted
        self.text = text
    }
}

public struct Meeting: Equatable {
    public let id: String
    public let title: String
    public let start: Date
    public let joinURL: URL

    public init(id: String, title: String, start: Date, joinURL: URL) {
        self.id = id
        self.title = title
        self.start = start
        self.joinURL = joinURL
    }
}

public enum MeetingDetector {
    private static let videoCallPattern = try! NSRegularExpression(
        pattern: #"https?://[^\s<>"]*(?:zoom\.us/j/|meet\.google\.com/|teams\.microsoft\.com/|teams\.live\.com/)[^\s<>"]*"#,
        options: .caseInsensitive
    )

    public static func videoCallLink(in text: String) -> URL? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = videoCallPattern.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text) else { return nil }
        return URL(string: String(text[matchRange]))
    }

    public static func recordableMeetings(from events: [CandidateEvent], now: Date, window: TimeInterval) -> [Meeting] {
        let deadline = now.addingTimeInterval(window)
        return events.compactMap { event in
            guard event.accepted,
                  event.start >= now,
                  event.start <= deadline,
                  let url = videoCallLink(in: event.text) else { return nil }
            return Meeting(id: event.id, title: event.title, start: event.start, joinURL: url)
        }
    }
}
