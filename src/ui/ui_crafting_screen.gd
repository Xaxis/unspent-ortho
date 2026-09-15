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
			return "Short of %s %s." % [_count_word(missing), UiRules.item_name(id)]
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
	# The station itself, sketched at the foot of the page.
	var sk := Vector2i(L.position.x + 58, L.end.y - 78)
	UiIcons.draw_station(self, station, sk, 4)
	UiDraw.text(self, Vector2i(sk.x + 60, sk.y + 30), "the %s, as found" % station, UiTheme.FADED)
	UiDraw.hand_hline(self, sk.x - 8, sk.x + 58, sk.y + 45, UiTheme.INK_SOFT, 71)
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
	var minutes := float(r.get("minutes", 0.0))
	var takes := "takes %s" % UiRules.duration(minutes)
	if game != null:
		takes += ", done %s" % UiRules.clock_at(game.clock.minutes + minutes, game.clock.minutes)
	UiDraw.text(self, Vector2i(tx, R.position.y + 42), takes, UiTheme.INK_SOFT)
	_draw_slip(Rect2i(R.position.x + 16, R.position.y + 84, R.size.x - 34, 0), r, row)


## The recipe as a printed slip pasted into the notebook: the one strict,
## institutional surface here, with a heavy grid, thick rules and capital labels.
func _draw_slip(at: Rect2i, r: Dictionary, row: Dictionary) -> void:
	var needs: Dictionary = r.get("needs", {})
	const HEAD := 26
	const ROW := 15
	var h := HEAD + ROW * maxi(1, needs.size()) + 20
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
	for id: StringName in needs:
		var want := int(needs[id])
		var have := inventory.count(id)
		var short := have < want
		UiIcons.draw_item(self, id, Vector2i(x0, y + 3))
		UiDraw.text(self, Vector2i(x0 + 13, y + 3), UiRules.item_name(id), UiTheme.INK)
		UiDraw.text_right(self, col_want, y + 3, str(want), UiTheme.INK)
		UiDraw.text_right(self, col_have, y + 3, str(have), UiTheme.ACCENT if short else UiTheme.INK)
		if short:
			# The shortfall ringed in the one accent, by hand, over the print.
			var w := UiFont.width(str(have))
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
		parts.append(UiRules.item_name(id) + (" ×%d" % n if n > 1 else ""))
	return ", ".join(parts)


static func _count_word(n: int) -> String:
	const WORDS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
	return WORDS[n] if n < WORDS.size() else str(n)
