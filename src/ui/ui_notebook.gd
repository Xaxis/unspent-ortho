class_name UiNotebook
## The notebook itself: cloth cover, linen pages ruled by hand, a rust margin,
## grain, thumbed corners, a ribbon. Every screen is written on these pages.
## Layout constants are shared so all screens line up on the same rules.

## The open book across the screen: cover, then two pages meeting at the gutter.
const COVER := Rect2i(16, 10, 608, 342)
const LEFT := Rect2i(22, 14, 296, 331)
const RIGHT := Rect2i(322, 14, 296, 331)
## A single page centred (pause, keys).
const SINGLE := Rect2i(204, 40, 232, 280)

## First ruled line below a page's top edge, then one every UiTheme.LINE.
const FIRST_RULE := 36
## Left margin, where the rust line runs.
const MARGIN_X := 22
const BOTTOM_KEEP := 20


## Dim the world under the book.
static func veil(ci: CanvasItem) -> void:
	UiDraw.rect(ci, Rect2i(0, 0, 640, 360), UiTheme.VEIL)


## The open book. Returns nothing; pages are LEFT and RIGHT.
static func spread(ci: CanvasItem, seed: int) -> void:
	veil(ci)
	_cover(ci, COVER)
	page(ci, LEFT, seed * 31 + 1, true, true)
	page(ci, RIGHT, seed * 31 + 2, true, false)
	# The gutter: the pages curve into the binding.
	var gx := LEFT.end.x
	UiDraw.rect(ci, Rect2i(gx, LEFT.position.y, RIGHT.position.x - gx, LEFT.size.y), UiTheme.PAPER_DEEP)
	for i in 4:
		var a := 0.42 - i * 0.1
		UiDraw.vline(ci, gx - 1 - i, LEFT.position.y, LEFT.end.y - 1, Color(UiTheme.PAPER_EDGE, a))
		UiDraw.vline(ci, RIGHT.position.x + i, RIGHT.position.y, RIGHT.end.y - 1, Color(UiTheme.PAPER_EDGE, a * 0.8))
	UiDraw.vline(ci, gx + 1, LEFT.position.y, LEFT.end.y - 1, UiTheme.PAPER_EDGE)
	# Stitches through the fold.
	var y := LEFT.position.y + 22
	while y < LEFT.end.y - 16:
		UiDraw.vline(ci, gx + 1, y, y + 4, UiTheme.INK_SOFT)
		y += 38
	_ribbon(ci, gx + 1, seed)


## A single loose page with a cover edge behind it.
static func single(ci: CanvasItem, r: Rect2i, seed: int) -> void:
	veil(ci)
	_cover(ci, r.grow(5))
	page(ci, r, seed, true, true)


## One page: paper, grain, hand-ruled lines, optionally the margin line.
static func page(ci: CanvasItem, r: Rect2i, seed: int, ruled: bool, margin: bool) -> void:
	# The stack of pages under this one shows at the bottom and outer edge.
	UiDraw.hline(ci, r.position.x + 1, r.end.x - 2, r.end.y, UiTheme.PAPER_DEEP)
	UiDraw.hline(ci, r.position.x + 2, r.end.x - 3, r.end.y + 1, UiTheme.PAPER_EDGE)
	UiDraw.rect(ci, r, UiTheme.PAPER)
	# Slow tone: a few broad, faint washes, so the paper is not a flat fill.
	for i in 7:
		var w := 40 + int(_h(seed, i, 1) * 120)
		var hgt := 20 + int(_h(seed, i, 2) * 70)
		var x := r.position.x + int(_h(seed, i, 3) * (r.size.x - w))
		var y := r.position.y + int(_h(seed, i, 4) * (r.size.y - hgt))
		UiDraw.rect(ci, Rect2i(x, y, w, hgt), Color(UiTheme.PAPER_SHADE, 0.07))
	# Grain.
	var specks := r.size.x * r.size.y / 55
	for i in specks:
		var x := r.position.x + int(_h(seed, i, 5) * r.size.x)
		var y := r.position.y + int(_h(seed, i, 6) * r.size.y)
		var dark := _h(seed, i, 7) < 0.8
		UiDraw.px(ci, x, y, Color(UiTheme.PAPER_SHADE, 0.55) if dark else Color(1, 1, 0.94, 0.5))
	if ruled:
		var y := r.position.y + FIRST_RULE
		var n := 0
		while y < r.end.y - BOTTOM_KEEP:
			UiDraw.hand_hline(ci, r.position.x + 3, r.end.x - 4, y, UiTheme.RULE, seed * 7 + n)
			y += UiTheme.LINE
			n += 1
	if margin:
		UiDraw.hand_vline(ci, r.position.x + MARGIN_X, r.position.y, r.end.y - 1, Color(UiTheme.ACCENT, 0.5), seed + 3)
	# Thumbed bottom corners and a darker outer edge.
	UiDraw.frame(ci, r, Color(UiTheme.PAPER_DEEP, 0.55))
	for c: int in [0, 1]:
		var cx := r.position.x if c == 0 else r.end.x - 1
		var dir := 1 if c == 0 else -1
		for i in 14:
			var x := cx + dir * int(_h(seed, i, 10 + c) * 9.0)
			var y := r.end.y - 1 - int(_h(seed, i, 12 + c) * 7.0)
			UiDraw.px(ci, x, y, Color(UiTheme.PAPER_DEEP, 0.45))
		UiDraw.px(ci, cx, r.end.y - 1, UiTheme.PAPER_EDGE)
	# The rubbed-bright top edge.
	UiDraw.hline(ci, r.position.x + 1, r.end.x - 2, r.position.y, Color(1, 0.98, 0.9, 0.55))


## y of the n-th ruled line (0 = first) on a page.
static func rule_y(r: Rect2i, n: int) -> int:
	return r.position.y + FIRST_RULE + n * UiTheme.LINE


## Top of text that sits on the n-th rule (its baseline is the rule).
static func line_top(r: Rect2i, n: int) -> int:
	return rule_y(r, n) - UiFont.ASCENT


## How many ruled lines fit on a page.
static func rule_count(r: Rect2i) -> int:
	return (r.size.y - FIRST_RULE - BOTTOM_KEEP) / UiTheme.LINE + 1


## Lower-case title, written in the head space, underlined twice by hand.
static func title(ci: CanvasItem, r: Rect2i, text: String, seed: int) -> void:
	var x := r.position.x + MARGIN_X + 6
	var y := r.position.y + 11
	UiDraw.text(ci, Vector2i(x, y), text, UiTheme.INK)
	var w := UiFont.width(text)
	UiDraw.hand_hline(ci, x - 2, x + w + 5, y + 11, UiTheme.INK, seed, 1)
	UiDraw.hand_hline(ci, x + 1, x + w + 12, y + 13, Color(UiTheme.INK, 0.6), seed + 1, 1)


## Fixed words at the foot of a page, ending with esc.
static func footer(ci: CanvasItem, r: Rect2i, words: String) -> void:
	UiDraw.text(ci, Vector2i(r.position.x + MARGIN_X + 6, r.end.y - 14), words, UiTheme.FADED)


## A note at the foot of a page (right-aligned), fading in the last second.
static func note(ci: CanvasItem, r: Rect2i, text: String, age: float) -> void:
	if text == "" or age > 4.0:
		return
	var a := clampf(4.0 - age, 0.0, 1.0)
	UiDraw.text_right(ci, r.end.x - 10, r.end.y - 14, text, Color(UiTheme.ACCENT, a))


## "> " in the accent, before the chosen row.
static func cursor(ci: CanvasItem, x: int, top: int) -> void:
	UiDraw.text(ci, Vector2i(x, top), ">", UiTheme.ACCENT)


## A hand-drawn box.
static func box(ci: CanvasItem, r: Rect2i, col: Color, seed: int) -> void:
	UiDraw.hand_hline(ci, r.position.x, r.end.x - 1, r.position.y, col, seed)
	UiDraw.hand_hline(ci, r.position.x + 1, r.end.x, r.end.y - 1, col, seed + 1)
	UiDraw.vline(ci, r.position.x, r.position.y + 1, r.end.y - 2, col)
	UiDraw.vline(ci, r.end.x - 1, r.position.y + 1, r.end.y - 1, col)


## A strip of tape holding something to the page.
static func tape(ci: CanvasItem, at: Vector2i, w: int) -> void:
	UiDraw.rect(ci, Rect2i(at.x, at.y, w, 6), Color(UiTheme.PAPER_SHADE, 0.7))
	UiDraw.hline(ci, at.x, at.x + w - 1, at.y + 5, Color(UiTheme.PAPER_DEEP, 0.5))
	for i in range(0, w, 3):
		UiDraw.px(ci, at.x + i, at.y, Color(UiTheme.PAPER, 0.9))


static func _cover(ci: CanvasItem, r: Rect2i) -> void:
	UiDraw.rect(ci, r.grow(1), UiTheme.INK_DEEP)
	UiDraw.rect(ci, r, UiTheme.COVER)
	# Worn cloth: the rubbed edge along the top and the corners gone pale.
	UiDraw.hline(ci, r.position.x + 2, r.end.x - 3, r.position.y, UiTheme.COVER_LIGHT)
	for i in 3:
		UiDraw.px(ci, r.position.x + i, r.position.y, UiTheme.COVER_LIGHT)
		UiDraw.px(ci, r.end.x - 1 - i, r.end.y - 1, UiTheme.COVER_LIGHT)


static func _ribbon(ci: CanvasItem, x: int, seed: int) -> void:
	var top := COVER.end.y - 40
	var bottom := COVER.end.y + 5
	UiDraw.rect(ci, Rect2i(x - 1, top, 4, bottom - top), UiTheme.ACCENT)
	UiDraw.vline(ci, x - 1, top, bottom - 1, Palette.RUST[2])
	UiDraw.vline(ci, x + 2, top, bottom - 1, Palette.RUST[4])
	# A notched end.
	UiDraw.rect(ci, Rect2i(x - 1, bottom, 1, 2), UiTheme.ACCENT)
	UiDraw.rect(ci, Rect2i(x + 2, bottom, 1, 2), UiTheme.ACCENT)
	UiDraw.px(ci, x, bottom, UiTheme.ACCENT)
	UiDraw.px(ci, x + 1, bottom, UiTheme.ACCENT)


static func _h(seed: int, i: int, salt: int) -> float:
	return Rng.hash01(seed, i, salt, 0x0b00c)
