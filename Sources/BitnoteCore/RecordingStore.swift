import Foundation

public struct Recording: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let date: Date
    public var fileSize: Int64

    public init(id: UUID = UUID(), url: URL, date: Date, fileSize: Int64) {
        self.id = id
        self.url = url
        self.date = date
        self.fileSize = fileSize
    }

    public var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    public var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

public struct RecordingStore: Sendable {
    public private(set) var recordings: [Recording]
    public let maxRecordings: Int

    public init(recordings: [Recording] = [], maxRecordings: Int = 20) {
        self.recordings = recordings
        self.maxRecordings = maxRecordings
    }

    public static func makeFilename(date: Date) -> String {
        makeFilename(title: nil, date: date)
    }

    public static func makeFilename(title: String?, date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let ts = fmt.string(from: date)
        let sanitized = title.map { sanitizeFilename($0) } ?? ""
        let stem = sanitized.isEmpty ? "Bitnote" : sanitized
        return "\(stem)_\(ts).m4a"
    }

    public static func sanitizeFilename(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:\\?%*|\"<>").union(.controlCharacters)
        return name
            .components(separatedBy: illegal)
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

    public mutating func add(_ recording: Recording) {
        recordings.insert(recording, at: 0)
        if recordings.count > maxRecordings {
            recordings = Array(recordings.prefix(maxRecordings))
        }
    }

    public mutating func delete(id: UUID) {
        recordings.removeAll { $0.id == id }
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(recordings)
    }

    public static func decoded(from data: Data) throws -> [Recording] {
        try JSONDecoder().decode([Recording].self, from: data)
    }
}
