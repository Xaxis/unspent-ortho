class_name UiDraw
## Pixel-exact drawing on a CanvasItem at the 640x360 base. Everything takes
## whole-pixel positions and draws axis-aligned rects, so nothing is ever
## filtered or lands between pixels. `seed` arguments make hand-drawn
## irregularity repeatable: the same page looks the same every time it opens.


## Text with its top-left at `at` (the font's line box, 10 px tall).
static func text(ci: CanvasItem, at: Vector2i, s: String, col: Color) -> void:
	ci.draw_string(UiFont.font(), Vector2(at.x, at.y + UiFont.ASCENT), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE, col)


## Text right-aligned so its last pixel column is at `right_x - 1`.
static func text_right(ci: CanvasItem, right_x: int, y: int, s: String, col: Color) -> void:
	text(ci, Vector2i(right_x - UiFont.width(s), y), s, col)


static func text_centred(ci: CanvasItem, centre_x: int, y: int, s: String, col: Color) -> void:
	text(ci, Vector2i(centre_x - UiFont.width(s) / 2, y), s, col)


## Text with a one-pixel rim on all eight sides: reads over any ground.
static func text_rimmed(ci: CanvasItem, at: Vector2i, s: String, fill: Color, rim: Color) -> void:
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		text(ci, at + d, s, rim)
	text(ci, at, s, fill)


static func rect(ci: CanvasItem, r: Rect2i, col: Color) -> void:
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


static func px(ci: CanvasItem, x: int, y: int, col: Color) -> void:
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
## colour in `colours` (missing = transparent). scale is a whole number.
static func sprite(ci: CanvasItem, rows: Array, at: Vector2i, colours: Dictionary, scale: int = 1) -> void:
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


## A sprite with a one-pixel rim of `rim` around every opaque pixel (at 1x).
static func sprite_rimmed(ci: CanvasItem, rows: Array, at: Vector2i, colours: Dictionary, rim: Color) -> void:
	var mask := {}
	for ch: String in colours:
		mask[ch] = rim
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		sprite(ci, rows, at + d, mask)
	sprite(ci, rows, at, colours)


static func _h(seed: int, salt: int) -> float:
	return Rng.hash01(seed, salt, 7, 0x51)
