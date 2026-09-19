class_name UiDevScreen
extends UiScreen
## Dev mode's app: the stolen display module's service mode, hacked open
## (docs/DEV.md). Pages stack like home and its keys page do: e steps into a
## page, esc backs out one level, ` shuts the whole app from anywhere in it.
##
## It wears the module's violet, never the player's phosphor, so nothing of it
## can be mistaken for the game: a DEV cap on the status bar, a dashed violet
## rule under it, DEV before every page's name.
##
## In a game the ui system (90_ui) owns it like any app and routes the keys; on
## the title it reads the keys itself (`standalone`), as the title's own slate does.
## A picture of the world is taken by whoever opens it, before its glass is
## drawn (`picture`), for a note.

## The first row, under DEV and the page's name: the list pane's own top plus the
## 15-pixel offset that heading used to take, at the type's factor.
const LIST_TOP := UiSlate.LIST.position.y + 30
## Rows that fit the list pane under the title. Sized off the pane and the line
## pitch rather than counted by hand, so the finer type simply fits more.
const LINES := (UiSlate.LIST.position.y + UiSlate.LIST.size.y - 8 - LIST_TOP) / UiTheme.LINE
const VIOLET := Color("#b3a8ea")
## Real seconds between two rebuilds of the rows (the clock, a job's progress).
const REFRESH_EVERY := 0.25
const ASK_SECONDS := 4.0

## The title this app is open on, or null in a game.
var title_scene: UiTitle
## Reads its own keys (the title); in a game the ui system routes them.
var standalone := false
var pages: Array[DevPage] = []
## The world as it was when the app was opened (full size), or null.
var picture: Image

## A line being typed: {id, text, max, done: Callable(text)}; empty when none.
var _edit: Dictionary = {}
var _swallow_until := -1
var _ask_key := ""
var _ask_until := 0
var _refresh_in := 0.0
var _caret := 0.0
var _was := {}
var _vertical := UiMenu.new()
var _horizontal := UiMenu.new()
## The frame the app opened on: the key that opened it is not a press on it.
var _opened_frame := -1

const KEYS := [[&"move_up", &"up"], [&"move_down", &"down"], [&"move_left", &"left"], [&"move_right", &"right"],
	[&"use", &"confirm"], [&"swing", &"confirm"], [&"pause", &"back"], [&"dev_toggle", &"dev_toggle"]]


func _init() -> void:
	super()
	screen_name = &"dev"
	own_action = &"dev_toggle"


func page() -> DevPage:
	return pages.back() if not pages.is_empty() else null


func _on_open() -> void:
	if pages.is_empty():
		push_page(DevPageHome.new(), false)
	_edit = {}
	_ask_key = ""
	if standalone:
		_opened_frame = Engine.get_process_frames()
		for pair: Array in KEYS:
			_was[pair[0]] = InputMap.has_action(pair[0]) and Input.is_action_pressed(pair[0])
		_vertical.absorb(_dir(&"move_up", &"move_down"))
		_horizontal.absorb(_dir(&"move_left", &"move_right"))


func _on_close() -> void:
	_edit = {}


## Open `p` over the page on the glass.
func push_page(p: DevPage, sound: bool = true) -> void:
	if page() != null:
		page().index = menu.index
	p.screen = self
	p.game = game
	p.title = title_scene
	pages.append(p)
	menu = UiMenu.new()
	scroll = 0
	if sound:
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	refresh()


## Open straight at a page by its home row id, and a row on it (--dev=PAGE:ROW, keys).
func open_at(page_id: StringName, row_id: StringName = &"") -> bool:
	while pages.size() > 1:
		pages.pop_back()
	if pages.is_empty():
		push_page(DevPageHome.new(), false)
	refresh()
	if page_id != &"" and page_id != &"home":
		var p := DevPageHome.page_for(page_id)
		if p == null:
			return false
		push_page(p, false)
	if row_id != &"":
		select(row_id)
	return true


func back() -> void:
	if pages.size() <= 1:
		close()
		return
	pages.pop_back()
	menu = UiMenu.new()
	refresh()
	menu.index = page().index
	keep_in_view(LINES)
	Events.sfx.emit(&"ui_slate_back", Vector3.ZERO)
	queue_redraw()


func refresh() -> void:
	if page() == null:
		return
	menu.set_rows(page().rows())
	keep_in_view(LINES)
	queue_redraw()


func handle(action: StringName) -> bool:
	if not is_open:
		return false
	if Engine.get_process_frames() <= _swallow_until:
		return true
	if not _edit.is_empty():
		# Typing: the keys are letters now (_input). Only esc, as an action, drops the line.
		if action == &"back":
			end_edit(false)
		return true
	match action:
		&"back":
			back()
			return true
		&"dev_toggle":
			close()
			return true
	var used := super(action)
	if action == &"up" or action == &"down":
		keep_in_view(LINES)
	return used


func _on_confirm(row: Dictionary) -> void:
	page().confirm(row)
	if is_open:
		refresh()


## The dev pages' own `side` still answers nothing, so this page keeps both
## arrows on every row and reaches its doors with `use` and `esc` as it always
## has. Making it honest means `DevPage.side` reporting too, across ten pages.
func _on_side(dir: int) -> bool:
	var row := menu.selected()
	if row.is_empty():
		return false
	page().side(row, dir)
	if is_open:
		refresh()
	return true


func _on_choice_changed() -> void:
	_ask_key = ""


## True on the second of two confirms of `key` inside ASK_SECONDS; the first says `line`.
func ask(key: String, line: String) -> bool:
	var now := Time.get_ticks_msec()
	if _ask_key == key and now <= _ask_until:
		_ask_key = ""
		return true
	_ask_key = key
	_ask_until = now + int(ASK_SECONDS * 1000.0)
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
	refuse(line)
	return false


# --- a line typed -----------------------------------------------------------------------

func edit_text(id: StringName, text: String, max_len: int, done: Callable) -> void:
	_edit = {"id": id, "text": text, "max": max_len, "done": done}
	_caret = 0.0
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
	queue_redraw()


func editing() -> bool:
	return not _edit.is_empty()


func end_edit(keep: bool) -> void:
	if _edit.is_empty():
		return
	var e := _edit
	_edit = {}
	# The key that ended the line is still down this frame: it is not a press on the page.
	_swallow_until = Engine.get_process_frames() + 1
	if keep:
		(e.done as Callable).call(str(e.text))
	else:
		Events.sfx.emit(&"ui_slate_back", Vector3.ZERO)
	if is_open:
		refresh()


## Type into the line being edited. Public so tests type without a keyboard.
func type_key(keycode: Key, unicode: int) -> void:
	if _edit.is_empty():
		return
	match keycode:
		KEY_ENTER, KEY_KP_ENTER:
			end_edit(true)
			return
		KEY_ESCAPE:
			end_edit(false)
			return
		KEY_BACKSPACE:
			var t := str(_edit.text)
			_edit.text = t.left(maxi(0, t.length() - 1))
		_:
			if unicode >= 32 and unicode < 127 and str(_edit.text).length() < int(_edit.max):
				_edit.text = str(_edit.text) + String.chr(unicode)
	_caret = 0.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _edit.is_empty() or not is_open:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	get_viewport().set_input_as_handled()
	type_key(k.keycode, k.unicode)


# --- frames -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	if not is_open:
		return
	if standalone:
		_read_keys(delta)
	if page() != null:
		page().step(delta)
	_refresh_in -= delta
	if _refresh_in <= 0.0 and _edit.is_empty():
		_refresh_in = REFRESH_EVERY
		refresh()
	if not _edit.is_empty():
		_caret += delta
		queue_redraw()


## The title's way: keys from the action state, a press the first frame one is down.
## A direction moves once on its press, then repeats while held (UiMenu.hold); a
## tap struck and let go inside one frame is never seen held, so the press is
## what moves, and the hold only repeats.
func _read_keys(delta: float) -> void:
	var tapped := {}
	var fresh := Engine.get_process_frames() != _opened_frame
	for pair: Array in KEYS:
		if not InputMap.has_action(pair[0]):
			continue
		var now := Input.is_action_pressed(pair[0])
		var went_down: bool = (now and not _was.get(pair[0], false)) or Input.is_action_just_pressed(pair[0])
		_was[pair[0]] = now
		# Held state is kept while typing too, or the enter that ends a line would
		# read as a fresh press the frame after.
		if not went_down or not _edit.is_empty() or not fresh:
			continue
		if pair[1] in [&"up", &"down", &"left", &"right"]:
			tapped[pair[1]] = true
			continue
		handle(pair[1])
		if not is_open:
			return
	if not _edit.is_empty() or not fresh:
		_vertical.absorb(_dir(&"move_up", &"move_down"))
		_horizontal.absorb(_dir(&"move_left", &"move_right"))
		return
	_step_axis(_vertical, tapped, &"up", &"down", _dir(&"move_up", &"move_down"), delta)
	_step_axis(_horizontal, tapped, &"left", &"right", _dir(&"move_left", &"move_right"), delta)


func _step_axis(m: UiMenu, tapped: Dictionary, neg: StringName, pos: StringName, held: int, delta: float) -> void:
	var dir := (1 if tapped.has(pos) else 0) - (1 if tapped.has(neg) else 0)
	if dir != 0:
		handle(pos if dir > 0 else neg)
		# The press moved it: the hold takes over from here, for repeats only.
		m.hold(dir, 0.0)
		if held == 0:
			m.hold(0, 0.0)
		return
	for i in m.hold(held, delta):
		handle(pos if held > 0 else neg)


func _dir(neg: StringName, pos: StringName) -> int:
	return int(Input.is_action_pressed(pos)) - int(Input.is_action_pressed(neg))


# --- drawing -----------------------------------------------------------------------------

func _draw() -> void:
	draw_frame(&"")
	_draw_service_marks()
	var L := UiSlate.LIST
	var R := UiSlate.SPARE
	var at := Vector2i(L.position.x + UiSlate.MARGIN_L, L.position.y + 8)
	UiDraw.text(self, at, "DEV", VIOLET)
	var x := at.x + UiFont.width("DEV") + 8
	UiDraw.px(self, x, at.y + 8, UiTheme.MACHINE[2])
	x += 8
	var name := page().heading() if page() != null else ""
	UiDraw.text(self, Vector2i(x, at.y), name, UiTheme.TEXT)
	UiDraw.hline(self, x + UiFont.width(name) + 10, L.end.x - UiSlate.MARGIN_R, at.y + UiFont.SIZE / 2, UiTheme.GHOST)
	UiSlate.spare(self)
	_draw_rows(L)
	if page() != null:
		page().detail(self, R)
	var row := menu.selected()
	if not _edit.is_empty():
		draw_keys([["enter", "keep"], ["esc", "drop"]])
	elif page() != null:
		draw_keys(page().keys(row))


## The service mode's own marks: a DEV cap before the clock and a dashed violet
## rule under the status bar.
func _draw_service_marks() -> void:
	var g := UiSlate.glass_of(device_rect)
	var y := g.position.y + 2
	# Where the status bar's clock ends (UiSlate.status: its `right`, less the gap
	# it leaves the clock), so the cap stands left of the clock and never over it.
	var right := g.end.x - UiSlate.MARGIN_R - 28 - 38
	var clock := clock_text()
	var cap_x := right - (UiFont.width(clock) + 20 if clock != "" else 0) - 44
	UiDraw.rect(self, Rect2i(cap_x, y, 38, 18), UiTheme.RIM)
	UiDraw.frame(self, Rect2i(cap_x, y - 2, 38, 22), UiTheme.MACHINE[1])
	UiDraw.text(self, Vector2i(cap_x + 4, y - 2), "DEV", UiTheme.MACHINE[4])
	var ry := g.position.y + UiSlate.STATUS_H + 2
	var x0 := g.position.x + UiSlate.MARGIN_L - 2 * UiSlate.UNIT
	var x1 := g.end.x - UiSlate.MARGIN_R
	for xx in range(x0, x1, 8):
		UiDraw.hline(self, xx, mini(xx + 3, x1), ry, UiTheme.MACHINE[2])


func _draw_rows(L: Rect2i) -> void:
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 16
	var end := mini(menu.rows.size(), scroll + LINES)
	for i in range(scroll, end):
		var row := menu.rows[i]
		var top := UiSlate.line_top(LIST_TOP, i - scroll)
		if row.has("header"):
			UiSlate.heading(self, Vector2i(x0 + 4, top), str(row.header), right)
			continue
		var chosen := i == menu.index
		if chosen:
			UiSlate.row_bar(self, x0 - 8, right + 6, top, VIOLET if str(row.get("tone", "")) == "dev" else UiTheme.TEXT)
		var usable := UiMenu.enabled(row)
		var ink := (UiTheme.BRIGHT if chosen else UiTheme.TEXT) if usable else UiTheme.TEXT_DIM
		match str(row.get("tone", "")):
			"warn":
				ink = UiTheme.WARN if usable else UiTheme.WARN_DIM
			"dev":
				ink = UiTheme.MACHINE[4] if chosen else VIOLET
		var editing_here: bool = not _edit.is_empty() and _edit.id == row.get("id")
		var value := str(row.get("value", ""))
		if editing_here:
			value = str(_edit.text) + ("_" if fmod(_caret, 1.0) < 0.55 else " ")
		var steps: bool = bool(row.get("steps", false)) and chosen and usable and not editing_here
		var vx := right - (44 if steps else 0)
		var value_w := UiFont.width(value)
		var text_w := maxi(48, vx - value_w - 16 - (x0 + 16))
		UiDraw.text(self, Vector2i(x0 + 16, top), DevPage._fit(str(row.text), text_w), ink)
		if value != "":
			var vcol := UiTheme.TEXT_DIM
			if editing_here:
				vcol = UiTheme.BRIGHT
			elif bool(row.get("edited", false)):
				vcol = VIOLET
			elif chosen:
				vcol = UiTheme.TEXT
			UiDraw.text_right(self, vx, top, value, vcol)
			if bool(row.get("edited", false)):
				UiDraw.rect(self, Rect2i(vx - value_w - 10, top + 6, 4, 4), VIOLET)
		if steps:
			UiDraw.text(self, Vector2i(right - 28, top), "<", UiTheme.TEXT)
			UiDraw.text(self, Vector2i(right - 10, top), ">", UiTheme.TEXT)
	# More above or below: a dim point at the pane's edge.
	if scroll > 0:
		UiDraw.text(self, Vector2i(right - 8, LIST_TOP - UiTheme.LINE), "↑", UiTheme.TEXT_DIM)
	if end < menu.rows.size():
		UiDraw.text(self, Vector2i(right - 8, UiSlate.line_top(LIST_TOP, LINES) - 4), "↓", UiTheme.TEXT_DIM)
