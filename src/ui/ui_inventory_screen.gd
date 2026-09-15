class_name UiInventoryScreen
extends UiScreen
## The notebook's carrying page (Tab / I). Left: everything carried, grouped,
## with its bulk. Right: the chosen thing drawn large, three lines about it,
## and the load against the creel. E holds a tool (or puts it away) and eats
## food; anything else is refused with the reason.

var inventory: Inventory
var body: Body
var _scroll := 0


func _init() -> void:
	super()
	screen_name = &"inventory"
	own_action = &"inventory"


func refresh() -> void:
	if inventory == null and game != null:
		inventory = game.inventory
		body = game.body
	if inventory == null:
		return
	var rows := UiRules.inventory_rows(inventory)
	for row in rows:
		if row.has("header"):
			continue
		var id: StringName = row.id
		var g := UiRules.item_group(id)
		if g == &"tools" or g == &"found":
			row["enabled"] = true
		elif g == &"food":
			row["enabled"] = true
		else:
			row["enabled"] = false
			row["why"] = "That is for making things with." if g == &"goods" else "Nothing to do with that yet."
	menu.set_rows(rows)
	queue_redraw()


func _on_confirm(row: Dictionary) -> void:
	var id: StringName = row.id
	var g := UiRules.item_group(id)
	if g == &"tools" or g == &"found":
		Events.sfx.emit(&"menu_select", Vector3.ZERO)
		if inventory.held == id:
			inventory.set_held(&"")
			say("Put the %s away." % UiRules.item_name(id))
		else:
			inventory.set_held(id)
			say("The %s in hand." % UiRules.item_name(id))
	elif g == &"food":
		eat(id)
	refresh()


## Eat one. Survival's system does it when it offers `eat(id) -> bool`;
## until then the notebook feeds the body by the item's `feeds` hours.
func eat(id: StringName) -> void:
	if game != null:
		for s in game.systems:
			if s.has_method("eat"):
				if s.call("eat", id):
					Events.sfx.emit(&"menu_select", Vector3.ZERO)
					say("Ate the %s." % UiRules.item_name(id))
				return
	if not inventory.remove(id):
		return
	var now := game.clock.minutes if game != null else 0.0
	if body != null:
		body.fed_until = maxf(body.fed_until, now) + float(Items.def(id).get("feeds", 0.0)) * 60.0
	Events.sfx.emit(&"eat", Vector3.ZERO)
	say("Ate the %s." % UiRules.item_name(id))


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
	if menu.index >= 0:
		if menu.index < _scroll:
			_scroll = menu.index
		elif menu.index >= _scroll + lines:
			_scroll = menu.index - lines + 1
		# Keep a group's heading in view with its first row.
		if _scroll > 0 and menu.index == _scroll and menu.rows[_scroll - 1].has("header"):
			_scroll -= 1
	if menu.rows.is_empty():
		UiDraw.text(self, Vector2i(x0 + 6, UiNotebook.line_top(L, 0)), "nothing but the clothes you stand in", UiTheme.FADED)
	for n in mini(lines, menu.rows.size() - _scroll):
		var i := _scroll + n
		var row := menu.rows[i]
		var top := UiNotebook.line_top(L, n)
		if row.has("header"):
			# A heading is written small in the margin's shadow, with a short stroke under it.
			var h := String(row.header)
			UiDraw.text(self, Vector2i(x0 + 6, top), h, UiTheme.FADED)
			UiDraw.hand_hline(self, x0 + 5, x0 + 8 + UiFont.width(h), top + 9, UiTheme.FADED, i * 13)
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
		if inventory.held == id:
			UiDraw.hand_hline(self, x0 + 23, nx + 1, top + 9, UiTheme.ACCENT, i)
		UiDraw.text_right(self, right, top, _num(Items.bulk(id) * int(row.count)), UiTheme.INK_SOFT)
	if _scroll > 0:
		UiDraw.text_right(self, right, L.position.y + 22, "↑", UiTheme.FADED)
	if _scroll + lines < menu.rows.size():
		UiDraw.text_right(self, right, UiNotebook.line_top(L, lines), "↓", UiTheme.FADED)
	UiNotebook.footer(self, L, "e use     tab close     esc")
	_draw_detail(R)
	UiNotebook.note(self, R, note, note_age)


func _draw_detail(R: Rect2i) -> void:
	var x0 := R.position.x + 26
	var row := menu.selected()
	# The load, always: carried bulk against the creel, as a hand-ruled bar.
	var load := inventory.bulk()
	var cap := UiRules.creel(body) if body != null else UiRules.CREEL
	var ly := UiNotebook.rule_y(R, UiNotebook.rule_count(R) - 5)
	UiDraw.text(self, Vector2i(x0, ly - 8 - 11), "load", UiTheme.INK)
	UiDraw.text_right(self, R.end.x - 16, ly - 8 - 11, "%s of %s" % [_num(load), _num(cap)], UiTheme.INK_SOFT)
	var bar := Rect2i(x0, ly - 4, R.end.x - 16 - x0, 8)
	UiNotebook.box(self, bar, UiTheme.INK, 77)
	var fill := int((bar.size.x - 3) * clampf(load / (cap * 2.0), 0.0, 1.0))
	# Hatched fill: pencil strokes, not a solid meter.
	for i in range(0, fill, 2):
		UiDraw.vline(self, bar.position.x + 2 + i, bar.position.y + 2, bar.end.y - 3, UiTheme.INK_SOFT if load < cap else UiTheme.ACCENT)
	# The creel mark: past it, load starts to tell.
	var cx := bar.position.x + 1 + int((bar.size.x - 3) * 0.5)
	UiDraw.vline(self, cx, bar.position.y - 2, bar.end.y + 1, UiTheme.ACCENT)
	var held_name := UiRules.item_name(inventory.held) if inventory.held != &"" else "bare hands"
	UiDraw.text(self, Vector2i(x0, ly + 16), "in hand", UiTheme.INK)
	UiDraw.text_right(self, R.end.x - 16, ly + 16, held_name, UiTheme.INK_SOFT)

	if row.is_empty():
		return
	var id: StringName = row.id
	# A sketch of the thing, taped in.
	var box := Rect2i(x0, R.position.y + 16, 46, 46)
	UiDraw.rect(self, box.grow(-1), Color(UiTheme.PAPER_SHADE, 0.25))
	UiNotebook.box(self, box, UiTheme.INK_SOFT, 3)
	UiIcons.draw_item(self, id, box.position + Vector2i(5, 5), 4)
	UiNotebook.tape(self, Vector2i(box.position.x + 12, box.position.y - 3), 22)
	var tx := box.end.x + 10
	var d := Items.def(id)
	UiDraw.text(self, Vector2i(tx, R.position.y + 18), UiRules.item_name(id), UiTheme.INK)
	var lines := _detail_lines(id, int(row.count))
	for i in lines.size():
		UiDraw.text(self, Vector2i(tx, R.position.y + 31 + i * 11), lines[i], UiTheme.INK_SOFT)
	if d.get("tool", false):
		_draw_edge(Vector2i(tx, R.position.y + 31 + lines.size() * 11), inventory.edge(id))
	# A tool: what it works on in the world, by its verb.
	var verb := String(d.get("verb", ""))
	if verb != "":
		var names := PackedStringArray()
		for k: int in UiRules.PROP_VERBS:
			if UiRules.PROP_VERBS[k] == verb and not names.has(PropKind.NAMES[k]):
				names.append(PropKind.NAMES[k])
		if not names.is_empty():
			UiDraw.text(self, Vector2i(x0, UiNotebook.line_top(R, 6)), "works on", UiTheme.INK)
			_draw_wrapped(Vector2i(x0 + 6, UiNotebook.line_top(R, 7)), R.end.x - 16 - x0 - 6, ", ".join(names), UiTheme.INK_SOFT)
	# What it goes into: the recipes that want it, so goods are never a dead end.
	var demo: Array[Dictionary] = []
	if game != null and game.options.ui_demo:
		demo.assign(UiDemo.RECIPES)
	var uses := UiRules.recipes_using(id, UiRules.all_recipes(demo))
	if uses.is_empty():
		return
	var n0 := 6
	UiDraw.text(self, Vector2i(x0, UiNotebook.line_top(R, n0)), "goes into", UiTheme.INK)
	var shown := mini(uses.size(), 6)
	for i in shown:
		var r: Dictionary = uses[i]
		var out: StringName = (r.makes as Dictionary).keys()[0]
		var top := UiNotebook.line_top(R, n0 + 1 + i)
		UiIcons.draw_item(self, out, Vector2i(x0 + 6, top - 1))
		UiDraw.text(self, Vector2i(x0 + 19, top), UiRules.item_name(out), UiTheme.INK_SOFT)
		var want := int((r.needs as Dictionary)[id])
		UiDraw.text_right(self, R.end.x - 16, top, "%d at the %s" % [want, r.get("at", "")], UiTheme.FADED)
	if uses.size() > shown:
		UiDraw.text(self, Vector2i(x0 + 19, UiNotebook.line_top(R, n0 + 1 + shown)), "and %d more" % (uses.size() - shown), UiTheme.FADED)


func _detail_lines(id: StringName, count: int) -> PackedStringArray:
	var d := Items.def(id)
	var out := PackedStringArray()
	if d.get("tool", false):
		var verb := String(d.get("verb", ""))
		var stuff := String(d.get("stuff", ""))
		out.append(("%s · %s" % [verb, stuff]) if verb != "" else stuff)
	if float(d.get("feeds", 0.0)) > 0.0:
		out.append("feeds %s" % UiRules.duration(float(d.feeds) * 60.0))
	out.append("bulk %s%s" % [_num(Items.bulk(id)), " each" if count > 1 else ""])
	return out


## Words wrapped onto successive ruled lines.
func _draw_wrapped(at: Vector2i, width: int, text: String, col: Color) -> void:
	var line := ""
	var y := at.y
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if UiFont.width(next) > width and line != "":
			UiDraw.text(self, Vector2i(at.x, y), line, col)
			y += UiTheme.LINE
			line = word
		else:
			line = next
	if line != "":
		UiDraw.text(self, Vector2i(at.x, y), line, col)


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


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
