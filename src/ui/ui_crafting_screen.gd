class_name UiCraftingScreen
extends UiScreen
## The making page (C). Left: what can be made where the player stands, under
## a heading per station in reach ("at the fire") and "by hand"; rows that
## cannot be made now are faded but choosable, and say why. Right: the chosen
## recipe sketched, a printed slip of what it wants against what is carried,
## and the station it is made at. E makes it through UiLink (Crafting's own
## make_in when survival provides it, which charges the clock and builds).

## Stations in reach, nearest first, &"hand" last; set by whoever opens the page.
var stations: Array[StringName] = [&"fire"]
var inventory: Inventory
## Recipes source for tests and demo shots; empty = Crafting.recipes_at.
var recipes_override: Array[Dictionary] = []


func _init() -> void:
	super()
	screen_name = &"crafting"
	own_action = &"craft"


func _on_open() -> void:
	scroll = 0
	var outs: Array[StringName] = []
	for r in recipes():
		var out := UiRules.recipe_output(r)
		if out != &"" and not outs.has(out):
			outs.append(out)
	UiSketch.warm(outs, UiInventoryScreen.SKETCH, stations)


## The recipes on the page, in the order drawn.
func recipes() -> Array[Dictionary]:
	if not recipes_override.is_empty():
		return recipes_override
	var list: Array[Dictionary] = []
	for st in _ordered_stations():
		var here := Crafting.recipes_at(st)
		if here.is_empty() and game != null and game.options.ui_demo:
			here = UiDemo.recipes_at(st)
		list.append_array(here)
	return list


## Stations first (nearest first), then by hand.
func _ordered_stations() -> Array[StringName]:
	var out: Array[StringName] = []
	for st in stations:
		if st != &"hand":
			out.append(st)
	if stations.has(&"hand"):
		out.append(&"hand")
	return out


func refresh() -> void:
	if inventory == null and game != null:
		inventory = game.inventory
	if inventory == null:
		return
	if game != null and recipes_override.is_empty():
		var here := UiLink.stations_here(game)
		if not here.is_empty():
			stations = here
	var list := recipes()
	var rows: Array[Dictionary] = []
	var group: Array[Dictionary] = []
	for i in list.size():
		var r := list[i]
		var why := UiLink.why_not(game, inventory, r)
		group.append({"id": r.get("id", &""), "recipe": r, "enabled": why == "", "why": why, "title": UiRules.recipe_title(r, list)})
		var at := StringName(r.get("at", &""))
		if i + 1 < list.size() and StringName(list[i + 1].get("at", &"")) == at:
			continue
		# A station's recipes that can be made now come first; the rest keep their order.
		if recipes_override.is_empty():
			rows.append({"header": UiRules.station_words(at)})
		var ready := group.filter(func(row: Dictionary) -> bool: return row.enabled)
		rows.append_array(ready)
		rows.append_array(group.filter(func(row: Dictionary) -> bool: return not row.enabled))
		group.clear()
	menu.set_rows(rows)
	queue_redraw()


func _on_confirm(row: Dictionary) -> void:
	var r: Dictionary = row.recipe
	var why := UiLink.why_not(game, inventory, r)
	if why != "":
		refuse(why)
		return
	if not UiLink.make(game, inventory, r):
		refuse("It did not come right.")
		return
	Events.sfx.emit(&"menu_select", Vector3.ZERO)
	var builds := StringName(r.get("builds", &""))
	if builds != &"":
		say("Built a %s." % builds)
	elif r.get("action", &"") != &"":
		say("It bites again.")
	else:
		say("Made %s." % UiRules.recipe_title(r))
	refresh()


func _draw() -> void:
	UiNotebook.spread(self, 23)
	var L := UiNotebook.LEFT
	var R := UiNotebook.RIGHT
	UiNotebook.title(self, L, "making", 9)
	if inventory == null:
		return
	var x0 := L.position.x + UiNotebook.MARGIN_X
	var right := L.end.x - 10
	UiDraw.text_right(self, right, L.position.y + 11, "takes", UiTheme.FADED)
	if menu.rows.is_empty():
		UiDraw.text(self, Vector2i(x0 + 6, UiNotebook.line_top(L, 0)), "nothing to make here yet", UiTheme.FADED)
	var lines := UiNotebook.rule_count(L) - 2
	keep_in_view(lines)
	for n in mini(lines, menu.rows.size() - scroll):
		var i := scroll + n
		var row := menu.rows[i]
		var top := UiNotebook.line_top(L, n)
		if row.has("header"):
			UiNotebook.heading(self, Vector2i(x0 + 6, top), String(row.header), i * 7)
			continue
		var r: Dictionary = row.recipe
		var ok := UiMenu.enabled(row)
		if i == menu.index:
			UiNotebook.cursor(self, x0 + 4, top)
		_draw_row_icon(r, Vector2i(x0 + 11, top - 1))
		UiDraw.text(self, Vector2i(x0 + 24, top), String(row.title), UiTheme.INK if ok else UiTheme.FADED)
		UiDraw.text_right(self, right, top, UiRules.duration(float(r.get("minutes", 0.0))), UiTheme.INK_SOFT if ok else UiTheme.FADED)
	if scroll > 0:
		UiDraw.text_right(self, right, L.position.y + 22, "↑", UiTheme.FADED)
	if scroll + lines < menu.rows.size():
		UiDraw.text_right(self, right, UiNotebook.line_top(L, lines), "↓", UiTheme.FADED)
	UiNotebook.footer(self, L, "e make     c close     esc")
	_draw_recipe(R)
	UiNotebook.note(self, R, note, note_age)


func _draw_row_icon(r: Dictionary, at: Vector2i) -> void:
	var out := UiRules.recipe_output(r)
	if out != &"":
		UiIcons.draw_item(self, out, at)
	elif r.get("action", &"") != &"":
		UiIcons.draw_item(self, &"hone", at)
	else:
		UiIcons.draw_station_mark(self, StringName(r.get("builds", &"fire")), at)


func _draw_recipe(R: Rect2i) -> void:
	var row := menu.selected()
	if row.is_empty():
		return
	var r: Dictionary = row.recipe
	var x0 := R.position.x + 26
	var at := StringName(r.get("at", &""))
	var box := Rect2i(x0, R.position.y + 14, 84, 84)
	var out := UiRules.recipe_output(r)
	if out != &"":
		UiNotebook.sketch_box(self, box, out, 13)
	else:
		UiDraw.rect(self, box.grow(-1), Color(UiTheme.PAPER_SHADE, 0.22))
		UiNotebook.box(self, box, UiTheme.INK_SOFT, 13)
		var built := StringName(r.get("builds", &""))
		if built != &"":
			UiSketch.draw_station(self, built, box.position + Vector2i(3, 22), 78)
		else:
			UiSketch.draw_item(self, &"hone", box.position + Vector2i(3, 3), 78)
		UiNotebook.tape(self, Vector2i(box.position.x + 30, box.position.y - 3), 24)
	var tx := box.end.x + 12
	UiDraw.text(self, Vector2i(tx, R.position.y + 18), String(row.title), UiTheme.INK)
	UiDraw.text(self, Vector2i(tx, R.position.y + 31), UiRules.station_words(at), UiTheme.INK_SOFT)
	var minutes := float(r.get("minutes", 0.0))
	var takes := "takes %s" % UiRules.duration(minutes)
	if game != null:
		takes += ", done %s" % UiRules.clock_at(game.clock.minutes + minutes, game.clock.minutes)
	UiDraw.text(self, Vector2i(tx, R.position.y + 42), takes, UiTheme.INK_SOFT)
	var slip_bottom := _draw_slip(Rect2i(R.position.x + 16, R.position.y + 112, R.size.x - 34, 0), r, row)
	# Where it is made, sketched at the foot of the page, if there is room.
	var sk := UiSketch.station_size(96)
	var sk_at := Vector2i(R.position.x + 34, R.end.y - 34 - sk.y)
	if sk_at.y > slip_bottom + 10:
		UiSketch.draw_station(self, at if at != &"" else &"hand", sk_at, 96)
		var caption := "made by hand, anywhere" if at == &"hand" else "the %s" % at
		UiDraw.text(self, Vector2i(sk_at.x + sk.x + 10, sk_at.y + sk.y - 18), caption, UiTheme.FADED)
		UiDraw.hand_hline(self, sk_at.x - 6, sk_at.x + sk.x + 4, sk_at.y + sk.y + 2, UiTheme.INK_SOFT, 71)


## The recipe as a printed slip pasted into the notebook: the one strict,
## institutional surface here, with a heavy grid, thick rules and capital
## labels. Returns the slip's bottom y.
func _draw_slip(at: Rect2i, r: Dictionary, row: Dictionary) -> int:
	var lines: Array[Dictionary] = []
	var needs: Dictionary = r.get("needs", {})
	for id: StringName in needs:
		lines.append({"id": id, "want": int(needs[id]), "have": inventory.count(id)})
	var keeps: Dictionary = r.get("keeps", {})
	for id: StringName in keeps:
		lines.append({"id": id, "want": int(keeps[id]), "have": inventory.count(id), "kept": true})
	var tool := StringName(r.get("tool", &""))
	if tool != &"":
		lines.append({"tool": tool, "want": 1, "have": 1 if _carries_verb(tool) else 0})
	const HEAD := 26
	const ROW := 15
	var h := HEAD + ROW * maxi(1, lines.size()) + 20
	var s := Rect2i(at.position.x, at.position.y, at.size.x, h)
	UiDraw.rect(self, Rect2i(s.position.x + 2, s.position.y + 2, s.size.x, s.size.y), Color(UiTheme.INK_DEEP, 0.16))
	UiDraw.rect(self, s, UiTheme.SLIP)
	UiDraw.frame(self, s, UiTheme.INK)
	UiDraw.frame(self, s.grow(-2), UiTheme.INK)
	UiDraw.rect(self, Rect2i(s.position.x + 2, s.position.y + 2, s.size.x - 4, 12), UiTheme.INK)
	UiDraw.text(self, Vector2i(s.position.x + 6, s.position.y + 3), "MATERIALS FOR ONE MAKING", UiTheme.SLIP)
	var no := "No. %03d" % (absi(hash(String(r.get("id", "")))) % 1000)
	UiDraw.text_right(self, s.end.x - 6, s.position.y + 3, no, UiTheme.SLIP)
	var col_have := s.end.x - 12
	var col_want := col_have - 36
	var x0 := s.position.x + 8
	var y := s.position.y + HEAD - 10
	UiDraw.text(self, Vector2i(x0 + 13, y), "ITEM", UiTheme.INK_SOFT)
	UiDraw.text_right(self, col_want, y, "WANT", UiTheme.INK_SOFT)
	UiDraw.text_right(self, col_have, y, "HAVE", UiTheme.INK_SOFT)
	y = s.position.y + HEAD
	UiDraw.hline(self, s.position.x + 2, s.end.x - 3, y - 1, UiTheme.INK)
	UiDraw.hline(self, s.position.x + 2, s.end.x - 3, y, UiTheme.INK)
	var sep_want := col_want - UiFont.width("WANT") - 5
	var sep_have := col_want + 5
	if lines.is_empty():
		UiDraw.text(self, Vector2i(x0 + 13, y + 3), "NOTHING", UiTheme.INK_SOFT)
		y += ROW
		UiDraw.hline(self, s.position.x + 2, s.end.x - 3, y, UiTheme.INK_SOFT)
	for l in lines:
		var want: int = l.want
		var have: int = l.have
		var short := have < want
		var label := ""
		if l.has("tool"):
			label = "SOMETHING TO %s WITH" % String(l.tool).to_upper()
			UiIcons.draw_item(self, &"knife", Vector2i(x0, y + 3))
		else:
			UiIcons.draw_item(self, l.id, Vector2i(x0, y + 3))
			label = UiRules.bare_name(l.id) + (", KEPT" if l.has("kept") else "")
		UiDraw.text(self, Vector2i(x0 + 13, y + 3), label, UiTheme.INK)
		UiDraw.text_right(self, col_want, y + 3, str(want) if not l.has("tool") else "-", UiTheme.INK)
		var have_text := str(have) if not l.has("tool") else ("YES" if have > 0 else "NO")
		UiDraw.text_right(self, col_have, y + 3, have_text, UiTheme.ACCENT if short else UiTheme.INK)
		if short:
			# The shortfall ringed in the one accent, by hand, over the print.
			var w := UiFont.width(have_text)
			UiNotebook.box(self, Rect2i(col_have - w - 4, y + 1, w + 7, 12), UiTheme.ACCENT, have * 7 + want)
		y += ROW
		UiDraw.hline(self, s.position.x + 2, s.end.x - 3, y, UiTheme.INK_SOFT)
	UiDraw.vline(self, sep_want, s.position.y + HEAD - 12, y, UiTheme.INK_SOFT)
	UiDraw.vline(self, sep_have, s.position.y + HEAD - 12, y, UiTheme.INK_SOFT)
	var ok := UiMenu.enabled(row)
	var verdict := "ALL IN HAND" if ok else String(row.get("why", "")).to_upper().trim_suffix(".")
	UiDraw.text(self, Vector2i(x0, y + 5), verdict, UiTheme.INK if ok else UiTheme.ACCENT)
	UiNotebook.tape(self, Vector2i(s.position.x - 6, s.position.y - 3), 24)
	UiNotebook.tape(self, Vector2i(s.end.x - 18, s.position.y - 3), 24)
	return s.end.y


func _carries_verb(verb: StringName) -> bool:
	for id: StringName in inventory.items:
		if Items.def(id).get("verb", &"") == verb:
			return true
	return false
