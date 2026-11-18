# clip FILE: put FILE on the system clipboard, ready to paste.
#
# FILE ending in .html is copied as rich text (pastes formatted into Gmail);
# anything else is copied as plain text. One trailing newline is dropped so
# a paste does not leave the cursor on an empty line.
#
# Linux (Wayland) uses wl-copy. macOS uses pbcopy, which only understands plain
# text and RTF, so HTML is converted to RTF with textutil first.

if [ $# -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: clip FILE   (.html -> rich text, anything else -> plain text)" >&2
  exit 2
fi

f=$1
case "$f" in
  *.html | *.htm) kind=rich ;;
  *) kind=plain ;;
esac

# The file content minus its trailing newline, for the round-trip check.
expected=$(cat "$f")

case "$(uname -s)" in
  Darwin)
    # pbcopy reads input in the locale's encoding; without UTF-8 it mangles
    # bullets and curly quotes.
    export LC_CTYPE=en_US.UTF-8
    if [ "$kind" = rich ]; then
      textutil -stdin -format html -inputencoding UTF-8 -convert rtf -stdout <"$f" | pbcopy
      # pbpaste hands back the plain-text rendering of the RTF, so only check
      # that something landed.
      [ -n "$(pbpaste)" ] || { echo "clip: clipboard is empty after pbcopy" >&2; exit 1; }
    else
      printf %s "$expected" | pbcopy
      [ "$(pbpaste)" = "$expected" ] || { echo "clip: clipboard does not match $f" >&2; exit 1; }
    fi
    ;;
  *)
    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
      echo "clip: no WAYLAND_DISPLAY (SSH session?). The text is in $f" >&2
      exit 1
    fi
    if [ "$kind" = rich ]; then mime=text/html; else mime=text/plain; fi
    # wl-copy forks and keeps serving the clipboard after this script exits.
    wl-copy --trim-newline --type "$mime" <"$f"
    [ "$(wl-paste --no-newline --type "$mime")" = "$expected" ] ||
      { echo "clip: clipboard does not match $f" >&2; exit 1; }
    ;;
esac

if [ "$kind" = rich ]; then
  echo "clip: copied $f as rich text"
else
  echo "clip: copied $f as plain text, $(printf %s "$expected" | wc -m | tr -d ' ') characters"
fi
