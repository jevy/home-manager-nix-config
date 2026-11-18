---
name: clipboard-copy
description: Use when writing text Jevin will paste somewhere else - a YouTube/LinkedIn/form input box, a Slack message, a Gmail email, a bio, a description, a reply draft - or when he says "copy", "clipboard", "so I can paste it", or complains that output is not copy-pasteable. Writes the text to /tmp/clip and puts it on the clipboard with `clip` (wl-copy on Linux, pbcopy on macOS), formatted for the destination (plain, Slack markdown, or Gmail rich text).
---

# Clipboard copy

Text shown in the terminal is **not pasteable**: the renderer adds blockquote bars,
italics, indentation, and wraps long lines into hard breaks. Jevin then has to fix
it line by line. So any text meant to be pasted elsewhere goes through this skill:
write a file, run `clip` on it, and say it is on the clipboard.

```
  draft text
      |
      v
  pick format (plain / slack / gmail)
      |
      v
  Write /tmp/clip/<slug>.<txt|md|html>    <- one paragraph per line, no hard wraps
      |
      v
  clip /tmp/clip/<slug>.<ext>             <- copies, verifies, prints char count
```

`clip` is installed by `modules/dev/clipboard-copy.nix` in ~/.config/nixpkgs (source
`pkgs/clip/clip.sh`). It works on lenovo-p14s (wl-copy) and mac-work (pbcopy).

## 1. Pick the format

Use what Jevin says. If he does not say, infer from the destination and state the
guess in one line so he can correct it.

| Destination | Format | File |
|---|---|---|
| YouTube, LinkedIn, web form, bio box, SMS, anything unknown | **plain** | `.txt` |
| Slack | **slack** (markdown) | `.md` |
| Gmail / email body | **gmail** (rich text) | `.html` |

`clip` picks the clipboard type from the extension: `.html` is copied as rich text,
everything else as plain text. When torn between plain and something else, choose
plain. It pastes everywhere.

## 2. Write the file

Use the Write tool to `/tmp/clip/<short-slug>.<ext>` (Jevin explicitly asked for
`/tmp`; `mkdir -p /tmp/clip` first). Rules for every format:

- **One paragraph = one line.** Never hard-wrap. Paragraphs separated by one blank line.
- No leading indentation, no `>` quote prefixes, no surrounding quotes or code fences.
- Only the text to paste. No preamble like "Here is your description".
- No em dashes, no puffery (global rule).
- Placeholders like `[link]` only when the info is genuinely unknown; mention them after.

Per format:

**plain**: no markdown at all. No `**`, `_`, `#`, or `-` bullets. Bullets are `• `
at the start of a line. Links as bare URLs. Most input boxes (YouTube, LinkedIn)
keep line breaks, so a bullet list is one item per line.

**slack**: Slack markdown. `*bold*` (single asterisks), `_italic_`, `` `code` ``,
`~strike~`, `• ` or `- ` bullets, `>` only when quoting is the point. Links as bare
URLs: the `<url|text>` form only works through the API, not when pasted. No `#`
headings (Slack shows them literally); use a `*bold*` line instead.

**gmail**: an HTML fragment, no `<html>`/`<head>`/`<body>`. `<p>` per paragraph,
`<ul><li>` lists, `<b>`, `<i>`, `<a href="...">text</a>`. No CSS classes or inline
font styles, so Gmail uses its default font. No `<br>` inside paragraphs.

## 3. Copy

```bash
clip /tmp/clip/<slug>.<ext>
```

It prints `clip: copied ... N characters` and exits non-zero if the clipboard does
not match the file afterwards. Each run replaces the clipboard.

If `clip` is missing (host not rebuilt yet), fall back to:
- Linux: `wl-copy --trim-newline --type text/plain < FILE` (`text/html` for gmail)
- macOS: `pbcopy < FILE`, or for gmail
  `textutil -stdin -format html -inputencoding UTF-8 -convert rtf -stdout < FILE | pbcopy`

If it fails with no `WAYLAND_DISPLAY` (an SSH session), say so and give the file path.

## 4. Report

Short, in this order:

1. "Copied to your clipboard (<format>, N characters)." Include the limit when the
   destination has one (YouTube About 1,000, YouTube title 100, LinkedIn headline 220,
   tweet 280).
2. The file path, so he can copy it again later: `clip /tmp/clip/<slug>.txt`.
3. Any placeholders he needs to fill in after pasting.
4. Show the text in the reply only while he is still reviewing wording. Even then,
   still copy it; never make the terminal output the thing he pastes.

When he asks for changes, rewrite the same file and run `clip` again, then say
"the new version is on your clipboard".
