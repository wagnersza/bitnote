import Foundation
import AppKit
import BitnoteCore

@MainActor
final class RecordingsManager: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var saveDirectory: URL

    private var store = RecordingStore()
    private let userDefaultsKey = "bitnote.recordings"

    init() {
        if let path = UserDefaults.standard.string(forKey: "bitnote.saveDirectoryPath") {
            saveDirectory = URL(fileURLWithPath: path)
        } else {
            saveDirectory = Self.defaultDirectory()
        }
        createDirectoryIfNeeded(saveDirectory)
        loadRecordings()
    }

    private static func defaultDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = recordingsFolderName(forBundleID: Bundle.main.bundleIdentifier)
        return docs.appendingPathComponent(folder)
    }

    private func createDirectoryIfNeeded(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func newRecordingURL(title: String? = nil) -> URL {
        let name = RecordingStore.makeFilename(title: title, date: Date())
        return saveDirectory.appendingPathComponent(name)
    }

    func addRecording(at url: URL) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? Int64 ?? 0
        let rec = Recording(url: url, date: Date(), fileSize: size)
        store.add(rec)
        recordings = store.recordings
        saveRecordings()
    }

    func delete(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.url)
        store.delete(id: recording.id)
        recordings = store.recordings
        saveRecordings()
    }

    func revealInFinder(_ recording: Recording) {
        NSWorkspace.shared.activateFileViewerSelecting([recording.url])
    }

    func shareToNotes(_ recording: Recording) {
        let services = NSSharingService.sharingServices(forItems: [recording.url as NSURL])
        if let notesService = services.first(where: { $0.title.localizedCaseInsensitiveContains("notes") }) {
            notesService.perform(withItems: [recording.url as NSURL])
        } else {
            revealInFinder(recording)
        }
    }

    func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose where Bitnote saves recordings"

        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: "bitnote.saveDirectoryPath")
            saveDirectory = url
            createDirectoryIfNeeded(url)
        }
    }

    private func saveRecordings() {
        if let data = try? store.encoded() {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadRecordings() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let saved = try? RecordingStore.decoded(from: data) else { return }
        let existing = saved.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        store = RecordingStore(recordings: existing)
        recordings = store.recordings
    }
}
