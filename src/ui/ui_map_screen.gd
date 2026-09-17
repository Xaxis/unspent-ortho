class_name UiMapScreen
extends UiScreen
## The survey app (M): only the land the player has seen, as the slate's
## scanner draws it (src/ui/map.gdshader), with regions lettered over their own
## land, villages, the places found on the way (landmarks), the machines' lines
## in the module's violet, and the way the player came. Arrows look around a
## step at a time (held keys repeat, per the menu standard); E changes the
## scale; M or Esc close.

## The survey's window on the glass, in screen pixels (clear of the dead column
## on the left and the crack on the right).
const MAP_RECT := Rect2i(34, 48, 568, 270)
const PAN_STEP := 12
const SCALES: Array[int] = [1, 2, 3, 4, 6]
## Seconds the scanner's line takes to cross the survey.
const SWEEP_SECONDS := 3.2

var explored: UiExplored
var data: UiMapData
var map_scale := 2
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
	_overlay.size = Vector2(UiBase.DESIGN)
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
	_seen_tex = ImageTexture.create_from_image(Image.create_from_data(explored.size, explored.size, false, Image.FORMAT_L8, explored.mask))
	_material.set_shader_parameter("ground_tex", data.ground)
	_material.set_shader_parameter("level_tex", data.level)
	_material.set_shader_parameter("coast_tex", data.coast)
	_material.set_shader_parameter("marks_tex", data.marks)
	_material.set_shader_parameter("palette_tex", data.palette)
	_material.set_shader_parameter("country_tex", data.country)
	_material.set_shader_parameter("seen_tex", _seen_tex)
	_material.set_shader_parameter("rect_size", Vector2(MAP_RECT.size))
	_material.set_shader_parameter("world_size", float(game.world.size))
	_regions = UiMapScreen.region_labels(game.world, explored)
	_seen_share = explored.fraction()
	var f := UiMapScreen.fit(explored.bounds, game.player.pos, MAP_RECT.size, SCALES)
	map_scale = f.scale
	centre_on(f.centre)


## The scale and centre that show the land seen so far: the largest scale at
## which all of it fits the window, centred on it, but never with the player
## off the survey. {scale: int, centre: Vector2 (tiles)}
static func fit(seen: Rect2i, player: Vector2, window: Vector2i, scales: Array[int]) -> Dictionary:
	const MARGIN := 24
	# A little land running off the survey is better than all of it drawn too small.
	const OVERFLOW := 1.3
	var s := scales[0]
	for k in scales:
		if seen.size.x * k <= (window.x - MARGIN * 2) * OVERFLOW and seen.size.y * k <= (window.y - MARGIN * 2) * OVERFLOW:
			s = maxi(s, k)
	var centre := Vector2(seen.get_center()) if seen.size != Vector2i.ZERO else player
	# Drawn a pixel a tile, land that fills less than half the window is a stamp in
	# an empty frame: a step closer reads as a survey. The player stays on it.
	if s == 1 and scales.has(2) and seen.size.x * seen.size.y * 2 < window.x * window.y:
		s = 2
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
	for dy: int in [0, -12, 12, -24, 24]:
		for x: int in xs:
			var at := Vector2i(x, s.y - 5 + dy)
			var moved := absi(x - (s.x - w / 2)) + absi(dy)
			var text_r := Rect2i(at, Vector2i(w, 10))
			var box := text_r.grow(3)
			if not MAP_RECT.grow(-6).encloses(text_r) or not free.call(box):
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
				mean = UiMapData.ink_in(data.ink, game.world.size, t) / float(maxi(1, t.get_area()))
			var score := mean + moved * 0.012
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
## a name over a drawn coast has to be read at 640x360 in one look.
static func clearing(ci: CanvasItem, box: Rect2i) -> void:
	var col := UiTheme.GLASS
	UiDraw.rect(ci, Rect2i(box.position.x + 1, box.position.y, box.size.x - 2, box.size.y), col)
	UiDraw.rect(ci, Rect2i(box.position.x, box.position.y + 1, box.size.x, box.size.y - 2), col)


## Put tile-space point `p` in the middle of the survey's window.
func centre_on(p: Vector2) -> void:
	origin_px = Vector2i(roundi(p.x * map_scale), roundi(p.y * map_scale)) - _anchor()
	_apply()


func _anchor() -> Vector2i:
	return MAP_RECT.size / 2


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
			map_scale = SCALES[(SCALES.find(map_scale) + 1) % SCALES.size()]
			if game != null:
				# Zoom about the middle, but never leave the player off the survey.
				var reach := (Vector2(MAP_RECT.size) * 0.5 - Vector2(24, 24)) / map_scale
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
		var f := UiMapScreen.fit(explored.bounds, game.player.pos, MAP_RECT.size, [s])
		map_scale = s
		centre_on(f.centre)


func _pan(d: Vector2i) -> void:
	origin_px += d
	_apply()


func _apply() -> void:
	if game != null:
		# Keep some of the world in the window: stop a half-window past its edge.
		var world_px := game.world.size * map_scale
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
	UiDraw.text(self, Vector2i(r.position.x, 36), "SURVEY", UiTheme.TEXT)
	# The survey's grid of points on the glass, where nothing has been seen yet.
	var y := r.position.y + 5
	while y < r.end.y:
		var x := r.position.x + 5
		while x < r.end.x:
			UiDraw.px(self, x, y, UiTheme.GHOST)
			x += 12
		y += 12
	if game == null:
		draw_keys([["esc", "back"]])
		return
	var p := game.player.pos
	var here := BiomeRegistry.at(game.world, p).display_name
	UiDraw.text(self, Vector2i(r.position.x + 50, 36), here, UiTheme.BRIGHT)
	UiDraw.text_right(self, r.end.x, 36, "%s of the land seen   1:%d" % [UiRules.share(_seen_share), map_scale], UiTheme.TEXT_DIM)
	draw_keys([["wasd", "look"], ["e", "scale"], ["m", "close"], ["esc", "back"]])


func _draw_overlay() -> void:
	var ci := _overlay
	var r := MAP_RECT
	UiSlate.brackets(ci, r.grow(2), UiTheme.TEXT_DIM, 8)
	if game == null:
		return
	var me := to_screen(game.player.pos)
	var me_rect := Rect2i(me.x - 6, me.y - 6, 13, 13)
	var inner := r.grow(-1)
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
			_dotted(ci, to_screen(a), to_screen(b), Color(UiTheme.MACHINE[2], 0.85), 2, inner)
			var s := to_screen(b)
			if inner.has_point(s):
				UiDraw.rect(ci, Rect2i(s.x - 1, s.y - 1, 3, 3), UiTheme.MACHINE[3])
	# Everything with a fixed place on the survey is claimed before a word is
	# laid anywhere: you-are-here with its ping ring, the compass and the scale
	# bar. A name is lettered last and over none of them.
	#
	# `placed` is what a name must never sit on. `words` is only the lettering:
	# when a name can find nowhere clear of the marks as well, it takes the best
	# place clear of the other words and its clearing covers the mark under it.
	# A name that gives way to a diamond is a name nobody reads.
	var placed: Array[Rect2i] = [Rect2i(me.x - 16, me.y - 16, 33, 33), Rect2i(r.end.x - 19, r.position.y + 2, 18, 30), Rect2i(r.position.x + 1, r.end.y - 21, 10 * map_scale + 54, 20)]
	var words: Array[Rect2i] = placed.duplicate()
	var villages: Array[Dictionary] = []
	for v in game.world.villages:
		var vp: Vector2 = v.pos
		if explored == null or not explored.seen(floori(vp.x), floori(vp.y)):
			continue
		var s := to_screen(vp)
		if not r.grow(-4).has_point(s):
			continue
		var name := String(v.name).to_lower()
		var w := UiFont.width(name)
		var tx := clampi(s.x - w / 2, r.position.x + 2, r.end.x - w - 2)
		var ty := s.y + 6
		if ty + 10 > r.end.y or Rect2i(tx - 2, ty - 1, w + 4, 11).intersects(me_rect):
			ty = s.y - 16
		var box := Rect2i(tx - 2, ty - 1, w + 4, 11)
		placed.append(box.grow(2))
		words.append(box.grow(2))
		placed.append(Rect2i(s.x - 3, s.y - 3, 7, 7).grow(2))
		villages.append({"at": s, "name": name, "box": box})
	# Every discovery's diamond is spoken for before a region is lettered. The
	# diamonds used to be drawn after the names and landed on top of them: COAST
	# read C◇AST and SCRAPWOOD SCR◇PWOOD on the canon survey.
	var found_all := UiMapScreen.discoveries(game.world, explored)
	var finds: Array[Dictionary] = []
	for found: Dictionary in found_all:
		var s := to_screen(found.pos)
		if not r.grow(-4).has_point(s):
			continue
		placed.append(Rect2i(s.x - 3, s.y - 3, 7, 7).grow(2))
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
			var col := Color(UiTheme.BRIGHT, (0.3 + 0.6 * float(i) / n) * (0.55 if map_scale == 1 else 1.0))
			var d := a1 - a0
			var len := maxi(absi(d.x), absi(d.y))
			for k in len:
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
		UiDraw.rect(ci, Rect2i(s.x - 3, s.y - 3, 7, 7), Color(UiTheme.GLASS, 0.8))
		var mark := UiMapScreen.mark_for(found.kind)
		if mark.is_empty():
			for k in 4:
				UiDraw.px(ci, s.x - 3 + k, s.y - k, col)
				UiDraw.px(ci, s.x + k, s.y - 3 + k, col)
				UiDraw.px(ci, s.x + 3 - k, s.y + k, col)
				UiDraw.px(ci, s.x - k, s.y + 3 - k, col)
		else:
			for row in mark.size():
				var line: String = mark[row]
				for cx in line.length():
					if line[cx] == "#":
						UiDraw.px(ci, s.x - 3 + cx, s.y - 3 + row, col)
		if map_scale >= 3:
			var word := String(found.kind).replace("_", " ")
			var box := Rect2i(s.x + 6, s.y - 5, UiFont.width(word) + 4, 10)
			if r.grow(-2).encloses(box) and _free_of(placed).call(box):
				placed.append(box)
				UiMapScreen.clearing(ci, box)
				UiDraw.text(ci, box.position + Vector2i(2, 0), word, col)
	for v: Dictionary in villages:
		var s: Vector2i = v.at
		var box: Rect2i = v.box
		UiMapScreen.clearing(ci, box)
		UiDraw.text(ci, box.position + Vector2i(2, 0), v.name, UiTheme.TEXT_DIM)
		UiDraw.rect(ci, Rect2i(s.x - 3, s.y - 3, 7, 7), UiTheme.GLASS)
		UiDraw.frame(ci, Rect2i(s.x - 2, s.y - 2, 5, 5), UiTheme.BRIGHT)
		UiDraw.px(ci, s.x, s.y, UiTheme.BRIGHT)
	# The scanner's line crossing the survey, slowly, top to bottom. It goes under
	# the lettering with everything else: a line travelling across a name reads
	# as a name struck out, even at six per cent.
	var sweep := r.position.y + roundi(fposmod(_time / SWEEP_SECONDS, 1.0) * r.size.y)
	UiDraw.hline(ci, r.position.x, r.end.x - 1, sweep, Color(UiTheme.PHOSPHOR[3], 0.06))
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
		var box := Rect2i(at, Vector2i(UiFont.width(text), 10)).grow(3)
		placed.append(box)
		words.append(box)
		UiMapScreen.clearing(ci, box)
		UiDraw.text(ci, at, text, UiTheme.TEXT)
	# You are here: a bright cross, and a ping ring going out from it.
	if r.has_point(me):
		UiDraw.rect(ci, Rect2i(me.x - 4, me.y - 4, 9, 9), Color(UiTheme.GLASS, 0.75))
		for i in range(-3, 4):
			UiDraw.px(ci, me.x + i, me.y, UiTheme.BRIGHT)
			UiDraw.px(ci, me.x, me.y + i, UiTheme.BRIGHT)
		var ping := fposmod(_time, 1.6) / 1.6
		var pr := 4.0 + ping * 10.0
		for k in 20:
			var a := k * TAU / 20.0
			var q := me + Vector2i(roundi(cos(a) * pr), roundi(sin(a) * pr))
			if inner.has_point(q):
				UiDraw.px(ci, q.x, q.y, Color(UiTheme.BRIGHT, UiDraw.stepped(1.0 - ping) * 0.6))
	# North, in the corner.
	var nx := r.end.x - 12
	var ny := r.position.y + 6
	UiDraw.rect(ci, Rect2i(nx - 5, ny - 2, 13, 26), Color(UiTheme.GLASS, 0.85))
	UiDraw.text(ci, Vector2i(nx - 1, ny), "N", UiTheme.TEXT)
	UiDraw.vline(ci, nx + 1, ny + 11, ny + 21, UiTheme.TEXT)
	UiDraw.hline(ci, nx, nx + 2, ny + 12, UiTheme.TEXT)
	UiDraw.hline(ci, nx - 1, nx + 3, ny + 13, UiTheme.TEXT)
	# A scale bar: ten tiles at this scale.
	var bx := r.position.x + 6
	var by := r.end.y - 8
	var bw := 10 * map_scale
	UiDraw.rect(ci, Rect2i(bx - 3, by - 11, bw + 50, 16), Color(UiTheme.GLASS, 0.85))
	UiDraw.hline(ci, bx, bx + bw, by, UiTheme.TEXT)
	UiDraw.vline(ci, bx, by - 2, by, UiTheme.TEXT)
	UiDraw.vline(ci, bx + bw, by - 2, by, UiTheme.TEXT)
	UiDraw.text(ci, Vector2i(bx + bw + 4, by - 8), "10 tiles", UiTheme.TEXT_DIM)


static func _dotted(ci: CanvasItem, a: Vector2i, b: Vector2i, col: Color, every: int, clip: Rect2i) -> void:
	var d := b - a
	var len := maxi(absi(d.x), absi(d.y))
	if len == 0:
		return
	for k in range(0, len, every):
		var q := a + Vector2i(roundi(d.x * k / float(len)), roundi(d.y * k / float(len)))
		if clip.has_point(q):
			UiDraw.px(ci, q.x, q.y, col)
