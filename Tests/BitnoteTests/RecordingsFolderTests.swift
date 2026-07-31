import XCTest
@testable import BitnoteCore

final class RecordingsFolderTests: XCTestCase {
    func testDevBundleIDMapsToDevFolder() {
        XCTAssertEqual(recordingsFolderName(forBundleID: "com.bitnote.app.dev"), "Bitnote-dev")
    }

    func testProductionBundleIDMapsToProductionFolder() {
        XCTAssertEqual(recordingsFolderName(forBundleID: "com.bitnote.app"), "Bitnote")
    }

    func testUnrelatedBundleIDMapsToProductionFolder() {
        XCTAssertEqual(recordingsFolderName(forBundleID: "com.example.other"), "Bitnote")
    }

    func testMissingBundleIDMapsToProductionFolder() {
        XCTAssertEqual(recordingsFolderName(forBundleID: nil), "Bitnote")
    }
}
