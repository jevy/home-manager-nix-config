---
name: tuicr
description: Use when review comments must reach a GitHub PR or GitLab MR, when the user asks to review a pull request together in the terminal, or when reading back comments a user left in a tuicr session. Also use when choosing between tuicr, reviewr, and hunk inside a herdr workspace.
---

# tuicr

tuicr is a terminal review TUI whose comments can be submitted to a forge. The
TUI belongs to the user; `tuicr review` is the agent's interface to it.

## Pick the reviewer first

This machine has three reviewers. Reaching for tuicr by default is the most
common mistake — it is the *forge* reviewer, not the general one.

| Situation | Tool | Why |
|-----------|------|-----|
| Open PR/MR, comments must reach the forge | **tuicr** | Only reviewer that submits to GitHub/GitLab |
| A local diff you just wrote, comments come back to you | **reviewr** (herdr plugin) | Works with no PR; its `s` key sends comments to the agent |
| User wants a quick look while you keep working | **hunk** (`hunk diff --watch`) | Viewer only, no comment channel |

**If there is no PR, tuicr is usually the wrong answer.** Local agent-authored
diffs go to reviewr: tell the user to press `prefix+d` (`ctrl+b` then `d`) to
toggle the reviewr pane, then `u` (uncommitted) / `b` (branch) / `t` (last turn)
to scope, `c` to comment, `s` to send.

**reviewr comments never appear in tuicr.** They are typed into your input and
arrive as an ordinary user message. Do not run `tuicr review comments` looking
for them — you will get an empty array and conclude something broke.

tuicr on a *local* diff (`tuicr -w`) is a valid fallback when the user
specifically wants tuicr's UI, and that session *is* readable via the CLI below.

## Sessions are the interface

```bash
tuicr review list --repo /path/to/repo   # checkout, plus PR sessions for its origin
tuicr review list --repo owner/repo      # or a PR/repo URL
tuicr review list --all                  # every session, when the repo is unknown
```

Returns a JSON array. Fields that matter: `slug`, `kind` (`local` / `pr`),
`comment_count`, `active`.

**Never construct a slug.** They look like
`sesstest@main/staged-and-unstaged/822c797` for local sessions and
`gh:owner/repo/pr/N` for PRs. A guessed slug fails with `session ... was not
found`. Always `list` first and read the slug out.

`--repo` accepts a PR URL directly, which is the cleanest selector for PR work:

```bash
tuicr review list --repo https://github.com/owner/repo/pull/412
```

### What `active` and an empty result actually mean

Verified behavior — do not reason about this from first principles:

- A session is written **as soon as tuicr opens**, with `comment_count: 0`. It
  does *not* require the user to comment or to quit.
- `active: true` means the TUI is running right now. `active: false` means the
  session is persisted but tuicr is closed. Both are readable.
- So an empty `comments` array means **the user hasn't written comments yet** —
  it does not mean they need to quit tuicr first. Do not tell them to quit.
- An empty `list` means tuicr was never opened for that selector. Check the
  selector before concluding anything.

## Opening tuicr

Prefer letting the user open it; you mostly need to read the result.

**PR review under herdr** — the wrapper does not support PR mode, so use pickr:
print the PR URL on its own line and have the user `Ctrl+click` it, then press
`t` in the chooser (tuicr is the default, so Enter works too). Equivalent manual
command for the user:

```bash
tuicr pr https://github.com/owner/repo/pull/412
```

**Local session, scripted** — wrappers ship in this skill directory:

| Environment | Wrapper |
|-------------|---------|
| `$HERDR_ENV` is `1` | `<skill-dir>/tuicr-wrapper-herdr.sh /path/to/repo` |
| `$TMUX` is set | `<skill-dir>/tuicr-wrapper.sh /path/to/repo` |
| `$ZELLIJ` is set | `<skill-dir>/tuicr-wrapper-zellij.sh /path/to/repo` |
| none | Ask the user to run `tuicr` themselves, then `list` |

The wrappers run bare `tuicr` (a local working-tree session) and **block until
the TUI exits**, so use a long timeout (~10 min) and expect to read comments
afterwards rather than during. The herdr wrapper needs `jq` and refuses to run
unless `HERDR_ENV=1`.

tuicr supports git and Jujutsu. Do not pre-check with `git rev-parse` or refuse
because a jj workspace has no `.git` — run the wrapper and let it validate.

## Read comments

```bash
tuicr review comments --repo /path/to/repo --session <slug>
```

JSON per comment: `id`, `location`, `path`, `start_line`, `end_line`, `side`,
`comment_type`, `lifecycle_state`, `content`.

Act on `comment_type`: `issue` blocks and gets fixed first; `suggestion` gets
implemented or an explicit reason why not; `note` gets answered; `praise` needs
nothing.

tuicr does **not** push to you and does **not** auto-reload its own diff (the
user presses `:e` to pick up your new edits). Read on demand: when the user says
comments are ready, or after the TUI exits. If you are explicitly waiting, poll
about every 30s and diff the `id` set. Re-read once more before claiming you
addressed everything — the user may have added comments while you worked.

## Add comments

Only for agent-authored review the user asked for. Never write comments into a
session the user is using to review *you*, and never impersonate the user.
Always pass `--username` so your comments are visually distinct.

```bash
tuicr review add --repo /path/to/repo --session <slug> \
  --target-file src/main.rs --line 42 --side new \
  --type issue --username "Claude Opus 5" \
  "Handle the empty case here."
```

Omit `--target-file` for a review-level comment; add `--end-line` for a range;
`--side old` for removed lines, `new` for added or unchanged. `--type` accepts
`issue`, `suggestion`, `note`, `praise` and works with no config file present.
Note it is **not validated** — a typo silently creates a comment with a junk
type rather than erroring, so check your spelling.

`--input` takes literal JSON, `@file.json`, or `-` for stdin; target types are
`review`, `file`, `line`, `line_range`.

## Gotchas

- Comments you add are `lifecycle_state: local_draft`. Getting them onto the
  forge is the user's submit action in the TUI, not something the CLI does.
- The CLI works fine outside herdr/tmux/Zellij. Never demand a multiplexer just
  to read an existing session.
- Under herdr, `prefix+tab` flips back to the agent pane and `prefix+z` zooms —
  useful to tell the user when the diff is hard to read in a split.

## When not to use

- The user just wants `git diff` output.
- The diff is local and comments should come back to you → reviewr.
- The user wants to skim while you work → `hunk diff --watch`.
