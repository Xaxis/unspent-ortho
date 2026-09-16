class_name UiLoadoutScreen
extends UiScreen
## The gear app (from home): the body's slots and what sits in each, the
## resistances they give against every pressure the land can put on a body, and
## the abilities fitted. The hazards package fills it through SlateFeeds
## (&"loadout"); until then it reads the worn kit, the thing in hand and
## Body.resist. The abilities are listed under the slots; the replacement
## sub-panel draws the body as the slate sees it, a wire figure with its slots
## lit, and beside it every resistance.

const LIST_TOP := 50
const ROW_PITCH := 22
## The resistances' column: right of the figure, to the panel's right margin.
const RESIST_X := 430
const RESIST_TOP := 56
const RESIST_PITCH := 12


## Where each of `n` resistances is drawn: one column down the panel, two when
## one will not hold them (VISION §6 names ten, and the land adds more).
static func resist_cells(n: int) -> Array[Rect2i]:
	var right := UiSlate.SPARE.end.x - 12
	var rows := (UiSlate.SPARE.end.y - 6 - RESIST_TOP) / RESIST_PITCH
	var cols := 1 if n <= rows else 2
	var w := (right - RESIST_X - (cols - 1) * 8) / cols
	var out: Array[Rect2i] = []
	for i in mini(n, rows * cols):
		var col := i / rows
		out.append(Rect2i(RESIST_X + col * (w + 8), RESIST_TOP + (i % rows) * RESIST_PITCH, w, 10))
	return out

var _feed: Dictionary = {}


func _init() -> void:
	super()
	screen_name = &"loadout"
	own_action = &""


func refresh() -> void:
	_feed = SlateFeeds.feed(&"loadout", game)
	var rows: Array[Dictionary] = []
	for s: Dictionary in _feed.get("slots", []):
		rows.append({"id": StringName(s.get("id", &"")), "slot": s})
	menu.set_rows(rows)
	queue_redraw()


func _on_confirm(row: Dictionary) -> void:
	var said := SlateFeeds.act(&"loadout", game, row.id)
	if said.begins_with("!"):
		refuse(said.substr(1))
	else:
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
		if said != "":
			say(said)
	refresh()


## What the land the player stands in puts on a body: hazard id -> strength,
## from the landscape type, and anything already pressing on the body.
func here() -> Dictionary:
	var out := {}
	if game == null:
		return out
	var land := BiomeRegistry.at(game.world, game.player.pos)
	for h: Variant in land.hazards:
		out[StringName(h)] = float(land.hazards[h])
	for id: Variant in game.body.pressure:
		out[StringName(id)] = maxf(float(game.body.pressure[id]), float(out.get(StringName(id), 0.0)))
	return out


## Every hazard a landscape can put on a body, and any the gear resists. What
## this land presses with comes first: an empty bar means something where the
## cold is being felt, and nothing at all under a hazard a long way off.
func hazards() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in BiomeRegistry.all():
		for h: Variant in d.hazards:
			if not out.has(StringName(h)):
				out.append(StringName(h))
	for h: Variant in (_feed.get("resist", {}) as Dictionary):
		if not out.has(StringName(h)):
			out.append(StringName(h))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var near := here()
	var first: Array[StringName] = []
	var rest: Array[StringName] = []
	for h in out:
		if near.has(h):
			first.append(h)
		else:
			rest.append(h)
	for h: StringName in near:
		if not first.has(h):
			first.append(h)
	first.append_array(rest)
	return first


func _draw() -> void:
	draw_frame()
	var L := UiSlate.LIST
	var R := UiSlate.SPARE
	UiSlate.title(self, L, "GEAR")
	UiSlate.spare(self)
	var x0 := L.position.x + UiSlate.MARGIN_L
	var right := L.end.x - 8
	UiDraw.text_right(self, right, L.position.y + 4, "SLOT / FITTED", UiTheme.TEXT_DIM)
	for i in menu.rows.size():
		var s: Dictionary = menu.rows[i].slot
		var top := LIST_TOP + i * ROW_PITCH
		var chosen := i == menu.index
		if chosen:
			UiDraw.rect(self, Rect2i(x0 - 4, top - 2, right - x0 + 7, ROW_PITCH - 2), UiTheme.GLASS_LIT)
			UiDraw.rect(self, Rect2i(x0 - 4, top - 1, 2, ROW_PITCH - 4), UiTheme.TEXT)
		UiDraw.text(self, Vector2i(x0 + 2, top), String(s.get("label", s.get("id", ""))).to_upper(), UiTheme.TEXT_DIM)
		var item := StringName(s.get("item", &""))
		var mods: Array = s.get("modules", [])
		if item == &"":
			UiDraw.text(self, Vector2i(x0 + 58, top), "empty", UiTheme.TEXT_DIM)
			# An empty slot still says what to look for out there.
			var fits := SlateFeeds.fits(StringName(s.get("id", &"")))
			if fits != "":
				UiDraw.text(self, Vector2i(x0 + 58, top + 10), fits, UiTheme.TEXT_DIM)
		else:
			UiIcons.draw_item(self, item, Vector2i(x0 + 58, top - 1))
			UiDraw.text(self, Vector2i(x0 + 71, top), UiRules.item_name(item), UiTheme.MACHINE[3] if UiIcons.is_found(item) else (UiTheme.BRIGHT if chosen else UiTheme.TEXT))
		# A socket per module: lit when one is fitted.
		for k in 3:
			var sx := right - 20 + k * 7
			if k < mods.size():
				UiDraw.rect(self, Rect2i(sx, top + 2, 5, 5), UiTheme.MACHINE[3])
			else:
				UiDraw.frame(self, Rect2i(sx, top + 2, 5, 5), UiTheme.FAINT)
		for k in mods.size():
			if k > 0:
				break
			var m: Dictionary = mods[k]
			UiDraw.text(self, Vector2i(x0 + 71, top + 10), "%s  %s" % [m.get("name", ""), m.get("grants", "")], UiTheme.MACHINE[2])
	# Abilities fitted, under the slots that give them.
	var ay := LIST_TOP + menu.rows.size() * ROW_PITCH + 6
	UiSlate.heading(self, Vector2i(x0, ay), "abilities", right)
	var abilities: Array = _feed.get("abilities", [])
	if abilities.is_empty():
		UiDraw.text(self, Vector2i(x0 + 4, ay + 14), "none fitted: modules give them", UiTheme.TEXT_DIM)
	var fit := maxi(1, UiSlate.line_count(ay + 14, L.end.y - 40))
	for i in mini(abilities.size(), fit):
		var a: Dictionary = abilities[i]
		var y := UiSlate.line_top(ay + 14, i)
		if i == fit - 1 and abilities.size() > fit:
			UiDraw.text(self, Vector2i(x0 + 4, y), "and %d more" % (abilities.size() - i), UiTheme.TEXT_DIM)
			break
		UiDraw.text(self, Vector2i(x0 + 4, y), String(a.get("name", a.get("id", ""))), UiTheme.MACHINE[3] if a.get("ready", true) else UiTheme.MACHINE[2])
		UiDraw.text_right(self, right, y, String(a.get("note", "")), UiTheme.TEXT_DIM)
	_draw_this_land(x0, right, L.end.y - 34)
	var px := R.position.x + UiSlate.MARGIN_L
	_draw_figure(Vector2i(px + 40, R.position.y + 14))
	# Resistances: every pressure, how much of it the gear keeps off, down the
	# whole panel beside the figure, in two columns once one will not hold them.
	var rright := R.end.x - 12
	UiSlate.heading(self, Vector2i(RESIST_X, R.position.y + 8), "resists", rright)
	UiSlate.chevron(self, Vector2i(rright - UiFont.width("here") - 6, R.position.y + 10), UiTheme.PHOSPHOR[2])
	UiDraw.text_right(self, rright, R.position.y + 8, "here", UiTheme.TEXT_DIM)
	var resist: Dictionary = _feed.get("resist", {})
	var near := here()
	var hz := hazards()
	var cells := resist_cells(hz.size())
	for i in cells.size():
		var c := cells[i]
		var v := float(resist.get(hz[i], 0.0))
		var pressing := near.has(hz[i])
		var meter_w := 60 if c.size.x > 120 else 22
		var word := String(hz[i]).replace("_", " ")
		while UiFont.width(word) > c.size.x - 13 - meter_w - 4 and word.length() > 3:
			word = word.left(word.length() - 1)
		if pressing:
			UiSlate.chevron(self, Vector2i(c.position.x - 5, c.position.y + 2), UiTheme.PHOSPHOR[2])
		UiIcons.draw_need(self, hz[i], Vector2i(c.position.x, c.position.y - 1), UiTheme.TEXT if v > 0.0 or pressing else UiTheme.FAINT)
		UiDraw.text(self, Vector2i(c.position.x + 13, c.position.y), word, UiTheme.TEXT if v > 0.0 or pressing else UiTheme.TEXT_DIM)
		UiSlate.meter(self, Rect2i(c.end.x - meter_w, c.position.y + 1, meter_w, 7), v)
	if cells.size() < hz.size():
		UiDraw.text_right(self, rright, UiSlate.SPARE.end.y - 12, "+%d" % (hz.size() - cells.size()), UiTheme.TEXT_DIM)
	var keys := [["e", "fit"], ["esc", "back"]]
	draw_keys(keys)


## What this land does to a body, at the foot of the slots: the reason an empty
## resist bar matters here and does not somewhere else.
func _draw_this_land(x0: int, right: int, top: int) -> void:
	if game == null:
		return
	UiSlate.heading(self, Vector2i(x0, top), "this land", right)
	var near := here()
	var words := PackedStringArray()
	for h: StringName in near:
		words.append(String(h).replace("_", " "))
	words.sort()
	var land := BiomeRegistry.at(game.world, game.player.pos)
	UiDraw.text(self, Vector2i(x0 + 4, top + 14), land.display_name, UiTheme.BRIGHT)
	var said := "puts nothing on you" if words.is_empty() else "presses: %s" % ", ".join(words)
	UiDraw.text(self, Vector2i(x0 + 4 + UiFont.width(land.display_name) + 8, top + 14), said, UiTheme.TEXT_DIM)


## The body as the slate draws it: a wire figure, exact, with a point at each
## slot, lit where something is fitted and brightest on the chosen slot.
func _draw_figure(at: Vector2i) -> void:
	var col := UiTheme.FAINT
	var c := at + Vector2i(0, 0)
	# Head.
	for k in 16:
		var a := k * TAU / 16.0
		UiDraw.px(self, c.x + roundi(cos(a) * 6.0), c.y + 8 + roundi(sin(a) * 7.0), col)
	# Torso, arms, legs as ruled lines.
	_line(c + Vector2i(0, 16), c + Vector2i(0, 60), col)
	_line(c + Vector2i(-16, 22), c + Vector2i(16, 22), col)
	_line(c + Vector2i(-16, 22), c + Vector2i(-24, 52), col)
	_line(c + Vector2i(16, 22), c + Vector2i(24, 52), col)
	_line(c + Vector2i(-10, 60), c + Vector2i(10, 60), col)
	_line(c + Vector2i(-10, 60), c + Vector2i(-14, 104), col)
	_line(c + Vector2i(10, 60), c + Vector2i(14, 104), col)
	var points := {&"head": c + Vector2i(0, 8), &"body": c + Vector2i(0, 36), &"hands": c + Vector2i(-24, 52), &"back": c + Vector2i(12, 30), &"tool": c + Vector2i(24, 52), &"craft": c + Vector2i(0, 112)}
	var chosen: StringName = menu.selected().get("id", &"")
	for row: Dictionary in menu.rows:
		var id: StringName = row.id
		if not points.has(id):
			continue
		var p: Vector2i = points[id]
		var filled := StringName(row.slot.get("item", &"")) != &""
		var dot := UiTheme.BRIGHT if id == chosen else (UiTheme.TEXT if filled else UiTheme.FAINT)
		UiDraw.rect(self, Rect2i(p.x - 2, p.y - 2, 5, 5), UiTheme.GLASS_SPARE)
		if filled or id == chosen:
			UiDraw.rect(self, Rect2i(p.x - 1, p.y - 1, 3, 3), dot)
		UiDraw.frame(self, Rect2i(p.x - 2, p.y - 2, 5, 5), dot)
		if id == chosen:
			UiSlate.brackets(self, Rect2i(p.x - 5, p.y - 5, 11, 11), UiTheme.BRIGHT, 2)


func _line(a: Vector2i, b: Vector2i, col: Color) -> void:
	var d := b - a
	var n := maxi(absi(d.x), absi(d.y))
	for k in n + 1:
		UiDraw.px(self, a.x + roundi(d.x * k / float(maxi(1, n))), a.y + roundi(d.y * k / float(maxi(1, n))), col)
