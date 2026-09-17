class_name UiCharacterScreen
extends UiScreen
## Who wakes on the coast: the character page, between "new game" on the title and
## the world (owner, 2026-09-17: "an initial character builder where a fully
## configurable character is created/configured and selected at game start").
##
## Every row is a thing about the body in the people model's own words
## (PersonLook): its build, skin, hair and beard, the hat, coat, shirt, trousers and
## boots it starts in and their colours, what it carries on it, how mended its
## clothes are. Left and right change a row; "someone else" deals a whole new
## person; "begin" starts the game with this one. The body is drawn beside the list
## by the gear page's own figure (UiGearFigure) in its colour, since colour is half
## of what is being chosen here — and it is the SAME body the gear page later dresses,
## because what begins here is AvatarState, and GearLook puts gear on over it.
##
## On the title there is no ui system: the page reads its own keys (`standalone`),
## as the settings page does there.

signal begun(look: Dictionary)

const LIST_TOP := 26
const ROW_PITCH := 12
const VALUE_W := 92
## Where the body stands on the spare panel.
const FIGURE := Rect2i(360, 44, 200, 250)

## The rows: `key` a PersonLook field chosen from `choices(key)`, `extra` a thing
## worn or not.
const ROWS: Array[Dictionary] = [
	{"id": &"build", "label": "build", "key": "build"},
	{"id": &"skin", "label": "skin", "key": "skin"},
	{"id": &"skin_v", "label": "skin tone", "key": "skin_v"},
	{"id": &"hair_style", "label": "hair", "key": "hair_style"},
	{"id": &"hair", "label": "hair colour", "key": "hair"},
	{"id": &"beard", "label": "beard", "key": "beard"},
	{"id": &"hat", "label": "hat", "key": "hat"},
	{"id": &"hat_col", "label": "hat colour", "key": "hat_col"},
	{"id": &"coat", "label": "coat", "key": "coat"},
	{"id": &"coat_col", "label": "coat colour", "key": "coat_col"},
	{"id": &"shirt_cut", "label": "shirt", "key": "shirt_cut"},
	{"id": &"shirt", "label": "shirt colour", "key": "shirt"},
	{"id": &"trouser", "label": "trousers", "key": "trouser"},
	{"id": &"boot", "label": "boots", "key": "boot"},
	{"id": &"neckerchief", "label": "neckerchief", "extra": &"neckerchief"},
	{"id": &"satchel", "label": "satchel", "extra": &"satchel"},
	{"id": &"rolled", "label": "sleeves rolled", "extra": &"rolled"},
	{"id": &"apron", "label": "apron", "extra": &"apron"},
	{"id": &"patches", "label": "patches", "key": "patches"},
]
## What the key strip and the tests read the page's own keys as.
const KEYS: Array[Array] = [
	[&"move_up", &"up"], [&"move_down", &"down"], [&"move_left", &"left"], [&"move_right", &"right"],
	[&"use", &"confirm"], [&"pause", &"back"],
]

## The body being made, a PersonLook spec.
var look: Dictionary = PersonLook.BASE.duplicate(true)
var standalone := false
## Where "someone else" deals from: the island's seed, and how many have been dealt.
var seed_value := 1
var figure: UiGearFigure
var _dealt := 0
var _was: Dictionary = {}
var _opened_frame := -1
var _vertical := UiMenu.new()
var _horizontal := UiMenu.new()


func _init() -> void:
	super()
	screen_name = &"character"
	own_action = &""
	device_rect = UiSlate.DEVICE
	figure = UiGearFigure.new()
	figure.name = "figure"
	figure.in_colour = true
	figure.place(FIGURE)
	add_child(figure)


## What a row may be. Builds are the grown ones: the one who wakes on this coast
## has been surviving it.
static func choices(key: String) -> Array:
	match key:
		"build":
			return PersonLook.BUILDS.filter(func(b: StringName) -> bool: return b != &"boy")
		"skin": return PersonLook.SKIN_WINDOWS.duplicate()
		"skin_v": return [1, 2, 3]
		"hair_style": return PersonLook.HAIR_STYLES.duplicate()
		"hair": return PersonLook.HAIR_PRESETS.duplicate()
		"beard": return PersonLook.BEARDS.duplicate()
		"hat": return PersonLook.FAIR_HATS.duplicate()
		"coat": return PersonLook.FAIR_COATS.duplicate()
		"shirt_cut": return PersonLook.SHIRT_CUTS.duplicate()
		"hat_col": return _shades(PersonLook.HAT_WEAR)
		"coat_col": return _shades(PersonLook.COAT_WEAR)
		"shirt": return _shades(PersonLook.SHIRT_WEAR)
		"trouser": return _shades(PersonLook.TROUSER_WEAR)
		"boot": return _shades(PersonLook.BOOT_WEAR)
		"patches": return [0, 1, 2, 3]
	return []


## Every "ramp:step" a wear table allows, in its own order, once each.
static func _shades(table: Array) -> Array:
	var out: Array = []
	for e: Array in table:
		for v in range(int(e[1]), int(e[2]) + 1):
			var s := "%s:%d" % [e[0], v]
			if not out.has(s):
				out.append(s)
	return out


## `look` with row `row` stepped `dir` through what it may be, wrapping.
static func stepped(spec: Dictionary, row: Dictionary, dir: int) -> Dictionary:
	var out := spec.duplicate(true)
	if row.has("extra"):
		var extras: Array = (out.get("extras", []) as Array).duplicate()
		var e: StringName = row.extra
		if extras.has(e):
			extras.erase(e)
		else:
			extras.append(e)
		out["extras"] = extras
		return out
	var key: String = row.key
	var all := choices(key)
	if all.is_empty():
		return out
	var at := -1
	for i in all.size():
		if str(all[i]) == str(out.get(key, "")):
			at = i
			break
	out[key] = all[posmod(at + dir, all.size())] if at >= 0 else all[0]
	return out


## What a row reads as, in words.
static func value_words(spec: Dictionary, row: Dictionary) -> String:
	if row.has("extra"):
		return "worn" if (spec.get("extras", []) as Array).has(row.extra) else "none"
	var v: Variant = spec.get(row.key, "")
	match String(row.key):
		"skin_v":
			return ["darker", "middle", "lighter"][clampi(int(v) - 1, 0, 2)]
		"patches":
			return ["none", "one", "a few", "many"][clampi(int(v), 0, 3)]
	return str(v).replace(":", " ").replace("_", " ")


func _on_open() -> void:
	if standalone:
		_opened_frame = Engine.get_process_frames()
		for pair: Array in KEYS:
			_was[pair[0]] = InputMap.has_action(pair[0]) and Input.is_action_pressed(pair[0])
	refresh()


func refresh() -> void:
	var rows: Array[Dictionary] = []
	for r: Dictionary in ROWS:
		rows.append({"id": r.id, "row": r})
	rows.append({"id": &"shuffle", "text": "someone else"})
	rows.append({"id": &"begin", "text": "begin"})
	var was := StringName(menu.selected().get("id", &""))
	menu.set_rows(rows)
	if was != &"":
		for i in menu.rows.size():
			if menu.rows[i].id == was:
				menu.index = i
	_dress()
	queue_redraw()


func _dress() -> void:
	figure.wear(look, &"", false)


func _on_side(dir: int) -> void:
	var row := menu.selected()
	if row.has("row"):
		look = stepped(look, row.row, dir)
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		_dress()
		queue_redraw()
	else:
		# Nothing to change on "someone else" or "begin": the same keys turn the body.
		figure.nudge(dir)


func _on_confirm(row: Dictionary) -> void:
	match row.id:
		&"shuffle":
			_dealt += 1
			var dealt := PersonLook.random(seed_value, _dealt)
			# A stranger's hat, coat and kit are theirs; the body and its clothes are
			# what is dealt here, and gear comes later, from the world.
			look = AvatarState.bare(dealt)
			if not choices("build").has(look.get("build", &"man")):
				look["build"] = &"slight"
			Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
			_dress()
			queue_redraw()
		&"begin":
			Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
			begun.emit(AvatarState.bare(PersonLook.normalize(look)))
		_:
			_on_side(1)


func settle() -> void:
	super.settle()
	figure.settle()


func _process(delta: float) -> void:
	super(delta)
	if is_open and standalone:
		_read_keys(delta)


func _read_keys(delta: float) -> void:
	var tapped := {}
	var fresh := Engine.get_process_frames() != _opened_frame
	for pair: Array in KEYS:
		if not InputMap.has_action(pair[0]):
			continue
		var now := Input.is_action_pressed(pair[0])
		var went_down: bool = (now and not _was.get(pair[0], false)) or Input.is_action_just_pressed(pair[0])
		_was[pair[0]] = now
		if not went_down or not fresh:
			continue
		if pair[1] in [&"up", &"down", &"left", &"right"]:
			tapped[pair[1]] = true
			continue
		handle(pair[1])
		if not is_open:
			return
	if not fresh:
		return
	_step_axis(_vertical, tapped, &"up", &"down", _axis(&"move_up", &"move_down"), delta)
	_step_axis(_horizontal, tapped, &"left", &"right", _axis(&"move_left", &"move_right"), delta)


func _step_axis(m: UiMenu, tapped: Dictionary, neg: StringName, pos: StringName, held: int, delta: float) -> void:
	var dir := (1 if tapped.has(pos) else 0) - (1 if tapped.has(neg) else 0)
	if dir != 0:
		handle(pos if dir > 0 else neg)
		m.hold(dir, 0.0)
		return
	for i in m.hold(held, delta):
		handle(pos if held > 0 else neg)


func _axis(neg: StringName, pos: StringName) -> int:
	var a := 1 if InputMap.has_action(pos) and Input.is_action_pressed(pos) else 0
	var b := 1 if InputMap.has_action(neg) and Input.is_action_pressed(neg) else 0
	return a - b


# --- drawn ----------------------------------------------------------------

## The device with no app tabs: nothing else on the slate exists yet.
func draw_frame(_app: StringName = screen_name) -> void:
	UiSlate.veil(self)
	draw_device()
	UiSlate.status(self, &"", "", power, device_rect, false)


func _draw() -> void:
	draw_frame()
	var L := UiSlate.LIST
	var R := UiSlate.SPARE
	UiSlate.title(self, L, "WHO WAKES")
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 8
	var first := L.position.y + LIST_TOP
	for i in menu.rows.size():
		var row := menu.rows[i]
		var top := first + i * ROW_PITCH
		if row.id == &"shuffle":
			top += 4
		elif row.id == &"begin":
			top += 6
		var chosen := i == menu.index
		if chosen:
			UiSlate.row_bar(self, x0 - 4, right + 3, top)
		if row.has("row"):
			var r: Dictionary = row.row
			UiDraw.text(self, Vector2i(x0 + 4, top), String(r.label), UiTheme.BRIGHT if chosen else UiTheme.TEXT)
			var words := value_words(look, r)
			var col := UiTheme.BRIGHT if chosen else UiTheme.TEXT_DIM
			UiDraw.text_right(self, right - (8 if chosen else 0), top, words, col)
			if chosen:
				UiDraw.text(self, Vector2i(right - 14 - UiFont.width(words), top), "<", UiTheme.TEXT)
				UiDraw.text(self, Vector2i(right - 5, top), ">", UiTheme.TEXT)
		else:
			UiDraw.text(self, Vector2i(x0 + 4, top), String(row.text), UiTheme.BRIGHT if chosen else UiTheme.TEXT)
	# The body, standing in the spare panel's bay.
	var px := R.position.x + UiSlate.MARGIN_L
	UiSlate.heading(self, Vector2i(px, R.position.y + 8), "the one who wakes", R.end.x - 12)
	var foot := Vector2i(FIGURE.position.x + FIGURE.size.x / 2, FIGURE.end.y - 8)
	for k in 36:
		var a := k * TAU / 36.0
		UiDraw.px(self, foot.x + roundi(cos(a) * 58.0), foot.y + roundi(sin(a) * 9.0), UiTheme.FAINT)
	var chosen_row := menu.selected()
	var says := "a d to change it" if chosen_row.has("row") else ("a d to turn them" if chosen_row.id != &"begin" else "wake on the coast behind the slate")
	UiDraw.text(self, Vector2i(px, R.end.y - 14), says, UiTheme.TEXT_DIM)
	var keys := [["a d", "change"], ["e", "begin" if chosen_row.get("id", &"") == &"begin" else "next"], ["esc", "back"]]
	draw_keys(keys)
