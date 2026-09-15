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
const CELL_H := 8
## One cell of the health tally: three strokes and the gap after them.
const TALLY_W := 12
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
## Pages open now. A page takes the messages said while it is up, so the HUD
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
	Events.screen_changed.connect(_on_screen_changed)


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
	UiDraw.text_rimmed_faded(ci, Vector2i(x, y), spaced, UiTheme.HUD_TEXT, UiTheme.INK_DEEP, a)
	var half := roundi((w / 2 + 16) * clampf(_place_age / PLACE_IN, 0.0, 1.0))
	var k := UiDraw.stepped(a)
	UiDraw.rect(ci, Rect2i(320 - half - 1, y + 13, half * 2 + 2, 3), Color(UiTheme.INK_DEEP, k))
	UiDraw.hline(ci, 320 - half, 320 + half, y + 14, UiTheme.HUD_DIM.lerp(UiTheme.INK_DEEP, 1.0 - k))


func _draw_health(ci: Control) -> void:
	# Health kept as a tally on a paper tag: three pen strokes to a cell, leaning
	# a little the way a hand makes them. A spent stroke is left as a pencil
	# ghost; a fresh loss shows in the accent before it goes. With one cell left
	# the strokes turn to the accent and the tag's rim warms and cools.
	var cells := UiRules.health_cells(health, max_health)
	var lost_cells := UiRules.health_cells(_lost_from, max_health)
	var x := MARGIN
	var y := MARGIN
	var w := cells.size() * TALLY_W + 1
	var tag := Rect2i(x, y, w, CELL_H + 3)
	var last := health > 0 and health <= UiRules.PER_CELL
	UiDraw.rect(ci, Rect2i(tag.position.x + 1, tag.position.y - 1, tag.size.x - 2, tag.size.y + 2), UiTheme.INK_DEEP)
	UiDraw.rect(ci, tag.grow_individual(1, 0, 1, 0), UiTheme.INK_DEEP)
	if last:
		var warm := 0.5 + 0.5 * sin(_time * 3.2)
		UiDraw.frame(ci, tag.grow(1), Color(UiTheme.ACCENT_BRIGHT, 0.3 + 0.55 * warm))
	UiDraw.rect(ci, tag, UiTheme.PAPER)
	UiDraw.hline(ci, tag.position.x, tag.end.x - 1, tag.end.y - 1, UiTheme.PAPER_SHADE)
	for i in cells.size():
		var cx := x + 3 + i * TALLY_W
		for t in UiRules.PER_CELL:
			var sx := cx + t * 3
			var col := UiTheme.ACCENT if last else UiTheme.INK
			if t >= cells[i]:
				col = UiTheme.PAPER_SHADE
				if _hurt_flash > 0.0 and t < lost_cells[i]:
					col = UiTheme.ACCENT_BRIGHT
			# Each stroke leans: its top a pixel right of its foot, and no two alike.
			var jog := 3 + (i * 7 + t * 5) % 2
			UiDraw.vline(ci, sx + 1, y + 1, y + jog - 1, col)
			UiDraw.vline(ci, sx, y + jog, y + CELL_H, col)
	if _wind_alpha > 0.0:
		# Wind: one thin line under the tag, pale as breath, only while some is spent.
		var fill := roundi((w - 2) * clampf(wind / maxf(1.0, max_wind), 0.0, 1.0))
		var wy := tag.end.y + 3
		var k := UiDraw.stepped(_wind_alpha)
		UiDraw.rect(ci, Rect2i(MARGIN, wy - 1, w, 3), Color(UiTheme.INK_DEEP, k * 0.8))
		UiDraw.rect(ci, Rect2i(MARGIN + 1, wy, fill, 1), Color(Palette.RIME[5], k))


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
	UiDraw.sprite_rimmed_faded(ci, UiIcons.NEEDS[k], at, {"#": col}, UiTheme.INK_DEEP, a)


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
		UiDraw.text_rimmed_faded(ci, Vector2i(320 - UiFont.width(text) / 2, y), text, UiTheme.HUD_TEXT if i == 0 else UiTheme.HUD_DIM, UiTheme.INK_DEEP, a)
	if _hint_alpha > 0.0 and hint != "":
		var total := 11 + 4 + UiFont.width(hint)
		var x := 320 - total / 2
		var y := 360 - MARGIN - UiFont.SIZE
		_draw_key(ci, Vector2i(x, y), hint_key, UiDraw.stepped(_hint_alpha))
		UiDraw.text_rimmed_faded(ci, Vector2i(x + 15, y + 1), hint, UiTheme.HUD_TEXT, UiTheme.INK_DEEP, _hint_alpha)


## A little paper key cap with the letter in ink, as one picture so it fades
## as a whole (its layers, faded one by one, would show through each other).
static func _draw_key(ci: CanvasItem, at: Vector2i, key: String, a: float) -> void:
	if a <= 0.0:
		return
	var rows := key_rows(key)
	var colours := {"k": UiTheme.INK_DEEP, "p": UiTheme.PAPER, "d": UiTheme.PAPER_DEEP, "i": UiTheme.INK}
	var top := Vector2i(at.x, at.y - 1)
	if a >= 1.0:
		UiDraw.sprite(ci, rows, top, colours)
	else:
		# picture() pads a pixel all round for a rim; a clear rim keeps the cap exact.
		ci.draw_texture(UiDraw.picture("key|" + key, rows, colours, Color(0, 0, 0, 0), false), Vector2(top - Vector2i.ONE), Color(1, 1, 1, a))


## The key cap's pixels: 11x12, rounded ink corners, paper face, a deeper
## bottom edge, the letter centred in ink.
static func key_rows(key: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for y in 12:
		var row := ""
		for x in 11:
			var corner := (x == 0 or x == 10) and (y == 0 or y == 11)
			var edge := x == 0 or x == 10 or y == 0 or y == 11
			if corner:
				row += "."
			elif edge:
				row += "k"
			elif y == 10:
				row += "d"
			else:
				row += "p"
		rows.append(row)
	var g := UiFont.glyph(key)
	var gx := 6 - UiFont.width(key) / 2
	for r in g.size():
		for c in g[r].length():
			var y := r + 2
			var x := gx + c
			if g[r][c] == "#" and y < 12 and x < 11:
				rows[y] = rows[y].substr(0, x) + "i" + rows[y].substr(x + 1)
	return rows
