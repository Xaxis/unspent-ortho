class_name UiMapScreen
extends UiScreen
## The survey app (M): the whole world's SHAPE, with the land the player has
## walked drawn in full, as the slate's scanner draws it (src/ui/map.gdshader) --
## regions lettered over their own land, villages, the places found on the way
## (landmarks), the machines' lines in the module's violet, and the way the
## player came. Arrows look around a step at a time (held keys repeat, per the
## menu standard); E changes the scale; M or Esc close.
##
## **WALKING BUYS DETAIL, NOT EXISTENCE** (owner, 2026-09-19). This app used to
## draw only what had been seen, which on a 1300-tile world is a smear on an
## empty field -- the readout says 0.1% of the land seen after a long walk, and
## that number was the whole picture. Now every tile's landmass, water and
## coarse landscape value are there from the first time it is opened, dimmed to
## `UNSEEN_LIGHT`, and what a player earns by going there is the contours, the
## hatch, the roads, the symbols, the soundings and the names.

## The survey is a PICTURE, so it kept the share of the frame it always had and
## is simply drawn at three times the detail: its window and every scale below
## are the old numbers times three, and the same span of land is on the glass.
## Its lettering, its marks and its legend are TYPE, and came down with the type.
##
## The window sits in the body's left margin and stops at the right one, so it is
## clear of the dead column and of the crack (tests/ui/test_map.gd holds it).
const HEADER_Y := UiSlate.BODY.position.y + 12
const MAP_RECT := Rect2i(UiSlate.BODY.position.x + UiSlate.MARGIN_L, UiSlate.BODY.position.y + 45,
	UiSlate.BODY.size.x - UiSlate.MARGIN_L - UiSlate.MARGIN_R, 810)
const PAN_STEP := 36
## Survey pixels to a tile. The widest view, SCALES[0], is one pixel of the OLD
## slate to a tile, which is what "a pixel a tile" means everywhere below.
const SCALES: Array[int] = [3, 6, 9, 12, 18]
## Clear space kept round the land seen when the survey opens, in survey pixels.
const MARGIN := 72
## From this scale up there is room to name a place beside its mark.
const NAME_FROM := 9
## Seconds the scanner's line takes to cross the survey.
const SWEEP_SECONDS := 3.2
## The widest step of all, and the only one that is COMPUTED: what puts the whole
## world on the glass at once (owner, 2026-09-19, "zoom out and view the ENTIRE
## map"). It cannot be a constant beside `SCALES`, because it is a ratio between
## two things that both move -- 1300 tiles into 810 survey pixels is 0.62 of a
## pixel a tile, and the next world size changes it. It is offered only when the
## world does not already fit at `SCALES[0]`, so a small world never grows a
## redundant step, and `SCALES` itself is untouched so `fit()` and everything
## holding it still mean what they meant.
static func whole_world(world_size: int, window: Vector2i) -> float:
	return minf(float(window.x) / maxf(1.0, world_size), float(window.y) / maxf(1.0, world_size))

var explored: UiExplored
var data: UiMapData
var map_scale := 6.0
## Map pixel (tile * map_scale) under the window's top-left pixel.
var origin_px := Vector2i.ZERO

var _rect: ColorRect
## The survey is drawn once into this each time it moves, not every frame.
var _viewport: SubViewport
var _overlay: Control
var _material: ShaderMaterial
var _seen_tex: ImageTexture
var _regions: Array[Dictionary] = []
var _seen_share := 0.0
var _time := 0.0


func _init() -> void:
	super()
	screen_name = &"map"
	own_action = &"map"
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/ui/map.gdshader")
	for pair: Array in [["glass", UiTheme.GLASS], ["ph0", UiTheme.PHOSPHOR[0]], ["ph1", UiTheme.PHOSPHOR[1]], ["ph2", UiTheme.PHOSPHOR[2]], ["ph3", UiTheme.PHOSPHOR[3]], ["ph4", UiTheme.PHOSPHOR[4]], ["violet", UiTheme.MACHINE[2]]]:
		var c: Color = pair[1]
		_material.set_shader_parameter(pair[0], Vector3(c.r, c.g, c.b))
	_viewport = SubViewport.new()
	_viewport.name = "sheet"
	_viewport.size = MAP_RECT.size
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_rect = ColorRect.new()
	_rect.name = "map"
	_rect.size = Vector2(MAP_RECT.size)
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_rect)
	var shown := TextureRect.new()
	shown.name = "shown"
	shown.position = Vector2(MAP_RECT.position)
	shown.size = Vector2(MAP_RECT.size)
	shown.texture = _viewport.get_texture()
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shown)
	_overlay = Control.new()
	_overlay.name = "marks"
	_overlay.size = Vector2(UiBase.SIZE)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _on_open() -> void:
	if game == null:
		return
	if data == null:
		data = UiMapData.new(game.world)
	data.ensure()
	if explored == null:
		explored = UiExplored.new(game.world.size)
	# A SURVEY OF 0.3% OF THE LAND IS NOT A SURVEY. The map draws only what has
	# been walked, which is right for a player and useless for the person
	# reviewing the world: on 1300 tiles across five continents, a long walk
	# reveals a fraction of a percent and the shape of it reads as a wedge rather
	# than a map (owner, 2026-09-18: "it only renders like a large triangle at a
	# time and never the entire thing"). Where dev mode is open at all, the whole
	# thing is shown -- the reveal already existed and was a row somebody had to
	# find, which is the same as not existing.
	if DevMode.reachable() and not explored.revealed:
		explored.reveal_all(game.world)
	_seen_tex = ImageTexture.create_from_image(Image.create_from_data(explored.size, explored.size, false, Image.FORMAT_L8, explored.shown_mask()))
	_material.set_shader_parameter("ground_tex", data.ground)
	_material.set_shader_parameter("level_tex", data.level)
	_material.set_shader_parameter("coast_tex", data.coast)
	_material.set_shader_parameter("marks_tex", data.marks)
	_material.set_shader_parameter("palette_tex", data.palette)
	_material.set_shader_parameter("country_tex", data.country)
	_material.set_shader_parameter("seen_tex", _seen_tex)
	_material.set_shader_parameter("rect_size", Vector2(MAP_RECT.size))
	_material.set_shader_parameter("world_size", float(game.world.size))
	# World tiles to one texel: the survey is built at a capped size so its cost
	# does not follow the world's (UiMapData.MOST).
	_material.set_shader_parameter("tex_step", float(data.step))
	_regions = UiMapScreen.region_labels(game.world, explored)
	_seen_share = explored.fraction()
	var f := UiMapScreen.fit(explored.shown_bounds(), game.player.pos, MAP_RECT.size, SCALES)
	map_scale = f.scale
	centre_on(f.centre)


## The scale and centre that show the land seen so far: the largest scale at
## which all of it fits the window, centred on it, but never with the player
## off the survey. {scale: int, centre: Vector2 (tiles)}
static func fit(seen: Rect2i, player: Vector2, window: Vector2i, scales: Array[int]) -> Dictionary:
	# A little land running off the survey is better than all of it drawn too small.
	const OVERFLOW := 1.3
	var s := scales[0]
	for k in scales:
		if seen.size.x * k <= (window.x - MARGIN * 2) * OVERFLOW and seen.size.y * k <= (window.y - MARGIN * 2) * OVERFLOW:
			s = maxi(s, k)
	var centre := Vector2(seen.get_center()) if seen.size != Vector2i.ZERO else player
	# Drawn a pixel a tile, land that fills less than half the window is a stamp in
	# an empty frame: a step closer reads as a survey. The player stays on it.
	if s == SCALES[0] and scales.has(SCALES[1]) and seen.size.x * SCALES[0] * seen.size.y * SCALES[0] * 2 < window.x * window.y:
		s = SCALES[1]
	var reach := (Vector2(window) * 0.5 - Vector2(MARGIN, MARGIN)) / s
	centre = centre.clamp(player - reach, player + reach)
	return {"scale": s, "centre": centre}


## Where to letter each region the player has seen enough of: the seen tile of
## that landscape deepest inside it (most of its neighbourhood the same), so a
## name sits over its own land rather than a neighbour's.
## [{text, at: Vector2, country, seen}]
static func region_labels(w: WorldData, seen: UiExplored) -> Array[Dictionary]:
	const STEP := 4
	const ENOUGH := 120 # seen tiles before a region is worth naming
	const REACH := 2 # neighbourhood, in coarse cells
	var n := ceili(w.size / float(STEP))
	var cells := PackedInt32Array()
	cells.resize(n * n)
	var counts := {}
	for cy in n:
		for cx in n:
			var x := cx * STEP + STEP / 2
			var y := cy * STEP + STEP / 2
			var c := -1
			if x < w.size and y < w.size and seen.seen(x, y) and w.level_at(x, y) > 0:
				c = w.country_at(x, y)
				counts[c] = int(counts.get(c, 0)) + 1
			cells[cy * n + cx] = c
	var best := {}
	for cy in n:
		for cx in n:
			var c := cells[cy * n + cx]
			if c < 0 or int(counts[c]) * STEP * STEP < ENOUGH:
				continue
			var score := 0
			for dy in range(-REACH, REACH + 1):
				for dx in range(-REACH, REACH + 1):
					var qx := cx + dx
					var qy := cy + dy
					if qx >= 0 and qy >= 0 and qx < n and qy < n and cells[qy * n + qx] == c:
						score += 1
			if not best.has(c) or score > int(best[c][0]):
				best[c] = [score, Vector2(cx * STEP + STEP / 2.0, cy * STEP + STEP / 2.0)]
	var out: Array[Dictionary] = []
	for c: int in best:
		var at: Vector2 = best[c][1]
		var name := BiomeRegistry.at(w, at).display_name.to_upper()
		var spaced := ""
		for i in name.length():
			spaced += (" " if i > 0 else "") + name[i]
		out.append({"text": spaced, "at": at, "country": c, "seen": int(counts[c]) * STEP * STEP})
	# The region seen most is lettered first; a crowded label gives way to it.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.seen > b.seen)
	return out


## THE MARK A PLACE IS DRAWN WITH, seven by seven, keyed by `LandmarkDef.mark`
## (src/core/landmarks). A survey with nine identical diamonds on it says only
## that there are nine of them; the whole reason a landmark is worth remembering
## is that it is a PARTICULAR place, and the mark is where the survey says which.
## Everything the world already knew about — a tip, a wreck, a shaft — keeps the
## diamond, so the marks that mean "somewhere worth the walk" stand apart.
const MARKS := {
	&"light": ["   #   ", "  # #  ", "  # #  ", " #   # ", " #   # ", "#     #", "#######"],
	&"tower": [" ##### ", " #   # ", " ##### ", "  # #  ", "  # #  ", " #   # ", "#     #"],
	&"mast": ["     ##", "    ## ", "   ##  ", "  ##   ", " ##    ", "##     ", "###    "],
	&"stack": [" ##### ", "  ###  ", "  # #  ", "  ###  ", "  # #  ", "  ###  ", " ##### "],
	&"stones": ["       ", "#  #  #", "#  #  #", "#  #  #", "#  #  #", "#  #  #", "#######"],
	&"evaporator": ["       ", "     ##", "#######", "#######", "#     #", "#     #", "       "],
	&"hulk": ["       ", "###    ", "###  ##", "### ###", "  # #  ", "  # #  ", "  # #  "],
	&"files": ["       ", "#######", "#     #", "# ### #", "#     #", "#######", "       "],
	&"pillar": [" ##### ", "  ###  ", "  ###  ", "  ###  ", "  ###  ", "  ###  ", " ##### "],
	&"sump": ["  ###  ", " #   # ", " #   # ", "  ###  ", "       ", "## ## #", " ## ## "],
}


## The mark for a place found on the way, or an empty list for the diamond.
static func mark_for(kind: StringName) -> Array:
	var d := Landmarks.by_id(kind)
	if d == null or not MARKS.has(d.mark):
		return []
	return MARKS[d.mark]


## Landmarks the player has seen: the discoveries. [{kind, pos, machine: bool}]
static func discoveries(w: WorldData, seen: UiExplored) -> Array[Dictionary]:
	const MACHINE_MADE: Array[StringName] = [&"tip", &"wreck"]
	var out: Array[Dictionary] = []
	for l: Dictionary in w.landmarks:
		var p: Vector2 = l.get("pos", Vector2(-1, -1))
		var kind := StringName(l.get("kind", &""))
		if kind == &"bridge" or kind == &"falls":
			continue
		if seen != null and seen.seen(floori(p.x), floori(p.y)):
			out.append({"kind": kind, "pos": p, "machine": MACHINE_MADE.has(kind)})
	return out


## Where to letter a region name (top-left, screen px), or x < -1000 when no
## candidate is free. `free` says whether a box is clear of other lettering.
func place_region(label: Dictionary, free: Callable) -> Vector2i:
	var text: String = label.text
	var w := UiFont.width(text)
	var s := to_screen(label.at)
	var best := Vector2i(-9999, 0)
	var best_score := INF
	var xs: Array[int] = [s.x - w / 2, s.x - w / 2 - w / 4, s.x - w / 2 + w / 4]
	for dy: int in [0, -UiTheme.LINE, UiTheme.LINE, -UiTheme.LINE * 2, UiTheme.LINE * 2]:
		for x: int in xs:
			var at := Vector2i(x, s.y - UiFont.SIZE / 2 + dy)
			var moved := absi(x - (s.x - w / 2)) + absi(dy)
			var text_r := Rect2i(at, Vector2i(w, UiFont.SIZE))
			var box := text_r.grow(6)
			if not MAP_RECT.grow(-12).encloses(text_r) or not free.call(box):
				continue
			if moved > w:
				continue
			var t := to_tiles(box)
			var mid := t.get_center()
			# Never letter a name off its own land (into the unknown or a neighbour).
			if moved > 0 and (explored == null or not explored.seen(mid.x, mid.y) or game.world.country_at(mid.x, mid.y) != int(label.country)):
				continue
			var mean := 0.0
			if data != null:
				mean = UiMapData.ink_in(data.ink, data.tex_size, Rect2i(t.position / data.step, \
					Vector2i(maxi(1, t.size.x / data.step), maxi(1, t.size.y / data.step)))) \
					/ float(maxi(1, (t.get_area()) / (data.step * data.step)))
			var score := mean + moved * 0.006
			if score < best_score:
				best_score = score
				best = at
	return best


func _free_of(placed: Array[Rect2i]) -> Callable:
	return func(box: Rect2i) -> bool: return not placed.any(func(o: Rect2i) -> bool: return o.intersects(box))


## The tiles under a screen rect.
func to_tiles(r: Rect2i) -> Rect2i:
	var a := r.position - MAP_RECT.position + origin_px
	var b := r.end - MAP_RECT.position + origin_px
	var lo := Vector2i(floori(a.x / float(map_scale)), floori(a.y / float(map_scale)))
	var hi := Vector2i(ceili(b.x / float(map_scale)), ceili(b.y / float(map_scale)))
	return Rect2i(lo, hi - lo)


## A patch of glass cleared under a name over the survey, its corners left open.
## Opaque: at 0.88 the coastline and the contours came through the letters, and
## a name over a drawn coast has to be read in one look.
static func clearing(ci: CanvasItem, box: Rect2i) -> void:
	var col := UiTheme.GLASS
	UiDraw.rect(ci, Rect2i(box.position.x + 2, box.position.y, box.size.x - 4, box.size.y), col)
	UiDraw.rect(ci, Rect2i(box.position.x, box.position.y + 2, box.size.x, box.size.y - 4), col)


## Put tile-space point `p` in the middle of the survey's window.
func centre_on(p: Vector2) -> void:
	origin_px = Vector2i(roundi(p.x * map_scale), roundi(p.y * map_scale)) - _anchor()
	_apply()


func _anchor() -> Vector2i:
	return MAP_RECT.size / 2


## Every scale the key offers, widest first.
func steps() -> Array[float]:
	var out: Array[float] = []
	if game != null:
		var whole := UiMapScreen.whole_world(game.world.size, MAP_RECT.size)
		if whole < float(SCALES[0]):
			out.append(whole)
	for s: int in SCALES:
		out.append(float(s))
	return out


## Whether the survey is showing the world whole -- the one step at which there
## is no more to zoom out to, and the readout says so instead of a ratio.
func at_whole_world() -> bool:
	var all := steps()
	return all.size() > SCALES.size() and is_equal_approx(map_scale, all[0])


func handle(action: StringName) -> bool:
	if not is_open:
		return false
	match action:
		&"up": _pan(Vector2i(0, -PAN_STEP))
		&"down": _pan(Vector2i(0, PAN_STEP))
		&"left": _pan(Vector2i(-PAN_STEP, 0))
		&"right": _pan(Vector2i(PAN_STEP, 0))
		&"confirm":
			var centre := Vector2(origin_px + _anchor()) / map_scale
			var all := steps()
			var at := 0
			for i in all.size():
				if is_equal_approx(all[i], map_scale):
					at = i
					break
			map_scale = all[(at + 1) % all.size()]
			if game != null:
				if at_whole_world():
					# The step whose whole purpose is the world entire centres the
					# WORLD. Centring on the player here is what the other steps
					# want and it put a 1300-tile island in the right-hand half of
					# the glass with the rest empty -- a picture of where he is
					# standing, at the one scale that is not about that.
					centre = Vector2(game.world.size, game.world.size) * 0.5
				else:
					# Zoom about the middle, but never leave the player off the survey.
					var reach := (Vector2(MAP_RECT.size) * 0.5 - Vector2(MARGIN, MARGIN)) / map_scale
					centre = centre.clamp(game.player.pos - reach, game.player.pos + reach)
			centre_on(centre)
			Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		_:
			return super(action)
	return true


## --screen=map:3 opens at that scale (the survey has no rows to choose).
func select(id: StringName) -> void:
	var s := String(id).to_int()
	if SCALES.has(s) and game != null:
		var f := UiMapScreen.fit(explored.shown_bounds(), game.player.pos, MAP_RECT.size, [s])
		map_scale = float(s)
		centre_on(f.centre)


func _pan(d: Vector2i) -> void:
	origin_px += d
	_apply()


func _apply() -> void:
	if game != null:
		# Keep some of the world in the window: stop a half-window past its edge.
		var world_px := roundi(game.world.size * map_scale)
		var half := MAP_RECT.size / 2
		origin_px.x = clampi(origin_px.x, -half.x, maxi(-half.x, world_px - half.x))
		origin_px.y = clampi(origin_px.y, -half.y, maxi(-half.y, world_px - half.y))
	_material.set_shader_parameter("origin_px", Vector2(origin_px))
	_material.set_shader_parameter("scale", float(map_scale))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()
	_overlay.queue_redraw()


## Screen position of tile-space point p.
func to_screen(p: Vector2) -> Vector2i:
	return MAP_RECT.position + Vector2i(floori(p.x * map_scale), floori(p.y * map_scale)) - origin_px


func _process(delta: float) -> void:
	super(delta)
	if is_open:
		_time += delta
		_overlay.queue_redraw()


func _draw() -> void:
	draw_frame()
	var r := MAP_RECT
	UiDraw.text(self, Vector2i(r.position.x, HEADER_Y), "SURVEY", UiTheme.TEXT)
	# The survey's grid of points on the glass, where nothing has been seen yet.
	var y := r.position.y + 10
	while y < r.end.y:
		var x := r.position.x + 10
		while x < r.end.x:
			UiDraw.px(self, x, y, UiTheme.GHOST)
			x += 24
		y += 24
	if game == null:
		draw_keys([["esc", "back"]])
		return
	var p := game.player.pos
	var here := BiomeRegistry.at(game.world, p).display_name
	UiDraw.text(self, Vector2i(r.position.x + 100, HEADER_Y), here, UiTheme.BRIGHT)
	UiDraw.text_right(self, r.end.x, HEADER_Y, "%s of the land seen   %s" % [UiRules.share(_seen_share), ("whole world" if at_whole_world() else "1:%d" % roundi(map_scale))], UiTheme.TEXT_DIM)
	draw_keys([["wasd", "look"], ["e", "scale"], ["m", "close"], ["esc", "back"]])


func _draw_overlay() -> void:
	var ci := _overlay
	var r := MAP_RECT
	UiSlate.brackets(ci, r.grow(6), UiTheme.TEXT_DIM, 24)
	if game == null:
		return
	var me := to_screen(game.player.pos)
	var me_rect := Rect2i(me.x - 12, me.y - 12, 26, 26)
	var inner := r.grow(-2)
	# Every mark on the survey is cut on the module's own grid, one pixel of glass
	# to a pixel of the shape, so the shapes are drawn exactly as they were written.
	var p := UiBase.PITCH
	# The machines' lines, pylon to pylon, in the module's violet: their order
	# cut straight across the land, shown where the player has seen it.
	for line: Dictionary in game.world.lines:
		var ids: PackedInt32Array = line.get("props", PackedInt32Array())
		for i in range(1, ids.size()):
			if ids[i - 1] >= game.world.props.size() or ids[i] >= game.world.props.size():
				continue
			var a := game.world.props[ids[i - 1]].pos
			var b := game.world.props[ids[i]].pos
			if explored == null or not (explored.seen(floori(a.x), floori(a.y)) or explored.seen(floori(b.x), floori(b.y))):
				continue
			_dotted(ci, to_screen(a), to_screen(b), Color(UiTheme.MACHINE[2], 0.85), 4, inner)
			var s := to_screen(b)
			if inner.has_point(s):
				UiDraw.rect(ci, Rect2i(s.x - 2, s.y - 2, 6, 6), UiTheme.MACHINE[3])
	# Everything with a fixed place on the survey is claimed before a word is
	# laid anywhere: you-are-here with its ping ring, the compass and the scale
	# bar. A name is lettered last and over none of them.
	#
	# `placed` is what a name must never sit on. `words` is only the lettering:
	# when a name can find nowhere clear of the marks as well, it takes the best
	# place clear of the other words and its clearing covers the mark under it.
	# A name that gives way to a diamond is a name nobody reads.
	var placed: Array[Rect2i] = [Rect2i(me.x - 32, me.y - 32, 66, 66), Rect2i(r.end.x - 38, r.position.y + 4, 36, 60), Rect2i(r.position.x + 2, r.end.y - 42, roundi(bar_tiles(map_scale) * map_scale) + 108, 40)]
	var words: Array[Rect2i] = placed.duplicate()
	var villages: Array[Dictionary] = []
	for v in game.world.villages:
		var vp: Vector2 = v.pos
		if explored == null or not explored.seen(floori(vp.x), floori(vp.y)):
			continue
		var s := to_screen(vp)
		if not r.grow(-8).has_point(s):
			continue
		var name := String(v.name).to_lower()
		var w := UiFont.width(name)
		var tx := clampi(s.x - w / 2, r.position.x + 4, r.end.x - w - 4)
		var ty := s.y + 12
		if ty + UiFont.SIZE > r.end.y or Rect2i(tx - 4, ty - 2, w + 8, UiTheme.LINE).intersects(me_rect):
			ty = s.y - 32
		var box := Rect2i(tx - 4, ty - 2, w + 8, UiTheme.LINE)
		placed.append(box.grow(4))
		words.append(box.grow(4))
		placed.append(Rect2i(s.x - 6, s.y - 6, 14, 14).grow(4))
		villages.append({"at": s, "name": name, "box": box})
	# Every discovery's diamond is spoken for before a region is lettered. The
	# diamonds used to be drawn after the names and landed on top of them: COAST
	# read C◇AST and SCRAPWOOD SCR◇PWOOD on the canon survey.
	var found_all := UiMapScreen.discoveries(game.world, explored)
	var finds: Array[Dictionary] = []
	for found: Dictionary in found_all:
		var s := to_screen(found.pos)
		if not r.grow(-8).has_point(s):
			continue
		placed.append(Rect2i(s.x - 6, s.y - 6, 14, 14).grow(4))
		finds.append({"at": s, "kind": found.kind, "machine": found.machine})
	# The way the player came, dotted, fading toward the start.
	if explored != null:
		var n := explored.trail.size()
		var step := 0
		for i in range(1, n):
			var a0 := to_screen(explored.trail[i - 1])
			var a1 := to_screen(explored.trail[i])
			# A jump (carried off, a teleport) is not walked: leave a gap.
			if explored.trail[i - 1].distance_to(explored.trail[i]) > 4.0:
				continue
			if not inner.has_point(a0) and not inner.has_point(a1):
				continue
			var col := Color(UiTheme.BRIGHT, (0.3 + 0.6 * float(i) / n) * (0.55 if map_scale <= float(SCALES[0]) else 1.0))
			var d := a1 - a0
			var len := maxi(absi(d.x), absi(d.y))
			# One dot of the module's glass at a time, two in three laid down.
			for k in range(0, len, UiBase.PITCH):
				step += 1
				if step % 3 == 0:
					continue
				var q := a0 + Vector2i(roundi(d.x * k / float(len)), roundi(d.y * k / float(len)))
				if inner.has_point(q):
					UiDraw.px(ci, q.x, q.y, col)
	# The places found on the way: a diamond, violet for what the machines left.
	for found: Dictionary in finds:
		var s: Vector2i = found.at
		var col := UiTheme.MACHINE[3] if found.machine else UiTheme.BRIGHT
		UiDraw.rect(ci, Rect2i(s.x - 3 * p, s.y - 3 * p, 7 * p, 7 * p), Color(UiTheme.GLASS, 0.8))
		var mark := UiMapScreen.mark_for(found.kind)
		if mark.is_empty():
			for k in 4:
				UiDraw.px(ci, s.x + (k - 3) * p, s.y - k * p, col)
				UiDraw.px(ci, s.x + k * p, s.y + (k - 3) * p, col)
				UiDraw.px(ci, s.x + (3 - k) * p, s.y + k * p, col)
				UiDraw.px(ci, s.x - k * p, s.y + (3 - k) * p, col)
		else:
			UiDraw.sprite(ci, mark, Vector2i(s.x - 3 * p, s.y - 3 * p), {"#": col}, p)
		if map_scale >= NAME_FROM:
			var word := String(found.kind).replace("_", " ")
			var box := Rect2i(s.x + 12, s.y - UiFont.SIZE / 2, UiFont.width(word) + 8, UiFont.SIZE)
			if r.grow(-4).encloses(box) and _free_of(placed).call(box):
				placed.append(box)
				UiMapScreen.clearing(ci, box)
				UiDraw.text(ci, box.position + Vector2i(4, 0), word, col)
	for v: Dictionary in villages:
		var s: Vector2i = v.at
		var box: Rect2i = v.box
		UiMapScreen.clearing(ci, box)
		UiDraw.text(ci, box.position + Vector2i(4, 0), v.name, UiTheme.TEXT_DIM)
		UiDraw.rect(ci, Rect2i(s.x - 3 * p, s.y - 3 * p, 7 * p, 7 * p), UiTheme.GLASS)
		# The square round a village is a MARK, so it is a pixel of glass thick and
		# never a hairline: bright ring, glass middle, one lit pixel in the centre.
		UiDraw.rect(ci, Rect2i(s.x - 2 * p, s.y - 2 * p, 5 * p, 5 * p), UiTheme.BRIGHT)
		UiDraw.rect(ci, Rect2i(s.x - p, s.y - p, 3 * p, 3 * p), UiTheme.GLASS)
		UiDraw.px(ci, s.x, s.y, UiTheme.BRIGHT)
	# The scanner's line crossing the survey, slowly, top to bottom. It goes under
	# the lettering with everything else: a line travelling across a name reads
	# as a name struck out, even at six per cent.
	# One pixel of the module's glass thick: a hairline at six per cent is nothing.
	var sweep := r.position.y + roundi(fposmod(_time / SWEEP_SECONDS, 1.0) * r.size.y)
	UiDraw.rect(ci, Rect2i(r.position.x, sweep, r.size.x, p), Color(UiTheme.PHOSPHOR[3], 0.06))
	# Regions, lettered across the land they cover, last of all and over nothing:
	# of the nearby places free of every mark already claimed, the one over the
	# least drawn detail is chosen, and the glass under it is cleared outright.
	for label: Dictionary in _regions:
		var text: String = label.text
		var at := place_region(label, _free_of(placed))
		if at.x < -1000:
			at = place_region(label, _free_of(words))
		if at.x < -1000:
			continue
		var box := Rect2i(at, Vector2i(UiFont.width(text), UiFont.SIZE)).grow(6)
		placed.append(box)
		words.append(box)
		UiMapScreen.clearing(ci, box)
		UiDraw.text(ci, at, text, UiTheme.TEXT)
	# You are here: a bright cross, and a ping ring going out from it.
	if r.has_point(me):
		UiDraw.rect(ci, Rect2i(me.x - 4 * p, me.y - 4 * p, 9 * p, 9 * p), Color(UiTheme.GLASS, 0.75))
		for i in range(-3, 4):
			UiDraw.px(ci, me.x + i * p, me.y, UiTheme.BRIGHT)
			UiDraw.px(ci, me.x, me.y + i * p, UiTheme.BRIGHT)
		var ping := fposmod(_time, 1.6) / 1.6
		var pr := (4.0 + ping * 10.0) * p
		for k in 20:
			var a := k * TAU / 20.0
			var q := me + Vector2i(roundi(cos(a) * pr), roundi(sin(a) * pr))
			if inner.has_point(q):
				UiDraw.px(ci, q.x, q.y, Color(UiTheme.BRIGHT, UiDraw.stepped(1.0 - ping) * 0.6))
	# North, in the corner: the needle is a mark, so it is two pixels of glass wide
	# rather than a rule.
	var nx := r.end.x - 24
	var ny := r.position.y + 12
	UiDraw.rect(ci, Rect2i(nx - 10, ny - 4, 26, 52), Color(UiTheme.GLASS, 0.85))
	UiDraw.text(ci, Vector2i(nx + 2 - UiFont.width("N") / 2, ny), "N", UiTheme.TEXT)
	UiDraw.rect(ci, Rect2i(nx + 2, ny + 22, p, 21), UiTheme.TEXT)
	UiDraw.rect(ci, Rect2i(nx, ny + 24, 3 * p, p), UiTheme.TEXT)
	UiDraw.rect(ci, Rect2i(nx - 2, ny + 26, 5 * p, p), UiTheme.TEXT)
	# A scale bar. It used to be ten tiles always, which is six pixels long once
	# the whole world is on the glass -- a scale bar shorter than its own label
	# measures nothing. It now takes a round number of tiles wide enough to read.
	var tiles := bar_tiles(map_scale)
	var bx := r.position.x + 12
	var by := r.end.y - 16
	var bw := roundi(tiles * map_scale)
	UiDraw.rect(ci, Rect2i(bx - 6, by - 22, bw + 100, 32), Color(UiTheme.GLASS, 0.85))
	UiDraw.rect(ci, Rect2i(bx, by, bw + p, p), UiTheme.TEXT)
	UiDraw.rect(ci, Rect2i(bx, by - 2 * p, p, 3 * p), UiTheme.TEXT)
	UiDraw.rect(ci, Rect2i(bx + bw, by - 2 * p, p, 3 * p), UiTheme.TEXT)
	UiDraw.text(ci, Vector2i(bx + bw + 8, by - 16), "%d tiles" % tiles, UiTheme.TEXT_DIM)


## A round number of tiles whose bar is long enough to be a measure. 1:18 takes
## ten; the whole world takes hundreds.
static func bar_tiles(scale: float) -> int:
	for n: int in [10, 20, 50, 100, 200, 500, 1000]:
		if n * scale >= 90.0:
			return n
	return 1000


static func _dotted(ci: CanvasItem, a: Vector2i, b: Vector2i, col: Color, every: int, clip: Rect2i) -> void:
	var d := b - a
	var len := maxi(absi(d.x), absi(d.y))
	if len == 0:
		return
	for k in range(0, len, every):
		var q := a + Vector2i(roundi(d.x * k / float(len)), roundi(d.y * k / float(len)))
		if clip.has_point(q):
			UiDraw.px(ci, q.x, q.y, col)
