class_name UiInventoryScreen
extends UiScreen
## The carrying app (Tab / I). The list: everything carried, grouped, with its
## bulk. The replacement sub-panel: the chosen thing scanned, what it is, what
## it works on or goes into, and the load against the creel. E does the row's
## verb: hold a tool (or put it away), eat food, wear kit; goods are refused
## with the reason, since they are for making. X puts the row down on a heap
## the world keeps (Survival owns it) — the way an over-full creel is emptied.

## The scan window in the sub-panel, and the sketch inside it. The sketch's size
## is what the warm is keyed on, so it is DERIVED from the window rather than
## written twice (UiSlate.scan_size says what happens when those two drift).
const SCAN := 234
const SKETCH := SCAN - UiSlate.SCAN_INSET
## The hardness ladder: a seam needs a tool of at least its rung.
const LADDER: Array[StringName] = [&"wood", &"iron", &"steel", &"crucible"]
const LIST_TOP := UiSlate.LIST.position.y + 36
## Groups whose rows ask before they are put down: a tool, the lamp and worn
## kit are what a slip would cost you, and X sits beside C.
const DROP_ASKS: Array[StringName] = [&"tools", &"found", &"to wear"]
## How long an ask stands before X means "put it down" again rather than "yes".
const ASK_SECONDS := 4.0

var inventory: Inventory
var body: Body
## The row X has asked about, and when (real seconds).
var _asked: StringName = &""
var _asked_at := -1000.0


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


## X on the chosen row puts it down. Everything else is the menu standard.
func handle(action: StringName) -> bool:
	if is_open and action == &"drop":
		put_down()
		return true
	return super(action)


func _on_choice_changed() -> void:
	_asked = &""


## True while `id` is the row X has just asked about.
func asking(id: StringName) -> bool:
	return _asked == id and Time.get_ticks_msec() / 1000.0 - _asked_at <= ASK_SECONDS


static func drop_asks(id: StringName) -> bool:
	return DROP_ASKS.has(UiRules.item_group(id)) or id == &"lamp"


## Put the chosen row down (all of it) through survival, which lays the heap,
## refuses with a hostile close and says what was left. A tool, the lamp or
## worn kit is asked about first.
func put_down() -> void:
	var row := menu.selected()
	if row.is_empty() or not row.has("id") or inventory == null:
		return
	var id: StringName = row.id
	if drop_asks(id) and not asking(id):
		_asked = id
		_asked_at = Time.get_ticks_msec() / 1000.0
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		say("Put down the %s? X again." % UiRules.bare_name(id))
		note_warn = true
		queue_redraw()
		return
	_asked = &""
	if UiLink.drop(game, inventory, id, int(row.get("count", 1))) <= 0:
		# Survival said why on the message line, which the key strip is showing.
		Events.sfx.emit(&"ui_slate_deny", Vector3.ZERO)
		note_warn = true
	else:
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	refresh()


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
	var right := L.end.x - 16
	UiDraw.text_right(self, right, L.position.y + 8, "BULK", UiTheme.TEXT_DIM)
	var lines := UiSlate.line_count(LIST_TOP, L.end.y - 8)
	keep_in_view(lines)
	if menu.rows.is_empty():
		UiDraw.text(self, Vector2i(x0 + 12, LIST_TOP), "nothing but the clothes you stand in", UiTheme.TEXT_DIM)
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
			UiSlate.row_bar(self, x0 - 8, right + 6, top)
			col = UiTheme.BRIGHT
		UiIcons.draw_item(self, id, Vector2i(x0 + 8, top - 2))
		var name := UiRules.list_name(id, int(row.count))
		UiDraw.text(self, Vector2i(x0 + 34, top), name, col)
		var nx := x0 + 34 + UiFont.width(name)
		if int(row.count) > 1:
			UiDraw.text(self, Vector2i(nx + 8, top), "×%d" % row.count, UiTheme.TEXT_DIM)
			nx += 10 + UiFont.width("×%d" % row.count)
		if inventory.held == id or UiLink.worn(inventory) == id:
			_tag(Vector2i(nx + 12, top), "HELD" if inventory.held == id else "WORN")
		UiDraw.text_right(self, right, top, UiRules.num(Items.bulk(id) * int(row.count)), UiTheme.TEXT_DIM)
	if scroll > 0:
		UiDraw.text_right(self, right, LIST_TOP - UiTheme.LINE, "↑", UiTheme.TEXT_DIM)
	if scroll + lines < menu.rows.size():
		UiDraw.text_right(self, right, UiSlate.line_top(LIST_TOP, lines) - 4, "↓", UiTheme.TEXT_DIM)
	_draw_detail(UiSlate.SPARE)
	var chosen_row := menu.selected()
	var verb: StringName = chosen_row.get("verb", &"")
	var keys: Array = []
	if verb != &"":
		keys.append(["e", "put away" if verb == &"hold" and inventory.held == chosen_row.get("id") else String(verb)])
	if chosen_row.has("id"):
		var id: StringName = chosen_row.id
		# Every key label on the slate names the verb that key does. While the ask
		# is standing, X still puts the thing down: the note carries the question.
		keys.append(["x", "yes, put it down" if asking(id) else ("put down" if int(chosen_row.get("count", 1)) < 2 else "put down all")])
	keys.append_array([["tab", "close"], ["esc", "back"]])
	draw_keys(keys)


## A small lit tag after a name: what is in hand or on the body.
func _tag(at: Vector2i, word: String) -> void:
	var w := UiFont.width(word) + 8
	UiDraw.rect(self, Rect2i(at.x, at.y - 2, w, UiFont.SIZE), UiTheme.PHOSPHOR[1])
	UiDraw.text(self, Vector2i(at.x + 4, at.y - 2), word, UiTheme.GLASS_OFF)


func _draw_detail(R: Rect2i) -> void:
	var x0 := R.position.x + UiSlate.MARGIN_L
	var right := R.end.x - UiSlate.SPARE_INSET
	_draw_load(R, x0, right)
	var row := menu.selected()
	if row.is_empty():
		return
	var id: StringName = row.id
	var d := Items.def(id)
	var found := UiIcons.is_found(id)
	UiSlate.scan_box(self, Rect2i(x0, R.position.y + 16, SCAN, SCAN), id)
	var tx := x0 + 258
	UiDraw.text(self, Vector2i(tx, R.position.y + 20), UiRules.item_name(id), UiTheme.MACHINE[3] if found else UiTheme.BRIGHT)
	var facts := _facts(id, int(row.count))
	for i in facts.size():
		UiDraw.text(self, Vector2i(tx, R.position.y + 46 + i * UiTheme.LINE), facts[i], UiTheme.MACHINE[2] if found else UiTheme.TEXT_DIM)
	if d.get("tool", false) and int(d.get("bite", 1)) > 0 and not d.get("stuff", &"") == &"found":
		_draw_edge(Vector2i(tx, R.position.y + 46 + facts.size() * UiTheme.LINE), inventory.edge(id))
	var y := R.position.y + 286
	# A tool: what it works on in the world, by its verb.
	var verb := String(d.get("verb", ""))
	if verb != "":
		var names := PackedStringArray()
		for k: int in UiRules.PROP_VERBS:
			if UiRules.PROP_VERBS[k] == verb and not names.has(PropKind.NAMES[k]):
				names.append(PropKind.NAMES[k])
		if not names.is_empty():
			UiSlate.heading(self, Vector2i(x0, y), "works on", right)
			y += UiTheme.LINE * (1 + UiSlate.wrapped(self, Vector2i(x0 + 12, y + UiTheme.LINE), right - x0 - 12, ", ".join(names), UiTheme.TEXT)) + 8
	# A made tool's rung on the hardness ladder: what it can take.
	var stuff := StringName(d.get("stuff", &""))
	if LADDER.has(stuff):
		UiSlate.heading(self, Vector2i(x0, y), "hardness", right)
		_draw_ladder(Vector2i(x0 + 12, y + UiTheme.LINE + 2), stuff)
		y += UiTheme.LINE * 2 + 16
	# What it goes into: the recipes that want it, so goods are never a dead end.
	var demo: Array[Dictionary] = []
	if game != null and game.options.ui_demo:
		demo.assign(UiDemo.RECIPES)
	var uses := UiRules.recipes_using(id, UiRules.all_recipes(demo))
	var room := (R.end.y - 140 - y) / UiTheme.LINE - 1
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
		UiIcons.draw_item(self, out, Vector2i(x0 + 12, top - 2))
		UiDraw.text(self, Vector2i(x0 + 38, top), UiRules.recipe_title(r), UiTheme.TEXT)
		var want := int((r.needs as Dictionary)[id])
		UiDraw.text_right(self, right, top, "%d, %s" % [want, UiRules.station_words(StringName(r.get("at", &"")))], UiTheme.TEXT_DIM)
	if uses.size() > shown:
		UiDraw.text(self, Vector2i(x0 + 38, y + UiTheme.LINE * (shown + 1)), "and %d more" % (uses.size() - shown), UiTheme.TEXT_DIM)


## The load, always: carried bulk against the creel as a segmented meter (its
## second half is past the creel, in the warning), and what is in hand and worn.
func _draw_load(R: Rect2i, x0: int, right: int) -> void:
	var load := inventory.bulk()
	var cap := UiLink.creel(inventory, body)
	var ly := R.end.y - 124
	UiDraw.hline(self, x0, right, ly - 12, UiTheme.GHOST)
	UiDraw.text(self, Vector2i(x0, ly), "LOAD", UiTheme.TEXT_DIM)
	UiDraw.text_right(self, right, ly, "%s of %s" % [UiRules.num(load), UiRules.num(cap)], UiTheme.WARN if load > cap else UiTheme.TEXT)
	var bar := Rect2i(x0, ly + 24, right - x0 + 1, 18)
	UiSlate.meter(self, bar, load / (cap * 2.0), 0.5)
	var creel_x := bar.position.x + bar.size.x / 2
	UiDraw.rect(self, Rect2i(creel_x, bar.position.y - 4, 2, bar.size.y + 8), UiTheme.BRIGHT)
	UiDraw.text(self, Vector2i(creel_x - UiFont.width("creel") / 2, bar.end.y + 2), "creel", UiTheme.TEXT_DIM)
	var held_name := UiRules.item_name(inventory.held) if inventory.held != &"" else "bare hands"
	UiDraw.text(self, Vector2i(x0, ly + 72), "in hand", UiTheme.TEXT_DIM)
	UiDraw.text(self, Vector2i(x0 + 96, ly + 72), held_name, UiTheme.TEXT)
	if UiLink.can_wear(inventory):
		var w := UiLink.worn(inventory)
		UiDraw.text(self, Vector2i(x0 + 300, ly + 72), "worn", UiTheme.TEXT_DIM)
		UiDraw.text(self, Vector2i(x0 + 360, ly + 72), UiRules.item_name(w) if w != &"" else "nothing", UiTheme.TEXT)


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
			UiDraw.rect(self, Rect2i(x - 6, at.y - 4, w + 12, UiTheme.LINE + 2), UiTheme.GLASS_LIT)
			UiSlate.brackets(self, Rect2i(x - 6, at.y - 4, w + 12, UiTheme.LINE + 2), UiTheme.BRIGHT, 6)
		UiDraw.text(self, Vector2i(x, at.y), word, UiTheme.BRIGHT if mine else UiTheme.TEXT_DIM)
		x += w
		if i < LADDER.size() - 1:
			for k in 3:
				UiDraw.px(self, x + 16 + k * 6, at.y + 10, UiTheme.FAINT)
			x += 48


## The edge as notches: ten of them, worn ones hollow, the last two in the warning.
func _draw_edge(at: Vector2i, edge: int) -> void:
	UiDraw.text(self, at, "edge", UiTheme.TEXT_DIM)
	var x := at.x + UiFont.width("edge") + 10
	var full := roundi(edge / 1000.0)
	for i in 10:
		# A notch and the clear pixel after it: at a pitch of 8 they touched, and
		# ten of them read as one bar rather than as an edge with ten notches left.
		if i < full:
			UiDraw.rect(self, Rect2i(x + i * 10, at.y + 4, 6, 12), UiTheme.WARN if full <= 2 else UiTheme.TEXT)
		else:
			UiDraw.frame(self, Rect2i(x + i * 10, at.y + 4, 6, 12), UiTheme.FAINT)
