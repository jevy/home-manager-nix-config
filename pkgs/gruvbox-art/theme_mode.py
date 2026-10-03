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


# Warm near-black whatever the painting: reads as black on OLED but keeps
# gruvbox's moderate text contrast (10.6:1 vs 12.8:1 on pure black).
ART_BACKGROUND = "#1b1a17"
DEFAULT_ROLES = ["base0D", "base0E", "base0C"]  # stylix's primary/secondary/tertiary
ART_ROLES = ["primary", "secondary", "tertiary"]  # extra keys gruvbox-art writes


def read_base16(path):
    pal = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        k, _, v = line.partition(":")
        if v and (k.startswith("base0") or k in ART_ROLES):
            pal[k] = "#" + v.strip().strip("\"'").lstrip("#").lower()
    return pal


def roles(c):
    """Slots for primary, secondary, tertiary: gruvbox-art's painting-hued,
    gruvbox-quiet roles when it wrote them (not for a grey painting)."""
    return ART_ROLES if all(r in c for r in ART_ROLES) else DEFAULT_ROLES


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
    p, s, t = (c[r] for r in roles(c))
    return {
        "dark": {
            "mPrimary": p, "mOnPrimary": c["base00"],
            "mSecondary": s, "mOnSecondary": c["base00"],
            "mTertiary": t, "mOnTertiary": c["base00"],
            "mError": c["base08"], "mOnError": c["base00"],
            "mSurface": c["base00"], "mOnSurface": c["base05"],
            "mHover": t, "mOnHover": c["base00"],
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


def hy3_tabs(c, rgb, primary, tertiary):
    # Same mapping as plugin.hy3.tabs.colors in modules/desktop/hyprland.nix.
    slots = {
        "active": (primary, primary, "base00"),
        "focused": ("base02", primary, "base05"),
        "inactive": ("base01", "base02", "base04"),
        "active_alt_monitor": ("base02", "base03", "base05"),
        "urgent": ("base08", "base08", "base00"),
        "locked": (tertiary, tertiary, "base00"),
    }
    out = {}
    for name, (bg, border, text) in slots.items():
        k = f"plugin:hy3:tabs:colors:{name}"
        out |= {k: rgb(bg), f"{k}_border": rgb(border), f"{k}_text": rgb(text)}
    return out


def hyprland_batch(c):
    rgb = lambda s: f"rgb({c[s][1:]})"  # noqa: E731
    primary, _, tertiary = roles(c)
    settings = {
        "decoration:shadow:color": f"rgba({c['base00'][1:]}99)",
        "general:col.active_border": rgb(primary),
        "general:col.inactive_border": rgb("base03"),
        "group:col.border_inactive": rgb("base03"),
        "group:col.border_active": rgb(primary),
        "group:col.border_locked_active": rgb(tertiary),
        "group:groupbar:text_color": rgb("base05"),
        "group:groupbar:col.active": rgb(primary),
        "group:groupbar:col.inactive": rgb("base03"),
        "misc:background_color": rgb("base00"),
    }
    settings |= hy3_tabs(c, rgb, primary, tertiary)
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
    c = read_base16(STATE / "art.yaml")
    c["base00"] = ART_BACKGROUND
    return c, title


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
