class_name UiPickupFeed
extends CanvasLayer
## What was just taken, on the HUD's edge: the thing as the slate scans it, how
## many, and what it is called (owner, 2026-09-17). A row stands a moment and fades; taking
## the same thing again while its row still stands adds to that row rather than
## stacking a second one, so a run of stones reads as "+6 stone", not six lines.
##
## The rows are data (`rows`, `add`, `step`, `alpha_of`) so a test can run the feed
## without a frame; the drawing below them is the HUD's idiom, laid out in the
## slate's design units (`UiBase`) from the HUD's own margin.

## Seconds a row stands at full strength, and then fades over.
const HOLD := 2.6
const FADE := 0.9
## The most rows at once: the oldest goes when a new one comes.
const MOST := 4
## A thing taken again inside this long adds to its standing row.
const MERGE := HOLD
## Each row shows the thing as the slate scans it (UiSketch, the carrying page's
## own drawing) at this many pixels square: at 9 a stone and a lump of coal are the
## same disc, and at 20 a copper vein, a whelk's whorls and the fork in a tuft of
## crottle still read, where at 16 they had begun to close up.
const SKETCH := 20
## One row's height and the gap between rows, and how far above the held-item
## window the stack stands.
const ROW := SKETCH + 2
const GAP := 3
const ABOVE_HELD := 17

## [{item: StringName, count: int, age: float}] oldest first.
var rows: Array[Dictionary] = []
var _canvas: Control


func _ready() -> void:
	layer = 10
	UiBase.fit(self)
	_canvas = Control.new()
	_canvas.name = "pickup_feed"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_feed)
	add_child(_canvas)


func add(item: StringName, count: int) -> void:
	for r in rows:
		if r.item == item and float(r.age) < MERGE:
			r.count = int(r.count) + count
			r.age = 0.0
			# The row that just grew moves to the bottom, where the eye already is.
			rows.erase(r)
			rows.append(r)
			return
	rows.append({"item": item, "count": count, "age": 0.0})
	while rows.size() > MOST:
		rows.remove_at(0)


func step(delta: float) -> void:
	for r in rows:
		r.age = float(r.age) + delta
	rows = rows.filter(func(r: Dictionary) -> bool: return float(r.age) < HOLD + FADE)


static func alpha_of(r: Dictionary) -> float:
	var age := float(r.age)
	if age <= HOLD:
		return 1.0
	return clampf(1.0 - (age - HOLD) / FADE, 0.0, 1.0)


## The words of a row: "+2 stone", "+3 pieces of plate", "+1 piece of plate".
static func words_of(r: Dictionary) -> String:
	var n := int(r.count)
	return "+%d %s" % [n, UiRules.bare(UiRules.list_name(StringName(r.item), n))]


func _process(delta: float) -> void:
	if rows.is_empty():
		return
	step(delta)
	_canvas.queue_redraw()


func _draw_feed() -> void:
	if rows.is_empty():
		return
	var x := Hud.MARGIN + 6
	var bottom := UiBase.DESIGN.y - Hud.MARGIN - ABOVE_HELD
	for i in rows.size():
		var r: Dictionary = rows[rows.size() - 1 - i]
		var a := UiDraw.stepped(alpha_of(r))
		if a <= 0.0:
			continue
		var id := StringName(r.item)
		var text := words_of(r)
		var box := Rect2i(x, bottom - (ROW + GAP) * (i + 1) + GAP, SKETCH + 6 + UiFont.width(text) + 4, ROW)
		_panel(box, a)
		_canvas.draw_texture(UiSketch.item_texture(id, SKETCH), Vector2(box.position + Vector2i(1, 1)), Color(1, 1, 1, a))
		var ink := UiTheme.MACHINE[3] if UiIcons.is_found(id) else UiTheme.TEXT
		UiDraw.text_rimmed_faded(_canvas, Vector2i(box.position.x + SKETCH + 4, box.position.y + (ROW - 9) / 2), text, ink, UiTheme.RIM, a)


## A strip of the slate's glass in its salvaged frame, as the held-item window is
## (Hud.clip), with no strap or tape: a stack of four would be all buckle.
func _panel(r: Rect2i, a: float) -> void:
	UiDraw.rect(_canvas, r.grow(2), Color(UiTheme.RIM, a))
	UiDraw.frame(_canvas, r.grow(1), Color(Palette.FOUND[1], a))
	UiDraw.hline(_canvas, r.position.x, r.end.x - 1, r.position.y - 1, Color(Palette.FOUND[3], a))
	UiDraw.rect(_canvas, r, Color(UiTheme.GLASS, a))
	for y in range(r.position.y + 1, r.end.y, 2):
		UiDraw.hline(_canvas, r.position.x, r.end.x - 1, y, Color(UiTheme.GLASS_ROW, a))
