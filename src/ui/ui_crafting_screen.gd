class_name UiCraftingScreen
extends UiScreen
## The making app (C). The list: what can be made where the player stands,
## under a heading per station in reach ("at the fire") and "by hand"; rows
## that cannot be made now are dim but choosable, and say why; under it, what
## is already cooking at the stations round you and when it comes off. The
## replacement sub-panel: the chosen recipe scanned, a table of what it wants
## against what is carried, and the station it is made at — and for long work,
## that it is set going and walked away from, not stood over. E makes it
## through UiLink (Crafting's own make_in when survival provides it, which
## charges the clock and builds).

const LIST_TOP := 50
## Jobs listed under the recipes before the rest are counted.
const COOK_ROWS := 3

## Stations in reach, nearest first, &"hand" last; set by whoever opens the app.
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


## The recipes in the app, in the order drawn.
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
	Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	var builds := StringName(r.get("builds", &""))
	if builds != &"":
		say("Built a %s." % builds)
	elif r.get("action", &"") != &"":
		say("It bites again.")
	elif not Crafting.sets_going(r):
		say("Made %s." % UiRules.recipe_title(r))
	# Long work is not made, it is left going: survival's own line says where and
	# until when, and it is already on the strip.
	refresh()


func _draw() -> void:
	draw_frame()
	var L := UiSlate.LIST
	UiSlate.title(self, L, "MAKING")
	UiSlate.spare(self)
	if inventory == null:
		draw_keys([["esc", "back"]])
		return
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 8
	UiDraw.text_right(self, right, L.position.y + 4, "TAKES", UiTheme.TEXT_DIM)
	if menu.rows.is_empty():
		UiDraw.text(self, Vector2i(x0 + 6, LIST_TOP), "nothing to make here yet", UiTheme.TEXT_DIM)
	var cooking := jobs()
	var bottom := L.end.y - 4 - cook_height(cooking.size())
	var lines := UiSlate.line_count(LIST_TOP, bottom)
	keep_in_view(lines)
	for n in mini(lines, menu.rows.size() - scroll):
		var i := scroll + n
		var row := menu.rows[i]
		var top := UiSlate.line_top(LIST_TOP, n)
		if row.has("header"):
			UiSlate.heading(self, Vector2i(x0, top), String(row.header), right)
			continue
		var r: Dictionary = row.recipe
		var ok := UiMenu.enabled(row)
		var col := UiTheme.TEXT if ok else UiTheme.TEXT_DIM
		if i == menu.index:
			UiSlate.row_bar(self, x0 - 4, right + 3, top, UiTheme.TEXT if ok else UiTheme.WARN)
			col = UiTheme.BRIGHT if ok else UiTheme.TEXT
		_draw_row_icon(r, Vector2i(x0 + 4, top - 1))
		UiDraw.text(self, Vector2i(x0 + 17, top), String(row.title), col)
		UiDraw.text_right(self, right, top, UiRules.duration(float(r.get("minutes", 0.0))), UiTheme.TEXT_DIM)
	if scroll > 0:
		UiDraw.text_right(self, right, LIST_TOP - 11, "↑", UiTheme.TEXT_DIM)
	if scroll + lines < menu.rows.size():
		UiDraw.text_right(self, right, UiSlate.line_top(LIST_TOP, lines) - 2, "↓", UiTheme.TEXT_DIM)
	_draw_cooking(cooking, x0, right, L.end.y - 2 - cook_height(cooking.size()))
	_draw_recipe(UiSlate.SPARE)
	draw_keys([["e", "make"], ["c", "close"], ["esc", "back"]])


## Work already set going at the stations round the player, soonest first.
func jobs() -> Array[Dictionary]:
	return Survival.cooking(game) if game != null else ([] as Array[Dictionary])


## Pixels the "on now" block takes under the list for `n` jobs (0 = none).
static func cook_height(n: int) -> int:
	return 0 if n <= 0 else 13 + mini(n, COOK_ROWS) * UiTheme.LINE


## When a recipe hands its work back: "done 14:20" for work done on the spot,
## and for long work at a station (Crafting.sets_going) that it goes on the
## station and is ready at a time the player can walk away from.
static func ready_line(g: Game, r: Dictionary) -> String:
	var minutes := float(r.get("minutes", 0.0))
	var now := g.clock.minutes
	if not Crafting.sets_going(r):
		return "done %s" % UiRules.clock_at(now + minf(minutes, Survival.MAX_JUMP_MINUTES), now)
	var done := now + Survival.SET_GOING_MINUTES + minutes
	return "on the %s, ready at %s" % [r.get("at", &""), UiRules.clock_at(done, now)]


## What is cooking, under the recipes: a line each, what it makes and when it
## comes off, so long work is watched from wherever the player has walked to.
func _draw_cooking(list: Array[Dictionary], x0: int, right: int, top: int) -> void:
	if list.is_empty():
		return
	var over := list.size() - COOK_ROWS
	UiSlate.heading(self, Vector2i(x0, top), "on now", right)
	for i in mini(list.size(), COOK_ROWS):
		var job: Dictionary = list[i]
		var y := top + 13 + i * UiTheme.LINE
		var makes: Dictionary = job.get("makes", {})
		if i == COOK_ROWS - 1 and over > 0:
			UiDraw.text(self, Vector2i(x0 + 4, y), "and %d more on the go" % over, UiTheme.TEXT_DIM)
			return
		var out := UiRules.recipe_output({"makes": makes})
		if out != &"":
			UiIcons.draw_item(self, out, Vector2i(x0 + 4, y - 1))
		UiDraw.text(self, Vector2i(x0 + 17, y), makes_words(makes), UiTheme.TEXT)
		var done := float(job.get("done", 0.0))
		var now := game.clock.minutes if game != null else 0.0
		UiDraw.text_right(self, right, y, "%s %s" % [job.get("station", &""), UiRules.clock_at(done, now)], UiTheme.TEXT_DIM)


## "charcoal ×2, tar" for what a job will hand back.
static func makes_words(makes: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: StringName in makes:
		var n := int(makes[id])
		parts.append(UiRules.list_name(id, n) + (" ×%d" % n if n > 1 else ""))
	return ", ".join(parts)


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
	var x0 := R.position.x + UiSlate.MARGIN_L
	var at := StringName(r.get("at", &""))
	var box := Rect2i(x0, R.position.y + 8, 84, 84)
	var out := UiRules.recipe_output(r)
	if out != &"":
		UiSlate.scan_box(self, box, out)
	else:
		UiSlate.brackets(self, box, UiTheme.TEXT_DIM, 6)
		var built := StringName(r.get("builds", &""))
		if built != &"":
			UiSketch.draw_station(self, built, box.position + Vector2i(3, 22), 78)
		else:
			UiSketch.draw_item(self, &"hone", box.position + Vector2i(3, 3), 78)
		UiDraw.text(self, Vector2i(box.position.x + 3, box.end.y + 2), "SCAN", UiTheme.TEXT_DIM)
	var tx := box.end.x + 12
	UiDraw.text(self, Vector2i(tx, R.position.y + 10), String(row.title), UiTheme.BRIGHT)
	UiDraw.text(self, Vector2i(tx, R.position.y + 23), UiRules.station_words(at), UiTheme.TEXT_DIM)
	var minutes := float(r.get("minutes", 0.0))
	var takes := "takes %s" % UiRules.duration(minutes)
	UiDraw.text(self, Vector2i(tx, R.position.y + 34), takes, UiTheme.TEXT_DIM)
	if game != null:
		# Long work at a station is set going and left: say so, and when to come back.
		var ready := ready_line(game, r)
		UiDraw.text(self, Vector2i(tx, R.position.y + 45), ready, UiTheme.TEXT if Crafting.sets_going(r) else UiTheme.TEXT_DIM)
	var table_bottom := _draw_table(Rect2i(x0, R.position.y + 110, R.size.x - UiSlate.MARGIN_L - 12, 0), r, row)
	# Where it is made, scanned at the foot of the panel, if there is room.
	var sk := UiSketch.station_size(72)
	var sk_at := Vector2i(x0 + 4, R.end.y - 8 - sk.y)
	if sk_at.y > table_bottom + 10:
		UiSketch.draw_station(self, at if at != &"" else &"hand", sk_at, 72)
		var caption := "made by hand, anywhere" if at == &"hand" else "the %s" % at
		UiDraw.text(self, Vector2i(sk_at.x + sk.x + 10, sk_at.y + sk.y - 12), caption, UiTheme.TEXT_DIM)
		UiSlate.brackets(self, Rect2i(sk_at - Vector2i(4, 4), sk + Vector2i(8, 8)), UiTheme.FAINT, 4)


## What one making wants against what is carried, as the slate tabulates it:
## capitals, ruled, a shortfall in the warning with a bracket round it.
## Returns the table's bottom y.
func _draw_table(at: Rect2i, r: Dictionary, row: Dictionary) -> int:
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
	const ROW := 13
	var s := at
	var col_have := s.end.x - 2
	var col_want := col_have - 36
	var x0 := s.position.x
	var y := s.position.y
	UiDraw.text(self, Vector2i(x0, y), "WANTS", UiTheme.TEXT_DIM)
	UiDraw.text_right(self, col_want, y, "WANT", UiTheme.TEXT_DIM)
	UiDraw.text_right(self, col_have, y, "HAVE", UiTheme.TEXT_DIM)
	y += 11
	UiDraw.hline(self, x0, s.end.x - 1, y, UiTheme.FAINT)
	y += 3
	if lines.is_empty():
		UiDraw.text(self, Vector2i(x0 + 13, y + 1), "NOTHING", UiTheme.TEXT_DIM)
		y += ROW
	for l in lines:
		var want: int = l.want
		var have: int = l.have
		var short := have < want
		var label := ""
		if l.has("tool"):
			label = "SOMETHING TO %s WITH" % String(l.tool).to_upper()
			UiIcons.draw_item(self, &"knife", Vector2i(x0, y))
		else:
			UiIcons.draw_item(self, l.id, Vector2i(x0, y))
			label = UiRules.bare_name(l.id).to_upper() + (", KEPT" if l.has("kept") else "")
		UiDraw.text(self, Vector2i(x0 + 13, y + 1), label, UiTheme.TEXT)
		UiDraw.text_right(self, col_want, y + 1, str(want) if not l.has("tool") else "-", UiTheme.TEXT)
		var have_text := str(have) if not l.has("tool") else ("YES" if have > 0 else "NO")
		UiDraw.text_right(self, col_have, y + 1, have_text, UiTheme.WARN if short else UiTheme.TEXT)
		if short:
			var w := UiFont.width(have_text)
			UiSlate.brackets(self, Rect2i(col_have - w - 5, y - 2, w + 10, 14), UiTheme.WARN, 2)
		y += ROW
		for k in range(x0, s.end.x, 2):
			UiDraw.px(self, k, y - 2, UiTheme.GHOST)
	var ok := UiMenu.enabled(row)
	var verdict := "ALL IN HAND" if ok else String(row.get("why", "")).to_upper().trim_suffix(".")
	UiDraw.text(self, Vector2i(x0, y + 3), verdict, UiTheme.BRIGHT if ok else UiTheme.WARN)
	return y + 14


func _carries_verb(verb: StringName) -> bool:
	for id: StringName in inventory.items:
		if Items.def(id).get("verb", &"") == verb:
			return true
	return false
