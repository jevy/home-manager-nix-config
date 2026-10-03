"""Switch the live desktop between stylix's gruvbox and gruvbox tinted by the
current painting, without a rebuild.

  theme-mode toggle | gruvbox | art | refresh | status

Reaches only what can recolour live: Noctalia (custom palette), Hyprland
borders (hyprctl keyword) and ghostty (an optional config-file override plus a
reload). Everything else stays stylix's build-time gruvbox. Colour mappings
copy stylix's own targets, so gruvbox mode matches a fresh login.

`refresh` re-applies art mode (after a new painting, and at login since
Hyprland keywords don't survive a restart); in gruvbox mode it does nothing.

Configured by the Nix wrapper through env vars:
  THEME_MODE_GRUVBOX   base16 YAML of stylix's scheme
  THEME_MODE_ART_DIR   directory holding current.json + the painting
  THEME_MODE_GRUVBOX_ART, THEME_MODE_GHOSTTY_RELOAD   helper commands
"""

import json
import os
import subprocess
import sys
from pathlib import Path

STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "theme-mode"
PALETTES = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "noctalia/palettes"
ART_PALETTE = "gruvbox-art"  # Noctalia custom palette name
GRUVBOX_PALETTE = "stylix"  # written by stylix.targets.noctalia


def read_base16(path):
    pal = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if line.startswith("base0") and ":" in line:
            k, v = line.split(":", 1)
            pal[k.strip()] = "#" + v.strip().strip("\"'").lstrip("#").lower()
    return pal


def run(*cmd):
    # Best effort: a missing compositor or terminal shouldn't stop the others.
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"theme-mode: {cmd[0]} failed: {r.stderr.strip()}", file=sys.stderr)
    return r


# --- per-app renderers (mappings from stylix's modules/<app>/hm.nix) ---------


def noctalia_palette(c):
    term = {
        "black": c["base00"], "red": c["base08"], "green": c["base0B"], "yellow": c["base0A"],
        "blue": c["base0D"], "magenta": c["base0E"], "cyan": c["base0C"], "white": c["base05"],
    }
    return {
        "dark": {
            "mPrimary": c["base0D"], "mOnPrimary": c["base00"],
            "mSecondary": c["base0E"], "mOnSecondary": c["base00"],
            "mTertiary": c["base0C"], "mOnTertiary": c["base00"],
            "mError": c["base08"], "mOnError": c["base00"],
            "mSurface": c["base00"], "mOnSurface": c["base05"],
            "mHover": c["base0C"], "mOnHover": c["base00"],
            "mSurfaceVariant": c["base01"], "mOnSurfaceVariant": c["base04"],
            "mOutline": c["base03"], "mShadow": c["base00"],
            "terminal": {
                "foreground": c["base05"], "background": c["base00"],
                "cursor": c["base05"], "cursorText": c["base00"],
                "selectionFg": c["base05"], "selectionBg": c["base02"],
                "normal": term,
                "bright": term | {"black": c["base03"], "white": c["base07"]},
            },
        }
    }


def ghostty_override(c):
    order = ["base00", "base08", "base0B", "base0A", "base0D", "base0E", "base0C", "base05",
             "base03", "base08", "base0B", "base0A", "base0D", "base0E", "base0C", "base07"]
    lines = [f"palette = {i}={c[s]}" for i, s in enumerate(order)]
    lines += [
        f"background = {c['base00']}", f"foreground = {c['base05']}",
        f"cursor-color = {c['base05']}",
        f"selection-background = {c['base02']}", f"selection-foreground = {c['base05']}",
    ]
    return "# Written by theme-mode (art). Overrides the stylix theme.\n" + "\n".join(lines) + "\n"


def hyprland_batch(c):
    rgb = lambda s: f"rgb({c[s][1:]})"  # noqa: E731
    settings = {
        "decoration:shadow:color": f"rgba({c['base00'][1:]}99)",
        "general:col.active_border": rgb("base0D"),
        "general:col.inactive_border": rgb("base03"),
        "group:col.border_inactive": rgb("base03"),
        "group:col.border_active": rgb("base0D"),
        "group:col.border_locked_active": rgb("base0C"),
        "group:groupbar:text_color": rgb("base05"),
        "group:groupbar:col.active": rgb("base0D"),
        "group:groupbar:col.inactive": rgb("base03"),
        "misc:background_color": rgb("base00"),
    }
    return ";".join(f"keyword {k} {v}" for k, v in settings.items())


# --- modes -------------------------------------------------------------------


def current_painting():
    d = Path(os.environ["THEME_MODE_ART_DIR"])
    meta = json.loads((d / "current.json").read_text())
    return d / meta["file"], meta.get("title", "painting")


def art_colours():
    image, title = current_painting()
    yaml = subprocess.run(
        [os.environ["THEME_MODE_GRUVBOX_ART"], str(image), "--name", f"Gruvbox Art: {title}"],
        capture_output=True, text=True, check=True,
    ).stdout
    (STATE / "art.yaml").write_text(yaml)
    return read_base16(STATE / "art.yaml"), title


def apply(mode):
    STATE.mkdir(parents=True, exist_ok=True)
    ghostty = STATE / "ghostty"
    if mode == "art":
        c, title = art_colours()
        PALETTES.mkdir(parents=True, exist_ok=True)
        # Write-then-rename so Noctalia never reads a half-written palette.
        tmp = PALETTES / f".{ART_PALETTE}.json.tmp"
        tmp.write_text(json.dumps(noctalia_palette(c), indent=2))
        tmp.replace(PALETTES / f"{ART_PALETTE}.json")
        run("noctalia", "msg", "color-scheme-set", "custom", ART_PALETTE)
        ghostty.write_text(ghostty_override(c))
        label = f"art · {title}"
    else:
        c = read_base16(os.environ["THEME_MODE_GRUVBOX"])
        run("noctalia", "msg", "color-scheme-set", "custom", GRUVBOX_PALETTE)
        ghostty.unlink(missing_ok=True)
        label = "gruvbox"
    run("hyprctl", "--batch", hyprland_batch(c))
    run("bash", os.environ["THEME_MODE_GHOSTTY_RELOAD"])
    (STATE / "mode").write_text(mode + "\n")
    return label


def saved_mode():
    try:
        return (STATE / "mode").read_text().strip()
    except FileNotFoundError:
        return "gruvbox"


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        print(saved_mode())
        return
    mode = {
        "toggle": "gruvbox" if saved_mode() == "art" else "art",
        "refresh": saved_mode(),
        "gruvbox": "gruvbox",
        "art": "art",
    }.get(cmd)
    if mode is None:
        sys.exit(__doc__)
    if cmd == "refresh" and mode == "gruvbox":
        return  # the build-time config already is gruvbox
    label = apply(mode)
    if cmd != "refresh":
        run("notify-send", "-a", "theme-mode", "Theme", label)


if __name__ == "__main__":
    main()
