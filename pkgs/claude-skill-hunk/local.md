
---

# This machine

Appended by `pkgs/claude-skill-hunk`. Everything above is upstream's; this
section is local setup upstream can't know about.

## hunk is the DEFAULT reviewer here

| Situation | Tool |
|-----------|------|
| Any local diff — your work, the user's, a past commit | **hunk** (this skill) |
| Comments must reach a GitHub PR / GitLab MR | **tuicr** — see the `tuicr` skill |

tuicr is used outside herdr, for already-pushed PRs. It is not the general
reviewer: on a local diff it cannot send comments anywhere, and it does not
auto-reload. Do not route local work to it.

## How the user drives it

Under herdr (prefix is `ctrl+b`):

- `prefix+d` — fzf picker: working tree (live) / staged / last commit / pick
  commit / pick range / branch vs upstream / stash. Every row **re-points an
  already-open hunk pane**, so this is also how they change scope.
- `prefix+shift+s` — pushes the notes they wrote into your input, then deletes
  them from the pane.
- In hunk: `c` starts a note, **`ctrl+s` saves it** (Enter only inserts a
  newline). Panes open with `--watch`, so they follow your edits.

If no session is live, ask them to press `prefix+d` — do not launch the TUI.

## --type user vs --type agent

Verified against a live session, and easy to get wrong:

| | user's note | yours |
|---|---|---|
| written by | `c` then `ctrl+s` in the TUI | `session comment add` |
| `source` | `user` | `agent` — **even with `--author` set** |
| `noteId` | `user:…` | `mcp:…` |

Always read with `--type user`. A bare `comment list` shows the legacy
live-agent view, and treating your own notes as the user's is the failure mode
this table exists to prevent.

Their notes do **not** arrive on their own — they land in your input only when
the user presses `prefix+shift+s`. Never tell them to quit hunk to "flush"
anything.

## On a git-spice stack

The base is not main, and hunk will not compute one — the picker's "Branch vs
upstream" row resolves the *upstream*, not the stack base. Use `gs-review`,
which reads the base git-spice tracks (`gs ls --json` → `.down.name`):

```bash
gs-review hunk       # this branch's own changes only
gs-review            # same, in tuicr
```

Or re-point their open pane yourself:

```bash
hunk session reload --repo . -- diff "$(gs ls --json |
  jq -r 'select(.current == true) | .down.name')...HEAD"
```

Say what you changed it to — the pane gives no other signal.
