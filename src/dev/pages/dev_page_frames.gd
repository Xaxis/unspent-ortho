class_name DevPageFrames
extends DevPage
## The frames a proof shot, to look at on the glass one by one (up and down), or
## their folder opened.

## The picture as it stands on the panel: the same share of the glass it always
## covered, drawn at three times the detail.
const PICTURE := Vector2i(840, 474)

var dir := ""
var _files: PackedStringArray = []
var _pictures := {}


func at(path: String) -> DevPageFrames:
	dir = path
	return self


func heading() -> String:
	return "FRAMES"


func rows() -> Array[Dictionary]:
	if _files.is_empty() and DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".png"):
				_files.append(f)
		_files.sort()
	var out: Array[Dictionary] = [item(&"folder", "open the folder", dir.get_file())]
	if _files.is_empty():
		out.append(item(&"none", "no frames", "", {"enabled": false, "why": "The run shot nothing here."}))
	for f in _files:
		out.append(item(StringName(f), f.get_basename(), "", {"tone": "warn" if f.begins_with("FAILED") else ""}))
	return out


func confirm(row: Dictionary) -> void:
	if row.id == &"folder":
		OS.shell_open(dir)
		return
	OS.shell_open(dir.path_join(String(row.id)))


func keys(_row: Dictionary) -> Array:
	return [["e", "open"], ["esc", "back"]]


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var f := String(screen.menu.selected().get("id", ""))
	if not f.ends_with(".png"):
		return
	if not _pictures.has(f):
		var img := Image.load_from_file(dir.path_join(f))
		_pictures[f] = fitted_texture(img, PICTURE)
	var box := Rect2i(panel_x(r) + 12, r.position.y + 24, PICTURE.x, PICTURE.y)
	panel_picture(ci, box, _pictures[f])
	var y := box.end.y + 20
	y = panel_line(ci, r, y, f, UiTheme.TEXT)
	panel_wrapped(ci, r, y, "Looked at here at a little under half its size; e opens it whole.")
