class_name UiCraftingScreen
extends UiScreen
## The making page (C, at a fire, bench or kiln). Left: what can be made here;
## rows short of something are faded but still choosable, and say what is
## short. Right: the chosen recipe as a hand-ruled table of what it needs
## against what is carried, and how long it takes. E makes it: Crafting.make
## moves the goods, then the clock is charged the recipe's minutes.

## &"fire" &"bench" &"kiln"; set by whoever opens the page.
var station: StringName = &"fire"
var inventory: Inventory
## Recipes source for tests and demo shots; empty = Crafting.recipes_at.
var recipes_override: Array[Dictionary] = []


func _init() -> void:
	super()
	screen_name = &"crafting"
	own_action = &"craft"


func recipes() -> Array[Dictionary]:
	if not recipes_override.is_empty():
		return recipes_override
	var list := Crafting.recipes_at(station)
	if list.is_empty() and game != null and game.options.ui_demo:
		list = UiDemo.recipes_at(station)
	return list


func refresh() -> void:
	if inventory == null and game != null:
		inventory = game.inventory
	if inventory == null:
		return
	var rows: Array[Dictionary] = []
	for r in recipes():
		var row := {"id": r.get("id", &""), "recipe": r, "enabled": Crafting.can_make(inventory, r)}
		if not row.enabled:
			row["why"] = _short_of(r)
		rows.append(row)
	menu.set_rows(rows)
	queue_redraw()


func _short_of(r: Dictionary) -> String:
	var needs: Dictionary = r.get("needs", {})
	for id: StringName in needs:
		if inventory.count(id) < int(needs[id]):
			var missing := int(needs[id]) - inventory.count(id)
			return "Short of %s %s." % [_count_word(missing), Items.display_name(id)]
	return "Not now."


func _on_confirm(row: Dictionary) -> void:
	var r: Dictionary = row.recipe
	if not Crafting.make(inventory, r):
		refuse(_short_of(r))
		return
	var minutes := float(r.get("minutes", 0.0))
	if game != null and minutes > 0.0:
		game.clock.skip(minutes)
		Events.time_skipped.emit(minutes, &"make")
	Events.sfx.emit(&"menu_select", Vector3.ZERO)
	say("Made %s." % _makes_text(r))
	refresh()


func _draw() -> void:
	UiNotebook.spread(self, 23)
	var L := UiNotebook.LEFT
	var R := UiNotebook.RIGHT
	UiNotebook.title(self, L, "at the %s" % station, 9)
	if inventory == null:
		return
	var x0 := L.position.x + UiNotebook.MARGIN_X
	var right := L.end.x - 10
	UiDraw.text_right(self, right, L.position.y + 11, "takes", UiTheme.FADED)
	if menu.rows.is_empty():
		UiDraw.text(self, Vector2i(x0 + 6, UiNotebook.line_top(L, 0)), "nothing to make here yet", UiTheme.FADED)
	var lines := UiNotebook.rule_count(L) - 2
	for i in mini(lines, menu.rows.size()):
		var row := menu.rows[i]
		var r: Dictionary = row.recipe
		var top := UiNotebook.line_top(L, i)
		var out_id := _first_output(r)
		var col := UiTheme.INK if UiMenu.enabled(row) else UiTheme.FADED
		if i == menu.index:
			UiNotebook.cursor(self, x0 + 4, top)
		UiIcons.draw_item(self, out_id, Vector2i(x0 + 11, top - 1))
		UiDraw.text(self, Vector2i(x0 + 24, top), _makes_text(r), col)
		UiDraw.text_right(self, right, top, UiRules.duration(float(r.get("minutes", 0.0))), UiTheme.INK_SOFT if UiMenu.enabled(row) else UiTheme.FADED)
	UiNotebook.footer(self, L, "e make     c close     esc")
	_draw_recipe(R)
	UiNotebook.note(self, R, note, note_age)


func _draw_recipe(R: Rect2i) -> void:
	var row := menu.selected()
	if row.is_empty():
		return
	var r: Dictionary = row.recipe
	var x0 := R.position.x + 26
	var out_id := _first_output(r)
	var box := Rect2i(x0, R.position.y + 16, 46, 46)
	UiDraw.rect(self, box.grow(-1), Color(UiTheme.PAPER_SHADE, 0.25))
	UiNotebook.box(self, box, UiTheme.INK_SOFT, 13)
	UiIcons.draw_item(self, out_id, box.position + Vector2i(5, 5), 4)
	UiNotebook.tape(self, Vector2i(box.position.x + 12, box.position.y - 3), 22)
	var tx := box.end.x + 10
	UiDraw.text(self, Vector2i(tx, R.position.y + 18), _makes_text(r), UiTheme.INK)
	UiDraw.text(self, Vector2i(tx, R.position.y + 31), "at the %s" % station, UiTheme.INK_SOFT)
	UiDraw.text(self, Vector2i(tx, R.position.y + 42), "takes %s" % UiRules.duration(float(r.get("minutes", 0.0))), UiTheme.INK_SOFT)

	# The table: a heavy-ruled grid, the one place the notebook is strict.
	var needs: Dictionary = r.get("needs", {})
	var top := UiNotebook.rule_y(R, 5) - 8
	var col_have := R.end.x - 20
	var col_need := col_have - 34
	var grid_l := x0 - 4
	var grid_r := R.end.x - 12
	UiDraw.text(self, Vector2i(x0 + 13, top - 12), "needs", UiTheme.INK)
	UiDraw.text_right(self, col_need, top - 12, "want", UiTheme.FADED)
	UiDraw.text_right(self, col_have, top - 12, "have", UiTheme.FADED)
	UiDraw.hline(self, grid_l, grid_r, top - 1, UiTheme.INK)
	UiDraw.hline(self, grid_l, grid_r, top, UiTheme.INK)
	var y := top + 3
	for id: StringName in needs:
		var want := int(needs[id])
		var have := inventory.count(id)
		UiIcons.draw_item(self, id, Vector2i(x0, y))
		UiDraw.text(self, Vector2i(x0 + 13, y + 1), Items.display_name(id), UiTheme.INK)
		UiDraw.text_right(self, col_need, y + 1, str(want), UiTheme.INK_SOFT)
		var short := have < want
		UiDraw.text_right(self, col_have, y + 1, str(have), UiTheme.ACCENT if short else UiTheme.INK)
		if short:
			UiDraw.hand_hline(self, col_have - UiFont.width(str(have)) - 2, col_have + 1, y + 11, UiTheme.ACCENT, have * 7 + want)
		y += 13
		UiDraw.hline(self, grid_l, grid_r, y - 1, UiTheme.RULE)
	UiDraw.hline(self, grid_l, grid_r, y, UiTheme.INK)
	UiDraw.vline(self, col_need - UiFont.width("want") - 6, top - 12, y, UiTheme.RULE)
	UiDraw.vline(self, col_need + 5, top - 12, y, UiTheme.RULE)
	if not UiMenu.enabled(row):
		UiDraw.text(self, Vector2i(x0, y + 8), String(row.get("why", "")).to_lower().trim_suffix("."), UiTheme.ACCENT)


static func _first_output(r: Dictionary) -> StringName:
	var makes: Dictionary = r.get("makes", {})
	for id: StringName in makes:
		return id
	return &""


static func _makes_text(r: Dictionary) -> String:
	var makes: Dictionary = r.get("makes", {})
	var parts := PackedStringArray()
	for id: StringName in makes:
		var n := int(makes[id])
		parts.append(Items.display_name(id) + (" ×%d" % n if n > 1 else ""))
	return ", ".join(parts)


static func _count_word(n: int) -> String:
	const WORDS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
	return WORDS[n] if n < WORDS.size() else str(n)
