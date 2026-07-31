# Reach Google Calendar / Zoom through EventKit, not their own APIs

The feature asked for "connect to Google Calendar and Zoom" to auto-start recording when a meeting begins. We decided Bitnote reads the **native macOS Calendar via EventKit** and detects a video-call link on accepted events, rather than integrating Google Calendar API (OAuth) or Zoom (OAuth + webhooks) directly.

Why: the user's Google account is already in macOS Calendar, so EventKit gives us the events with one local permission prompt — no Google Cloud project, no OAuth consent screen, no embedded client secret, no public webhook server, and the app stays sandboxed. The trade-off: Bitnote only sees meetings surfaced in macOS Calendar (account must be added there once), and knows the *scheduled* start, not Zoom's real call state — acceptable because stop is manual and start is a cancellable notification, not a silent action.

## Considered Options

- **Zoom OAuth + webhooks** — precise real start/stop, but needs a public HTTPS endpoint, Zoom Marketplace app review, and only covers the linked account. Rejected: heavy for a local menu-bar app.
- **Google Calendar API (OAuth)** — works without macOS Calendar, but owns an OAuth app + token refresh + network entitlement. Rejected: EventKit already has the data.
