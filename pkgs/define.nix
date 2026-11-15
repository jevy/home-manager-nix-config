# define / spell: offline dictionary and spell checker for the terminal.
#
#   define <word>   WordNet definitions (local database, no network)
#   spell <word>    `ok` if spelled right, else aspell's suggestions
#
# The old-school `dict` needs a dictd server (or dict.org over the network);
# WordNet ships its database locally. Multi-word entries work: WordNet joins
# them with `_`, so `define ad hoc` looks up ad_hoc.
#
# `define-menu` (Linux, built with withMenu) is the Hyprland popup on the
# $mod+D which-key menu: type a word in fuzzel, pick a spelling if aspell
# doesn't know it, read the definition. The correct spelling lands on the
# clipboard either way, so it doubles as "how do I spell this".
{
  lib,
  symlinkJoin,
  writeShellApplication,
  wordnet,
  aspellWithDicts,
  gnused,
  gnugrep,
  fuzzel,
  wl-clipboard,
  libnotify,
  withMenu ? false,
}:
let
  aspell = aspellWithDicts (d: [ d.en ]);

  define = writeShellApplication {
    name = "define";
    runtimeInputs = [ wordnet ];
    text = ''
      if [ $# -eq 0 ]; then
        echo "usage: define <word or phrase>" >&2
        exit 1
      fi
      word=$(printf '%s' "$*" | tr ' ' '_')
      out=$(wn "$word" -over || true)
      if [ -z "$out" ]; then
        echo "define: no entry for '$*'" >&2
        exit 1
      fi
      printf '%s\n' "$out"
    '';
  };

  # Prints `ok` when aspell accepts the word, else one suggestion per line.
  # Exit 1 when misspelled, so scripts can branch on it.
  spell = writeShellApplication {
    name = "spell";
    runtimeInputs = [
      aspell
      gnused
    ];
    text = ''
      if [ $# -ne 1 ]; then
        echo "usage: spell <word>" >&2
        exit 2
      fi
      # aspell -a: `*` = correct, `& word n off: a, b` = suggestions,
      # `# word off` = misspelled with no suggestions. `^` stops a leading
      # character in the word being read as an aspell command.
      line=$(printf '^%s\n' "$1" | aspell -a --lang=en | sed -n 2p)
      case "$line" in
        '*'*) echo ok ;;
        '&'*) printf '%s\n' "''${line#*: }" | sed 's/, /\n/g'; exit 1 ;;
        *) echo "spell: no suggestions for '$1'" >&2; exit 1 ;;
      esac
    '';
  };

  defineMenu = writeShellApplication {
    name = "define-menu";
    runtimeInputs = [
      define
      spell
      gnugrep
      fuzzel
      wl-clipboard
      libnotify
    ];
    text = ''
      # theme-mode (pkgs/gruvbox-art) writes this in art mode only; it
      # includes the stylix fuzzel.ini and overrides the colours.
      art="''${XDG_STATE_HOME:-$HOME/.local/state}/theme-mode/fuzzel.ini"
      cfg=()
      [ -f "$art" ] && cfg=(--config "$art")
      fuzzel() { command fuzzel "''${cfg[@]}" "$@"; }

      # --prompt-only: a bare text prompt, prints what was typed.
      word=$(fuzzel --dmenu --prompt-only "define: " || true)
      [ -z "$word" ] && exit 0

      # Spell-check single words only; aspell checks phrases word by word.
      if [[ "$word" != *" "* ]] && ! spell "$word" >/dev/null 2>&1; then
        sugg=$(spell "$word" 2>/dev/null || true)
        if [ -z "$sugg" ]; then
          notify-send "define" "No suggestions for '$word'"
          exit 0
        fi
        word=$(printf '%s\n' "$sugg" | fuzzel --dmenu --prompt "did you mean: " || true)
        [ -z "$word" ] && exit 0
      fi

      printf '%s' "$word" | wl-copy
      if ! out=$(define "$word" 2>/dev/null); then
        notify-send "$word" "Spelled right (copied), but WordNet has no entry"
        exit 0
      fi
      # Definitions in a wide fuzzel list: scroll with arrows, Esc closes.
      printf '%s\n' "$out" | grep -v '^\s*$' \
        | fuzzel --dmenu --width 100 --lines 20 --prompt "$word (copied) " >/dev/null || true
    '';
  };
in
symlinkJoin {
  name = "define";
  paths = [
    define
    spell
  ]
  ++ lib.optional withMenu defineMenu;
}
