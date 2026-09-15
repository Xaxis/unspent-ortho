class_name UiInventoryScreen
extends UiScreen
## The carrying app (Tab / I). The list: everything carried, grouped, with its
## bulk. The replacement sub-panel: the chosen thing scanned, what it is, what
## it works on or goes into, and the load against the creel. E does the row's
## verb: hold a tool (or put it away), eat food, wear kit; goods are refused
## with the reason, since they are for making.

const SKETCH := 78
## The hardness ladder: a seam needs a tool of at least its rung.
const LADDER: Array[StringName] = [&"wood", &"iron", &"steel", &"crucible"]
const LIST_TOP := 50

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
	# Things can arrive or go while the app is open (a fire finishing, a theft).
	if inventory != null and not inventory.changed.is_connected(refresh):
		inventory.changed.connect(refresh)


func _on_close() -> void:
	if inventory != null and inventory.changed.is_connected(refresh):
		inventory.changed.disconnect(refresh)


## What E does to a row's thing: &"hold" &"eat" &"wear", or &"" (refused,
## with why_refused saying why in one plain sentence).
func verb_for(id: StringName) -> StringName:
	match UiRules.item_group(id):
		&"tools":
			return &"hold"
		&"found":
			return &"hold" if Items.def(id).get("tool", false) else &""
		&"food":
			return &"eat" if UiLink.can_eat(game, inventory) else &""
		&"to wear":
			return &"wear" if UiLink.can_wear(inventory) else &""
	return &""


static func why_refused(id: StringName) -> String:
	match UiRules.item_group(id):
		&"goods":
			return "That is for making things with."
		&"found":
			return "A found tool spends that; it is not held."
		&"food":
			return "Eating is not in the game yet."
	return "Nothing to do with that yet."


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
			row["why"] = why_refused(id)
	menu.set_rows(rows)
	queue_redraw()


func _on_confirm(row: Dictionary) -> void:
	var id: StringName = row.id
	var name := UiRules.bare_name(id)
	match row.get("verb", &""):
		&"hold":
			Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
			if inventory.held == id:
				UiLink.hold(game, inventory, &"")
				say("Put the %s away." % name)
			else:
				UiLink.hold(game, inventory, id)
				say("The %s in hand." % name)
		&"eat":
			if UiLink.eat(game, inventory, id):
				say("Ate the %s." % name)
			else:
				refuse("Not while your hands are full.")
		&"wear":
			Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
			if UiLink.worn(inventory) == id:
				UiLink.wear(inventory, &"")
				say("Took off the %s." % name)
			elif UiLink.wear(inventory, id):
				say("Wearing the %s." % name)
	refresh()


func _draw() -> void:
	draw_frame()
	var L := UiSlate.LIST
	UiSlate.title(self, L, "CARRYING")
	UiSlate.spare(self)
	if inventory == null:
		draw_keys([["esc", "back"]])
		return
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 8
	UiDraw.text_right(self, right, L.position.y + 4, "BULK", UiTheme.TEXT_DIM)
	var lines := UiSlate.line_count(LIST_TOP, L.end.y - 4)
	keep_in_view(lines)
	if menu.rows.is_empty():
		UiDraw.text(self, Vector2i(x0 + 6, LIST_TOP), "nothing but the clothes you stand in", UiTheme.TEXT_DIM)
	for n in mini(lines, menu.rows.size() - scroll):
		var i := scroll + n
		var row := menu.rows[i]
		var top := UiSlate.line_top(LIST_TOP, n)
		if row.has("header"):
			UiSlate.heading(self, Vector2i(x0, top), String(row.header), right)
			continue
		var id: StringName = row.id
		var chosen := i == menu.index
		var col := UiTheme.TEXT if UiMenu.enabled(row) or UiRules.item_group(id) == &"goods" else UiTheme.TEXT_DIM
		if chosen:
			UiSlate.row_bar(self, x0 - 4, right + 3, top)
			col = UiTheme.BRIGHT
		UiIcons.draw_item(self, id, Vector2i(x0 + 4, top - 1))
		var name := UiRules.list_name(id, int(row.count))
		UiDraw.text(self, Vector2i(x0 + 17, top), name, col)
		var nx := x0 + 17 + UiFont.width(name)
		if int(row.count) > 1:
			UiDraw.text(self, Vector2i(nx + 4, top), "×%d" % row.count, UiTheme.TEXT_DIM)
			nx += 5 + UiFont.width("×%d" % row.count)
		if inventory.held == id or UiLink.worn(inventory) == id:
			_tag(Vector2i(nx + 6, top), "HELD" if inventory.held == id else "WORN")
		UiDraw.text_right(self, right, top, UiRules.num(Items.bulk(id) * int(row.count)), UiTheme.TEXT_DIM)
	if scroll > 0:
		UiDraw.text_right(self, right, LIST_TOP - 11, "↑", UiTheme.TEXT_DIM)
	if scroll + lines < menu.rows.size():
		UiDraw.text_right(self, right, UiSlate.line_top(LIST_TOP, lines) - 2, "↓", UiTheme.TEXT_DIM)
	_draw_detail(UiSlate.SPARE)
	var verb: StringName = menu.selected().get("verb", &"")
	var keys: Array = []
	if verb != &"":
		keys.append(["e", "put away" if verb == &"hold" and inventory.held == menu.selected().get("id") else String(verb)])
	keys.append_array([["tab", "close"], ["esc", "back"]])
	draw_keys(keys)


## A small lit tag after a name: what is in hand or on the body.
func _tag(at: Vector2i, word: String) -> void:
	var w := UiFont.width(word) + 4
	UiDraw.rect(self, Rect2i(at.x, at.y - 1, w, 10), UiTheme.PHOSPHOR[1])
	UiDraw.text(self, Vector2i(at.x + 2, at.y - 1), word, UiTheme.GLASS_OFF)


func _draw_detail(R: Rect2i) -> void:
	var x0 := R.position.x + UiSlate.MARGIN_L
	var right := R.end.x - 12
	_draw_load(R, x0, right)
	var row := menu.selected()
	if row.is_empty():
		return
	var id: StringName = row.id
	var d := Items.def(id)
	var found := UiIcons.is_found(id)
	UiSlate.scan_box(self, Rect2i(x0, R.position.y + 8, 84, 84), id)
	var tx := x0 + 96
	UiDraw.text(self, Vector2i(tx, R.position.y + 10), UiRules.item_name(id), UiTheme.MACHINE[3] if found else UiTheme.BRIGHT)
	var facts := _facts(id, int(row.count))
	for i in facts.size():
		UiDraw.text(self, Vector2i(tx, R.position.y + 23 + i * 11), facts[i], UiTheme.MACHINE[2] if found else UiTheme.TEXT_DIM)
	if d.get("tool", false) and int(d.get("bite", 1)) > 0 and not d.get("stuff", &"") == &"found":
		_draw_edge(Vector2i(tx, R.position.y + 23 + facts.size() * 11), inventory.edge(id))
	var y := R.position.y + 114
	# A tool: what it works on in the world, by its verb.
	var verb := String(d.get("verb", ""))
	if verb != "":
		var names := PackedStringArray()
		for k: int in UiRules.PROP_VERBS:
			if UiRules.PROP_VERBS[k] == verb and not names.has(PropKind.NAMES[k]):
				names.append(PropKind.NAMES[k])
		if not names.is_empty():
			UiSlate.heading(self, Vector2i(x0, y), "works on", right)
			y += UiTheme.LINE * (1 + UiSlate.wrapped(self, Vector2i(x0 + 6, y + UiTheme.LINE), right - x0 - 6, ", ".join(names), UiTheme.TEXT)) + 4
	# A made tool's rung on the hardness ladder: what it can take.
	var stuff := StringName(d.get("stuff", &""))
	if LADDER.has(stuff):
		UiSlate.heading(self, Vector2i(x0, y), "hardness", right)
		_draw_ladder(Vector2i(x0 + 6, y + UiTheme.LINE + 1), stuff)
		y += UiTheme.LINE * 2 + 8
	# What it goes into: the recipes that want it, so goods are never a dead end.
	var demo: Array[Dictionary] = []
	if game != null and game.options.ui_demo:
		demo.assign(UiDemo.RECIPES)
	var uses := UiRules.recipes_using(id, UiRules.all_recipes(demo))
	var room := (R.position.y + 206 - y) / UiTheme.LINE - 1
	if uses.is_empty() or room < 1:
		return
	UiSlate.heading(self, Vector2i(x0, y), "goes into", right)
	var shown := mini(uses.size(), room)
	if uses.size() > room:
		shown = room - 1
	for i in shown:
		var r: Dictionary = uses[i]
		var top := y + UiTheme.LINE * (i + 1)
		var out := UiRules.recipe_output(r)
		UiIcons.draw_item(self, out, Vector2i(x0 + 6, top - 1))
		UiDraw.text(self, Vector2i(x0 + 19, top), UiRules.recipe_title(r), UiTheme.TEXT)
		var want := int((r.needs as Dictionary)[id])
		UiDraw.text_right(self, right, top, "%d, %s" % [want, UiRules.station_words(StringName(r.get("at", &"")))], UiTheme.TEXT_DIM)
	if uses.size() > shown:
		UiDraw.text(self, Vector2i(x0 + 19, y + UiTheme.LINE * (shown + 1)), "and %d more" % (uses.size() - shown), UiTheme.TEXT_DIM)


## The load, always: carried bulk against the creel as a segmented meter (its
## second half is past the creel, in the warning), and what is in hand and worn.
func _draw_load(R: Rect2i, x0: int, right: int) -> void:
	var load := inventory.bulk()
	var cap := UiLink.creel(inventory, body)
	var ly := R.end.y - 62
	UiDraw.hline(self, x0, right, ly - 6, UiTheme.GHOST)
	UiDraw.text(self, Vector2i(x0, ly), "LOAD", UiTheme.TEXT_DIM)
	UiDraw.text_right(self, right, ly, "%s of %s" % [UiRules.num(load), UiRules.num(cap)], UiTheme.WARN if load > cap else UiTheme.TEXT)
	var bar := Rect2i(x0, ly + 12, right - x0 + 1, 9)
	UiSlate.meter(self, bar, load / (cap * 2.0), 0.5)
	var creel_x := bar.position.x + bar.size.x / 2
	UiDraw.vline(self, creel_x, bar.position.y - 2, bar.end.y + 1, UiTheme.BRIGHT)
	UiDraw.text(self, Vector2i(creel_x - UiFont.width("creel") / 2, bar.end.y + 1), "creel", UiTheme.TEXT_DIM)
	var held_name := UiRules.item_name(inventory.held) if inventory.held != &"" else "bare hands"
	UiDraw.text(self, Vector2i(x0, ly + 36), "in hand", UiTheme.TEXT_DIM)
	UiDraw.text(self, Vector2i(x0 + 48, ly + 36), held_name, UiTheme.TEXT)
	if UiLink.can_wear(inventory):
		var w := UiLink.worn(inventory)
		UiDraw.text(self, Vector2i(x0 + 150, ly + 36), "worn", UiTheme.TEXT_DIM)
		UiDraw.text(self, Vector2i(x0 + 180, ly + 36), UiRules.item_name(w) if w != &"" else "nothing", UiTheme.TEXT)


func _facts(id: StringName, count: int) -> PackedStringArray:
	var d := Items.def(id)
	var out := PackedStringArray()
	if d.get("tool", false):
		var verb := String(d.get("verb", ""))
		var stuff := String(d.get("stuff", ""))
		if stuff == "found":
			out.append("found, not made")
			if int(d.get("wick", 0)) > 0:
				out.append("spends %d charge a swing" % int(d.wick))
		else:
			out.append(("%s · %s" % [verb, stuff]) if verb != "" else "%s, for a fight" % stuff)
	if float(d.get("feeds", 0.0)) > 0.0:
		out.append("feeds %s" % UiRules.duration(float(d.feeds) * 60.0))
	if d.has("kit"):
		out.append("worn: %s" % d.kit)
	out.append("bulk %s%s" % [UiRules.num(Items.bulk(id)), " each" if count > 1 else ""])
	return out


func _draw_ladder(at: Vector2i, stuff: StringName) -> void:
	var x := at.x
	for i in LADDER.size():
		var word := String(LADDER[i])
		var w := UiFont.width(word)
		var mine := LADDER[i] == stuff
		if mine:
			UiDraw.rect(self, Rect2i(x - 3, at.y - 2, w + 6, 12), UiTheme.GLASS_LIT)
			UiSlate.brackets(self, Rect2i(x - 3, at.y - 2, w + 6, 12), UiTheme.BRIGHT, 2)
		UiDraw.text(self, Vector2i(x, at.y), word, UiTheme.BRIGHT if mine else UiTheme.TEXT_DIM)
		x += w
		if i < LADDER.size() - 1:
			for k in 3:
				UiDraw.px(self, x + 8 + k * 3, at.y + 5, UiTheme.FAINT)
			x += 24


## The edge as notches: ten of them, worn ones hollow, the last two in the warning.
func _draw_edge(at: Vector2i, edge: int) -> void:
	UiDraw.text(self, at, "edge", UiTheme.TEXT_DIM)
	var x := at.x + UiFont.width("edge") + 5
	var full := roundi(edge / 1000.0)
	for i in 10:
		if i < full:
			UiDraw.rect(self, Rect2i(x + i * 4, at.y + 2, 3, 5), UiTheme.WARN if full <= 2 else UiTheme.TEXT)
		else:
			UiDraw.frame(self, Rect2i(x + i * 4, at.y + 2, 3, 5), UiTheme.FAINT)
