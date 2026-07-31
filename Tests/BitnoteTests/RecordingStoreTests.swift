import XCTest
@testable import BitnoteCore

final class RecordingTests: XCTestCase {
    private func makeRecording(name: String = "test", size: Int64 = 1024) -> Recording {
        Recording(url: URL(fileURLWithPath: "/tmp/\(name).m4a"), date: Date(), fileSize: size)
    }

    func testDisplayName() {
        let r = makeRecording(name: "Bitnote_2024-01-15_10-30-00")
        XCTAssertEqual(r.displayName, "Bitnote_2024-01-15_10-30-00")
    }

    func testFormattedSizeKB() {
        let r = makeRecording(size: 2048)
        XCTAssertFalse(r.formattedSize.isEmpty)
    }

    func testFormattedDateNonEmpty() {
        let r = makeRecording()
        XCTAssertFalse(r.formattedDate.isEmpty)
    }

    func testEquatable() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/a.m4a")
        let date = Date()
        let a = Recording(id: id, url: url, date: date, fileSize: 0)
        let b = Recording(id: id, url: url, date: date, fileSize: 0)
        XCTAssertEqual(a, b)
    }
}

final class RecordingStoreFilenameTests: XCTestCase {
    private var fixedDate: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: 2024, month: 3, day: 15, hour: 9, minute: 5, second: 3))!
    }()

    func testFilenameFormat() {
        let name = RecordingStore.makeFilename(date: fixedDate)
        XCTAssert(name.hasPrefix("Bitnote_"), "prefix mismatch: \(name)")
        XCTAssert(name.hasSuffix(".m4a"), "suffix mismatch: \(name)")
        let inner = name.dropFirst("Bitnote_".count).dropLast(".m4a".count)
        XCTAssertEqual(inner.count, 19, "timestamp length mismatch: \(inner)")
        XCTAssertEqual(inner.filter { $0 == "-" }.count, 4)
        XCTAssertEqual(inner.filter { $0 == "_" }.count, 1)
    }

    func testManualNilTitleFallsBackToBitnote() {
        let name = RecordingStore.makeFilename(title: nil, date: fixedDate)
        XCTAssert(name.hasPrefix("Bitnote_"), "expected Bitnote_ prefix, got: \(name)")
        XCTAssert(name.hasSuffix(".m4a"))
    }

    func testEmptyTitleFallsBackToBitnote() {
        let name = RecordingStore.makeFilename(title: "", date: fixedDate)
        XCTAssert(name.hasPrefix("Bitnote_"), "empty title should fallback, got: \(name)")
    }

    func testWhitespaceTitleFallsBackToBitnote() {
        let name = RecordingStore.makeFilename(title: "   ", date: fixedDate)
        XCTAssert(name.hasPrefix("Bitnote_"), "whitespace title should fallback, got: \(name)")
    }

    func testAutoTitleProducesCorrectPrefix() {
        let name = RecordingStore.makeFilename(title: "Team Sync", date: fixedDate)
        XCTAssert(name.hasPrefix("Team Sync_"), "expected 'Team Sync_' prefix, got: \(name)")
        XCTAssert(name.hasSuffix(".m4a"))
    }

    func testSanitizeRemovesSlash() {
        XCTAssertEqual(RecordingStore.sanitizeFilename("a/b"), "ab")
    }

    func testSanitizeRemovesColon() {
        XCTAssertEqual(RecordingStore.sanitizeFilename("a:b"), "ab")
    }

    func testSanitizeRemovesControlChars() {
        XCTAssertEqual(RecordingStore.sanitizeFilename("a\u{0001}b"), "ab")
    }

    func testSanitizePreservesNormalTitle() {
        XCTAssertEqual(RecordingStore.sanitizeFilename("Team Sync Q1"), "Team Sync Q1")
    }

    func testSanitizeTrimsSurroundingWhitespace() {
        XCTAssertEqual(RecordingStore.sanitizeFilename("  Meeting  "), "Meeting")
    }

    func testIllegalTitleFallsBackAfterSanitize() {
        // title that becomes empty after sanitize → should fall back to Bitnote
        let name = RecordingStore.makeFilename(title: "/", date: fixedDate)
        XCTAssert(name.hasPrefix("Bitnote_"), "fully-illegal title should fallback, got: \(name)")
    }
}

final class RecordingStoreTests: XCTestCase {
    private func rec(_ name: String = "x") -> Recording {
        Recording(url: URL(fileURLWithPath: "/tmp/\(name).m4a"), date: Date(), fileSize: 0)
    }

    func testAddInsertsAtFront() {
        var store = RecordingStore()
        let a = rec("a")
        let b = rec("b")
        store.add(a)
        store.add(b)
        XCTAssertEqual(store.recordings.first?.id, b.id)
        XCTAssertEqual(store.recordings.last?.id, a.id)
    }

    func testCapAtMaxRecordings() {
        var store = RecordingStore(maxRecordings: 3)
        for i in 0..<5 { store.add(rec("r\(i)")) }
        XCTAssertEqual(store.recordings.count, 3)
    }

    func testCapKeepsNewest() {
        var store = RecordingStore(maxRecordings: 2)
        let a = rec("a"); let b = rec("b"); let c = rec("c")
        store.add(a); store.add(b); store.add(c)
        // c was added last → front; b second; a should be dropped
        XCTAssertEqual(store.recordings.map(\.id), [c.id, b.id])
    }

    func testDeleteById() {
        var store = RecordingStore()
        let a = rec("a"); let b = rec("b")
        store.add(a); store.add(b)
        store.delete(id: a.id)
        XCTAssertEqual(store.recordings.count, 1)
        XCTAssertEqual(store.recordings.first?.id, b.id)
    }

    func testDeleteNonexistentIsNoop() {
        var store = RecordingStore()
        store.add(rec("a"))
        store.delete(id: UUID())
        XCTAssertEqual(store.recordings.count, 1)
    }

    func testEncodeDecodeRoundtrip() throws {
        var store = RecordingStore()
        let r = rec("enc")
        store.add(r)
        let data = try store.encoded()
        let loaded = try RecordingStore.decoded(from: data)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, r.id)
        XCTAssertEqual(loaded.first?.url, r.url)
    }

    func testDecodeInvalidDataThrows() {
        XCTAssertThrowsError(try RecordingStore.decoded(from: Data("bad".utf8)))
    }

    func testDefaultMaxIs20() {
        let store = RecordingStore()
        XCTAssertEqual(store.maxRecordings, 20)
    }

    func testEmptyStoreEncodesDecodesEmpty() throws {
        let store = RecordingStore()
        let data = try store.encoded()
        let loaded = try RecordingStore.decoded(from: data)
        XCTAssertTrue(loaded.isEmpty)
    }

    func testAddExactlyAtMax() {
        var store = RecordingStore(maxRecordings: 2)
        store.add(rec("a")); store.add(rec("b"))
        XCTAssertEqual(store.recordings.count, 2)
    }
}
