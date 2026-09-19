class_name UiTitleMenu
extends UiScreen
## The title's slate: it wakes over the drifting coast, UNSPENT on its glass
## and under it new game, which island to play (left/right draws another), the
## keys, quit. Waking is a sequence of its own: the glass dark, a line of light
## across its middle opening out, the scan running down, then the words.
## With a game saved, continue heads the list (the newest readable save) and a
## scan of that save's picture sits on the glass beside it, where and when under
## it; a save that cannot be read is said plainly in the key strip. New game over
## a readable autosave asks once more: the new game's first autosave writes over it.
## The strip has room for one short line only, so the WHOLE reason a save will not
## open (SaveFile.WHY_*, or the ground that moved under it) is drawn over the list
## when the player asks for it — confirming the faded continue row — and at once
## when a game has just handed back here because this build would not open it.

## The title's device is a smaller one than the page slate, and it came across
## the same way (`UiSlate.UNIT`): the same object, cut at the base's resolution,
## covering the share of the frame it always did. The type on it did not.
const DEVICE := Rect2i(166 * UiSlate.UNIT, 158 * UiSlate.UNIT, 308 * UiSlate.UNIT, 188 * UiSlate.UNIT)
## The game's name is display lettering, not type: it belongs to the device.
const LETTER_H := 34 * UiSlate.UNIT
## When the wake begins, the line opens, the scan runs, all is lit (seconds).
const WAKE_AT := [0.35, 0.62, 0.95]
const ROW_H := UiTheme.LINE + 4
## The reason page's margin each side of the glass, and the lines there is room
## for between the list's top and the key strip.
const REASON_INSET := 60
const REASON_LINES := 6
## The continued save's picture on the glass, right of the list.
const PHOTO_SIZE := Vector2i(96 * UiSlate.UNIT, 54 * UiSlate.UNIT)
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
## The whole reason a save will not open, drawn over the list on the "why" page.
var why_text := ""
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

## The key strip under the list, and the one under a page. The note is said at
## the other end of the same strip, so what is left over is all the room a
## sentence has (tests/save/test_problem_fits.gd reads these, never a copy).
const KEY_HINTS := [["e", "choose"]]
const KEY_HINTS_ISLAND := [["a d", "another island"]]
const KEY_HINTS_PAGE := [["esc", "back"]]


func _init() -> void:
	super()
	screen_name = &"title"
	wakes = false
	device_rect = DEVICE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	var rows: Array[Dictionary] = [
		{"id": &"new", "text": "new game"},
		{"id": &"seed", "text": "island"},
		{"id": &"settings", "text": "settings"},
		{"id": &"quit", "text": "quit"},
	]
	var entries := SaveSlots.list()
	saved = SaveSlots.newest(entries)
	# Asked about before a new game writes over it: one this build cannot open
	# (made on another island) is still a game the player has not lost, and a new
	# game's first autosave would be the end of it.
	var auto: Dictionary = entries[SaveSlots.AUTO]
	_autosave = bool(auto.ok) or (bool(auto.exists) and auto.code == &"elsewhere")
	_ask_until = 0
	_photo = SaveSlots.thumbnail(saved.header) if not saved.is_empty() else null
	# A game just handed back here says its own slot's reason first, whichever
	# other slot is also in trouble.
	var handed := SaveSlots.take_handed_back()
	var trouble := SaveSlots.first_problem(entries, handed)
	if not saved.is_empty():
		rows.insert(0, {"id": &"continue", "text": "continue"})
	elif not trouble.is_empty():
		rows.insert(1, {"id": &"continue", "text": "continue", "enabled": false,
			"why": str(trouble.line), "full": str(trouble.why)})
	if UiTitle.island_fixed():
		# The configuration fixed the island: there is no other to choose.
		rows = rows.filter(func(r: Dictionary) -> bool: return r.id != &"seed")
	menu.set_rows(rows)
	if _opening and not saved.is_empty():
		menu.index = 0
	_opening = false
	if not trouble.is_empty():
		say(str(trouble.line))
		# Amber, as the saves app says the same thing: one sentence, one weight,
		# whichever screen the player meets it on.
		note_warn = true
		if handed >= 0:
			# They pressed continue and were sent straight back: the strip's one
			# line is not enough, so the whole reason is on the glass already.
			show_reason(str(trouble.why))
	queue_redraw()


## A save that will not open, said both ways: the slot's one line in the strip,
## which is all the room there is there, and the whole reason on the page.
func refuse_save(slot: int, why: String) -> void:
	var code: StringName = &"damaged"
	if slot >= 0 and slot < SaveSlots.COUNT:
		code = SaveSlots.list()[slot].code
	refuse(SaveSlots.problem(slot, code))
	show_reason(why)


## Draw the whole reason over the list until the player backs out of it.
func show_reason(text: String) -> void:
	if text == "":
		return
	why_text = text
	page = "why"
	queue_redraw()


func _on_open() -> void:
	_opening = true


## Where the continued save's picture sits on the glass; empty without one.
func photo_rect() -> Rect2i:
	if saved.is_empty():
		return Rect2i()
	var g := UiSlate.glass_of(DEVICE)
	return Rect2i(g.end.x - UiSlate.MARGIN_R - 18 - PHOTO_SIZE.x, list_top(), PHOTO_SIZE.x, PHOTO_SIZE.y)


## Where the list (and the reason page in its place) begins on the glass. Static,
## so what fits there can be worked out without a title on screen.
static func list_top() -> int:
	return UiSlate.glass_of(DEVICE).position.y + UiSlate.STATUS_H + 24 + LETTER_H + 24


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
	if page == "keys" or page == "why":
		if action == &"back" or action == &"confirm":
			page = "list"
			Events.sfx.emit(&"ui_slate_back", Vector3.ZERO)
			queue_redraw()
		return true
	if action == &"back":
		return true
	if action == &"confirm":
		var row := menu.selected()
		# UiScreen refuses a faded row with its one short line. Here the whole
		# reason has somewhere to go, so the player can read it and not be left
		# with a row they cannot press and no account of why.
		if not row.is_empty() and not UiMenu.enabled(row) and str(row.get("full", "")) != "":
			refuse(str(row.get("why", "")))
			show_reason(str(row.full))
			return true
	return super(action)


func _on_side(dir: int) -> bool:
	if menu.selected().get("id") == &"seed" and title != null:
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		title.change_seed(dir)
		return true
	return false


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
		&"settings":
			Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
			if title != null:
				title.open_settings()
		&"quit":
			get_tree().quit()


func _on_choice_changed() -> void:
	_ask_until = 0
	# The note is said at the far end of the key strip, and the island row is the
	# one row that draws a second hint into that strip: a sentence still standing
	# there would be drawn straight through it. So that row, and only that row,
	# takes the note with it (tests/save/test_problem_fits.gd).
	if menu.selected().get("id") == &"seed":
		note = ""


func _process(delta: float) -> void:
	super(delta)
	if not is_open:
		return
	if not sleeping and title != null and ((title.dev != null and title.dev.is_open()) or (title.character != null and title.character.is_open)):
		# Dev mode's app, or the character page, has the keys; what is held is still
		# noted, or the key that shuts it would read as a fresh press on this list.
		for pair: Array in KEYS:
			_was[pair[0]] = Input.is_action_pressed(pair[0])
	elif not sleeping:
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
		UiDraw.rect(self, Rect2i(0, i * 18, UiBase.SIZE.x, 18), Color(UiTheme.GLASS_OFF, 0.3 - i * 0.05))
		UiDraw.rect(self, Rect2i(0, UiBase.SIZE.y - 18 - i * 18, UiBase.SIZE.x, 18), Color(UiTheme.GLASS_OFF, 0.3 - i * 0.05))
	if fade > 0.0:
		UiDraw.rect(self, UiBase.screen(), Color(UiTheme.GLASS_OFF, fade))
	draw_device()
	var g := UiSlate.glass_of(DEVICE)
	if not is_lit() and wake_stage()[1] <= 0.0:
		return
	UiSlate.status(self, &"", "island %d" % (title.seed_value if title != null else 0), 1.0, DEVICE, false)
	if page == "keys":
		UiPauseScreen.draw_keys_list(self, Vector2i(g.position.x + UiSlate.MARGIN_L + 8, g.position.y + UiSlate.STATUS_H + 16), 104)
		draw_keys(KEY_HINTS_PAGE)
		return
	var word := "UNSPENT"
	var w := UiLettering.width(word, LETTER_H)
	var at := Vector2i(g.position.x + (g.size.x - w) / 2, g.position.y + UiSlate.STATUS_H + 24)
	# A ghost of the word burnt into the glass a row below, the word in phosphor
	# with every other row a step dimmer, the scan structure of the module. The
	# rows are the MODULE's pixels, not the base's: a one-pixel stripe at this
	# resolution is a moire pattern, not a scan line.
	UiLettering.draw(self, word, at + Vector2i(0, 6), LETTER_H, UiTheme.GHOST, 7)
	UiLettering.draw(self, word, at, LETTER_H, UiTheme.TEXT, 7)
	for y in range(at.y + UiBase.PITCH, at.y + LETTER_H, UiBase.PITCH * 2):
		UiDraw.rect(self, Rect2i(at.x, y, w, UiBase.PITCH), Color(UiTheme.GLASS, 0.35))
	if page == "why":
		_draw_reason(g)
		draw_keys(KEY_HINTS_PAGE)
		return
	# With a save to continue its picture takes the right of the glass and the list moves left.
	var photo := photo_rect()
	var x0 := g.position.x + (60 if photo.has_area() else 116)
	var x1 := photo.position.x - 24 if photo.has_area() else g.end.x - 116
	var top0 := list_top()
	for i in menu.rows.size():
		var row := menu.rows[i]
		var top := top0 + i * ROW_H
		var chosen := i == menu.index
		if chosen:
			UiSlate.row_bar(self, x0 - 16, x1, top)
		var text: String = row.text
		if row.id == &"seed" and title != null:
			# Which island a new game is played on. The arrows are drawn whether or
			# not this row is the one chosen: hidden until then, the row read as a
			# menu entry nobody could explain rather than as something to turn.
			text = "island %d" % title.seed_value
			var arrows := UiTheme.TEXT if chosen else UiTheme.TEXT_DIM
			UiDraw.text(self, Vector2i(x1 - 36, top), "<", arrows)
			UiDraw.text(self, Vector2i(x1 - 16, top), ">", arrows)
		var ink := (UiTheme.BRIGHT if chosen else UiTheme.TEXT) if UiMenu.enabled(row) else UiTheme.TEXT_DIM
		UiDraw.text(self, Vector2i(x0, top), text, ink)
	if photo.has_area():
		_draw_saved(photo)
	var keys := KEY_HINTS.duplicate()
	if menu.selected().get("id") == &"seed":
		# Left and right only do something on the island row.
		keys.append_array(KEY_HINTS_ISLAND)
	draw_keys(keys)


## The whole reason, wrapped where the list stands. The saves app says it in the
## same amber; this is the only other place it is said in full.
func _draw_reason(g: Rect2i) -> void:
	var at := Vector2i(g.position.x + REASON_INSET, list_top())
	UiSlate.wrapped(self, at, g.size.x - REASON_INSET * 2, why_text, UiTheme.WARN)


## The save Continue would load: its picture in brackets, where and when under it.
func _draw_saved(photo: Rect2i) -> void:
	UiSlate.brackets(self, photo.grow(6), UiTheme.TEXT_DIM, 15)
	if _photo != null:
		draw_texture_rect(_photo, Rect2(photo), false)
	else:
		UiDraw.text_centred(self, photo.position.x + photo.size.x / 2, photo.position.y + photo.size.y / 2 - UiFont.SIZE / 2, "NO PICTURE", UiTheme.TEXT_DIM)
	# One line, right-aligned under it: the key strip lies just below.
	UiDraw.text_right(self, photo.end.x, photo.end.y + 8, SaveSlots.describe(saved.header), UiTheme.TEXT_DIM)


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
			var half_h := roundi(maxf(0.0, st[0] * 2.0 - 1.0) * 3.0) * UiSlate.UNIT
			var cy := g.position.y + g.size.y / 2
			UiDraw.rect(_fx, Rect2i(g.position.x + g.size.x / 2 - half_w, cy - half_h, half_w * 2, half_h * 2 + UiSlate.UNIT), Color(UiTheme.BRIGHT, 0.7))
		# The power light is still off. It is a part of the device, and sits exactly
		# where the bake puts the green one.
		UiDraw.rect(_fx, Rect2i(DEVICE.position.x + UiSlate.BEZEL_L + 2 * UiSlate.UNIT, DEVICE.position.y + 6 * UiSlate.UNIT, 3 * UiSlate.UNIT, 2 * UiSlate.UNIT), Palette.FOUND[1])
		return
	UiSlate.marks(_fx, DEVICE)
	UiSlate.wake(_fx, st[1], DEVICE)
