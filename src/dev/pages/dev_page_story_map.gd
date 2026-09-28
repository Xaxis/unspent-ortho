class_name DevPageStoryMap
extends DevPage
## The story map (docs/ROADMAP.md, "Tools track"): the whole story over THIS
## world, off the STORY tab. Two views of one projection (StoryMap), m between
## them, the chosen beat held across:
##
##   WORLD  the survey's own sheet, dimmed, and on it the journey's legs as a bold
##          spine; every arc a coloured line of arrows from the place one beat
##          lands to the place its next does, drawn beside the others where arcs
##          share ground, like lines through a station; a region's own asks as
##          thin dashed spurs to its yard; the gates into 2029. Beats with no place
##          on this world stand on a rail under the sheet, in story order.
##   ORDER  a schematic: the story left to right in story order, the legs as
##          bands, one lane an arc, so how the arcs interleave across the whole
##          game reads at once, geography or none.
##
## What the live game has made of each beat is drawn on its mark: landed (solid),
## open (lit and ringed), withheld while a revelation settles (violet), later
## (hollow). Tab and y step through the story in order and everything after the
## chosen beat dims: the scrub. x narrows it to the chosen beat's arc, then its
## person, then its leg, then all again. The panel says what the chosen mark is:
## its words, who says it, where, what opens it, and the line of source it is.
##
## A PAGE THAT TAKES THE WHOLE GLASS (`wide`). The dev screen draws its frame,
## strip and keys and leaves the body to this page, which lays its own nodes over
## the screen (the survey's sheet in a SubViewport, drawn once per move, and a
## layer of marks over it) and takes them away when it is left.

const MODES: Array[StringName] = [&"world", &"order"]
const PANEL_W := 560
const RAIL_H := 58
const PAN_STEP := 60
## Survey pixels a tile, widest first; the widest is worked out to fit the story.
const SCALES: Array[float] = [1.0, 1.5, 2.0, 3.0, 4.5, 6.0, 9.0, 12.0]
## From this scale a station names itself, and from the next lists its beats.
const NAME_FROM := 1.5
const LIST_FROM := 3.0
## An arc's own colour, in ARCS order: each a phosphor of its own, all lit to the
## same weight so none reads as more important than the others, and the spine
## (who he was) the slate's own brightest green.
const ARC_COLOURS: Array[Color] = [
	Color("#c9fbe2"), Color("#ff9a6b"), Color("#b3a8ea"), Color("#e8c46a"), Color("#7fc8f8"),
	Color("#f28fb1"), Color("#ffe0a8"), Color("#9ee6ff"), Color("#8fc27a"), Color("#d6a2ff"),
	Color("#ffb3a3"), Color("#dfe8e4"), Color("#5fe0c0"), Color("#c8a27a"), Color("#ff7fbf"),
]
const FILTERS: Array[StringName] = [&"", &"arc", &"cast", &"leg"]

var map: StoryMap
var mode := 0
## Survey pixels a tile, and the tile under the sheet's top-left pixel.
var scale := 1.0
var origin_px := Vector2.ZERO
## The chosen beat (&"": none), and the filter: which kind and what it keeps.
var chosen: StringName = &""
var filter := 0
var filter_value: Variant = null
## How long opening the page took (ms), for the panel and the test.
var open_ms := 0

var _viewport: SubViewport
var _sheet: ColorRect
var _ground: TextureRect
var _overlay: Control
var _material: ShaderMaterial
var _widest := 1.0
var _time := 0.0
var _drag := false
## Marks drawn this frame, for a click to find: [{rect, beat}].
var _hits: Array[Dictionary] = []


func heading() -> String:
	return "THE MAP"


func wide() -> bool:
	return true


func rows() -> Array[Dictionary]:
	return []


## The sheet's window and the panel beside it, in base pixels.
static func sheet_rect() -> Rect2i:
	var top := UiDevScreen.LIST_TOP + 10
	var b := UiSlate.BODY
	return Rect2i(b.position.x + UiSlate.MARGIN_L, top, b.size.x - UiSlate.MARGIN_L - UiSlate.MARGIN_R - PANEL_W - 20, b.end.y - top - 8)


static func map_rect() -> Rect2i:
	var r := sheet_rect()
	return Rect2i(r.position, Vector2i(r.size.x, r.size.y - RAIL_H - 6))


static func rail_rect() -> Rect2i:
	var r := sheet_rect()
	return Rect2i(r.position.x, r.end.y - RAIL_H, r.size.x, RAIL_H)


static func panel_rect() -> Rect2i:
	var s := sheet_rect()
	return Rect2i(s.end.x + 20, s.position.y, PANEL_W, s.size.y)


# --- the page on the glass ------------------------------------------------------------

func enter() -> void:
	if _overlay != null or game == null:
		return
	var t := Time.get_ticks_msec()
	map = StoryMap.of(game.world)
	var r := map_rect()
	_material = UiMapScreen.survey_material()
	_viewport = SubViewport.new()
	_viewport.size = r.size
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen.add_child(_viewport)
	_sheet = ColorRect.new()
	_sheet.size = Vector2(r.size)
	_sheet.material = _material
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_sheet)
	_ground = TextureRect.new()
	_ground.position = Vector2(r.position)
	_ground.size = Vector2(r.size)
	_ground.texture = _viewport.get_texture()
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_ground)
	_overlay = Control.new()
	_overlay.size = Vector2(UiBase.SIZE)
	_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay.draw.connect(_draw_overlay)
	_overlay.gui_input.connect(_on_gui_input)
	screen.add_child(_overlay)
	var data := _survey()
	if data != null:
		# The whole world is drawn as seen: the sheet reads its mask tile by tile.
		var all := Image.create(game.world.size, game.world.size, false, Image.FORMAT_L8)
		all.fill(Color.WHITE)
		var seen := ImageTexture.create_from_image(all)
		UiMapScreen.feed(_material, data, seen, r.size)
	_fit_story()
	_show_mode()
	open_ms = Time.get_ticks_msec() - t


func leave() -> void:
	for n: Node in [_viewport, _ground, _overlay]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_viewport = null
	_ground = null
	_overlay = null


## The survey's textures: the ones the ui system already built for the map app.
func _survey() -> UiMapData:
	var ui := DevCheats.system(game, "90_ui")
	var data: UiMapData = ui.get("map_data") if ui != null else null
	if data == null:
		data = UiMapData.new(game.world)
	data.ensure()
	return data


## The widest scale shows every place the story stands, with room round it.
func _fit_story() -> void:
	var r := map_rect()
	var box := Rect2(game.world.spawn, Vector2.ZERO)
	for id: StringName in map.places:
		box = box.expand(map.places[id].pos)
	box = box.grow(maxf(box.size.x, box.size.y) * 0.06 + 8.0)
	_widest = minf(r.size.x / maxf(1.0, box.size.x), r.size.y / maxf(1.0, box.size.y))
	scale = _widest
	_centre_on(box.get_center())


func _centre_on(p: Vector2) -> void:
	origin_px = p * scale - Vector2(map_rect().size) * 0.5
	_apply()


func _apply() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("origin_px", origin_px.round())
	_material.set_shader_parameter("scale", scale)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_overlay.queue_redraw()


func _show_mode() -> void:
	var world := MODES[mode] == &"world"
	_ground.visible = world
	_overlay.queue_redraw()


func to_screen(p: Vector2) -> Vector2:
	return Vector2(map_rect().position) + p * scale - origin_px.round()


func step(delta: float) -> void:
	_time += delta
	if _overlay != null:
		_overlay.queue_redraw()


# --- keys -------------------------------------------------------------------------------

func handle(action: StringName) -> bool:
	if map == null:
		return false
	match action:
		&"up", &"down", &"left", &"right":
			if MODES[mode] == &"order":
				_order_step(action)
			else:
				var d := {&"up": Vector2(0, -1), &"down": Vector2(0, 1), &"left": Vector2(-1, 0), &"right": Vector2(1, 0)}[action] as Vector2
				origin_px += d * PAN_STEP
				_apply()
			return true
		&"zoom_in", &"zoom_out":
			_zoom(1 if action == &"zoom_in" else -1, Vector2(map_rect().get_center()))
			return true
		&"inventory":
			scrub(1)
			return true
		&"craft":
			scrub(-1)
			return true
		&"map":
			mode = (mode + 1) % MODES.size()
			_show_mode()
			Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
			return true
		&"drop":
			next_filter()
			return true
		&"confirm":
			if chosen == &"":
				scrub(1)
			return true
	return false


## The scales on offer, widest first: the fit, then every step closer than it.
func scales() -> Array[float]:
	var out: Array[float] = [_widest]
	for s: float in SCALES:
		if s > _widest * 1.2:
			out.append(s)
	return out


func _zoom(dir: int, about: Vector2) -> void:
	var all := scales()
	var at := 0
	for i in all.size():
		if all[i] <= scale + 0.001:
			at = i
	var to := clampi(at + dir, 0, all.size() - 1)
	if to == at:
		return
	var tile := (about - Vector2(map_rect().position) + origin_px) / scale
	scale = all[to]
	origin_px = tile * scale - (about - Vector2(map_rect().position))
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
	_apply()


## The beats the filter keeps, in story order.
func shown() -> Array[StringName]:
	match FILTERS[filter]:
		&"arc":
			return map.visible(StringName(str(filter_value)))
		&"cast":
			return map.visible(&"", StringName(str(filter_value)))
		&"leg":
			return map.visible(&"", &"", int(filter_value))
	return map.visible()


## Along the story by `dir` among what the filter keeps; off the end is the whole again.
func scrub(dir: int) -> void:
	var list := shown()
	if list.is_empty():
		return
	var at := list.find(chosen)
	at = at + dir if at >= 0 else (0 if dir > 0 else list.size() - 1)
	chosen = list[clampi(at, 0, list.size() - 1)]
	_follow()
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


## --dev=story_map:WORDS, joined by "+": world or order; zoomN, the Nth scale
## from the widest (0); a beat's id, chosen; narrow, the filter's next step.
func pick(what: StringName) -> bool:
	if map == null:
		return false
	var w := String(what)
	if MODES.has(what):
		mode = MODES.find(what)
		_show_mode()
		return true
	if w.begins_with("zoom"):
		var all := scales()
		var i := clampi(w.trim_prefix("zoom").to_int(), 0, all.size() - 1)
		var about: Vector2 = map.beats[chosen].pos if chosen != &"" and (map.beats[chosen].pos as Vector2).is_finite() else Vector2(map_rect().get_center()) - Vector2(map_rect().position) + origin_px
		if chosen == &"" or not (map.beats[chosen].pos as Vector2).is_finite():
			about = about / scale
		scale = all[i]
		_centre_on(about)
		return true
	if w == "narrow":
		next_filter()
		return true
	if map.beats.has(what):
		choose(what)
		return true
	return false


func choose(beat: StringName) -> void:
	if map.beats.has(beat):
		chosen = beat
		_follow()


## Keep the chosen beat on the sheet.
func _follow() -> void:
	if MODES[mode] != &"world" or chosen == &"":
		_overlay.queue_redraw()
		return
	var p: Vector2 = map.beats[chosen].pos
	if p.is_finite() and not Rect2(map_rect()).grow(-40).has_point(to_screen(p)):
		_centre_on(p)
	_overlay.queue_redraw()


## all -> the chosen beat's arc -> its person -> its leg -> all. A kind the chosen
## beat has nothing for is passed over.
func next_filter() -> void:
	for i in FILTERS.size():
		filter = (filter + 1) % FILTERS.size()
		filter_value = _filter_value(FILTERS[filter])
		if FILTERS[filter] == &"" or filter_value != null:
			break
	if chosen != &"" and not shown().has(chosen):
		chosen = &""
	_frame_kept()
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
	_overlay.queue_redraw()


## Narrowed, the sheet frames what is kept; widened again, the whole story.
func _frame_kept() -> void:
	if FILTERS[filter] == &"":
		_fit_story()
		return
	var box := Rect2()
	var any := false
	for b: StringName in shown():
		var p: Vector2 = map.beats[b].pos
		if not p.is_finite():
			continue
		box = box.expand(p) if any else Rect2(p, Vector2.ZERO)
		any = true
	if not any:
		return
	box = box.grow(maxf(box.size.x, box.size.y) * 0.1 + 12.0)
	var r := map_rect()
	var want := minf(r.size.x / maxf(1.0, box.size.x), r.size.y / maxf(1.0, box.size.y))
	scale = _widest
	for sc: float in scales():
		if sc <= want:
			scale = sc
	_centre_on(box.get_center())


func _filter_value(kind: StringName) -> Variant:
	if chosen == &"":
		return null
	var d: Dictionary = map.beats[chosen]
	match kind:
		&"arc":
			return d.arc
		&"cast":
			for door: Dictionary in d.doors:
				if door.cast != &"":
					return door.cast
		&"leg":
			return int(d.leg) if int(d.leg) >= 0 else null
	return null


## In ORDER: left and right along the story, up and down to the nearest beat of
## the lane above or below.
func _order_step(action: StringName) -> void:
	if action == &"left" or action == &"right":
		scrub(-1 if action == &"left" else 1)
		return
	var lanes := _lanes()
	if lanes.is_empty():
		return
	if chosen == &"":
		scrub(1)
		return
	var lane := lanes.find(map.beats[chosen].arc)
	var to := clampi(lane + (-1 if action == &"up" else 1), 0, lanes.size() - 1)
	var here := int(map.beats[chosen].order)
	var best := &""
	for b: StringName in shown():
		if map.beats[b].arc != lanes[to]:
			continue
		if best == &"" or absi(int(map.beats[b].order) - here) < absi(int(map.beats[best].order) - here):
			best = b
	if best != &"":
		chosen = best
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func _on_gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1, mb.position)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var hit := _hit(mb.position)
			if hit != &"":
				chosen = hit
				Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
			_drag = hit == &"" and Rect2(map_rect()).has_point(mb.position)
			_overlay.queue_redraw()
	elif mb != null and not mb.pressed:
		_drag = false
	var mm := e as InputEventMouseMotion
	if mm != null and _drag and MODES[mode] == &"world":
		origin_px -= mm.relative
		_apply()


func _hit(p: Vector2) -> StringName:
	var best := &""
	var bd := 18.0 * 18.0
	for h: Dictionary in _hits:
		var d := (h.rect as Rect2).get_center().distance_squared_to(p)
		if (h.rect as Rect2).grow(4).has_point(p) and d < bd:
			bd = d
			best = h.beat
	return best


func keys(_row: Dictionary) -> Array:
	return [[PlayerSettings.cap_of([&"move_up", &"move_left", &"move_down", &"move_right"]), "look" if MODES[mode] == &"world" else "along"],
		[PlayerSettings.cap_of([&"zoom_out", &"zoom_in"]), "scale"],
		[PlayerSettings.cap_of(&"inventory") + " " + PlayerSettings.cap_of(&"craft"), "story order"],
		[PlayerSettings.cap_of(&"map"), "order" if MODES[mode] == &"world" else "world"],
		[PlayerSettings.cap_of(&"drop"), "narrow"], ["esc", "back"]]


# --- how a mark reads -------------------------------------------------------------------

func arc_colour(arc: StringName) -> Color:
	var i := map.arcs.find(arc)
	return ARC_COLOURS[i % ARC_COLOURS.size()] if i >= 0 else UiTheme.TEXT


## How strongly a beat is drawn: kept by the filter and not past the scrub is whole.
func _weight(b: StringName, kept: Dictionary) -> float:
	if not kept.has(b):
		return 0.14
	if chosen != &"" and int(map.beats[b].order) > int(map.beats[chosen].order):
		return 0.5
	return 1.0


## One beat's mark, a square `s` wide at `c`: solid landed, hollow later, ringed
## and lit open, violet withheld.
func _mark(ci: CanvasItem, c: Vector2, s: int, b: StringName, a: float) -> void:
	var col := arc_colour(map.beats[b].arc)
	var st := map.state_of(b)
	var r := Rect2i(Vector2i(c.round()) - Vector2i(s / 2, s / 2), Vector2i(s, s))
	UiDraw.rect(ci, r.grow(2), Color(UiTheme.RIM, 0.9 * a))
	match st:
		&"landed":
			UiDraw.rect(ci, r, Color(col, a))
		&"withheld":
			UiDraw.rect(ci, r, Color(UiTheme.MACHINE[1], a))
			UiDraw.frame(ci, r, Color(UiTheme.MACHINE[4], a))
		&"open":
			UiDraw.frame(ci, r, Color(col, a))
			UiDraw.rect(ci, r.grow(-UiBase.PITCH * 2), Color(col, a))
			var ring := 0.5 + 0.5 * sin(_time * 4.0)
			UiDraw.frame(ci, r.grow(3 + roundi(ring * 2.0)), Color(col, 0.5 * a))
		_:
			UiDraw.frame(ci, r, Color(col, a))
	if bool(map.beats[b].reveal):
		# A revelation carries a point of warning above it: these land one at a time.
		UiDraw.rect(ci, Rect2i(r.position.x + s / 2 - 1, r.position.y - 6, 2 * UiBase.PITCH / 2 + 1, 3), Color(UiTheme.BRIGHT, a))
	if b == chosen:
		UiDraw.frame(ci, r.grow(6), UiTheme.BRIGHT)
		UiDraw.frame(ci, r.grow(7), UiTheme.BRIGHT)
	_hits.append({"rect": Rect2(r), "beat": b})


# --- drawing ----------------------------------------------------------------------------

## The screen's own draw, under the sheet: nothing but the panel; the marks are
## the overlay's, over the sheet.
func draw_wide(ci: CanvasItem) -> void:
	var pr := panel_rect()
	UiSlate.spare(ci, pr)
	_panel(ci, pr)


func _draw_overlay() -> void:
	var ci := _overlay
	_hits.clear()
	if map == null:
		return
	var kept := {}
	for b: StringName in shown():
		kept[b] = true
	if MODES[mode] == &"world":
		_draw_world(ci, kept)
	else:
		_draw_order(ci, kept)
	_draw_rail(ci, kept)
	UiSlate.brackets(ci, sheet_rect().grow(6), UiTheme.TEXT_DIM, 24)


func _draw_world(ci: CanvasItem, kept: Dictionary) -> void:
	var r := map_rect()
	var clip := Rect2(r)
	# The sheet under the story is dimmed, so the story is what is read.
	UiDraw.rect(ci, r, Color(UiTheme.GLASS, 0.4))
	# The scale bar's corner is claimed before any name is laid.
	var placed: Array[Rect2i] = [Rect2i(r.position.x + 6, r.end.y - 34, roundi(UiMapScreen.bar_tiles(scale) * scale) + 110, 34)]
	# A region's own asks: a thin dashed spur from its village to its yard.
	for sa: Dictionary in map.subarcs:
		var st := StoryMap.subarc_state(int(sa.region))
		var col := UiTheme.FAINT if st == &"" else (UiTheme.TEXT if st == &"asked" else UiTheme.BRIGHT)
		var a := to_screen(sa.pos)
		if (sa.from as Vector2).is_finite():
			_dashed(ci, to_screen(sa.from), a, col, 3, 5, clip)
		if clip.has_point(a):
			UiDraw.frame(ci, Rect2i(Vector2i(a.round()) - Vector2i(3, 3), Vector2i(7, 7)), col)
	# The journey: a bold line through the spine's stops, leg by leg.
	for i in range(1, map.spine.size()):
		_thick(ci, to_screen(map.spine[i - 1].pos), to_screen(map.spine[i].pos), Color(UiTheme.PHOSPHOR[1], 0.95), 7.0, clip)
		_thick(ci, to_screen(map.spine[i - 1].pos), to_screen(map.spine[i].pos), Color(UiTheme.PHOSPHOR[2], 0.95), 3.0, clip)
	# Every arc's arrows. Where several arcs run between the same two places they
	# are drawn side by side, each in its own lane of the bundle, so an arc never
	# hides another and shared ground reads as shared.
	var bundle := {}
	for arrow: Dictionary in map.arrows:
		var pa: StringName = map.beats[arrow.from].place
		var pb: StringName = map.beats[arrow.to].place
		if pa == pb:
			continue
		var key := "%s|%s" % [mini(String(pa).hash(), String(pb).hash()), maxi(String(pa).hash(), String(pb).hash())]
		if not bundle.has(key):
			bundle[key] = []
		if not (bundle[key] as Array).has(arrow.arc):
			(bundle[key] as Array).append(arrow.arc)
	for arrow: Dictionary in map.arrows:
		var pa: StringName = map.beats[arrow.from].place
		var pb: StringName = map.beats[arrow.to].place
		if pa == pb:
			continue
		var key := "%s|%s" % [mini(String(pa).hash(), String(pb).hash()), maxi(String(pa).hash(), String(pb).hash())]
		var lane: Array = bundle[key]
		var k := lane.find(arrow.arc)
		var a := to_screen(map.places[pa].pos)
		var b := to_screen(map.places[pb].pos)
		var n := (b - a).orthogonal().normalized()
		# One side of the pair always, so a lane is the same lane both ways.
		if String(pa).hash() > String(pb).hash():
			n = -n
		var off := n * (float(k) - float(lane.size() - 1) * 0.5) * 5.0
		var w := minf(_weight(arrow.from, kept), _weight(arrow.to, kept))
		var col := Color(arc_colour(arrow.arc), w)
		if chosen != &"" and map.beats[chosen].arc == arrow.arc and w >= 1.0:
			_thick(ci, a + off, b + off, Color(UiTheme.RIM, 0.8), 6.0, clip)
		_thick(ci, a + off, b + off, col, 3.0 if chosen == &"" or map.beats[chosen].arc == arrow.arc else 2.0, clip)
		_heads(ci, a + off, b + off, col, clip)
	# The gates into 2029: a door, and where it leads.
	for g: Dictionary in map.gates:
		var s := to_screen(g.pos)
		if not clip.has_point(s):
			continue
		var col := UiTheme.BRIGHT if bool(g.open) else UiTheme.MACHINE[3]
		UiDraw.rect(ci, Rect2i(Vector2i(s.round()) + Vector2i(10, -14), Vector2i(10, 14)), UiTheme.RIM)
		UiDraw.frame(ci, Rect2i(Vector2i(s.round()) + Vector2i(10, -14), Vector2i(10, 14)), col)
	# Stations: each place's beats, a mark apiece, in story order.
	var at := map.at_places()
	var names: Array[Dictionary] = []
	for place: StringName in at:
		var list: Array = at[place]
		var s := to_screen(map.places[place].pos)
		if not clip.grow(-6).has_point(s):
			continue
		var cols := mini(list.size(), 4 if scale < LIST_FROM else 6)
		var rows := ceili(float(list.size()) / cols)
		var cell := 10
		var box := Rect2i(Vector2i(s.round()) - Vector2i(cols * cell / 2 + 4, rows * cell / 2 + 4), Vector2i(cols * cell + 8, rows * cell + 8))
		UiDraw.rect(ci, box, Color(UiTheme.GLASS, 0.92))
		var spine := false
		for stop: Dictionary in map.spine:
			spine = spine or stop.id == place
		UiDraw.frame(ci, box, UiTheme.TEXT if spine else UiTheme.FAINT)
		for i in list.size():
			var c := Vector2(box.position) + Vector2(4 + (i % cols) * cell + cell / 2, 4 + (i / cols) * cell + cell / 2)
			_mark(ci, c, 6, list[i], _weight(list[i], kept))
		placed.append(box.grow(4))
		names.append({"place": place, "box": box, "list": list, "spine": spine})
	# The legs' numbers, at the first stop of each.
	for leg: Dictionary in map.legs:
		if not (leg.pos as Vector2).is_finite():
			continue
		var s := to_screen(leg.pos)
		var disc := Rect2i(Vector2i(s.round()) + Vector2i(-40, -40), Vector2i(26, 26))
		if clip.has_point(Vector2(disc.position)):
			UiDraw.rect(ci, disc, UiTheme.PHOSPHOR[2])
			UiDraw.text_centred(ci, disc.position.x + 13, disc.position.y + 2, str(int(leg.leg) + 1), UiTheme.GLASS)
			placed.append(disc.grow(2))
	# Names last, over nothing already claimed: the spine's always, a station's
	# once there is room, and close in the beats themselves.
	names.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return bool(x.spine) and not bool(y.spine))
	for nm: Dictionary in names:
		# Far out, a place with one beat is named only when it is the chosen one's.
		if not bool(nm.spine) and scale < NAME_FROM and (nm.list as Array).size() < 2 and not (nm.list as Array).has(chosen):
			continue
		var box: Rect2i = nm.box
		var text: String = map.places[nm.place].name
		if (map.places[nm.place] as Dictionary).has("who"):
			text += " · " + str(map.places[nm.place].who)
		var lines: Array[Array] = [[text, UiTheme.TEXT if bool(nm.spine) else UiTheme.TEXT_DIM]]
		if scale >= LIST_FROM:
			for b: StringName in nm.list:
				lines.append([str(map.beats[b].short), Color(arc_colour(map.beats[b].arc), _weight(b, kept))])
		var w := 0
		for l: Array in lines:
			w = maxi(w, UiFont.width(str(l[0])))
		var h := lines.size() * UiTheme.LINE
		var spot := Rect2i()
		var found := false
		for cand: Vector2i in [Vector2i(box.end.x + 6, box.position.y - 2), Vector2i(box.position.x - w - 14, box.position.y - 2),
				Vector2i(box.position.x, box.end.y + 4), Vector2i(box.position.x, box.position.y - h - 4),
				Vector2i(box.end.x + 6, box.end.y + 2), Vector2i(box.position.x - w - 14, box.end.y + 2),
				Vector2i(box.end.x + 6, box.position.y - h - 2), Vector2i(box.position.x - w - 14, box.position.y - h - 2)]:
			var tr := Rect2i(cand, Vector2i(w + 8, h))
			if not r.encloses(tr):
				continue
			var free := true
			for p: Rect2i in placed:
				if p.intersects(tr):
					free = false
					break
			if free:
				spot = tr
				found = true
				break
		if not found:
			continue
		placed.append(spot)
		UiDraw.rect(ci, spot, Color(UiTheme.GLASS, 0.85))
		for i in lines.size():
			UiDraw.text(ci, spot.position + Vector2i(4, i * UiTheme.LINE), str(lines[i][0]), lines[i][1])
	# The scale, as the survey says it.
	var tiles := UiMapScreen.bar_tiles(scale)
	var bw := roundi(tiles * scale)
	var by := r.end.y - 14
	UiDraw.rect(ci, Rect2i(r.position.x + 6, by - 20, bw + 110, 28), Color(UiTheme.GLASS, 0.85))
	UiDraw.rect(ci, Rect2i(r.position.x + 12, by, bw, UiBase.PITCH), UiTheme.TEXT_DIM)
	UiDraw.text(ci, Vector2i(r.position.x + 20 + bw, by - 16), "%d tiles" % tiles, UiTheme.TEXT_DIM)


func _draw_order(ci: CanvasItem, kept: Dictionary) -> void:
	var r := map_rect()
	UiDraw.rect(ci, r, UiTheme.GLASS)
	var lanes := _lanes()
	var list := map.order
	if lanes.is_empty() or list.is_empty():
		return
	const GUTTER := 170
	var head := 30
	var lane_h := float(r.size.y - head - 6) / lanes.size()
	var col_w := float(r.size.x - GUTTER - 10) / list.size()
	var x0 := r.position.x + GUTTER
	var cols := order_columns(list, x0, r.size.x - GUTTER - 10)
	# The legs, as bands with their number and name over them.
	for band: Dictionary in cols.bands:
		var leg := int(band.leg)
		var bx := roundi(float(band.x))
		var bw := roundi(float(band.w))
		UiDraw.rect(ci, Rect2i(bx, r.position.y, bw, r.size.y), UiTheme.GLASS_ROW if leg % 2 == 0 else UiTheme.GLASS)
		UiDraw.vline(ci, bx, r.position.y, r.end.y, UiTheme.FAINT)
		UiDraw.text(ci, Vector2i(bx + 6, r.position.y + 4), DevPage._fit("%d  %s" % [leg + 1, StoryMap.LEGS[leg]], bw - 8), UiTheme.TEXT)
	var placed: Array[Rect2i] = []
	var pos := {}
	for b: StringName in list:
		var lane := lanes.find(map.beats[b].arc)
		if lane < 0:
			continue
		pos[b] = Vector2(float(cols.x[b]), r.position.y + head + (lane + 0.5) * lane_h)
	for i in lanes.size():
		var y := roundi(r.position.y + head + (i + 0.5) * lane_h)
		var col := arc_colour(lanes[i])
		UiDraw.hline(ci, x0, r.end.x - 4, y, Color(col, 0.12))
		UiDraw.text(ci, Vector2i(r.position.x + 6, y - UiFont.SIZE / 2), DevPage._fit(str(StoryContent.ARCS[lanes[i]].title), GUTTER - 12), col)
	# Each arc's beats one to the next, in its own order, placed or not.
	for arc: StringName in lanes:
		var last := &""
		for b: StringName in StoryContent.arc_beats(arc):
			if not pos.has(b):
				continue
			# Two lands' locals are gathered by the arc, not walked between (StoryMap._arrows).
			if last != &"" and not (map.local(map.beats[last].place) and map.local(map.beats[b].place)):
				var col := Color(arc_colour(arc), minf(_weight(last, kept), _weight(b, kept)))
				_thick(ci, pos[last], pos[b], col, 2.0, Rect2(r))
				_heads(ci, pos[last], pos[b], col, Rect2(r))
			last = b
	for b: StringName in pos:
		_mark(ci, pos[b], 8 if col_w >= 8.0 else 6, b, _weight(b, kept))
		placed.append(Rect2i(Vector2i((pos[b] as Vector2).round()) - Vector2i(6, 6), Vector2i(12, 12)))
	# Words where they fit: the chosen beat's first, then every revelation, then the rest.
	var want: Array[StringName] = []
	if chosen != &"" and pos.has(chosen):
		want.append(chosen)
	for b: StringName in list:
		if pos.has(b) and bool(map.beats[b].reveal) and not want.has(b):
			want.append(b)
	for b: StringName in list:
		if pos.has(b) and not want.has(b):
			want.append(b)
	for b: StringName in want:
		var text := str(map.beats[b].short)
		var p: Vector2 = pos[b]
		var w := UiFont.width(text) + 6
		for cand: Vector2i in [Vector2i(roundi(p.x) + 8, roundi(p.y) - UiFont.SIZE - 2), Vector2i(roundi(p.x) + 8, roundi(p.y) + 4)]:
			var tr := Rect2i(cand, Vector2i(w, UiFont.SIZE))
			if not r.encloses(tr):
				continue
			var free := true
			for q: Rect2i in placed:
				if q.intersects(tr):
					free = false
					break
			if free:
				placed.append(tr)
				UiDraw.text(ci, tr.position + Vector2i(2, 0), text, Color(arc_colour(map.beats[b].arc), _weight(b, kept)))
				break
	if chosen != &"" and pos.has(chosen):
		UiDraw.vline(ci, roundi((pos[chosen] as Vector2).x), r.position.y + head - 4, r.end.y, Color(UiTheme.BRIGHT, 0.35))


## Where each beat of `list` (in story order) stands across `width` pixels from
## `x0`: {x: beat -> x, bands: [{leg, x, w}]}. Each leg is a band as wide as its
## beats need, and never narrower than its own name, so a leg of three beats is
## still a leg you can read.
func order_columns(list: Array[StringName], x0: int, width: int) -> Dictionary:
	var counts: Array[int] = []
	var legs: Array[int] = []
	for b: StringName in list:
		var leg := int(map.beats[b].at_leg)
		if legs.is_empty() or legs[-1] != leg:
			legs.append(leg)
			counts.append(0)
		counts[-1] += 1
	# Every band its name first; what is left is shared by how many beats each holds.
	var least: Array[float] = []
	var need := 0.0
	for i in legs.size():
		least.append(float(UiFont.width("%d  %s" % [legs[i] + 1, StoryMap.LEGS[legs[i]]]) + 16))
		need += least[i]
	var spare := maxf(0.0, width - need)
	var k := minf(1.0, float(width) / maxf(1.0, need))
	var out := {"x": {}, "bands": []}
	var x := float(x0)
	var at := 0
	for i in legs.size():
		var w := least[i] * k + spare * counts[i] / maxf(1.0, list.size())
		(out.bands as Array).append({"leg": legs[i], "x": x, "w": w})
		for j in counts[i]:
			out.x[list[at]] = x + (j + 0.5) * w / counts[i]
			at += 1
		x += w
	return out


## The arcs that have a beat the filter keeps, in ARCS order.
func _lanes() -> Array[StringName]:
	var out: Array[StringName] = []
	var list := shown()
	for arc: StringName in map.arcs:
		for b: StringName in list:
			if map.beats[b].arc == arc:
				out.append(arc)
				break
	return out


## Beats this world has no place for, in story order, each with its arc's colour.
func _draw_rail(ci: CanvasItem, kept: Dictionary) -> void:
	var r := rail_rect()
	UiDraw.rect(ci, r, UiTheme.GLASS)
	UiDraw.frame(ci, r, UiTheme.FAINT)
	var title := "no place on this world  %d" % map.unplaced.size() if MODES[mode] == &"world" else "every beat  %d" % map.order.size()
	UiDraw.text(ci, Vector2i(r.position.x + 8, r.position.y + 4), title, UiTheme.TEXT_DIM)
	if MODES[mode] != &"world":
		UiDraw.text(ci, Vector2i(r.position.x + 8, r.position.y + 4 + UiTheme.LINE), "x is story order, left to right; a lane is an arc", UiTheme.TEXT_DIM)
		return
	var x := r.position.x + 8
	var y := r.position.y + 4 + UiTheme.LINE + 8
	for b: StringName in map.order:
		if not map.unplaced.has(b):
			continue
		if x > r.end.x - 14:
			break
		_mark(ci, Vector2(x + 4, y + 4), 8, b, _weight(b, kept))
		x += 14
	if chosen != &"" and map.unplaced.has(chosen):
		UiDraw.text_right(ci, r.end.x - 8, r.position.y + 4, "%s: %s" % [map.beats[chosen].short, map.beats[chosen].why], UiTheme.TEXT)


# --- the panel ---------------------------------------------------------------------------

func _panel(ci: CanvasItem, r: Rect2i) -> void:
	if map == null:
		return
	var y := r.position.y + 12
	y = panel_heading(ci, r, y, "%s · seed %d" % ["world" if MODES[mode] == &"world" else "order", map.seed_value], true)
	var f := "everything"
	match FILTERS[filter]:
		&"arc": f = "the arc: %s" % str(StoryContent.ARCS[filter_value].title)
		&"cast": f = "the person: %s" % StoryCast.get_def(StringName(str(filter_value))).name
		&"leg": f = "the leg: %d %s" % [int(filter_value) + 1, StoryMap.LEGS[int(filter_value)]]
	y = panel_pair(ci, r, y, "showing", f)
	y = panel_pair(ci, r, y, "beats", "%d, %d placed" % [map.beats.size(), map.beats.size() - map.unplaced.size()])
	y += 8
	if chosen == &"":
		y = _arcs_panel(ci, r, y)
	else:
		y = _chosen_panel(ci, r, y)
	_legend(ci, r)


func _chosen_panel(ci: CanvasItem, r: Rect2i, y: int) -> int:
	var d: Dictionary = map.beats[chosen]
	var col := arc_colour(d.arc)
	UiSlate.heading(ci, Vector2i(panel_x(r), y), "%s  %d of %d" % [str(StoryContent.ARCS[d.arc].title), int(d.index) + 1, int(d.of)], panel_right(r), col)
	y += UiTheme.LINE + 8
	y = panel_line(ci, r, y, str(d.short) + ("  (a revelation)" if bool(d.reveal) else ""), UiTheme.BRIGHT)
	y = panel_wrapped(ci, r, y, "\"%s\"" % str(d.says), UiTheme.TEXT)
	y = panel_pair(ci, r, y, "now", String(map.state_of(chosen)))
	y = panel_pair(ci, r, y, "lands at", str(map.places[d.place].name) if d.place != &"" else "nowhere here")
	if d.place == &"":
		y = panel_wrapped(ci, r, y, str(d.why))
	y = panel_pair(ci, r, y, "leg", "%d  %s" % [int(d.at_leg) + 1, StoryMap.LEGS[int(d.at_leg)]])
	y = panel_pair(ci, r, y, "story order", "%d of %d" % [int(d.order) + 1, map.order.size()])
	y += 6
	y = panel_heading(ci, r, y, "what lands it")
	var shown_doors := 0
	for door: Dictionary in d.doors:
		if y > r.end.y - 180 or shown_doors >= 4:
			break
		shown_doors += 1
		var who := str(door.speaker)
		var what := "%s %s" % [_door_word(door.kind), who if who != "" else String(door.id)]
		if door.node != &"":
			what += " · %s" % door.node
		y = panel_line(ci, r, y, what, UiTheme.TEXT)
		y = panel_line(ci, r, y, "  " + str(door.source), UiTheme.MACHINE[3])
	if d.doors.size() > shown_doors:
		y = panel_line(ci, r, y, "and %d more" % (d.doors.size() - shown_doors), UiTheme.TEXT_DIM)
	y = panel_line(ci, r, y, "the beat  " + str(d.source), UiTheme.MACHINE[3])
	return y


## Every arc in its colour, how much of it the player knows, and where it runs.
func _arcs_panel(ci: CanvasItem, r: Rect2i, y: int) -> int:
	y = panel_heading(ci, r, y, "the arcs")
	for arc: StringName in map.arcs:
		var col := arc_colour(arc)
		var n := StoryContent.arc_beats(arc).size()
		var got := roundi(Story.at(arc) * n)
		var legs := PackedStringArray()
		for b: StringName in StoryContent.arc_beats(arc):
			var l := str(int(map.beats[b].at_leg) + 1)
			if not legs.has(l):
				legs.append(l)
		legs.sort()
		UiDraw.rect(ci, Rect2i(panel_x(r) + 8, y + 8, 22, 4), col)
		UiDraw.text(ci, Vector2i(panel_x(r) + 38, y), str(StoryContent.ARCS[arc].title), col)
		UiDraw.text_right(ci, panel_right(r), y, "%d of %d  legs %s" % [got, n, ",".join(legs)], UiTheme.TEXT_DIM)
		y += UiTheme.LINE
	y += 6
	return panel_wrapped(ci, r, y, "Each line is an arc, arrowed beat to beat in the order they land. The bold line is the journey. Tab walks the story in order.")


static func _door_word(kind: StringName) -> String:
	match kind:
		&"talk": return "said by"
		&"fragment_placed", &"fragment_land", &"room": return "read in"
		&"keeper": return "kept by"
		&"testimony": return "read off"
		&"witness": return "seen:"
		&"secret": return "the secret:"
	return String(kind)


func _legend(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.end.y - 5 * UiTheme.LINE - 14
	y = panel_heading(ci, r, y, "marks")
	var x := panel_x(r) + 8
	var items := [["landed", 0], ["open", 1], ["withheld", 2], ["later", 3]]
	for it: Array in items:
		var c := Vector2(x + 5, y + UiFont.SIZE / 2)
		var rr := Rect2i(Vector2i(c) - Vector2i(4, 4), Vector2i(8, 8))
		match int(it[1]):
			0: UiDraw.rect(ci, rr, UiTheme.TEXT)
			1:
				UiDraw.frame(ci, rr, UiTheme.TEXT)
				UiDraw.frame(ci, rr.grow(3), Color(UiTheme.TEXT, 0.5))
			2:
				UiDraw.rect(ci, rr, UiTheme.MACHINE[1])
				UiDraw.frame(ci, rr, UiTheme.MACHINE[4])
			3: UiDraw.frame(ci, rr, UiTheme.TEXT)
		UiDraw.text(ci, Vector2i(x + 16, y), str(it[0]), UiTheme.TEXT_DIM)
		x += UiFont.width(str(it[0])) + 36
	y += UiTheme.LINE + 4
	UiDraw.rect(ci, Rect2i(panel_x(r) + 8, y + 8, 30, 5), UiTheme.PHOSPHOR[2])
	UiDraw.text(ci, Vector2i(panel_x(r) + 46, y), "the journey", UiTheme.TEXT_DIM)
	_dashed(ci, Vector2(panel_x(r) + 200, y + 10), Vector2(panel_x(r) + 230, y + 10), UiTheme.TEXT, 3, 5, Rect2(r))
	UiDraw.text(ci, Vector2i(panel_x(r) + 238, y), "a region asks", UiTheme.TEXT_DIM)
	y += UiTheme.LINE + 4
	UiDraw.frame(ci, Rect2i(panel_x(r) + 12, y + 2, 10, 14), UiTheme.MACHINE[3])
	UiDraw.text(ci, Vector2i(panel_x(r) + 46, y), "a gate into 2029", UiTheme.TEXT_DIM)


# --- lines ---------------------------------------------------------------------------------

## A line `w` pixels wide from a to b, cut to `clip`.
static func _thick(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, clip: Rect2) -> void:
	var seg := _clip(a, b, clip)
	if seg.is_empty():
		return
	ci.draw_line(seg[0], seg[1], col, w)


## Chevrons along a line pointing from a to b, one every 70 pixels and at least one.
static func _heads(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, clip: Rect2) -> void:
	var len := a.distance_to(b)
	if len < 14.0:
		return
	var dir := (b - a) / len
	var n := dir.orthogonal()
	var count := maxi(1, floori(len / 70.0))
	for i in count:
		var t := (float(i) + 0.6) / float(count)
		var p := a.lerp(b, t)
		if not clip.has_point(p):
			continue
		ci.draw_line(p + dir * 2.0, p - dir * 9.0 + n * 6.0, col, 3.0)
		ci.draw_line(p + dir * 2.0, p - dir * 9.0 - n * 6.0, col, 3.0)


static func _dashed(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, on: int, off: int, clip: Rect2) -> void:
	var seg := _clip(a, b, clip)
	if seg.is_empty():
		return
	ci.draw_dashed_line(seg[0], seg[1], col, 2.0, float(on + off))


## The part of a..b inside `r` (Liang-Barsky), or [] when none is.
static func _clip(a: Vector2, b: Vector2, r: Rect2) -> Array[Vector2]:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for pair: Array in [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y], [d.y, r.end.y - a.y]]:
		var p: float = pair[0]
		var q: float = pair[1]
		if is_zero_approx(p):
			if q < 0.0:
				return []
			continue
		var t := q / p
		if p < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return []
	return [a + d * t0, a + d * t1]
