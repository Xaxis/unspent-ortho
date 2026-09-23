class_name UiJournalScreen
extends UiScreen
## The journal (n): what the player has found out, kept where they can read it
## again (docs/STORY.md, §15).
##
## Three kinds of row, each section only once it holds something:
##   an arc's title, and under it every beat of that arc that has LANDED, in the
##   arc's own order — never a beat still to come, never how many are left, so
##   the story is a thing being learnt and not a list being ticked off;
##   READ, every fragment read, oldest first, whose lines the spare pane gives
##   back exactly as they were written, so a sign walked away from can be read
##   again;
##   SAID, every answer the player gave somebody, and what it was said to.
##
## It only reads. `Story` is the state and `StoryContent` the words; nothing on
## this page lands a beat, reads a fragment or records a choice, and a test
## holds it to that.

## Every position on this page is measured from the slate's own panes
## (UiSlate.LIST, UiSlate.SPARE), never from the screen, so it goes wherever the
## slate goes and at whatever size it is drawn.
##
## The first row, below the top of the list pane: clear of the app's title.
const ROWS_DOWN := 36
## Clear pixels between a row's title and the words right-aligned beside it.
const COLUMN_GAP := 20
## The spare pane's heading, below the top of the pane, and the words under it.
const PANE_DOWN := 16
const UNDER_HEADING := 32
## Kept clear at the foot of the spare pane.
const PANE_FOOT := 12

## The row the story last added to while the page was shut: the journal opens on
## what the player has just found, the way a notebook falls open at its last page.
var latest: StringName = &""


func _init() -> void:
	super()
	screen_name = &"journal"
	own_action = &"journal"


func _enter_tree() -> void:
	# Listened to while shut as well as open: the page has to know what came last
	# when it is next opened, and redraw at once if it is open when it happens.
	if not Events.story_found.is_connected(_on_found):
		Events.story_found.connect(_on_found)
		Events.story_beat.connect(_on_beat)
		Events.story_chose.connect(_on_chose)


func _exit_tree() -> void:
	if Events.story_found.is_connected(_on_found):
		Events.story_found.disconnect(_on_found)
		Events.story_beat.disconnect(_on_beat)
		Events.story_chose.disconnect(_on_chose)
	super()


func _on_open() -> void:
	scroll = 0
	menu.set_rows(rows_now())
	if latest != &"":
		select(latest)
		latest = &""


func refresh() -> void:
	menu.set_rows(rows_now())
	queue_redraw()


func _on_found(id: StringName) -> void:
	_story_moved(StringName("read_%s" % id))


func _on_beat(id: StringName) -> void:
	_story_moved(StringName("beat_%s" % id))


func _on_chose(where: StringName, _pick: StringName) -> void:
	_story_moved(StringName("said_%s" % where))


func _story_moved(row: StringName) -> void:
	if is_open:
		refresh()
	else:
		latest = row


## Reading a page is not doing anything: confirm has no verb here, and a sound
## would promise one.
func _on_confirm(_row: Dictionary) -> void:
	pass


# --- what is on the page -------------------------------------------------------

## Every row the journal holds now, built from the story's state and nothing
## else. Static and pure, so a test reads the page without drawing it.
static func rows_now() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for arc: StringName in StoryContent.arcs():
		var def: Dictionary = StoryContent.ARCS[arc]
		var landed: Array[Dictionary] = []
		for beat: StringName in StoryContent.arc_beats(arc):
			if not Story.landed(beat):
				continue
			landed.append({"id": StringName("beat_%s" % beat), "beat": beat, "arc": arc,
				"title": short_of(beat)})
		if landed.is_empty():
			continue
		rows.append({"header": String(def.get("title", arc))})
		rows.append_array(landed)
	var found := Story.found()
	if not found.is_empty():
		rows.append({"header": "read"})
		for id: StringName in found:
			var title := StoryFragments.title_of(id)
			rows.append({"id": StringName("read_%s" % id), "fragment": id,
				"title": title if title != "" else String(id),
				"kind": String(StoryFragments.kind_of(id))})
	var said := said_rows()
	if not said.is_empty():
		rows.append({"header": "said"})
		rows.append_array(said)
	if rows.is_empty():
		rows.append({"id": &"nothing", "title": "nothing written yet", "dim": true})
	return rows


## What a beat is called in the list: the content's own `short` when it gives
## one, otherwise the first sentence of what the beat says. The whole line is on
## the spare pane.
static func short_of(beat: StringName) -> String:
	var def: Dictionary = StoryContent.BEATS.get(beat, {})
	var short := String(def.get("short", ""))
	if short != "":
		return short
	var says := StoryContent.beat_says(beat)
	if says == "":
		return String(beat)
	var stop := says.find(". ")
	return says.substr(0, stop + 1) if stop >= 0 else says


## One row per answer given, in the order the conversation itself is written
## rather than the order the save file happened to keep, which is alphabetical
## once a game has been saved and loaded. Answers whose talk or node is no longer
## in the content follow, as the record has them.
static func said_rows() -> Array[Dictionary]:
	var choices := Story.choices()
	var rows: Array[Dictionary] = []
	var placed: Dictionary = {}
	for talk: StringName in StoryContent.TALKS:
		var nodes: Dictionary = StoryContent.TALKS[talk].get("nodes", {})
		for node: StringName in nodes:
			var where := StringName("%s.%s" % [talk, node])
			if choices.has(where):
				rows.append(said_row(where, StringName(str(choices[where]))))
				placed[where] = true
	for where: StringName in choices:
		if not placed.has(where):
			rows.append(said_row(where, StringName(str(choices[where]))))
	return rows


## A choice as a row: what it was said to, and the words the player picked. A
## pick the content no longer has (a line rewritten since the save) shows its id
## plainly: the record is still true, only the words for it have gone.
static func said_row(where: StringName, pick: StringName) -> Dictionary:
	var s := String(where)
	var dot := s.find(".")
	var talk := StringName(s.substr(0, dot)) if dot >= 0 else where
	var node := StringName(s.substr(dot + 1)) if dot >= 0 else &""
	var def: Dictionary = StoryContent.TALKS.get(talk, {})
	var title := String(def.get("title", ""))
	var says := PackedStringArray()
	var text := ""
	var at: Dictionary = def.get("nodes", {}).get(node, {})
	for l: String in at.get("says", []):
		says.append(l)
	for r: Dictionary in at.get("replies", []):
		if StringName(str(r.get("pick", &""))) == pick:
			text = String(r.get("text", ""))
			break
	return {"id": StringName("said_%s" % where), "where": where, "pick": pick,
		"title": title if title != "" else String(talk),
		"said": text if text != "" else String(pick), "says": says}


## Which part of the page the chosen row belongs to: &"beat", &"read", &"said",
## or &"" (the empty page). What a tour's `journal:SECTION` asks.
func section() -> StringName:
	var row := menu.selected()
	if row.has("beat"):
		return &"beat"
	if row.has("fragment"):
		return &"read"
	if row.has("where"):
		return &"said"
	return &""


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	# No tab of its own on the status strip, as the holding has none: the slate
	# itself is lit.
	draw_frame(&"")
	var L := UiSlate.LIST
	UiSlate.title(self, L, "JOURNAL")
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 16
	var first := L.position.y + ROWS_DOWN
	var lines := UiSlate.line_count(first, L.end.y - 8)
	keep_in_view(lines)
	for n in mini(lines, menu.rows.size() - scroll):
		var i := scroll + n
		var row := menu.rows[i]
		var top := UiSlate.line_top(first, n)
		if row.has("header"):
			UiSlate.heading(self, Vector2i(x0, top), String(row.header), right)
			continue
		var col := UiTheme.TEXT_DIM if row.get("dim", false) else UiTheme.TEXT
		var aside := _aside(row)
		if i == menu.index and not row.get("dim", false):
			UiSlate.row_bar(self, x0 - 8, right + 6, top)
			col = UiTheme.BRIGHT
		var room := right - (x0 + 8)
		var title := String(row.title)
		if aside != "":
			# The title keeps its words; what stands beside it gives way first.
			var title_w := UiFont.width(title)
			aside = UiSlate.elided(aside, room - mini(title_w, room / 2) - COLUMN_GAP)
		if aside != "":
			title = _fit(title, room - UiFont.width(aside) - COLUMN_GAP)
			UiDraw.text_right(self, right, top, aside, UiTheme.TEXT_DIM)
		else:
			title = _fit(title, room)
		UiDraw.text(self, Vector2i(x0 + 8, top), title, col)
	if scroll > 0:
		UiDraw.text_right(self, right, first - UiTheme.LINE, "↑", UiTheme.TEXT_DIM)
	if scroll + lines < menu.rows.size():
		UiDraw.text_right(self, right, UiSlate.line_top(first, lines) - 4, "↓", UiTheme.TEXT_DIM)
	_draw_spare(UiSlate.SPARE)
	if is_inside_tree() and get_tree().paused:
		# Over home the world is stopped and so is the system that reads this
		# page's own key: only the key that works is offered.
		draw_keys([["esc", "back"]])
	else:
		draw_keys([[key_name(), "close"], ["esc", "back"]])


## The words right-aligned on a row: what kind of thing was read, or what was said.
static func _aside(row: Dictionary) -> String:
	if row.has("fragment"):
		return String(row.get("kind", ""))
	if row.has("where"):
		return String(row.get("said", ""))
	return ""


## `text` cut with an ellipsis to `room` pixels, or whole when it fits. Unlike
## UiSlate.elided it never gives back nothing: a row always says what it is.
static func _fit(text: String, room: int) -> String:
	if UiFont.width(text) <= room:
		return text
	var cut := UiSlate.elided(text, room)
	# Six cells of the module's grid is the widest advance the face has, so this
	# never over-counts the letters that fit.
	return cut if cut != "" else text.left(maxi(1, room / (6 * UiFont.PITCH)))


## The key the journal is on now, rebinds included, as the key strip names keys.
static func key_name() -> String:
	var code := PlayerSettings.key_of(&"journal")
	return OS.get_keycode_string(code).to_lower() if code != KEY_NONE else "n"


func _draw_spare(R: Rect2i) -> void:
	var row := menu.selected()
	var x0 := R.position.x + UiSlate.MARGIN_L
	var width := R.end.x - UiSlate.MARGIN_R - x0
	var bottom := R.end.y - PANE_FOOT
	var y := R.position.y + PANE_DOWN
	var rule := R.end.x - UiSlate.MARGIN_R
	if row.has("beat"):
		var arc: StringName = row.arc
		_heading(x0, y, String(StoryContent.ARCS.get(arc, {}).get("title", arc)), rule)
		y += UNDER_HEADING
		y = _page(x0, y, width, bottom, PackedStringArray([StoryContent.beat_says(row.beat)]), UiTheme.BRIGHT)
		y += 16
		var note := String(StoryContent.ARCS.get(arc, {}).get("note", ""))
		if note != "":
			_page(x0, y, width, bottom, PackedStringArray([note]), UiTheme.TEXT_DIM)
	elif row.has("fragment"):
		_heading(x0, y, String(row.title), rule)
		y += UNDER_HEADING
		var lines := StoryFragments.lines(row.fragment)
		if lines.is_empty():
			lines = PackedStringArray(["Nothing on it can be read now."])
		_page(x0, y, width, bottom, lines, UiTheme.TEXT)
	elif row.has("where"):
		_heading(x0, y, String(row.title), rule)
		y += UNDER_HEADING
		var says: PackedStringArray = row.get("says", PackedStringArray())
		y = _page(x0, y, width, bottom, says, UiTheme.TEXT_DIM)
		y += 12
		# What the player said, marked the way the conversation marked it when it
		# was chosen, so the two read as the same moment.
		if y + UiTheme.LINE <= bottom:
			UiDraw.rect(self, Rect2i(x0, y, 6, UiTheme.LINE - 2), UiTheme.TEXT)
		_page(x0 + 16, y, width - 16, bottom, PackedStringArray([String(row.said)]), UiTheme.BRIGHT)
	else:
		_page(x0, y, width, bottom, PackedStringArray(["What you read and what you are told is kept here."]), UiTheme.TEXT_DIM)


## A heading on the spare pane, cut to the pane: a title is content-written and
## may be longer than anybody measured.
func _heading(x: int, y: int, text: String, right: int) -> void:
	UiSlate.heading(self, Vector2i(x, y), _fit(text.to_upper(), right - x), right)


## Lines drawn from `y` down, each wrapped to `width`, stopping at `bottom`.
## Returns the y under the last line drawn.
func _page(x: int, y: int, width: int, bottom: int, lines: PackedStringArray, col: Color) -> int:
	var shown := page_lines(width, lines)
	for i in shown.size():
		if y + UiTheme.LINE > bottom:
			return y
		if i < shown.size() - 1 and y + 2 * UiTheme.LINE > bottom:
			# Nothing written for the glass should be longer than it
			# (docs/STORY.md); if something is, it is cut where it is seen to be.
			UiDraw.text(self, Vector2i(x, y), "…", UiTheme.TEXT_DIM)
			return y + UiTheme.LINE
		if shown[i] != "":
			UiDraw.text(self, Vector2i(x, y), shown[i], col)
		y += UiTheme.LINE
	return y


## Lines as the glass will show them: each broken at `width`, a blank line kept
## as a blank line, and a line's leading spaces kept on every piece of it — how a
## clerk's readout lines up its columns and how a quote hangs under its mark.
static func page_lines(width: int, lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in lines:
		var body := line.strip_edges(true, false)
		if body == "":
			out.append("")
			continue
		var indent := line.substr(0, line.length() - body.length())
		var room := width - UiFont.width(indent + "x") + UiFont.width("x")
		for piece: String in UiSlate.wrap_text(room, body):
			out.append(indent + _fit(piece, room))
	return out
