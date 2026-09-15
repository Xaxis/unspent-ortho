class_name UiSavesScreen
extends UiScreen
## Save and load, one level down the pause page. Left: the slots, each with where
## and when it stands (load also lists the autosave). Right: the chosen slot's
## picture of the world as it was, and how long ago and how much play it holds.
## E saves into the chosen slot (a slot that holds a game asks once more before
## it is written over) or loads it; a slot that is empty or cannot be read is
## faded and says so plainly. The work is the save system's (05_save):
##   save_to(slot) -> String, load_from(slot) -> String ("" = done, else why)

## Real seconds a first press on a filled slot waits for the second that writes.
const ASK_SECONDS := 3.0
const THUMB := Vector2i(160, 90)

## &"save" or &"load"; set before opening.
var mode: StringName = &"save"
## What saves and loads: the running game's 05_save, or a stand-in (tests).
var saver: Object
var _entries: Array[Dictionary] = []
var _thumbs: Dictionary = {} # slot -> ImageTexture or null
var _ask_slot := -1
var _ask_until := 0
## Loading has begun: the page takes no more keys while the game gives way.
var _loading := false


func _init() -> void:
	super()
	screen_name = &"saves"


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
		if e.ok:
			_thumbs[slot] = SaveSlots.thumbnail(e.header)
	menu.set_rows(rows)
	queue_redraw()


func _on_confirm(row: Dictionary) -> void:
	var slot := int(row.slot)
	if saver == null:
		refuse("It will not save here.")
		return
	if mode == &"load":
		var why: String = saver.call("load_from", slot)
		if why != "":
			refuse(why)
			return
		Events.sfx.emit(&"menu_select", Vector3.ZERO)
		_loading = true
		say("Loading %s..." % SaveSlots.slot_name(slot))
		return
	var entry: Dictionary = row.entry
	var now := Time.get_ticks_msec()
	if entry.exists and (_ask_slot != slot or now > _ask_until):
		_ask_slot = slot
		_ask_until = now + int(ASK_SECONDS * 1000.0)
		Events.sfx.emit(&"menu_move", Vector3.ZERO)
		say("Again, to write over %s." % SaveSlots.slot_name(slot))
		return
	_ask_slot = -1
	var why: String = saver.call("save_to", slot)
	if why != "":
		refuse(why)
		return
	Events.sfx.emit(&"menu_select", Vector3.ZERO)
	refresh()
	say("Saved to %s." % SaveSlots.slot_name(slot))


func handle(action: StringName) -> bool:
	if is_open and _loading:
		return true
	return super(action)


func _on_choice_changed() -> void:
	_ask_slot = -1


func _draw() -> void:
	UiNotebook.spread(self, 23 if mode == &"save" else 29)
	var L := UiNotebook.LEFT
	var R := UiNotebook.RIGHT
	UiNotebook.title(self, L, String(mode), 7)
	var x0 := L.position.x + UiNotebook.MARGIN_X
	var right := L.end.x - 10
	for i in menu.rows.size():
		var row := menu.rows[i]
		var e: Dictionary = row.entry
		var n := 1 + i * 3
		var top := UiNotebook.line_top(L, n)
		if i == menu.index:
			UiNotebook.cursor(self, x0 + 4, top)
		var col := UiTheme.INK if UiMenu.enabled(row) else UiTheme.FADED
		UiDraw.text(self, Vector2i(x0 + 14, top), SaveSlots.slot_name(int(row.slot)), col)
		var under := UiNotebook.line_top(L, n + 1)
		if e.ok:
			UiDraw.text_right(self, right, top, played(e.header), UiTheme.INK_SOFT)
			UiDraw.text(self, Vector2i(x0 + 20, under), SaveSlots.describe(e.header), UiTheme.INK_SOFT)
		elif e.exists:
			UiDraw.text(self, Vector2i(x0 + 20, under), "cannot be read", UiTheme.ACCENT)
		else:
			UiDraw.text(self, Vector2i(x0 + 20, under), "empty", UiTheme.FADED)
	var verb := "e save" if mode == &"save" else "e load"
	UiNotebook.footer(self, L, "%s     esc back" % verb)
	_draw_detail(R)
	# The page's word on what just happened, under the facts, where the folio cannot cross it.
	if note != "" and note_age < 4.0:
		var a := clampf(4.0 - note_age, 0.0, 1.0)
		UiDraw.text(self, Vector2i(R.position.x + (R.size.x - THUMB.x) / 2, UiNotebook.line_top(R, 18)), note, Color(UiTheme.ACCENT, a))


func _draw_detail(R: Rect2i) -> void:
	var row := menu.selected()
	if row.is_empty():
		return
	var slot := int(row.slot)
	var e: Dictionary = row.entry
	var pic := Rect2i(R.position.x + (R.size.x - THUMB.x) / 2, R.position.y + 30, THUMB.x, THUMB.y)
	var x0 := pic.position.x
	# The picture sits on the page in a paper mount, taped at its top.
	UiDraw.rect(self, Rect2i(pic.position.x + 3, pic.position.y + 3, pic.size.x + 6, pic.size.y + 6), Color(UiTheme.INK_DEEP, 0.25))
	UiDraw.rect(self, pic.grow(3), UiTheme.SLIP)
	UiDraw.frame(self, pic.grow(4), Color(UiTheme.PAPER_EDGE, 0.8))
	var tex: ImageTexture = _thumbs.get(slot)
	if tex != null:
		draw_texture_rect(tex, Rect2(pic), false)
	else:
		UiDraw.rect(self, pic, Color(UiTheme.PAPER_SHADE, 0.35))
		UiNotebook.box(self, pic.grow(-6), Color(UiTheme.INK_SOFT, 0.5), slot * 7 + 3)
		var word := "cannot be read" if e.exists and not e.ok else "empty"
		UiDraw.text_centred(self, pic.position.x + pic.size.x / 2, pic.position.y + pic.size.y / 2 - 5, word, UiTheme.FADED)
	UiNotebook.tape(self, Vector2i(pic.position.x + pic.size.x / 2 - 14, pic.position.y - 7), 28)
	var line := 12
	if e.ok:
		var h: Dictionary = e.header
		UiDraw.text(self, Vector2i(x0, UiNotebook.line_top(R, line)), str(h.get("clock", "")), UiTheme.INK)
		UiDraw.text(self, Vector2i(x0, UiNotebook.line_top(R, line + 1)), str(h.get("place", "")), UiTheme.INK_SOFT)
		UiDraw.text(self, Vector2i(x0, UiNotebook.line_top(R, line + 2)), played(h), UiTheme.INK_SOFT)
		UiDraw.text(self, Vector2i(x0, UiNotebook.line_top(R, line + 3)), ago(SaveCodec.to_num(h.get("saved_at")), Time.get_unix_time_from_system()), UiTheme.FADED)
	elif e.exists:
		UiNotebook.wrapped(self, Vector2i(x0, UiNotebook.line_top(R, line)), THUMB.x + 20, SaveSlots.problem(slot, e.code), UiTheme.ACCENT)
	elif mode == &"save":
		UiDraw.text(self, Vector2i(x0, UiNotebook.line_top(R, line)), "e writes the game here", UiTheme.FADED)


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
