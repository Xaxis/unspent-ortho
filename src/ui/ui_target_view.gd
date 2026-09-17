class_name UiTargetView
extends CanvasLayer
## What targeting draws (owner, 2026-09-16): the tag every body carries, the
## brackets and ring on the one being read, and the slate's read of it.
##
## Two tiers, so a fight is not covered in words:
##   always   every body on screen carries a wordless tag — health pips and one
##            glyph for how much it has noticed the player
##   held     the locked body is bracketed and ringed, and the slate says in
##            words what it is, what it can do, what it has noticed and what it
##            is thinking; a sweep says the short of it for the whole field
##
## Machine-sourced data is the stolen module's violet (docs/ART.md §9); what the
## player reads off a living creature with their own eyes is the slate's
## phosphor, since the module reads no creature's signature (SlateFeeds).

## The tag: pips PIP_W wide with a gap, then the notice glyph.
const PIP_W := 2
const PIP_H := 4
const PIP_GAP := 1
const GLYPH := 5
const TAG_LIFT := 5
## The read panel on the right edge, under the clock.
const PANEL := Rect2i(438, 46, 194, 140)
const SWEEP_PANEL := Rect2i(438, 46, 194, 122)
## Rows of the read, at most, so the panel never pushes a line off its own glass.
const STATS_MOST := 5
const POWERS_MOST := 2
## A body further than this from the player is tagged but never named.
const NAME_REACH := 14.0
## The scan line that runs down a locked body's brackets (seconds).
const SCAN_SECONDS := 1.3

var game: Game
var _canvas: Control
var _t := 0.0


func _ready() -> void:
	layer = 11
	_canvas = Control.new()
	_canvas.name = "marks"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = UiTheme.theme()
	_canvas.draw.connect(_draw_marks)
	add_child(_canvas)


func _process(delta: float) -> void:
	_t += delta
	_canvas.queue_redraw()


func _system() -> Node:
	return get_parent()


## Where a body stands on the glass: the ground under it, and the top of it.
func _screen_of(m: MobState) -> Array:
	var cam := game.camera
	var base := game.world.to_3d(m.pos)
	var top := base + Vector3(0.0, float(m.row.get("height", 1.0)), 0.0)
	return [cam.unproject_position(base).round(), cam.unproject_position(top).round()]


func _on_glass(p: Vector2) -> bool:
	return p.x > -40.0 and p.x < 680.0 and p.y > -40.0 and p.y < 400.0


## The stolen module's violet for a machine's signature, the slate's phosphor for
## a creature read by eye. Never the palest step: a tag over the world has to sit
## under the words the slate says, not over them (docs/ART.md §5).
func _ink(machine: bool, lit: bool = true) -> Color:
	if machine:
		return UiTheme.MACHINE[3] if lit else UiTheme.MACHINE[2]
	return UiTheme.TEXT if lit else UiTheme.TEXT_DIM


func _draw_marks() -> void:
	if game == null or game.world == null or game.player == null or game.camera == null:
		return
	if not game.open_screens.is_empty() or not game.camera.is_inside_tree():
		return
	var sim := game.player.sim
	if sim == null:
		return
	var sys := _system()
	var locked: MobState = sys.get("locked")
	var field: Array = sys.get("field")
	var now := sim.now
	for m in sim.mobs:
		if not m.alive or m.removed:
			continue
		var at := _screen_of(m)
		if not _on_glass(at[1]):
			continue
		_draw_tag(m, at[1], TargetRead.tag(m, now), m == locked)
	if locked != null:
		_draw_lock(locked)
		_draw_read(sys.get("read"))
	elif bool(sys.get("sweeping")):
		_draw_sweep(sys.get("rows"), field)


## The wordless tag above a body: its health in pips, and one glyph for how far
## it has got with the player (nothing, stirring, sure, coming).
func _draw_tag(m: MobState, top: Vector2, tag: Dictionary, lit: bool) -> void:
	var pips: Array = tag.pips
	var machine := bool(tag.machine)
	var width := TargetRead.PIPS * (PIP_W + PIP_GAP) - PIP_GAP + 3 + GLYPH
	var x := int(top.x) - width / 2
	var y := int(top.y) - TAG_LIFT - PIP_H
	var full := int(pips[0])
	var part := float(pips[1])
	# Dead glass behind it: pips over grass at noon are the same value as the grass.
	UiDraw.rect(_canvas, Rect2i(x - 2, y - 2, width + 4, PIP_H + 4), UiTheme.RIM)
	for i in TargetRead.PIPS:
		var cell := Rect2i(x + i * (PIP_W + PIP_GAP), y, PIP_W, PIP_H)
		var col := UiTheme.GHOST
		if i < full:
			col = _ink(machine, lit)
		elif i == full and part > 0.25:
			col = UiTheme.MACHINE[2] if machine else UiTheme.TEXT_DIM
		UiDraw.rect(_canvas, cell, col)
	_draw_notice(Vector2i(x + TargetRead.PIPS * (PIP_W + PIP_GAP) + 2, y - 1), int(tag.notice), machine, lit)


## The notice glyph, 5x5: a hollow ring for a body that has noticed nothing, a
## ring with a point for one that is wondering, a filled one for a body that is
## sure, and a filled one with a chevron for one that is coming.
func _draw_notice(at: Vector2i, notice: int, machine: bool, lit: bool) -> void:
	var col := _ink(machine, lit) if notice > 0 else (UiTheme.MACHINE[2] if machine else UiTheme.TEXT_DIM)
	if notice >= 3:
		col = UiTheme.WARN
	UiDraw.hline(_canvas, at.x + 1, at.x + 3, at.y, col)
	UiDraw.hline(_canvas, at.x + 1, at.x + 3, at.y + 4, col)
	UiDraw.vline(_canvas, at.x, at.y + 1, at.y + 3, col)
	UiDraw.vline(_canvas, at.x + 4, at.y + 1, at.y + 3, col)
	if notice == 1:
		UiDraw.px(_canvas, at.x + 2, at.y + 2, col)
	elif notice >= 2:
		UiDraw.rect(_canvas, Rect2i(at.x + 1, at.y + 1, 3, 3), col)
	if notice >= 3:
		# The chevron of something on its way to you.
		for k in 3:
			UiDraw.px(_canvas, at.x + 6 + k, at.y + k, col)
			UiDraw.px(_canvas, at.x + 6 + k, at.y + 4 - k, col)


## The locked body: corner brackets round it, a ring on the ground it stands on,
## and a scan line running down the brackets while the slate reads it.
func _draw_lock(m: MobState) -> void:
	var at := _screen_of(m)
	var base: Vector2 = at[0]
	var top: Vector2 = at[1]
	var half := maxf(9.0, absf(base.y - top.y) * 0.45)
	var box := Rect2i(int(base.x - half), int(top.y) - 3, int(half * 2.0), int(base.y - top.y) + 6)
	var col := _ink(m.machine)
	# A dark bracket under the bright one: the corners have to hold against grass
	# at noon as well as against snow (docs/ART.md §5).
	UiSlate.brackets(_canvas, box.grow(1), UiTheme.RIM, maxi(5, box.size.y / 4))
	UiSlate.brackets(_canvas, box, col, maxi(4, box.size.y / 4))
	var t := fmod(_t, SCAN_SECONDS) / SCAN_SECONDS
	var line := box.position.y + roundi(t * box.size.y)
	UiDraw.hline(_canvas, box.position.x + 1, box.end.x - 2, line, Color(col, 0.45))
	_draw_ring(m, col)


## A ring on the ground, drawn through the camera so it lies on the world: the
## body's own radius, a ring of points rather than a disc, so it never covers
## what it is round.
func _draw_ring(m: MobState, col: Color) -> void:
	var cam := game.camera
	var r := maxf(0.45, float(m.row.get("radius", 0.5)) + 0.25)
	var base := game.world.to_3d(m.pos)
	var was := Vector2.ZERO
	for i in range(0, 25):
		var a := i * TAU / 24.0
		var p := cam.unproject_position(base + Vector3(cos(a) * r, 0.02, sin(a) * r)).round()
		if i > 0 and p.distance_to(was) < 40.0:
			_dotted(was, p, col)
		was = p


## A line of every other pixel between two points: a ring that reads as drawn.
func _dotted(a: Vector2, b: Vector2, col: Color) -> void:
	var steps := maxi(1, int(a.distance_to(b)))
	for i in range(0, steps + 1, 2):
		var p := a.lerp(b, float(i) / float(steps))
		UiDraw.px(_canvas, int(p.x), int(p.y), col)


## The read: what the body is, what it can do, what it has noticed, what it is
## thinking. Words, because the player is holding the key that asks for them.
func _draw_read(read: Dictionary) -> void:
	if read.is_empty():
		return
	var machine := bool(read.machine)
	var r := PANEL
	Hud.clip(_canvas, r, false)
	var x := r.position.x + 5
	var y := r.position.y + 3
	var title := "%s  %s" % [String(read.name).to_upper(), read.role]
	UiDraw.text(_canvas, Vector2i(x, y), _fit(title, r.size.x - 10), _ink(machine))
	y += 11
	y = _draw_pips_line(x, y, read, machine)
	# Laid out in order and cut to what fits, so the last two lines — what it has
	# noticed and what it is doing about it — always have their room.
	var stats: Array = read.stats
	for i in mini(stats.size(), STATS_MOST):
		var s: Array = stats[i]
		UiDraw.text(_canvas, Vector2i(x, y), str(s[0]), UiTheme.TEXT_DIM)
		UiDraw.text_right(_canvas, r.end.x - 5, y, _fit(str(s[1]), r.size.x - 48), UiTheme.TEXT)
		y += 10
	var powers: PackedStringArray = read.powers
	for i in mini(powers.size(), POWERS_MOST):
		UiDraw.text(_canvas, Vector2i(x, y), _fit(powers[i], r.size.x - 10), UiTheme.MACHINE[3] if machine else UiTheme.TEXT_DIM)
		y += 10
	# The last two lines are anchored: what it has noticed and what it is doing
	# about it are the whole point of the panel, and they never move about.
	var aware: Dictionary = read.awareness
	y = maxi(y, r.end.y - 37)
	UiDraw.hline(_canvas, x, r.end.x - 5, y - 3, UiTheme.GHOST)
	UiDraw.text(_canvas, Vector2i(x, y), _fit(str(aware.word), r.size.x - 10), UiTheme.WARN if bool(aware.sure) else UiTheme.TEXT_DIM)
	UiDraw.text(_canvas, Vector2i(x, y + 11), _fit(str(read.thinking), r.size.x - 10), UiTheme.BRIGHT)
	_draw_keys(r, false)


func _draw_pips_line(x: int, y: int, read: Dictionary, machine: bool) -> int:
	var pips: Array = read.pips
	var full := int(pips[0])
	for i in TargetRead.PIPS:
		var col := UiTheme.GHOST
		if i < full:
			col = _ink(machine)
		elif i == full and float(pips[1]) > 0.25:
			col = UiTheme.MACHINE[2] if machine else UiTheme.TEXT_DIM
		UiDraw.rect(_canvas, Rect2i(x + i * 5, y + 1, 4, 7), col)
	UiDraw.text(_canvas, Vector2i(x + TargetRead.PIPS * 5 + 6, y), "%d of %d" % [int(read.health), int(read.max_health)], UiTheme.TEXT)
	UiDraw.text_right(_canvas, PANEL.end.x - 5, y, TargetRead.tiles(float(roundi(float(read.distance)))), UiTheme.TEXT_DIM)
	return y + 11


## What the other keys do while the target key is held, on the panel's own glass:
## over the world these words had nothing behind them and read as litter.
func _draw_keys(r: Rect2i, sweeping: bool) -> void:
	var y := r.end.y - 11
	var x := r.position.x + 4
	UiDraw.hline(_canvas, x, r.end.x - 5, y - 2, UiTheme.GHOST)
	if not sweeping:
		x += UiSlate.mini_cap(_canvas, Vector2i(x, y + 1), "a d") + 3
		UiDraw.text(_canvas, Vector2i(x, y), "another", UiTheme.TEXT_DIM)
		x += UiFont.width("another") + 7
	x += UiSlate.mini_cap(_canvas, Vector2i(x, y + 1), "r") + 3
	UiDraw.text(_canvas, Vector2i(x, y), "one at a time" if sweeping else "the field", UiTheme.TEXT_DIM)


## A sweep: the short of every body in the field, and a tag on each of them.
func _draw_sweep(rows: Array, field: Array) -> void:
	var r := Rect2i(SWEEP_PANEL.position, Vector2i(SWEEP_PANEL.size.x, 28 + maxi(1, rows.size()) * 11))
	Hud.clip(_canvas, r, false)
	var x := r.position.x + 5
	var y := r.position.y + 3
	UiDraw.text(_canvas, Vector2i(x, y), "THE FIELD", UiTheme.MACHINE[4])
	UiDraw.text_right(_canvas, r.end.x - 5, y, "%d" % rows.size(), UiTheme.TEXT_DIM)
	y += 12
	for row: Dictionary in rows:
		if y > r.end.y - 13:
			break
		var machine := bool(row.machine)
		var tag: Dictionary = row.tag
		var full := int((tag.pips as Array)[0])
		for i in TargetRead.PIPS:
			UiDraw.rect(_canvas, Rect2i(x + i * 3, y + 2, 2, 5), _ink(machine) if i < full else UiTheme.GHOST)
		_draw_notice(Vector2i(x + TargetRead.PIPS * 3 + 3, y + 1), int(tag.notice), machine, true)
		UiDraw.text(_canvas, Vector2i(x + TargetRead.PIPS * 3 + 15, y), _fit(str(row.name), 74), _ink(machine, false))
		UiDraw.text_right(_canvas, r.end.x - 5, y, "%dt" % roundi(float(row.distance)), UiTheme.TEXT_DIM)
		y += 11
	if rows.is_empty():
		UiDraw.text(_canvas, Vector2i(x, y), "nothing within reach", UiTheme.TEXT_DIM)
	for m: Variant in field:
		var body := m as MobState
		if body == null:
			continue
		var at := _screen_of(body)
		if _on_glass(at[1]):
			UiDraw.hline(_canvas, int(at[1].x) - 4, int(at[1].x) + 4, int(at[1].y) - TAG_LIFT - 8, UiTheme.MACHINE[3] if body.machine else UiTheme.TEXT)
	_draw_keys(r, true)


## Text cut to `width` pixels with an ellipsis: a panel this narrow must never
## push a word off its own glass.
static func _fit(text: String, width: int) -> String:
	if UiFont.width(text) <= width:
		return text
	var t := text
	while t.length() > 1 and UiFont.width(t + "…") > width:
		t = t.left(t.length() - 1)
	return t + "…"
