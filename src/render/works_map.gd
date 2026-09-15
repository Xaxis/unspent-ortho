class_name WorksMap
extends RefCounted
## Where the machines have cut the land, as a map world.gdshader reads: one
## texel per tile, a channel per kind of work, 0..1 with a feathered edge so the
## shader can tear the region's rim raggedly (the chaos) while it rules the
## rows, cuts, benches and bores inside exactly along the survey bearing (the
## order). Baked once from the landmarks GenWorks records ({pos, dir, half,
## mark}); decor reads the same bytes.
##
## Channels:
##   R  cut     turf cut in rows (turf, heath), drainage cuts (fen, peat, mud),
##              harvester tracks (needles)
##   G  scorch  burnt and poisoned ground, whatever it was
##   B  quarry  benches cut in the grid (pavement, rock, gravel, turf)
##   A  bores   an exact grid of drill holes and the survey's paint lines

const CHANNEL := {&"cut": 0, &"scorch": 1, &"quarry": 2, &"bores": 3}
## Tiles over which a work's edge fades out.
const FEATHER := 1.5
## What the machines' marks keep off, and the tiles over which they fade back
## in beyond it: roads (the way stays a way), water (a cut silts up before a
## river), the houses people live in, and each village square plus a margin.
const KEEP_ROAD := Vector2(0.9, 1.6)
const KEEP_WATER := Vector2(0.6, 1.8)
const KEEP_HOUSE := Vector2(1.6, 1.6)
const KEEP_VILLAGE := Vector2(3.0, 3.0)

var size := 0
var bytes := PackedByteArray()
## Three bytes per tile, the shader's works_lines:
##   R  255 where a stretch of the survey runs (GenWorks.survey_sections)
##   G  255 where a stump stands, so a harvester's rut stops short of it
##   B  255 where the survey may run as a wet ditch: deep in a wide fen, clear
##      of water and houses (a small patch of moss keeps it dry)
var survey := PackedByteArray()
## GenWorks.survey_phase: where the survey's two families of lines sit.
var phase := Vector2.ZERO
## The survey bearing as a unit vector (GenWorks.bearing).
var dir := Vector2.RIGHT


static func bake(w: WorldData) -> WorksMap:
	var m := WorksMap.new()
	m.size = w.size
	m.bytes.resize(w.size * w.size * 4)
	m.dir = Vector2.from_angle(GenWorks.bearing(w.seed_value))
	var houses := PackedVector2Array()
	for p in w.props:
		if p.kind == PropKind.HOUSE:
			houses.append(p.pos)
	for lm in w.landmarks:
		if not lm.has("mark"):
			continue
		var ch: int = CHANNEL.get(lm.mark, -1)
		if ch < 0:
			continue
		m._paint(w, houses, lm.pos, lm.get("dir", Vector2.RIGHT), lm.get("half", Vector2(4, 4)), ch)
	m.survey.resize(w.size * w.size * 3)
	for p in w.props:
		if p.kind == PropKind.STUMP:
			m.survey[(floori(p.pos.y) * w.size + floori(p.pos.x)) * 3 + 1] = 255
	m.phase = GenWorks.survey_phase(w.seed_value)
	for sec: Array in GenWorks.survey_sections(w.seed_value, w.size):
		m._line(w, houses, sec[0], sec[1])
	return m


## Grounds a drainage ditch can be cut in.
static func fen(g: int) -> bool:
	return g == Ground.MOSS or g == Ground.PEAT or g == Ground.MUD or g == Ground.BLACKWATER


## 1 where the ground round p (radius 5) is nearly all fen and no open water
## or house stands within 3: a ditch may hold water there.
static func wet_at(w: WorldData, houses: PackedVector2Array, p: Vector2) -> bool:
	var n := 0
	var f := 0
	for ring: float in [0.0, 2.5, 5.0]:
		var count := 1 if ring == 0.0 else (8 if ring < 3.0 else 12)
		for k in count:
			var q := p + Vector2.from_angle(float(k) / count * TAU) * ring
			var x := floori(q.x)
			var y := floori(q.y)
			if not w.in_bounds(x, y):
				return false
			var g := int(w.ground[y * w.size + x])
			if ring < 4.0 and (g == Ground.RIVER or g == Ground.WATER or g == Ground.DEEP_WATER or g == Ground.ROAD or w.level[y * w.size + x] <= 0):
				return false
			n += 1
			if fen(g):
				f += 1
	if f < n * 0.8:
		return false
	for h in houses:
		if h.distance_squared_to(p) < 9.0:
			return false
	return true


## Where a stretch of the survey survives: a band the shader rules its exact
## line inside. Villages keep it out of their squares, roads break it. Along it,
## every few tiles, whether it may run wet (wet_at), so a ditch narrows and dries
## out before a river, a house or the edge of a small patch of moss.
func _line(w: WorldData, houses: PackedVector2Array, a: Vector2, b: Vector2) -> void:
	var d := (b - a).normalized()
	var nrm := Vector2(-d.y, d.x)
	var length := a.distance_to(b)
	var near := PackedVector2Array()
	var box := Rect2(a, Vector2.ZERO).expand(b).grow(8.0)
	for h in houses:
		if box.has_point(h):
			near.append(h)
	var t := 0.0
	var wet_here := false
	while t <= length:
		var centre := a + d * t
		if fmod(t, 3.0) < 0.25:
			var cx := floori(centre.x)
			var cy := floori(centre.y)
			wet_here = w.in_bounds(cx, cy) and fen(int(w.ground[cy * size + cx])) and wet_at(w, near, centre)
		for s: float in [-1.5, -0.75, 0.0, 0.75, 1.5]:
			var q := centre + nrm * s
			var x := floori(q.x)
			var y := floori(q.y)
			if x < 0 or y < 0 or x >= size or y >= size:
				continue
			if w.ground[y * size + x] == Ground.ROAD:
				continue
			survey[(y * size + x) * 3] = 255
			if wet_here:
				survey[(y * size + x) * 3 + 2] = 255
		t += 0.5
	for v in w.villages:
		var vp: Vector2 = v.pos
		if Geometry2D.get_closest_point_to_segment(vp, a, b).distance_to(vp) < 14.0:
			var r := 14
			for y in range(maxi(0, floori(vp.y) - r), mini(size, floori(vp.y) + r + 1)):
				for x in range(maxi(0, floori(vp.x) - r), mini(size, floori(vp.x) + r + 1)):
					survey[(y * size + x) * 3] = 0
					survey[(y * size + x) * 3 + 2] = 0


## A rotated rectangle into one channel: full inside, fading over FEATHER, and
## faded out again near what it keeps off (keep()).
func _paint(w: WorldData, houses: PackedVector2Array, centre: Vector2, d: Vector2, half: Vector2, ch: int) -> void:
	var nrm := Vector2(-d.y, d.x)
	var outer := half + Vector2(FEATHER, FEATHER)
	var nu := ceili(outer.x * 2.5)
	var nv := ceili(outer.y * 2.5)
	# Long works (a corridor) are kept piece by piece, so the keep grid follows
	# the work and not its whole bounding box.
	var pieces := maxi(1, ceili(outer.x * 2.0 / 10.0))
	for piece in pieces:
		var iu0 := -nu + floori(float(2 * nu + 1) * piece / pieces)
		var iu1 := -nu + floori(float(2 * nu + 1) * (piece + 1) / pieces)
		var u0 := outer.x * iu0 / nu
		var u1 := outer.x * (iu1 - 1) / nu
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q: Vector2 in [centre + d * u0 + nrm * outer.y, centre + d * u0 - nrm * outer.y, centre + d * u1 + nrm * outer.y, centre + d * u1 - nrm * outer.y]:
			lo = lo.min(q)
			hi = hi.max(q)
		var rect := Rect2i(Vector2i(floori(lo.x) - 1, floori(lo.y) - 1), Vector2i(floori(hi.x) - floori(lo.x) + 3, floori(hi.y) - floori(lo.y) + 3))
		var kept := keep(w, houses, rect)
		for iu in range(iu0, iu1):
			var u := outer.x * iu / nu
			var along := centre + d * u
			for iv in range(-nv, nv + 1):
				var v := outer.y * iv / nv
				var q := along + nrm * v
				var x := floori(q.x)
				var y := floori(q.y)
				if x < 0 or y < 0 or x >= size or y >= size:
					continue
				var e := maxf(absf(u) - half.x, absf(v) - half.y)
				var lx := x - rect.position.x
				var ly := y - rect.position.y
				var f := 1.0
				if lx >= 0 and ly >= 0 and lx < rect.size.x and ly < rect.size.y:
					f = kept[ly * rect.size.x + lx]
				var k := clampi(roundi((1.0 - clampf(e / FEATHER, 0.0, 1.0)) * f * 255.0), 0, 255)
				var i := (y * size + x) * 4 + ch
				if k > bytes[i]:
					bytes[i] = k


## For each tile of `rect` (row by row), 0 where the machines' marks must not
## show and 1 where they may, rising over a few tiles: distance to the nearest
## road, water, house and village square (the KEEP_* margins). A chamfer
## distance over the rect and a little beyond, so a source just outside counts.
static func keep(w: WorldData, houses: PackedVector2Array, rect: Rect2i) -> PackedFloat32Array:
	const PAD := 4
	var gx0 := rect.position.x - PAD
	var gy0 := rect.position.y - PAD
	var gw := rect.size.x + PAD * 2
	var gh := rect.size.y + PAD * 2
	var road := PackedFloat32Array()
	var water := PackedFloat32Array()
	road.resize(gw * gh)
	water.resize(gw * gh)
	road.fill(99.0)
	water.fill(99.0)
	var roads := false
	var waters := false
	for gy in gh:
		var y := clampi(gy0 + gy, 0, w.size - 1)
		for gx in gw:
			var i := y * w.size + clampi(gx0 + gx, 0, w.size - 1)
			var g := w.ground[i]
			if g == Ground.ROAD:
				road[gy * gw + gx] = 0.0
				roads = true
			elif g <= Ground.WATER or g >= Ground.BLACKWATER and g != Ground.PEAT or w.level[i] <= 0:
				water[gy * gw + gx] = 0.0
				waters = true
	if roads:
		_chamfer(road, gw, gh)
	if waters:
		_chamfer(water, gw, gh)
	var near_villages: Array[Dictionary] = []
	for v in w.villages:
		var r := float(v.get("radius", 4.0)) + KEEP_VILLAGE.x + KEEP_VILLAGE.y
		if Rect2(rect).grow(r).has_point(v.pos):
			near_villages.append(v)
	var near_houses := PackedVector2Array()
	for h in houses:
		if Rect2(rect).grow(KEEP_HOUSE.x + KEEP_HOUSE.y + 1.0).has_point(h):
			near_houses.append(h)
	var out := PackedFloat32Array()
	out.resize(rect.size.x * rect.size.y)
	for ly in rect.size.y:
		for lx in rect.size.x:
			var gi := (ly + PAD) * gw + lx + PAD
			var f := 1.0
			if roads:
				f = _ramp(road[gi], KEEP_ROAD)
			if waters:
				f *= _ramp(water[gi], KEEP_WATER)
			if not near_villages.is_empty() or not near_houses.is_empty():
				var q := Vector2(rect.position.x + lx + 0.5, rect.position.y + ly + 0.5)
				for v in near_villages:
					f *= _ramp(q.distance_to(v.pos) - float(v.get("radius", 4.0)), KEEP_VILLAGE)
				for h in near_houses:
					f *= _ramp(q.distance_to(h), KEEP_HOUSE)
			out[ly * rect.size.x + lx] = f
	return out


## 0 up to margin.x, rising to 1 over margin.y.
static func _ramp(dist: float, margin: Vector2) -> float:
	return clampf((dist - margin.x) / margin.y, 0.0, 1.0)


## Two-pass chamfer distance in place: 0 at sources, tiles (1, 1.41) elsewhere.
static func _chamfer(g: PackedFloat32Array, gw: int, gh: int) -> void:
	for y in gh:
		for x in gw:
			var i := y * gw + x
			var v := g[i]
			if x > 0:
				v = minf(v, g[i - 1] + 1.0)
			if y > 0:
				v = minf(v, g[i - gw] + 1.0)
				if x > 0:
					v = minf(v, g[i - gw - 1] + 1.41)
				if x < gw - 1:
					v = minf(v, g[i - gw + 1] + 1.41)
			g[i] = v
	for y in range(gh - 1, -1, -1):
		for x in range(gw - 1, -1, -1):
			var i := y * gw + x
			var v := g[i]
			if x < gw - 1:
				v = minf(v, g[i + 1] + 1.0)
			if y < gh - 1:
				v = minf(v, g[i + gw] + 1.0)
				if x < gw - 1:
					v = minf(v, g[i + gw + 1] + 1.41)
				if x > 0:
					v = minf(v, g[i + gw - 1] + 1.41)
			g[i] = v


## 0..1 of channel ch at tile (x, y).
func at(x: int, y: int, ch: int) -> float:
	if x < 0 or y < 0 or x >= size or y >= size:
		return 0.0
	return bytes[(y * size + x) * 4 + ch] / 255.0


func texture() -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes))


## Hand the map to a world material (world.gdshader).
func bind(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("works_map", texture())
	mat.set_shader_parameter("works_inv_size", 1.0 / maxf(1.0, float(size)))
	mat.set_shader_parameter("works_dir", dir)
	mat.set_shader_parameter("works_lines", ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGB8, survey)))
	mat.set_shader_parameter("works_survey", Vector4(phase.x, phase.y, GenWorks.SURVEY_ALONG, GenWorks.SURVEY_ACROSS))
