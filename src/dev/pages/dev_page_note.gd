class_name DevPageNote
extends DevPage
## One note: stage its moment again, copy it out, hand it over (a download on
## the web, its folder anywhere else), or throw it away.

var note: Dictionary = {}
var _picture: ImageTexture


func with(n: Dictionary) -> DevPageNote:
	note = n
	return self


func heading() -> String:
	return "NOTE"


func rows() -> Array[Dictionary]:
	var here := DevStamp.label(DevStamp.current()) if not DevStamp.current().is_empty() else "source %s" % DevStamp.source_commit()
	var same := str(note.get("build", "")) == here
	return [
		item(&"restage", "stage it again", "" if same else "another build", {"tone": "warn" if not same else ""}),
		item(&"copy", "copy it out", "json"),
		item(&"hand", "download it" if DevMode.web() else "open its folder"),
		item(&"repro", "copy the command", "shot.sh"),
		header(""),
		item(&"throw", "throw it away", "", {"tone": "warn"}),
	]


func confirm(row: Dictionary) -> void:
	match row.id:
		&"restage":
			var scene: Node = game if game != null else title
			DevPlay.note(scene, note)
			report("Staging %s." % note.id)
		&"copy":
			DisplayServer.clipboard_set(DevNotes.text(note))
			report("Copied.")
		&"repro":
			DisplayServer.clipboard_set(str(note.get("repro", "")))
			report("Copied the command.")
		&"hand":
			report(DevNotes.hand_over(note))
		&"throw":
			if screen.ask("throw", "Again: the note and its picture go."):
				DevNotes.remove(note)
				Events.sfx.emit(&"ui_slate_back", Vector3.ZERO)
				screen.back()


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var box := Rect2i(panel_x(r) + 12, r.position.y + 24, DevPageNotes.PICTURE.x, DevPageNotes.PICTURE.y)
	if _picture == null:
		var path := DevNotes.folder().path_join(str(note.get("id", "")) + ".png")
		_picture = fitted_texture(Image.load_from_file(path) if FileAccess.file_exists(path) else null, box.size)
	panel_picture(ci, box, _picture)
	var y := box.end.y + 20
	var s: Dictionary = note.get("state", {})
	y = panel_pair(ci, r, y, str(note.get("kind", "")), "%s  %s" % [str(s.get("land", "")), str(s.get("clock", ""))])
	y = panel_pair(ci, r, y, "build", str(note.get("build", "")))
	match screen.menu.selected().get("id", &""):
		&"restage":
			panel_wrapped(ci, r, y + 4, "A new game at this place, hour, sky and kit, with its saves kept apart. Made in another build, the land may not be the same.")
		&"repro":
			panel_wrapped(ci, r, y + 4, str(note.get("repro", "")))
		_:
			panel_wrapped(ci, r, y + 4, str(note.get("words", "")), UiTheme.TEXT)
