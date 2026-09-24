class_name Hud
extends CanvasLayer
## The slate's edge overlay, drawn in the base's own pixels (`UiBase.SIZE`) so
## every pixel is a screen pixel. Small readouts clipped to the corners, as if strapped to the
## wrist or thrown onto a salvaged lens (docs/LOOK.md). Nothing sits over the
## middle of the screen, where the fight is, and nothing in a fight is text
## beyond the readouts:
##
##   top left     the wrist unit: health as cells of three segments (no numbers);
##                wind under it only while some is spent; charges beside it only
##                while the thing in hand spends them; under all of it the goal,
##                one dim line, standing until it changes
##   top right    the clock and the slate's cell; under it the felt pressures,
##                a small gauge each, only while they matter, hunger nearest the
##                clock
##   top middle   nothing but the location ping, when the player crosses into
##                a landscape
##   bottom left  the thing in hand
##   bottom mid   a message line that fades; under it what E (or the key the
##                guide is teaching) would do here
##
## The HUD owns no rules. The ui system (src/systems/90_ui.gd) feeds it every
## frame from Body, Inventory and the world; Events.message arrives directly.

const MARGIN := 24
## One health cell: three segments and the gap after them.
const CELL_W := 24
const PLACE_IN := 0.8
const PLACE_HOLD := 2.6
const PLACE_OUT := 1.4
## A place name gives way to a fight this fast.
const PLACE_HUSH := 0.3
## How far outside their place the name's brackets start, in pixels, and how far
## off the last letter they come to rest.
const PLACE_SWEEP := 60.0
const PLACE_CLEAR := 24
## Top of the place name's line box; its label sits a line above it.
const PLACE_Y := 72
## Samples in the ping's ring, how far past the plate it rings out, how long it
## takes to get there, and the gap it starts at so the plate's own rim cannot
## eat it. It used to start 2 px off the plate and fade over 1.2 s multiplied by
## the ping's rise, which put its brightest moment at a fifth of full ink: over
## the world it was never once seen.
const RING_STEPS := 40
const RING_STEPS_MAX := 1280
const RING_REACH := 52.0
const RING_LIFE := 0.7
const RING_GAP := 8.0
## Seconds the ping's scrap of glass takes to come up. The lettering starts only
## once it is opaque: for the whole 0.8 s rise the name used to be mid-grey type
## on a half-transparent plate over a snowfield, which is the half second the eye
## lands on it.
const PLATE_IN := 0.18
## A pressure gauge's tile, and the gap between tiles.
const GAUGE := Vector2i(26, 32)
## The body's own needs, in the order they cost you the run. The gauges are
## drawn right to left from the clock, so the first here sits under the clock:
## hunger, the rung that ends the run, is nearest it and never moves.
const GAUGE_ORDER: Array[StringName] = [&"hunger", &"lamp", &"wet", &"load", &"tired"]
## Seconds a gauge answers for a line that was not said in words: brackets
## close on it, the way the location ping's brackets close on a name.
const GAUGE_FLARE := 1.2
## Longest a line about a pressure waits for the readouts to be fed.
const PEND_WAIT := 0.25
## Where the standing goal line sits: under the wrist unit and its wind line.
const GOAL_Y := 58

var clock_text := ""
var health := 12
var max_health := 12
var wind := 1.0
var max_wind := 1.0
var held: StringName = &""
var pressures: Array[Dictionary] = []
## Somebody is being talked to, drawn over the world rather than on the glass.
## 90_ui writes it from `game.talking` every frame; the HUD holds no reference to
## the game and does not want one.
var talking := false
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
## Gauges answering for a line the glass did not say, id -> seconds left.
var _gauge_flare := {}
## Lines about a pressure, waiting for the readouts to be fed: see
## `show_message`. [{text, feed, age}]
var _pending: Array[Dictionary] = []
## How many times the readouts have been fed (UiRules.pressures).
var _feeds := 0
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
	# A line said about where you WERE is not about where you are.
	Events.warped.connect(func(_to: Vector2) -> void: messages.clear())
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
	_feeds += 1


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


## A line about a pressure waits for the readouts to be fed before it is said.
## The hazards system (52) tells the moment a pressure begins to bite, and the
## ui system (90) feeds the gauges later in the same frame, so asking the
## readouts at once asks them about the frame before — and the first line of a
## run was said in words although its badge was already on its way. It waits
## for the next feed, or PEND_WAIT seconds if nothing is feeding it at all.
func show_message(text: String) -> void:
	if not _pages.is_empty():
		return
	if UiMessages.gauge_for(text) != &"":
		_pending.append({"text": text, "feed": _feeds, "age": 0.0, "teach": false})
		return
	messages.push(text)


## True while a gauge is answering for a line the glass did not say in words.
func answering() -> bool:
	return not _gauge_flare.is_empty()


## The level of the gauge for `id` now, or 0 while it is not on the glass.
func gauge_level(id: StringName) -> int:
	for p in pressures:
		if StringName(p.id) == id:
			return int(p.level)
	return 0


## Say, or hand to a gauge, every line held by `show_message` whose readouts
## have since been fed.
##
## A line waits at most PEND_WAIT, and in that time an app can open over the
## glass. Whatever `show_message` and `teach` would have refused outright a
## frame earlier is refused here too, rather than landing on the glass behind
## the app and playing when it closes: a `message` while a page is up is not
## said (hud's own `_pages` rule), and a `hint` outside its moment is dropped
## for good (the Events.hint contract), never queued.
func settle_pending(delta: float = 0.0) -> void:
	if _pending.is_empty():
		return
	var keep: Array[Dictionary] = []
	for e in _pending:
		e.age = float(e.age) + delta
		if int(e.feed) >= _feeds and float(e.age) < PEND_WAIT:
			keep.append(e)
			continue
		if bool(e.get("teach", false)):
			if not can_teach():
				continue
		elif not _pages.is_empty():
			continue
		if not answer_with_gauge(String(e.text)):
			messages.push(String(e.text))
	_pending = keep


## A line whose whole subject is already a gauge in the top right is not also
## said across the bottom of the screen: the gauge answers for it, brackets
## closing on the tile. Three hazards plus hunger used to put three lines of
## body text over the middle of the world at once, which is the opposite of
## "small quiet readouts clipped to the corners" (docs/LOOK.md).
##
## The last rung is the exception: at level 3 the words still come, because
## starving and a dry lamp are what end the run and a badge should not be the
## only warning. Returns true when the gauge took it.
func answer_with_gauge(text: String) -> bool:
	var id := UiMessages.gauge_for(text)
	if id == &"":
		return false
	var level := gauge_level(id)
	if level <= 0 or level >= 3:
		return false
	_gauge_flare[id] = GAUGE_FLARE
	return true


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
	if not can_teach():
		return
	if UiMessages.gauge_for(text) != &"":
		_pending.append({"text": text, "feed": _feeds, "age": 0.0, "teach": true})
		return
	messages.push(text)


## True while a teaching line said now would be read: nothing hostile close,
## nothing over the glass, nobody talking. A lesson whose moment is "the fight is
## over" (the guide's plate line, said after a machine has broken off) waits on
## this rather than being emitted into the quiet, where `teach` would drop it for
## good.
##
## A CONVERSATION IS NOT A PAGE, which is why it had to be named here. It is
## drawn over the WORLD (`UiTalkView`, the owner's ruling) and not on the slate,
## so `_pages` is empty while one is up and a hint went straight onto the glass
## underneath the words somebody was reading — seen in tours/cast.tour frame 08,
## a works arrival line drawn under an open panel. The hint channel is "said in
## its moment or dropped", and the moment a hint arrives in is not one where the
## player is reading somebody's answer.
func can_teach() -> bool:
	return not messages.quiet and _pages.is_empty() and not talking


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
	# Not PEND_WAIT: a line still waiting for its gauge is waiting for the ui
	# system's next feed, and forcing it here would answer with the readouts of
	# the frame before — which is the whole thing the wait exists to avoid.
	settle_pending(0.0)
	_wind_alpha = 1.0 if UiRules.wind_shown(wind, max_wind) else 0.0
	_charge_alpha = 1.0 if charge_shown else 0.0
	_hint_alpha = _hint_target
	_hurt_flash = 0.0
	if _place_age < PLACE_IN:
		_place_age = PLACE_IN
	# A flare is an event, not a fade with a target: a settled frame catches it
	# half closed, so a shot shows which gauge answered for the line it took.
	for k: StringName in _gauge_flare:
		_gauge_flare[k] = GAUGE_FLARE * 0.55
	_gauge_alpha.clear()
	for p in pressures:
		_gauge_alpha[p.id] = 1.0


func _process(delta: float) -> void:
	_time += delta
	settle_pending(delta)
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
			_gauge_flare.erase(k)
		else:
			_gauge_alpha[k] = a
	for k: StringName in _gauge_flare.keys():
		var f: float = float(_gauge_flare[k]) - delta
		if f <= 0.0:
			_gauge_flare.erase(k)
		else:
			_gauge_flare[k] = f
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
	UiDraw.rect(ci, Rect2i(r.position.x - 2, r.position.y - 4, r.size.x + 4, r.size.y + 8), UiTheme.RIM)
	UiDraw.rect(ci, Rect2i(r.position.x - 4, r.position.y - 2, r.size.x + 8, r.size.y + 4), UiTheme.RIM)
	UiDraw.frame(ci, r.grow(2), F[1])
	UiDraw.hline(ci, r.position.x, r.end.x - 1, r.position.y - 2, F[3])
	UiDraw.rect(ci, r, UiTheme.GLASS)
	for y in range(r.position.y + UiBase.PITCH, r.end.y, UiBase.PITCH * 2):
		UiDraw.rect(ci, Rect2i(r.position.x, y, r.size.x, UiBase.PITCH), UiTheme.GLASS_ROW)
	if strap_left:
		# The strap it is buckled to, running off the edge of the wrist.
		var A := Palette.ASH
		UiDraw.rect(ci, Rect2i(0, r.position.y + 4, r.position.x - 4, r.size.y - 8), A[1])
		UiDraw.hline(ci, 0, r.position.x - 6, r.position.y + 4, A[2])
		for x in range(2, r.position.x - 4, 6):
			UiDraw.px(ci, x, r.position.y + r.size.y / 2, A[0])
	else:
		# A strip of tape over its top corner.
		var A := Palette.ASH
		for k in 5:
			UiDraw.rect(ci, Rect2i(r.end.x - 14 + k * 2, r.position.y - 6 + k * 2, 16, 2), A[4] if k != 4 else A[3])


func _draw_wrist(ci: Control) -> void:
	var cells := UiRules.health_cells(health, max_health)
	var lost_cells := UiRules.health_cells(_lost_from, max_health)
	var last := health > 0 and health <= UiRules.PER_CELL
	var w := cells.size() * CELL_W + 6
	var win := Rect2i(MARGIN + 12, MARGIN, w, UiTheme.LINE)
	clip(ci, win, true)
	if last:
		var warm := 0.5 + 0.5 * sin(_time * 3.2)
		UiDraw.frame(ci, win.grow(2), Color(UiTheme.WARN, 0.3 + 0.55 * warm))
	for i in cells.size():
		var cx := win.position.x + 6 + i * CELL_W
		for t in UiRules.PER_CELL:
			var col := UiTheme.WARN if last else UiTheme.TEXT
			if t >= cells[i]:
				col = UiTheme.GHOST
				if _hurt_flash > 0.0 and t < lost_cells[i]:
					col = UiTheme.WARN
			UiDraw.rect(ci, Rect2i(cx + t * 6, win.position.y + 4, 4, 14), col)
	if _wind_alpha > 0.0:
		# Wind: one thin line under the window, only while some is spent.
		var k := UiDraw.stepped(_wind_alpha)
		var fill := roundi((w - 4) * clampf(wind / maxf(1.0, max_wind), 0.0, 1.0))
		var wy := win.end.y + 6
		UiDraw.rect(ci, Rect2i(win.position.x - 2, wy - 2, w + 4, 6), Color(UiTheme.RIM, k * 0.85))
		UiDraw.rect(ci, Rect2i(win.position.x, wy, fill, 2), Color(UiTheme.PHOSPHOR[2], k))
	if _charge_alpha > 0.0:
		var k := UiDraw.stepped(_charge_alpha)
		var text := "%d" % charges
		var cw := Rect2i(win.end.x + 12, win.position.y, 26 + UiFont.width(text) + 16, UiTheme.LINE)
		if k >= 1.0:
			clip(ci, cw, false)
			_charge_glyph(ci, Vector2i(cw.position.x + 4, cw.position.y + 4), UiTheme.WARN if charges <= 0 else UiTheme.MACHINE[3])
			UiDraw.text(ci, Vector2i(cw.position.x + 26, cw.position.y), text, UiTheme.WARN if charges <= 0 else UiTheme.MACHINE[3])
		else:
			UiDraw.text_rimmed_faded(ci, Vector2i(cw.position.x + 26, cw.position.y), text, UiTheme.MACHINE[3], UiTheme.RIM, k)


## A found charge: a small violet cell with its slot lit.
static func _charge_glyph(ci: CanvasItem, at: Vector2i, col: Color) -> void:
	UiDraw.frame(ci, Rect2i(at.x, at.y, 18, 14), col)
	UiDraw.rect(ci, Rect2i(at.x + 4, at.y + 4, 10, 6), col)
	UiDraw.rect(ci, Rect2i(at.x + 18, at.y + 4, 2, 6), col)


func _draw_clock(ci: Control) -> void:
	var w := UiFont.width(clock_text) + 48
	var win := Rect2i(UiBase.SIZE.x - MARGIN - w, MARGIN, w, UiTheme.LINE)
	clip(ci, win, false)
	UiSlate.cell(ci, Vector2i(win.position.x + 6, win.position.y + 4), power)
	UiDraw.text(ci, Vector2i(win.position.x + 38, win.position.y), clock_text, UiTheme.TEXT)
	# Felt pressures, right to left under the clock, in a fixed order so they never swap.
	var x := UiBase.SIZE.x - MARGIN - GAUGE.x
	var level := {}
	var value := {}
	for p in pressures:
		level[p.id] = p.level
		value[p.id] = p.value
	for k: StringName in gauge_order(_gauge_alpha.keys()):
		var a: float = _gauge_alpha.get(k, 0.0)
		if a <= 0.0:
			continue
		var lv := int(level.get(k, 1))
		_draw_gauge(ci, k, Vector2i(x, win.end.y + 12), gauge_ink(lv), float(value.get(k, 0.5)), a, lv)
		x -= GAUGE.x + 10


## The gauges under the clock, in the order they stand out from it (GAUGE_ORDER
## first, then whatever the land presses with, by name).
static func gauge_order(ids: Array) -> Array[StringName]:
	var rest: Array = ids.duplicate()
	# By name: StringName's own ordering is by pointer, which is no order at all.
	rest.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var out: Array[StringName] = []
	for k in GAUGE_ORDER:
		if rest.has(k):
			rest.erase(k)
			out.append(k)
	for k: Variant in rest:
		out.append(StringName(k))
	return out


## The ink a gauge is drawn in at each rung. The UI is the quietest layer, so
## the full warning — the loudest colour the slate owns — is kept for the rung
## that ends the run. A pressure that merely bites is said by the phosphor the
## rest of the slate uses; only its meter runs in the dimmed warning, which is
## the part that is actually about how bad it is. Before this, six badges of
## saturated #ff6f4f sat in the top right of a snowfield at dusk and were the
## loudest pixels in the frame.
static func gauge_ink(level: int) -> Color:
	if level >= 3:
		return UiTheme.WARN
	return UiTheme.TEXT


## The ink a gauge's meter is drawn in: the bar is what says how hard it presses.
static func gauge_meter_ink(level: int) -> Color:
	if level >= 3:
		return UiTheme.WARN
	if level >= 2:
		return UiTheme.WARN_DIM
	return UiTheme.TEXT


## A felt pressure: its glyph on a scrap of glass, a meter under it filling
## with how hard it presses. At level 3 (starving, the lamp all but dry) the
## tile is bracketed and beats, so the last rung is never read as the middle one.
## `flare` 0..1 brackets the tile for a moment: this gauge has just answered for
## a line the glass did not say in words.
func _draw_gauge(ci: Control, id: StringName, at: Vector2i, col: Color, v: float, a: float, level: int = 1) -> void:
	# Fading, the whole tile steps in and out together (its glass holds the glyph).
	var k := UiDraw.stepped(a)
	if k <= 0.0:
		return
	var r := Rect2i(at, GAUGE)
	UiDraw.rect(ci, r.grow(2), Color(UiTheme.RIM, k))
	UiDraw.rect(ci, r, Color(UiTheme.GLASS, k))
	if level >= 3:
		var beat := 0.55 + 0.45 * sin(_time * 3.2)
		UiDraw.frame(ci, r.grow(2), Color(col, k * (0.35 + 0.55 * beat)))
	var flare := clampf(float(_gauge_flare.get(id, 0.0)) / GAUGE_FLARE, 0.0, 1.0)
	if flare > 0.0:
		# Brackets closing in on the tile, as they close on the location ping's
		# name: the eye is sent to the readout instead of to a line of text.
		# They stand over the world, so they carry their own shade — phosphor
		# alone is invisible over a snowfield.
		var out := r.grow(2 + roundi(flare * 8.0))
		var fa := k * (0.45 + 0.55 * flare)
		UiSlate.brackets(ci, Rect2i(out.position + Vector2i(0, 2), out.size), Color(UiTheme.RIM, fa * 0.85), 8)
		UiSlate.brackets(ci, out, Color(UiTheme.BRIGHT, fa), 8)
	UiDraw.sprite(ci, UiIcons.pressure_rows(id), at + Vector2i(4, 2), {"#": Color(col, k)})
	var mcol := gauge_meter_ink(level)
	var fill := roundi((GAUGE.x - 8) * clampf(v, 0.0, 1.0))
	UiDraw.rect(ci, Rect2i(at.x + 4, at.y + GAUGE.y - 8, GAUGE.x - 8, 4), Color(UiTheme.GHOST, k))
	UiDraw.rect(ci, Rect2i(at.x + 4, at.y + GAUGE.y - 8, fill, 4), Color(mcol, k))


func _draw_held(ci: Control) -> void:
	var name := UiRules.item_name(held) if held != &"" else "hands"
	var w := UiFont.width(name) + (38 if held != &"" else 12)
	var win := Rect2i(MARGIN + 12, UiBase.SIZE.y - MARGIN - UiTheme.LINE, w, UiTheme.LINE)
	clip(ci, win, true)
	var x := win.position.x + 6
	if held != &"":
		UiIcons.draw_item(ci, held, Vector2i(x, win.position.y + 2))
		x += 26
	UiDraw.text(ci, Vector2i(x, win.position.y), name, UiTheme.MACHINE[3] if UiIcons.is_found(held) else UiTheme.TEXT)


func _draw_bottom(ci: Control) -> void:
	# Newest message lowest; older ones stand above it, dimmer, until they fade.
	# A lesson standing on the key row below is not said again above it: the
	# guide says it as a message AND the row shows it with its cap, and the row
	# is the one that teaches the key (lockon_shoulder frame 03).
	var lines := messages.visible()
	if _hint_alpha > 0.0 and hint != "":
		lines = lines.filter(func(l: Dictionary) -> bool: return String(l.text) != hint)
	for i in lines.size():
		var line: Dictionary = lines[lines.size() - 1 - i]
		var a: float = line.alpha * (1.0 if i == 0 else 0.72)
		var text: String = line.text
		var y := UiBase.SIZE.y - MARGIN - 50 - i * UiTheme.LINE
		UiDraw.text_rimmed_faded(ci, Vector2i(UiBase.mid_x() - UiFont.width(text) / 2, y), text, UiTheme.TEXT if i == 0 else UiTheme.TEXT_DIM, UiTheme.RIM, a)
	if _hint_alpha > 0.0 and hint != "":
		var cap := maxi(18, UiFont.width(hint_key) + 8)
		var total := cap + 10 + UiFont.width(hint)
		var x := UiBase.mid_x() - total / 2
		var y := UiBase.SIZE.y - MARGIN - UiTheme.LINE
		var k := UiDraw.stepped(_hint_alpha)
		UiSlate.key_cap(ci, Vector2i(x, y), hint_key, k)
		UiDraw.text_rimmed_faded(ci, Vector2i(x + cap + 10, y + 2), hint, UiTheme.TEXT, UiTheme.RIM, _hint_alpha)


## What to want next: one quiet line hung off the wrist unit, a phosphor
## chevron before it. It stands (it is not a message that fades) so a player who
## looks up an hour later still knows what they were doing — and it hangs off a
## corner readout rather than banding the top middle, where the fight is and
## where nothing but the location ping belongs (docs/LOOK.md).
func _draw_goal(ci: Control) -> void:
	if not goal_shown():
		return
	var r := Hud.goal_clip(goal)
	# In a window, like every other readout on this glass. Dim phosphor with a
	# rim stood at 1.00:1 against the ground beside its own letters over a
	# snowfield at noon: the one line that says what to do next, unreadable in
	# the landscape a player is most likely to be lost in.
	Hud.clip(ci, r, false)
	var x := MARGIN + 12
	UiSlate.chevron(ci, Vector2i(x, GOAL_Y + 6), UiTheme.PHOSPHOR[2])
	UiDraw.text(ci, Vector2i(x + 14, GOAL_Y), goal, UiTheme.TEXT)


## The window the goal line is read off, for a goal of this length.
static func goal_clip(text: String) -> Rect2i:
	return Rect2i(MARGIN + 4, GOAL_Y - 4, 30 + UiFont.width(text), UiTheme.LINE + 6)


## How far from the middle each bracket of the place name stands, `grow` 0..1
## through the ping's rise. They close IN from outside the word to their place
## and never sweep across the letters: a bright mark travelling over a name
## reads as a name struck out (docs/LOOK.md — the slate's type is exact).
static func place_half(w: int, grow: float) -> int:
	return roundi(w / 2.0 + PLACE_CLEAR + (1.0 - clampf(grow, 0.0, 1.0)) * PLACE_SWEEP)


## The scrap of glass the landscape's name is read off. Every other readout sits
## in one (see `clip`); the ping did not, and over the snowfield at noon its
## phosphor green stood on near-white paper at 3.5:1 — the name of the place
## you have just walked into, unreadable. Its ends are where the brackets come
## to rest, so the plate IS the clip they close on.
static func place_plate(w: int) -> Rect2i:
	var half := place_half(w, 1.0)
	return Rect2i(UiBase.mid_x() - half, PLACE_Y - 30, half * 2, 54)


## Where the ping's ring stands at `age`, in screen pixels: an ellipse ringing
## OUT from the plate's own edge, never inside it.
##
## It used to start at the middle and grow through the word, and the 0.5
## vertical squash clustered its samples at the horizontal extremes — exactly
## the height of the letters — so `C O A S T` read `C ⌷CH:S T` for half a
## second, which is when the eye lands on it. A bright mark travelling over a
## name reads as a name struck out; that was true of the ring as well as of
## the brackets, and the ring is the thing that was crossing.
static func ring_points(age: float, plate: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if age < 0.0 or age >= RING_LIFE:
		return out
	var t := age / RING_LIFE
	var c := plate.get_center()
	var rx := plate.size.x * 0.5 + RING_GAP + t * RING_REACH
	var ry := plate.size.y * 0.5 + RING_GAP + t * RING_REACH * 0.5
	# Sampled by how far round the ellipse is, not by a fixed count: forty
	# samples on an ellipse as wide as a place name stood eight pixels apart and
	# read as dust blown over the snow, not as a ring.
	var steps := clampi(roundi((rx + ry) * 5.0), RING_STEPS, RING_STEPS_MAX)
	var clear := plate.grow(4)
	var last := Vector2i(-9999, -9999)
	for s in steps:
		var an := s * TAU / float(steps)
		var p := Vector2i(c.x + roundi(cos(an) * rx), c.y + roundi(sin(an) * ry))
		if p == last:
			continue
		last = p
		if clear.has_point(p):
			continue
		out.append(p)
	return out


## How brightly the ring stands at `age`, 0..1. It is the ping itself, so it is
## brightest as it leaves and spends what it has on the way out — it does not
## wait on the plate's rise the way the lettering does.
static func ring_alpha(age: float) -> float:
	if age < 0.0 or age >= RING_LIFE:
		return 0.0
	return pow(1.0 - age / RING_LIFE, 1.3)


## The ping's two inks at `age`, given the ping's own alpha `a`: [glass, type].
## The plate is opaque before there is anything to read on it, and the lettering
## and the label come up over the rest of the rise.
static func place_rise(age: float, a: float) -> Array[float]:
	var glass := minf(a, clampf(age / PLATE_IN, 0.0, 1.0))
	var ink := minf(a, clampf((age - PLATE_IN) / maxf(PLACE_IN - PLATE_IN, 0.001), 0.0, 1.0))
	return [glass, ink]


## The location ping: the landscape's name on a scrap of the slate's glass,
## brackets closing on its ends, a ring going out around it over the world.
func _draw_place(ci: Control) -> void:
	var a := place_alpha()
	if a <= 0.0 or place == "":
		return
	var spaced := ""
	for i in place.length():
		spaced += (" " if i > 0 else "") + place[i].to_upper()
	var w := UiFont.width(spaced)
	var y := PLACE_Y
	var rise := Hud.place_rise(_place_age, a)
	var k := UiDraw.stepped(rise[0])
	var ink := UiDraw.stepped(rise[1])
	var grow := clampf(_place_age / PLACE_IN, 0.0, 1.0)
	var plate := place_plate(w)
	place_glass(ci, plate, k)
	# The ring rings out over the world, so it carries its own shade: bright
	# phosphor alone is invisible over a snowfield. Drawn after the plate, and
	# starting clear of it, so the plate's own rim cannot swallow it.
	# Not multiplied by the ping's own rise: the ring is the arrival, and the
	# rise is near nothing exactly when the ring is furthest out. A ping hushed
	# by a fight throws `_place_age` past RING_LIFE, so the ring goes with it.
	var ring_a := UiDraw.stepped(Hud.ring_alpha(_place_age)) * 0.9
	if ring_a > 0.0:
		for p in Hud.ring_points(_place_age, plate):
			UiDraw.px(ci, p.x, p.y + UiBase.PITCH, Color(UiTheme.RIM, ring_a * 0.8))
			UiDraw.px(ci, p.x, p.y, Color(UiTheme.BRIGHT, ring_a))
	UiDraw.text(ci, Vector2i(UiBase.mid_x() - w / 2, y), spaced, Color(UiTheme.BRIGHT, ink))
	UiDraw.text(ci, Vector2i(UiBase.mid_x() - UiFont.width("location") / 2, y - 24), "location", Color(UiTheme.TEXT_DIM, ink))
	var half := place_half(w, grow)
	for side: int in [-1, 1]:
		var bx := UiBase.mid_x() + side * half
		UiDraw.rect(ci, Rect2i(bx - 2, plate.position.y - 2, 6, plate.size.y + 4), Color(UiTheme.RIM, k))
		UiDraw.rect(ci, Rect2i(bx, plate.position.y, 2, plate.size.y), Color(UiTheme.TEXT, k))
		UiDraw.rect(ci, Rect2i(mini(bx, bx - side * 6), plate.position.y, 6, 2), Color(UiTheme.TEXT, k))
		UiDraw.rect(ci, Rect2i(mini(bx, bx - side * 6), plate.end.y - 2, 6, 2), Color(UiTheme.TEXT, k))


## The ping's glass: the same window `clip` gives every corner readout, held on
## by nothing — it is thrown on the middle of the lens while the slate reads the
## ground, and taken off again.
static func place_glass(ci: CanvasItem, r: Rect2i, k: float) -> void:
	if k <= 0.0:
		return
	var F := Palette.FOUND
	UiDraw.rect(ci, Rect2i(r.position.x - 2, r.position.y, r.size.x + 4, r.size.y), Color(UiTheme.RIM, k))
	UiDraw.rect(ci, Rect2i(r.position.x, r.position.y - 2, r.size.x, r.size.y + 4), Color(UiTheme.RIM, k))
	UiDraw.rect(ci, r, Color(UiTheme.GLASS, k))
	for y in range(r.position.y + UiBase.PITCH, r.end.y, UiBase.PITCH * 2):
		UiDraw.rect(ci, Rect2i(r.position.x, y, r.size.x, UiBase.PITCH), Color(UiTheme.GLASS_ROW, k))
	UiDraw.rect(ci, Rect2i(r.position.x + 8, r.position.y - 2, r.size.x - 18, 2), Color(F[1], k * 0.8))
	UiDraw.rect(ci, Rect2i(r.position.x + 8, r.end.y, r.size.x - 18, 2), Color(F[1], k * 0.55))
