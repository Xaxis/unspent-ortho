class_name UiDraw
## Pixel-exact drawing on a CanvasItem at the 1920x1080 base (`UiBase.SIZE`).
## Everything takes whole-pixel positions and draws axis-aligned rects, so
## nothing is ever filtered or lands between pixels. `seed` arguments make
## hand-drawn irregularity repeatable: the same page looks the same every time it
## opens.
##
## Two weights, and the difference is deliberate:
##
##   a RULE (`hline`, `vline`, `frame`) is ONE base pixel. A hairline under
##   14-pixel type is the right hierarchy, and it is what a sharp device looks
##   like; the 3-pixel slabs the slate used to draw are half of why it read as
##   three times magnified.
##   a PIXEL (`px`) is `UiBase.PITCH` square, because it stands for one pixel of
##   the stolen module's own glass — a dead column, a grain of dirt, a dot of a
##   dotted ring. Those are the marks that say this is a pixel device, and a
##   hairline dot would say nothing at all.
##
## `text_legacy` is the old 640x360 face, for the loading page and the gallery
## (see `UiBase`); nothing else may use it.


## Tests hold what is drawn to the rules: while `taping`, every word and every
## rect is noted on `tape` as {kind: &"text"|&"rect", ci, text, rect, col}.
static var taping := false
static var tape: Array[Dictionary] = []


static func _note(kind: StringName, ci: CanvasItem, r: Rect2, col: Color, s: String = "") -> void:
	tape.append({"kind": kind, "ci": ci, "text": s, "rect": r, "col": col})


## Text with its top-left at `at` (the font's line box, UiFont.SIZE tall).
static func text(ci: CanvasItem, at: Vector2i, s: String, col: Color) -> void:
	if taping:
		_note(&"text", ci, Rect2(at.x, at.y, UiFont.width(s), UiFont.SIZE), col, s)
	ci.draw_string(UiFont.font(), Vector2(at.x, at.y + UiFont.ASCENT), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE, col)


## Text right-aligned so its last pixel column is at `right_x - 1`.
static func text_right(ci: CanvasItem, right_x: int, y: int, s: String, col: Color) -> void:
	text(ci, Vector2i(right_x - UiFont.width(s), y), s, col)


static func text_centred(ci: CanvasItem, centre_x: int, y: int, s: String, col: Color) -> void:
	text(ci, Vector2i(centre_x - UiFont.width(s) / 2, y), s, col)


## The same face at the old 640x360 size, on a layer still scaled by
## `UiBase.fit`: the loading page and the gallery, and nothing else.
static func text_legacy(ci: CanvasItem, at: Vector2i, s: String, col: Color) -> void:
	if taping:
		_note(&"text", ci, Rect2(at.x, at.y, UiFont.legacy_width(s), UiFont.LEGACY_SIZE), col, s)
	ci.draw_string(UiFont.legacy_font(), Vector2(at.x, at.y + UiFont.LEGACY_ASCENT), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.LEGACY_SIZE, col)


static func text_right_legacy(ci: CanvasItem, right_x: int, y: int, s: String, col: Color) -> void:
	text_legacy(ci, Vector2i(right_x - UiFont.legacy_width(s), y), s, col)


## Text with a rim on all eight sides `UiBase.PITCH` deep: reads over any ground.
static func text_rimmed(ci: CanvasItem, at: Vector2i, s: String, fill: Color, rim: Color) -> void:
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		text(ci, at + d * UiBase.PITCH, s, rim)
	text(ci, at, s, fill)


static func rect(ci: CanvasItem, r: Rect2i, col: Color) -> void:
	if taping:
		_note(&"rect", ci, Rect2(r), col)
	ci.draw_rect(Rect2(r), col, true)


static func frame(ci: CanvasItem, r: Rect2i, col: Color) -> void:
	hline(ci, r.position.x, r.end.x - 1, r.position.y, col)
	hline(ci, r.position.x, r.end.x - 1, r.end.y - 1, col)
	vline(ci, r.position.x, r.position.y, r.end.y - 1, col)
	vline(ci, r.end.x - 1, r.position.y, r.end.y - 1, col)


static func hline(ci: CanvasItem, x0: int, x1: int, y: int, col: Color) -> void:
	if x1 < x0:
		return
	ci.draw_rect(Rect2(x0, y, x1 - x0 + 1, 1), col, true)


static func vline(ci: CanvasItem, x: int, y0: int, y1: int, col: Color) -> void:
	if y1 < y0:
		return
	ci.draw_rect(Rect2(x, y0, 1, y1 - y0 + 1), col, true)


## One pixel of the module's glass: PITCH square, drawn from `x, y`.
static func px(ci: CanvasItem, x: int, y: int, col: Color) -> void:
	ci.draw_rect(Rect2(x, y, UiBase.PITCH, UiBase.PITCH), col, true)


## One pixel of the LEGACY 640x360 space, on a layer still scaled by `UiBase.fit`.
static func px_legacy(ci: CanvasItem, x: int, y: int, col: Color) -> void:
	ci.draw_rect(Rect2(x, y, 1, 1), col, true)


## A line ruled by hand: it drifts one pixel up or down once or twice along its
## length and its ends are not quite square. thickness 1 or 2.
static func hand_hline(ci: CanvasItem, x0: int, x1: int, y: int, col: Color, seed: int, thickness: int = 1) -> void:
	var len := x1 - x0 + 1
	if len <= 0:
		return
	var jog1 := x0 + int(len * (0.25 + 0.3 * _h(seed, 1)))
	var jog2 := x0 + int(len * (0.6 + 0.3 * _h(seed, 2)))
	var d1 := -1 if _h(seed, 3) < 0.5 else 1
	var d2 := 0 if _h(seed, 4) < 0.5 else -d1
	var start := x0 + (1 if _h(seed, 5) < 0.4 else 0)
	var end := x1 - (1 if _h(seed, 6) < 0.4 else 0)
	for t in thickness:
		hline(ci, start, jog1 - 1, y + t, col)
		hline(ci, jog1, jog2 - 1, y + t + d1, col)
		hline(ci, jog2, end, y + t + d1 + d2, col)


## A vertical hand-ruled line, same idea.
static func hand_vline(ci: CanvasItem, x: int, y0: int, y1: int, col: Color, seed: int) -> void:
	var len := y1 - y0 + 1
	if len <= 0:
		return
	var jog := y0 + int(len * (0.35 + 0.3 * _h(seed, 7)))
	var d := -1 if _h(seed, 8) < 0.5 else 1
	vline(ci, x, y0, jog - 1, col)
	vline(ci, x + d, jog, y1, col)


## A small pixel sprite from rows of characters; each character maps to a
## colour in `colours` (missing = transparent). `scale` is base pixels to one
## pixel of the sprite, and whole.
static func sprite(ci: CanvasItem, rows: Array, at: Vector2i, colours: Dictionary, scale: int = UiBase.PITCH) -> void:
	for r in rows.size():
		var row: String = rows[r]
		var x := 0
		while x < row.length():
			var ch := row[x]
			if not colours.has(ch):
				x += 1
				continue
			# Merge horizontal runs of one colour into one rect.
			var run := 1
			while x + run < row.length() and row[x + run] == ch:
				run += 1
			ci.draw_rect(Rect2(at.x + x * scale, at.y + r * scale, run * scale, scale), colours[ch], true)
			x += run


## A sprite with a rim of `rim` one sprite pixel deep around every opaque pixel.
static func sprite_rimmed(ci: CanvasItem, rows: Array, at: Vector2i, colours: Dictionary, rim: Color, scale: int = UiBase.PITCH) -> void:
	var mask := {}
	for ch: String in colours:
		mask[ch] = rim
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		sprite(ci, rows, at + d * scale, mask, scale)
	sprite(ci, rows, at, colours, scale)


## How many steps a fade takes: a fading line of HUD text holds each for a
## moment rather than sliding, so it reads as drawn, not as a video dissolve.
const FADE_STEPS := 4

static var _pictures := {}


## A fade level stepped to FADE_STEPS: 0 < a < 1 rounds up, so it is gone only at 0.
static func stepped(a: float) -> float:
	if a <= 0.0:
		return 0.0
	return minf(1.0, ceilf(a * FADE_STEPS - 0.001) / FADE_STEPS)


## Rimmed text at fade `a`. Opaque, it is drawn as text_rimmed. Fading, it is
## one picture laid down once at a stepped alpha: drawn as nine translucent
## passes, the rim piles up where passes overlap and smears grey.
static func text_rimmed_faded(ci: CanvasItem, at: Vector2i, s: String, fill: Color, rim: Color, a: float) -> void:
	var k := stepped(a)
	if k <= 0.0 or s == "":
		return
	if k >= 1.0:
		text_rimmed(ci, at, s, fill, rim)
		return
	ci.draw_texture(text_picture(s, fill, rim), Vector2(at.x - UiBase.PITCH, at.y), Color(1, 1, 1, k))


## A rimmed sprite at fade `a`, the same way (a need glyph fading in or out).
static func sprite_rimmed_faded(ci: CanvasItem, rows: Array, at: Vector2i, colours: Dictionary, rim: Color, a: float) -> void:
	var k := stepped(a)
	if k <= 0.0:
		return
	if k >= 1.0:
		sprite_rimmed(ci, rows, at, colours, rim)
		return
	var tex := picture("s|%s|%s|%s" % [str(rows), str(colours), rim.to_html()], rows, colours, rim, false, 1)
	ci.draw_texture_rect(tex, Rect2(Vector2(at - Vector2i.ONE * UiBase.PITCH), Vector2(tex.get_size()) * UiBase.PITCH), false, Color(1, 1, 1, k))


## Text and its eight-way rim as one texture, at the face's own resolution
## (`UiFont.glyph_cut`). Drawn at text()'s `at` less one rim, its glyphs land
## exactly where text() puts them: the face sets a glyph's top two rows under the
## box, and the picture's two rim rows fill them.
static func text_picture(s: String, fill: Color, rim: Color) -> ImageTexture:
	var rows := PackedStringArray()
	rows.resize(UiFont.ROWS * UiBase.PITCH)
	for i in s.length():
		var g := UiFont.glyph_cut(s[i])
		if g.is_empty():
			g = UiFont.glyph_cut("?")
		for r in rows.size():
			rows[r] += ("".rpad(UiBase.PITCH, " ") if i > 0 else "") + g[r]
	return picture("t|%s|%s|%s" % [s, fill.to_html(), rim.to_html()], rows, {"#": fill}, rim, true, UiBase.PITCH)


## Rows of characters (colours by character) with a rim `pad` deep, as a cached
## texture that much bigger on every side. `eight` rims the corners too. `pad` is
## in the ROWS' own pixels: PITCH for lettering, which is already cut at the
## face's resolution, and 1 for a sprite, which is drawn scaled.
static func picture(key: String, rows: Array, colours: Dictionary, rim: Color, eight: bool, pad: int = 1) -> ImageTexture:
	if _pictures.has(key):
		return _pictures[key]
	if _pictures.size() > 96:
		_pictures.clear()
	var w := 0
	for row: String in rows:
		w = maxi(w, row.length())
	var h := rows.size()
	var img := Image.create_empty(w + pad * 2, h + pad * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for r in h:
		var row: String = rows[r]
		for x in row.length():
			if not colours.has(row[x]):
				continue
			for dy in range(-pad, pad + 1):
				for dx in range(-pad, pad + 1):
					if dx == 0 and dy == 0:
						continue
					if not eight and dx != 0 and dy != 0:
						continue
					img.set_pixel(x + pad + dx, r + pad + dy, rim)
	for r in h:
		var row: String = rows[r]
		for x in row.length():
			if colours.has(row[x]):
				img.set_pixel(x + pad, r + pad, colours[row[x]])
	var tex := ImageTexture.create_from_image(img)
	_pictures[key] = tex
	return tex


static func _h(seed: int, salt: int) -> float:
	return Rng.hash01(seed, salt, 7, 0x51)
