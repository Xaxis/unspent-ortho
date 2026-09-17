class_name DevPageGo
extends DevPage
## Warp: the strand, every landscape, every village, the river, the cliff and
## the first of every kind of landmark. E goes there and shuts the app, so the
## place is what is seen next.

var _places: Array[Dictionary] = []


func heading() -> String:
	return "GO"


func rows() -> Array[Dictionary]:
	if _places.is_empty():
		_places = DevCheats.places(game)
	var out: Array[Dictionary] = []
	if DevSession.came_from.is_finite():
		out.append(item(&"back", "back where I was", _tiles(DevSession.came_from)))
	var group := ""
	for p: Dictionary in _places:
		var g := _group(String(p.id))
		if g != group:
			group = g
			out.append(header(g))
		out.append(item(p.id, p.label, _tiles(p.pos)))
	return out


static func _group(id: String) -> String:
	if id.begins_with("land_") or id == "spawn":
		return "landscapes"
	if id.begins_with("village_"):
		return "villages"
	return "landmarks"


func _tiles(p: Vector2) -> String:
	return "%d tiles" % roundi(p.distance_to(game.player.pos))


func _place(id: StringName) -> Dictionary:
	for p: Dictionary in _places:
		if p.id == id:
			return p
	return {}


func confirm(row: Dictionary) -> void:
	var to := DevSession.came_from if row.id == &"back" else Vector2.INF
	if row.id != &"back":
		var p := _place(row.id)
		if p.is_empty():
			return
		to = p.pos
	DevSession.came_from = game.player.pos
	DevCheats.teleport(game, to)
	Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	screen.close()


func keys(_row: Dictionary) -> Array:
	return [["e", "go there"], ["esc", "back"]]


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var row := screen.menu.selected()
	var y := r.position.y + 16
	var to := DevSession.came_from if row.get("id") == &"back" else Vector2.INF
	var note := "where the last warp left from"
	if row.get("id") != &"back":
		var p := _place(row.get("id", &""))
		if p.is_empty():
			return
		to = p.pos
		note = str(p.note)
	y = panel_heading(ci, r, y, str(row.get("text", "")))
	var w := game.world
	var b := BiomeRegistry.at(w, to)
	y = panel_pair(ci, r, y, "at", "%.1f, %.1f" % [to.x, to.y])
	y = panel_pair(ci, r, y, "land", b.display_name.to_lower())
	y = panel_pair(ci, r, y, "level", str(w.level_at(floori(to.x), floori(to.y))))
	var d := to - game.player.pos
	y = panel_pair(ci, r, y, "from here", "%d tiles %s" % [roundi(d.length()), _bearing(d)])
	if note != "":
		y = panel_wrapped(ci, r, y + 8, note)


static func _bearing(d: Vector2) -> String:
	if d.length() < 1.0:
		return ""
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[posmod(roundi(d.angle() / (TAU / 8.0)), 8)]
