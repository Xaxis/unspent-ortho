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

## The first row of the list, one text line's clearance under the pane's title.
const LIST_TOP := UiSlate.LIST.position.y + 36
## A slot's row holds two lines: what it is, and what is in it.
const ROW_PITCH := UiTheme.LINE * 2
## The list panel's right margin, and where a row's words begin across from the
## slot's name. Named because a TEST measures the room a module's conflict line
## has against them (tests/gear_economy/test_modifiers.gd) and used to carry its
## own copies: 71 against this 142 and 8 against this 16, both left behind when
## the base moved. It therefore allowed 737 px where the row has 658 — a line
## between the two fitted the test and ran across the resistances column, which
## is the exact failure that test was written to stop.
const LIST_PAD_R := 16
const ROW_TEXT_X := 142
## Where the figure stands on the spare panel. The viewport is a PICTURE, so it
## covers the share of the panel it always did and is simply drawn at three times
## the detail; the gap between it and the panel's edge is type-sized.
const FIGURE := Rect2i(UiSlate.SPARE.position.x + 8, UiSlate.SPARE.position.y + 30, 444, 798)
## The resistances' column: right of the figure, to the panel's right margin.
const RESIST_X := FIGURE.end.x + 8
const RESIST_TOP := UiSlate.SPARE.position.y + 42
const RESIST_PITCH := 24
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
	var right := UiSlate.SPARE.end.x - 24
	var rows := (UiSlate.SPARE.end.y - 12 - RESIST_TOP) / RESIST_PITCH
	var cols := 1 if n <= rows else 2
	var w := (right - RESIST_X - (cols - 1) * 16) / cols
	var out: Array[Rect2i] = []
	for i in mini(n, rows * cols):
		var col := i / rows
		out.append(Rect2i(RESIST_X + col * (w + 16), RESIST_TOP + (i % rows) * RESIST_PITCH, w, UiFont.SIZE))
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


## Turning the figure IS what the arrows do here, on every row, so this page
## keeps them and never falls through to the door.
func _on_side(dir: int) -> bool:
	figure.nudge(dir)
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
	return true


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
	var right := L.end.x - LIST_PAD_R
	UiDraw.text_right(self, right, L.position.y + 8, "SLOT / FITTED", UiTheme.TEXT_DIM)
	for i in menu.rows.size():
		var s: Dictionary = menu.rows[i].slot
		var top := LIST_TOP + i * ROW_PITCH
		var chosen := i == menu.index
		if chosen:
			UiDraw.rect(self, Rect2i(x0 - 8, top - 4, right - x0 + 14, ROW_PITCH - 4), UiTheme.GLASS_LIT)
			UiDraw.rect(self, Rect2i(x0 - 8, top - 2, 4, ROW_PITCH - 8), UiTheme.TEXT)
		UiDraw.text(self, Vector2i(x0 + 4, top), String(s.get("label", s.get("id", ""))).to_upper(), UiTheme.TEXT_DIM)
		var item := StringName(s.get("item", &""))
		var mods: Array = s.get("modules", [])
		if item == &"":
			UiDraw.text(self, Vector2i(x0 + 116, top), "empty", UiTheme.TEXT_DIM)
			# An empty slot still says what to look for out there.
			var fits := SlateFeeds.fits(StringName(s.get("id", &"")))
			if fits != "":
				UiDraw.text(self, Vector2i(x0 + 116, top + UiTheme.LINE), fits, UiTheme.TEXT_DIM)
		else:
			UiIcons.draw_item(self, item, Vector2i(x0 + 116, top - 2))
			UiDraw.text(self, Vector2i(x0 + ROW_TEXT_X, top), UiRules.item_name(item), UiTheme.MACHINE[3] if UiIcons.is_found(item) else (UiTheme.BRIGHT if chosen else UiTheme.TEXT))
		# A socket per module: lit when one is fitted.
		# A socket per module the piece takes; without a feed, three.
		for k in int(s.get("sockets", 3)):
			var sx := right - 40 + k * 14
			if k < mods.size():
				UiDraw.rect(self, Rect2i(sx, top + 4, 10, 10), UiTheme.MACHINE[3])
			else:
				UiDraw.frame(self, Rect2i(sx, top + 4, 10, 10), UiTheme.FAINT)
		for k in mods.size():
			if k > 0:
				break
			var m: Dictionary = mods[k]
			UiDraw.text(self, Vector2i(x0 + ROW_TEXT_X, top + UiTheme.LINE), "%s  %s" % [m.get("name", ""), m.get("grants", "")], UiTheme.MACHINE[2])
	# Abilities fitted, under the slots that give them.
	var ay := LIST_TOP + menu.rows.size() * ROW_PITCH + 12
	UiSlate.heading(self, Vector2i(x0, ay), "abilities", right)
	var abilities: Array = _feed.get("abilities", [])
	if abilities.is_empty():
		UiDraw.text(self, Vector2i(x0 + 8, ay + 28), "none fitted: modules give them", UiTheme.TEXT_DIM)
	var fit := maxi(1, UiSlate.line_count(ay + 28, L.end.y - 80))
	for i in mini(abilities.size(), fit):
		var a: Dictionary = abilities[i]
		var y := UiSlate.line_top(ay + 28, i)
		if i == fit - 1 and abilities.size() > fit:
			UiDraw.text(self, Vector2i(x0 + 8, y), "and %d more" % (abilities.size() - i), UiTheme.TEXT_DIM)
			break
		UiDraw.text(self, Vector2i(x0 + 8, y), String(a.get("name", a.get("id", ""))), UiTheme.MACHINE[3] if a.get("ready", true) else UiTheme.MACHINE[2])
		UiDraw.text_right(self, right, y, String(a.get("note", "")), UiTheme.TEXT_DIM)
	_draw_this_land(x0, right, L.end.y - 68)
	_draw_bay()
	# Resistances: every pressure, how much of it the gear keeps off, down the
	# whole panel beside the figure, in two columns once one will not hold them.
	var rright := R.end.x - 24
	UiSlate.heading(self, Vector2i(RESIST_X, R.position.y + 16), "resists", rright)
	UiSlate.chevron(self, Vector2i(rright - UiFont.width("here") - 12, R.position.y + 20), UiTheme.PHOSPHOR[2])
	UiDraw.text_right(self, rright, R.position.y + 16, "here", UiTheme.TEXT_DIM)
	var resist: Dictionary = _feed.get("resist", {})
	var near := here()
	var hz := hazards()
	var cells := resist_cells(hz.size())
	for i in cells.size():
		var c := cells[i]
		var v := float(resist.get(hz[i], 0.0))
		var pressing := near.has(hz[i])
		var meter_w := 120 if c.size.x > 240 else 44
		var word := String(hz[i]).replace("_", " ")
		while UiFont.width(word) > c.size.x - 26 - meter_w - 8 and word.length() > 3:
			word = word.left(word.length() - 1)
		if pressing:
			UiSlate.chevron(self, Vector2i(c.position.x - 10, c.position.y + 4), UiTheme.PHOSPHOR[2])
		UiIcons.draw_need(self, hz[i], Vector2i(c.position.x, c.position.y - 2), UiTheme.TEXT if v > 0.0 or pressing else UiTheme.FAINT)
		UiDraw.text(self, Vector2i(c.position.x + 26, c.position.y), word, UiTheme.TEXT if v > 0.0 or pressing else UiTheme.TEXT_DIM)
		UiSlate.meter(self, Rect2i(c.end.x - meter_w, c.position.y + 2, meter_w, 14), v)
	if cells.size() < hz.size():
		UiDraw.text_right(self, rright, UiSlate.SPARE.end.y - 24, "+%d" % (hz.size() - cells.size()), UiTheme.TEXT_DIM)
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
	UiDraw.text(self, Vector2i(x0 + 8, top + 28), land.display_name, UiTheme.BRIGHT)
	var said := "puts nothing on you" if words.is_empty() else "presses: %s" % ", ".join(words)
	UiDraw.text(self, Vector2i(x0 + 8 + UiFont.width(land.display_name) + 16, top + 28), said, UiTheme.TEXT_DIM)


## The bay the body is scanned in: a heading, faint rules
## down the glass behind the figure, and the plinth ring it stands on. The figure
## itself is its own layer above this (UiGearFigure), and the marks above that.
func _draw_bay() -> void:
	var R := UiSlate.SPARE
	var x0 := R.position.x + UiSlate.MARGIN_L
	UiSlate.heading(self, Vector2i(x0, R.position.y + 16), "body", FIGURE.end.x - 20)
	# The bay's rules and its plinth are part of the picture: they keep the size
	# they had on the glass, and are drawn in the module's finer pixels.
	for x in range(FIGURE.position.x + 24, FIGURE.end.x - 12, 42):
		for y in range(FIGURE.position.y + 12, FIGURE.end.y - 36, 9):
			UiDraw.px(self, x, y, UiTheme.GHOST)
	var foot := Vector2i(FIGURE.position.x + FIGURE.size.x / 2, FIGURE.end.y - 30)
	for k in 32:
		var a := k * TAU / 32.0
		UiDraw.px(self, foot.x + roundi(cos(a) * 132.0), foot.y + roundi(sin(a) * 21.0), UiTheme.FAINT)
	for k in 20:
		var a := k * TAU / 20.0
		UiDraw.px(self, foot.x + roundi(cos(a) * 84.0), foot.y + roundi(sin(a) * 12.0), UiTheme.GHOST)


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
		UiDraw.rect(_marks, Rect2i(at.x - 4, at.y - 4, 10, 10), UiTheme.RIM)
		if filled:
			UiDraw.rect(_marks, Rect2i(at.x - 2, at.y - 2, 6, 6), UiTheme.TEXT)
		else:
			UiDraw.frame(_marks, Rect2i(at.x - 2, at.y - 2, 6, 6), UiTheme.FAINT)
	if not PARTS.has(chosen):
		return
	var cp := figure.point_of(PARTS[chosen].bone, PARTS[chosen].at)
	if not FIGURE.grow(8).has_point(cp):
		return
	var c := Vector2i(cp.round())
	var flash := _placed < 0.6 and int(_placed * 10.0) % 2 == 0
	var ink := UiTheme.BRIGHT if not flash else UiTheme.PHOSPHOR[4]
	var grow := 14 if not flash else 18
	UiSlate.brackets(_marks, Rect2i(c.x - grow - 2, c.y - grow - 2, grow * 2 + 6, grow * 2 + 6), UiTheme.RIM, 8)
	UiSlate.brackets(_marks, Rect2i(c.x - grow, c.y - grow, grow * 2 + 2, grow * 2 + 2), ink, 6)
	var row := menu.selected()
	var item := StringName((row.get("slot", {}) as Dictionary).get("item", &""))
	var words := UiRules.item_name(item) if item != &"" else "empty"
	var tag_w := UiFont.width(words) + (30 if item != &"" else 12)
	# The name stands on whichever side of the figure the part is not.
	var left := c.x > FIGURE.position.x + FIGURE.size.x / 2
	var tx := FIGURE.position.x + 4 if left else FIGURE.end.x - 4 - tag_w
	var ty := clampi(c.y - 40, FIGURE.position.y, FIGURE.end.y - 24)
	var tag := Rect2i(tx, ty, tag_w, UiTheme.LINE)
	var near_x := tag.end.x if left else tag.position.x
	var out_x := c.x - grow if left else c.x + grow
	# The leader is a bar the eye follows to the body, never a hairline.
	var lead := Rect2i(mini(near_x, out_x), ty + UiTheme.LINE / 2, absi(out_x - near_x), UiBase.PITCH)
	UiDraw.rect(_marks, lead, UiTheme.RIM)
	UiDraw.rect(_marks, lead, ink if not flash else UiTheme.TEXT)
	UiDraw.rect(_marks, tag.grow(2), UiTheme.RIM)
	UiDraw.rect(_marks, tag, UiTheme.GLASS)
	UiDraw.frame(_marks, tag, UiTheme.TEXT_DIM)
	var x := tag.position.x + 6
	if item != &"":
		UiIcons.draw_item(_marks, item, Vector2i(x, tag.position.y + 2))
		x += 24
	UiDraw.text(_marks, Vector2i(x, tag.position.y), words, UiTheme.MACHINE[3] if UiIcons.is_found(item) else UiTheme.BRIGHT)
