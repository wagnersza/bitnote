# Bitnote

A lightweight macOS menu bar app that records system audio and microphone input into a single AAC file.

## Features

- Captures system audio via ScreenCaptureKit
- Captures microphone via AVAudioEngine
- Mixes both sources using ring buffers and timer-driven mixing with soft clipping
- Outputs AAC 24kHz mono at ~32kbps (~240KB/min)
- Lives in the menu bar with a minimal UI

## Requirements

- macOS 14.0+
- Screen recording permission
- Microphone permission

## Build

```bash
swift build
bash build_app.sh
```

`build_app.sh` builds a debug binary, assembles it as **`Bitnote-dev.app`** (bundle id
`com.bitnote.app.dev`, name Bitnote-dev), signs it, and launches it. macOS keys
`UserDefaults` and the mic/screen/calendar permission grants on the bundle id, so the dev
app has its own settings, permissions, and recordings list — separate from the production
app. It defaults recordings to `~/Documents/Bitnote-dev`; production keeps
`~/Documents/Bitnote`. Both apps can run at the same time.

## Production install

```bash
bash install.sh
```

Builds a **release** binary with the production identity (`com.bitnote.app`, Bitnote),
signs it, and installs it to `/Applications/Bitnote.app`. It prints what it will replace
and asks for confirmation; pass `-y` (or `--yes`) to skip the prompt for unattended use.
It never touches `Bitnote-dev.app` — the dev and production identities are always built
and signed separately.

## DMG

```bash
bash create_dmg.sh
```

Builds a release `Bitnote.app` with the production identity, signs it, and packages it into
`Bitnote.dmg` for distribution. Open the DMG and drag Bitnote to Applications to install.

## Usage

1. Launch the app — it appears in the menu bar
2. Click the menu bar icon to start/stop recording
3. Recordings are saved as `.m4a` files

## Running Tests and Coverage

`swift test` requires Xcode. Run with:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --enable-code-coverage
```

To regenerate the coverage report after tests pass:

```bash
xcrun llvm-cov report \
  .build/arm64-apple-macosx/debug/BitnotePackageTests.xctest/Contents/MacOS/BitnotePackageTests \
  -instr-profile=.build/arm64-apple-macosx/debug/codecov/default.profdata \
  --ignore-filename-regex=".build|Tests"
```

Every `Sources/BitnoteCore/*.swift` file must maintain ≥90% line coverage.

## Evidence convention

`docs/review/` is gitignored. Ticket evidence (screenshots, recordings) is real-run
proof written outside the repo, never a committed screenshot — a worktree is removed
after a ticket merges, so anything checked in would be a leak of whatever the screen
happened to show at the time, not a permanent artifact worth keeping in git history.
