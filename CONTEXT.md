# Bitnote

A macOS menu-bar app that records system audio + microphone into one small `.m4a`. It can auto-start recording when a calendar meeting begins.

## Language

**Meeting Event**:
A macOS Calendar event, read via EventKit, that Bitnote considers recordable: the user **accepted** it and it carries a video-call link.
_Avoid_: Appointment, calendar entry

**Video-call link**:
A join URL for Zoom, Google Meet, or Teams found in an event's location, URL, or notes. Its presence is what makes an event a Meeting Event.
_Avoid_: Zoom link (it's not Zoom-only), invite link

**Auto-start**:
Bitnote posting a start notification and beginning recording on its own when a Meeting Event's start time arrives — after a short cancellable countdown.
_Avoid_: Auto-record (recording is the manual/existing action; auto-start is the trigger)

**Manual stop**:
The user ending a recording from the menu. Bitnote never stops a recording on its own — there is no auto-stop.
_Avoid_: Auto-stop

**Poll**:
The ~60s timer sweep that queries EventKit for Meeting Events about to start.

**Monitored Calendars**:
The subset of macOS Calendars a Poll queries for Meeting Events. An empty selection means *all* calendars (no narrowing) — this is the default.
_Avoid_: Watched calendars, selected calendars

**Input Source**:
The microphone device the mic path records from. Either **System Default** (a sentinel that resolves to the macOS current default input at record start) or a pinned device. If a pinned device is unavailable when recording starts, Bitnote falls back to System Default rather than failing — the recording is never lost.
_Avoid_: Mic, input device, capture source

Note: system audio is always captured whole-system; only the Input Source is configurable. Per-app system-audio scope is deliberately out of scope.
