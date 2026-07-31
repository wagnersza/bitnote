# Bitnote - Implementation Plan

## Context

Build a macOS menu bar app ("Bitnote") that records system audio (meeting participants) and microphone (AirPods) into a single, tiny `.m4a` file. Uses ScreenCaptureKit for system audio capture (no virtual drivers needed) and AVAudioEngine for mic input. Output is AAC at 24kHz mono 32kbps — roughly 8-10x smaller than standard recordings, matching Apple Notes' file size efficiency. The `~/git/bitnote` directory is empty; this is a greenfield project.

## Project Structure

```
bitnote/
├── Package.swift
├── Info.plist
├── Bitnote.entitlements
└── Sources/Bitnote/
    ├── App.swift                  # @main, MenuBarExtra scene
    ├── AudioEngineManager.swift   # Core: SCStream + AVAudioEngine + mixing + AVAssetWriter
    ├── MenuBarView.swift          # Menu bar popover UI
    ├── RecordingsManager.swift    # File management, recent recordings, share to Notes
    └── PermissionsManager.swift   # Mic + screen capture permissions, AirPods detection
```

## Implementation Steps

### 1. Create `Package.swift`
- Swift 5.9+, macOS 13+ platform target
- Single executable target `Bitnote`
- `-parse-as-library` swift setting (required for `@main` in SPM)
- Link frameworks: ScreenCaptureKit, AVFoundation, CoreMedia, CoreAudio, AppKit

### 2. Create `Info.plist`
- `LSUIElement = true` (no Dock icon, menu bar only)
- `NSMicrophoneUsageDescription` and `NSScreenCaptureUsageDescription` (mandatory for permission dialogs)
- Bundle identifier: `com.bitnote.app`

### 3. Create `Bitnote.entitlements`
- App Sandbox enabled
- Audio input entitlement
- User-selected file read/write (for save destination persistence)

### 4. Create `PermissionsManager.swift`
- `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()` for screen capture
- `AVCaptureDevice.requestAccess(for: .audio)` for microphone
- AirPods detection via `AVCaptureDevice.DiscoverySession` (match device name containing "AirPods")
- `@MainActor ObservableObject` with published permission states

### 5. Create `AudioEngineManager.swift` (most complex)
- **System audio**: `SCStream` with `capturesAudio = true`, video disabled (2x2 minimal), `excludesCurrentProcessAudio = true`
- **Mic**: `AVAudioEngine.inputNode.installTap` for microphone buffer capture
- **Format conversion**: Both streams converted to 24kHz mono Float32 via `AVAudioConverter`
- **Serialization**: Dedicated `DispatchQueue` (`mixQueue`) serializes writes from both sources
- **Output**: `AVAssetWriter` with settings: `kAudioFormatMPEG4AAC`, 24kHz, mono, 32kbps, variable constrained bitrate
- **Timestamps**: Monotonic `presentationSampleOffset` counter for correct CMTime progression
- **CMSampleBuffer conversion**: `AVAudioPCMBuffer` → `CMBlockBuffer` → `CMSampleBuffer` for AVAssetWriterInput
- Published state: `isRecording`, `elapsedTimeString`, `blinkState` for UI

### 6. Create `RecordingsManager.swift`
- Default save directory: `~/Documents/Bitnote/`
- `NSOpenPanel` for custom save destination selection
- Security-scoped bookmarks for sandbox persistence across launches
- Recent recordings list (max 20, persisted in UserDefaults as JSON)
- Share to Apple Notes via `NSSharingService` (fallback: reveal in Finder)
- Delete and reveal-in-Finder actions

### 7. Create `MenuBarView.swift`
- Header with app name and AirPods connection indicator
- Start/Stop recording button (red, prominent)
- Recording indicator: blinking red dot + elapsed time (monospaced)
- Permission warnings with "Grant" buttons when access is missing
- Save destination display with "Change" button
- Recent recordings list with hover actions (share to Notes, reveal, delete)
- Quit button in footer

### 8. Create `App.swift`
- `@main` SwiftUI App with `MenuBarExtra` scene (`.menuBarExtraStyle(.window)`)
- Menu bar icon: `record.circle` / `record.circle.fill` (red when recording)
- `@StateObject` instances of all three managers, injected as `environmentObject`

## Key Technical Decisions

| Aspect | Choice | Why |
|--------|--------|-----|
| Audio mixing | Interleaved writes on serial queue | Simple & correct; avoids ring buffer complexity |
| Output codec | AAC 24kHz mono 32kbps | Matches Apple Notes; ~240KB per minute |
| Project format | Swift Package (no .xcodeproj) | Clean, opens in Xcode via `open Package.swift` |
| UI | MenuBarExtra with `.window` style | Native macOS 13+ popover, full SwiftUI layout |
| SCStream format | Lazy converter from first buffer | System audio format varies by hardware |

## Verification

1. `swift build` — confirm project compiles with no errors
2. Open `Package.swift` in Xcode, run the app
3. Grant microphone and screen recording permissions when prompted
4. Play audio (e.g., YouTube in browser), click Start Recording
5. Speak into AirPods mic while audio plays
6. Click Stop Recording — verify `.m4a` file is created in save destination
7. Check file size: a 1-minute recording should be ~240KB (32kbps * 60s / 8)
8. Play back the file — both system audio and mic audio should be audible
9. Test "Share to Apple Notes" and "Reveal in Finder" actions
10. Verify menu bar icon turns red during recording and reverts when stopped
