# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues in `wagnersza/bitnote`. Use the `gh` CLI for all operations. Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body-file <file>`. Use `--body-file` for multi-line bodies; `gh issue create` prints the new issue URL (it does not accept `--json`).
- **Read an issue**: `gh issue view <number> --comments`
- **List issues**: `gh issue list --state open --json number,title,body,labels` with `--label` / `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number>`

## Work-state labels

These four are **mutually exclusive** — swap one for the next, never stack them:

| Label | Meaning |
|-------|---------|
| `ready-for-agent` | Startable now. An orchestrator worker may claim it. |
| `in-progress` | A worker owns it. |
| `to-review` | Work is done and a PR is open. Waits for a human to merge. |
| `done` | The PR is merged to `main`. |

`user-story` is **orthogonal**. It marks a full spec (from `/to-spec`) whose acceptance criteria live in its user stories. It rides alongside a work-state label and never swaps with one.

A `user-story` parent is worked through its **children** — the `/to-tickets` issues that carry a `## Parent #N` body line — never directly. Therefore a parent does **not** carry `ready-for-agent`, which keeps it out of the ready queue. The parent moves as a function of its children: `in-progress` when the first child starts, `done` when the last child closes.

## Blocking

A ticket declares its blockers in a `## Blocked by` section at the end of its body:

```markdown
## Blocked by

- #21 (shared file: the popover view — contention, not logical)
```

Or `- None — can start immediately.` when nothing gates it.

A ticket is **unblocked** when every issue named in that section is closed. Two kinds of edge appear there:

- **Dependency edge** — the ticket needs the blocker's behaviour to exist first.
- **Contention edge** — no logical dependency, but both tickets write the same file, so they are serialized to keep the merge clean. Record the reason so the order stays legible.

## Project board

The labels are the source of truth. Optionally mirror issues to a GitHub Project board; a brand-new issue is not added automatically — add it, then set its status:

```bash
gh project item-add <board-number> --owner <owner> --url "$(gh issue view <N> --json url -q .url)"
```

Status field values map to the work-state labels: `ready-for-agent` → Ready, `in-progress` → In progress, `to-review` → In review, `done` → Done.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

GitHub shares one number space across issues and PRs, so a bare `#42` may be either — resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.
