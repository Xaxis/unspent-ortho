class_name UiSettingsScreen
extends UiScreen
## The settings app (owner, 2026-09-17): how loud it is, how big the window is,
## what each key does, and the few switches a player expects to find. Reached
## from the pause page and from the title, and it is the same page in both.
##
## Left: the settings, in their groups. Right: what the row under the cursor
## means, in plain words, because a slider called "the world" should say what the
## world is. Left and right change a value; on the KEYS page, E asks for a key
## and the next one pressed is bound to that action.
##
## It reads the LIVE input map, never a written list of letters: the controls
## page it replaces was a const table that had already drifted from the keys the
## game actually uses (no craft key, no dev key), and a page that lies about the
## controls is worse than no page.

const LIST_TOP := 26
const ROW_PITCH := 15
const BAR_CELLS := 10
## A row's value is drawn from here to the right edge of the list pane.
const VALUE_W := 86

## "list" or "keys".
var page := "list"
## While a key is being asked for: the action waiting for it, or &"".
var catching: StringName = &""
## On the title there is no ui system to route actions here, so the app reads the
## keys itself, as dev mode's does (`UiDevScreen.standalone`).
var standalone := false
var _stolen: StringName = &""
var _was: Dictionary = {}
var _opened_frame := -1
var _vertical := UiMenu.new()
var _horizontal := UiMenu.new()

## What a key does on this page, when this page is reading them itself.
const KEYS: Array[Array] = [
	[&"move_up", &"up"], [&"move_down", &"down"], [&"move_left", &"left"], [&"move_right", &"right"],
	[&"use", &"confirm"], [&"pause", &"back"],
]


func _init() -> void:
	super()
	screen_name = &"settings"
	own_action = &""


func _on_open() -> void:
	page = "list"
	catching = &""
	scroll = 0
	PlayerSettings.load_once()
	if standalone:
		# The key that opened it is still down this frame: taken as held, not as a
		# fresh press, or the app opens and acts on the same stroke.
		_opened_frame = Engine.get_process_frames()
		for pair: Array in KEYS:
			_was[pair[0]] = InputMap.has_action(pair[0]) and Input.is_action_pressed(pair[0])
	refresh()


func _on_close() -> void:
	catching = &""


func refresh() -> void:
	var rows: Array[Dictionary] = []
	if page == "keys":
		for b: Dictionary in PlayerSettings.BINDABLE:
			if not InputMap.has_action(b.action):
				# An action a package adds only when it is loaded (a craft's, a
				# sentinel's): not in this build, so not on this page either.
				continue
			rows.append({"id": b.action, "action": b.action, "text": b.label, "key": true})
		rows.append({"id": &"keys_reset", "text": "put the keys back"})
		rows.append({"id": &"keys_done", "text": "back"})
	else:
		for group: StringName in PlayerSettings.GROUPS:
			rows.append({"header": _group_name(group)})
			for r: Dictionary in PlayerSettings.ROWS:
				if r.group != group:
					continue
				if r.get("applies", &"") == &"window" and not SettingsApply.can_set_window():
					# A browser canvas has no window a player can size: the row is
					# left out rather than shown doing nothing.
					continue
				rows.append({"id": r.id, "text": r.label, "row": r})
		rows.append({"header": "keys"})
		rows.append({"id": &"keys", "text": "what each key does"})
		rows.append({"id": &"reset", "text": "everything back to how it came"})
	menu.set_rows(rows)
	queue_redraw()


static func _group_name(group: StringName) -> String:
	match group:
		&"sound": return "sound"
		&"picture": return "picture"
		&"playing": return "playing"
	return String(group)


# --- keys in --------------------------------------------------------------

func handle(action: StringName) -> bool:
	if not is_open:
		return false
	if catching != &"":
		# Only Esc gets through while a key is being asked for; everything else
		# is a key the player might want to bind, and _unhandled_key_input has it.
		if action == &"back":
			catching = &""
			note = "left it as it was"
			queue_redraw()
		return true
	if page == "keys" and action == &"back":
		page = "list"
		Events.sfx.emit(&"ui_slate_back", Vector3.ZERO)
		refresh()
		return true
	if action == &"left" or action == &"right":
		var row := menu.selected()
		if row.has("row"):
			PlayerSettings.step(StringName(row.row.id), 1 if action == &"right" else -1)
			Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
			queue_redraw()
			return true
	return super(action)


func _on_confirm(row: Dictionary) -> void:
	match row.get("id", &""):
		&"keys":
			page = "keys"
			Events.sfx.emit(&"ui_slate_switch", Vector3.ZERO)
			refresh()
			return
		&"keys_done":
			page = "list"
			Events.sfx.emit(&"ui_slate_back", Vector3.ZERO)
			refresh()
			return
		&"keys_reset":
			PlayerSettings.reset_keys()
			note = "the keys are as they came"
			Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
			refresh()
			return
		&"reset":
			PlayerSettings.reset_all()
			note = "everything is as it came"
			Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
			refresh()
			return
	if row.get("key", false):
		catching = row.action
		_stolen = &""
		note = "press a key for it"
		Events.sfx.emit(&"ui_slate_switch", Vector3.ZERO)
		queue_redraw()
		return
	if row.has("row"):
		# Confirm on a setting is the same as pressing right: one key does
		# something on every row, which is what a player tries first.
		PlayerSettings.step(StringName(row.row.id), 1)
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		queue_redraw()


## The one place this app reads a device: a key being bound is a key, not an
## action, or a player could never bind the key an action is already on.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_open or catching == &"":
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	get_viewport().set_input_as_handled()
	var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	if code == KEY_ESCAPE:
		catching = &""
		note = "left it as it was"
		queue_redraw()
		return
	_stolen = PlayerSettings.bind_key(catching, code)
	note = "%s is %s" % [_label_of(catching), _key_name(code)]
	if _stolen != &"":
		note = "%s is %s, and %s has nothing" % [_label_of(catching), _key_name(code), _label_of(_stolen)]
		note_warn = true
	catching = &""
	Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	refresh()


static func _label_of(action: StringName) -> String:
	for b: Dictionary in PlayerSettings.BINDABLE:
		if b.action == action:
			return b.label
	return String(action)


static func _key_name(code: int) -> String:
	if code == KEY_NONE:
		return "nothing"
	return OS.get_keycode_string(code).to_lower()


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
		# Just pressed as well as newly held: a key struck and let go inside one
		# frame (a browser delivers a tap that way) is never seen down.
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

func _draw() -> void:
	draw_frame()
	var L := UiSlate.LIST
	UiSlate.title(self, L, "SETTINGS" if page == "list" else "KEYS")
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 8
	# The keys page grows with every action a package adds, and it outgrew the
	# pane once: the rows past the glass could still be chosen, blind. It scrolls
	# with the cursor now, the way every other long list on the slate does.
	var first := L.position.y + LIST_TOP
	var lines := (L.end.y - ROW_PITCH - first) / ROW_PITCH + 1
	keep_in_view(lines)
	for n in mini(lines, menu.rows.size() - scroll):
		var i := scroll + n
		var row := menu.rows[i]
		var top := first + n * ROW_PITCH
		if row.has("header"):
			UiDraw.text(self, Vector2i(x0, top), String(row.header).to_upper(), UiTheme.TEXT_DIM)
			UiDraw.hline(self, x0, right, top + 10, UiTheme.GHOST)
			continue
		var chosen := i == menu.index
		if chosen:
			UiDraw.rect(self, Rect2i(x0 - 4, top - 2, right - x0 + 7, ROW_PITCH - 3), UiTheme.GLASS_LIT)
			UiDraw.rect(self, Rect2i(x0 - 4, top - 2, 2, ROW_PITCH - 3), UiTheme.TEXT)
		UiDraw.text(self, Vector2i(x0 + 4, top), String(row.text), UiTheme.BRIGHT if chosen else UiTheme.TEXT)
		if row.get("key", false):
			_draw_key_value(row, right, top, chosen)
		elif row.has("row"):
			_draw_value(row.row, right, top, chosen)
	if scroll > 0:
		UiDraw.text_right(self, right, first - UiTheme.LINE - 1, "↑", UiTheme.TEXT_DIM)
	if scroll + lines < menu.rows.size():
		UiDraw.text_right(self, right, first + lines * ROW_PITCH - 4, "↓", UiTheme.TEXT_DIM)
	_draw_help()
	if page == "keys":
		draw_keys([["e", "ask for a key"], ["esc", "back"]])
	else:
		draw_keys([["left right", "change it"], ["e", "change it"], ["esc", "back"]])


func _draw_key_value(row: Dictionary, right: int, top: int, chosen: bool) -> void:
	if catching == row.action:
		UiDraw.text_right(self, right, top, "press a key", UiTheme.WARN)
		return
	var code := PlayerSettings.key_of(row.action)
	var word := _key_name(code)
	var x := right - UiFont.width(word) - 8
	UiSlate.mini_cap(self, Vector2i(x, top + 1), word)
	if code == KEY_NONE:
		UiDraw.text_right(self, right, top, "nothing", UiTheme.WARN)


func _draw_value(r: Dictionary, right: int, top: int, chosen: bool) -> void:
	var v: Variant = PlayerSettings.value(r.id)
	match StringName(str(r.kind)):
		PlayerSettings.LEVEL:
			var full := int(roundf(float(v) * BAR_CELLS))
			var x := right - VALUE_W
			for c in BAR_CELLS:
				var cell := Rect2i(x + c * 8, top + 2, 6, 7)
				UiDraw.rect(self, cell, UiTheme.TEXT if c < full else UiTheme.GHOST)
		PlayerSettings.SWITCH:
			UiDraw.text_right(self, right, top, "on" if bool(v) else "off",
				UiTheme.TEXT if bool(v) else UiTheme.TEXT_DIM)
		PlayerSettings.CHOICE:
			var word := str(v)
			if r.id == &"picture.scale":
				word = "%dx" % int(v)
			UiDraw.text_right(self, right, top, word, UiTheme.TEXT)


## The right-hand panel: what the row under the cursor is, said plainly.
func _draw_help() -> void:
	var R := UiSlate.SPARE
	var x := R.position.x + 6
	var y := R.position.y + 8
	var row := menu.selected()
	if page == "keys":
		UiDraw.text(self, Vector2i(x, y), "E asks for a key.", UiTheme.TEXT_DIM)
		UiSlate.wrapped(self, Vector2i(x, y + 22), R.size.x - 12,
			"A key may only do one thing: bound to something else, it is taken off that.", UiTheme.TEXT_DIM)
		return
	if row.has("row"):
		var r: Dictionary = row.row
		UiDraw.text(self, Vector2i(x, y), String(r.label).to_upper(), UiTheme.TEXT)
		var help := String(r.get("help", ""))
		if help != "":
			UiSlate.wrapped(self, Vector2i(x, y + 16), R.size.x - 12, help, UiTheme.TEXT_DIM)
		UiDraw.text(self, Vector2i(x, R.end.y - 26), "left  right", UiTheme.TEXT_DIM)
		return
	if row.get("id", &"") == &"keys":
		UiSlate.wrapped(self, Vector2i(x, y), R.size.x - 12,
			"Every key the game answers to, read off the map itself, and each one yours to move.", UiTheme.TEXT_DIM)
		return
	if row.get("id", &"") == &"reset":
		UiSlate.wrapped(self, Vector2i(x, y), R.size.x - 12,
			"Sound, picture, keys: all of it back to how the game came.", UiTheme.TEXT_DIM)
