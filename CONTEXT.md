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
The user ending a recording from the menu. A Manual stop is always available, at any moment, including while a Keep-recording prompt is on screen. A **limit stop** is the one other way a recording ends.
_Avoid_: Auto-stop

**Recording Limit**:
The absolute time at which Bitnote asks the user whether a recording must continue. Every recording has one. A recording with no Meeting Event gets 30 minutes, then 30 minutes again, then 15 minutes for every later round. Bitnote sets the next limit each time the user answers, so a recording can never run without one.
_Avoid_: Timeout, max duration

**Keep-recording prompt**:
The question Bitnote asks when a Recording Limit arrives, on two surfaces at once: a system notification carrying a **Keep recording** action, and a row in the Bitnote menu with a live countdown. The user clicks **Keep recording** on either one and the recording continues.
_Avoid_: Warning, alert

**Grace period**:
The 60 seconds the user has to answer a Keep-recording prompt, measured from the moment the prompt appeared, never from the limit. Nobody answers, and Bitnote does a limit stop: it stops the recording and saves the file, exactly as a Manual stop does. Because the count starts at the prompt, a computer that woke from a long sleep asks the user and gives the full minute instead of stopping at once.
_Avoid_: Timeout window, countdown

**Poll**:
The ~60s timer sweep that queries EventKit for Meeting Events about to start.

**Monitored Calendars**:
The subset of macOS Calendars a Poll queries for Meeting Events. An empty selection means *all* calendars (no narrowing) — this is the default.
_Avoid_: Watched calendars, selected calendars

**Input Source**:
The microphone device the mic path records from. Either **System Default** (a sentinel that resolves to the macOS current default input at record start) or a pinned device. If a pinned device is unavailable when recording starts, Bitnote falls back to System Default rather than failing — the recording is never lost.
_Avoid_: Mic, input device, capture source

Note: system audio is always captured whole-system; only the Input Source is configurable. Per-app system-audio scope is deliberately out of scope.
