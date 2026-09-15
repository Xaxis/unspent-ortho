class_name TerrainMesher
extends RefCounted
## Builds one CHUNK x CHUNK tile area into meshes. The tile grid is the rules'
## business, never the eye's (docs/ART.md): the land is drawn as CONTOUR TERRACES.
##
## A continuous elevation field f(x, y) is the bilinear interpolation of tile
## levels (sampled at tile centres) warped by noise. A point is on terrace L when
## f >= L - 0.5. Marching squares over a half-tile lattice traces each terrace
## edge as a curve; every terrace is a flat wash at L * STEP and every edge is a
## wall down to the terrace below, banded as its country's strata. Two-level
## cliffs read as stacked rock ledges, one-level steps as a single inked lip, and
## a coastline as a survey contour rather than a staircase.
##
## What a lattice point is drawn as is its KEY: ground, the country it is drawn
## in, and whether it is wet. Across an ecotone a world-space noise lets the
## neighbour country show through in ragged patches whose share grows toward the
## border (WorldData.blend, or BlendFallback's approximation). A cell's two most
## common keys become its wash and second wash; world.gdshader meets them on a
## ragged pixel edge, each with its own ink mark and hatch hand.
##
## Water: the sea is one sheet at WATER_Y carrying depth; inland water (rivers,
## pools, blackwater) is a sheet WADE above its bed's level, so anything standing
## in it has its shins hidden by the water itself, whatever it is drawn with.
## The bed under inland water sinks, so a bank at the same level slopes in.
##
## Channels written per vertex are documented in world.gdshader and water.gdshader.

const CHUNK := 32
const WATER_Y := 0.3
const SEA_FLOOR := -1.0
## Lattice samples per tile. 2 = half-tile cells.
const RES := 2
## How far (in levels) the noise warps the field: shapes curves, never moves a cliff far.
const WARP := 0.2
## How far (in tiles) a terrace edge may wander from the tile rows it follows.
const DOMAIN_WARP := 1.1
## Inland water: the sheet stands this far above its tile's level (a walker's shins)...
const WADE := 0.3
## ...and the bed sinks this far below it.
const WET_SINK := 0.42
## Tiles of context around a chunk for distances to the waterline.
const MARGIN := 10
## How readily a neighbour country shows through across an ecotone.
const ECO_SPREAD := 0.95

const _KEY_WET := 1 << 16
## How far a bank at the level of the water beside it lips up: just above the
## inland sheet (WADE). Keys carry the shore profile index in bits 17-21.
const BANK_LIFT := 0.36
## Inland wetness at which the land is under the sheet, and where its lip begins.
const WET_EDGE := 0.4
const LIP_START := 0.3
## How much lower inland water counts in the smoothed elevation field.
const WATER_BIAS := 0.7
static var _LIFTS := PackedFloat32Array()
var _blur: Dictionary = {}
## Cumulative build time by stage (usec) and vertices, for tools/gd/bench_chunks.gd.
static var PROF := PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0])
## Tiles of country and shore data kept around a chunk for warped lookups.
const RING := 2

var world: WorldData
var eco: BlendFallback
var _warp: FastNoiseLite
var _eco: FastNoiseLite
var _lip: FastNoiseLite
var _tab_col := PackedColorArray()
var _tab_style := PackedInt32Array()
var _tab_cliff := PackedColorArray()
var _tab_front := PackedColorArray()
## 0 no lip, 1 turf, 2 snow; per (ground, country, parity).
var _tab_lip := PackedByteArray()
# Scratch for the cell being emitted: corner keys, values, positions; polygon.
var _ck := PackedInt32Array([0, 0, 0, 0])
var _cv := PackedFloat32Array([0, 0, 0, 0])
var _cx := PackedFloat32Array([0, 0, 0, 0])
var _cz := PackedFloat32Array([0, 0, 0, 0])
var _poly := PackedVector3Array()
var _k1 := 0
var _k2 := -1
const _UV_CONTOUR := Vector2(Ink.CONTOUR * 17, 0.0)
static var _WET := PackedByteArray()

# Output buffers of the chunk being built.
var _tv: PackedVector3Array
var _tn: PackedVector3Array
var _tc: PackedColorArray
var _tuv: PackedVector2Array
var _tuv2: PackedVector2Array
var _tc0: PackedColorArray
var _wv: PackedVector3Array
var _wc: PackedColorArray

# Paint state of the cell being emitted.
var _pc := Color.WHITE
var _sc := Color.WHITE
var _style := 0.0
var _m2 := 2.0
var _w00 := 0.0
var _w10 := 0.0
var _w11 := 0.0
var _w01 := 0.0
var _ox := 0.0
var _oy := 0.0


## One built chunk: meshes plus what decor and props need to sit on the land.
class Chunk:
	var cx: int
	var cy: int
	var x0: int
	var y0: int
	## Tiles across and down.
	var w: int
	var h: int
	## Lattice cells across (w * RES).
	var n: int
	var terrain: ArrayMesh
	var water: ArrayMesh
	## Per lattice point ((n + 1) * (h * RES + 1), row-major): field, terrace, key.
	var f := PackedFloat32Array()
	var t := PackedInt32Array()
	var key := PackedInt32Array()
	## Per tile of the chunk: signed tiles to the waterline, + in water, - on land.
	var shore := PackedFloat32Array()
	## Cliff feet: point on the lower terrace, outward direction, country.
	var feet := PackedVector3Array()
	var feet_out := PackedVector3Array()
	var feet_country := PackedByteArray()

	func _lat(x: float, y: float) -> int:
		var i := clampi(roundi((x - x0) * RES), 0, n)
		var j := clampi(roundi((y - y0) * RES), 0, h * RES)
		return j * (n + 1) + i

	## The key drawn nearest to tile-space point (x, y): ground | country << 8 | wet << 16.
	func key_at(x: float, y: float) -> int:
		return key[_lat(x, y)]

	func ground_at(x: float, y: float) -> int:
		return key[_lat(x, y)] & 0xFF

	func country_at(x: float, y: float) -> int:
		return (key[_lat(x, y)] >> 8) & 0xFF

	func shore_at(x: float, y: float) -> float:
		var tx := clampi(floori(x) - x0, 0, w - 1)
		var ty := clampi(floori(y) - y0, 0, h - 1)
		return shore[ty * w + tx]

	## True when the four lattice points around (x, y) are one terrace and one
	## key: a small thing placed there sits flat and away from any edge.
	func settled(x: float, y: float) -> bool:
		var i := clampi(floori((x - x0) * RES), 0, n - 1)
		var j := clampi(floori((y - y0) * RES), 0, h * RES - 1)
		var a := j * (n + 1) + i
		var k := key[a]
		var l := t[a]
		return t[a + 1] == l and t[a + n + 1] == l and t[a + n + 2] == l and key[a + 1] == k and key[a + n + 1] == k and key[a + n + 2] == k

	## Height of the drawn land surface at (x, y) (bed height under inland water).
	func surface(x: float, y: float) -> float:
		var u := clampf((x - x0) * RES, 0.0, n - 0.001)
		var v := clampf((y - y0) * RES, 0.0, h * RES - 0.001)
		var i := floori(u)
		var j := floori(v)
		var a := j * (n + 1) + i
		var fu := u - i
		var fv := v - j
		var val := lerpf(lerpf(f[a], f[a + 1], fu), lerpf(f[a + n + 1], f[a + n + 2], fu), fv)
		var l := floori(val + 0.5)
		var ht := TerrainMesher.level_height(l)
		if l > 0:
			ht += TerrainMesher._lift(key[_lat(x, y)])
		return ht


static func _static_init() -> void:
	_WET.resize(256)
	for g in 256:
		_WET[g] = 1 if Ground.is_water(g) else 0
	_LIFTS.resize(32)
	_LIFTS[0] = 0.0
	for i in range(1, 32):
		_LIFTS[i] = _profile(LIP_START + (i - 1) / 30.0 * (1.0 - LIP_START))


func _init(w: WorldData) -> void:
	world = w
	eco = BlendFallback.new(w)
	_warp = FastNoiseLite.new()
	_warp.seed = Rng.hash_ints(w.seed_value, 32) & 0x7FFFFFFF
	_warp.frequency = 1.0 / 3.5
	_warp.fractal_octaves = 2
	_eco = FastNoiseLite.new()
	_eco.seed = Rng.hash_ints(w.seed_value, 33) & 0x7FFFFFFF
	_eco.frequency = 1.0 / 7.0
	_eco.fractal_octaves = 3
	_lip = FastNoiseLite.new()
	_lip.seed = Rng.hash_ints(w.seed_value, 34) & 0x7FFFFFFF
	_lip.frequency = 1.3
	_lip.fractal_octaves = 1
	# Paint per (ground, country, terrace parity): wash with its mark in alpha.
	_tab_col.resize(Ground.COUNT * Country.COUNT * 2)
	_tab_style.resize(Ground.COUNT * Country.COUNT * 2)
	_tab_cliff.resize(Ground.COUNT * Country.COUNT * 2)
	_tab_front.resize(Ground.COUNT * Country.COUNT * 2)
	_tab_lip.resize(Ground.COUNT * Country.COUNT * 2)
	for g in Ground.COUNT:
		for c in Country.COUNT:
			for parity in 2:
				var col := GroundColors.wash(g, c)
				# Terraces one level apart alternate a hair in value: the contour is felt, not seen.
				if parity == 1:
					col = col.darkened(0.03)
				col.a = GroundColors.mark(g, c) / 255.0
				var i := (g * Country.COUNT + c) * 2 + parity
				_tab_col[i] = col
				_tab_style[i] = Ink.COUNTRY_STYLE[c]
				var cl := GroundColors.cliff(g, c)
				if parity == 1:
					cl = cl.darkened(0.06)
				cl.a = (GroundColors.STRATA + GroundColors.strata(g, c)) / 255.0
				_tab_cliff[i] = cl
				var snow := g == Ground.SNOW or (c == Country.SNOWFIELD and g != Ground.ICE and g != Ground.SAND and g != Ground.SHINGLE and g != Ground.ROCK and g != Ground.SCREE and not Ground.is_water(g))
				var turf := g == Ground.GRASS or g == Ground.HEATH or g == Ground.MOSS or g == Ground.PEAT or g == Ground.NEEDLES
				_tab_lip[i] = 2 if snow else (1 if turf else 0)
				var fr := Palette.RIME[4] if snow else GroundColors.down(col, 1.0)
				fr.a = 1.0
				_tab_front[i] = fr


## Vertical offset of a land vertex with key k: the shore profile of inland
## water (a lip, then down to the bed).
static func _lift(k: int) -> float:
	return _LIFTS[(k >> 17) & 31]


## Shore profile index (0 = none) for an inland wetness value wf.
static func _shore_lift(wf: float) -> int:
	if wf < LIP_START:
		return 0
	return 1 + roundi(clampf((wf - LIP_START) / (1.0 - LIP_START), 0.0, 1.0) * 30.0)


static func _profile(wf: float) -> float:
	if wf < LIP_START:
		return 0.0
	var mid := (LIP_START + WET_EDGE) * 0.5
	if wf < mid:
		return lerpf(0.0, BANK_LIFT, (wf - LIP_START) / (mid - LIP_START))
	if wf < WET_EDGE:
		return lerpf(BANK_LIFT, WADE, (wf - mid) / (WET_EDGE - mid))
	return lerpf(WADE, -WET_SINK, clampf((wf - WET_EDGE) / 0.15, 0.0, 1.0))


## Wetness of inland water at `terrace` at (x, y), from the blurred tile window
## for that level (made on first use per chunk).
func _wet_field(x: float, y: float, terrace: int, wl: PackedInt32Array, rx0: int, ry0: int, rw: int, rh: int) -> float:
	if not _blur.has(terrace):
		var bw := PackedFloat32Array()
		bw.resize(rw * rh)
		for yy in rh:
			for xx in rw:
				var sum := 0
				for dy in range(-1, 2):
					var ny := clampi(yy + dy, 0, rh - 1) * rw
					for dx in range(-1, 2):
						if wl[ny + clampi(xx + dx, 0, rw - 1)] == terrace:
							sum += (2 - absi(dx)) * (2 - absi(dy))
				var own := wl[yy * rw + xx] == terrace
				bw[yy * rw + xx] = maxf(0.6, sum / 16.0) if own else minf(sum / 16.0 * 0.8, 0.26)
		_blur[terrace] = bw
	var b: PackedFloat32Array = _blur[terrace]
	var gx := x - 0.5
	var gy := y - 0.5
	var ix := clampi(floori(gx) - rx0, 0, rw - 2)
	var iy := clampi(floori(gy) - ry0, 0, rh - 2)
	var fx := clampf(gx - (ix + rx0), 0.0, 1.0)
	var fy := clampf(gy - (iy + ry0), 0.0, 1.0)
	var a := iy * rw + ix
	var top := b[a] + (b[a + 1] - b[a]) * fx
	var bot := b[a + rw] + (b[a + rw + 1] - b[a + rw]) * fx
	return top + (bot - top) * fy


## The ground of the inland water at `terrace` nearest (x, y).
func _water_ground(x: float, y: float, terrace: int, wl: PackedInt32Array, tg: PackedByteArray, rx0: int, ry0: int, rw: int, rh: int) -> int:
	var tx := clampi(floori(x) - rx0, 0, rw - 1)
	var ty := clampi(floori(y) - ry0, 0, rh - 1)
	for r in 3:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var o := clampi(ty + dy, 0, rh - 1) * rw + clampi(tx + dx, 0, rw - 1)
				if wl[o] == terrace:
					return tg[o]
	return Ground.RIVER


static func level_height(l: int) -> float:
	if l > 0:
		return l * WorldData.STEP
	return 0.0 if l == 0 else SEA_FLOOR


func _lv(x: int, y: int) -> float:
	var i := clampi(y, 0, world.size - 1) * world.size + clampi(x, 0, world.size - 1)
	var l := world.level[i]
	return float(l) - (WATER_BIAS if l > 0 and _WET[world.ground[i]] == 1 else 0.0)


## A tile's level blurred over its neighbours, but never out of its own
## terrace: the shape between tile centres is smoothed, the rules are not.
## Inland water counts a little lower, so a one-tile river keeps its terrace
## right across its width instead of pinching to a thread between its banks.
func smooth_level(x: int, y: int) -> float:
	var c := _lv(x, y)
	var own := float(world.level_at(clampi(x, 0, world.size - 1), clampi(y, 0, world.size - 1)))
	var sum := c * 4.0
	sum += (_lv(x - 1, y) + _lv(x + 1, y) + _lv(x, y - 1) + _lv(x, y + 1)) * 2.0
	sum += _lv(x - 1, y - 1) + _lv(x + 1, y - 1) + _lv(x - 1, y + 1) + _lv(x + 1, y + 1)
	return clampf(sum / 16.0, own - 0.45, own + 0.45)


## Near an edge the field is read through a gentle domain warp (the contour
## wanders like a drawn coast instead of running along tile rows) plus a finer
## value warp. `smooth` is a window of smooth_level() starting at (ox-1, oy-1).
func _edge_field(x: float, y: float, smooth: PackedFloat32Array, sw: int, ox: int, oy: int) -> float:
	var px := x + _warp.get_noise_2d(x * 0.9 + 70.0, y * 0.9) * DOMAIN_WARP
	var py := y + _warp.get_noise_2d(x * 0.9, y * 0.9 + 70.0) * DOMAIN_WARP
	var gx := px - 0.5
	var gy := py - 0.5
	var ix := floori(gx)
	var iy := floori(gy)
	var fx := gx - ix
	var fy := gy - iy
	var sh := smooth.size() / sw
	var ax := clampi(ix - ox + 1, 0, sw - 1)
	var bx := clampi(ix - ox + 2, 0, sw - 1)
	var ay := clampi(iy - oy + 1, 0, sh - 1) * sw
	var by := clampi(iy - oy + 2, 0, sh - 1) * sw
	var la := smooth[ay + ax]
	var lb := smooth[ay + bx]
	var lc := smooth[by + ax]
	var ld := smooth[by + bx]
	var v := (la + (lb - la) * fx) + ((lc + (ld - lc) * fx) - (la + (lb - la) * fx)) * fy
	return v + _warp.get_noise_2d(x * 4.0, y * 4.0) * WARP


## The continuous elevation field, in levels, at tile-space point (x, y).
func field(x: float, y: float) -> float:
	var gx := x - 0.5
	var gy := y - 0.5
	var ix := floori(gx)
	var iy := floori(gy)
	var fx := gx - ix
	var fy := gy - iy
	# Warp only where the land actually changes height, so flats stay flat.
	if _lv(ix, iy) != _lv(ix + 1, iy) or _lv(ix, iy) != _lv(ix, iy + 1) or _lv(ix, iy) != _lv(ix + 1, iy + 1):
		var win := PackedFloat32Array()
		win.resize(36)
		for yy in 6:
			for xx in 6:
				win[yy * 6 + xx] = smooth_level(ix - 2 + xx, iy - 2 + yy)
		return _edge_field(x, y, win, 6, ix - 1, iy - 1)
	return lerpf(lerpf(smooth_level(ix, iy), smooth_level(ix + 1, iy), fx), lerpf(smooth_level(ix, iy + 1), smooth_level(ix + 1, iy + 1), fx), fy)


## Height of the drawn land at a point, for things placed outside a chunk build.
func surface_height(x: float, y: float) -> float:
	return level_height(floori(field(x, y) + 0.5))


## The map tool's colour for a tile.
func top_color(x: int, y: int) -> Color:
	return GroundColors.wash(world.ground_at(x, y), maxi(Country.COAST, world.country_at(x, y)))


## Returns [terrain: ArrayMesh, water: ArrayMesh or null].
func build_chunk(cx: int, cy: int) -> Array:
	var ch := build(cx, cy)
	return [ch.terrain, ch.water]


func build(cx: int, cy: int) -> Chunk:
	var w := world
	var size := w.size
	var ch := Chunk.new()
	ch.cx = cx
	ch.cy = cy
	ch.x0 = cx * CHUNK
	ch.y0 = cy * CHUNK
	var x1 := mini(size, ch.x0 + CHUNK)
	var y1 := mini(size, ch.y0 + CHUNK)
	ch.w = x1 - ch.x0
	ch.h = y1 - ch.y0
	ch.n = ch.w * RES
	var n := ch.n
	var m := ch.h * RES
	var np := n + 1
	var x0 := ch.x0
	var y0 := ch.y0
	var _t0 := Time.get_ticks_usec()
	# Countries and transitions over the chunk and a ring (the ground lookup is
	# warped by up to RING tiles).
	var rx0 := x0 - RING
	var ry0 := y0 - RING
	var rw := ch.w + RING * 2
	var rh := ch.h + RING * 2
	var rc := PackedByteArray()
	var rc2 := PackedByteArray()
	var rb := PackedFloat32Array()
	eco.fill(rx0, ry0, x1 + RING, y1 + RING, rc, rc2, rb)
	var _t1 := Time.get_ticks_usec()
	var shore := _shore_window(rx0, ry0, x1 + RING, y1 + RING)
	var has_water := false
	for v in shore:
		if v > -float(MARGIN):
			has_water = true
			break
	var _t2 := Time.get_ticks_usec()
	ch.shore.resize(ch.w * ch.h)
	for y in ch.h:
		for x in ch.w:
			ch.shore[y * ch.w + x] = shore[(y + RING) * rw + x + RING]
	var level := w.level
	var ground := w.ground
	var legacy := eco.active
	# Per tile of the ring: the tile's ground as drawn in its own country (legacy
	# worlds get their sub-grounds here) and whether it holds inland water.
	var tg := PackedByteArray()
	tg.resize(rw * rh)
	var inland := false
	_blur.clear()
	# Level of the inland water in each ring tile (0 none), and nearness to it.
	var wl := PackedInt32Array()
	wl.resize(rw * rh)
	var near := PackedByteArray()
	near.resize(rw * rh)
	for yy in rh:
		var ty := clampi(ry0 + yy, 0, size - 1)
		for xx in rw:
			var tx := clampi(rx0 + xx, 0, size - 1)
			var o := yy * rw + xx
			var g: int = ground[ty * size + tx]
			if legacy and _WET[g] == 0:
				g = eco.legacy_ground(g, rc[o], tx + 0.5, ty + 0.5, shore[o])
			elif _WET[g] == 1 and level[ty * size + tx] > 0:
				inland = true
				wl[o] = level[ty * size + tx]
			tg[o] = g
	if inland:
		# Lattice points within reach of inland water (the field and its warp).
		for yy in rh:
			for xx in rw:
				if wl[yy * rw + xx] == 0:
					continue
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var ny := yy + dy
						var nx := xx + dx
						if nx >= 0 and ny >= 0 and nx < rw and ny < rh:
							near[ny * rw + nx] = 1
	# Raw and smoothed tile levels: contours run straight along a diagonal coast
	# instead of stepping round every tile. Raw covers x0-3 .. x1+2.
	var aw := ch.w + 6
	var ah := ch.h + 6
	var raw := PackedInt32Array()
	raw.resize(aw * ah)
	var biased := PackedFloat32Array()
	biased.resize(aw * ah)
	for yy in ah:
		var ty := clampi(y0 - 3 + yy, 0, size - 1) * size
		for xx in aw:
			var ti := ty + clampi(x0 - 3 + xx, 0, size - 1)
			var l: int = level[ti]
			raw[yy * aw + xx] = l
			biased[yy * aw + xx] = float(l) - (WATER_BIAS if l > 0 and _WET[ground[ti]] == 1 else 0.0)
	var sw := ch.w + 4
	var smooth := PackedFloat32Array()
	smooth.resize(sw * (ch.h + 4))
	for yy in ch.h + 4:
		for xx in sw:
			var a := (yy + 1) * aw + xx + 1
			var c := float(raw[a])
			var sum := biased[a] * 4.0 + (biased[a - 1] + biased[a + 1] + biased[a - aw] + biased[a + aw]) * 2.0 + biased[a - aw - 1] + biased[a - aw + 1] + biased[a + aw - 1] + biased[a + aw + 1]
			smooth[yy * sw + xx] = clampf(sum / 16.0, c - 0.45, c + 0.45)
	var cnt := np * (m + 1)
	ch.f.resize(cnt)
	ch.t.resize(cnt)
	ch.key.resize(cnt)
	var depth := PackedFloat32Array()
	depth.resize(cnt)
	var _t3 := Time.get_ticks_usec()
	for j in m + 1:
		var sy := y0 + j * 0.5
		var gy := sy - 0.5
		var iy := floori(gy)
		var fy := gy - iy
		for i in np:
			var sx := x0 + i * 0.5
			var li := j * np + i
			var gx := sx - 0.5
			var ix := floori(gx)
			var fx := gx - ix
			var ri := (iy - y0 + 3) * aw + (ix - x0 + 3)
			var ss := (iy - y0 + 2) * sw + (ix - x0 + 2)
			var v: float
			var r0 := raw[ri]
			if r0 != raw[ri + 1] or r0 != raw[ri + aw] or r0 != raw[ri + aw + 1]:
				v = _edge_field(sx, sy, smooth, sw, x0 - 1, y0 - 1)
			else:
				var la := smooth[ss]
				var lb := smooth[ss + 1]
				var top := la + (lb - la) * fx
				var lc := smooth[ss + sw]
				v = top + ((lc + (smooth[ss + sw + 1] - lc) * fx) - top) * fy
			ch.f[li] = v
			var terrace := floori(v + 0.5)
			ch.t[li] = terrace
			if terrace <= 0:
				# The sea bed is never seen: one key, so it merges into runs.
				ch.key[li] = Ground.WATER | _KEY_WET
			else:
				# Ground under a warp, so type boundaries (and the edges of inland
				# water) wander with the contours instead of following tiles.
				var wx := sx + 0.01 + _warp.get_noise_2d(sx * 0.9 + 70.0, sy * 0.9) * DOMAIN_WARP + _warp.get_noise_2d(sx * 3.0 + 50.0, sy * 3.0) * 0.3
				var wy := sy + 0.01 + _warp.get_noise_2d(sx * 0.9, sy * 0.9 + 70.0) * DOMAIN_WARP + _warp.get_noise_2d(sx * 3.0, sy * 3.0 + 50.0) * 0.3
				var otx := clampi(floori(wx), rx0, rx0 + rw - 1)
				var oty := clampi(floori(wy), ry0, ry0 + rh - 1)
				var o := (oty - ry0) * rw + (otx - rx0)
				var g: int = tg[o]
				var c: int = rc[o]
				var dc := c
				var b: float = rb[o]
				if b > 0.0 and rc2[o] != c and _eco.get_noise_2d(sx, sy) < (b - 0.5) * ECO_SPREAD:
					dc = rc2[o]
					if legacy and _WET[g] == 0:
						g = eco.legacy_ground(GroundColors.morph(ground[clampi(oty, 0, size - 1) * size + clampi(otx, 0, size - 1)], dc), dc, sx, sy, shore[o])
				var extra := 0
				var wf := 0.0
				if inland and near[(floori(sy) - ry0) * rw + (floori(sx) - rx0)] == 1:
					# Inland water is a smooth field read through a small warp: its
					# shore slopes up to a narrow lip and down to a bed, so the sheet
					# meets the land on a curve, while every water tile's centre stays
					# wet and every dry tile's centre stays dry and unlifted.
					var qx := sx + _warp.get_noise_2d(sx * 3.0 + 50.0, sy * 3.0) * 0.3
					var qy := sy + _warp.get_noise_2d(sx * 3.0, sy * 3.0 + 50.0) * 0.3
					wf = _wet_field(qx, qy, terrace, wl, rx0, ry0, rw, rh)
					extra = _shore_lift(wf) << 17
					if wf >= WET_EDGE:
						extra |= _KEY_WET
						if _WET[g] == 0:
							g = _water_ground(wx, wy, terrace, wl, tg, rx0, ry0, rw, rh)
				if _WET[g] == 1 and (extra & _KEY_WET) == 0:
					g = GroundColors.bank(dc)
				ch.key[li] = g | (dc << 8) | extra
				if (extra & _KEY_WET) != 0:
					# Inland depth from the same field, so bands follow the shore.
					depth[li] = (wf - WET_EDGE) * 6.0
					continue
			if has_water:
				# Signed tiles to the waterline, bilinear between tile centres.
				var so := clampi(iy - ry0, 0, rh - 2) * rw + clampi(ix - rx0, 0, rw - 2)
				var sa := shore[so]
				var sb := shore[so + 1]
				var top := sa + (sb - sa) * fx
				var sc := shore[so + rw]
				depth[li] = top + ((sc + (shore[so + rw + 1] - sc) * fx) - top) * fy
			else:
				depth[li] = -float(MARGIN)
	var _t4 := Time.get_ticks_usec()
	_begin()
	for j in m:
		var py := y0 + j * 0.5
		var run_start := -1
		var run_key := 0
		var run_t := 0
		for i in n:
			var i00 := j * np + i
			var k00 := ch.key[i00]
			var k10 := ch.key[i00 + 1]
			var k01 := ch.key[i00 + np]
			var k11 := ch.key[i00 + np + 1]
			var t00 := ch.t[i00]
			var same_t := ch.t[i00 + 1] == t00 and ch.t[i00 + np] == t00 and ch.t[i00 + np + 1] == t00
			var flat := same_t and k10 == k00 and k01 == k00 and k11 == k00
			if flat and run_start >= 0 and (k00 != run_key or t00 != run_t):
				_flat_run(ch, run_start, i, py, run_key, run_t)
				run_start = -1
			if flat:
				if run_start < 0:
					run_start = i
					run_key = k00
					run_t = t00
				continue
			if run_start >= 0:
				_flat_run(ch, run_start, i, py, run_key, run_t)
				run_start = -1
			if same_t:
				if t00 > 0:
					_mixed_flat(x0 + i * 0.5, py, t00, k00, k10, k11, k01)
				continue
			_cell(ch, i, j)
		if run_start >= 0:
			_flat_run(ch, run_start, n, py, run_key, run_t)
	var _t5 := Time.get_ticks_usec()
	if has_water:
		_build_water(ch, depth)
	var _t6 := Time.get_ticks_usec()
	ch.terrain = _finish_terrain()
	ch.water = _finish_water()
	PROF[0] += _t1 - _t0
	PROF[1] += _t2 - _t1
	PROF[2] += _t3 - _t2
	PROF[7] += _t4 - _t3
	PROF[3] += _t5 - _t4
	PROF[4] += _t6 - _t5
	PROF[5] += Time.get_ticks_usec() - _t6
	PROF[6] += _tv.size()
	return ch


## A same-terrace cell whose corners carry two or more keys: one quad, the
## most common key as its wash and the next as the second wash.
func _mixed_flat(px: float, py: float, terrace: int, k00: int, k10: int, k11: int, k01: int) -> void:
	_pick_keys(k00, k10, k11, k01)
	_ox = px
	_oy = py
	_paint(_k1, _k2, terrace)
	var h := level_height(terrace)
	var h00 := h + _lift(k00)
	var h10 := h + _lift(k10)
	var h11 := h + _lift(k11)
	var h01 := h + _lift(k01)
	var s := 0.5
	_vtop(px, h00, py)
	_vtop(px + s, h10, py)
	_vtop(px + s, h11, py + s)
	_vtop(px, h00, py)
	_vtop(px + s, h11, py + s)
	_vtop(px, h01, py + s)


func _begin() -> void:
	_tv = PackedVector3Array()
	_tn = PackedVector3Array()
	_tc = PackedColorArray()
	_tuv = PackedVector2Array()
	_tuv2 = PackedVector2Array()
	_tc0 = PackedColorArray()
	_wv = PackedVector3Array()
	_wc = PackedColorArray()


func _finish_terrain() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _tv.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _tv
	arrays[Mesh.ARRAY_NORMAL] = _tn
	arrays[Mesh.ARRAY_COLOR] = _tc
	arrays[Mesh.ARRAY_TEX_UV] = _tuv
	arrays[Mesh.ARRAY_TEX_UV2] = _tuv2
	arrays[Mesh.ARRAY_CUSTOM0] = _tc0.to_byte_array().to_float32_array()
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return mesh


func _finish_water() -> ArrayMesh:
	if _wv.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _wv
	var nrm := PackedVector3Array()
	nrm.resize(_wv.size())
	nrm.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = _wc
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Set the paint state for tops of key k1 (and a second key k2 by corner flags).
func _paint(k1: int, k2: int, terrace: int) -> void:
	var i1 := ((k1 & 0xFF) * Country.COUNT + ((k1 >> 8) & 0xFF)) * 2 + (terrace & 1)
	_pc = _tab_col[i1]
	var s1 := _tab_style[i1] if terrace > 0 else Ink.NONE
	if k2 >= 0:
		var i2 := ((k2 & 0xFF) * Country.COUNT + ((k2 >> 8) & 0xFF)) * 2 + (terrace & 1)
		_sc = _tab_col[i2]
		_style = s1 + (_tab_style[i2] if terrace > 0 else Ink.NONE) * 16
		_m2 = 2.0 + _sc.a * 255.0
	else:
		_sc = _pc
		_style = s1 * 17
		_m2 = 2.0 + _pc.a * 255.0


func _vtop(x: float, y: float, z: float) -> void:
	var fx := (x - _ox) * RES
	var fz := (z - _oy) * RES
	var top := _w00 + (_w10 - _w00) * fx
	var bot := _w01 + (_w11 - _w01) * fx
	var wt := top + (bot - top) * fz
	_tv.append(Vector3(x, y, z))
	_tn.append(Vector3.UP)
	_tc.append(_pc)
	_tuv.append(Vector2(_style, wt))
	_tuv2.append(Vector2(0.0, _m2))
	_tc0.append(Color(_sc.r, _sc.g, _sc.b, wt))


## A run of identical flat cells [i0, i1) on lattice row starting at py.
func _flat_run(ch: Chunk, i0: int, i1: int, py: float, k: int, terrace: int) -> void:
	if terrace <= 0:
		return
	_paint(k, -1, terrace)
	_w00 = 0.0
	_w10 = 0.0
	_w11 = 0.0
	_w01 = 0.0
	var h := level_height(terrace)
	h += _lift(k)
	var xa := ch.x0 + i0 * 0.5
	var xb := ch.x0 + i1 * 0.5
	var yb := py + 0.5
	_ox = xa
	_oy = py
	_vtop(xa, h, py)
	_vtop(xb, h, py)
	_vtop(xb, h, yb)
	_vtop(xa, h, py)
	_vtop(xb, h, yb)
	_vtop(xa, h, yb)


## One lattice cell with more than one key or terrace: the lowest terrace fills
## the square; each higher terrace is the marching-squares region above its
## threshold, with a wall (and a lip) on its edge.
func _cell(ch: Chunk, i: int, j: int) -> void:
	var np := ch.n + 1
	var s := 0.5
	var px := ch.x0 + i * s
	var py := ch.y0 + j * s
	var i00 := j * np + i
	var ia := i00 + np
	_ck[0] = ch.key[i00]
	_ck[1] = ch.key[i00 + 1]
	_ck[2] = ch.key[ia + 1]
	_ck[3] = ch.key[ia]
	_cv[0] = ch.f[i00]
	_cv[1] = ch.f[i00 + 1]
	_cv[2] = ch.f[ia + 1]
	_cv[3] = ch.f[ia]
	var t0 := ch.t[i00]
	var t1 := ch.t[i00 + 1]
	var t2 := ch.t[ia + 1]
	var t3 := ch.t[ia]
	var lo := mini(mini(t0, t1), mini(t2, t3))
	var hi := maxi(maxi(t0, t1), maxi(t2, t3))
	if hi <= 0:
		return
	_cx[0] = px
	_cx[1] = px + s
	_cx[2] = px + s
	_cx[3] = px
	_cz[0] = py
	_cz[1] = py
	_cz[2] = py + s
	_cz[3] = py + s
	_pick_keys(_ck[0], _ck[1], _ck[2], _ck[3])
	_ox = px
	_oy = py
	if lo > 0:
		# Under the sea sheet the lowest terrace is never seen.
		_paint(_k1, _k2, lo)
		var h0 := level_height(lo)
		var ha := h0 + _lift(_ck[0])
		var hc := h0 + _lift(_ck[2])
		_vtop(px, ha, py)
		_vtop(px + s, h0 + _lift(_ck[1]), py)
		_vtop(px + s, hc, py + s)
		_vtop(px, ha, py)
		_vtop(px + s, hc, py + s)
		_vtop(px, h0 + _lift(_ck[3]), py + s)
	for L in range(maxi(lo + 1, 1), hi + 1):
		var thr := L - 0.5
		var h := level_height(L)
		var hb := level_height(L - 1)
		var in0 := _cv[0] >= thr
		var in1 := _cv[1] >= thr
		var in2 := _cv[2] >= thr
		var in3 := _cv[3] >= thr
		if in0 == in2 and in1 == in3 and in0 != in1:
			_paint(_k1, _k2, L)
			_saddle(ch, px, py, L)
			continue
		_poly.clear()
		var cross_a := -1
		var cross_b := -1
		var near_e := -1
		for e in 4:
			var e2 := (e + 1) & 3
			var a := _cv[e]
			var ina := a >= thr
			if ina:
				_poly.append(Vector3(_cx[e], h + _lift(_ck[e]), _cz[e]))
				if near_e < 0:
					near_e = e
			if ina != (_cv[e2] >= thr):
				var tt := clampf((thr - a) / (_cv[e2] - a), 0.05, 0.95)
				if cross_a < 0:
					cross_a = _poly.size()
				else:
					cross_b = _poly.size()
				_poly.append(Vector3(_cx[e] + (_cx[e2] - _cx[e]) * tt, h, _cz[e] + (_cz[e2] - _cz[e]) * tt))
		var pn := _poly.size()
		if pn < 3:
			continue
		_paint(_k1, _k2, L)
		var p0 := _poly[0]
		for e in range(1, pn - 1):
			var pe := _poly[e]
			var pf := _poly[e + 1]
			_vtop(p0.x, p0.y, p0.z)
			_vtop(pe.x, pe.y, pe.z)
			_vtop(pf.x, pf.y, pf.z)
		if cross_b >= 0:
			# The inside corner nearest the wall says which ground it stands under.
			var ca := _poly[cross_a]
			var cb := _poly[cross_b]
			var mx := (ca.x + cb.x) * 0.5
			var mz := (ca.z + cb.z) * 0.5
			var best := INF
			for e in 4:
				if _cv[e] >= thr:
					var dd := (_cx[e] - mx) * (_cx[e] - mx) + (_cz[e] - mz) * (_cz[e] - mz)
					if dd < best:
						best = dd
						near_e = e
			_wall(ch, ca.x, ca.z, cb.x, cb.z, _cx[near_e], _cz[near_e], hb, h, L, _ck[near_e])


## A cell whose diagonal corners are on the same side of a threshold.
func _saddle(ch: Chunk, px: float, py: float, L: int) -> void:
	var thr := L - 0.5
	var h := level_height(L)
	var hb := level_height(L - 1)
	var s := 0.5
	var centre := (_cv[0] + _cv[1] + _cv[2] + _cv[3]) * 0.25 >= thr
	var mx := px + s * 0.5
	var mz := py + s * 0.5
	_poly.clear()
	for e in 4:
		var e2 := (e + 1) & 3
		var e0 := (e + 3) & 3
		var ina := _cv[e] >= thr
		var tb := clampf((thr - _cv[e]) / (_cv[e0] - _cv[e]), 0.05, 0.95)
		var ta := clampf((thr - _cv[e]) / (_cv[e2] - _cv[e]), 0.05, 0.95)
		var bx := _cx[e] + (_cx[e0] - _cx[e]) * tb
		var bz := _cz[e] + (_cz[e0] - _cz[e]) * tb
		var ax := _cx[e] + (_cx[e2] - _cx[e]) * ta
		var az := _cz[e] + (_cz[e2] - _cz[e]) * ta
		var hc := h + _lift(_ck[e])
		if ina and not centre:
			# Separate islands at the inside corners.
			_vtop(_cx[e], hc, _cz[e])
			_vtop(ax, h, az)
			_vtop(bx, h, bz)
			_wall(ch, ax, az, bx, bz, _cx[e], _cz[e], hb, h, L, _ck[e])
		elif centre:
			if ina:
				_poly.append(Vector3(_cx[e], hc, _cz[e]))
			else:
				# The centre is high: walls cut off the outside corners.
				_poly.append(Vector3(bx, h, bz))
				_poly.append(Vector3(ax, h, az))
				_wall(ch, bx, bz, ax, az, mx, mz, hb, h, L, _ck[e2])
	if centre:
		var pn := _poly.size()
		for e in pn:
			var a := _poly[e]
			var b := _poly[(e + 1) % pn]
			_vtop(mx, h, mz)
			_vtop(a.x, a.y, a.z)
			_vtop(b.x, b.y, b.z)


## Primary key: the most common corner key; secondary: the next different one,
## with its corner flags for the second wash.
func _pick_keys(k00: int, k10: int, k11: int, k01: int) -> void:
	var n00 := 1 + int(k10 == k00) + int(k11 == k00) + int(k01 == k00)
	var n10 := 1 + int(k00 == k10) + int(k11 == k10) + int(k01 == k10)
	var n11 := 1 + int(k00 == k11) + int(k10 == k11) + int(k01 == k11)
	var n01 := 1 + int(k00 == k01) + int(k10 == k01) + int(k11 == k01)
	var k1 := k00
	var best := n00
	if n10 > best:
		best = n10
		k1 = k10
	if n11 > best:
		best = n11
		k1 = k11
	if n01 > best:
		k1 = k01
	var k2 := k00 if k00 != k1 else (k10 if k10 != k1 else (k11 if k11 != k1 else (k01 if k01 != k1 else -1)))
	_k1 = k1
	_k2 = k2
	_w00 = 1.0 if k00 == k2 else 0.0
	_w10 = 1.0 if k10 == k2 else 0.0
	_w11 = 1.0 if k11 == k2 else 0.0
	_w01 = 1.0 if k01 == k2 else 0.0


## A wall along a terrace edge from p to q, from hb up to h, facing away from
## the point (ix, iz) on the high side, under ground key k.
func _wall(ch: Chunk, px: float, pz: float, qx: float, qz: float, ix: float, iz: float, hb: float, h: float, L: int, k: int) -> void:
	if (k & _KEY_WET) != 0 or L <= 0:
		# Water on the high side, or under the sea: a sheet covers the step.
		return
	var dx := qx - px
	var dz := qz - pz
	var len2 := dx * dx + dz * dz
	if len2 < 1e-8:
		return
	# The quad below faces (dz, -dx); flip so that points away from the high side.
	if dz * (ix - (px + qx) * 0.5) - dx * (iz - (pz + qz) * 0.5) > 0.0:
		var tx := px
		var tz := pz
		px = qx
		pz = qz
		qx = tx
		qz = tz
		dx = -dx
		dz = -dz
	var inv := 1.0 / sqrt(len2)
	var nrm := Vector3(dz * inv, 0.0, -dx * inv)
	var gi := ((k & 0xFF) * Country.COUNT + ((k >> 8) & 0xFF)) * 2 + (L & 1)
	var col := _tab_cliff[gi]
	var c0 := Color(col.r, col.g, col.b, 0.0)
	var a0 := Vector3(qx, hb, qz)
	var a1 := Vector3(px, h, pz)
	_tv.append(a0)
	_tv.append(a1)
	_tv.append(Vector3(px, hb, pz))
	_tv.append(a0)
	_tv.append(Vector3(qx, h, qz))
	_tv.append(a1)
	for v in 6:
		_tn.append(nrm)
		_tc.append(col)
		_tuv.append(_UV_CONTOUR)
		_tuv2.append(Vector2.ZERO)
		_tc0.append(c0)
	var lip := _tab_lip[gi]
	if lip > 0:
		_lip_strip(px, pz, qx, qz, nrm, h, gi, lip == 2)
	if h - hb > 0.3:
		ch.feet.append(Vector3((px + qx) * 0.5, hb, (pz + qz) * 0.5) + nrm * 0.18)
		ch.feet_out.append(nrm)
		ch.feet_country.append((k >> 8) & 0xFF)


## A ragged overhang of turf or snow along a terrace lip. Its reach at each end
## is a function of world position, so neighbouring cells meet exactly.
func _lip_strip(px: float, pz: float, qx: float, qz: float, nrm: Vector3, h: float, gi: int, snow: bool) -> void:
	var reach := 0.07 if snow else 0.045
	var op := reach * (0.7 + 0.3 * _lip.get_noise_2d(px, pz))
	var oq := reach * (0.7 + 0.3 * _lip.get_noise_2d(qx, qz))
	var extra := 0.09 if snow else 0.05
	var drop_p := extra + 0.04 * _lip.get_noise_2d(px + 31.0, pz)
	var drop_q := extra + 0.04 * _lip.get_noise_2d(qx + 31.0, qz)
	var top := _tab_col[gi]
	var front := _tab_front[gi]
	var hl := h + 0.004
	var pp := Vector3(px, hl, pz)
	var qq := Vector3(qx, hl, qz)
	var po := pp + nrm * op
	var qo := qq + nrm * oq
	var uv := Vector2(_tab_style[gi] * 17, 0.0)
	var c0 := Color(top.r, top.g, top.b, 0.0)
	var pd := po - Vector3(0, drop_p, 0)
	var qd := qo - Vector3(0, drop_q, 0)
	# Top (face up, see _vtop winding), then the front edge facing out.
	_tv.append(pp)
	_tv.append(po)
	_tv.append(qo)
	_tv.append(pp)
	_tv.append(qo)
	_tv.append(qq)
	_tv.append(pd)
	_tv.append(qo)
	_tv.append(po)
	_tv.append(pd)
	_tv.append(qd)
	_tv.append(qo)
	for v in 6:
		_tn.append(Vector3.UP)
		_tc.append(top)
	for v in 6:
		_tn.append(nrm)
		_tc.append(front)
	for v in 12:
		_tuv.append(uv)
		_tuv2.append(Vector2.ZERO)
		_tc0.append(c0)


## Signed distance (tiles) from each tile centre in [x0, x1) x [y0, y1) to the
## waterline: water positive, land negative. Exact within MARGIN tiles of the
## window, so neighbouring chunks agree. Row-major over the window.
func _shore_window(x0: int, y0: int, x1: int, y1: int) -> PackedFloat32Array:
	var w := world
	var size := w.size
	var wx0 := x0 - MARGIN
	var wy0 := y0 - MARGIN
	var ww := x1 - x0 + MARGIN * 2
	var wh := y1 - y0 + MARGIN * 2
	var wet := PackedByteArray()
	wet.resize(ww * wh)
	var any_wet := false
	var any_dry := false
	for y in wh:
		var ty := clampi(wy0 + y, 0, size - 1) * size
		var outside_y := wy0 + y < 0 or wy0 + y >= size
		for x in ww:
			var tx := wx0 + x
			var water := outside_y or tx < 0 or tx >= size
			if not water:
				var i := ty + tx
				water = w.level[i] <= 0 or Ground.is_water(w.ground[i])
			wet[y * ww + x] = 1 if water else 0
			if water:
				any_wet = true
			else:
				any_dry = true
	var out := PackedFloat32Array()
	var rw := x1 - x0
	out.resize(rw * (y1 - y0))
	if not any_wet or not any_dry:
		out.fill(float(MARGIN) if any_wet else -float(MARGIN))
		return out
	var d := PackedFloat32Array()
	d.resize(ww * wh)
	d.fill(99.0)
	for y in wh:
		for x in ww:
			var i := y * ww + x
			var here := wet[i]
			if (x > 0 and wet[i - 1] != here) or (x < ww - 1 and wet[i + 1] != here) or (y > 0 and wet[i - ww] != here) or (y < wh - 1 and wet[i + ww] != here):
				d[i] = 0.5
	var dg := 1.4142
	for y in wh:
		for x in ww:
			var i := y * ww + x
			var v := d[i]
			if x > 0:
				v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - ww] + 1.0)
				if x > 0:
					v = minf(v, d[i - ww - 1] + dg)
				if x < ww - 1:
					v = minf(v, d[i - ww + 1] + dg)
			d[i] = v
	for yy in wh:
		var y := wh - 1 - yy
		for xx in ww:
			var x := ww - 1 - xx
			var i := y * ww + x
			var v := d[i]
			if x < ww - 1:
				v = minf(v, d[i + 1] + 1.0)
			if y < wh - 1:
				v = minf(v, d[i + ww] + 1.0)
				if x < ww - 1:
					v = minf(v, d[i + ww + 1] + dg)
				if x > 0:
					v = minf(v, d[i + ww - 1] + dg)
			d[i] = v
	for i in d.size():
		d[i] = minf(d[i], float(MARGIN)) * (1.0 if wet[i] == 1 else -1.0)
	# Two blur passes: soundings follow the coast instead of its tile rows.
	for _pass in 2:
		var b := d.duplicate()
		for y in range(1, wh - 1):
			for x in range(1, ww - 1):
				var i := y * ww + x
				b[i] = (d[i] * 4.0 + d[i - 1] + d[i + 1] + d[i - ww] + d[i + ww]) / 8.0
		d = b
	for y in range(y0, y1):
		for x in range(x0, x1):
			out[(y - y0) * rw + (x - x0)] = d[(y - wy0) * ww + (x - wx0)]
	return out


## Water sheets. COLOR: r = kind / 8 (0 sea, 1 river or still water,
## 2 blackwater), g/b = flow direction * 0.5 + 0.5 (zero flow is still water),
## a = depth 0 (waterline) .. 1 (deep).
func _build_water(ch: Chunk, depth: PackedFloat32Array) -> void:
	var np := ch.n + 1
	var m := ch.h * RES
	var cnt := np * (m + 1)
	var w := world
	var size := w.size
	var sheet := PackedFloat32Array()
	sheet.resize(cnt)
	var col := PackedColorArray()
	col.resize(cnt)
	var any := false
	var flows := {}
	for j in m + 1:
		var ly := ch.y0 + j * 0.5
		for i in np:
			var li := j * np + i
			var k := ch.key[li]
			if (k & _KEY_WET) == 0:
				sheet[li] = INF
				continue
			any = true
			var terrace := ch.t[li]
			if terrace <= 0:
				sheet[li] = WATER_Y
				col[li] = Color(0.0, 0.5, 0.5, clampf(depth[li] / 9.0, 0.0, 1.0))
				continue
			var lx := ch.x0 + i * 0.5
			# Level water: a sheet over its terrace, under any bank (which lips up).
			sheet[li] = terrace * WorldData.STEP + WADE
			var kind := 2 if (k & 0xFF) == Ground.BLACKWATER else 1
			var flow := Vector2.ZERO
			if kind == 1:
				var ti := clampi(floori(ly), 0, size - 1) * size + clampi(floori(lx), 0, size - 1)
				if not flows.has(ti):
					flows[ti] = _flow(ti % size, ti / size)
				flow = flows[ti]
			col[li] = Color(kind / 8.0, flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, clampf(depth[li] / 2.5, 0.0, 1.0))
	if not any:
		return
	# Dry points beside water take the sheet and kind of a wet neighbour, at the
	# waterline.
	var fill := sheet.duplicate()
	for j in m + 1:
		for i in np:
			var li := j * np + i
			if sheet[li] != INF:
				continue
			var from := -1
			if i > 0 and sheet[li - 1] != INF:
				from = li - 1
			if i < np - 1 and sheet[li + 1] != INF and (from < 0 or sheet[li + 1] < sheet[from]):
				from = li + 1
			if j > 0 and sheet[li - np] != INF and (from < 0 or sheet[li - np] < sheet[from]):
				from = li - np
			if j < m and sheet[li + np] != INF and (from < 0 or sheet[li + np] < sheet[from]):
				from = li + np
			if from >= 0:
				# Tuck the sheet's edge under the land, so the waterline is where
				# the two cross and never a square of water over a bank.
				var t := ch.t[li]
				fill[li] = sheet[from] if t <= 0 else minf(sheet[from], level_height(t) + _lift(ch.key[li]) - 0.03)
				var c := col[from]
				col[li] = Color(c.r, c.g, c.b, 0.0)
	for j in m:
		var py := ch.y0 + j * 0.5
		var run := -1
		var run_h := 0.0
		var run_c := Color()
		for i in ch.n:
			var i00 := j * np + i
			var a := i00
			var b := i00 + 1
			var c := i00 + np + 1
			var d := i00 + np
			if (ch.key[a] & _KEY_WET) == 0 and (ch.key[b] & _KEY_WET) == 0 and (ch.key[c] & _KEY_WET) == 0 and (ch.key[d] & _KEY_WET) == 0:
				if run >= 0:
					_water_quad(ch.x0 + run * 0.5, ch.x0 + i * 0.5, py, run_h, run_h, run_h, run_h, run_c, run_c, run_c, run_c)
					run = -1
				continue
			var ha := fill[a]
			var ca := col[a]
			var uniform := fill[b] == ha and fill[c] == ha and fill[d] == ha and ha != INF and col[b] == ca and col[c] == ca and col[d] == ca
			if uniform:
				if run >= 0 and (ha != run_h or ca != run_c):
					_water_quad(ch.x0 + run * 0.5, ch.x0 + i * 0.5, py, run_h, run_h, run_h, run_h, run_c, run_c, run_c, run_c)
					run = -1
				if run < 0:
					run = i
					run_h = ha
					run_c = ca
				continue
			if run >= 0:
				_water_quad(ch.x0 + run * 0.5, ch.x0 + i * 0.5, py, run_h, run_h, run_h, run_h, run_c, run_c, run_c, run_c)
				run = -1
			var lo := minf(minf(fill[a], fill[b]), minf(fill[c], fill[d]))
			var wet_c := col[a] if fill[a] != INF else (col[b] if fill[b] != INF else (col[c] if fill[c] != INF else col[d]))
			var hb := fill[b] if fill[b] != INF else lo
			var hc := fill[c] if fill[c] != INF else lo
			var hd := fill[d] if fill[d] != INF else lo
			var h0 := ha if ha != INF else lo
			var px := ch.x0 + i * 0.5
			var ca2 := col[a] if ha != INF else wet_c
			var cb2 := col[b] if fill[b] != INF else wet_c
			var cc2 := col[c] if fill[c] != INF else wet_c
			var cd2 := col[d] if fill[d] != INF else wet_c
			# Where two waters at different levels meet, the sheet falls and breaks
			# white. A sheet tucked under a bank slopes too, but is no fall.
			var wet_lo := INF
			var wet_hi := -INF
			for q: int in [a, b, c, d]:
				if sheet[q] != INF:
					wet_lo = minf(wet_lo, sheet[q])
					wet_hi = maxf(wet_hi, sheet[q])
			if wet_hi - wet_lo > 0.1:
				ca2.r = 4.0 / 8.0
				cb2.r = 4.0 / 8.0
				cc2.r = 4.0 / 8.0
				cd2.r = 4.0 / 8.0
			_water_quad(px, px + 0.5, py, h0, hb, hc, hd, ca2, cb2, cc2, cd2)
		if run >= 0:
			_water_quad(ch.x0 + run * 0.5, ch.x0 + ch.n * 0.5, py, run_h, run_h, run_h, run_h, run_c, run_c, run_c, run_c)


func _water_quad(xa: float, xb: float, py: float, h00: float, h10: float, h11: float, h01: float, c00: Color, c10: Color, c11: Color, c01: Color) -> void:
	var v00 := Vector3(xa, h00, py)
	var v11 := Vector3(xb, h11, py + 0.5)
	_wv.append(v00)
	_wv.append(Vector3(xb, h10, py))
	_wv.append(v11)
	_wv.append(v00)
	_wv.append(v11)
	_wv.append(Vector3(xa, h01, py + 0.5))
	_wc.append(c00)
	_wc.append(c10)
	_wc.append(c11)
	_wc.append(c00)
	_wc.append(c11)
	_wc.append(c01)


## Downstream direction of an inland water tile: toward lower water, otherwise
## along the channel toward the nearer map edge; ZERO for still water.
func _flow(x: int, y: int) -> Vector2:
	var w := world
	var here := w.level_at(x, y)
	var acc := Vector2.ZERO
	var axis := Vector2.ZERO
	var wet_n := 0
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			if ox == 0 and oy == 0:
				continue
			var g := w.ground_at(x + ox, y + oy)
			if not Ground.is_water(g):
				continue
			wet_n += 1
			var dv := Vector2(ox, oy)
			var l := w.level_at(x + ox, y + oy)
			acc += dv.normalized() * float(here - l)
			var ang := dv.angle() * 2.0
			axis += Vector2(cos(ang), sin(ang))
	if w.ground_at(x, y) != Ground.RIVER:
		return Vector2.ZERO
	if acc.length() > 0.5:
		return acc.normalized()
	if axis.length() > 2.0 and wet_n < 20:
		var dir := Vector2.from_angle(axis.angle() * 0.5)
		var centre := Vector2(w.size * 0.5, w.size * 0.5)
		if dir.dot(Vector2(x, y) - centre) < 0.0:
			dir = -dir
		return dir
	return Vector2.ZERO
