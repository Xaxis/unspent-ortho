class_name UiMapScreen
extends UiScreen
## The notebook map (M): only the land the player has seen, drawn in ink and
## wash across both pages and the fold. Arrows look around a step at a time
## (held keys repeat, per the menu standard); E changes the scale; M or Esc close.

## The map's window on the spread, in screen pixels.
const MAP_RECT := Rect2i(32, 50, 576, 272)
const PAN_STEP := 12
const SCALES: Array[int] = [1, 2, 3, 4, 6]

var explored: UiExplored
var data: UiMapData
var map_scale := 2
## Map pixel (tile * map_scale) under the window's top-left pixel.
var origin_px := Vector2i.ZERO

var _rect: ColorRect
## The map is drawn once into this each time it moves, not every frame.
var _viewport: SubViewport
var _overlay: Control
var _material: ShaderMaterial
var _seen_tex: ImageTexture
var _regions: Array[Dictionary] = []
var _seen_share := 0.0


func _init() -> void:
	super()
	screen_name = &"map"
	own_action = &"map"
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/ui/map.gdshader")
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
	_overlay.size = Vector2(640, 360)
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
	var f := UiMapScreen.fit(explored.bounds, game.player.pos, MAP_RECT.size, SCALES, fold_x())
	map_scale = f.scale
	centre_on(f.centre)


## The scale and centre that show the land seen so far: the largest scale at
## which all of it fits the window, centred on it, but never with the player
## off the page. `fold` is the book's gutter as a window x (-1: none); the
## player and, when it fits on one page, the whole seen land are kept off it.
## {scale: int, centre: Vector2 (tiles)}
static func fit(seen: Rect2i, player: Vector2, window: Vector2i, scales: Array[int], fold: int = -1) -> Dictionary:
	const MARGIN := 24
	# A little land running off the page is better than all of it drawn too small.
	const OVERFLOW := 1.3
	var s := scales[0]
	for k in scales:
		if seen.size.x * k <= (window.x - MARGIN * 2) * OVERFLOW and seen.size.y * k <= (window.y - MARGIN * 2) * OVERFLOW:
			s = maxi(s, k)
	var centre := Vector2(seen.get_center()) if seen.size != Vector2i.ZERO else player
	# Drawn a pixel a tile, land that fills less than half the window is a stamp in
	# an empty frame: a step closer reads as a chart. The player stays on the page
	# and as much seen land as fits comes with them; the rest is a pan away.
	if s == 1 and scales.has(2) and seen.size.x * seen.size.y * 2 < window.x * window.y:
		s = 2
	var reach := (Vector2(window) * 0.5 - Vector2(MARGIN, MARGIN)) / s
	centre = centre.clamp(player - reach, player + reach)
	if fold >= 0:
		centre.x = off_the_fold(centre.x, seen, player, window, s, fold)
	return {"scale": s, "centre": centre}


## The map's centre x (tiles), moved so nothing that matters sits in the gutter:
## land narrow enough for one page goes to the middle of the page the player
## was on; wider land keeps its place, but the player is kept clear of the fold.
static func off_the_fold(cx: float, seen: Rect2i, player: Vector2, window: Vector2i, s: int, fold: int) -> float:
	const CLEAR := 10 # px either side of the gutter
	const GUTTER := 4
	const PAGE_MARGIN := 14
	var half := window.x / 2.0
	var left_w := fold
	var right_w := window.x - fold - GUTTER
	var land_w := seen.size.x * s
	if seen.size != Vector2i.ZERO and land_w <= mini(left_w, right_w) - PAGE_MARGIN * 2:
		var land_cx := seen.position.x + seen.size.x / 2.0
		# Which page: the one the player already stands on, as the window was.
		var px := (player.x - cx) * s + half
		var page_cx := fold / 2.0 if px < fold + GUTTER / 2.0 else fold + GUTTER + right_w / 2.0
		return land_cx - (page_cx - half) / s
	var at := (player.x - cx) * s + half
	if at > fold - CLEAR and at < fold + GUTTER + CLEAR:
		var want := fold - CLEAR if at < fold + GUTTER / 2.0 else fold + GUTTER + CLEAR
		return cx + (at - want) / s
	return cx


## Where to letter each country the player has seen enough of: the seen tile
## of that country deepest inside it (most of its neighbourhood the same
## country), so a name sits over its own land rather than a neighbour's.
## [{text, at: Vector2, country, seen}]
static func region_labels(w: WorldData, seen: UiExplored) -> Array[Dictionary]:
	const STEP := 4
	const ENOUGH := 120 # seen tiles before a country is worth naming
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
		var name := String(Country.NAMES[c]).to_upper()
		var spaced := ""
		for i in name.length():
			spaced += (" " if i > 0 else "") + name[i]
		out.append({"text": spaced, "at": best[c][1], "country": c, "seen": int(counts[c]) * STEP * STEP})
	# The country seen most is lettered first; a crowded label gives way to it.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.seen > b.seen)
	return out


## The book's gutter, as an x in the map's window.
static func fold_x() -> int:
	return UiNotebook.LEFT.end.x - MAP_RECT.position.x


## Where to letter a country name (top-left, screen px), or x < -1000 when no
## candidate is free. `free` says whether a box is clear of other lettering.
func place_region(label: Dictionary, free: Callable) -> Vector2i:
	var text: String = label.text
	var w := UiFont.width(text)
	var s := to_screen(label.at)
	var best := Vector2i(-9999, 0)
	var best_score := INF
	var gx := MAP_RECT.position.x + fold_x()
	# Left edges to try: on the spot, nudged, and set just clear of either side of the fold.
	var xs: Array[int] = [s.x - w / 2, s.x - w / 2 - w / 4, s.x - w / 2 + w / 4, gx + 10, gx - 6 - w]
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
			# A name broken by the gutter is hard to read.
			if box.position.x < gx + 6 and box.end.x > gx - 2:
				score += 1.5
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


## A paper clearing for a name over the map: nearly opaque, its corners and the
## odd pixel of its edge left open, so it reads as ink rubbed back, not a sticker.
static func clearing(ci: CanvasItem, box: Rect2i, seed: int) -> void:
	var col := Color(UiTheme.PAPER, 0.9)
	UiDraw.rect(ci, Rect2i(box.position.x + 1, box.position.y + 1, box.size.x - 2, box.size.y - 2), col)
	for x in range(box.position.x + 2, box.end.x - 2):
		if Rng.hash01(seed, x, 0, 0xc1) > 0.18:
			UiDraw.px(ci, x, box.position.y, col)
		if Rng.hash01(seed, x, 1, 0xc1) > 0.18:
			UiDraw.px(ci, x, box.end.y - 1, col)
	for y in range(box.position.y + 2, box.end.y - 2):
		UiDraw.px(ci, box.position.x, y, Color(col, 0.6))
		UiDraw.px(ci, box.end.x - 1, y, Color(col, 0.6))


## Put tile-space point `p` in the middle of the map's window.
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
				# Zoom about the middle, but never leave the player in the gutter.
				var reach := (Vector2(MAP_RECT.size) * 0.5 - Vector2(24, 24)) / map_scale
				centre = centre.clamp(game.player.pos - reach, game.player.pos + reach)
				centre.x = UiMapScreen.off_the_fold(centre.x, Rect2i(), game.player.pos, MAP_RECT.size, map_scale, fold_x())
			centre_on(centre)
			Events.sfx.emit(&"menu_move", Vector3.ZERO)
		_:
			return super(action)
	return true


## --screen=map:3 opens at that scale (the map has no rows to choose).
func select(id: StringName) -> void:
	var s := String(id).to_int()
	if SCALES.has(s) and game != null:
		var f := UiMapScreen.fit(explored.bounds, game.player.pos, MAP_RECT.size, [s], fold_x())
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


func _draw() -> void:
	UiNotebook.spread(self, 37)
	UiNotebook.title(self, UiNotebook.LEFT, "map", 21)
	if game == null:
		return
	var R := UiNotebook.RIGHT
	var p := game.player.pos
	var c := game.world.country_at(floori(p.x), floori(p.y))
	var place := Country.NAMES[c]
	UiDraw.text_right(self, R.end.x - 16, R.position.y + 11, "%s   %s" % [place, game.clock.label()], UiTheme.INK_SOFT)
	UiNotebook.footer(self, UiNotebook.LEFT, "wasd look     e scale     m close     esc")
	UiDraw.text_right(self, R.end.x - 28, R.end.y - 14, "%d%% of the coast seen" % roundi(_seen_share * 100.0), UiTheme.FADED)


func _draw_overlay() -> void:
	var ci := _overlay
	var r := MAP_RECT
	# The fold runs through the map: shade it as the pages do.
	var gx := UiNotebook.LEFT.end.x
	for i in 5:
		var a := 0.34 - i * 0.065
		UiDraw.vline(ci, gx - 1 - i, r.position.y, r.end.y - 1, Color(UiTheme.PAPER_EDGE, a))
		UiDraw.vline(ci, gx + 4 + i, r.position.y, r.end.y - 1, Color(UiTheme.PAPER_EDGE, a * 0.8))
	UiDraw.rect(ci, Rect2i(gx, r.position.y, 4, r.size.y), Color(UiTheme.PAPER_DEEP, 0.75))
	UiDraw.vline(ci, gx + 1, r.position.y, r.end.y - 1, Color(UiTheme.PAPER_EDGE, 0.8))
	# A drawn border, ruled twice.
	UiNotebook.box(ci, r.grow(2), UiTheme.INK, 5)
	UiNotebook.box(ci, r.grow(4), Color(UiTheme.INK, 0.45), 6)
	if game == null:
		return
	var me := to_screen(game.player.pos)
	var me_rect := Rect2i(me.x - 6, me.y - 6, 13, 13)
	# Villages first, so a country's name gives way to a village's, not over it.
	var placed: Array[Rect2i] = [me_rect.grow(2)]
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
		placed.append(Rect2i(s.x - 3, s.y - 3, 7, 7).grow(2))
		villages.append({"at": s, "name": name, "box": box})
	# Countries, lettered across the land they cover, spaced out like a region on a
	# chart. Of the nearby places free of other names, the one over the least ink
	# (cliffs, shore, symbols) is chosen, and the name sits on a paper clearing.
	for label: Dictionary in _regions:
		var text: String = label.text
		var at := place_region(label, _free_of(placed))
		if at.x < -1000:
			continue
		var box := Rect2i(at, Vector2i(UiFont.width(text), 10)).grow(3)
		placed.append(box)
		UiMapScreen.clearing(ci, box, hash(text))
		UiDraw.text(ci, at, text, Palette.EARTH[1])
	# The way the player came, dotted in the accent, fading toward the start.
	if explored != null:
		var n := explored.trail.size()
		var inner := r.grow(-1)
		var step := 0
		for i in range(1, n):
			var a0 := to_screen(explored.trail[i - 1])
			var a1 := to_screen(explored.trail[i])
			# A jump (carried off, a teleport) is not walked: leave a gap.
			if explored.trail[i - 1].distance_to(explored.trail[i]) > 4.0:
				continue
			if not inner.has_point(a0) and not inner.has_point(a1):
				continue
			# Lighter when zoomed out, where a long walk would bury the land in dots.
			var col := Color(UiTheme.ACCENT, (0.35 + 0.55 * float(i) / n) * (0.55 if map_scale == 1 else 1.0))
			var d := a1 - a0
			var len := maxi(absi(d.x), absi(d.y))
			for k in len:
				step += 1
				if step % 3 == 0:
					continue
				var p := a0 + Vector2i(roundi(d.x * k / float(len)), roundi(d.y * k / float(len)))
				if inner.has_point(p):
					UiDraw.px(ci, p.x, p.y, col)
	# Villages the player has seen: a house mark and the name, lettered on a clearing.
	for v: Dictionary in villages:
		var s: Vector2i = v.at
		var box: Rect2i = v.box
		UiDraw.rect(ci, box, Color(UiTheme.PAPER, 0.85))
		UiDraw.text(ci, box.position + Vector2i(2, 1), v.name, UiTheme.INK)
		UiDraw.rect(ci, Rect2i(s.x - 3, s.y - 3, 7, 7), UiTheme.PAPER)
		UiDraw.frame(ci, Rect2i(s.x - 2, s.y - 2, 5, 5), UiTheme.INK)
		UiDraw.px(ci, s.x, s.y, UiTheme.ACCENT)
	# You are here: an accent cross in a paper clearing.
	if r.has_point(me):
		UiDraw.rect(ci, Rect2i(me.x - 4, me.y - 4, 9, 9), Color(UiTheme.PAPER, 0.7))
		for i in range(-3, 4):
			UiDraw.px(ci, me.x + i, me.y + i, UiTheme.ACCENT)
			UiDraw.px(ci, me.x + i, me.y - i, UiTheme.ACCENT)
			UiDraw.px(ci, me.x + i + (1 if i < 3 else 0), me.y + i, UiTheme.ACCENT)
			UiDraw.px(ci, me.x + i + (1 if i < 3 else 0), me.y - i, UiTheme.ACCENT)
	# North, in the corner, the way it is always drawn.
	var nx := r.end.x - 14
	var ny := r.position.y + 6
	UiDraw.rect(ci, Rect2i(nx - 5, ny - 2, 13, 26), Color(UiTheme.PAPER, 0.8))
	UiDraw.text(ci, Vector2i(nx - 1, ny), "N", UiTheme.INK)
	UiDraw.vline(ci, nx + 1, ny + 11, ny + 21, UiTheme.INK)
	UiDraw.hline(ci, nx, nx + 2, ny + 12, UiTheme.INK)
	UiDraw.hline(ci, nx - 1, nx + 3, ny + 13, UiTheme.INK)
