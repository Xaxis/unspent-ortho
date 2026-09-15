class_name UiTitleMenu
extends UiScreen
## The title's slate: it wakes over the drifting coast, UNSPENT on its glass
## and under it new game, the coast's seed (left/right draws another), the
## keys, quit. Waking is a sequence of its own: the glass dark, a line of light
## across its middle opening out, the scan running down, then the words.
## With a game saved, continue heads the list (the newest readable save) and a
## scan of that save's picture sits on the glass beside it, where and when under
## it; a save that cannot be read is said plainly in the key strip. New game over
## a readable autosave asks once more: the new game's first autosave writes over it.

const DEVICE := Rect2i(166, 158, 308, 188)
const LETTER_H := 34
## When the wake begins, the line opens, the scan runs, all is lit (seconds).
const WAKE_AT := [0.35, 0.62, 0.95]
const ROW_H := 13
## The continued save's picture on the glass, right of the list.
const PHOTO_SIZE := Vector2i(96, 54)
## Real seconds a first press of new game waits for the second.
const ASK_SECONDS := 3.0
const ASK_NEW := "Again: it writes over the autosave."

var title: UiTitle
## 0 shows the world, 1 is dark over everything.
var fade := 1.0:
	set(v):
		if not is_equal_approx(v, fade):
			fade = v
			queue_redraw()
var page := "list"
## Seconds since the slate was switched on.
var awake_for := 0.0
## The slate goes dark as a new game starts.
var sleeping := false
var _chirped := false
var _held_wake := false
var _was := {}
## The newest readable save (SaveSlots.list entry), or {}.
var saved := {}
var _photo: ImageTexture
## The autosave slot holds a game that reads.
var _autosave := false
var _ask_until := 0
var _opening := false

const KEYS := [[&"move_up", &"up"], [&"move_down", &"down"], [&"move_left", &"left"], [&"move_right", &"right"], [&"use", &"confirm"], [&"swing", &"confirm"], [&"pause", &"back"]]


func _init() -> void:
	super()
	screen_name = &"title"
	wakes = false
	device_rect = DEVICE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	var rows: Array[Dictionary] = [
		{"id": &"new", "text": "new game"},
		{"id": &"seed", "text": "coast"},
		{"id": &"controls", "text": "controls"},
		{"id": &"quit", "text": "quit"},
	]
	var entries := SaveSlots.list()
	saved = SaveSlots.newest(entries)
	_autosave = bool(entries[SaveSlots.AUTO].ok)
	_ask_until = 0
	_photo = SaveSlots.thumbnail(saved.header) if not saved.is_empty() else null
	var problems := SaveSlots.problems(entries)
	if not saved.is_empty():
		rows.insert(0, {"id": &"continue", "text": "continue"})
	elif not problems.is_empty():
		rows.insert(1, {"id": &"continue", "text": "continue", "enabled": false, "why": problems[0]})
	menu.set_rows(rows)
	if _opening and not saved.is_empty():
		menu.index = 0
	_opening = false
	if not problems.is_empty():
		say(problems[0])
	queue_redraw()


func _on_open() -> void:
	_opening = true


## Where the continued save's picture sits on the glass; empty without one.
func photo_rect() -> Rect2i:
	if saved.is_empty():
		return Rect2i()
	var g := UiSlate.glass_of(DEVICE)
	return Rect2i(g.end.x - UiSlate.MARGIN_R - 6 - PHOTO_SIZE.x, _list_top(), PHOTO_SIZE.x, PHOTO_SIZE.y)


func _list_top() -> int:
	return UiSlate.glass_of(DEVICE).position.y + UiSlate.STATUS_H + 12 + LETTER_H + 12


func open(switched: bool = false) -> void:
	awake_for = 0.0
	_chirped = false
	# A key still held from the game that gave way (E on "to the title") is not
	# a press on the title, or it would continue straight back into a game.
	for pair: Array in KEYS:
		_was[pair[0]] = Input.is_action_pressed(pair[0])
	super(switched)


## How far the title's wake has come: [line 0..1, scan 0..1] (1, 1 when lit).
func wake_stage() -> Array[float]:
	var line := clampf((awake_for - WAKE_AT[0]) / (WAKE_AT[1] - WAKE_AT[0]), 0.0, 1.0)
	var scan := clampf((awake_for - WAKE_AT[1]) / (WAKE_AT[2] - WAKE_AT[1]), 0.0, 1.0)
	return [line, scan]


func is_lit() -> bool:
	return awake_for >= WAKE_AT[2] and not sleeping


## Jump the wake to lit (shots).
func settle() -> void:
	awake_for = WAKE_AT[2]
	_chirped = true
	super()


## Hold the wake at `secs` in (shots of the wake): time no longer moves it.
func hold_wake(secs: float) -> void:
	awake_for = secs
	_chirped = true
	_held_wake = true
	queue_redraw()
	_fx.queue_redraw()


func sleep() -> void:
	sleeping = true
	Events.sfx.emit(&"ui_slate_sleep", Vector3.ZERO)
	queue_redraw()


func handle(action: StringName) -> bool:
	if page == "keys":
		if action == &"back" or action == &"confirm":
			page = "list"
			Events.sfx.emit(&"ui_slate_back", Vector3.ZERO)
			queue_redraw()
		return true
	if action == &"back":
		return true
	return super(action)


func _on_side(dir: int) -> void:
	if menu.selected().get("id") == &"seed" and title != null:
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		title.change_seed(dir)


func _on_confirm(row: Dictionary) -> void:
	match row.id:
		&"continue":
			if title != null:
				title.continue_game(int(saved.get("slot", -1)))
		&"new":
			var now := Time.get_ticks_msec()
			if _autosave and (_ask_until == 0 or now > _ask_until):
				_ask_until = now + int(ASK_SECONDS * 1000.0)
				Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
				say(ASK_NEW)
				return
			_ask_until = 0
			if title != null:
				title.new_game()
		&"seed":
			_on_side(1)
		&"controls":
			Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
			page = "keys"
			queue_redraw()
		&"quit":
			get_tree().quit()


func _on_choice_changed() -> void:
	_ask_until = 0


func _process(delta: float) -> void:
	super(delta)
	if not is_open:
		return
	if not sleeping:
		_read_keys()
	var before := awake_for
	if not _held_wake:
		awake_for += delta
	if not _chirped and awake_for >= WAKE_AT[0]:
		_chirped = true
		Events.sfx.emit(&"ui_slate_wake", Vector3.ZERO)
	if before < WAKE_AT[2] + 0.1:
		queue_redraw()
		_fx.queue_redraw()


## Keys are read from the action state, as the ui system reads them, so a
## tour's Input.action_press drives the title the way a key does. A press is
## the first frame an action is seen down. Every key that went down this frame
## is answered, in order: two presses inside one frame (a fast hand, a slow
## frame while the coast streams in) must not lose one, or down-then-up would
## leave the choice a row from where the player left it.
func _read_keys() -> void:
	for pair: Array in KEYS:
		var now := Input.is_action_pressed(pair[0])
		var went_down: bool = (now and not _was.get(pair[0], false)) or Input.is_action_just_pressed(pair[0])
		_was[pair[0]] = now
		if went_down:
			handle(pair[1])


func _draw() -> void:
	# Dark bands top and bottom keep the slate calm over bright ground.
	for i in 6:
		UiDraw.rect(self, Rect2i(0, i * 6, 640, 6), Color(UiTheme.GLASS_OFF, 0.3 - i * 0.05))
		UiDraw.rect(self, Rect2i(0, 354 - i * 6, 640, 6), Color(UiTheme.GLASS_OFF, 0.3 - i * 0.05))
	if fade > 0.0:
		UiDraw.rect(self, Rect2i(0, 0, 640, 360), Color(UiTheme.GLASS_OFF, fade))
	draw_device()
	var g := UiSlate.glass_of(DEVICE)
	if not is_lit() and wake_stage()[1] <= 0.0:
		return
	UiSlate.status(self, &"", "coast %d" % (title.seed_value if title != null else 0), 1.0, DEVICE, false)
	if page == "keys":
		UiPauseScreen.draw_keys_list(self, Vector2i(g.position.x + UiSlate.MARGIN_L + 4, g.position.y + UiSlate.STATUS_H + 8), 52)
		draw_keys([["esc", "back"]])
		return
	var word := "UNSPENT"
	var w := UiLettering.width(word, LETTER_H)
	var at := Vector2i(g.position.x + (g.size.x - w) / 2, g.position.y + UiSlate.STATUS_H + 12)
	# A ghost of the word burnt into the glass a row below, the word in phosphor
	# with every other row a step dimmer, the scan structure of the module.
	UiLettering.draw(self, word, at + Vector2i(0, 2), LETTER_H, UiTheme.GHOST, 7)
	UiLettering.draw(self, word, at, LETTER_H, UiTheme.TEXT, 7)
	for y in range(at.y + 1, at.y + LETTER_H, 2):
		UiDraw.hline(self, at.x, at.x + w, y, Color(UiTheme.GLASS, 0.35))
	# With a save to continue its picture takes the right of the glass and the list moves left.
	var photo := photo_rect()
	var x0 := g.position.x + (30 if photo.has_area() else 58)
	var x1 := photo.position.x - 12 if photo.has_area() else g.end.x - 58
	var top0 := _list_top()
	for i in menu.rows.size():
		var row := menu.rows[i]
		var top := top0 + i * ROW_H
		var chosen := i == menu.index
		if chosen:
			UiSlate.row_bar(self, x0 - 8, x1, top)
		var text: String = row.text
		if row.id == &"seed" and title != null:
			text = "coast %d" % title.seed_value
			if chosen:
				UiDraw.text(self, Vector2i(x1 - 18, top), "<", UiTheme.TEXT_DIM)
				UiDraw.text(self, Vector2i(x1 - 8, top), ">", UiTheme.TEXT_DIM)
		var ink := (UiTheme.BRIGHT if chosen else UiTheme.TEXT) if UiMenu.enabled(row) else UiTheme.TEXT_DIM
		UiDraw.text(self, Vector2i(x0, top), text, ink)
	if photo.has_area():
		_draw_saved(photo)
	var keys := [["e", "choose"]]
	if menu.selected().get("id") == &"seed":
		# Left and right only do something on the coast row.
		keys.append(["a d", "another coast"])
	draw_keys(keys)


## The save Continue would load: its picture in brackets, where and when under it.
func _draw_saved(photo: Rect2i) -> void:
	UiSlate.brackets(self, photo.grow(2), UiTheme.TEXT_DIM, 5)
	if _photo != null:
		draw_texture_rect(_photo, Rect2(photo), false)
	else:
		UiDraw.text_centred(self, photo.position.x + photo.size.x / 2, photo.position.y + photo.size.y / 2 - 5, "NO PICTURE", UiTheme.TEXT_DIM)
	# One line, right-aligned under it: the key strip lies just below.
	UiDraw.text_right(self, photo.end.x, photo.end.y + 4, SaveSlots.describe(saved.header), UiTheme.TEXT_DIM)


func _draw_glass() -> void:
	if not is_open:
		return
	var g := UiSlate.glass_of(DEVICE)
	if sleeping:
		UiDraw.rect(_fx, g, UiTheme.GLASS_OFF)
		return
	var st := wake_stage()
	if st[1] <= 0.0:
		# Still dark; then a line of light across the middle, opening out.
		UiDraw.rect(_fx, g, UiTheme.GLASS_OFF)
		if st[0] > 0.0:
			var half_w := roundi(g.size.x * 0.5 * minf(1.0, st[0] * 2.0))
			var half_h := roundi(maxf(0.0, st[0] * 2.0 - 1.0) * 3.0)
			var cy := g.position.y + g.size.y / 2
			UiDraw.rect(_fx, Rect2i(g.position.x + g.size.x / 2 - half_w, cy - half_h, half_w * 2, half_h * 2 + 1), Color(UiTheme.BRIGHT, 0.7))
		# The power light is still off.
		UiDraw.rect(_fx, Rect2i(DEVICE.position.x + UiSlate.BEZEL_L + 2, DEVICE.position.y + 6, 3, 2), Palette.FOUND[1])
		return
	UiSlate.marks(_fx, DEVICE)
	UiSlate.wake(_fx, st[1], DEVICE)
