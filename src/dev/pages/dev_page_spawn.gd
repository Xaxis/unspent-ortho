class_name DevPageSpawn
extends DevPage
## Bodies and the plan: whether the land puts bodies round the player (the
## configuration's `rules.machines`), clearing it, the file this region's network
## keeps on the player, and any roster kind put down in front of them.


func heading() -> String:
	return "BODIES"


func rows() -> Array[Dictionary]:
	var file := DevCheats.file_here(game)
	var out: Array[Dictionary] = [header("the land")]
	out.append(item(&"machines", "bodies come", ConfigChoices.show("rules.machines", GameConfig.value("rules.machines")),
		{"steps": true, "edited": GameConfig.edits.has("rules.machines")}))
	out.append(item(&"clear", "clear the land", "%d about" % _about()))
	out.append(item(&"file", "this region's file", "%s %d%%" % [String(file.level), roundi(float(file.value) * 100.0)], {"steps": true}))
	var machines := true
	out.append(header("machines"))
	for k in DevCheats.kinds():
		var machine := bool(Roster.row(k).get("machine", false))
		if machines and not machine:
			machines = false
			out.append(header("creatures"))
		out.append(item(k, String(k).replace("_", " ").replace(".", " "), str(Roster.row(k).get("role", ""))))
	return out


func _about() -> int:
	var n := 0
	for m: Node in game.get_tree().get_nodes_in_group(&"mobs"):
		if m.get("alive") == null or bool(m.get("alive")):
			n += 1
	return n


func confirm(row: Dictionary) -> void:
	match row.id:
		&"machines", &"file":
			side(row, 1)
		&"clear":
			DevCheats.clear_bodies(game)
			report("The land is clear.")
		_:
			if DevCheats.spawn(game, row.id):
				report("%s put down." % str(row.text))
			else:
				refuse("Nowhere in view to put one.")


func side(row: Dictionary, dir: int) -> void:
	match row.id:
		&"machines":
			GameConfig.set_value("rules.machines", not bool(GameConfig.value("rules.machines")))
		&"file":
			var lvl := Interference.LEVELS.find(DevCheats.file_here(game).level)
			DevCheats.set_file(game, posmod(lvl + dir, Interference.LEVELS.size()))
		_:
			return
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func keys(row: Dictionary) -> Array:
	if Roster.has(row.get("id", &"")):
		return [["e", "put one down"], ["esc", "back"]]
	return super(row)


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var id: StringName = screen.menu.selected().get("id", &"")
	var y := r.position.y + 8
	if id == &"file":
		y = panel_heading(ci, r, y, "the file", true)
		panel_wrapped(ci, r, y, "What this region's network makes of the player. Wary: workers look up. Hostile: they stop and come. Hunted: it sends hunters.")
		return
	if id == &"machines":
		y = panel_heading(ci, r, y, "bodies come")
		y = panel_wrapped(ci, r, y, str(ConfigSchema.row("rules.machines").note))
		panel_wrapped(ci, r, y, "An edit of the configuration: kept only if kept on its page.", UiTheme.MACHINE[3])
		return
	if not Roster.has(id):
		return
	var row := Roster.row(id)
	y = panel_heading(ci, r, y, String(id).replace("_", " "), bool(row.get("machine", false)))
	y = panel_pair(ci, r, y, "role", str(row.get("role", "-")))
	y = panel_pair(ci, r, y, "hostile", "yes" if bool(row.get("hostile", true)) else "no")
	y = panel_pair(ci, r, y, "health", str(Roster.health_of(id)))
	y = panel_pair(ci, r, y, "size", "%s tiles across" % str(float(row.get("radius", 0.5)) * 2.0))
	var where: Dictionary = row.get("where", {})
	if where.has("hours"):
		y = panel_pair(ci, r, y, "hours", "%s-%s" % [str(where.hours[0]), str(where.hours[1])])
	if where.has("countries"):
		var lands := PackedStringArray()
		for c: Variant in where.countries:
			lands.append(str(c))
		panel_wrapped(ci, r, y + 4, "lives in " + ", ".join(lands))
