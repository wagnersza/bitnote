import SwiftUI
import BitnoteCore

struct MenuBarView: View {
    @EnvironmentObject var audioEngine: AudioEngineManager
    @EnvironmentObject var recordings: RecordingsManager
    @EnvironmentObject var permissions: PermissionsManager
    @EnvironmentObject var meetingWatcher: MeetingWatcher
    @EnvironmentObject var inputDevices: InputDeviceManager

    @State private var hoveredRecordingID: UUID?
    @State private var recordingError: String? = nil
    @AppStorage("bitnote.calendarPickerExpanded") private var calendarPickerExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            recordingControls
            if !permissions.allPermissionsGranted {
                Divider()
                permissionWarnings
            }
            Divider()
            inputSourceRow
            Divider()
            calendarPickerRow
            Divider()
            todaySection
            Divider()
            saveDestinationRow
            Divider()
            recordingsList
            Divider()
            footer
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Bitnote")
                .font(.headline)
            Spacer()
            if permissions.airPodsDevice != nil {
                Label("AirPods", systemImage: "airpodspro")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        VStack(spacing: 6) {
            if audioEngine.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(audioEngine.blinkState ? 1 : 0.2)
                    Text(audioEngine.elapsedTimeString)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                    if let title = meetingWatcher.autoRecordingTitle {
                        Text("· \(title)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            Button(action: toggleRecording) {
                HStack {
                    Image(systemName: audioEngine.isRecording ? "stop.circle.fill" : "record.circle")
                    Text(audioEngine.isRecording ? "Stop Recording" : "Start Recording")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(audioEngine.isRecording ? Color.red : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(!permissions.allPermissionsGranted && !audioEngine.isRecording)
            .padding(.horizontal, 12)

            if let error = recordingError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button("Open Settings") {
                        permissions.requestScreenCapturePermission()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 12)
            }
            Spacer().frame(height: 8)
        }
    }

    private func toggleRecording() {
        if audioEngine.isRecording {
            Task {
                await meetingWatcher.stopAndSaveRecording()
            }
        } else {
            inputDevices.refreshDevices()
            let resolved = inputDevices.resolveForRecording()
            let deviceUID = resolved == .systemDefault ? nil : resolved.uid
            let url = recordings.newRecordingURL()
            Task {
                do {
                    try await audioEngine.startRecording(to: url, deviceUID: deviceUID)
                    recordingError = nil
                } catch {
                    recordingError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Permissions

    private var permissionWarnings: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !permissions.hasMicPermission {
                permissionRow(
                    icon: "mic.slash.fill",
                    message: "Microphone access required",
                    action: { permissions.requestMicPermission() }
                )
            }
            if !permissions.hasScreenCapturePermission {
                permissionRow(
                    icon: "display.trianglebadge.exclamationmark",
                    message: "Screen recording required",
                    action: { permissions.requestScreenCapturePermission() }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func permissionRow(icon: String, message: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Grant") { action() }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
        }
    }

    // MARK: - Input Source

    private var inputSourceRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "mic")
                    .foregroundColor(.secondary)
                Picker("", selection: Binding(
                    get: { inputDevices.selectedUID ?? InputDevice.systemDefault.uid },
                    set: { inputDevices.selectedUID = $0 == InputDevice.systemDefault.uid ? nil : $0 }
                )) {
                    Text(InputDevice.systemDefault.name).tag(InputDevice.systemDefault.uid)
                    if !inputDevices.availableDevices.isEmpty {
                        Divider()
                        ForEach(inputDevices.availableDevices) { device in
                            Text(device.name).tag(device.uid)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.caption)
            }
            if let note = inputDevices.fallbackNote {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Calendar Picker

    private var calendarPlainInfos: [CalendarInfo] {
        meetingWatcher.availableCalendars.map {
            CalendarInfo(id: $0.calendarIdentifier, title: $0.title, accountName: $0.source.title)
        }
    }

    private var effectiveSelectedCount: Int {
        let availableIDs = Set(calendarPlainInfos.map(\.id))
        let filterResult = calendarFilter(selectedIDs: meetingWatcher.selectedCalendarIDs, availableIDs: availableIDs)
        return filterResult?.count ?? 0
    }

    private var calendarPickerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { calendarPickerExpanded.toggle() }) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text("Monitor calendars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(calendarSelectionSummary(selectedCount: effectiveSelectedCount, totalCount: calendarPlainInfos.count))
                        .font(.caption2)
                        .foregroundColor(effectiveSelectedCount > 0 ? .accentColor : .secondary)
                    Image(systemName: calendarPickerExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Monitor calendars, \(calendarSelectionSummary(selectedCount: effectiveSelectedCount, totalCount: calendarPlainInfos.count))")
            .accessibilityHint(calendarPickerExpanded ? "Collapse" : "Expand")

            if calendarPickerExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(groupCalendarsByAccount(calendarPlainInfos)) { group in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.accountName)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(group.calendars) { cal in
                                    calendarRow(cal)
                                }
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func calendarRow(_ cal: CalendarInfo) -> some View {
        let isSelected = meetingWatcher.selectedCalendarIDs.contains(cal.id)
        return Button(action: {
            if isSelected {
                meetingWatcher.selectedCalendarIDs.remove(cal.id)
            } else {
                meetingWatcher.selectedCalendarIDs.insert(cal.id)
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.caption)
                Text(cal.title)
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            switch meetingWatcher.todayState {
            case .meetings(let rows):
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(rows) { row in
                            todayRow(row)
                        }
                    }
                }
                .frame(height: min(CGFloat(rows.count) * 22, 132))
            case .noMeetingsToday:
                Text("No more meetings today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .noCalendarAccess:
                Text("Grant calendar access to see today's meetings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func todayRow(_ row: TodayMeetingRow) -> some View {
        HStack(spacing: 6) {
            if row.isAutoRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
            }
            Text(row.startTime)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            Text(row.title)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer()
        }
    }

    // MARK: - Save Destination

    private var saveDestinationRow: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundColor(.secondary)
            Text(recordings.saveDirectory.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Change") { recordings.chooseSaveDirectory() }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Recordings List

    private var recordingsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if recordings.recordings.isEmpty {
                Text("No recordings yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(recordings.recordings) { recording in
                    recordingRow(recording)
                    if recording.id != recordings.recordings.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
    }

    private func recordingRow(_ recording: Recording) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(recording.formattedDate)
                    Text("·")
                    Text(recording.formattedSize)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            Spacer()
            if hoveredRecordingID == recording.id {
                HStack(spacing: 4) {
                    Button(action: { recordings.shareToNotes(recording) }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Share to Notes")
                    Button(action: { recordings.revealInFinder(recording) }) {
                        Image(systemName: "folder")
                    }
                    .help("Reveal in Finder")
                    Button(action: { recordings.delete(recording) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .help("Delete")
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered in
            hoveredRecordingID = isHovered ? recording.id : nil
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit Bitnote") {
                NSApp.terminate(nil)
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
