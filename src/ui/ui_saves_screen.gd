class_name UiSavesScreen
extends UiScreen
## The saves app (from home). Left: SAVE and LOAD, switched with left and right,
## and the slots under them, each with where and when it stands (load also lists
## the autosave). Right, on the replacement sub-panel: the chosen slot's picture
## of the world as it was, and how long ago and how much play it holds.
## E saves into the chosen slot (a slot that holds a game asks once more before
## it is written over) or loads it; a slot that is empty or cannot be read is
## dim and says so plainly, and one made on another island (SaveFile's
## &"elsewhere") still shows the game it holds with the reason under it, because
## the player has not lost it — this build just cannot grow that world again.
## The work is the save system's (05_save):
##   save_to(slot) -> String, load_from(slot) -> String ("" = done, else why)

## Real seconds a first press on a filled slot waits for the second that writes.
const ASK_SECONDS := 3.0
## How big the save's picture is DRAWN.
##
## **It is held down by its source, not chosen.** The picture is captured at
## `05_save.THUMB` — 160x90 — so anything drawn here is an upscale of that, and
## an upscale is exactly the softness this wave exists to remove. Drawn at three
## times it was a blur on the first screen of the game; at two it reads as a
## small photograph, which is what it is.
##
## Capturing it at the size it is drawn is the real fix and it is the owner's
## call, because it is a save-file change: measured on a real frame, the PNG in a
## save's header goes from 40 KB at 160x90 to 147 KB at 320x180 and 318 KB at
## 480x270, against about 6 KB for everything else a save holds. A JPEG thumb
## would take a 480-wide picture back under 40 KB, but the header's `thumb` is a
## PNG by contract (`SaveFile`, `SaveSlots.thumbnail`) and changing that is a
## migration, not a constant.
const THUMB := Vector2i(320, 180)
## Under the title, relative to the list pane; the rows start below them.
const TABS_TOP := 36
const LIST_TOP := UiSlate.LIST.position.y + 80
## A row is two lines, the slot and what it holds, with a clear line round them.
const ROW_PITCH := UiTheme.LINE * 2 + 8
const MODES: Array[StringName] = [&"save", &"load"]

## &"save" or &"load"; left and right switch it, and it is kept between openings.
var mode: StringName = &"save"
## What saves and loads: the running game's 05_save, or a stand-in (tests).
var saver: Object
var _entries: Array[Dictionary] = []
var _thumbs: Dictionary = {} # slot -> ImageTexture or null
var _ask_slot := -1
var _ask_until := 0
## Loading has begun: the app takes no more keys while the game gives way.
var _loading := false


func _init() -> void:
	super()
	screen_name = &"saves"
	own_action = &""


func _on_open() -> void:
	scroll = 0
	_ask_slot = -1
	_loading = false
	if saver == null and game != null:
		for sys in game.systems:
			if sys.name == "05_save":
				saver = sys


func refresh() -> void:
	_entries = SaveSlots.list()
	_thumbs.clear()
	var rows: Array[Dictionary] = []
	for e in _entries:
		var slot := int(e.slot)
		if mode == &"save" and slot == SaveSlots.AUTO:
			continue
		var row := {"id": StringName("slot_%d" % slot), "slot": slot, "entry": e}
		if mode == &"load" and not e.ok:
			row["enabled"] = false
			row["why"] = SaveSlots.problem(slot, e.code)
		rows.append(row)
		# A save this build will not open still has a whole header (one made on
		# another island does): show the game it holds and say why beside it,
		# rather than blanking a game the player has not lost.
		if not (e.header as Dictionary).is_empty():
			_thumbs[slot] = SaveSlots.thumbnail(e.header)
	var was := menu.index
	menu.set_rows(rows)
	if was >= 0 and was < rows.size() and UiMenu.selectable(rows[was]):
		menu.index = was
	queue_redraw()


func _on_side(dir: int) -> void:
	var next := MODES[posmod(MODES.find(mode) + dir, MODES.size())]
	if next == mode or _loading:
		return
	mode = next
	_ask_slot = -1
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
	refresh()


func _on_confirm(row: Dictionary) -> void:
	var slot := int(row.slot)
	if saver == null:
		refuse("No save module is wired into the slate here.")
		return
	if mode == &"load":
		var why: String = saver.call("load_from", slot)
		if why != "":
			refuse(why)
			return
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
		_loading = true
		say("Loading %s..." % SaveSlots.slot_name(slot))
		return
	var entry: Dictionary = row.entry
	var now := Time.get_ticks_msec()
	if entry.exists and (_ask_slot != slot or now > _ask_until):
		_ask_slot = slot
		_ask_until = now + int(ASK_SECONDS * 1000.0)
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		say("Again, to write over %s." % SaveSlots.slot_name(slot))
		return
	_ask_slot = -1
	var why: String = saver.call("save_to", slot)
	if why != "":
		refuse(why)
		return
	Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	refresh()
	say("Saved to %s." % SaveSlots.slot_name(slot))


func handle(action: StringName) -> bool:
	if is_open and _loading:
		return true
	return super(action)


func _on_choice_changed() -> void:
	_ask_slot = -1


func _draw() -> void:
	draw_frame()
	var L := UiSlate.LIST
	var R := UiSlate.SPARE
	UiSlate.title(self, L, "SAVES")
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 16
	# SAVE | LOAD: the mode lit, the other dim.
	var tx := x0 + 8
	for m: StringName in MODES:
		var word := String(m).to_upper()
		var lit := m == mode
		if lit:
			UiDraw.hline(self, tx - 2, tx + UiFont.width(word), L.position.y + TABS_TOP + UiFont.SIZE, UiTheme.TEXT)
		UiDraw.text(self, Vector2i(tx, L.position.y + TABS_TOP), word, UiTheme.BRIGHT if lit else UiTheme.TEXT_DIM)
		tx += UiFont.width(word) + 28
	for i in menu.rows.size():
		var row := menu.rows[i]
		var e: Dictionary = row.entry
		var top := LIST_TOP + i * ROW_PITCH
		var chosen := i == menu.index
		if chosen:
			UiDraw.rect(self, Rect2i(x0 - 8, top - 4, right - x0 + 14, ROW_PITCH - 8), UiTheme.GLASS_LIT)
			UiDraw.rect(self, Rect2i(x0 - 8, top - 2, 4, ROW_PITCH - 12), UiTheme.TEXT)
		var usable := UiMenu.enabled(row)
		UiDraw.text(self, Vector2i(x0 + 8, top), SaveSlots.slot_name(int(row.slot)), (UiTheme.BRIGHT if chosen else UiTheme.TEXT) if usable else UiTheme.TEXT_DIM)
		if e.ok:
			UiDraw.text_right(self, right, top, played(e.header), UiTheme.TEXT_DIM)
			UiDraw.text(self, Vector2i(x0 + 20, top + UiTheme.LINE), SaveSlots.describe(e.header), UiTheme.TEXT_DIM)
		elif e.exists:
			UiDraw.text(self, Vector2i(x0 + 20, top + UiTheme.LINE), SaveSlots.short_problem(e.code), UiTheme.WARN)
		else:
			UiDraw.text(self, Vector2i(x0 + 20, top + UiTheme.LINE), "empty", UiTheme.TEXT_DIM)
	_draw_detail(R)
	var keys := [["e", String(mode)], ["a d", "save or load"], ["esc", "back"]]
	draw_keys(keys)


func _draw_detail(R: Rect2i) -> void:
	var row := menu.selected()
	if row.is_empty():
		return
	var slot := int(row.slot)
	var e: Dictionary = row.entry
	var px := R.position.x + UiSlate.MARGIN_L
	var pic := Rect2i(px + 8, R.position.y + 24, THUMB.x, THUMB.y)
	UiSlate.brackets(self, pic.grow(9), UiTheme.TEXT_DIM, 18)
	var tex: ImageTexture = _thumbs.get(slot)
	if tex != null:
		draw_texture_rect(tex, Rect2(pic), false)
	else:
		# No picture: the glass's own snow, fixed, dim. A grain is a pixel of the
		# module, laid on every other one of them.
		var step := UiBase.PITCH * 2
		for y in range(pic.position.y, pic.end.y, step):
			for x in range(pic.position.x, pic.end.x, step):
				if Rng.hash01(x, y, 0, 0x5a0) < 0.14:
					UiDraw.px(self, x, y, UiTheme.GHOST if Rng.hash01(x, y, 1, 0x5a0) < 0.7 else UiTheme.FAINT)
		var word := SaveSlots.short_problem(e.code).to_upper() if e.exists else "EMPTY"
		UiDraw.text_centred(self, pic.position.x + pic.size.x / 2, pic.position.y + pic.size.y / 2 - UiFont.SIZE / 2, word, UiTheme.TEXT_DIM)
	var ty := pic.end.y + 24
	var h: Dictionary = e.header
	# A save made on another island keeps its whole header: the game it holds is
	# shown, dimmed, and the reason it will not open is said under it.
	if not h.is_empty():
		UiDraw.text(self, Vector2i(px + 8, ty), str(h.get("clock", "")), UiTheme.BRIGHT if e.ok else UiTheme.TEXT)
		UiDraw.text(self, Vector2i(px + 8, ty + UiTheme.LINE), str(h.get("place", "")), UiTheme.TEXT if e.ok else UiTheme.TEXT_DIM)
		UiDraw.text(self, Vector2i(px + 8, ty + UiTheme.LINE * 2), played(h), UiTheme.TEXT_DIM)
		UiDraw.text(self, Vector2i(px + 8, ty + UiTheme.LINE * 3), ago(SaveCodec.to_num(h.get("saved_at")), Time.get_unix_time_from_system()), UiTheme.TEXT_DIM)
		ty += UiTheme.LINE * 4 + 16
	if e.exists and not e.ok:
		# The whole reason, in the one place with room to say it.
		UiSlate.wrapped(self, Vector2i(px + 8, ty), R.end.x - 24 - px, str(e.why), UiTheme.WARN)
	elif not e.exists and mode == &"save":
		UiDraw.text(self, Vector2i(px + 8, ty), "e writes the game here", UiTheme.TEXT_DIM)


## "played 1 h 06 m": said as play, so a slot's row never reads as how long ago
## it was saved (the detail says that, under the picture).
static func played(header: Dictionary) -> String:
	return "played %s" % SaveSlots.play_time(header)


## "saved just now", "saved 5 minutes ago", "saved 2 days ago".
static func ago(then: float, now: float) -> String:
	var s := maxf(0.0, now - then)
	if s < 60.0:
		return "saved just now"
	var units: Array = [[86400.0, "day"], [3600.0, "hour"], [60.0, "minute"]]
	for u: Array in units:
		if s >= float(u[0]):
			var n := floori(s / float(u[0]))
			return "saved %d %s%s ago" % [n, u[1], "" if n == 1 else "s"]
	return "saved just now"
