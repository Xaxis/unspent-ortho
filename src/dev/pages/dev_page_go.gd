class_name DevPageGo
extends DevPage
## Warp: anywhere in this world (owner, 2026-09-18, "a menu that enables me to
## jump anywhere in the world so I can inspect and debug"). Every region of every
## landscape, every border two of them share, every village, the river, the cliff,
## the plan's depots, the keepers' lairs, the shafts down, the first of every kind
## of landmark — and a line to TYPE, for the places a list cannot hold.
##
## E goes there and shuts the app, so the place is what is seen next.
##
## And the map whole (owner, 2026-09-18, "in dev mode you should obviously be able
## to reveal the full world map on the map"), which belongs here rather than on
## VIEW because it is the other half of warping: the rows below say where a place
## is, and the survey is how you decide it is worth the trip.
##
## The typed line is the whole of "anywhere": it takes a coordinate ("342, 362")
## and every name GenPlaces answers to — the same words the tools' `--place=` and
## a tour's `place` take, including the ones no row here could ever list, like
## `typical_moss`, `open_coast`, `tip3` or `works_breaker`. Rows are for what the
## world happens to hold; the line is for what you already know you want.

const TYPED_MAX := 40

var _places: Array[Dictionary] = []
## What was last typed, kept so a second warp by name does not retype it.
var _typed := ""
var _typed_at := Vector2.INF
var _typed_why := ""


func heading() -> String:
	return "GO"


## One row whose spot still costs a whole-world sweep, settled per frame, so the
## list is on the glass before the island is read for the last of it. A place
## this world does not have is dropped rather than left as a row that refuses.
func step(_delta: float) -> void:
	for i in _places.size():
		var p: Dictionary = _places[i]
		if not p.has("later"):
			continue
		var at := DevCheats.settle(game.world, str(p.later))
		p.erase("later")
		if at.is_finite():
			p.pos = at
		else:
			_places.remove_at(i)
		screen.refresh()
		return


func rows() -> Array[Dictionary]:
	if _places.is_empty():
		_places = DevCheats.places(game)
	var out: Array[Dictionary] = []
	if DevSession.came_from.is_finite():
		out.append(item(&"back", "back where I was", _tiles(DevSession.came_from)))
	out.append(item(&"typed", "by name or x,y…", _typed))
	# On GO rather than VIEW because it is half of warping: the list below says
	# where a place IS, and the map is how you decide it is worth going.
	out.append(item(&"map", "the whole map", "shown" if _map_shown() else "as walked", {"steps": true}))
	var group := ""
	for p: Dictionary in _places:
		var g := _group(String(p.id))
		if g != group:
			group = g
			out.append(header(g))
		out.append(item(p.id, p.label, _tiles(p.pos)))
	return out


static func _group(id: String) -> String:
	if id.begins_with("land_") or id.begins_with("region_") or id == "spawn":
		return "landscapes"
	if id.begins_with("border_"):
		return "borders"
	if id.begins_with("village_"):
		return "villages"
	if id.begins_with("works_") or id.begins_with("lair_") or id.begins_with("shaft_"):
		return "the plan"
	return "landmarks"


func _tiles(p: Vector2) -> String:
	if not p.is_finite():
		return ""
	return "%d tiles" % roundi(p.distance_to(game.player.pos))


func _place(id: StringName) -> Dictionary:
	for p: Dictionary in _places:
		if p.id == id:
			return p
	return {}


## Where a row goes, Vector2.INF when it has nowhere (a typed line that resolved
## to nothing). The list is rebuilt per world, so a position here is always this
## world's.
func _to(id: StringName) -> Vector2:
	if id == &"back":
		return DevSession.came_from
	if id == &"typed":
		return _typed_at
	var p := _place(id)
	if p.is_empty():
		return Vector2.INF
	if p.has("later"):
		# Asked for before step() got to it: settle it now rather than refuse.
		var at := DevCheats.settle(game.world, str(p.later))
		p.erase("later")
		p.pos = at
	return p.pos as Vector2


## The explored map of whichever system keeps one, through the same door the save
## takes: systems are found by what they KEEP, never by their number.
func _explored() -> UiExplored:
	return SaveCore.explored_of(game)


func _map_shown() -> bool:
	var e := _explored()
	return e != null and e.revealed


func _show_map(on: bool) -> void:
	var e := _explored()
	if e == null:
		return
	if on:
		e.reveal_all(game.world)
	else:
		e.revealed = false
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func confirm(row: Dictionary) -> void:
	var id: StringName = row.get("id", &"")
	if id == &"typed":
		screen.edit_text(&"typed", _typed, TYPED_MAX, _resolve)
		return
	if id == &"map":
		_show_map(not _map_shown())
		return
	_go(_to(id))


## Go, or say why not. Kept apart from confirm() because the typed row's confirm
## is "open the line", so a typed place that resolved cannot ask confirm to take
## it — that is a loop that reopens the line instead of warping.
func _go(to: Vector2) -> void:
	if not to.is_finite():
		refuse(_typed_why if _typed_why != "" else "nowhere to go")
		return
	DevSession.came_from = game.player.pos
	DevCheats.teleport(game, to)
	Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	screen.close()


## What was typed, once the line is done: a coordinate or a GenPlaces name. It
## GOES straight away when it resolves — typing a place and then pressing e again
## to use it is one press too many for a key whose whole point is to be quick.
func _resolve(text: String) -> void:
	_typed = text.strip_edges()
	_typed_at = Vector2.INF
	_typed_why = ""
	if _typed == "":
		return
	var at := DevCheats.find_place(game.world, _typed)
	if not at.is_finite():
		_typed_why = "no place called \"%s\"" % _typed
		refuse(_typed_why)
		screen.refresh()
		return
	_typed_at = at
	_go(at)


func side(row: Dictionary, _dir: int) -> void:
	if row.get("id") == &"map":
		_show_map(not _map_shown())


func keys(row: Dictionary) -> Array:
	match row.get("id"):
		&"typed":
			return [["e", "type a place"], ["esc", "back"]]
		&"map":
			return [["e", "shown / as walked"], ["esc", "back"]]
	return [["e", "go there"], ["esc", "back"]]


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var row := screen.menu.selected()
	var id: StringName = row.get("id", &"")
	var y := r.position.y + 16
	y = panel_heading(ci, r, y, str(row.get("text", "")))
	if id == &"typed":
		_typed_detail(ci, r, y)
		return
	if id == &"map":
		_map_detail(ci, r, y)
		return
	var to := _to(id)
	if not to.is_finite():
		return
	var note := "where the last warp left from"
	if id != &"back":
		var p := _place(id)
		if p.is_empty():
			return
		note = str(p.note)
	_where(ci, r, y, to, note)


## Says what it does and, as plainly, what it does NOT: the walked map is still
## underneath and the share on the pause page still counts it, so this can be
## turned on to read a seed and off again without having spent anybody's game.
func _map_detail(ci: CanvasItem, r: Rect2i, y: int) -> void:
	var e := _explored()
	y = panel_pair(ci, r, y, "walked", "%d%%" % roundi((e.fraction() if e != null else 0.0) * 100.0))
	y = panel_wrapped(ci, r, y + 8, "The survey (m) drawn whole, every landscape, border and "
		+ "village, whether it has been walked to or not.")
	panel_wrapped(ci, r, y + 8, "Shown only. What the player has really seen is untouched "
		+ "underneath, the walked share above still counts it, and nothing of this reaches a save.")


func _typed_detail(ci: CanvasItem, r: Rect2i, y: int) -> void:
	if _typed_at.is_finite():
		_where(ci, r, y, _typed_at, "\"%s\"" % _typed)
		return
	if _typed_why != "":
		y = panel_wrapped(ci, r, y, _typed_why, UiTheme.WARN)
		y += 8
	panel_wrapped(ci, r, y, "A coordinate (\"342, 362\"), or any name the tools take: "
		+ "a landscape, two with a dash between them for their border, typical_LAND, "
		+ "open_LAND, a landmark kind with an Nth (tip3), works, river, cliff, spawn.")


## What is at `to`, and how far off: the same four lines for a row and a typed line.
func _where(ci: CanvasItem, r: Rect2i, y: int, to: Vector2, note: String) -> int:
	var w := game.world
	var b := BiomeRegistry.at(w, to)
	y = panel_pair(ci, r, y, "at", "%.1f, %.1f" % [to.x, to.y])
	y = panel_pair(ci, r, y, "land", b.display_name.to_lower())
	y = panel_pair(ci, r, y, "level", str(w.level_at(floori(to.x), floori(to.y))))
	var d := to - game.player.pos
	y = panel_pair(ci, r, y, "from here", "%d tiles %s" % [roundi(d.length()), _bearing(d)])
	if note != "":
		y = panel_wrapped(ci, r, y + 8, note)
	return y


static func _bearing(d: Vector2) -> String:
	if d.length() < 1.0:
		return ""
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[posmod(roundi(d.angle() / (TAU / 8.0)), 8)]
