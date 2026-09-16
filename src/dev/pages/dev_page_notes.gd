class_name DevPageNotes
extends DevPage
## Notes: a new one of the moment the app was opened on (its picture was taken
## before the slate woke), and every note kept on this device, newest first.

var _kind := "bug"
var _words := ""
var _notes: Array[Dictionary] = []
var _read_at := -INF
## note id -> its picture, shrunk to the panel.
var _pictures := {}
var _pending: ImageTexture
const PICTURE := Vector2i(280, 158)


func heading() -> String:
	return "NOTES"


func rows() -> Array[Dictionary]:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _read_at > 2.0:
		_read_at = now
		_notes = DevNotes.list()
	var out: Array[Dictionary] = []
	if game != null:
		out.append(header("a note of this moment"))
		out.append(item(&"kind", "kind", _kind, {"steps": true}))
		out.append(item(&"words", "words", _words if _words != "" else "-"))
		out.append(item(&"keep", "keep it", "", {"tone": "dev"}))
	out.append(header("kept here"))
	if _notes.is_empty():
		out.append(item(&"none", "no notes yet", "", {"enabled": false, "why": "A note is made in a game: F2, or here."}))
	for n: Dictionary in _notes:
		var words := str(n.get("words", ""))
		out.append(item(StringName(str(n.id)), "%s  %s" % [str(n.kind), words if words != "" else str(n.state.get("clock", ""))],
			UiSavesScreen.ago(float(n.get("at", 0)), Time.get_unix_time_from_system()).trim_prefix("saved ")))
	return out


func confirm(row: Dictionary) -> void:
	match row.id:
		&"kind":
			side(row, 1)
		&"words":
			screen.edit_text(&"words", _words, 60, func(text: String) -> void: _words = text.strip_edges())
		&"keep":
			var note := DevNotes.make(game, _kind, _words)
			var why := DevNotes.write(note, screen.picture)
			if why != "":
				refuse(why)
				return
			_words = ""
			_read_at = -INF
			report("Kept %s." % note.id)
		_:
			var n := _note(row.id)
			if not n.is_empty():
				screen.push_page(DevPageNote.new().with(n))


func side(row: Dictionary, dir: int) -> void:
	if row.id != &"kind":
		return
	_kind = DevNotes.KINDS[posmod(DevNotes.KINDS.find(_kind) + dir, DevNotes.KINDS.size())]
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func keys(row: Dictionary) -> Array:
	match row.get("id", &""):
		&"kind":
			return [["a d", "change"], ["esc", "back"]]
		&"words":
			return [["e", "write"], ["esc", "back"]]
		&"keep":
			return [["e", "keep"], ["esc", "back"]]
	return [["e", "open"], ["esc", "back"]]


func _note(id: StringName) -> Dictionary:
	for n: Dictionary in _notes:
		if StringName(str(n.id)) == id:
			return n
	return {}


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var row := screen.menu.selected()
	var box := Rect2i(panel_x(r) + 6, r.position.y + 12, PICTURE.x, PICTURE.y)
	var n := _note(row.get("id", &""))
	var y := box.end.y + 10
	if n.is_empty():
		if game == null:
			return
		if _pending == null and screen.picture != null:
			_pending = fitted_texture(screen.picture, PICTURE)
		panel_picture(ci, box, _pending)
		y = panel_pair(ci, r, y, "where", "%s  %s" % [BiomeRegistry.at(game.world, game.player.pos).display_name.to_lower(), game.clock.label()])
		y = panel_pair(ci, r, y, "build", DevReadout.build_line())
		panel_wrapped(ci, r, y + 2, "Kept with the picture, the state of the game and the command that stages this moment again.")
		return
	if not _pictures.has(n.id):
		var img: Image = null
		var path := DevNotes.folder().path_join(str(n.id) + ".png")
		if FileAccess.file_exists(path):
			img = Image.load_from_file(path)
		_pictures[n.id] = fitted_texture(img, PICTURE)
	panel_picture(ci, box, _pictures[n.id])
	y = panel_pair(ci, r, y, "where", "%s  %s" % [str(n.state.get("land", "")), str(n.state.get("clock", ""))])
	y = panel_pair(ci, r, y, "build", str(n.get("build", "")))
	y = panel_pair(ci, r, y, "config", str(n.get("config", "")) if str(n.get("config", "")) != "" else "none")
	panel_wrapped(ci, r, y + 2, str(n.get("words", "")), UiTheme.TEXT)
