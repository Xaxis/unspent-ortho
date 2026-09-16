class_name Hud
extends CanvasLayer
## The slate's edge overlay, drawn at the 640x360 base so every pixel is a
## screen pixel. Small readouts clipped to the corners, as if strapped to the
## wrist or thrown onto a salvaged lens (docs/ART.md §9). Nothing sits over the
## middle of the screen, where the fight is, and nothing in a fight is text
## beyond the readouts:
##
##   top left     the wrist unit: health as cells of three segments (no numbers);
##                wind under it only while some is spent; charges beside it only
##                while the thing in hand spends them
##   top right    the clock and the slate's cell; under it the felt pressures,
##                a small gauge each, only while they matter
##   top middle   the goal, one line, standing until it changes; the location
##                ping takes the space when the player crosses into a landscape
##   bottom left  the thing in hand
##   bottom mid   a message line that fades; under it what E (or the key the
##                guide is teaching) would do here
##
## The HUD owns no rules. The ui system (src/systems/90_ui.gd) feeds it every
## frame from Body, Inventory and the world; Events.message arrives directly.

const MARGIN := 8
## One health cell: three segments and the gap after them.
const CELL_W := 12
const PLACE_IN := 0.8
const PLACE_HOLD := 2.6
const PLACE_OUT := 1.4
## A place name gives way to a fight this fast.
const PLACE_HUSH := 0.3
## How far outside their place the name's brackets start, in pixels.
const PLACE_SWEEP := 30.0
## A pressure gauge's tile, and the gap between tiles.
const GAUGE := Vector2i(13, 16)

var clock_text := ""
var health := 12
var max_health := 12
var wind := 1.0
var max_wind := 1.0
var held: StringName = &""
var pressures: Array[Dictionary] = []
var hint := ""
var hint_key := "e"
var messages := UiMessages.new()
## What to want next (Guide.goal), standing at the top until it changes. It
## steps aside for the location ping, for a fight, and for its own words while
## they are still on the message line.
var goal := ""
var place := ""
var charge_shown := false
var charges := 0
var power := 1.0

var _canvas: Control
var _place_age := 99.0
var _time := 0.0
var _wind_alpha := 0.0
var _charge_alpha := 0.0
var _hint_alpha := 0.0
var _hint_target := 0.0
var _hurt_flash := 0.0
var _lost_from := 0
var _gauge_alpha := {}
## Apps open now. An app takes the messages said while it is up, so the HUD
## does not queue them to play a second time when it closes.
var _pages := {}


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
	Events.hint.connect(teach)
	Events.screen_changed.connect(_on_screen_changed)


func set_clock(text: String) -> void:
	if text != clock_text:
		clock_text = text
		if _canvas != null:
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


## Charges carried, shown only while `shown` (the thing in hand spends them).
func set_charge(shown: bool, count: int) -> void:
	charge_shown = shown
	charges = count


## The slate's power 0..1: the readouts dim with it, as the glass does.
func set_power(p: float) -> void:
	power = p


## Felt pressures as UiRules.pressures gives them: [{id, level, value}].
func set_pressures(list: Array[Dictionary]) -> void:
	pressures = list


## Needs as UiRules.needs gives them ([{need, level}]), shown as pressures.
func set_needs(list: Array[Dictionary]) -> void:
	var out: Array[Dictionary] = []
	for n in list:
		out.append({"id": n.need, "level": n.level, "value": float(n.get("value", 0.5 if n.level == 1 else 1.0))})
	pressures = out


## The one-line goal, or "" for none.
func set_goal(text: String) -> void:
	goal = text


## text "" hides the hint (it fades out rather than blinking off).
func set_hint(text: String, key: String = "e") -> void:
	if text != "":
		hint = text
		hint_key = key
	_hint_target = 1.0 if text != "" else 0.0


## Ping a place name at the top: faded in, held, faded out.
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
	if not _pages.is_empty():
		return
	messages.push(text)


func _on_screen_changed(n: StringName, open: bool) -> void:
	if open:
		_pages[n] = true
	else:
		_pages.erase(n)


## A line said at once, even with a hostile close.
func say_now(text: String) -> void:
	messages.push(text, true)


## A teaching line (Events.hint): said now, or not at all. It is never held
## back by the fight's quiet mode and never queued, so a lesson about walking
## or the lamp cannot arrive minutes later, out of the moment that earned it.
func teach(text: String, _key: String = "") -> void:
	if messages.quiet or not _pages.is_empty():
		return
	messages.push(text)


## True while the goal line is on the glass: nothing louder is using the space.
func goal_shown() -> bool:
	if goal == "" or messages.quiet or place_alpha() > 0.0:
		return false
	for l in messages.visible():
		if String(l.text).begins_with(goal):
			return false
	return true


## While true (a fight is near), messages wait until it is over.
func set_quiet(q: bool) -> void:
	if q != messages.quiet:
		messages.quiet = q


## How visible each readout is now, 0..1, by name (tests, and what is drawn):
## health clock held always; wind, charge, hint, place and each pressure id by their fades.
func shown() -> Dictionary:
	var out := {&"health": 1.0, &"clock": 1.0, &"held": 1.0, &"wind": _wind_alpha, &"charge": _charge_alpha, &"hint": _hint_alpha, &"place": place_alpha(), &"goal": 1.0 if goal_shown() else 0.0}
	for k: StringName in _gauge_alpha:
		out[k] = _gauge_alpha[k]
	return out


## Jump every fade to where it is heading (screenshots, tests).
func settle() -> void:
	_wind_alpha = 1.0 if UiRules.wind_shown(wind, max_wind) else 0.0
	_charge_alpha = 1.0 if charge_shown else 0.0
	_hint_alpha = _hint_target
	_hurt_flash = 0.0
	if _place_age < PLACE_IN:
		_place_age = PLACE_IN
	_gauge_alpha.clear()
	for p in pressures:
		_gauge_alpha[p.id] = 1.0


func _process(delta: float) -> void:
	_time += delta
	messages.step(delta)
	step_place(delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	var wind_target := 1.0 if UiRules.wind_shown(wind, max_wind) else 0.0
	_wind_alpha = move_toward(_wind_alpha, wind_target, delta * (4.0 if wind_target > 0.0 else 1.2))
	_charge_alpha = move_toward(_charge_alpha, 1.0 if charge_shown else 0.0, delta * 4.0)
	_hint_alpha = move_toward(_hint_alpha, _hint_target, delta * 6.0)
	var present := {}
	for p in pressures:
		present[p.id] = true
	for k: StringName in present:
		if not _gauge_alpha.has(k):
			_gauge_alpha[k] = 0.0
	for k: StringName in _gauge_alpha.keys():
		var a: float = _gauge_alpha[k]
		a = move_toward(a, 1.0 if present.has(k) else 0.0, delta * 1.5)
		if a <= 0.0 and not present.has(k):
			_gauge_alpha.erase(k)
		else:
			_gauge_alpha[k] = a
	if _canvas != null:
		var b := UiRules.brightness(power)
		_canvas.modulate = Color(b, b, b, 1.0)
		_canvas.queue_redraw()


func _draw_hud() -> void:
	var ci := _canvas
	_draw_wrist(ci)
	_draw_clock(ci)
	_draw_held(ci)
	_draw_bottom(ci)
	_draw_goal(ci)
	_draw_place(ci)


## A small window of the slate's glass in a violet clip, held on by a strap
## (left) or a strip of tape (right): every corner readout sits in one.
static func clip(ci: CanvasItem, r: Rect2i, strap_left: bool) -> void:
	var F := Palette.FOUND
	UiDraw.rect(ci, Rect2i(r.position.x - 1, r.position.y - 2, r.size.x + 2, r.size.y + 4), UiTheme.RIM)
	UiDraw.rect(ci, Rect2i(r.position.x - 2, r.position.y - 1, r.size.x + 4, r.size.y + 2), UiTheme.RIM)
	UiDraw.frame(ci, r.grow(1), F[1])
	UiDraw.hline(ci, r.position.x, r.end.x - 1, r.position.y - 1, F[3])
	UiDraw.rect(ci, r, UiTheme.GLASS)
	for y in range(r.position.y + 1, r.end.y, 2):
		UiDraw.hline(ci, r.position.x, r.end.x - 1, y, UiTheme.GLASS_ROW)
	if strap_left:
		# The strap it is buckled to, running off the edge of the wrist.
		var A := Palette.ASH
		UiDraw.rect(ci, Rect2i(0, r.position.y + 2, r.position.x - 2, r.size.y - 4), A[1])
		UiDraw.hline(ci, 0, r.position.x - 3, r.position.y + 2, A[2])
		for x in range(1, r.position.x - 2, 3):
			UiDraw.px(ci, x, r.position.y + r.size.y / 2, A[0])
	else:
		# A strip of tape over its top corner.
		var A := Palette.ASH
		for k in 5:
			UiDraw.hline(ci, r.end.x - 7 + k, r.end.x + 1 + k, r.position.y - 3 + k, A[4] if k != 4 else A[3])


func _draw_wrist(ci: Control) -> void:
	var cells := UiRules.health_cells(health, max_health)
	var lost_cells := UiRules.health_cells(_lost_from, max_health)
	var last := health > 0 and health <= UiRules.PER_CELL
	var w := cells.size() * CELL_W + 3
	var win := Rect2i(MARGIN + 6, MARGIN, w, 11)
	clip(ci, win, true)
	if last:
		var warm := 0.5 + 0.5 * sin(_time * 3.2)
		UiDraw.frame(ci, win.grow(1), Color(UiTheme.WARN, 0.3 + 0.55 * warm))
	for i in cells.size():
		var cx := win.position.x + 3 + i * CELL_W
		for t in UiRules.PER_CELL:
			var col := UiTheme.WARN if last else UiTheme.TEXT
			if t >= cells[i]:
				col = UiTheme.GHOST
				if _hurt_flash > 0.0 and t < lost_cells[i]:
					col = UiTheme.WARN
			UiDraw.rect(ci, Rect2i(cx + t * 3, win.position.y + 2, 2, 7), col)
	if _wind_alpha > 0.0:
		# Wind: one thin line under the window, only while some is spent.
		var k := UiDraw.stepped(_wind_alpha)
		var fill := roundi((w - 2) * clampf(wind / maxf(1.0, max_wind), 0.0, 1.0))
		var wy := win.end.y + 3
		UiDraw.rect(ci, Rect2i(win.position.x - 1, wy - 1, w + 2, 3), Color(UiTheme.RIM, k * 0.85))
		UiDraw.rect(ci, Rect2i(win.position.x, wy, fill, 1), Color(UiTheme.PHOSPHOR[2], k))
	if _charge_alpha > 0.0:
		var k := UiDraw.stepped(_charge_alpha)
		var text := "%d" % charges
		var cw := Rect2i(win.end.x + 6, win.position.y, 13 + UiFont.width(text) + 8, 11)
		if k >= 1.0:
			clip(ci, cw, false)
			_charge_glyph(ci, Vector2i(cw.position.x + 2, cw.position.y + 2), UiTheme.WARN if charges <= 0 else UiTheme.MACHINE[3])
			UiDraw.text(ci, Vector2i(cw.position.x + 13, cw.position.y), text, UiTheme.WARN if charges <= 0 else UiTheme.MACHINE[3])
		else:
			UiDraw.text_rimmed_faded(ci, Vector2i(cw.position.x + 13, cw.position.y), text, UiTheme.MACHINE[3], UiTheme.RIM, k)


## A found charge: a small violet cell with its slot lit.
static func _charge_glyph(ci: CanvasItem, at: Vector2i, col: Color) -> void:
	UiDraw.frame(ci, Rect2i(at.x, at.y, 9, 7), col)
	UiDraw.rect(ci, Rect2i(at.x + 2, at.y + 2, 5, 3), col)
	UiDraw.vline(ci, at.x + 9, at.y + 2, at.y + 4, col)


func _draw_clock(ci: Control) -> void:
	var w := UiFont.width(clock_text) + 24
	var win := Rect2i(640 - MARGIN - w, MARGIN, w, 11)
	clip(ci, win, false)
	UiSlate.cell(ci, Vector2i(win.position.x + 3, win.position.y + 2), power)
	UiDraw.text(ci, Vector2i(win.position.x + 19, win.position.y), clock_text, UiTheme.TEXT)
	# Felt pressures, right to left under the clock, in a fixed order so they never swap.
	var x := 640 - MARGIN - GAUGE.x
	var level := {}
	var value := {}
	for p in pressures:
		level[p.id] = p.level
		value[p.id] = p.value
	var order: Array = _gauge_alpha.keys()
	order.sort()
	for k: StringName in [&"hunger", &"lamp", &"wet", &"load", &"tired"]:
		if order.has(k):
			order.erase(k)
			order.push_front(k)
	for k: StringName in order:
		var a: float = _gauge_alpha.get(k, 0.0)
		if a <= 0.0:
			continue
		var lv := int(level.get(k, 1))
		_draw_gauge(ci, k, Vector2i(x, win.end.y + 6), UiTheme.WARN if lv >= 2 else UiTheme.TEXT, float(value.get(k, 0.5)), a, lv)
		x -= GAUGE.x + 5


## A felt pressure: its glyph on a scrap of glass, a meter under it filling
## with how hard it presses. At level 3 (starving, the lamp all but dry) the
## tile is bracketed and beats, so the last rung is never read as the middle one.
func _draw_gauge(ci: Control, id: StringName, at: Vector2i, col: Color, v: float, a: float, level: int = 1) -> void:
	# Fading, the whole tile steps in and out together (its glass holds the glyph).
	var k := UiDraw.stepped(a)
	if k <= 0.0:
		return
	var r := Rect2i(at, GAUGE)
	UiDraw.rect(ci, r.grow(1), Color(UiTheme.RIM, k))
	UiDraw.rect(ci, r, Color(UiTheme.GLASS, k))
	if level >= 3:
		var beat := 0.55 + 0.45 * sin(_time * 3.2)
		UiDraw.frame(ci, r.grow(1), Color(col, k * (0.35 + 0.55 * beat)))
	UiDraw.sprite(ci, UiIcons.pressure_rows(id), at + Vector2i(2, 1), {"#": Color(col, k)})
	var fill := roundi((GAUGE.x - 4) * clampf(v, 0.0, 1.0))
	UiDraw.rect(ci, Rect2i(at.x + 2, at.y + GAUGE.y - 4, GAUGE.x - 4, 2), Color(UiTheme.GHOST, k))
	UiDraw.rect(ci, Rect2i(at.x + 2, at.y + GAUGE.y - 4, fill, 2), Color(col, k))


func _draw_held(ci: Control) -> void:
	var name := UiRules.item_name(held) if held != &"" else "hands"
	var w := UiFont.width(name) + (19 if held != &"" else 6)
	var win := Rect2i(MARGIN + 6, 360 - MARGIN - 11, w, 11)
	clip(ci, win, true)
	var x := win.position.x + 3
	if held != &"":
		UiIcons.draw_item(ci, held, Vector2i(x, win.position.y + 1))
		x += 13
	UiDraw.text(ci, Vector2i(x, win.position.y), name, UiTheme.MACHINE[3] if UiIcons.is_found(held) else UiTheme.TEXT)


func _draw_bottom(ci: Control) -> void:
	# Newest message lowest; older ones stand above it, dimmer, until they fade.
	var lines := messages.visible()
	for i in lines.size():
		var line: Dictionary = lines[lines.size() - 1 - i]
		var a: float = line.alpha * (1.0 if i == 0 else 0.72)
		var text: String = line.text
		var y := 360 - MARGIN - 25 - i * 12
		UiDraw.text_rimmed_faded(ci, Vector2i(320 - UiFont.width(text) / 2, y), text, UiTheme.TEXT if i == 0 else UiTheme.TEXT_DIM, UiTheme.RIM, a)
	if _hint_alpha > 0.0 and hint != "":
		var cap := maxi(9, UiFont.width(hint_key) + 4)
		var total := cap + 5 + UiFont.width(hint)
		var x := 320 - total / 2
		var y := 360 - MARGIN - 11
		var k := UiDraw.stepped(_hint_alpha)
		UiSlate.key_cap(ci, Vector2i(x, y), hint_key, k)
		UiDraw.text_rimmed_faded(ci, Vector2i(x + cap + 5, y + 1), hint, UiTheme.TEXT, UiTheme.RIM, _hint_alpha)


## What to want next: one quiet line along the top, a phosphor chevron before
## it. It stands (it is not a message that fades) so a player who looks up an
## hour later still knows what they were doing.
func _draw_goal(ci: Control) -> void:
	if not goal_shown():
		return
	var w := UiFont.width(goal)
	var x := 320 - (w + 6) / 2
	UiSlate.chevron(ci, Vector2i(x, 11), UiTheme.PHOSPHOR[2])
	UiDraw.text_rimmed(ci, Vector2i(x + 6, 8), goal, UiTheme.TEXT_DIM, UiTheme.RIM)


## How far from the middle each bracket of the place name stands, `grow` 0..1
## through the ping's rise. They close IN from outside the word to their place
## and never sweep across the letters: a bright mark travelling over a name
## reads as a name struck out (docs/ART.md §9 — the slate's type is exact).
static func place_half(w: int, grow: float) -> int:
	return roundi(w / 2.0 + 12.0 + (1.0 - clampf(grow, 0.0, 1.0)) * PLACE_SWEEP)


## The location ping: a ring goes out from the top middle, then the landscape's
## name in spaced capitals between brackets drawn out from the middle.
func _draw_place(ci: Control) -> void:
	var a := place_alpha()
	if a <= 0.0 or place == "":
		return
	var spaced := ""
	for i in place.length():
		spaced += (" " if i > 0 else "") + place[i].to_upper()
	var w := UiFont.width(spaced)
	var y := 30
	var k := UiDraw.stepped(a)
	var grow := clampf(_place_age / PLACE_IN, 0.0, 1.0)
	if _place_age < PLACE_IN * 1.5:
		var pr := 3.0 + (_place_age / (PLACE_IN * 1.5)) * 22.0
		var ring_a := UiDraw.stepped(1.0 - _place_age / (PLACE_IN * 1.5)) * 0.8
		for s in 28:
			var an := s * TAU / 28.0
			UiDraw.px(ci, 320 + roundi(cos(an) * pr * 1.6), y + 4 + roundi(sin(an) * pr * 0.5), Color(UiTheme.BRIGHT, ring_a))
	UiDraw.text_rimmed_faded(ci, Vector2i(320 - w / 2, y), spaced, UiTheme.BRIGHT, UiTheme.RIM, a)
	UiDraw.text_rimmed_faded(ci, Vector2i(320 - UiFont.width("location") / 2, y - 12), "location", UiTheme.TEXT_DIM, UiTheme.RIM, a * grow)
	var half := place_half(w, grow)
	for side: int in [-1, 1]:
		var bx := 320 + side * half
		UiDraw.rect(ci, Rect2i(bx - 1, y - 2, 3, 13), Color(UiTheme.RIM, k))
		UiDraw.vline(ci, bx, y - 1, y + 10, Color(UiTheme.TEXT, k))
		UiDraw.hline(ci, mini(bx, bx - side * 3), maxi(bx, bx - side * 3), y - 1, Color(UiTheme.TEXT, k))
		UiDraw.hline(ci, mini(bx, bx - side * 3), maxi(bx, bx - side * 3), y + 10, Color(UiTheme.TEXT, k))
