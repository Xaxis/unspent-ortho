class_name Hud
extends CanvasLayer
## The quiet layer, drawn at the 640x360 base so every pixel is a screen pixel.
## Nothing sits over the middle of the screen, where the fight is:
##
##   top left     health, a gauge of cells of three (no numbers); wind under it,
##                only while some is spent
##   top right    the clock; under it the needs that matter now, as glyphs
##   bottom left  the thing in hand: its icon and name
##   bottom mid   a message that fades; under it what E would do here
##
## The HUD owns no rules. The ui system (src/systems/90_ui.gd) feeds it every
## frame from Body, Inventory and the world; Events.message arrives directly.

const MARGIN := 8
const CELL_W := 10
const CELL_H := 8
const PLACE_IN := 0.8
const PLACE_HOLD := 2.6
const PLACE_OUT := 1.4
## A place name gives way to a fight this fast.
const PLACE_HUSH := 0.3

var clock_text := ""
var health := 12
var max_health := 12
var wind := 1.0
var max_wind := 1.0
var held: StringName = &""
var needs: Array[Dictionary] = []
var hint := ""
var hint_key := "e"
var messages := UiMessages.new()
var place := ""

var _canvas: Control
var _place_age := 99.0
var _time := 0.0
var _wind_alpha := 0.0
var _hint_alpha := 0.0
var _hint_target := 0.0
var _hurt_flash := 0.0
var _lost_from := 0
var _needs_alpha := {}


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.name = "canvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = UiTheme.theme()
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	Events.message.connect(show_message)


func set_clock(text: String) -> void:
	if text != clock_text:
		clock_text = text
		_canvas.queue_redraw()


func set_body(p_health: int, p_max_health: int, p_wind: float, p_max_wind: float) -> void:
	if p_health < health:
		_lost_from = health
		_hurt_flash = 0.5
	health = p_health
	max_health = p_max_health
	wind = p_wind
	max_wind = p_max_wind


func set_held(id: StringName) -> void:
	held = id


func set_needs(list: Array[Dictionary]) -> void:
	needs = list


## text "" hides the hint (it fades out rather than blinking off).
func set_hint(text: String, key: String = "e") -> void:
	if text != "":
		hint = text
		hint_key = key
	_hint_target = 1.0 if text != "" else 0.0


## Letter a place name across the top: faded in, held, faded out.
func show_place(text: String) -> void:
	place = text
	_place_age = 0.0


## A place name is text too: in a fight it fades from wherever it stands to
## nothing in PLACE_HUSH seconds, and does not come back after.
func step_place(delta: float) -> void:
	if messages.quiet:
		var a := place_alpha()
		if a > 0.0:
			_place_age = PLACE_IN + PLACE_HOLD + PLACE_OUT * (1.0 - a)
		_place_age += delta * PLACE_OUT / PLACE_HUSH
	else:
		_place_age += delta


func place_alpha() -> float:
	if _place_age < PLACE_IN:
		return _place_age / PLACE_IN
	if _place_age < PLACE_IN + PLACE_HOLD:
		return 1.0
	return clampf(1.0 - (_place_age - PLACE_IN - PLACE_HOLD) / PLACE_OUT, 0.0, 1.0)


func show_message(text: String) -> void:
	messages.push(text)


## A line said at once, even with a hostile close.
func say_now(text: String) -> void:
	messages.push(text, true)


## While true (a fight is near), messages wait until it is over.
func set_quiet(q: bool) -> void:
	if q != messages.quiet:
		messages.quiet = q


## Jump every fade to where it is heading (screenshots, tests).
func settle() -> void:
	_wind_alpha = 1.0 if UiRules.wind_shown(wind, max_wind) else 0.0
	_hint_alpha = _hint_target
	_hurt_flash = 0.0
	if _place_age < PLACE_IN:
		_place_age = PLACE_IN
	for n in needs:
		_needs_alpha[n.need] = 1.0


func _process(delta: float) -> void:
	_time += delta
	messages.step(delta)
	step_place(delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	var wind_target := 1.0 if UiRules.wind_shown(wind, max_wind) else 0.0
	_wind_alpha = move_toward(_wind_alpha, wind_target, delta * (4.0 if wind_target > 0.0 else 1.2))
	_hint_alpha = move_toward(_hint_alpha, _hint_target, delta * 6.0)
	var present := {}
	for n in needs:
		present[n.need] = true
	for k: StringName in [&"hunger", &"wet", &"load", &"tired"]:
		var a: float = _needs_alpha.get(k, 0.0)
		_needs_alpha[k] = move_toward(a, 1.0 if present.has(k) else 0.0, delta * 1.5)
	_canvas.queue_redraw()


func _draw_hud() -> void:
	var ci := _canvas
	_draw_health(ci)
	_draw_clock(ci)
	_draw_held(ci)
	_draw_bottom(ci)
	_draw_place(ci)


func _draw_place(ci: Control) -> void:
	var a := place_alpha()
	if a <= 0.0 or place == "":
		return
	# Spaced capitals, the way a map letters a region, with a rule drawn out from the middle.
	var spaced := ""
	for i in place.length():
		spaced += (" " if i > 0 else "") + place[i].to_upper()
	var w := UiFont.width(spaced)
	var x := 320 - w / 2
	var y := 30
	UiDraw.text_rimmed(ci, Vector2i(x, y), spaced, Color(UiTheme.HUD_TEXT, a), Color(UiTheme.INK_DEEP, a * 0.9))
	var half := roundi((w / 2 + 16) * clampf(_place_age / PLACE_IN, 0.0, 1.0))
	UiDraw.rect(ci, Rect2i(320 - half - 1, y + 13, half * 2 + 2, 3), Color(UiTheme.INK_DEEP, a * 0.9))
	UiDraw.hline(ci, 320 - half, 320 + half, y + 14, Color(UiTheme.HUD_DIM, a))


func _draw_health(ci: Control) -> void:
	# Cells of three, kept like a tally: three upright strokes to a box. A spent
	# stroke leaves a hollow; a fresh loss flashes paper-white before it goes.
	var cells := UiRules.health_cells(health, max_health)
	var lost_cells := UiRules.health_cells(_lost_from, max_health)
	var x := MARGIN
	var y := MARGIN
	for i in cells.size():
		var r := Rect2i(x, y, CELL_W, CELL_H)
		UiDraw.rect(ci, r.grow(1), UiTheme.INK_DEEP)
		UiDraw.rect(ci, r, Color(UiTheme.INK_SOFT, 0.9))
		# The last cell standing breathes: its rim warms and cools, slowly.
		if health > 0 and health <= UiRules.PER_CELL and i == 0:
			var warm := 0.5 + 0.5 * sin(_time * 3.2)
			UiDraw.frame(ci, r.grow(1), Color(UiTheme.ACCENT, 0.35 + 0.5 * warm))
		for t in UiRules.PER_CELL:
			var stroke := Rect2i(x + 1 + t * 3, y + 1, 2, CELL_H - 2)
			if t < cells[i]:
				UiDraw.rect(ci, stroke, UiTheme.ACCENT_BRIGHT)
				UiDraw.px(ci, stroke.position.x, stroke.position.y, Palette.RUST[5])
			elif _hurt_flash > 0.0 and t < lost_cells[i]:
				UiDraw.rect(ci, stroke, Color(Palette.LINEN[5], clampf(_hurt_flash * 2.0, 0.0, 1.0)))
			else:
				UiDraw.rect(ci, stroke, Color(UiTheme.INK_DEEP, 0.6))
		x += CELL_W + 3
	if _wind_alpha > 0.0:
		# Wind: one thin line under the cells, pale as breath, only while some is spent.
		var w := cells.size() * (CELL_W + 3) - 3
		var fill := roundi(w * clampf(wind / maxf(1.0, max_wind), 0.0, 1.0))
		var wy := y + CELL_H + 3
		UiDraw.rect(ci, Rect2i(MARGIN - 1, wy - 1, w + 2, 3), Color(UiTheme.INK_DEEP, _wind_alpha * 0.8))
		UiDraw.rect(ci, Rect2i(MARGIN, wy, fill, 1), Color(Palette.RIME[5], _wind_alpha))


func _draw_clock(ci: Control) -> void:
	var w := UiFont.width(clock_text)
	UiDraw.text_rimmed(ci, Vector2i(640 - MARGIN - w, MARGIN - 1), clock_text, UiTheme.HUD_TEXT, UiTheme.INK_DEEP)
	# Needs, right to left under the clock, in a fixed order so they never swap places.
	var x := 640 - MARGIN - UiIcons.SIZE
	var level := {}
	for n in needs:
		level[n.need] = n.level
	for k: StringName in [&"hunger", &"wet", &"load", &"tired"]:
		var a: float = _needs_alpha.get(k, 0.0)
		if a <= 0.0:
			continue
		var col := UiTheme.ACCENT_BRIGHT if level.get(k, 1) >= 2 else UiTheme.HUD_TEXT
		_draw_faded_need(ci, k, Vector2i(x, MARGIN + 12), col, a)
		x -= UiIcons.SIZE + 4


func _draw_faded_need(ci: Control, k: StringName, at: Vector2i, col: Color, a: float) -> void:
	UiDraw.sprite_rimmed(ci, UiIcons.NEEDS[k], at, {"#": Color(col, a)}, Color(UiTheme.INK_DEEP, a))


func _draw_held(ci: Control) -> void:
	# The thing in hand on a little paper tag, so its colours read on any ground.
	var y := 360 - MARGIN - 13
	var x := MARGIN
	var name := UiRules.item_name(held) if held != &"" else "hands"
	if held != &"":
		var tag := Rect2i(x, y, 13, 13)
		UiDraw.rect(ci, Rect2i(tag.position.x + 1, tag.position.y - 1, tag.size.x - 2, tag.size.y + 2), UiTheme.INK_DEEP)
		UiDraw.rect(ci, tag.grow_individual(1, 0, 1, 0), UiTheme.INK_DEEP)
		UiDraw.rect(ci, tag, UiTheme.PAPER)
		UiDraw.hline(ci, tag.position.x, tag.end.x - 1, tag.end.y - 1, UiTheme.PAPER_SHADE)
		UiIcons.draw_item(ci, held, tag.position + Vector2i(2, 2))
		x += 17
	UiDraw.text_rimmed(ci, Vector2i(x, y + 2), name, UiTheme.HUD_TEXT, UiTheme.INK_DEEP)


func _draw_bottom(ci: Control) -> void:
	# Newest message lowest; older ones stand above it, dimmer, until they fade.
	var shown := messages.visible()
	for i in shown.size():
		var line: Dictionary = shown[shown.size() - 1 - i]
		var a: float = line.alpha * (1.0 if i == 0 else 0.72)
		var text: String = line.text
		var y := 360 - MARGIN - 24 - i * 12
		UiDraw.text_rimmed(ci, Vector2i(320 - UiFont.width(text) / 2, y), text, Color(UiTheme.HUD_TEXT if i == 0 else UiTheme.HUD_DIM, a), Color(UiTheme.INK_DEEP, a))
	if _hint_alpha > 0.0 and hint != "":
		var total := 11 + 4 + UiFont.width(hint)
		var x := 320 - total / 2
		var y := 360 - MARGIN - UiFont.SIZE
		_draw_key(ci, Vector2i(x, y), hint_key, _hint_alpha)
		UiDraw.text_rimmed(ci, Vector2i(x + 15, y + 1), hint, Color(UiTheme.HUD_TEXT, _hint_alpha), Color(UiTheme.INK_DEEP, _hint_alpha))


## A little paper key cap with the letter in ink.
static func _draw_key(ci: CanvasItem, at: Vector2i, key: String, a: float) -> void:
	var r := Rect2i(at.x, at.y - 1, 11, 12)
	UiDraw.rect(ci, Rect2i(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), Color(UiTheme.INK_DEEP, a))
	UiDraw.rect(ci, Rect2i(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), Color(UiTheme.INK_DEEP, a))
	UiDraw.rect(ci, Rect2i(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 3), Color(UiTheme.PAPER, a))
	UiDraw.hline(ci, r.position.x + 1, r.end.x - 2, r.end.y - 2, Color(UiTheme.PAPER_DEEP, a))
	UiDraw.text(ci, Vector2i(at.x + 6 - UiFont.width(key) / 2 - 0, at.y), key, Color(UiTheme.INK, a))
