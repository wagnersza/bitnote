# Orchestrator config

How the orchestrator runs workers in **this** repo. Edit freely; re-run
`/orchestrator-setup` only to start over.

```yaml
# --- worker triple ---
tool:     orca            # orca | cmux | herdr  -> references/tools/<tool>.md
harness:  claude          # claude | codex | pi | copilot | cursor -> references/harnesses/<h>.md
model:    sonnet-5        # a model id from references/models.md
yolo:     on              # required; the harness ref supplies the actual flag

# --- adversarial review (optional) ---
review:
  enabled: false          # on -> spawn a cross-vendor reviewer at the review state
  model:   gpt-5.6-terra  # MUST be a different vendor than `model` above
  rounds:  3              # max fix<->review cycles before handing to human review

# --- repo + tracker ---
repo:     ~/git/bitnote               # the main checkout; stays on `main`
tracker:  # read from docs/agents/issue-tracker.md; do NOT redefine labels here

# --- project recipe (the completion contract's project-specific parts) ---
setup_cmd:  ""            # none — Swift package, no install step; the worker runs `swift build`
run_recipe: "bash build_app.sh"   # builds + launches Bitnote-dev.app (never the production app)
ports:      ""            # none — menu-bar app, no servers
db_gate:    ""            # none — no database
evidence:   "real-run proof + full test suite passing"
promote:    "bash install.sh"     # user-confirmed; only when a user-story parent closes
```

## Notes

- **tool / harness / model** pick the worker triple. The skill reads the matching
  reference files for concrete commands; nothing tool-specific is hardcoded in the
  skill body.
- **yolo** is always required for a worker (nobody approves its prompts). For the
  `claude` harness the flag is `--dangerously-skip-permissions`, so a worker
  launches as `claude --model sonnet --dangerously-skip-permissions`.
- **review** is off, so you are the reviewer: a worker stops at `to-review` with an
  open PR and you merge it. You can still ask for a one-off cross-vendor review
  ("review #N adversarially") without turning it on here. If you do enable it,
  `review.model` must be an **openai** model, because `model` above is anthropic.
- **Work-state labels** (`ready-for-agent`, `in-progress`, `to-review`, `done`) and
  the `user-story` marker come from `docs/agents/issue-tracker.md`, not this file —
  single source of truth.

## Project specifics

This is a **macOS menu-bar app** built as a Swift package. There is no web server,
no database, and no HTTP surface, so `ports` and `db_gate` are deliberately blank.

**Build and test:**

```bash
swift build
bash build_app.sh    # assembles + ad-hoc signs Bitnote-dev.app, then launches it
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

`swift test` **requires the `DEVELOPER_DIR` prefix** — it needs Xcode, and fails
without it. A worker that reports "tests can't run" has probably omitted it.

**Coverage gate:** every file in `Sources/BitnoteCore/` must keep **≥90% line
coverage**. That target is the repo's testing seam — pure, synchronous,
framework-free decision functions. The OS-facing wiring in `Sources/Bitnote/`
(EventKit, AVAudioEngine, ScreenCaptureKit, SwiftUI) is not unit-tested by
convention. A new feature puts its *decision* logic in `BitnoteCore` with tests and
leaves the OS glue untested.

## Dev app vs production — every ticket

A worker **always** builds and runs **`Bitnote-dev.app`**, never the production app.
`build_app.sh` produces it: bundle id `com.bitnote.app.dev`, name `Bitnote-dev`,
recordings defaulting to `~/Documents/Bitnote-dev`. macOS keys `UserDefaults` and the
mic/screen/calendar grants on the **bundle id**, so the dev id is what keeps a
worker's test run out of the user's real recordings list, save directory, Monitored
Calendars selection, and permission grants. Both apps run side by side — two menu-bar
icons is the expected state, not a bug.

Two consequences a worker should expect and not chase: the dev app asks for its own
permissions on first launch, and ad-hoc signing means macOS may re-ask after a
rebuild.

**Promotion is a separate, user-confirmed step.** `install.sh` rebuilds at **release**
with the **production** identity (`com.bitnote.app`, `Bitnote`) and installs to
`/Applications/Bitnote.app`. The dev bundle is **never** renamed or moved there — that
would carry the dev bundle id inside an app named "Bitnote" (empty recordings list,
permissions re-prompted) and would ship a debug binary as production.

The orchestrator offers the promotion when a **`user-story` parent closes** — i.e. its
last child merged — and runs it only after the user agrees. It replaces the app the
user is currently running, so it follows the same rule as merge: human decision. A
worker never promotes, and never promotes per-ticket.

## Evidence bar

`evidence: real-run proof + full test suite passing`. Build output alone is **never**
enough — the evidence must let a reviewer confirm the ticket's acceptance criteria
against a real run. Always include the test suite, then add what fits the ticket:

| Ticket type | Required proof |
|-------------|----------------|
| any | `DEVELOPER_DIR=... swift test` passing, plus `swift build` + `bash build_app.sh` assembling `Bitnote-dev.app` |
| UI | a screenshot written to `~/Documents/Bitnote-evidence/<N>/`, its **absolute path** named in the review note |
| recording / audio | an `ls -la` of the produced `.m4a` with its size, plus what was recorded (a 1-minute file ≈ 240KB at 32kbps) |

Evidence artifacts live **outside the repo**, under `~/Documents/Bitnote-evidence/<N>/`
(one directory per work item, created by the worker if absent). A worker's worktree is
removed at teardown, so anything written inside it — gitignored or not — is destroyed
before the owner can inspect it; writing outside the worktree is what keeps the proof
alive after the worktree is gone.

**Report shape:** one comment on the work item, containing a checked-off list of the
acceptance criteria the worker satisfied, and for each piece of proof, that artifact's
absolute path on its own line. No inline images, no embedded image markup, and no
repo-relative image paths — the comment is the claim, the path is how the owner checks
it. The existing four-heading review note (What to review / Main changes / How to test /
Evidence) is unchanged; only what sits under Evidence follows this shape.

## Codebase memory

One index, the main repo: **`bitnote-main`**. Workers **query**
it and must **not** run `index_repository` on their own worktree — codebase-memory
keys projects by `root_path`, so a worktree index duplicates main and orphans when
the worktree is torn down. The orchestrator refreshes the single main index after a
merge lands, and prunes any stray worktree index it finds.

## Merge is human

The orchestrator never auto-merges. A worker's last act is flipping the ticket to
`to-review` with an open PR; advancing to `done` happens only after a human merges
to `main`. After a merge, pull `main` in the main checkout **before** tearing down
the worktree — the codebase-memory refresh indexes local `main`, so an unpulled
merge would index stale code.

Installing to production is human too, for the same reason: once the last child of a
`user-story` parent is merged and the parent closes, offer `install.sh` and wait for
the user's yes. See [Dev app vs production](#dev-app-vs-production--every-ticket).
