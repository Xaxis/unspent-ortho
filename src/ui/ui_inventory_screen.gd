class_name UiInventoryScreen
extends UiScreen
## The notebook's carrying page (Tab / I). Left: everything carried, grouped,
## with its bulk. Right: the chosen thing sketched, what it is, what it works
## on or goes into, and the load against the creel. E does the row's verb:
## hold a tool (or put it away), eat food, wear kit; goods are refused with the
## reason, since they are for making.

const SKETCH := 78

var inventory: Inventory
var body: Body


func _init() -> void:
	super()
	screen_name = &"inventory"
	own_action = &"inventory"


func _on_open() -> void:
	if inventory == null and game != null:
		inventory = game.inventory
		body = game.body
	scroll = 0
	if inventory != null:
		var ids: Array[StringName] = []
		ids.assign(inventory.items.keys())
		UiSketch.warm(ids, SKETCH)
	# Things can arrive or go while the page is open (a fire finishing, a theft).
	if inventory != null and not inventory.changed.is_connected(refresh):
		inventory.changed.connect(refresh)


func _on_close() -> void:
	if inventory != null and inventory.changed.is_connected(refresh):
		inventory.changed.disconnect(refresh)


## What E does to a row's thing: &"hold" &"eat" &"wear", or &"" (refused).
func verb_for(id: StringName) -> StringName:
	match UiRules.item_group(id):
		&"tools", &"found":
			return &"hold"
		&"food":
			return &"eat"
		&"to wear":
			return &"wear" if UiLink.can_wear(inventory) else &""
	return &""


func refresh() -> void:
	if inventory == null:
		return
	var rows := UiRules.inventory_rows(inventory)
	for row in rows:
		if row.has("header"):
			continue
		var id: StringName = row.id
		var v := verb_for(id)
		row["verb"] = v
		row["enabled"] = v != &""
		if v == &"":
			row["why"] = "That is for making things with." if UiRules.item_group(id) == &"goods" else "Nothing to do with that yet."
	menu.set_rows(rows)
	queue_redraw()


func _on_confirm(row: Dictionary) -> void:
	var id: StringName = row.id
	var name := UiRules.item_name(id)
	match row.get("verb", &""):
		&"hold":
			Events.sfx.emit(&"menu_select", Vector3.ZERO)
			if inventory.held == id:
				UiLink.hold(game, inventory, &"")
				say("Put the %s away." % name)
			else:
				UiLink.hold(game, inventory, id)
				say("The %s in hand." % name)
		&"eat":
			if UiLink.eat(game, inventory, body, id):
				say("Ate the %s." % name)
			else:
				refuse("Not while your hands are full.")
		&"wear":
			Events.sfx.emit(&"menu_select", Vector3.ZERO)
			if UiLink.worn(inventory) == id:
				UiLink.wear(inventory, &"")
				say("Took off the %s." % name)
			elif UiLink.wear(inventory, id):
				say("Wearing the %s." % name)
	refresh()


func _draw() -> void:
	UiNotebook.spread(self, 11)
	var L := UiNotebook.LEFT
	var R := UiNotebook.RIGHT
	UiNotebook.title(self, L, "carrying", 5, "bag")
	if inventory == null:
		return
	var x0 := L.position.x + UiNotebook.MARGIN_X
	var right := L.end.x - 10
	UiDraw.text_right(self, right, L.position.y + 11, "bulk", UiTheme.FADED)
	var lines := UiNotebook.rule_count(L) - 2
	keep_in_view(lines)
	if menu.rows.is_empty():
		UiDraw.text(self, Vector2i(x0 + 6, UiNotebook.line_top(L, 0)), "nothing but the clothes you stand in", UiTheme.FADED)
	for n in mini(lines, menu.rows.size() - scroll):
		var i := scroll + n
		var row := menu.rows[i]
		var top := UiNotebook.line_top(L, n)
		if row.has("header"):
			UiNotebook.heading(self, Vector2i(x0 + 6, top), String(row.header), i * 13)
			continue
		var id: StringName = row.id
		var col := UiTheme.INK if UiMenu.enabled(row) or UiRules.item_group(id) == &"goods" else UiTheme.FADED
		if i == menu.index:
			UiNotebook.cursor(self, x0 + 4, top)
		UiIcons.draw_item(self, id, Vector2i(x0 + 11, top - 1))
		var name := UiRules.item_name(id)
		UiDraw.text(self, Vector2i(x0 + 24, top), name, col)
		var nx := x0 + 24 + UiFont.width(name)
		if int(row.count) > 1:
			UiDraw.text(self, Vector2i(nx + 4, top), "×%d" % row.count, UiTheme.INK_SOFT)
		if inventory.held == id or UiLink.worn(inventory) == id:
			# In hand or on the body: underlined in the accent, the way you mark what matters.
			UiDraw.hand_hline(self, x0 + 23, nx + 1, top + 9, UiTheme.ACCENT, i)
		UiDraw.text_right(self, right, top, UiRules.num(Items.bulk(id) * int(row.count)), UiTheme.INK_SOFT)
	if scroll > 0:
		UiDraw.text_right(self, right, L.position.y + 22, "↑", UiTheme.FADED)
	if scroll + lines < menu.rows.size():
		UiDraw.text_right(self, right, UiNotebook.line_top(L, lines), "↓", UiTheme.FADED)
	var verb: StringName = menu.selected().get("verb", &"")
	var does := "e %s" % ("put away" if verb == &"hold" and inventory.held == menu.selected().get("id") else String(verb)) if verb != &"" else ""
	UiNotebook.footer(self, L, "%s%stab close     esc" % [does, "     " if does != "" else ""])
	_draw_detail(R)
	UiNotebook.note(self, R, note, note_age)


func _draw_detail(R: Rect2i) -> void:
	var x0 := R.position.x + 26
	var right := R.end.x - 16
	_draw_load(R, x0, right)
	var row := menu.selected()
	if row.is_empty():
		return
	var id: StringName = row.id
	var d := Items.def(id)
	UiNotebook.sketch_box(self, Rect2i(x0, R.position.y + 14, 84, 84), id, 3)
	var tx := x0 + 96
	UiDraw.text(self, Vector2i(tx, R.position.y + 18), UiRules.item_name(id), UiTheme.INK)
	var facts := _facts(id, int(row.count))
	for i in facts.size():
		UiDraw.text(self, Vector2i(tx, R.position.y + 31 + i * 11), facts[i], UiTheme.INK_SOFT)
	if d.get("tool", false) and int(d.get("bite", 1)) > 0 and not d.get("stuff", &"") == &"found":
		_draw_edge(Vector2i(tx, R.position.y + 31 + facts.size() * 11), inventory.edge(id))
	var n := 7
	# A tool: what it works on in the world, by its verb.
	var verb := String(d.get("verb", ""))
	if verb != "":
		var names := PackedStringArray()
		for k: int in UiRules.PROP_VERBS:
			if UiRules.PROP_VERBS[k] == verb and not names.has(PropKind.NAMES[k]):
				names.append(PropKind.NAMES[k])
		if not names.is_empty():
			UiDraw.text(self, Vector2i(x0, UiNotebook.line_top(R, n)), "works on", UiTheme.INK)
			n += 1 + UiNotebook.wrapped(self, Vector2i(x0 + 6, UiNotebook.line_top(R, n + 1)), right - x0 - 6, ", ".join(names), UiTheme.INK_SOFT)
	# What it goes into: the recipes that want it, so goods are never a dead end.
	var demo: Array[Dictionary] = []
	if game != null and game.options.ui_demo:
		demo.assign(UiDemo.RECIPES)
	var uses := UiRules.recipes_using(id, UiRules.all_recipes(demo))
	if uses.is_empty() or n > 12:
		return
	UiDraw.text(self, Vector2i(x0, UiNotebook.line_top(R, n)), "goes into", UiTheme.INK)
	var room := 17 - n
	var shown := mini(uses.size(), room)
	if uses.size() > room:
		shown = room - 1
	for i in shown:
		var r: Dictionary = uses[i]
		var top := UiNotebook.line_top(R, n + 1 + i)
		var out := UiRules.recipe_output(r)
		UiIcons.draw_item(self, out, Vector2i(x0 + 6, top - 1))
		UiDraw.text(self, Vector2i(x0 + 19, top), UiRules.recipe_title(r), UiTheme.INK_SOFT)
		var want := int((r.needs as Dictionary)[id])
		UiDraw.text_right(self, right, top, "%d, %s" % [want, UiRules.station_words(StringName(r.get("at", &"")))], UiTheme.FADED)
	if uses.size() > shown:
		UiDraw.text(self, Vector2i(x0 + 19, UiNotebook.line_top(R, n + 1 + shown)), "and %d more" % (uses.size() - shown), UiTheme.FADED)


## The load, always: carried bulk against the creel as a hatched bar, and what
## is in hand and worn.
func _draw_load(R: Rect2i, x0: int, right: int) -> void:
	var load := inventory.bulk()
	var cap := UiLink.creel(inventory, body)
	var ly := UiNotebook.rule_y(R, UiNotebook.rule_count(R) - 4)
	UiDraw.text(self, Vector2i(x0, ly - 19), "load", UiTheme.INK)
	UiDraw.text_right(self, right, ly - 19, "%s of %s" % [UiRules.num(load), UiRules.num(cap)], UiTheme.ACCENT if load > cap else UiTheme.INK_SOFT)
	var bar := Rect2i(x0, ly - 5, right - x0, 9)
	UiNotebook.box(self, bar, UiTheme.INK, 77)
	var span := bar.size.x - 4
	var fill := int(span * clampf(load / (cap * 2.0), 0.0, 1.0))
	# Pencil strokes, not a solid meter; past the creel they go to the accent.
	var creel_x := bar.position.x + 2 + span / 2
	for i in range(0, fill, 2):
		var x := bar.position.x + 2 + i
		UiDraw.vline(self, x, bar.position.y + 2, bar.end.y - 3, UiTheme.INK_SOFT if x < creel_x else UiTheme.ACCENT)
	UiDraw.vline(self, creel_x, bar.position.y - 2, bar.end.y + 1, UiTheme.ACCENT)
	UiDraw.text(self, Vector2i(creel_x - UiFont.width("creel") / 2, bar.end.y + 2), "creel", UiTheme.FADED)
	var held_name := UiRules.item_name(inventory.held) if inventory.held != &"" else "bare hands"
	UiDraw.text(self, Vector2i(x0, ly + 20), "in hand", UiTheme.INK)
	UiDraw.text_right(self, right, ly + 20, held_name, UiTheme.INK_SOFT)
	if UiLink.can_wear(inventory):
		var w := UiLink.worn(inventory)
		UiDraw.text(self, Vector2i(x0, ly + 31), "worn", UiTheme.INK)
		UiDraw.text_right(self, right, ly + 31, UiRules.item_name(w) if w != &"" else "nothing", UiTheme.INK_SOFT)


func _facts(id: StringName, count: int) -> PackedStringArray:
	var d := Items.def(id)
	var out := PackedStringArray()
	if d.get("tool", false):
		var verb := String(d.get("verb", ""))
		var stuff := String(d.get("stuff", ""))
		if stuff == "found":
			out.append("found, not made")
		else:
			out.append(("%s · %s" % [verb, stuff]) if verb != "" else "%s, for a fight" % stuff)
	if float(d.get("feeds", 0.0)) > 0.0:
		out.append("feeds %s" % UiRules.duration(float(d.feeds) * 60.0))
	if d.has("kit"):
		out.append("worn: %s" % d.kit)
	out.append("bulk %s%s" % [UiRules.num(Items.bulk(id)), " each" if count > 1 else ""])
	return out


## The edge as notches: ten of them, worn ones left hollow.
func _draw_edge(at: Vector2i, edge: int) -> void:
	UiDraw.text(self, at, "edge", UiTheme.INK_SOFT)
	var x := at.x + UiFont.width("edge") + 5
	var full := roundi(edge / 1000.0)
	for i in 10:
		if i < full:
			UiDraw.rect(self, Rect2i(x + i * 4, at.y + 2, 3, 5), UiTheme.INK_SOFT)
		else:
			UiDraw.frame(self, Rect2i(x + i * 4, at.y + 2, 3, 5), UiTheme.FADED)
