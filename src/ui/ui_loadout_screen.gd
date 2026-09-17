class_name UiLoadoutScreen
extends UiScreen
## The gear app (from home): the body's slots and what sits in each, the
## resistances they give against every pressure the land can put on a body, and
## the abilities fitted. The hazards package fills it through SlateFeeds
## (&"loadout"); until then it reads the worn kit, the thing in hand and
## Body.resist.
##
## The spare panel is the body itself (owner, 2026-09-17: "the stick figure outline
## needs to be the fully rendered character ... wearing real gear"): the player's
## own figure, scanned onto the glass by `UiGearFigure`, wearing exactly the look
## the loadout puts on the figure in the world (the feed's `figure`). The chosen
## slot is bracketed on the part of the body it dresses and named beside it; the
## figure turns to show that part (the back slot turns it round), left and right
## turn it by hand, and fitting a piece runs the scan down it again.

const LIST_TOP := 50
const ROW_PITCH := 22
## The resistances' column: right of the figure, to the panel's right margin.
const RESIST_X := 466
const RESIST_TOP := 56
const RESIST_PITCH := 12
## Where the figure stands on the spare panel.
const FIGURE := Rect2i(314, 50, 148, 266)
## Where each slot sits on the body: a bone and a point in its frame, and the way
## the figure turns to show it (radians; 0 faces the glass).
const PARTS := {
	&"head": {"bone": &"head", "at": Vector3(0.0, 0.1, 0.0), "yaw": 0.35},
	&"body": {"bone": &"spine", "at": Vector3(0.05, 0.3, 0.0), "yaw": 0.35},
	&"hands": {"bone": &"hand_l", "at": Vector3(0.0, -0.04, 0.0), "yaw": -0.55},
	&"back": {"bone": &"spine", "at": Vector3(-0.16, 0.34, 0.0), "yaw": PI + 0.45},
	&"tool": {"bone": &"tool", "at": Vector3.ZERO, "yaw": 0.75},
	&"craft": {"bone": &"root", "at": Vector3.ZERO, "yaw": 0.35},
}


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


## How the figure turns to show `slot`.
static func yaw_for(slot: StringName) -> float:
	return float((PARTS.get(slot, PARTS[&"body"]) as Dictionary).yaw)


## The body the page draws when no package says: the base body, bare-handed or
## holding what is in hand, wearing nothing.
static func bare_figure(game: Game) -> Dictionary:
	var look := PersonLook.BASE.duplicate(true)
	look["kit"] = true
	return {"look": look, "held": game.inventory.held if game != null and game.inventory != null else &"", "wing": false}

var _feed: Dictionary = {}


var figure: UiGearFigure
var _marks: Control
## Real seconds since a piece last went on, for the bracket's flash.
var _placed := 9.0


func _init() -> void:
	super()
	screen_name = &"loadout"
	own_action = &""
	figure = UiGearFigure.new()
	figure.name = "figure"
	figure.place(FIGURE)
	add_child(figure)
	_marks = Control.new()
	_marks.name = "marks"
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)


func refresh() -> void:
	_feed = SlateFeeds.feed(&"loadout", game)
	var rows: Array[Dictionary] = []
	for s: Dictionary in _feed.get("slots", []):
		rows.append({"id": StringName(s.get("id", &"")), "slot": s})
	menu.set_rows(rows)
	var fig: Dictionary = _feed.get("figure", bare_figure(game))
	if game != null and game.view != null:
		figure.made = game.view.world_material()
	figure.wear(fig.get("look", {}), StringName(fig.get("held", &"")), bool(fig.get("wing", false)))
	figure.turn_to(yaw_for(StringName(menu.selected().get("id", &""))))
	queue_redraw()


func _on_confirm(row: Dictionary) -> void:
	var said := SlateFeeds.act(&"loadout", game, row.id)
	if said.begins_with("!"):
		refuse(said.substr(1))
	else:
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
		if said != "":
			say(said)
		_placed = 0.0
	refresh()


func settle() -> void:
	super.settle()
	figure.settle()


func _on_choice_changed() -> void:
	figure.turn_to(yaw_for(StringName(menu.selected().get("id", &""))))
	_marks.queue_redraw()


func _on_side(dir: int) -> void:
	figure.nudge(dir)
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func _process(delta: float) -> void:
	super._process(delta)
	if is_open:
		_placed += delta
		_marks.queue_redraw()


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
		# A socket per module the piece takes; without a feed, three.
		for k in int(s.get("sockets", 3)):
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
	_draw_bay()
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
	var keys := [["e", "fit"], ["a d", "turn"], ["esc", "back"]]
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


## The bay the body is scanned in: a heading, faint rules
## down the glass behind the figure, and the plinth ring it stands on. The figure
## itself is its own layer above this (UiGearFigure), and the marks above that.
func _draw_bay() -> void:
	var R := UiSlate.SPARE
	var x0 := R.position.x + UiSlate.MARGIN_L
	UiSlate.heading(self, Vector2i(x0, R.position.y + 8), "body", FIGURE.end.x - 10)
	for x in range(FIGURE.position.x + 8, FIGURE.end.x - 4, 14):
		for y in range(FIGURE.position.y + 4, FIGURE.end.y - 12, 3):
			UiDraw.px(self, x, y, UiTheme.GHOST)
	var foot := Vector2i(FIGURE.position.x + FIGURE.size.x / 2, FIGURE.end.y - 10)
	for k in 32:
		var a := k * TAU / 32.0
		UiDraw.px(self, foot.x + roundi(cos(a) * 44.0), foot.y + roundi(sin(a) * 7.0), UiTheme.FAINT)
	for k in 20:
		var a := k * TAU / 20.0
		UiDraw.px(self, foot.x + roundi(cos(a) * 28.0), foot.y + roundi(sin(a) * 4.0), UiTheme.GHOST)


## Over the figure: a point on each part of the body a slot dresses, lit where
## something is fitted; the chosen one bracketed, flashing as a piece goes on,
## with what it holds named beside it and a rule out to the edge of the bay.
func _draw_marks() -> void:
	if not is_open:
		return
	var chosen := StringName(menu.selected().get("id", &""))
	for row: Dictionary in menu.rows:
		var id: StringName = row.id
		if not PARTS.has(id) or id == chosen:
			continue
		var p := figure.point_of(PARTS[id].bone, PARTS[id].at)
		if not FIGURE.has_point(p) or not figure.faces_glass(PARTS[id].bone, PARTS[id].at):
			continue
		var filled := StringName(row.slot.get("item", &"")) != &""
		var at := Vector2i(p.round())
		UiDraw.rect(_marks, Rect2i(at.x - 2, at.y - 2, 5, 5), UiTheme.RIM)
		if filled:
			UiDraw.rect(_marks, Rect2i(at.x - 1, at.y - 1, 3, 3), UiTheme.TEXT)
		else:
			UiDraw.frame(_marks, Rect2i(at.x - 1, at.y - 1, 3, 3), UiTheme.FAINT)
	if not PARTS.has(chosen):
		return
	var cp := figure.point_of(PARTS[chosen].bone, PARTS[chosen].at)
	if not FIGURE.grow(4).has_point(cp):
		return
	var c := Vector2i(cp.round())
	var flash := _placed < 0.6 and int(_placed * 10.0) % 2 == 0
	var ink := UiTheme.BRIGHT if not flash else UiTheme.PHOSPHOR[4]
	var grow := 7 if not flash else 9
	UiSlate.brackets(_marks, Rect2i(c.x - grow - 1, c.y - grow - 1, grow * 2 + 3, grow * 2 + 3), UiTheme.RIM, 4)
	UiSlate.brackets(_marks, Rect2i(c.x - grow, c.y - grow, grow * 2 + 1, grow * 2 + 1), ink, 3)
	var row := menu.selected()
	var item := StringName((row.get("slot", {}) as Dictionary).get("item", &""))
	var words := UiRules.item_name(item) if item != &"" else "empty"
	var tag_w := UiFont.width(words) + (15 if item != &"" else 6)
	# The name stands on whichever side of the figure the part is not.
	var left := c.x > FIGURE.position.x + FIGURE.size.x / 2
	var tx := FIGURE.position.x + 2 if left else FIGURE.end.x - 2 - tag_w
	var ty := clampi(c.y - 20, FIGURE.position.y, FIGURE.end.y - 12)
	var tag := Rect2i(tx, ty, tag_w, 11)
	var near_x := tag.end.x if left else tag.position.x
	UiDraw.hline(_marks, mini(near_x, c.x - grow if left else c.x + grow), maxi(near_x, c.x - grow if left else c.x + grow), ty + 5, UiTheme.RIM)
	UiDraw.hline(_marks, mini(near_x, c.x - grow if left else c.x + grow), maxi(near_x, c.x - grow if left else c.x + grow), ty + 5, ink if not flash else UiTheme.TEXT)
	UiDraw.rect(_marks, tag.grow(1), UiTheme.RIM)
	UiDraw.rect(_marks, tag, UiTheme.GLASS)
	UiDraw.frame(_marks, tag, UiTheme.TEXT_DIM)
	var x := tag.position.x + 3
	if item != &"":
		UiIcons.draw_item(_marks, item, Vector2i(x, tag.position.y + 1))
		x += 12
	UiDraw.text(_marks, Vector2i(x, tag.position.y), words, UiTheme.MACHINE[3] if UiIcons.is_found(item) else UiTheme.BRIGHT)
