"""Gruvbox, tinted by a painting.

A pure function of (base scheme, image, strength): no clustering with random
starts, no network, no clock, so the same inputs always give the same YAML.

The base scheme keeps its structure. Every slot keeps its OKLCH lightness, so
contrast between background, text and accents stays what gruvbox tuned it to.
Only hue and chroma move:

  base00-03  backgrounds take the colour of the painting's shadows
  base04-07  text takes the colour of the painting's highlights
  base08-0F  each accent drifts toward the painting's nearest strong hue,
             but never more than MAX_ACCENT_SHIFT degrees, so red stays red

Usage: gruvbox-art IMAGE [--base FILE] [--strength 0..1] [--name NAME]
                         [--preview OUT.png]
"""

import argparse
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

NEUTRALS = [f"base0{i}" for i in range(8)]
ACCENTS = ["base08", "base09", "base0A", "base0B", "base0C", "base0D", "base0E", "base0F"]

THUMB = 96  # longest side for sampling; fixed so results don't depend on scan size
HUE_BINS = 72  # 5 degrees each
DARK_L, LIGHT_L = 0.5, 0.7  # OKLab lightness splitting shadows / highlights
# Chroma range base00-03 may take from the shadows. Kept near gruvbox's own
# (base00 is 0.003): at 0.015-0.045 the background read as brown, not grey.
BG_CHROMA = (0.006, 0.010)
FG_CHROMA = (0.02, 0.07)  # chroma range base04-07 may take from the highlights
MAX_ACCENT_SHIFT = 40.0
# Red marks errors; 40 degrees turns it orange, which reads as a warning.
SLOT_MAX_SHIFT = {"base08": 15.0}
ACCENT_WINDOW = 50.0  # how far an accent looks for a painting hue to follow
MIN_ACCENT_MASS = 0.01  # less painting than this near an accent: leave it alone
PRESENT_MASS = 0.05  # this much painting near an accent counts as fully present
ABSENT_MUTE = 0.7  # chroma cut for an absent hue at strength 1 (0.42 at 0.6)
MIN_CONTRAST = 4.5  # WCAG AA, accent on base00


# --- colour math (sRGB <-> OKLab <-> OKLCH) ---------------------------------


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def rgb_to_oklab(r, g, b):
    r, g, b = _lin(r), _lin(g), _lin(b)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    )


def oklab_to_rgb_linear(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def lch_to_lab(L, C, h):
    return L, C * math.cos(math.radians(h)), C * math.sin(math.radians(h))


def lab_to_lch(L, a, b):
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def in_gamut(L, C, h, eps=1e-4):
    return all(-eps <= c <= 1 + eps for c in oklab_to_rgb_linear(*lch_to_lab(L, C, h)))


def lch_to_hex(L, C, h):
    # Gamut map by lowering chroma only, so lightness (and contrast) is kept.
    lo, hi = 0.0, C
    if not in_gamut(L, C, h):
        for _ in range(30):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if in_gamut(L, mid, h) else (lo, mid)
        C = lo
    rgb = oklab_to_rgb_linear(*lch_to_lab(L, C, h))
    return "#" + "".join(f"{round(min(1, max(0, _gam(max(0, c)))) * 255):02x}" for c in rgb)


def hex_to_rgb(hx):
    hx = hx.lstrip("#")
    return tuple(int(hx[i : i + 2], 16) / 255 for i in (0, 2, 4))


def hex_to_lch(hx):
    return lab_to_lch(*rgb_to_oklab(*hex_to_rgb(hx)))


def luminance(hx):
    r, g, b = (_lin(c) for c in hex_to_rgb(hx))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hue_delta(frm, to):
    """Signed shortest rotation from hue `frm` to hue `to`, in (-180, 180]."""
    d = (to - frm) % 360
    return d - 360 if d > 180 else d


# --- reading the painting ----------------------------------------------------


def _tone(sa, sb, n):
    """Average (a, b) of a pixel group as (hue, chroma); grey if the group is empty."""
    if n == 0:
        return 0.0, 0.0
    _, c, h = lab_to_lch(0, sa / n, sb / n)
    return h, c


def analyse(path):
    img = Image.open(path).convert("RGB")
    img.thumbnail((THUMB, THUMB), Image.Resampling.BOX)
    hist = [0.0] * HUE_BINS
    dark = [0.0, 0.0, 0]  # sum a, sum b, count
    light = [0.0, 0.0, 0]
    sum_c = 0.0
    n = 0
    for r, g, b in img.get_flattened_data():
        L, a, bb = rgb_to_oklab(r / 255, g / 255, b / 255)
        _, C, h = lab_to_lch(L, a, bb)
        sum_c, n = sum_c + C, n + 1
        group = dark if L < DARK_L else light if L > LIGHT_L else None
        if group:
            group[0], group[1], group[2] = group[0] + a, group[1] + bb, group[2] + 1
        if C > 0.03 and 0.15 < L < 0.95:  # ignore greys, black and paper white
            hist[int(h / (360 / HUE_BINS)) % HUE_BINS] += C
    # Circular [1, 2, 1] smoothing so one noisy bin doesn't win.
    hist = [
        (hist[i - 1] + 2 * hist[i] + hist[(i + 1) % HUE_BINS]) / 4 for i in range(HUE_BINS)
    ]
    total = sum(hist) or 1.0
    return {
        "hist": [w / total for w in hist],
        "dark": _tone(*dark),
        "light": _tone(*light),
        "mean_chroma": sum_c / n,
    }


def accent_target(hist, hue):
    """Weighted circular mean of painting hues near `hue`, and how much is there."""
    x = y = mass = 0.0
    step = 360 / HUE_BINS
    for i, w in enumerate(hist):
        bh = (i + 0.5) * step
        d = abs(hue_delta(hue, bh))
        if d > ACCENT_WINDOW or w == 0:
            continue
        k = w * math.exp(-((d / (ACCENT_WINDOW / 2)) ** 2))
        x += k * math.cos(math.radians(bh))
        y += k * math.sin(math.radians(bh))
        mass += k
    if mass == 0:
        return hue, 0.0
    return math.degrees(math.atan2(y, x)) % 360, mass


# --- building the scheme -----------------------------------------------------


def _toward(L, C, h, tone, c_range, t):
    """Move a neutral toward a painting tone in (a, b), keeping lightness.

    Rotating the hue of a near-grey is invisible, so chroma moves too: the
    target is the tone's hue at its own chroma, clamped to `c_range`.
    """
    th, tc = tone
    tc = min(c_range[1], max(c_range[0], tc))
    _, a0, b0 = lch_to_lab(L, C, h)
    _, a1, b1 = lch_to_lab(L, tc, th)
    return lab_to_lch(L, a0 + (a1 - a0) * t, b0 + (b1 - b0) * t)


def tint(base, art, strength):
    out = {}

    # Backgrounds take the painting's shadows, text takes its highlights.
    for slot in NEUTRALS:
        tone, c_range = (art["dark"], BG_CHROMA) if slot <= "base03" else (art["light"], FG_CHROMA)
        out[slot] = lch_to_hex(*_toward(*hex_to_lch(base[slot]), tone, c_range, strength))

    # Accents: muted paintings mute the accents a little, vivid ones lift them.
    sat = min(1.15, max(0.75, art["mean_chroma"] / 0.06))
    sat = 1 + (sat - 1) * strength
    for slot in ACCENTS:
        L, C, h = hex_to_lch(base[slot])
        target, mass = accent_target(art["hist"], h)
        pull = strength if mass > MIN_ACCENT_MASS else 0.0
        cap = SLOT_MAX_SHIFT.get(slot, MAX_ACCENT_SHIFT)
        shift = max(-cap, min(cap, hue_delta(h, target)))
        # Hues the painting lacks recede: same hue (magenta still reads as
        # magenta) but less chroma, so gruvbox pink doesn't shout over a brown
        # painting. Red is exempt: errors stay loud.
        absent = 0.0 if slot == "base08" else 1 - min(1.0, mass / PRESENT_MASS)
        C *= 1 - strength * ABSENT_MUTE * absent
        hx = lch_to_hex(L, C * sat, h + shift * pull)
        # Keep gruvbox's own contrast (capped at WCAG AA) on the new background.
        # Some gruvbox accents (base0F) start below 4.5:1; forcing them up would
        # change them identically for every painting.
        need = min(MIN_CONTRAST, contrast(base[slot], base["base00"]))
        while contrast(hx, out["base00"]) < need and L < 0.98:
            L += 0.005
            hx = lch_to_hex(L, C * sat, h + shift * pull)
        out[slot] = hx
    return out


def read_base16(path):
    """Minimal reader for the base16 YAML layout (avoids a YAML dependency)."""
    pal = {}
    for line in open(path):
        line = line.strip()
        if line.startswith("base0") and ":" in line:
            k, v = line.split(":", 1)
            pal[k.strip()] = "#" + v.strip().strip("\"'").lstrip("#").lower()
    missing = [s for s in NEUTRALS + ACCENTS if s not in pal]
    if missing:
        sys.exit(f"base scheme is missing {missing}")
    return pal


def accent_rank(base, art):
    """Accents ordered by how much of the painting sits near them, most first.

    A UI's main accent slots (Noctalia's primary/secondary) should be the
    painting's main colours; base16 fixes them to blue and magenta, which a
    brown painting never moves. Red is left out so errors still read as errors.
    Ties keep slot order (sorted is stable), so the ranking is deterministic.
    """
    mass = {
        s: accent_target(art["hist"], hex_to_lch(base[s])[2])[1] for s in ACCENTS if s != "base08"
    }
    rank = sorted(mass, key=lambda s: -mass[s])
    # A grey painting has nothing to rank by: callers keep their default roles.
    return rank if mass[rank[0]] > MIN_ACCENT_MASS else []


ROLE_SLOTS = ["base0D", "base0E", "base0C"]  # gruvbox's primary/secondary/tertiary


def ui_roles(base, tinted, rank):
    """Primary/secondary/tertiary UI colours: the painting's hues, gruvbox's quiet.

    Each role takes the hue of a top-ranked accent but the lightness and chroma
    of the gruvbox slot it stands in for. Gruvbox gives its large surfaces
    (tabs, active pill, borders) its most muted accents (base0D is C 0.055);
    promoting yellow at its own chroma (0.113) made those surfaces glare.
    """
    if not rank:
        return {}
    out = {}
    for name, role, src in zip(("primary", "secondary", "tertiary"), ROLE_SLOTS, rank):
        L, C, _ = hex_to_lch(base[role])
        out[name] = lch_to_hex(L, C, hex_to_lch(tinted[src])[2])
    return out


def to_yaml(pal, name, roles=None):
    lines = ['system: "base16"', f'name: "{name}"', 'author: "gruvbox-art"', 'variant: "dark"']
    # Extra top-level keys; base16 tools read only `palette`.
    lines += [f'{k}: "{v}"' for k, v in (roles or {}).items()]
    lines.append("palette:")
    lines += [f'  {k}: "{pal[k]}"' for k in NEUTRALS + ACCENTS]
    return "\n".join(lines) + "\n"


# --- preview -----------------------------------------------------------------


def preview(image_path, base, tinted, out):
    W, sw, pad = 1200, 60, 20
    art = Image.open(image_path).convert("RGB")
    art.thumbnail((W // 2 - pad * 2, 420))
    H = max(art.height, 420) + pad * 2
    canvas = Image.new("RGB", (W, H), tinted["base00"])
    canvas.paste(art, (pad, pad))
    d = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype(os.environ.get("GRUVBOX_ART_FONT", "DejaVuSansMono.ttf"), 15)
    except OSError:
        font = ImageFont.load_default()
    x0 = W // 2
    for row, (label, pal) in enumerate((("gruvbox", base), ("tinted", tinted))):
        y = pad + row * (sw + 24)
        d.text((x0, y), label, fill=tinted["base05"], font=font)
        for i, slot in enumerate(NEUTRALS + ACCENTS):
            d.rectangle([x0 + i * (sw // 2 + 4), y + 18, x0 + i * (sw // 2 + 4) + sw // 2, y + 18 + sw], fill=pal[slot])
    # A fake editor pane in the tinted colours.
    y = pad + 2 * (sw + 24) + 6
    d.rectangle([x0, y, W - pad, H - pad], fill=tinted["base01"])
    code = [
        [("base0E", "def "), ("base0D", "rotate"), ("base05", "(painting):")],
        [("base03", "    # pick tomorrow's wall")],
        [("base05", "    hue = "), ("base09", "42"), ("base05", " + painting."), ("base0C", "cast")],
        [("base0E", "    if "), ("base05", "hue > "), ("base09", "360"), ("base05", ":")],
        [("base05", "        "), ("base08", "raise"), ("base0A", " ValueError"), ("base05", "("), ("base0B", '"too warm"'), ("base05", ")")],
        [("base0E", "    return "), ("base0F", "Wall"), ("base05", "(hue)")],
        [],
        [("base04", " NORMAL "), ("base02", "|"), ("base06", " gruvbox_art.py ")],
    ]
    for li, parts in enumerate(code):
        cx = x0 + 14
        for slot, text in parts:
            d.text((cx, y + 12 + li * 22), text, fill=tinted[slot], font=font)
            cx += d.textlength(text, font=font)
    canvas.save(out)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("image")
    p.add_argument("--base", required=True, help="base16 YAML to tint (gruvbox)")
    p.add_argument("--strength", type=float, default=0.6)
    p.add_argument("--name", default="Gruvbox Art")
    p.add_argument("--preview")
    a = p.parse_args()
    base = read_base16(a.base)
    art = analyse(a.image)
    tinted = tint(base, art, max(0.0, min(1.0, a.strength)))
    sys.stdout.write(to_yaml(tinted, a.name, ui_roles(base, tinted, accent_rank(base, art))))
    if a.preview:
        preview(a.image, base, tinted, a.preview)


if __name__ == "__main__":
    main()
