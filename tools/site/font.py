#!/usr/bin/env python3
"""The game's one typeface as a webfont, for unspent.world.

    tools/site/font.py            write site/fonts/unspent-5x7.woff2 and site/favicon.svg
    tools/site/font.py --check    exit 1 if either is not what the game draws

The face is src/ui/ui_font.gd's GLYPHS, cut exactly as UiFont.glyph_cut cuts it
(each source pixel PITCH x PITCH, staircase notches filled), and traced into
outlines rather than shipped as a bitmap, so the site letters with the slate's
own shapes at any size. The site may never use a face of its own for what the
slate says (docs/LOOK.md: one hacked slate), and a second table copied by hand is
how the loading page's copy once drifted (tests/export/test_export.gd).

Needs fontTools and brotli (`uv pip install fonttools brotli`); the output is
committed, so the site's build and deploy never need them.
"""
import io
import json
import re
import sys
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src/ui/ui_font.gd"
OUT = ROOT / "site/fonts/unspent-5x7.woff2"
ICON = ROOT / "site/favicon.svg"
PITCH = 2     # UiBase.PITCH: a source pixel is PITCH x PITCH cut pixels
ROWS = 9      # UiFont.ROWS: 7 above the baseline, 2 below
ABOVE = 7     # rows above the baseline (UiFont's glyph offset is -(ROWS - 2))
U = 50        # font units per cut pixel: a source pixel is 100, the line box 1000


def glyphs() -> dict:
    text = SRC.read_text()
    block = text[text.index("const GLYPHS := {"):]
    block = block[:block.index("\n}\n")]
    out = {}
    for line in block.splitlines()[1:]:
        m = re.match(r'^\s*("(?:[^"\\]|\\.)*")\s*:\s*(\[.*\]),\s*$', line)
        if m:
            out[json.loads(m.group(1))] = json.loads(m.group(2))
    return out


def width(rows: list) -> int:
    return max((len(r) for r in rows), default=0)


def cut(rows: list) -> list:
    """UiFont.glyph_cut: the cut bitmap, a list of rows of 0/1."""
    w = width(rows)
    src = [r.ljust(w, ".") for r in rows] + ["." * w] * (ROWS - len(rows))
    lit = lambda x, y: 0 <= x < w and 0 <= y < ROWS and src[y][x] == "#"
    big = [[0] * (w * PITCH) for _ in range(ROWS * PITCH)]
    for r in range(ROWS):
        for x in range(w):
            if src[r][x] == "#":
                for dy in range(PITCH):
                    for dx in range(PITCH):
                        big[r * PITCH + dy][x * PITCH + dx] = 1
    # UiFont._corners: fill a true staircase's notch, never an inner corner.
    for r in range(ROWS):
        for x in range(w):
            if src[r][x] == "#":
                continue
            for dy in (-1, 1):
                for dx in (-1, 1):
                    if not lit(x + dx, r) or not lit(x, r + dy) or lit(x + dx, r + dy):
                        continue
                    big[r * PITCH + (PITCH - 1 if dy > 0 else 0)][x * PITCH + (PITCH - 1 if dx > 0 else 0)] = 1
    return big


def contours(big: list) -> list:
    """The union of the lit cells as closed loops, filled on the right (clockwise,
    y up): TrueType's winding. A loop that only touches another at a corner takes
    the right turn there, so loops never cross."""
    h = len(big)
    w = len(big[0]) if h else 0
    on = lambda x, y: 0 <= x < w and 0 <= y < h and big[y][x] == 1
    edges = {}
    for y in range(h):
        for x in range(w):
            if not big[y][x]:
                continue
            # Cell corners in font units, y up, the baseline at row ABOVE * PITCH.
            x0, x1 = x * U, (x + 1) * U
            y1 = (ABOVE * PITCH - y) * U
            y0 = y1 - U
            if not on(x, y - 1):
                edges.setdefault((x0, y1), []).append((x1, y1))
            if not on(x + 1, y):
                edges.setdefault((x1, y1), []).append((x1, y0))
            if not on(x, y + 1):
                edges.setdefault((x1, y0), []).append((x0, y0))
            if not on(x - 1, y):
                edges.setdefault((x0, y0), []).append((x0, y1))
    loops = []
    while edges:
        start = next(iter(edges))
        loop = [start]
        here = start
        came = None
        while True:
            outs = edges[here]
            nxt = outs[0]
            if came is not None and len(outs) > 1:
                right = (sign(came[1]), -sign(came[0]))
                nxt = next((o for o in outs if (sign(o[0] - here[0]), sign(o[1] - here[1])) == right), nxt)
            outs.remove(nxt)
            if not outs:
                del edges[here]
            came = (nxt[0] - here[0], nxt[1] - here[1])
            here = nxt
            if here == start:
                break
            loop.append(here)
        loops.append(simplify(loop))
    return loops


def sign(v: int) -> int:
    return (v > 0) - (v < 0)


def simplify(loop: list) -> list:
    """Drop the points a straight run passes through."""
    out = []
    n = len(loop)
    for i, p in enumerate(loop):
        a, b = loop[i - 1], loop[(i + 1) % n]
        if (p[0] - a[0]) * (b[1] - p[1]) != (p[1] - a[1]) * (b[0] - p[0]):
            out.append(p)
    return out


def build() -> bytes:
    table = glyphs()
    order = [".notdef"] + ["u%04X" % ord(c) for c in table]
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({ord(c): "u%04X" % ord(c) for c in table})
    shapes = {".notdef": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (500, 0)}
    for c, rows in table.items():
        pen = TTGlyphPen(None)
        for loop in contours(cut(rows)):
            pen.moveTo(loop[0])
            for p in loop[1:]:
                pen.lineTo(p)
            pen.closePath()
        name = "u%04X" % ord(c)
        shapes[name] = pen.glyph()
        # UiFont: the advance is the glyph's width plus one source pixel.
        metrics[name] = ((width(rows) + 1) * PITCH * U, 0)
    fb.setupGlyf(shapes)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=800, descent=-200, lineGap=0)
    fb.setupNameTable({"familyName": "UNSPENT 5x7", "styleName": "Regular",
                       "uniqueFontIdentifier": "UNSPENT 5x7 (src/ui/ui_font.gd)",
                       "version": "Version 1.0"})
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, sTypoLineGap=0,
                usWinAscent=800, usWinDescent=200, sCapHeight=700, sxHeight=500,
                achVendID="UNSP", fsType=0)
    fb.setupPost()
    # A fixed date, so the same table always makes the same bytes (--check).
    fb.updateHead(created=3850070400, modified=3850070400)
    fb.font.recalcTimestamp = False
    fb.font.flavor = "woff2"
    buf = io.BytesIO()
    fb.font.save(buf, reorderTables=False)
    return buf.getvalue()


def icon() -> str:
    """The site's icon: the face's own U, phosphor on the slate's glass
    (src/ui/ui_theme.gd TEXT on GLASS)."""
    big = cut(glyphs()["U"])
    w = len(big[0])
    h = ABOVE * PITCH
    pad = 3
    side = max(w, h) + pad * 2
    ox = (side - w) // 2
    oy = (side - h) // 2
    cells = "".join('<rect x="%d" y="%d" width="1" height="1"/>' % (ox + x, oy + y)
                    for y in range(h) for x in range(w) if big[y][x])
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" shape-rendering="crispEdges">'
            '<rect width="%d" height="%d" fill="#0b1315"/><g fill="#87d9b5">%s</g></svg>\n') % (side, side, side, side, cells)


def main() -> int:
    data = build()
    svg = icon()
    if "--check" in sys.argv[1:]:
        if not OUT.exists() or OUT.read_bytes() != data or not ICON.exists() or ICON.read_text() != svg:
            print("font: site/'s face or icon is not what src/ui/ui_font.gd draws; run tools/site/font.py")
            return 1
        print("font: ok")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(data)
    ICON.write_text(svg)
    print("font: wrote %s (%d glyphs, %d bytes)" % (OUT.relative_to(ROOT), len(glyphs()), len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
