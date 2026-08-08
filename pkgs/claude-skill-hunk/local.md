
---

# This machine

Local setup, appended by `pkgs/claude-skill-hunk`. Everything between here and
the header at the top is upstream's, verbatim.

## How the user drives it

Under herdr (prefix is `ctrl+b`):

- `prefix+d` — fzf picker: working tree (live) / staged / last commit / pick
  commit / pick range / branch vs upstream / stash. Every row **re-points an
  already-open hunk pane**, so this is also how they change scope.
- `prefix+shift+s` — pushes the notes they wrote into your input, then deletes
  them from the pane.
- In hunk: `c` starts a note, **`ctrl+s` saves it** (Enter only inserts a
  newline). Panes open with `--watch`, so they follow your edits.

Their notes do **not** arrive on their own — they land in your input only when
the user presses `prefix+shift+s`. Never tell them to quit hunk to "flush"
anything.

## The user/agent note split

Verified against a live session:

| | user's note | yours |
|---|---|---|
| written by | `c` then `ctrl+s` in the TUI | `session comment add` |
| `source` | `user` | `agent` — **even with `--author` set** |
| `noteId` | `user:…` | `mcp:…` |

So `--type user` never echoes your own notes back at you, and you can annotate a
session the user is reviewing without polluting what they wrote.

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
