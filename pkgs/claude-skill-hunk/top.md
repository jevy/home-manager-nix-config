---
name: hunk-review
description: Use when reviewing any local diff — an agent's changes, uncommitted or staged work, a commit or a range — or when a hunk session is running and you need to read the user's notes or annotate a line. For comments that must reach a GitHub PR or GitLab MR, use the tuicr skill instead.
---

# hunk

hunk is the DEFAULT reviewer for local diffs on this machine. tuicr is the forge
reviewer, used outside herdr for already-pushed PRs — on a local diff it cannot
send comments anywhere and does not auto-reload. Do not route local work to it.

The TUI belongs to the user; `hunk session *` is your interface. If no session is
live, ask them to press `prefix+d` — do not launch the TUI yourself.

**Read the user's notes with `--type user`.** CLI-added notes are `source: agent`
even with `--author` set, so an unfiltered `comment list` shows you your own
notes as though the user wrote them.

```bash
hunk session comment list --repo . --type user --json   # what the USER wrote
hunk session comment add --repo . --file src/a.ts --new-line 42 \
  --summary "Handle the empty case?" --focus             # annotate + jump there
```

Full CLI reference follows (upstream's). Local setup — keybindings, the
user/agent note split, git-spice stacks — is in "This machine" at the end.

