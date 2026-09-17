class_name UiFont
## The game's one typeface: a hand-cut 5x7 face (caps and digits 7 rows, lower
## case 5 with 2-row descenders), built into a FontFile in code so no font file
## is imported.
##
## ## The decision LANTERN forced, and what was chosen
##
## The face used to be drawn at one glyph pixel per pixel of a 640x360 slate that
## was then blown up three times, so on a 1920x1080 screen a capital stood 21
## pixels tall out of blocks 3 pixels square. It was not broken; it was a
## readout the size of a title card, made of visibly large squares, sitting on a
## world drawn at full resolution. Three answers were open: cut a new face at the
## new base, keep this one at 1x and put more on the glass, or take a hinted
## vector face.
##
## **The face is kept, its cell halved, and its corners cut.** A capital is now
## 14 base pixels tall (`CAP`), which is ordinary readout size at 1080p, so half
## again as much fits on the glass; and every glyph is rendered into a cell
## PITCH pixels square with its diagonal notches filled (`_corners`), so a stroke
## that used to climb in 3-pixel steps now climbs in 1-pixel ones. The letters
## have four times the pixels and two-thirds the size.
##
## Why not a vector face: the slate is a display module stolen from a machine
## (docs/ART.md §9) and a module draws glyphs on its own pixel grid. An outline
## face with hinting would read as an application running on a laptop, which is
## the one thing the interface may never look like. Why not cut a new face by
## hand: the shapes here are the game's, every width is load-bearing in a dozen
## layouts, and 95 glyphs re-cut blind is 95 chances to ship a wrong letter.
## Deriving the detail keeps every silhouette exactly as it was drawn.
##
## **`GLYPHS` is therefore untouched**, which matters beyond taste: the table is
## copied into `src/boot/shell.html` so the browser can letter the loading page
## before the engine is down, and `tests/export/test_export.gd` holds the two
## equal.
##
## ## Metrics
##
## Everything public here is in BASE pixels (`UiBase.SIZE`), because that is what
## `src/ui/` is written in: line box `SIZE` 20 = `ASCENT` 16 + `DESCENT` 4, and
## an advance of the glyph's own width plus one cell, so narrow letters stay
## narrow and digits are all one width so a ticking clock never shuffles.
##
## `legacy_font()` is the same face at the old size, for the three things still
## drawn in the 640x360 space (see `UiBase`): the loading page, its HTML twin and
## the gallery.

## Base pixels to one pixel of the hand-cut cell (`UiBase.PITCH`, the module's
## own grid). Whole, so nothing is ever filtered.
const PITCH := UiBase.PITCH

const SIZE := 10 * PITCH
const ASCENT := 8 * PITCH
const DESCENT := 2 * PITCH
## Glyph rows in the SOURCE cell: 0..6 sit above the baseline, 7..8 below it.
const ROWS := 9
## A capital's height in base pixels: what the size of this face actually is.
const CAP := 7 * PITCH

## The same numbers in the legacy 640x360 space.
const LEGACY_SIZE := 10
const LEGACY_ASCENT := 8
const LEGACY_DESCENT := 2

## Each glyph: rows top to bottom, '#' lit, anything else clear. Width is the
## longest row. Trailing empty rows may be left out.
const GLYPHS := {
	" ": ["...", "...", "...", "...", "...", "...", "..."],
	"!": ["#", "#", "#", "#", "#", ".", "#"],
	"\"": ["#.#", "#.#"],
	"#": [".#.#.", ".#.#.", "#####", ".#.#.", "#####", ".#.#.", ".#.#."],
	"$": ["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."],
	"%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
	"&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
	"'": ["#", "#"],
	"(": ["..#", ".#.", "#..", "#..", "#..", ".#.", "..#"],
	")": ["#..", ".#.", "..#", "..#", "..#", ".#.", "#.."],
	"*": [".....", "..#..", "#.#.#", ".###.", "#.#.#", "..#..", "....."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	",": ["..", "..", "..", "..", "..", ".#", ".#", "#."],
	"-": ["....", "....", "....", "####"],
	".": [".", ".", ".", ".", ".", ".", "#"],
	"/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", "..#..", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	":": [".", ".", "#", ".", ".", "#"],
	";": ["..", "..", ".#", "..", "..", ".#", ".#", "#."],
	"<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
	"=": ["....", "....", "####", "....", "####"],
	">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	"@": [".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".###."],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
	"J": ["....#", "....#", "....#", "....#", "#...#", "#...#", ".###."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".###.", "#...#", "#....", ".###.", "....#", "#...#", ".###."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"[": ["###", "#..", "#..", "#..", "#..", "#..", "###"],
	"\\": ["#....", "#....", ".#...", "..#..", "...#.", "....#", "....#"],
	"]": ["###", "..#", "..#", "..#", "..#", "..#", "###"],
	"^": ["..#..", ".#.#.", "#...#"],
	"_": [".....", ".....", ".....", ".....", ".....", ".....", ".....", "#####"],
	"`": ["#.", ".#"],
	"a": [".....", ".....", ".###.", "....#", ".####", "#...#", ".####"],
	"b": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "####."],
	"c": ["....", "....", ".###", "#...", "#...", "#...", ".###"],
	"d": ["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####"],
	"e": [".....", ".....", ".###.", "#...#", "#####", "#....", ".###."],
	"f": ["..##", ".#..", "####", ".#..", ".#..", ".#..", ".#.."],
	"g": [".....", ".....", ".####", "#...#", "#...#", "#...#", ".####", "....#", ".###."],
	"h": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "#...#"],
	"i": ["#", ".", "#", "#", "#", "#", "#"],
	"j": ["..#", "...", "..#", "..#", "..#", "..#", "..#", "..#", "##."],
	"k": ["#...", "#...", "#..#", "#.#.", "##..", "#.#.", "#..#"],
	"l": ["#.", "#.", "#.", "#.", "#.", "#.", ".#"],
	"m": [".....", ".....", "####.", "#.#.#", "#.#.#", "#.#.#", "#.#.#"],
	"n": [".....", ".....", "####.", "#...#", "#...#", "#...#", "#...#"],
	"o": [".....", ".....", ".###.", "#...#", "#...#", "#...#", ".###."],
	"p": [".....", ".....", "####.", "#...#", "#...#", "#...#", "####.", "#....", "#...."],
	"q": [".....", ".....", ".####", "#...#", "#...#", "#...#", ".####", "....#", "....#"],
	"r": ["....", "....", "#.##", "##..", "#...", "#...", "#..."],
	"s": ["....", "....", ".###", "#...", ".##.", "...#", "###."],
	"t": [".#.", ".#.", "###", ".#.", ".#.", ".#.", "..#"],
	"u": [".....", ".....", "#...#", "#...#", "#...#", "#...#", ".####"],
	"v": [".....", ".....", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"w": [".....", ".....", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
	"x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	"y": [".....", ".....", "#...#", "#...#", "#...#", "#...#", ".####", "....#", ".###."],
	"z": [".....", ".....", "#####", "...#.", "..#..", ".#...", "#####"],
	"{": ["..##", ".#..", ".#..", "#...", ".#..", ".#..", "..##"],
	"|": ["#", "#", "#", "#", "#", "#", "#", "#"],
	"}": ["##..", "..#.", "..#.", "...#", "..#.", "..#.", "##.."],
	"~": [".....", ".....", ".##.#", "#.##."],
	# A few marks the slate uses beyond ASCII.
	"·": [".", ".", ".", "#"],
	"—": [".....", ".....", ".....", "#####"],
	"…": [".....", ".....", ".....", ".....", ".....", ".....", "#.#.#"],
	"×": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	"←": [".....", "..#..", ".#...", "#####", ".#...", "..#.."],
	"→": [".....", "..#..", "...#.", "#####", "...#.", "..#.."],
	"↑": ["..#..", ".###.", "#.#.#", "..#..", "..#..", "..#..", "..#.."],
	"↓": ["..#..", "..#..", "..#..", "..#..", "#.#.#", ".###.", "..#.."],
}

static var _font: FontFile
static var _legacy: FontFile
static var _cut := {}


## The shared FontFile, in base pixels. Built once, on first use.
static func font() -> FontFile:
	if _font == null:
		_font = _build(PITCH, SIZE, ASCENT, DESCENT)
	return _font


## The same face at the old 640x360 size, for the loading page and the gallery.
static func legacy_font() -> FontFile:
	if _legacy == null:
		_legacy = _build(1, LEGACY_SIZE, LEGACY_ASCENT, LEGACY_DESCENT)
	return _legacy


## The rows of one glyph in its SOURCE cell, padded to ROWS; empty for a
## character the font lacks.
static func glyph(ch: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not GLYPHS.has(ch):
		return out
	var rows: Array = GLYPHS[ch]
	var w := glyph_width(ch)
	for r in ROWS:
		var s: String = rows[r] if r < rows.size() else ""
		out.append(s.rpad(w, "."))
	return out


## The rows of one glyph AS IT IS DRAWN: the source cell at PITCH pixels square
## with its diagonal notches filled. ROWS * PITCH rows of `glyph_width * PITCH`.
## This is the face the player actually reads, and what anything drawing its own
## lettering (a rimmed picture, a scratch in the bezel) must use.
static func glyph_cut(ch: String) -> PackedStringArray:
	if _cut.has(ch):
		return _cut[ch]
	var src := glyph(ch)
	var out := PackedStringArray()
	if src.is_empty():
		_cut[ch] = out
		return out
	var w := glyph_width(ch)
	var big: Array[PackedByteArray] = []
	for _r in ROWS * PITCH:
		var row := PackedByteArray()
		row.resize(w * PITCH)
		big.append(row)
	for r in ROWS:
		for x in w:
			if src[r][x] != "#":
				continue
			for dy in PITCH:
				for dx in PITCH:
					big[r * PITCH + dy][x * PITCH + dx] = 1
	_corners(src, big, w)
	for r in big.size():
		var s := ""
		for x in big[r].size():
			s += "#" if big[r][x] == 1 else "."
		out.append(s)
	_cut[ch] = out
	return out


## Fill the notch where a stroke steps sideways, so a diagonal climbs in single
## pixels instead of in PITCH-wide stairs.
##
## For a clear source pixel whose neighbour ACROSS and neighbour DOWN (in one of
## the four corner directions) are both lit while the pixel DIAGONALLY between
## them is clear, the corner nearest those two is filled. That is the whole rule,
## and the two things it deliberately does NOT do are why the face still reads as
## machine-cut rather than as a smoothing filter run over it:
##
##   it never takes ink away, so every stem, bar and terminal keeps the square
##   end it was drawn with — the convex corners of E, H, I, L and T are exactly
##   as they were;
##   it never fires where the diagonal between is already lit, so a solid inner
##   corner is not thickened into a blob.
##
## What it does fire on is a true staircase: the joins in A K M N V W X Z / and \
## close up, and the bowls of C G O S a e o s become eight-sided instead of
## square-cornered. Nothing else in the face moves.
static func _corners(src: PackedStringArray, big: Array[PackedByteArray], w: int) -> void:
	for r in ROWS:
		for x in w:
			if src[r][x] == "#":
				continue
			for dy: int in [-1, 1]:
				for dx: int in [-1, 1]:
					if not _lit(src, x + dx, r, w) or not _lit(src, x, r + dy, w):
						continue
					if _lit(src, x + dx, r + dy, w):
						continue
					var px := x * PITCH + (PITCH - 1 if dx > 0 else 0)
					var py := r * PITCH + (PITCH - 1 if dy > 0 else 0)
					big[py][px] = 1


static func _lit(src: PackedStringArray, x: int, y: int, w: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= src.size():
		return false
	return src[y][x] == "#"


static func glyph_width(ch: String) -> int:
	var w := 0
	for s: String in GLYPHS.get(ch, []):
		w = maxi(w, s.length())
	return w


## Pixel width of a string in BASE pixels: advances summed, less the last gap.
static func width(text: String) -> int:
	return _width(text, PITCH)


## The same in the legacy 640x360 space (the loading page, the gallery).
static func legacy_width(text: String) -> int:
	return _width(text, 1)


static func _width(text: String, unit: int) -> int:
	var w := 0
	for i in text.length():
		var ch := text[i]
		w += ((glyph_width(ch) if GLYPHS.has(ch) else glyph_width("?")) + 1) * unit
	return maxi(0, w - unit)


static func _build(unit: int, size: int, ascent: int, descent: int) -> FontFile:
	var f := FontFile.new()
	f.font_name = "unspent 5x7"
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_NONE
	f.generate_mipmaps = false
	f.multichannel_signed_distance_field = false
	f.fixed_size = size
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.allow_system_fallback = false
	var key := Vector2i(size, 0)
	f.set_cache_ascent(0, size, ascent)
	f.set_cache_descent(0, size, descent)
	f.set_cache_underline_position(0, size, unit)
	f.set_cache_underline_thickness(0, size, unit)

	# One atlas row per 16 glyphs, each cell a guard column wider and a guard row
	# taller than the widest glyph, so no glyph can sample its neighbour.
	var chars: Array = GLYPHS.keys()
	var cols := 16
	var cw := 6 * unit
	var ch_h := (ROWS + 1) * unit
	var img := Image.create_empty(cols * cw, ceili(chars.size() / float(cols)) * ch_h, false, Image.FORMAT_LA8)
	img.fill(Color(1, 1, 1, 0))
	for n in chars.size():
		var c: String = chars[n]
		var rows := glyph_cut(c) if unit > 1 else glyph(c)
		var ox := (n % cols) * cw
		var oy := (n / cols) * ch_h
		for r in rows.size():
			for x in rows[r].length():
				if rows[r][x] == "#":
					img.set_pixel(ox + x, oy + r, Color(1, 1, 1, 1))
	f.set_texture_image(0, key, 0, img)
	for n in chars.size():
		var c: String = chars[n]
		var code := c.unicode_at(0)
		var w := glyph_width(c) * unit
		var ox := (n % cols) * cw
		var oy := (n / cols) * ch_h
		f.set_glyph_texture_idx(0, key, code, 0)
		f.set_glyph_uv_rect(0, key, code, Rect2(ox, oy, w, ROWS * unit))
		f.set_glyph_size(0, key, code, Vector2(w, ROWS * unit))
		# Offset is from the pen on the baseline to the glyph's top-left.
		f.set_glyph_offset(0, key, code, Vector2(0, -(ROWS - 2) * unit))
		f.set_glyph_advance(0, size, code, Vector2(w + unit, 0))
	return f
