#!/usr/bin/env python3
"""Builds the Keyholdr app icon assets from one vector definition.

Default design ("balloon"): the same picture as the website's animated logo — a balloon
lifting a black house key on two dashed cords — set on a paper-coloured macOS tile.
An alternate "k" design (a key whose shaft is the stem of a K) is kept for comparison.

Outputs in branding/export/ (or export-k/ for the alternate):
  AppIcon.icns, AppIcon-1024.png   macOS icon (artwork on Apple's 824/1024 grid, with shadow)
  keyholdr-icon.svg                the coloured icon as a vector
  keyholdr-mark.svg                the key alone, one colour (currentColor)
  MenuBarIcon*.png                 black template glyph, 18 pt at @1x/@2x/@3x

Rasterising uses headless Chrome, so nothing beyond Python + Pillow + Chrome is needed.
Usage: python3 branding/generate.py [balloon|k]
"""
import math, os, subprocess, sys, shutil, tempfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "export"
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

# ---------------------------------------------------------------- geometry
def squircle(cx, cy, a, n=5.0, steps=64):
    """Continuous-corner rounded square (superellipse) like Apple's icon shape, as a smooth
    closed cubic path (Catmull-Rom through `steps` points) so the SVG stays small."""
    P = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        P.append((cx + a * math.copysign(abs(c) ** (2 / n), c), cy + a * math.copysign(abs(s) ** (2 / n), s)))
    f = lambda v: f"{v:.1f}".rstrip("0").rstrip(".")
    d = f"M{f(P[0][0])} {f(P[0][1])}"
    for i in range(steps):
        p0, p1, p2, p3 = P[i - 1], P[i], P[(i + 1) % steps], P[(i + 2) % steps]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}"
    return d + "Z"

# The key-K mark, in a 1024 canvas. One shape family: a ring, a shaft with its teeth on the
# left, and a K whose arms grow out of the shaft's right side (kept clear of the teeth so
# the two stay distinct even at 16-32 px).
INK_W = 76                       # K arm thickness
RING_C, RING_R, HOLE_R = (402.5, 380.0), 109.0, 52.0
SHAFT_L, SHAFT_R, SHAFT_TOP, SHAFT_BOTTOM = 360.0, 445.0, 452.0, 776.0

def _fillet(side, f=26.0):
    """Concave fillet where the shaft edge meets the ring (radius f), as a fill path."""
    cx, cy = RING_C
    ex = SHAFT_L if side < 0 else SHAFT_R          # shaft edge x
    fx = ex + side * f                             # fillet-circle centre x (outside the shaft)
    dy = math.sqrt((RING_R + f) ** 2 - (cx - fx) ** 2)
    fy = cy + dy
    # tangent point on the ring and on the shaft edge
    ux, uy = (fx - cx) / (RING_R + f), (fy - cy) / (RING_R + f)
    tx, ty = cx + RING_R * ux, cy + RING_R * uy
    sweep = 1 if side < 0 else 0
    return f"M{tx:.2f} {ty:.2f} A{f} {f} 0 0 {sweep} {ex:.2f} {fy:.2f} L{ex:.2f} {ty - 6:.2f} Z"

def mark_paths():
    cx, cy = RING_C
    ring = (f"M{cx} {cy - RING_R} a{RING_R} {RING_R} 0 1 0 .01 0 Z "
            f"M{cx} {cy - HOLE_R} a{HOLE_R} {HOLE_R} 0 1 1 -.01 0 Z")           # even-odd hole
    r = 28
    shaft = (f"M{SHAFT_L} {SHAFT_TOP} L{SHAFT_R} {SHAFT_TOP} L{SHAFT_R} {SHAFT_BOTTOM - r} "
             f"Q{SHAFT_R} {SHAFT_BOTTOM} {SHAFT_R - r} {SHAFT_BOTTOM} L{SHAFT_L + r} {SHAFT_BOTTOM} "
             f"Q{SHAFT_L} {SHAFT_BOTTOM} {SHAFT_L} {SHAFT_BOTTOM - r} Z")
    tooth = lambda y, h: (f"M{SHAFT_L} {y} L321 {y} Q308 {y} 308 {y + 13} L308 {y + h - 13} "
                          f"Q308 {y + h} 321 {y + h} L{SHAFT_L} {y + h} Z")
    fills = [ring, shaft, _fillet(-1), _fillet(1), tooth(606, 48), tooth(676, 40)]
    # K: the upper arm ends inside the shaft (its cap hidden); the leg branches off the arm
    arms = ["M706 338 L402 581", "M493 508 L708 742"]
    return fills, arms

def mark_group(fill="url(#ink)", dx=-14, dy=-11.5):
    fills, arms = mark_paths()
    body = "".join(f'<path d="{d}" fill="{fill}" fill-rule="evenodd"/>' for d in fills)
    body += "".join(f'<path d="{d}" stroke="{fill}" stroke-width="{INK_W}" stroke-linecap="round" fill="none"/>' for d in arms)
    return f'<g transform="translate({dx} {dy})">{body}</g>'

# ---------------------------------------------------------------- balloon design
# Coordinates are the website GIF's own pixels (frame 0, cropped to x 230.., y 20..), so the
# drawing can be checked against key-balloon.gif directly; a single transform places it on the tile.
BALLOON_C, BALLOON_R = (243.0, 228.0), 205.0
BOW_C = (243.0, 601.0)
ATTACH = (250.0, 512.0)                       # where the cords meet the key; the key sways about here
LEAN = -7.0                                    # degrees: a little sway so it isn't frozen
INK, GREY, PAPER = "#121212", "#9C9B99", "#F4F3EF"

# blade outline, traced from the GIF (teeth on the left, groove down the right), in detail-crop coords
_BLADE = [(232,300),(232,375),(270,380),(270,432),(312,452),(312,497),(252,535),(252,560),(300,588),
          (300,628),(268,645),(268,662),(298,682),(298,715),(250,745),(250,780),(372,838),(378,390),
          (410,392),(404,850),(444,800),(450,300)]

def _rot(pt, deg=LEAN, about=ATTACH):
    a = math.radians(deg); x, y = pt[0] - about[0], pt[1] - about[1]
    return (about[0] + x * math.cos(a) - y * math.sin(a), about[1] + x * math.sin(a) + y * math.cos(a))

def key_paths():
    """The key as (svg path for the ink shape with even-odd cutouts, unrotated). Crop coords."""
    cx, cy = BOW_C
    circ = lambda x, y, r: f"M{x-r:.1f} {y:.1f}a{r} {r} 0 1 0 {2*r} 0a{r} {r} 0 1 0 {-2*r} 0Z"
    # bow: ink disc, white ring, ink disc, hole  (alternating, so even-odd cuts them out)
    bow = circ(cx, cy, 110) + circ(cx, cy, 92) + circ(cx, cy, 82) + circ(cx + 2, cy - 29, 32)
    blade = "M" + " L".join(f"{x/2+70:.1f},{y/2+540:.1f}" for x, y in _BLADE) + "Z"
    return bow, blade

def key_group(fill=INK, rotate=True):
    bow, blade = key_paths()
    rot = f' transform="rotate({LEAN} {ATTACH[0]} {ATTACH[1]})"' if rotate else ""
    return f'<g{rot}><path d="{bow}" fill="{fill}" fill-rule="evenodd"/><path d="{blade}" fill="{fill}"/></g>'

def cords(color=INK):
    """Two dashed cords from the balloon down to the (swayed) key."""
    tops = [(205, 432), (287, 432)]
    ends = [_rot((238, 517)), _rot((262, 517))]
    return "".join(f'<path d="M{t[0]} {t[1]} L{e[0]:.1f} {e[1]:.1f}" stroke="{color}" stroke-width="6" stroke-dasharray="15 9" fill="none"/>'
                   for t, e in zip(tops, ends))

ART_SCALE, ART_TILT = 0.78, 0.0

def balloon_art(scale=None, tilt=None):
    """Balloon + cords + key, centred on (512,512) of the 1024 canvas (optionally tilted)."""
    scale = ART_SCALE if scale is None else scale
    tilt = ART_TILT if tilt is None else tilt
    cx, cy = 243.0, (23 + 962) / 2                      # logo bbox centre in GIF coords
    tx, ty = 512 - cx * scale, 512 - cy * scale
    return (f'<g transform="rotate({tilt} 512 512) translate({tx:.2f} {ty:.2f}) scale({scale})">'
            f'<circle cx="{BALLOON_C[0]}" cy="{BALLOON_C[1]}" r="{BALLOON_R}" fill="url(#balloon)"/>'
            f'{cords()}{key_group()}</g>')

# ---------------------------------------------------------------- svg
def icon_svg(design="balloon", shadow=True, size=1024):
    path = squircle(512, 512, 412)                      # 824 artwork on the 1024 grid
    sh = ('<filter id="sh" x="-20%" y="-20%" width="140%" height="150%">'
          '<feDropShadow dx="0" dy="12" stdDeviation="16" flood-color="#1c1a14" flood-opacity="0.28"/></filter>') if shadow else ""
    if design == "k":
        defs = ('<linearGradient id="base" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FBFCFF"/><stop offset="1" stop-color="#E8F0FF"/></linearGradient>'
                '<radialGradient id="blue" cx="0.08" cy="0.95" r="0.95"><stop offset="0" stop-color="#3DB8FF"/><stop offset="0.38" stop-color="#8ED8FF" stop-opacity="0.85"/><stop offset="1" stop-color="#CFEAFF" stop-opacity="0"/></radialGradient>'
                '<radialGradient id="violet" cx="0.96" cy="0.04" r="0.75"><stop offset="0" stop-color="#A996FB"/><stop offset="0.45" stop-color="#C8BCFC" stop-opacity="0.8"/><stop offset="1" stop-color="#E4DEFF" stop-opacity="0"/></radialGradient>'
                '<linearGradient id="ink" gradientUnits="userSpaceOnUse" x1="330" y1="260" x2="720" y2="790"><stop offset="0" stop-color="#26262F"/><stop offset="1" stop-color="#14141A"/></linearGradient>')
        tint = ('<rect x="100" y="100" width="824" height="824" fill="url(#blue)"/><rect x="100" y="100" width="824" height="824" fill="url(#violet)"/>'
                '<path d="M100 640 C 330 690, 520 800, 760 924 L100 924 Z" fill="#fff" fill-opacity="0.16"/>')
        art = mark_group()
    else:
        defs = ('<linearGradient id="base" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FAF9F6"/><stop offset="1" stop-color="#ECEAE4"/></linearGradient>'
                '<radialGradient id="balloon" cx="0.36" cy="0.30" r="0.85"><stop offset="0" stop-color="#ABAAA8"/><stop offset="1" stop-color="#92918E"/></radialGradient>')
        tint = ""
        art = balloon_art()
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">
<defs>
  <path id="shape" d="{path}"/>
  <clipPath id="sq"><use href="#shape"/></clipPath>
  <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0.55"/><stop offset="0.5" stop-color="#fff" stop-opacity="0"/></linearGradient>
  {defs}
  {sh}
</defs>
<g{' filter="url(#sh)"' if shadow else ''}><use href="#shape" fill="url(#base)"/></g>
<g clip-path="url(#sq)">
  {tint}
  <rect x="100" y="100" width="824" height="824" fill="url(#sheen)"/>
  <use href="#shape" fill="none" stroke="#fff" stroke-opacity="0.75" stroke-width="3"/>
</g>
{art}
</svg>'''

def mark_svg(design="balloon", color="currentColor", pad=20):
    """The glyph alone, one colour. Balloon design: the key only (the balloon adds nothing at 18 pt)."""
    if design == "k":
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{293-pad} {262-pad} {456+2*pad} {514+2*pad}">'
                f'{mark_group(fill=color, dx=0, dy=0)}</svg>')
    # key bbox in crop coords, after the sway
    pts = [_rot((x, y)) for x, y in [(133, 491), (353, 491), (133, 711), (353, 711), (185, 962), (300, 962)]]
    x0, x1 = min(p[0] for p in pts) - pad, max(p[0] for p in pts) + pad
    y0, y1 = min(p[1] for p in pts) - pad, max(p[1] for p in pts) + pad
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.0f} {y0:.0f} {x1-x0:.0f} {y1-y0:.0f}">'
            f'{key_group(fill=color)}</svg>')

# ---------------------------------------------------------------- raster
def render(html, out_png, w, h, transparent=True):
    """Screenshot an HTML string with headless Chrome. Transparency is recovered by
    rendering on black and white and solving for alpha, which works in any Chrome build."""
    with tempfile.TemporaryDirectory() as td:
        shots = {}
        for name, bg in (("k", "#000"), ("w", "#fff")):
            f = Path(td) / f"{name}.html"
            f.write_text(f'<!doctype html><meta charset="utf-8"><style>html,body{{margin:0;background:{bg}}}</style>{html}')
            png = Path(td) / f"{name}.png"
            subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                            f"--window-size={w},{h}", "--virtual-time-budget=4000", f"--screenshot={png}", f"file://{f}"],
                           check=True, capture_output=True)
            shots[name] = Image.open(png).convert("RGB")
        if not transparent:
            shots["w"].save(out_png); return
        k, wimg = shots["k"], shots["w"]
        out = Image.new("RGBA", k.size)
        kp, wp, op = k.load(), wimg.load(), out.load()
        for y in range(k.size[1]):
            for x in range(k.size[0]):
                kr, kg, kb = kp[x, y]; wr, wg, wb = wp[x, y]
                a = 1 - ((wr - kr) + (wg - kg) + (wb - kb)) / (3 * 255)
                a = min(max(a, 0), 1)
                if a < 0.002: op[x, y] = (0, 0, 0, 0)
                else: op[x, y] = tuple(min(255, round(c / a)) for c in (kr, kg, kb)) + (round(a * 255),)
        out.crop((0, 0, w, h)).save(out_png)

def tight(svg):
    """The icon artwork without the transparent margin (for web use)."""
    return svg.replace('width="1024" height="1024" viewBox="0 0 1024 1024"', 'viewBox="100 100 824 824"', 1)

def svg_html(svg, height):
    sized = svg.replace("<svg ", '<svg height="%d" ' % height, 1)
    return f'<div style="height:{height}px;line-height:0">{sized}</div>'

def build_all(design="balloon"):
    out = OUT if design == "balloon" else ROOT / f"export-{design}"
    out.mkdir(exist_ok=True)
    (out / "keyholdr-icon.svg").write_text(tight(icon_svg(design, shadow=False)))
    (out / "keyholdr-mark.svg").write_text(mark_svg(design))

    # macOS app icon: artwork on Apple's 824/1024 grid with its shadow, transparent margins
    master = out / "AppIcon-1024.png"
    render(icon_svg(design, shadow=True), master, 1024, 1024)
    iconset = out / "AppIcon.iconset"
    shutil.rmtree(iconset, ignore_errors=True); iconset.mkdir()
    big = Image.open(master)
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = base * scale
            big.resize((px, px), Image.LANCZOS).save(iconset / f"icon_{base}x{base}{'@2x' if scale == 2 else ''}.png")
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(out / "AppIcon.icns")], check=True)
    shutil.rmtree(iconset)

    # menu bar template glyph (black on transparent; macOS tints it). 18 pt tall.
    for scale in (1, 2, 3):
        h = 18 * scale
        render(svg_html(mark_svg(design, "#000", pad=6), h), out / f"MenuBarIcon{'' if scale == 1 else f'@{scale}x'}.png", 24 * scale, h)
    for f in out.glob("MenuBarIcon*.png"):
        im = Image.open(f); box = im.getbbox()
        if box: im.crop((box[0], 0, box[2], im.size[1])).save(f)
    return out

if __name__ == "__main__":
    design = sys.argv[1] if len(sys.argv) > 1 else "balloon"
    out = build_all(design)
    for f in sorted(out.rglob("*")):
        if f.is_file(): print(f"{f.relative_to(ROOT.parent)}  {f.stat().st_size:,} B")
