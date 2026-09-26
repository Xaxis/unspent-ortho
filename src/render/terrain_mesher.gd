class_name TerrainMesher
extends RefCounted
## Builds one CHUNK x CHUNK tile area into meshes. The tile grid is the rules'
## business, never the eye's (docs/LOOK.md): the land is drawn as CONTOUR TERRACES.
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
## border (WorldData.blend, drawn through Transitions). A cell's two most
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
## How far (in tiles) a terrace edge may wander from the tile rows it follows,
## and over how many tiles it wanders. Slow on purpose: a fast or strong warp
## folds the field and kinks every edge into right-angled zigzags.
const DOMAIN_WARP := 1.0
const WARP_SCALE := 0.45
## The finer warp that frays ground and water edges: tiles, and per tile.
const FRAY := 0.3
const FRAY_SCALE := 0.9
## Inland water: the sheet stands this far above its tile's level (a walker's shins)...
const WADE := 0.3
## ...and the bed sinks this far below it.
const WET_SINK := 0.42
## Tiles of context around a chunk for distances to the waterline.
const MARGIN := 10
## Share of an ecotone drawn as the neighbour at blend b (0..0.5): nothing far
## out, then small tongues, then lobes that merge into an even mix on the border.
static func eco_cover(b: float) -> float:
	return 0.5 * pow(clampf(b * 2.0, 0.0, 1.0), 1.7)


## Share drawn as the higher-numbered country of a pair, at t = 0 (all the
## lower) .. 0.5 (the border) .. 1 (all the higher).
static func eco_share(t: float) -> float:
	return eco_cover(t) if t <= 0.5 else 1.0 - eco_cover(1.0 - t)

const _KEY_WET := 1 << 16
const NO_WET := -9.0
## The bits of a key that say how it is painted (ground, country, wet).
const _PAINT_BITS := 0x1FFFF
const INLAND_BANK := 1.0
const INLAND_SPAN := 3.5
## How far a bank at the level of the water beside it lips up: just above the
## inland sheet (WADE). Keys carry the shore profile index in bits 17-21.
const BANK_LIFT := 0.36
## Inland wetness at which the land is under the sheet, and where its lip begins.
const WET_EDGE := 0.4
const LIP_START := 0.3
## How much lower inland water counts in the smoothed elevation field.
const WATER_BIAS := 0.7
## Passes of the spur and notch filter on drawn levels (drawn_levels()).
const SPUR_PASSES := 2
static var _LIFTS := PackedFloat32Array()
var _blur: Dictionary = {}
## Cumulative build time of this mesher by stage (usec): fill, shore, tiles,
## cells, water, arrays, vertices, lattice. Per instance, so a mesher building
## on a worker thread never shares it (WorldView reads it for --stats).
var prof := PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0])
## Tiles of country and shore data kept around a chunk for warped lookups.
const RING := 2
## Tiles past a chunk its build reads (`TileWindow`): the transitions' country
## samples past the ring reach furthest, beyond the shore field's MARGIN and the
## spur filter's 3 + SPUR_PASSES. A read outside the window is an out-of-bounds
## error, never a wrong tile.
const WINDOW := RING + Transitions.WINDOW

var world: WorldData
var eco: Transitions
var _warp: FastNoiseLite
var _eco: FastNoiseLite
## The ecotone field: two octaves, lobes and the tongues on them, read through
## its own percentile table so a share of cover is a threshold.
var _eco2: FastNoiseLite
var _eco_cdf := PackedFloat32Array()
## How many of a country's own grounds an ecotone may borrow from.
const ECO_MENU := 3
## The commonest dry, unmade grounds of each country, most common first, tallied
## from the world itself so a landscape type new tomorrow needs no table here.
var _eco_ground := PackedInt32Array()
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
var _mar := PackedFloat32Array()
var _wetv := PackedFloat32Array()
var _np := 0
var _i00 := 0
var _bump_key := -1
var _bump_t := -99
const _UV_CONTOUR := Vector2(Ink.CONTOUR * 17, 0.0)
static var _WET := PackedByteArray()
## Hummock height by ground.
static var _BUMP := PackedFloat32Array()

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
	## Surface arrays, until commit() turns them into the meshes above (a
	## worker thread builds arrays; meshes are made on the main thread).
	var terrain_arrays: Array = []
	var water_arrays: Array = []
	## Per lattice point ((n + 1) * (h * RES + 1), row-major): field, terrace, key.
	var f := PackedFloat32Array()
	var t := PackedInt32Array()
	var key := PackedInt32Array()
	## How far each lattice point is from the nearest change of key, 0 (on it)
	## to 1 (well clear), so a ground edge is interpolated as a curve and not
	## as the lattice's triangles.
	var margin := PackedFloat32Array()
	## Per lattice point: inland wetness less WET_EDGE (>= 0 under the sheet),
	## or NO_WET where no inland water is near.
	var wet := PackedFloat32Array()
	## Per tile of the chunk: signed tiles to the waterline, + in water, - on land.
	var shore := PackedFloat32Array()
	## Cliff feet: point on the lower terrace, outward direction, country.
	var feet := PackedVector3Array()
	var feet_out := PackedVector3Array()
	var feet_country := PackedByteArray()
	## Terrace edges as drawn: the top of every wall, as point pairs.
	var edges := PackedVector3Array()
	## Per tile of the chunk: the neighbour country across an ecotone (0 none)
	## and how far toward it the tile has turned (0..0.5, Transitions.fill).
	var c2 := PackedByteArray()
	var blend := PackedFloat32Array()
	## Make the meshes from the arrays (main thread).
	func commit() -> void:
		terrain = ArrayMesh.new()
		if not terrain_arrays.is_empty():
			var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
			terrain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, terrain_arrays, [], {}, flags)
		water = null
		if not water_arrays.is_empty():
			water = ArrayMesh.new()
			water.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, water_arrays)
		terrain_arrays = []
		water_arrays = []

	## Per lattice point: hummock height added to the terrace (soft ground only).
	var bump := PackedFloat32Array()

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
			if not bump.is_empty():
				ht += lerpf(lerpf(bump[a], bump[a + 1], fu), lerpf(bump[a + n + 1], bump[a + n + 2], fu), fv)
		return ht


static func _static_init() -> void:
	_WET.resize(256)
	for g in 256:
		_WET[g] = 1 if Ground.is_water(g) else 0
	_BUMP.resize(256)
	_BUMP[Ground.MOSS] = 0.1
	_BUMP[Ground.PEAT] = 0.06
	_BUMP[Ground.SNOW] = 0.07
	_BUMP[Ground.HEATH] = 0.04
	_LIFTS.resize(32)
	_LIFTS[0] = 0.0
	for i in range(1, 32):
		_LIFTS[i] = _profile(LIP_START + (i - 1) / 30.0 * (1.0 - LIP_START))


func _init(w: WorldData) -> void:
	world = w
	eco = Transitions.new(w)
	_warp = FastNoiseLite.new()
	_warp.seed = Rng.hash_ints(w.seed_value, 32) & 0x7FFFFFFF
	_warp.frequency = 1.0 / 3.5
	_warp.fractal_octaves = 2
	_eco = FastNoiseLite.new()
	_eco.seed = Rng.hash_ints(w.seed_value, 33) & 0x7FFFFFFF
	_eco.frequency = 1.0 / 7.0
	_eco.fractal_octaves = 3
	_eco2 = FastNoiseLite.new()
	_eco2.seed = Rng.hash_ints(w.seed_value, 35) & 0x7FFFFFFF
	_eco2.frequency = 1.0 / 11.0
	_eco2.fractal_octaves = 2
	_eco2.fractal_lacunarity = 2.6
	_eco2.fractal_gain = 0.45
	var hist := PackedInt32Array()
	hist.resize(256)
	for i in 4096:
		var v := _eco2.get_noise_2d(float(i % 64) * 5.37 + 0.31, float(i / 64) * 5.61 + 0.77)
		hist[clampi(int((v + 1.0) * 128.0), 0, 255)] += 1
	_eco_cdf.resize(256)
	var acc := 0
	for i in 256:
		acc += hist[i]
		_eco_cdf[i] = float(acc) / 4096.0
	_tally_grounds(w)
	_lip = FastNoiseLite.new()
	_lip.seed = Rng.hash_ints(w.seed_value, 34) & 0x7FFFFFFF
	_lip.frequency = 1.3
	_lip.fractal_octaves = 1
	# Paint per (ground, landscape type, terrace parity): wash with its mark in alpha.
	var types := BiomeRegistry.SLOTS
	_tab_col.resize(Ground.COUNT * types * 2)
	_tab_style.resize(Ground.COUNT * types * 2)
	_tab_cliff.resize(Ground.COUNT * types * 2)
	_tab_front.resize(Ground.COUNT * types * 2)
	_tab_lip.resize(Ground.COUNT * types * 2)
	for g in Ground.COUNT:
		for c in BiomeRegistry.count():
			var def := BiomeRegistry.by_index(c)
			for parity in 2:
				var col := GroundColors.wash(g, c)
				# Terraces one level apart alternate a hair in value: the contour is felt, not seen.
				if parity == 1:
					col = col.darkened(0.03)
				col.a = GroundColors.mark(g, c) / 255.0
				var i := (g * types + c) * 2 + parity
				_tab_col[i] = col
				_tab_style[i] = def.hatch
				var cl := GroundColors.cliff(g, c)
				if parity == 1:
					cl = cl.darkened(0.06)
				cl.a = (GroundColors.STRATA + GroundColors.strata(g, c)) / 255.0
				_tab_cliff[i] = cl
				var snow := g == Ground.SNOW or (def.lip_snow and g != Ground.ICE and g != Ground.SAND and g != Ground.SHINGLE and g != Ground.ROCK and g != Ground.SCREE and not Ground.is_water(g))
				var turf := g == Ground.GRASS or g == Ground.HEATH or g == Ground.MOSS or g == Ground.PEAT or g == Ground.NEEDLES
				_tab_lip[i] = 2 if snow else (1 if turf else 0)
				var fr := Palette.RIME[4] if snow else GroundColors.down(col, 1.0)
				fr.a = 1.0
				_tab_front[i] = fr


## What each LANDSCAPE TYPE is laid with: the commonest dry, unmade grounds it
## carries, most common first. Read every second tile — it is a share, not a
## census. Keyed by the registry's type index, so a landscape added as a file
## is tallied with the rest and needs nothing here.
func _tally_grounds(w: WorldData) -> void:
	var types := BiomeRegistry.count()
	_eco_ground.resize(types * ECO_MENU)
	_eco_ground.fill(-1)
	var count := PackedInt32Array()
	count.resize(types * Ground.COUNT)
	var size := w.size
	for y in range(0, size, 2):
		var row := y * size
		for x in range(0, size, 2):
			var g: int = w.ground[row + x]
			if _WET[g] == 1 or g == Ground.ROAD or g == Ground.FLOOR:
				continue
			count[w.country[row + x] * Ground.COUNT + g] += 1
	for c: int in types:
		var base: int = c * Ground.COUNT
		for slot in ECO_MENU:
			var best := -1
			var best_n := 0
			for g in Ground.COUNT:
				if count[base + g] > best_n:
					best_n = count[base + g]
					best = g
			if best < 0:
				break
			_eco_ground[c * ECO_MENU + slot] = best
			count[base + best] = 0


## A cell drawn as its neighbour across an ecotone carries that neighbour's
## GROUND too, not only its tint. Flipping the country alone changes the wash by
## whatever the country's ramp does to the ground already there, and where two
## landscapes are laid with different grounds — pale limestone against ash —
## that is far too little: the marks, the hatch and most of the value belong to
## the ground, so the band stayed a seam however ragged the country field was
## (art review 13). Water, road and floor are never borrowed over: a river or a
## made surface crosses a border as itself.
func _eco_borrow(c: int, g: int, sx: float, sy: float) -> int:
	if _WET[g] == 1 or g == Ground.ROAD or g == Ground.FLOOR or _eco_ground.is_empty():
		return g
	var first := _eco_ground[c * ECO_MENU]
	if first < 0:
		return g
	# Which of its grounds, in lobes of about fifteen units: a borrowed patch is
	# laid the way that country is laid, never speckled ground by ground.
	var f := _eco.get_noise_2d(sx * 0.5 + 900.0, sy * 0.5 + 900.0) * 0.5 + 0.5
	var pick := _eco_ground[c * ECO_MENU + clampi(int(f * float(ECO_MENU)), 0, ECO_MENU - 1)]
	return pick if pick >= 0 else first


## The ecotone field's percentile at ring point (gx, gy), bilinear.
func _eco_p(grid: PackedFloat32Array, gx: float, gy: float, rw: int) -> float:
	var ix := clampi(floori(gx), 0, rw - 1)
	var iy := clampi(floori(gy), 0, grid.size() / (rw + 1) - 2)
	var fx := clampf(gx - ix, 0.0, 1.0)
	var fy := clampf(gy - iy, 0.0, 1.0)
	var a := iy * (rw + 1) + ix
	var top := grid[a] + (grid[a + 1] - grid[a]) * fx
	return top + ((grid[a + rw + 1] + (grid[a + rw + 2] - grid[a + rw + 1]) * fx) - top) * fy


## The weight by which the last _major4() choice beat the runner-up.
var _major_margin := 1.0


## The value among four with the most bilinear weight; _major_margin says by
## how much it beat the runner-up.
func _major4(v0: int, v1: int, v2: int, v3: int, w00: float, w10: float, w01: float, w11: float) -> int:
	var s0 := w00 + (w10 if v1 == v0 else 0.0) + (w01 if v2 == v0 else 0.0) + (w11 if v3 == v0 else 0.0)
	var s1 := 0.0 if v1 == v0 else w10 + (w01 if v2 == v1 else 0.0) + (w11 if v3 == v1 else 0.0)
	var s2 := 0.0 if v2 == v0 or v2 == v1 else w01 + (w11 if v3 == v2 else 0.0)
	var s3 := w11 if v3 != v0 and v3 != v1 and v3 != v2 else 0.0
	var best := v0
	var bw := s0
	var second := 0.0
	if s1 > bw:
		second = bw
		bw = s1
		best = v1
	elif s1 > second:
		second = s1
	if s2 > bw:
		second = bw
		bw = s2
		best = v2
	elif s2 > second:
		second = s2
	if s3 > bw:
		second = bw
		bw = s3
		best = v3
	elif s3 > second:
		second = s3
	_major_margin = (bw - second) * 1.6
	return best


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


## How grid-like drawn terrace edges are (for tests and tuning): chains the
## edge segments of a chunk into polylines, walks each at quarter-tile steps and
## counts CORNERS, places where the line turns more than 60 degrees within half
## a tile either side. Returns [edge length in tiles, corners].
static func edge_corners(edges: PackedVector3Array) -> PackedFloat32Array:
	var ends := {}
	var nseg := edges.size() / 2
	for s in nseg:
		for e in 2:
			var p := edges[s * 2 + e]
			var key := Vector3i(roundi(p.x * 500.0), roundi(p.y * 500.0), roundi(p.z * 500.0))
			if not ends.has(key):
				ends[key] = PackedInt32Array()
			var arr: PackedInt32Array = ends[key]
			arr.append(s * 2 + e)
			ends[key] = arr
	var used := PackedByteArray()
	used.resize(nseg)
	var length := 0.0
	var corners := 0.0
	for s0 in nseg:
		if used[s0] == 1:
			continue
		# Walk back to a chain's start (or once round a loop), then forward.
		var cur := s0 * 2
		var guard := nseg
		while guard > 0:
			guard -= 1
			var p := edges[cur]
			var key := Vector3i(roundi(p.x * 500.0), roundi(p.y * 500.0), roundi(p.z * 500.0))
			var arr: PackedInt32Array = ends[key]
			if arr.size() != 2:
				break
			var other := arr[0] if arr[0] != cur else arr[1]
			var nxt := other ^ 1
			if nxt / 2 == s0:
				break
			cur = nxt
		var pts := PackedVector3Array()
		pts.append(edges[cur])
		var seg := cur
		while true:
			var sidx := seg / 2
			if used[sidx] == 1:
				break
			used[sidx] = 1
			var far := edges[seg ^ 1]
			pts.append(far)
			var key := Vector3i(roundi(far.x * 500.0), roundi(far.y * 500.0), roundi(far.z * 500.0))
			var arr: PackedInt32Array = ends[key]
			if arr.size() != 2:
				break
			seg = arr[0] if arr[0] != (seg ^ 1) else arr[1]
		# Resample at a quarter tile.
		var rs := PackedVector2Array()
		rs.append(Vector2(pts[0].x, pts[0].z))
		var carry := 0.0
		for i in range(1, pts.size()):
			var a := Vector2(pts[i - 1].x, pts[i - 1].z)
			var b := Vector2(pts[i].x, pts[i].z)
			var d := a.distance_to(b)
			length += d
			var t := 0.25 - carry
			while t <= d:
				rs.append(a.lerp(b, t / d))
				t += 0.25
			carry = d - (t - 0.25)
		var in_corner := false
		for i in range(2, rs.size() - 2):
			var u := rs[i] - rs[i - 2]
			var v := rs[i + 2] - rs[i]
			if u.length() < 0.3 or v.length() < 0.3:
				continue
			var sharp := absf(u.angle_to(v)) > deg_to_rad(60.0)
			if sharp and not in_corner:
				corners += 1.0
			in_corner = sharp
	return PackedFloat32Array([length, corners])


static func level_height(l: int) -> float:
	if l > 0:
		return l * WorldData.STEP
	return 0.0 if l == 0 else SEA_FLOOR


func _lv(x: int, y: int, win: TileWindow) -> float:
	var i := win.at(clampi(x, 0, world.size - 1), clampi(y, 0, world.size - 1))
	var l := drawn_levels(x, y, 1, 1, win)[0]
	return float(l) - (WATER_BIAS if l > 0 and _WET[win.ground[i]] == 1 else 0.0)


## The levels the land is DRAWN at over the tile rectangle (x0, y0, w, h),
## row-major. The rules' level everywhere, except that a dry tile standing out
## of its neighbours alone (a one-tile spur, notch or pit: at most one of its
## four neighbours shares its level, and five of its eight share another) is
## drawn at theirs. Contours are forced through every tile centre's own side,
## so without this each such tile turns the wall in a right-angled notch.
## Two passes, so a two-tile finger goes as well. Inland water and the sea are
## never moved, and nothing is drawn into the sea. Read from `win`, which must
## hold the rectangle and SPUR_PASSES round it; one is made when none is given.
func drawn_levels(x0: int, y0: int, w: int, h: int, win: TileWindow = null) -> PackedInt32Array:
	const PAD := SPUR_PASSES
	var size := world.size
	if win == null:
		win = TileWindow.of(world, x0 - PAD, y0 - PAD, x0 + w + PAD, y0 + h + PAD)
	var ww := w + PAD * 2
	var wh := h + PAD * 2
	var lv := PackedInt32Array()
	lv.resize(ww * wh)
	var dry := PackedByteArray()
	dry.resize(ww * wh)
	var level := win.level
	var ground := win.ground
	for yy in wh:
		var ty := (clampi(y0 - PAD + yy, 0, size - 1) - win.y0) * win.w - win.x0
		for xx in ww:
			var ti := ty + clampi(x0 - PAD + xx, 0, size - 1)
			var l: int = level[ti]
			lv[yy * ww + xx] = l
			dry[yy * ww + xx] = 1 if l > 0 and _WET[ground[ti]] == 0 else 0
	for _pass in SPUR_PASSES:
		var out := lv.duplicate()
		for yy in range(1, wh - 1):
			for xx in range(1, ww - 1):
				var i := yy * ww + xx
				if dry[i] == 0:
					continue
				var l := lv[i]
				var a := lv[i - 1]
				var b := lv[i + 1]
				var c := lv[i - ww]
				var d := lv[i + ww]
				if int(a == l) + int(b == l) + int(c == l) + int(d == l) >= 2:
					continue
				var best := l
				var best_n := 0
				for o: int in [i - 1, i + 1, i - ww, i + ww, i - ww - 1, i - ww + 1, i + ww - 1, i + ww + 1]:
					var m := lv[o]
					if m == l or m < 1 or m == best:
						continue
					var cnt := int(a == m) + int(b == m) + int(c == m) + int(d == m) + int(lv[i - ww - 1] == m) + int(lv[i - ww + 1] == m) + int(lv[i + ww - 1] == m) + int(lv[i + ww + 1] == m)
					if cnt > best_n:
						best_n = cnt
						best = m
				if best_n >= 5:
					out[i] = best
		lv = out
	if PAD == 0:
		return lv
	var inner := PackedInt32Array()
	inner.resize(w * h)
	for yy in h:
		for xx in w:
			inner[yy * w + xx] = lv[(yy + PAD) * ww + xx + PAD]
	return inner


## A tile's drawn level blurred over its neighbours, but never out of its own
## terrace: the shape between tile centres is smoothed, the rules are not.
## Inland water counts a little lower, so a one-tile river keeps its terrace
## right across its width instead of pinching to a thread between its banks.
## `win` must hold the tile, its neighbours and SPUR_PASSES round them.
func smooth_level(x: int, y: int, win: TileWindow = null) -> float:
	if win == null:
		win = TileWindow.of(world, x - 1 - SPUR_PASSES, y - 1 - SPUR_PASSES, x + 2 + SPUR_PASSES, y + 2 + SPUR_PASSES)
	var c := _lv(x, y, win)
	var own := float(drawn_levels(x, y, 1, 1, win)[0])
	var sum := c * 4.0
	sum += (_lv(x - 1, y, win) + _lv(x + 1, y, win) + _lv(x, y - 1, win) + _lv(x, y + 1, win)) * 2.0
	sum += _lv(x - 1, y - 1, win) + _lv(x + 1, y - 1, win) + _lv(x - 1, y + 1, win) + _lv(x + 1, y + 1, win)
	return clampf(sum / 16.0, own - 0.45, own + 0.45)


## Near an edge the field is read through a gentle domain warp, so the contour
## wanders like a drawn coast instead of running along tile rows. `smooth` is a window of smooth_level() starting at (ox-1, oy-1).
func _edge_field(x: float, y: float, smooth: PackedFloat32Array, sw: int, ox: int, oy: int, dwx: float, dwy: float) -> float:
	var gx := x + dwx - 0.5
	var gy := y + dwy - 0.5
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
	return (la + (lb - la) * fx) + ((lc + (ld - lc) * fx) - (la + (lb - la) * fx)) * fy


## The warps at a tile corner: the slow domain warp that bends contours
## (x, y) and the finer one that frays ground edges (z, w). Sampled at tile
## corners and read bilinearly, so neighbouring chunks agree and a chunk costs
## a few hundred noise reads instead of thousands.
func _warp_corner(x: int, y: int) -> Vector4:
	return Vector4(
		_warp.get_noise_2d(x * WARP_SCALE + 70.0, y * WARP_SCALE) * DOMAIN_WARP,
		_warp.get_noise_2d(x * WARP_SCALE, y * WARP_SCALE + 70.0) * DOMAIN_WARP,
		_warp.get_noise_2d(x * FRAY_SCALE + 50.0, y * FRAY_SCALE) * FRAY,
		_warp.get_noise_2d(x * FRAY_SCALE, y * FRAY_SCALE + 50.0) * FRAY)


## The warps at any point (bilinear between tile corners).
func warp_at(x: float, y: float) -> Vector4:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	return _warp_corner(ix, iy).lerp(_warp_corner(ix + 1, iy), fx).lerp(_warp_corner(ix, iy + 1).lerp(_warp_corner(ix + 1, iy + 1), fx), fy)


## The continuous elevation field, in levels, at tile-space point (x, y).
func field(x: float, y: float) -> float:
	var gx := x - 0.5
	var gy := y - 0.5
	var ix := floori(gx)
	var iy := floori(gy)
	var fx := gx - ix
	var fy := gy - iy
	# Every tile this reads: smooth levels from ix-2 to ix+3, each a tile and
	# SPUR_PASSES further.
	const R := 3 + SPUR_PASSES
	var tiles := TileWindow.of(world, ix - R, iy - R, ix + R + 2, iy + R + 2)
	# Warp only where the land actually changes height, so flats stay flat.
	if _lv(ix, iy, tiles) != _lv(ix + 1, iy, tiles) or _lv(ix, iy, tiles) != _lv(ix, iy + 1, tiles) or _lv(ix, iy, tiles) != _lv(ix + 1, iy + 1, tiles):
		var win := PackedFloat32Array()
		win.resize(36)
		for yy in 6:
			for xx in 6:
				win[yy * 6 + xx] = smooth_level(ix - 2 + xx, iy - 2 + yy, tiles)
		var wp := warp_at(x, y)
		return _edge_field(x, y, win, 6, ix - 1, iy - 1, wp.x, wp.y)
	return lerpf(lerpf(smooth_level(ix, iy, tiles), smooth_level(ix + 1, iy, tiles), fx), lerpf(smooth_level(ix, iy + 1, tiles), smooth_level(ix + 1, iy + 1, tiles), fx), fy)


## Height of the drawn land at a point, for things placed outside a chunk build.
func surface_height(x: float, y: float) -> float:
	return level_height(floori(field(x, y) + 0.5))


## The map tool's colour for a tile.
func top_color(x: int, y: int) -> Color:
	return GroundColors.wash(world.ground_at(x, y), maxi(Country.COAST, world.country_at(x, y)))


## Build a chunk with its meshes (main thread).
func build(cx: int, cy: int) -> Chunk:
	var ch := build_arrays(cx, cy)
	ch.commit()
	return ch


## Build a chunk's data and surface arrays but no meshes: safe on a worker
## thread, as long as this mesher is used by one thread at a time.
func build_arrays(cx: int, cy: int) -> Chunk:
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
	# Every tile this build reads, and no other (a streamed world holds only
	# some sections).
	var win := TileWindow.of(w, x0 - WINDOW, y0 - WINDOW, x1 + WINDOW, y1 + WINDOW)
	# Countries and transitions over the chunk and a ring (the ground lookup is
	# warped by up to RING tiles).
	var rx0 := x0 - RING
	var ry0 := y0 - RING
	var rw := ch.w + RING * 2
	var rh := ch.h + RING * 2
	var rc := PackedByteArray()
	var rc2 := PackedByteArray()
	var rb := PackedFloat32Array()
	eco.fill(rx0, ry0, x1 + RING, y1 + RING, rc, rc2, rb, win)
	var _t1 := Time.get_ticks_usec()
	var shore := _shore_window(rx0, ry0, x1 + RING, y1 + RING, win)
	# `has_water` is "within MARGIN of the waterline", which the DEPTH FIELD needs
	# for the terrain shader. The water MESH needs the stronger thing: a lattice
	# point actually wet. A chunk nine tiles inland satisfies the first and not
	# the second, and paid `_build_water`'s whole first sweep — 4,225 points and a
	# 4,225-entry PackedColorArray — before its own `if not any: return` fired.
	# That early-out is the proof the skipped work produces nothing, so gating on
	# `any_wet` is output-identical by the mesher's own argument rather than mine.
	var has_water := false
	for v in shore:
		if v > -float(MARGIN):
			has_water = true
			break
	var any_wet := false
	var _t2 := Time.get_ticks_usec()
	# The ecotone field at tile corners of the ring, as percentiles (only when
	# any of the ring lies in a band).
	var eco_grid := PackedFloat32Array()
	for v in rb:
		if v > 0.0:
			eco_grid.resize((rw + 1) * (rh + 1))
			for yy in rh + 1:
				for xx in rw + 1:
					var ev := _eco2.get_noise_2d(rx0 + xx, ry0 + yy)
					eco_grid[yy * (rw + 1) + xx] = _eco_cdf[clampi(int((ev + 1.0) * 128.0), 0, 255)]
			break
	ch.shore.resize(ch.w * ch.h)
	ch.c2.resize(ch.w * ch.h)
	ch.blend.resize(ch.w * ch.h)
	for y in ch.h:
		for x in ch.w:
			var ro := (y + RING) * rw + x + RING
			ch.shore[y * ch.w + x] = shore[ro]
			ch.c2[y * ch.w + x] = rc2[ro] if rc[ro] != rc2[ro] else 0
			ch.blend[y * ch.w + x] = rb[ro]
	var level := win.level
	var ground := win.ground
	# Per tile of the ring: the tile's ground and whether it holds inland water.
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
			var ti := (ty - win.y0) * win.w + tx - win.x0
			var g: int = ground[ti]
			if _WET[g] == 1 and level[ti] > 0:
				inland = true
				wl[o] = level[ti]
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
	var raw := drawn_levels(x0 - 3, y0 - 3, aw, ah, win)
	var biased := PackedFloat32Array()
	biased.resize(aw * ah)
	for yy in ah:
		var ty := (clampi(y0 - 3 + yy, 0, size - 1) - win.y0) * win.w - win.x0
		for xx in aw:
			var ti := ty + clampi(x0 - 3 + xx, 0, size - 1)
			var l: int = raw[yy * aw + xx]
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
	ch.margin.resize(cnt)
	ch.margin.fill(1.0)
	ch.wet.resize(cnt)
	ch.wet.fill(NO_WET)
	var depth := PackedFloat32Array()
	depth.resize(cnt)
	# Warps at the tile corners round the chunk, from x0 - 1, y0 - 1.
	var ww := ch.w + 3
	var wh := ch.h + 3
	var warps := PackedFloat32Array()
	warps.resize(ww * wh * 4)
	for yy in wh:
		for xx in ww:
			var wv := _warp_corner(x0 - 1 + xx, y0 - 1 + yy)
			var wo := (yy * ww + xx) * 4
			warps[wo] = wv.x
			warps[wo + 1] = wv.y
			warps[wo + 2] = wv.z
			warps[wo + 3] = wv.w
	# CALM ring tiles: the same ground and country, no ecotone and no inland
	# water for three tiles round, so any warp lands on the same key and a
	# lattice point there needs no warps, no majority and no margins.
	var rough := PackedInt32Array()
	rough.resize((rw + 1) * (rh + 1))
	for yy in rh:
		for xx in rw:
			var o := yy * rw + xx
			var r := 1 if (rb[o] > 0.0 and rc2[o] != rc[o]) or wl[o] != 0 or near[o] != 0 else 0
			if xx < rw - 1 and (tg[o + 1] != tg[o] or rc[o + 1] != rc[o]):
				r = 1
			if yy < rh - 1 and (tg[o + rw] != tg[o] or rc[o + rw] != rc[o]):
				r = 1
			# Summed-area table, one row and column of padding.
			rough[(yy + 1) * (rw + 1) + xx + 1] = r + rough[yy * (rw + 1) + xx + 1] + rough[(yy + 1) * (rw + 1) + xx] - rough[yy * (rw + 1) + xx]
	var calm := PackedByteArray()
	calm.resize(rw * rh)
	for yy in rh:
		var ya := maxi(0, yy - 3)
		var yb := mini(rh, yy + 3)
		for xx in rw:
			var xa := maxi(0, xx - 3)
			var xb := mini(rw, xx + 3)
			var sum := rough[yb * (rw + 1) + xb] - rough[ya * (rw + 1) + xb] - rough[yb * (rw + 1) + xa] + rough[ya * (rw + 1) + xa]
			calm[yy * rw + xx] = 1 if sum == 0 and xx >= 3 and yy >= 3 and xx < rw - 3 and yy < rh - 3 else 0
	var _t3 := Time.get_ticks_usec()
	# Locals, not members, in the hot loop: a member write costs several reads.
	var lf := ch.f
	var lt := ch.t
	var lk := ch.key
	var lm := ch.margin
	var lw := ch.wet
	ch.f = PackedFloat32Array()
	ch.t = PackedInt32Array()
	ch.key = PackedInt32Array()
	ch.margin = PackedFloat32Array()
	ch.wet = PackedFloat32Array()
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
			var level_flat := r0 == raw[ri + 1] and r0 == raw[ri + aw] and r0 == raw[ri + aw + 1]
			if level_flat and r0 > 0:
				var ct := (floori(sy) - ry0) * rw + (floori(sx) - rx0)
				if calm[ct] == 1:
					var la := smooth[ss]
					var lb := smooth[ss + 1]
					var top := la + (lb - la) * fx
					var lc := smooth[ss + sw]
					v = top + ((lc + (smooth[ss + sw + 1] - lc) * fx) - top) * fy
					lf[li] = v
					var terrace := floori(v + 0.5)
					lt[li] = terrace
					var g: int = tg[ct]
					if _WET[g] == 1:
						g = GroundColors.bank(rc[ct])
					lk[li] = g | (int(rc[ct]) << 8)
					if has_water:
						var so := clampi(iy - ry0, 0, rh - 2) * rw + clampi(ix - rx0, 0, rw - 2)
						var sa := shore[so]
						var top_s := sa + (shore[so + 1] - sa) * fx
						var sc := shore[so + rw]
						depth[li] = top_s + ((sc + (shore[so + rw + 1] - sc) * fx) - top_s) * fy
					else:
						depth[li] = -float(MARGIN)
					continue
			# The warps here, bilinear in the corner grid (lattice points fall on
			# tile corners and half tiles).
			var wxi := clampi(floori(sx) - x0 + 1, 0, ww - 2)
			var wyi := clampi(floori(sy) - y0 + 1, 0, wh - 2)
			var wfx := sx - floori(sx)
			var wfy := sy - floori(sy)
			var q00 := (wyi * ww + wxi) * 4
			var q10 := q00 + 4
			var q01 := q00 + ww * 4
			var q11 := q01 + 4
			var dwx := lerpf(lerpf(warps[q00], warps[q10], wfx), lerpf(warps[q01], warps[q11], wfx), wfy)
			var dwy := lerpf(lerpf(warps[q00 + 1], warps[q10 + 1], wfx), lerpf(warps[q01 + 1], warps[q11 + 1], wfx), wfy)
			var frx := lerpf(lerpf(warps[q00 + 2], warps[q10 + 2], wfx), lerpf(warps[q01 + 2], warps[q11 + 2], wfx), wfy)
			var fry := lerpf(lerpf(warps[q00 + 3], warps[q10 + 3], wfx), lerpf(warps[q01 + 3], warps[q11 + 3], wfx), wfy)
			if not level_flat:
				v = _edge_field(sx, sy, smooth, sw, x0 - 1, y0 - 1, dwx, dwy)
			else:
				var la := smooth[ss]
				var lb := smooth[ss + 1]
				var top := la + (lb - la) * fx
				var lc := smooth[ss + sw]
				v = top + ((lc + (smooth[ss + sw + 1] - lc) * fx) - top) * fy
			lf[li] = v
			var terrace := floori(v + 0.5)
			lt[li] = terrace
			if terrace <= 0:
				# The sea bed is never seen: one key, so it merges into runs.
				lk[li] = Ground.WATER | _KEY_WET
				any_wet = true
			else:
				# Ground under a warp, so type boundaries (and the edges of inland
				# water) wander with the contours instead of following tiles.
				var wx := sx + 0.01 + dwx + frx
				var wy := sy + 0.01 + dwy + fry
				# Ground and country from the four tiles round the point, the one
				# with most weight: a boundary is a curve through the corners of
				# the tiles, never their staircase.
				var gxw := wx - 0.5 - rx0
				var gyw := wy - 0.5 - ry0
				gxw = 0.0 if gxw < 0.0 else (rw - 1.001 if gxw > rw - 1.001 else gxw)
				gyw = 0.0 if gyw < 0.0 else (rh - 1.001 if gyw > rh - 1.001 else gyw)
				var ixw := int(gxw)
				var iyw := int(gyw)
				var fxw := gxw - ixw
				var fyw := gyw - iyw
				var o00 := iyw * rw + ixw
				var o10 := o00 + 1
				var o01 := o00 + rw
				var o11 := o01 + 1
				var w00 := (1.0 - fxw) * (1.0 - fyw)
				var w10 := fxw * (1.0 - fyw)
				var w01 := (1.0 - fxw) * fyw
				var w11 := fxw * fyw
				var o := o00
				var wo := w00
				if w10 > wo:
					o = o10
					wo = w10
				if w01 > wo:
					o = o01
					wo = w01
				if w11 > wo:
					o = o11
				var em := 1.0
				var g: int = tg[o]
				var g0: int = tg[o00]
				var g1: int = tg[o10]
				var g2: int = tg[o01]
				var g3: int = tg[o11]
				if g0 != g or g1 != g or g2 != g or g3 != g:
					g = _major4(g0, g1, g2, g3, w00, w10, w01, w11)
					em = _major_margin
				var c: int = rc[o]
				var c0: int = rc[o00]
				var c1: int = rc[o10]
				var c2b: int = rc[o01]
				var c3: int = rc[o11]
				if c0 != c or c1 != c or c2b != c or c3 != c:
					c = _major4(c0, c1, c2b, c3, w00, w10, w01, w11)
					em = minf(em, _major_margin)
					if rc[o] != c:
						o = o00 if c0 == c else (o10 if c1 == c else (o01 if c2b == c else o11))
				var dc := c
				var c2: int = rc2[o]
				if c2 != c and eco_grid.size() > 0 and rb[o00] + rb[o10] + rb[o01] + rb[o11] > 0.0:
					# Which of the pair is drawn: the share of the higher country
					# across the four tiles, smooth through the border itself.
					var lo := mini(c, c2)
					var hi := maxi(c, c2)
					var tsum := 0.0
					var wsum := 0.0
					for qi in 4:
						var q := o00 if qi == 0 else (o10 if qi == 1 else (o01 if qi == 2 else o11))
						var qw := w00 if qi == 0 else (w10 if qi == 1 else (w01 if qi == 2 else w11))
						var qc: int = rc[q]
						var qb: float = rb[q] if rc2[q] == (hi if qc == lo else lo) else 0.0
						if qc == lo:
							tsum += qb * qw
							wsum += qw
						elif qc == hi:
							tsum += (1.0 - qb) * qw
							wsum += qw
					var t := tsum / maxf(wsum, 1e-4)
					if t > 0.0 and t < 1.0:
						var ep := _eco_p(eco_grid, wx - rx0, wy - ry0, rw) - eco_share(t)
						dc = hi if ep < 0.0 else lo
						em = minf(em, absf(ep) * 9.0)
						if dc != c:
							g = _eco_borrow(dc, g, sx, sy)
				var extra := 0
				var wf := 0.0
				if inland and near[(floori(sy) - ry0) * rw + (floori(sx) - rx0)] == 1:
					# Inland water is a smooth field read through a small warp: its
					# shore slopes up to a narrow lip and down to a bed, so the sheet
					# meets the land on a curve, while every water tile's centre stays
					# wet and every dry tile's centre stays dry and unlifted.
					var qx := sx + frx
					var qy := sy + fry
					wf = _wet_field(qx, qy, terrace, wl, rx0, ry0, rw, rh)
					lw[li] = wf - WET_EDGE
					em = minf(em, absf(wf - WET_EDGE) * 5.0)
					extra = _shore_lift(wf) << 17
					if wf >= WET_EDGE:
						extra |= _KEY_WET
						any_wet = true
						if _WET[g] == 0:
							g = _water_ground(wx, wy, terrace, wl, tg, rx0, ry0, rw, rh)
				if _WET[g] == 1 and (extra & _KEY_WET) == 0:
					g = GroundColors.bank(dc)
				lk[li] = g | (dc << 8) | extra
				lm[li] = clampf(em, 0.0, 1.0)
				if lw[li] != NO_WET:
					# Inland depth from the same field, so bands follow the shore;
					# negative on the bank, so a band edge between a wet and a dry
					# point falls where the field crosses, not half way.
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
	ch.f = lf
	ch.t = lt
	ch.key = lk
	ch.margin = lm
	ch.wet = lw
	# Hummocks: soft ground (fen, peat, snow) rises and dips a little, only well
	# inside one terrace and one ground, so edges and walking read the same.
	ch.bump.resize(cnt)
	for j in range(1, m):
		for i in range(1, ch.n):
			var li := j * np + i
			var k := ch.key[li]
			var amp: float = _BUMP[k & 0xFF] if (k & 0xFFFF0000) == 0 else 0.0
			if amp <= 0.0:
				continue
			var t0 := ch.t[li]
			if ch.key[li - 1] != k or ch.key[li + 1] != k or ch.key[li - np] != k or ch.key[li + np] != k \
					or ch.key[li - np - 1] != k or ch.key[li - np + 1] != k or ch.key[li + np - 1] != k or ch.key[li + np + 1] != k \
					or ch.t[li - 1] != t0 or ch.t[li + 1] != t0 or ch.t[li - np] != t0 or ch.t[li + np] != t0 \
					or ch.t[li - np - 1] != t0 or ch.t[li - np + 1] != t0 or ch.t[li + np - 1] != t0 or ch.t[li + np + 1] != t0:
				continue
			var sx := x0 + i * 0.5
			var sy := y0 + j * 0.5
			ch.bump[li] = _eco.get_noise_2d(sx * 2.6 + 300.0, sy * 2.6) * amp
	var _t4 := Time.get_ticks_usec()
	_begin()
	var keys := ch.key
	var terr := ch.t
	_mar = ch.margin
	_wetv = ch.wet
	_np = np
	var bump := ch.bump
	for j in m:
		var py := y0 + j * 0.5
		var run_start := -1
		var run_key := 0
		var run_t := 0
		for i in n:
			var i00 := j * np + i
			var k00 := keys[i00]
			var k10 := keys[i00 + 1]
			var k01 := keys[i00 + np]
			var k11 := keys[i00 + np + 1]
			var t00 := terr[i00]
			var same_t := terr[i00 + 1] == t00 and terr[i00 + np] == t00 and terr[i00 + np + 1] == t00
			var flat := same_t and k10 == k00 and k01 == k00 and k11 == k00
			if flat and (bump[i00] != 0.0 or bump[i00 + 1] != 0.0 or bump[i00 + np] != 0.0 or bump[i00 + np + 1] != 0.0):
				if run_start >= 0:
					_flat_run(ch, run_start, i, py, run_key, run_t)
					run_start = -1
				_bump_cell(x0 + i * 0.5, py, t00, k00, bump[i00], bump[i00 + 1], bump[i00 + np + 1], bump[i00 + np])
				continue
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
					_i00 = i00
					_mixed_flat(x0 + i * 0.5, py, t00, k00, k10, k11, k01, bump[i00], bump[i00 + 1], bump[i00 + np + 1], bump[i00 + np])
				continue
			_cell(ch, i, j)
		if run_start >= 0:
			_flat_run(ch, run_start, n, py, run_key, run_t)
	var _t5 := Time.get_ticks_usec()
	if has_water and any_wet:
		_build_water(ch, depth)
	var _t6 := Time.get_ticks_usec()
	_spans(ch)
	ch.terrain_arrays = _terrain_arrays()
	ch.water_arrays = _water_arrays()
	prof[0] += _t1 - _t0
	prof[1] += _t2 - _t1
	prof[2] += _t3 - _t2
	prof[7] += _t4 - _t3
	prof[3] += _t5 - _t4
	prof[4] += _t6 - _t5
	prof[5] += Time.get_ticks_usec() - _t6
	prof[6] += _tv.size()
	return ch


## A same-terrace cell whose corners carry two or more keys: one quad, the
## most common key as its wash and the next as the second wash.
## One cell of a single key with hummock heights at its corners: two
## triangles with their own normals, painted once.
func _bump_cell(px: float, py: float, terrace: int, k: int, b00: float, b10: float, b11: float, b01: float) -> void:
	if k != _bump_key or terrace != _bump_t:
		_paint(k, -1, terrace)
		_bump_key = k
		_bump_t = terrace
	var h := level_height(terrace)
	var p00 := Vector3(px, h + b00, py)
	var p10 := Vector3(px + 0.5, h + b10, py)
	var p11 := Vector3(px + 0.5, h + b11, py + 0.5)
	var p01 := Vector3(px, h + b01, py + 0.5)
	var n1 := (p11 - p00).cross(p10 - p00).normalized()
	var n2 := (p01 - p00).cross(p11 - p00).normalized()
	_tv.append_array([p00, p10, p11, p00, p11, p01])
	_tn.append_array([n1, n1, n1, n2, n2, n2])
	var uv := Vector2(_style, 0.0)
	var uv2 := Vector2(0.0, _m2)
	var c0 := Color(_sc.r, _sc.g, _sc.b, 0.0)
	for v in 6:
		_tc.append(_pc)
		_tuv.append(uv)
		_tuv2.append(uv2)
		_tc0.append(c0)


func _mixed_flat(px: float, py: float, terrace: int, k00: int, k10: int, k11: int, k01: int, b00: float, b10: float, b11: float, b01: float) -> void:
	if ((k00 ^ k10) | (k00 ^ k11) | (k00 ^ k01)) & _KEY_WET != 0 and _shore_split(px, py, terrace, k00, k10, k11, k01, b00, b10, b11, b01):
		return
	_pick_keys(k00, k10, k11, k01, _i00)
	_ox = px
	_oy = py
	_paint(_k1, _k2, terrace)
	_bump_key = -1
	var h := level_height(terrace)
	var h00 := h + _lift(k00) + b00
	var h10 := h + _lift(k10) + b10
	var h11 := h + _lift(k11) + b11
	var h01 := h + _lift(k01) + b01
	var s := 0.5
	var start := _tv.size()
	_vtop(px, h00, py)
	_vtop(px + s, h10, py)
	_vtop(px + s, h11, py + s)
	_vtop(px, h00, py)
	_vtop(px + s, h11, py + s)
	_vtop(px, h01, py + s)
	if b00 != 0.0 or b10 != 0.0 or b11 != 0.0 or b01 != 0.0:
		# A hummock's faces turn toward or away from the light.
		for tri in 2:
			var a := _tv[start + tri * 3]
			var n := (_tv[start + tri * 3 + 2] - a).cross(_tv[start + tri * 3 + 1] - a).normalized()
			if n.y < 0.0:
				n = -n
			for v in 3:
				_tn[start + tri * 3 + v] = n


## A cell the waterline crosses: cut along the wet field's own contour, the
## bank on one side and the bed on the other, both meeting the sheet exactly
## at the crossing. Never fanned to the lattice corners, so the shore is a
## curve and not a row of teeth. False for a saddle (left to _mixed_flat).
func _shore_split(px: float, py: float, terrace: int, k00: int, k10: int, k11: int, k01: int, b00: float, b10: float, b11: float, b01: float) -> bool:
	var i00 := _i00
	var vs := PackedFloat32Array([_wetv[i00], _wetv[i00 + 1], _wetv[i00 + _np + 1], _wetv[i00 + _np]])
	if vs[0] == NO_WET or vs[1] == NO_WET or vs[2] == NO_WET or vs[3] == NO_WET:
		return false
	var crossings := 0
	for e in 4:
		if (vs[e] >= 0.0) != (vs[(e + 1) & 3] >= 0.0):
			crossings += 1
	if crossings != 2:
		return false
	var ks := PackedInt32Array([k00, k10, k11, k01])
	var bs := PackedFloat32Array([b00, b10, b11, b01])
	var s := 0.5
	var cx := PackedFloat32Array([px, px + s, px + s, px])
	var cz := PackedFloat32Array([py, py, py + s, py + s])
	var h := level_height(terrace)
	var dry := PackedVector3Array()
	var wet := PackedVector3Array()
	var dry_k := -1
	var wet_k := -1
	for e in 4:
		var e2 := (e + 1) & 3
		var is_wet := vs[e] >= 0.0
		var p := Vector3(cx[e], h + _lift(ks[e]) + bs[e], cz[e])
		if is_wet:
			wet.append(p)
			wet_k = ks[e] if wet_k < 0 else wet_k
		else:
			dry.append(p)
			dry_k = ks[e] if dry_k < 0 else dry_k
		if is_wet != (vs[e2] >= 0.0):
			var t := vs[e] / (vs[e] - vs[e2])
			var q := Vector3(lerpf(cx[e], cx[e2], t), h + WADE, lerpf(cz[e], cz[e2], t))
			dry.append(q)
			wet.append(q)
	_ox = px
	_oy = py
	for side in 2:
		var poly := dry if side == 0 else wet
		if side == 0:
			# The bank may itself be two grounds: each wet corner takes the key
			# of a dry neighbour, so the ground edge runs on to the water.
			var dk := PackedInt32Array()
			for e in 4:
				var k := ks[e]
				if vs[e] >= 0.0:
					k = ks[(e + 1) & 3] if vs[(e + 1) & 3] < 0.0 else (ks[(e + 3) & 3] if vs[(e + 3) & 3] < 0.0 else dry_k)
				dk.append(k)
			_pick_keys(dk[0], dk[1], dk[2], dk[3], i00)
			_paint(_k1, _k2, terrace)
		else:
			_w00 = 0.0
			_w10 = 0.0
			_w11 = 0.0
			_w01 = 0.0
			_paint(wet_k, -1, terrace)
		var p0 := poly[0]
		for e in range(1, poly.size() - 1):
			_vtop(p0.x, p0.y, p0.z)
			_vtop(poly[e].x, poly[e].y, poly[e].z)
			_vtop(poly[e + 1].x, poly[e + 1].y, poly[e + 1].z)
	return true


func _begin() -> void:
	_bump_key = -1
	_bump_t = -99
	_tv = PackedVector3Array()
	_tn = PackedVector3Array()
	_tc = PackedColorArray()
	_tuv = PackedVector2Array()
	_tuv2 = PackedVector2Array()
	_tc0 = PackedColorArray()
	_wv = PackedVector3Array()
	_wc = PackedColorArray()


func _terrain_arrays() -> Array:
	if _tv.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _tv
	arrays[Mesh.ARRAY_NORMAL] = _tn
	arrays[Mesh.ARRAY_COLOR] = _tc
	arrays[Mesh.ARRAY_TEX_UV] = _tuv
	arrays[Mesh.ARRAY_TEX_UV2] = _tuv2
	arrays[Mesh.ARRAY_CUSTOM0] = _tc0.to_byte_array().to_float32_array()
	return arrays


func _water_arrays() -> Array:
	if _wv.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _wv
	var nrm := PackedVector3Array()
	nrm.resize(_wv.size())
	nrm.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = _wc
	return arrays


## Set the paint state for tops of key k1 (and a second key k2 by corner flags).
func _paint(k1: int, k2: int, terrace: int) -> void:
	_bump_key = -1
	var i1 := ((k1 & 0xFF) * BiomeRegistry.SLOTS + ((k1 >> 8) & 0xFF)) * 2 + (terrace & 1)
	_pc = _tab_col[i1]
	var s1 := _tab_style[i1] if terrace > 0 else Ink.NONE
	if k2 >= 0:
		var i2 := ((k2 & 0xFF) * BiomeRegistry.SLOTS + ((k2 >> 8) & 0xFF)) * 2 + (terrace & 1)
		_sc = _tab_col[i2]
		_style = s1 + (_tab_style[i2] if terrace > 0 else Ink.NONE) * 16
		# +256 when the keys are in the other order, so the shader bends a shared
		# edge the same way from both sides of a cell seam.
		_m2 = 2.0 + _sc.a * 255.0 + (256.0 if k1 > k2 else 0.0)
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
	_pick_keys(_ck[0], _ck[1], _ck[2], _ck[3], i00)
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
		var out_a := Vector2.ZERO
		var out_b := Vector2.ZERO
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
				var out := _out_axis(e, e2) if ina else _out_axis(e2, e)
				if cross_a < 0:
					cross_a = _poly.size()
					out_a = out
				else:
					cross_b = _poly.size()
					out_b = out
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
			_wall(ch, ca.x, ca.z, cb.x, cb.z, _cx[near_e], _cz[near_e], hb, h, L, _ck[near_e], out_a, out_b)


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
			_wall(ch, ax, az, bx, bz, _cx[e], _cz[e], hb, h, L, _ck[e], _out_axis(e, e2), _out_axis(e, e0))
		elif centre:
			if ina:
				_poly.append(Vector3(_cx[e], hc, _cz[e]))
			else:
				# The centre is high: walls cut off the outside corners.
				_poly.append(Vector3(bx, h, bz))
				_poly.append(Vector3(ax, h, az))
				_wall(ch, bx, bz, ax, az, mx, mz, hb, h, L, _ck[e2], _out_axis(e0, e), _out_axis(e2, e))
	if centre:
		var pn := _poly.size()
		for e in pn:
			var a := _poly[e]
			var b := _poly[(e + 1) % pn]
			_vtop(mx, h, mz)
			_vtop(a.x, a.y, a.z)
			_vtop(b.x, b.y, b.z)


## Primary key: the most common corner key; secondary: the next different one.
## A corner's weight toward the second wash is 0.5 plus or minus half its
## margin, so the edge falls where the margins cross, a smooth line through
## the cell, and neighbouring cells agree on it.
func _pick_keys(k00: int, k10: int, k11: int, k01: int, i00: int) -> void:
	# The shore lift rides in the key's high bits; it shapes height, not paint.
	k00 &= _PAINT_BITS
	k10 &= _PAINT_BITS
	k11 &= _PAINT_BITS
	k01 &= _PAINT_BITS
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
	_w00 = _corner_w(k00, k1, k2, _mar[i00])
	_w10 = _corner_w(k10, k1, k2, _mar[i00 + 1])
	_w11 = _corner_w(k11, k1, k2, _mar[i00 + _np + 1])
	_w01 = _corner_w(k01, k1, k2, _mar[i00 + _np])


static func _corner_w(k: int, k1: int, k2: int, m: float) -> float:
	if k == k2:
		return 0.5 + 0.5 * m
	if k == k1:
		return 0.5 - 0.5 * m
	return 0.0


## Which way is out at a crossing on the lattice edge from corner `from` (on
## the high side) to corner `to`: along that edge. Both cells that share the
## edge, in this chunk or the next, read the same two corners, so a wall's
## foot pushed out along it meets its neighbour's exactly -- a segment's own
## normal would open a crack at every joint.
func _out_axis(from: int, to: int) -> Vector2:
	return Vector2(_cx[to] - _cx[from], _cz[to] - _cz[from]).normalized()


## A wall is LAND seen from the side, not a board stood on edge. Contour
## terraces stay (docs/LOOK.md), but at eye level a vertical quad per segment
## read as a stack of slabs. So each wall is cut in three bands: the foot runs
## out as a talus slope and tucks under the terrace below, the face leans and
## bulges and undercuts by world position, and only the top edge stays on the
## contour, where the flat and the lip meet it. Everything is a function of
## where a point IS (and its level), so neighbouring segments and chunks meet.
const WALL_TALUS := 0.24
const WALL_TALUS_VARY := 0.2
const WALL_LEAN := 0.06
const WALL_BULGE := 0.055
## How far the foot sinks under the terrace below, so it never shows a seam.
const WALL_TUCK := 0.05
## A segment longer than this (tiles) is broken at its middle as well. Most
## run half a tile, and splitting every one nearly doubled the land's
## triangles for detail a lattice step already gives.
const WALL_SPLIT := 0.62

## One column of a wall at (x, z): how far out its foot, lower band and upper
## band stand (tiles), then the two band heights as shares of the wall.
func _wall_column(x: float, z: float, L: int, span: float) -> PackedFloat32Array:
	var lz := z + L * 17.3
	var lean := WALL_LEAN * (0.4 + _warp.get_noise_2d(x * 3.1 + 40.0, lz * 3.1))
	var talus := span * (WALL_TALUS + WALL_TALUS_VARY * _lip.get_noise_2d(x * 0.9 + 11.0, lz * 0.9))
	var b1 := WALL_BULGE * _lip.get_noise_2d(x * 2.3 + 77.0, lz * 2.3)
	var b2 := WALL_BULGE * _lip.get_noise_2d(x * 2.3 - 51.0, lz * 2.3 + 9.0)
	var h1 := 0.3 + 0.1 * _lip.get_noise_2d(x * 1.7 + 3.0, lz * 1.7 - 20.0)
	var h2 := 0.68 + 0.09 * _lip.get_noise_2d(x * 1.7 - 13.0, lz * 1.7 + 31.0)
	return PackedFloat32Array([maxf(0.03, lean + talus), lean * 0.65 + b1, lean * 0.3 + b2, h1, h2])


## A wall along a terrace edge from p to q, from hb up to h, facing away from
## the point (ix, iz) on the high side, under ground key k. `op` and `oq` are
## the outward axes at p and q (see _out_axis).
func _wall(ch: Chunk, px: float, pz: float, qx: float, qz: float, ix: float, iz: float, hb: float, h: float, L: int, k: int, op: Vector2 = Vector2.ZERO, oq: Vector2 = Vector2.ZERO) -> void:
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
		var to := op
		op = oq
		oq = to
	var inv := 1.0 / sqrt(len2)
	var nrm := Vector3(dz * inv, 0.0, -dx * inv)
	var n2 := Vector2(nrm.x, nrm.z)
	if op == Vector2.ZERO:
		op = n2
	if oq == Vector2.ZERO:
		oq = n2
	ch.edges.append(Vector3(px, h, pz))
	ch.edges.append(Vector3(qx, h, qz))
	var gi := ((k & 0xFF) * BiomeRegistry.SLOTS + ((k >> 8) & 0xFF)) * 2 + (L & 1)
	var col := _tab_cliff[gi]
	var span := h - hb
	# Columns: p, the middle of a long segment (its own normal, so no
	# neighbour has to agree with it), q.
	var mx := (px + qx) * 0.5
	var mz := (pz + qz) * 0.5
	var cols_x := PackedFloat32Array([px, mx, qx])
	var cols_z := PackedFloat32Array([pz, mz, qz])
	var outs: Array[Vector2] = [op, n2, oq]
	var ncol := 3 if len2 > WALL_SPLIT * WALL_SPLIT else 2
	if ncol == 2:
		cols_x = PackedFloat32Array([px, qx])
		cols_z = PackedFloat32Array([pz, qz])
		outs = [op, oq]
	# Four rows per column, foot to top.
	var grid := PackedVector3Array()
	grid.resize(ncol * 4)
	var foot_out := 0.0
	for c in ncol:
		var x := cols_x[c]
		var z := cols_z[c]
		var o := outs[c]
		var w := _wall_column(x, z, L, span)
		if c == ncol / 2:
			foot_out = w[0]
		grid[c * 4] = Vector3(x + o.x * w[0], hb - WALL_TUCK, z + o.y * w[0])
		grid[c * 4 + 1] = Vector3(x + o.x * w[1], hb + span * w[3], z + o.y * w[1])
		grid[c * 4 + 2] = Vector3(x + o.x * w[2], hb + span * w[4], z + o.y * w[2])
		grid[c * 4 + 3] = Vector3(x, h, z)
	var c0 := Color(col.r, col.g, col.b, 0.0)
	var n := 0
	for c in ncol - 1:
		for r in 3:
			var p_lo := grid[c * 4 + r]
			var p_hi := grid[c * 4 + r + 1]
			var q_lo := grid[(c + 1) * 4 + r]
			var q_hi := grid[(c + 1) * 4 + r + 1]
			# The same winding as the flat wall this replaced: (q_lo, p_hi, p_lo)
			# and (q_lo, q_hi, p_hi), each lit by its own facet.
			var na := (p_lo - q_lo).cross(p_hi - q_lo).normalized()
			var nb := (p_hi - q_lo).cross(q_hi - q_lo).normalized()
			if na.dot(nrm) < 0.0:
				na = -na
			if nb.dot(nrm) < 0.0:
				nb = -nb
			_tv.append(q_lo)
			_tv.append(p_hi)
			_tv.append(p_lo)
			_tv.append(q_lo)
			_tv.append(q_hi)
			_tv.append(p_hi)
			for v in 3:
				_tn.append(na)
			for v in 3:
				_tn.append(nb)
			n += 6
	for v in n:
		_tc.append(col)
		_tuv.append(_UV_CONTOUR)
		_tuv2.append(Vector2.ZERO)
		_tc0.append(c0)
	var lip := _tab_lip[gi]
	if lip > 0:
		_lip_strip(px, pz, qx, qz, nrm, h, gi, lip == 2)
	if span > 0.3:
		# Rubble lies past the talus, not buried in it.
		ch.feet.append(Vector3(mx, hb, mz) + nrm * (0.18 + foot_out))
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
func _shore_window(x0: int, y0: int, x1: int, y1: int, win: TileWindow) -> PackedFloat32Array:
	var size := world.size
	var wx0 := x0 - MARGIN
	var wy0 := y0 - MARGIN
	var ww := x1 - x0 + MARGIN * 2
	var wh := y1 - y0 + MARGIN * 2
	var wet := PackedByteArray()
	wet.resize(ww * wh)
	var any_wet := false
	var any_dry := false
	for y in wh:
		var ty := (clampi(wy0 + y, 0, size - 1) - win.y0) * win.w - win.x0
		var outside_y := wy0 + y < 0 or wy0 + y >= size
		for x in ww:
			var tx := wx0 + x
			var water := outside_y or tx < 0 or tx >= size
			if not water:
				var i := ty + tx
				water = win.level[i] <= 0 or Ground.is_water(win.ground[i])
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
			var lx := ch.x0 + i * 0.5
			if terrace <= 0:
				sheet[li] = WATER_Y
				# A pool or a river mouth that happens to lie at sea level keeps
				# its own kind, or the moss ends up with a white beach round its
				# black water; and even the sea itself only breaks white where the
				# bank it meets is not a bog (docs/LOOK.md section 3).
				var g0 := ch.key[li] & 0xFF
				if g0 == Ground.DEEP_WATER or g0 == Ground.WATER:
					# Every sea point carries the weight, not only the shallow ones:
					# the quad interpolates, so one deep corner would put surf back
					# on the band its shallow corner was meant to keep off.
					col[li] = Color(0.0, _surf_at(lx, ly), 0.5, clampf(depth[li] / 9.0, 0.0, 1.0))
				else:
					col[li] = Color(_inland_kind(k, lx, ly) / 8.0, 0.5, 0.5, inland_alpha(depth[li]))
				continue
			# Level water: a sheet over its terrace, under any bank (which lips up).
			sheet[li] = terrace * WorldData.STEP + WADE
			var kind := _inland_kind(k, lx, ly)
			var flow := Vector2.ZERO
			if kind == 1:
				var ti := clampi(floori(ly), 0, size - 1) * size + clampi(floori(lx), 0, size - 1)
				if not flows.has(ti):
					flows[ti] = _flow(ti % size, ti / size)
				flow = flows[ti]
			col[li] = Color(kind / 8.0, flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, inland_alpha(depth[li]))
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
				col[li] = Color(c.r, c.g, c.b, inland_alpha(depth[li]) if c.r > 0.01 else 0.0)
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
			if _clip_sheet(ch, a, b, c, d, sheet, col, ch.x0 + i * 0.5, py):
				continue
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


## An inland water cell the shoreline crosses, one level of water, not a
## saddle: the sheet is cut along the wet field's contour, exactly where
## _shore_split meets it with the bank, so the sheet never shows past the
## shore as a wedge and its shallow band follows the curve. Corners a, b, c, d
## run round the cell from its north-west corner.
func _clip_sheet(ch: Chunk, a: int, b: int, c: int, d: int, sheet: PackedFloat32Array, col: PackedColorArray, px: float, py: float) -> bool:
	var idx := PackedInt32Array([a, b, c, d])
	var level := INF
	var crossings := 0
	for e in 4:
		var q := idx[e]
		if ch.wet[q] == NO_WET or ch.t[q] <= 0:
			return false
		if sheet[q] != INF:
			if level != INF and absf(sheet[q] - level) > 1e-4:
				return false
			level = sheet[q]
		if (ch.wet[q] >= 0.0) != (ch.wet[idx[(e + 1) & 3]] >= 0.0):
			crossings += 1
	if crossings != 2 or level == INF:
		return false
	var wet_c := Color()
	for q in idx:
		if sheet[q] != INF:
			wet_c = col[q]
			break
	var s := 0.5
	var cx := PackedFloat32Array([px, px + s, px + s, px])
	var cz := PackedFloat32Array([py, py, py + s, py + s])
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for e in 4:
		var q := idx[e]
		var q2 := idx[(e + 1) & 3]
		var v := ch.wet[q]
		if v >= 0.0 and sheet[q] != INF:
			pts.append(Vector3(cx[e], level, cz[e]))
			cols.append(col[q])
		if (v >= 0.0) != (ch.wet[q2] >= 0.0):
			var t := v / (v - ch.wet[q2])
			pts.append(Vector3(lerpf(cx[e], cx[(e + 1) & 3], t), level, lerpf(cz[e], cz[(e + 1) & 3], t)))
			cols.append(Color(wet_c.r, wet_c.g, wet_c.b, inland_alpha(0.0)))
	if pts.size() < 3:
		return false
	for e in range(1, pts.size() - 1):
		_wv.append(pts[0])
		_wv.append(pts[e])
		_wv.append(pts[e + 1])
		_wc.append(cols[0])
		_wc.append(cols[e])
		_wc.append(cols[e + 1])
	return true


## Inland depth (field units * 6, negative on the bank) as vertex alpha;
## water.gdshader reads it back as a * INLAND_SPAN - INLAND_BANK.
static func inland_alpha(d: float) -> float:
	return clampf((d + INLAND_BANK) / INLAND_SPAN, 0.0, 1.0)


## Which water an inland sheet is: blackwater (2) where the land it lies in is
## wet enough to be a bog, so a river or a pool in the moss is the moss's own
## black water with green edges and never a pale blue lagoon (docs/LOOK.md
## section 3); a plain sheet (1) everywhere else.
func _inland_kind(key: int, lx: float, ly: float) -> int:
	if (key & 0xFF) == Ground.BLACKWATER:
		return 2
	return 2 if _surf_at(lx, ly) < 0.5 else 1


## Land wet at or above this takes no surf: its bank is a bog, not a shore.
const SURF_WET := 0.5


## How the sea breaks on the bank under a point: 1 on an open coast, 0 where the
## land it meets is soft and wet. Read from the nearest land's `wet` hazard
## (BiomeRegistry), never from a country: the moss's black water is scummed reed
## at its edge, not a white beach (docs/LOOK.md section 3, art review wave N).
var _surf: Dictionary = {}
func _surf_at(lx: float, ly: float) -> float:
	var size := world.size
	var ti := clampi(floori(ly), 0, size - 1) * size + clampi(floori(lx), 0, size - 1)
	if _surf.has(ti):
		return _surf[ti]
	var out := _surf_scan(lx, ly)
	_surf[ti] = out
	return out


func _surf_scan(lx: float, ly: float) -> float:
	var size := world.size
	for r: int in [2, 4, 7]:
		for i in 8:
			var a := float(i) / 8.0 * TAU
			var x := clampi(floori(lx + cos(a) * float(r)), 0, size - 1)
			var y := clampi(floori(ly + sin(a) * float(r)), 0, size - 1)
			if Ground.is_water(world.ground_at(x, y)):
				continue
			var wet := float(BiomeRegistry.at(world, Vector2(x, y)).hazards.get(&"wet", 0.0))
			return 0.0 if wet >= SURF_WET else 1.0
	return 1.0


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


## GROUND ABOVE THE GROUND, drawn (DESIGN_ABOVE S1): the mass WorldData.overhead
## hangs over tiles is contoured on the chunk's own half-tile lattice through
## the same slow warp as a terrace edge, so a roof's edge wanders as a
## terrace's does and is never a tile-stepped block. Each region is drawn as
## its top (its landscape's wash, with a lip), its rim (banded rock like a
## cliff, its lower band undercut so the mass reads as hanging, not as a
## wall standing on the ground) and its underside (facing down, darker than
## the rim, hung with drip relief). How far inside a point is, and the heights
## of its underside and top, are functions of where it is, so neighbouring
## chunks meet: the tile mask read bilinearly at tile centres through the warp,
## the heights weighted the same way over the spanned tiles alone, so an arch's
## underside curves instead of stepping.
## The warp and fray a span's edge is read through, as shares of a terrace
## edge's: less, because the rules stop a body at the tile (WorldData.headroom_at)
## and a drawn edge a tile off would put a head through rock or stop it at air.
const SPAN_WARP := 0.35
const SPAN_FRAY := 0.5
## How far drips hang below the underside, and how far the rim's lower band
## tucks in above its edge.
const SPAN_DRIP := 0.16
const SPAN_UNDERCUT := 0.2
## An underside is its rim's rock in shadow.
const SPAN_UNDER_SHADE := 0.55


func _spans(ch: Chunk) -> void:
	var w := world
	if w.overhead.is_empty():
		return
	# Only a chunk with mass over it, or within the warp's reach of it.
	var any := false
	for y in range(ch.y0 - 2, ch.y0 + ch.h + 2):
		for x in range(ch.x0 - 2, ch.x0 + ch.w + 2):
			if w.overhead_at(x, y).x >= 0:
				any = true
				break
		if any:
			break
	if not any:
		return
	var n := ch.n
	var m := ch.h * RES
	var np := n + 1
	var ins := PackedFloat32Array()
	ins.resize(np * (m + 1))
	for j in m + 1:
		for i in np:
			ins[j * np + i] = _span_sample(ch.x0 + i * 0.5, ch.y0 + j * 0.5).x
	_w00 = 0.0
	_w10 = 0.0
	_w11 = 0.0
	_w01 = 0.0
	for j in m:
		for i in n:
			var li := j * np + i
			var v := PackedFloat32Array([ins[li], ins[li + 1], ins[li + np + 1], ins[li + np]])
			if v[0] < 0.5 and v[1] < 0.5 and v[2] < 0.5 and v[3] < 0.5:
				continue
			_span_cell(ch, i, j, v)


## (inside, underside y, top y) at tile-space point (x, y), read through the warp.
## Inside is 0..1 (a region is where it is at least 0.5); the heights are those
## of the spanned tiles round it, or 0 where there are none.
func _span_sample(x: float, y: float) -> Vector3:
	var wp := warp_at(x, y)
	var gx := x + wp.x * SPAN_WARP + wp.z * SPAN_FRAY - 0.5
	var gy := y + wp.y * SPAN_WARP + wp.w * SPAN_FRAY - 0.5
	var ix := floori(gx)
	var iy := floori(gy)
	var fx := gx - ix
	var fy := gy - iy
	var inside := 0.0
	var wsum := 0.0
	var under := 0.0
	var over := 0.0
	for c in 4:
		var tx := ix + (c & 1)
		var ty := iy + (c >> 1)
		var o := world.overhead_at(tx, ty)
		if o.x < 0:
			continue
		var wt := (fx if (c & 1) == 1 else 1.0 - fx) * (fy if (c >> 1) == 1 else 1.0 - fy)
		inside += wt
		wsum += wt
		under += wt * o.x
		over += wt * o.y
	if wsum <= 0.0:
		# Only a lattice point well outside asks here; a crossing always has a
		# spanned tile under its footprint.
		return Vector3(inside, 0.0, 0.0)
	var drip := SPAN_DRIP * (0.55 + 0.45 * _lip.get_noise_2d(x * 2.1 + 140.0, y * 2.1))
	return Vector3(inside, under / wsum * WorldData.STEP - drip, over / wsum * WorldData.STEP)


## One lattice cell with mass over some of it: marching squares on `v` (NW, NE,
## SE, SW) as a terrace edge is traced, a saddle settled by the cell's middle.
func _span_cell(ch: Chunk, i: int, j: int, v: PackedFloat32Array) -> void:
	var x0 := ch.x0 + i * 0.5
	var y0 := ch.y0 + j * 0.5
	var cx := PackedFloat32Array([x0, x0 + 0.5, x0 + 0.5, x0])
	var cz := PackedFloat32Array([y0, y0, y0 + 0.5, y0 + 0.5])
	var np := ch.n + 1
	var li := j * np + i
	var keys := PackedInt32Array([ch.key[li], ch.key[li + 1], ch.key[li + np + 1], ch.key[li + np]])
	var inside: Array[bool] = [v[0] >= 0.5, v[1] >= 0.5, v[2] >= 0.5, v[3] >= 0.5]
	# Mass is its country's rock, whatever ground lies under it: painting it
	# from the ground below drew every ground edge under a roof on its top.
	var k := Ground.ROCK
	for c in 4:
		if inside[c]:
			k = Ground.ROCK | (keys[c] & 0xFF00)
			break
	# Crossings on each edge c (corner c to c + 1), where the edge changes.
	var ex := PackedFloat32Array([0, 0, 0, 0])
	var ez := PackedFloat32Array([0, 0, 0, 0])
	var nx := 0
	for c in 4:
		var d := (c + 1) % 4
		if inside[c] != inside[d]:
			var t := clampf((0.5 - v[c]) / (v[d] - v[c]), 0.05, 0.95)
			ex[c] = lerpf(cx[c], cx[d], t)
			ez[c] = lerpf(cz[c], cz[d], t)
			nx += 1
	var polys: Array[PackedVector2Array] = []
	var segs: Array[PackedVector2Array] = []
	var saddle := nx == 4
	var middle_in := (v[0] + v[1] + v[2] + v[3]) * 0.25 >= 0.5
	if saddle and not middle_in:
		# Two corners, each cut off on its own.
		for c in 4:
			if inside[c]:
				var b := (c + 3) % 4
				polys.append(PackedVector2Array([Vector2(cx[c], cz[c]), Vector2(ex[c], ez[c]), Vector2(ex[b], ez[b])]))
				segs.append(PackedVector2Array([Vector2(ex[b], ez[b]), Vector2(ex[c], ez[c]), Vector2(cx[c], cz[c])]))
	else:
		var poly := PackedVector2Array()
		for c in 4:
			var d := (c + 1) % 4
			if inside[c]:
				poly.append(Vector2(cx[c], cz[c]))
			if inside[c] != inside[d]:
				poly.append(Vector2(ex[c], ez[c]))
		polys.append(poly)
		if saddle:
			# The middle joins them: the edges cut off the two outside corners.
			for c in 4:
				if not inside[c]:
					var b := (c + 3) % 4
					segs.append(PackedVector2Array([Vector2(ex[b], ez[b]), Vector2(ex[c], ez[c]), Vector2(x0 + 0.25, y0 + 0.25)]))
		elif nx == 2:
			var e := PackedVector2Array()
			var ref := Vector2.ZERO
			var nin := 0
			for c in 4:
				if inside[c] != inside[(c + 1) % 4]:
					e.append(Vector2(ex[c], ez[c]))
				if inside[c]:
					ref += Vector2(cx[c], cz[c])
					nin += 1
			e.append(ref / nin)
			segs.append(e)
	for poly in polys:
		_span_faces(poly, k)
	for sg in segs:
		_span_rim(sg[0], sg[1], sg[2], k)


## A region's top and underside over one polygon (in NW, NE, SE, SW order, the
## order _vtop draws facing up).
func _span_faces(poly: PackedVector2Array, k: int) -> void:
	var ys := PackedVector2Array()
	for p in poly:
		var s := _span_sample(p.x, p.y)
		ys.append(Vector2(s.y, s.z))
	_paint(k, -1, SPAN_PAINT)
	_m2 += SPAN_LIFTED
	_ox = poly[0].x
	_oy = poly[0].y
	var ups := PackedVector3Array()
	var downs := PackedVector3Array()
	for p in poly:
		var g := _span_slope(p.x, p.y)
		ups.append(Vector3(-g.z, 1.0, -g.w).normalized())
		downs.append(Vector3(g.x, -1.0, g.y).normalized())
	for a in range(1, poly.size() - 1):
		for b: int in [0, a, a + 1]:
			_vtop(poly[b].x, ys[b].y, poly[b].y)
			_tn[_tn.size() - 1] = ups[b]
	var rock := _tab_cliff[_span_gi(k)]
	var col := Color(rock.r * SPAN_UNDER_SHADE, rock.g * SPAN_UNDER_SHADE, rock.b * SPAN_UNDER_SHADE, rock.a)
	var c0 := Color(col.r, col.g, col.b, 0.0)
	for a in range(1, poly.size() - 1):
		for b: int in [0, a + 1, a]:
			_tv.append(Vector3(poly[b].x, ys[b].x, poly[b].y))
			_tn.append(downs[b])
			_tc.append(col)
			_tuv.append(_UV_CONTOUR)
			_tuv2.append(Vector2.ZERO)
			_tc0.append(c0)


## The rim along a region's edge from p to q, facing away from `ref` inside
## it: from the underside up to the top, its lower band tucked in under the mass,
## the face bulging as a cliff's does, a lip on its top edge.
func _span_rim(p: Vector2, q: Vector2, ref: Vector2, k: int) -> void:
	var d := q - p
	if d.length_squared() < 1e-8:
		return
	# Face (d.y, -d.x), as _wall's quads do; flip it away from the inside.
	var mid := (p + q) * 0.5
	if d.y * (ref.x - mid.x) - d.x * (ref.y - mid.y) > 0.0:
		var t := p
		p = q
		q = t
		d = -d
	var o := Vector2(d.y, -d.x).normalized()
	var nrm := Vector3(o.x, 0.0, o.y)
	var sp := _span_sample(p.x, p.y)
	var sq := _span_sample(q.x, q.y)
	var terrace := roundi(sp.z / WorldData.STEP)
	var gi := _span_gi(k)
	var col := _tab_cliff[gi]
	var grid := PackedVector3Array()
	grid.resize(8)
	var ends: Array[Vector2] = [p, q]
	var ys: Array[Vector3] = [sp, sq]
	for c in 2:
		var at := ends[c]
		var lo := ys[c].y
		var hi := ys[c].z
		var wc := _wall_column(at.x, at.y, terrace, hi - lo)
		grid[c * 4] = Vector3(at.x, lo, at.y)
		grid[c * 4 + 1] = Vector3(at.x + o.x * (wc[1] - SPAN_UNDERCUT), lerpf(lo, hi, wc[3]), at.y + o.y * (wc[1] - SPAN_UNDERCUT))
		grid[c * 4 + 2] = Vector3(at.x + o.x * wc[2], lerpf(lo, hi, wc[4]), at.y + o.y * wc[2])
		grid[c * 4 + 3] = Vector3(at.x, hi, at.y)
	var c0 := Color(col.r, col.g, col.b, 0.0)
	for r in 3:
		var p_lo := grid[r]
		var p_hi := grid[r + 1]
		var q_lo := grid[4 + r]
		var q_hi := grid[4 + r + 1]
		var na := (p_lo - q_lo).cross(p_hi - q_lo).normalized()
		var nb := (p_hi - q_lo).cross(q_hi - q_lo).normalized()
		if na.dot(nrm) < 0.0:
			na = -na
		if nb.dot(nrm) < 0.0:
			nb = -nb
		for vtx: Vector3 in [q_lo, p_hi, p_lo, q_lo, q_hi, p_hi]:
			_tv.append(vtx)
		for vv in 3:
			_tn.append(na)
		for vv in 3:
			_tn.append(nb)
		for vv in 6:
			_tc.append(col)
			_tuv.append(_UV_CONTOUR)
			_tuv2.append(Vector2.ZERO)
			_tc0.append(c0)
	var lip := _tab_lip[gi]
	if lip > 0:
		_lip_strip(p.x, p.y, q.x, q.y, nrm, sp.z, gi, lip == 2)


## The paint row a span is drawn from: its ground key's, always as an odd
## terrace. A sloping top or underside crosses levels cell by cell, and the
## terraces' alternating shade would stripe it in triangles.
const SPAN_PAINT := 1
## Added to a span top's UV2.y: world.gdshader draws none of the ground's wear,
## trampling or works on it.
const SPAN_LIFTED := 512.0
func _span_gi(k: int) -> int:
	return ((k & 0xFF) * BiomeRegistry.SLOTS + ((k >> 8) & 0xFF)) * 2 + SPAN_PAINT


## The slopes of the underside and the top at (x, y): d(under)/dx, d(under)/dz,
## d(top)/dx, d(top)/dz, by central differences on _span_sample, so a face is
## lit smooth across its cells and chunks rather than stepped cell by cell.
const SPAN_SLOPE_H := 0.25
func _span_slope(x: float, y: float) -> Vector4:
	var e := SPAN_SLOPE_H
	var a := _span_sample(x - e, y)
	var b := _span_sample(x + e, y)
	var c := _span_sample(x, y - e)
	var d := _span_sample(x, y + e)
	# A side sampled off the mass has no heights: take the slope as flat there.
	var ux := (b.y - a.y) / (2.0 * e) if a.x > 0.0 and b.x > 0.0 else 0.0
	var uz := (d.y - c.y) / (2.0 * e) if c.x > 0.0 and d.x > 0.0 else 0.0
	var tx := (b.z - a.z) / (2.0 * e) if a.x > 0.0 and b.x > 0.0 else 0.0
	var tz := (d.z - c.z) / (2.0 * e) if c.x > 0.0 and d.x > 0.0 else 0.0
	return Vector4(ux, uz, tx, tz)
