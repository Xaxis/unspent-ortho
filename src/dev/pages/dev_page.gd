class_name DevPage
extends RefCounted
## One page of the dev app (UiDevScreen). A page is rows on the left (the menu
## standard: up and down choose, left and right change a value, e step in or
## do, esc back one level) and what the chosen row is about on the spare panel.
##
## A row is a Dictionary: {id, text, value: String, steps: bool (left and right
## change it), edited: bool (a configuration edit not kept), enabled, why,
## tone: &"" | &"warn" | &"dev"}, or {header: "words"}.
##
## Pages never touch the input or the slate directly: they are handed the game
## (null on the title), and say, refuse, ask and open through `screen`.

var screen: UiDevScreen
var game: Game
var title: UiTitle
## The menu's choice while a page opened over this one is up.
var index := -1


func heading() -> String:
	return ""


func rows() -> Array[Dictionary]:
	return []


func confirm(_row: Dictionary) -> void:
	pass


func side(_row: Dictionary, _dir: int) -> void:
	pass


func detail(_ci: CanvasItem, _r: Rect2i) -> void:
	pass


func keys(row: Dictionary) -> Array:
	var out: Array = [["e", "do"]]
	if bool(row.get("steps", false)):
		out.append(["a d", "change"])
	out.append(["esc", "back"])
	return out


## Called every frame while the page is on the glass.
func step(_delta: float) -> void:
	pass


# --- rows -------------------------------------------------------------------------------

static func item(id: StringName, text: String, value: String = "", extra: Dictionary = {}) -> Dictionary:
	var r := {"id": id, "text": text, "value": value}
	r.merge(extra, true)
	return r


static func header(text: String) -> Dictionary:
	return {"header": text}


## A row only the machine the game is built on can do: faded elsewhere, with why.
static func local_only(r: Dictionary) -> Dictionary:
	var why := DevMode.why_not_local()
	if why != "":
		r["enabled"] = false
		r["why"] = why
	return r


func say(text: String) -> void:
	screen.say(text)


func refuse(text: String) -> void:
	screen.refuse(text)


## A row's act said back: "" nothing, "!why" a refusal, anything else a line.
func report(line: String) -> void:
	if line == "":
		return
	if line.begins_with("!"):
		refuse(line.substr(1))
	else:
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
		say(line)


# --- the spare panel ----------------------------------------------------------------------

const PANEL_PAD := 10


static func panel_x(r: Rect2i) -> int:
	return r.position.x + PANEL_PAD


static func panel_right(r: Rect2i) -> int:
	return r.end.x - 12


## A heading on the panel; returns the y the next line goes at.
static func panel_heading(ci: CanvasItem, r: Rect2i, y: int, text: String, dev: bool = false) -> int:
	UiSlate.heading(ci, Vector2i(panel_x(r), y), text, panel_right(r), UiTheme.MACHINE[3] if dev else UiTheme.TEXT_DIM)
	return y + 15


static func panel_line(ci: CanvasItem, r: Rect2i, y: int, text: String, col: Color = UiTheme.TEXT) -> int:
	UiDraw.text(ci, Vector2i(panel_x(r) + 4, y), _fit(text, panel_right(r) - panel_x(r) - 4), col)
	return y + UiTheme.LINE


## "name   value" on one line: the name dim, the value on the right.
static func panel_pair(ci: CanvasItem, r: Rect2i, y: int, name: String, value: String, col: Color = UiTheme.TEXT) -> int:
	UiDraw.text(ci, Vector2i(panel_x(r) + 4, y), name, UiTheme.TEXT_DIM)
	UiDraw.text_right(ci, panel_right(r), y, _fit(value, panel_right(r) - panel_x(r) - 70), col)
	return y + UiTheme.LINE


static func panel_wrapped(ci: CanvasItem, r: Rect2i, y: int, text: String, col: Color = UiTheme.TEXT_DIM) -> int:
	var used := UiSlate.wrapped(ci, Vector2i(panel_x(r) + 4, y), panel_right(r) - panel_x(r) - 4, text, col)
	return y + maxi(used, 1) * UiTheme.LINE + 2


## The last lines of a log, as many as fit above `bottom`.
static func panel_log(ci: CanvasItem, r: Rect2i, y: int, lines: PackedStringArray, bottom: int) -> int:
	var n := maxi(0, (bottom - y) / UiTheme.LINE)
	var from := maxi(0, lines.size() - n)
	for i in range(from, lines.size()):
		var l := lines[i]
		var col := UiTheme.TEXT_DIM
		if l.contains("FAIL") or l.contains("ERROR") or l.begins_with("== stopped"):
			col = UiTheme.WARN
		elif l.contains(" ok") or l.begins_with("export ") or l.contains("CHECK OK") or l.begins_with("deploy done"):
			col = UiTheme.TEXT
		y = panel_line(ci, r, y, l.replace("\t", "  "), col)
	return y


## A picture fitted into `box`, in brackets. Hand it one already made that size
## (fitted_texture): shrunk here it would be sampled nearest and shimmer.
static func panel_picture(ci: CanvasItem, box: Rect2i, tex: Texture2D) -> void:
	UiSlate.brackets(ci, box.grow(2), UiTheme.TEXT_DIM, 5)
	if tex == null:
		UiDraw.text_centred(ci, box.position.x + box.size.x / 2, box.position.y + box.size.y / 2 - 5, "NO PICTURE", UiTheme.TEXT_DIM)
		return
	var s := tex.get_size()
	var k := maxf(s.x / box.size.x, s.y / box.size.y)
	var size := Vector2(floorf(s.x / k), floorf(s.y / k))
	var at := Vector2(box.position) + (Vector2(box.size) - size) * 0.5
	ci.draw_texture_rect(tex, Rect2(at.floor(), size), false)


## Text cut to fit `width` pixels, with an ellipsis.
static func _fit(text: String, width: int) -> String:
	if UiFont.width(text) <= width:
		return text
	var t := text
	while t.length() > 1 and UiFont.width(t + "…") > width:
		t = t.left(t.length() - 1)
	return t + "…"


## An image shrunk once, smoothly, to fit `size`, as a texture for panel_picture.
static func fitted_texture(img: Image, size: Vector2i) -> ImageTexture:
	if img == null or img.is_empty():
		return null
	var copy := img.duplicate() as Image
	var k := maxf(float(copy.get_width()) / size.x, float(copy.get_height()) / size.y)
	if k > 1.0:
		copy.resize(maxi(1, floori(copy.get_width() / k)), maxi(1, floori(copy.get_height() / k)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(copy)
