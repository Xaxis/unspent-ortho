class_name UiMapData
extends RefCounted
## The world packed into small textures for the map shader (src/ui/map.gdshader).
## Built once per world, off the main thread when started with build_async().
##   ground   L8     ground id per tile (straight from WorldData.ground)
##   level    RGBA8  level per tile, low byte in R (straight from WorldData.level)
##   coast    L8     distance to the other side of the shore, 1/16 tile steps:
##                  for sea, how far to land (ripple lines); for land, to sea
##   marks    L8     what stands on a tile, for map symbols (MARK_*)
##   palette  RGBA8  32x1 wash colour per ground id
##   country  RGBA8  country in R, the ecotone's other country in G, its weight in B
## and, for lettering, `ink`: a summed-area table of how much ink the map draws
## on each tile (cliffs, shore, symbols), so a name can find a clear place.

const MARK_NONE := 0
const MARK_CONIFER := 1
const MARK_TREE := 2
const MARK_ROCK := 3
const MARK_REEDS := 4
const MARK_HOUSE := 5
const MARK_STATION := 6
const MARK_RUIN := 7
## Written around a tree so forest reads as forest at the map's cell size.
const MARK_WOOD := 8

var world: WorldData
var ground: ImageTexture
var level: ImageTexture
var coast: ImageTexture
var marks: ImageTexture
var palette: ImageTexture
var country: ImageTexture
## (size+1)^2 summed-area table of ink per tile; see ink_in().
var ink := PackedInt32Array()
var ready := false
var build_ms := 0

## THE SURVEY IS NOT A SATELLITE PHOTO, and its cost must not follow the world.
##
## Every pass below is O(tiles) in GDScript on one worker: the shore distance
## alone is five sweeps, two of them chamfers that cannot be split by rows. At
## 512 that was 262,000 tiles and merely slow; at 1300 it is 1,690,000 and the
## map takes seconds to open. Nothing about this file changed -- the world grew
## 6.4x underneath it, which is the same countdown the flyover's 120-unit ceiling
## and the absolute test bars were on.
##
## So the textures are built at MOST texels a side and no more, sampling the
## world with a stride. A survey drawn at 580 pixels wide never had a use for one
## texel per tile, and past this the cost is flat whatever size the world becomes.
const MOST := 512

## World tiles to one texel: 1 until the world is bigger than MOST.
var step := 1
## Texels a side -- what the images and the ink table are actually built at.
var tex_size := 0

var _images := {}
var _task := -1


func _init(w: WorldData) -> void:
	world = w


## Build images on a worker thread; textures are made on the main thread by ensure().
func build_async() -> void:
	if ready or _task >= 0:
		return
	_task = WorkerThreadPool.add_task(_build_images)


## Wait out a background build, if one is running (before the world goes away).
func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if not ready:
			_finish_textures()


## Make sure textures exist (waits for a running build). Main thread only.
func ensure() -> void:
	if ready:
		return
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	else:
		_build_images()
	_finish_textures()


func _finish_textures() -> void:
	ground = ImageTexture.create_from_image(_images.ground)
	level = ImageTexture.create_from_image(_images.level)
	coast = ImageTexture.create_from_image(_images.coast)
	marks = ImageTexture.create_from_image(_images.marks)
	palette = ImageTexture.create_from_image(_images.palette)
	country = ImageTexture.create_from_image(_images.country)
	ink = _images.ink
	_images.clear()
	ready = true


func _build_images() -> void:
	var t0 := Time.get_ticks_msec()
	step = maxi(1, ceili(float(world.size) / float(MOST)))
	var w := thinned(world, step) if step > 1 else world
	tex_size = w.size
	var n := tex_size
	_images.ground = Image.create_from_data(n, n, false, Image.FORMAT_L8, w.ground)
	_images.level = Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, w.level.to_byte_array())
	_images.coast = Image.create_from_data(n, n, false, Image.FORMAT_L8, shore_distance(w))
	var mk := mark_bytes(world, step, n)
	_images.marks = Image.create_from_data(n, n, false, Image.FORMAT_L8, mk)
	_images.ink = ink_table(w, mk)
	_images.country = Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, country_bytes(w))
	var pal := Image.create_empty(32, 1, false, Image.FORMAT_RGBA8)
	for g in Ground.COUNT:
		pal.set_pixel(g, 0, GroundColors.top(g, 1))
	_images.palette = pal
	build_ms = Time.get_ticks_msec() - t0


## The world sampled every `step` tiles, as a world of its own, so every pass
## below runs unchanged against a smaller grid.
##
## NEAREST, NOT AVERAGED, and deliberately: level, ground and country are IDS.
## The mean of two ground ids is a third ground, and the mean of two levels is a
## cliff that is not there -- averaging them would invent terrain the world does
## not have. Taking the tile at the corner of each block keeps every value one
## the world actually holds.
static func thinned(w: WorldData, step: int) -> WorldData:
	var n := w.size
	var m := ceili(float(n) / float(step))
	var out := WorldData.new(w.seed_value, m)
	var has2 := w.country2.size() == n * n and w.blend.size() == n * n
	for y in m:
		var sy := mini(y * step, n - 1)
		var row := y * m
		var srow := sy * n
		for x in m:
			var sx := mini(x * step, n - 1)
			var i := row + x
			var si := srow + sx
			out.level[i] = w.level[si]
			out.ground[i] = w.ground[si]
			out.country[i] = w.country[si]
			if has2:
				out.country2[i] = w.country2[si]
				out.blend[i] = w.blend[si]
	return out


## Country, ecotone neighbour and blend weight per tile, four bytes each.
static func country_bytes(w: WorldData) -> PackedByteArray:
	var n := w.size * w.size
	var out := PackedByteArray()
	out.resize(n * 4)
	var has2 := w.country2.size() == n and w.blend.size() == n
	for i in n:
		out[i * 4] = w.country[i]
		out[i * 4 + 1] = w.country2[i] if has2 else w.country[i]
		out[i * 4 + 2] = clampi(roundi(w.blend[i] * 255.0), 0, 255) if has2 else 0
		out[i * 4 + 3] = 255
	return out


## Octagonal chamfer distance across the shoreline, in 1/16 tiles, capped at 255.
static func shore_distance(w: WorldData) -> PackedByteArray:
	var n := w.size
	var land := PackedByteArray()
	land.resize(n * n)
	var lv := w.level
	for i in n * n:
		land[i] = 1 if lv[i] > 0 else 0
	var d := PackedInt32Array()
	d.resize(n * n)
	const BIG := 1 << 20
	# A tile touching the other kind across an edge is at distance 8 (half a tile).
	for y in n:
		for x in n:
			var i := y * n + x
			var me := land[i]
			var edge := (x > 0 and land[i - 1] != me) or (x < n - 1 and land[i + 1] != me) \
				or (y > 0 and land[i - n] != me) or (y < n - 1 and land[i + n] != me)
			d[i] = 8 if edge else BIG
	const A := 16
	const D := 23
	for y in n:
		for x in n:
			var i := y * n + x
			var v := d[i]
			if x > 0:
				v = mini(v, d[i - 1] + A)
			if y > 0:
				v = mini(v, d[i - n] + A)
				if x > 0:
					v = mini(v, d[i - n - 1] + D)
				if x < n - 1:
					v = mini(v, d[i - n + 1] + D)
			d[i] = v
	for y in range(n - 1, -1, -1):
		for x in range(n - 1, -1, -1):
			var i := y * n + x
			var v := d[i]
			if x < n - 1:
				v = mini(v, d[i + 1] + A)
			if y < n - 1:
				v = mini(v, d[i + n] + A)
				if x < n - 1:
					v = mini(v, d[i + n + 1] + D)
				if x > 0:
					v = mini(v, d[i + n - 1] + D)
			d[i] = v
	var out := PackedByteArray()
	out.resize(n * n)
	for i in n * n:
		out[i] = mini(255, d[i])
	return out


static func mark_of(kind: int) -> int:
	match kind:
		PropKind.PINE, PropKind.SNOW_PINE:
			return MARK_CONIFER
		PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.GORSE:
			return MARK_TREE
		PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE, PropKind.CLINTS, PropKind.STANDING_STONE, PropKind.CAIRN:
			return MARK_ROCK
		PropKind.REEDS, PropKind.PEAT_BANK:
			return MARK_REEDS
		PropKind.HOUSE:
			return MARK_HOUSE
		PropKind.FIRE, PropKind.BENCH, PropKind.KILN:
			return MARK_STATION
		PropKind.RUIN, PropKind.WRECK, PropKind.TIP, PropKind.PYLON:
			return MARK_RUIN
	return MARK_NONE


## One mark per tile; stronger marks (houses) win over weaker (trees).
static func mark_bytes(w: WorldData, step: int = 1, side: int = 0) -> PackedByteArray:
	var n := side if side > 0 else w.size
	var out := PackedByteArray()
	out.resize(n * n)
	const RANK := [0, 2, 2, 3, 1, 6, 5, 4, 0]
	for p in w.each_prop():
		var m := mark_of(p.kind)
		if m == MARK_NONE:
			continue
		var x := floori(p.pos.x) / step
		var y := floori(p.pos.y) / step
		if x < 0 or y < 0 or x >= n or y >= n:
			continue
		var i := y * n + x
		if RANK[m] >= RANK[out[i]]:
			out[i] = m
		if m == MARK_CONIFER or m == MARK_TREE:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if w.in_bounds(x + d.x, y + d.y) and out[i + d.y * n + d.x] == MARK_NONE:
					out[i + d.y * n + d.x] = MARK_WOOD
	return out


## Ink the map lays on each tile, summed: a cliff is drawn hardest, then the
## shore and symbols, then a terrace step. Returns a (size+1)^2 summed-area table.
static func ink_table(w: WorldData, marks: PackedByteArray) -> PackedInt32Array:
	var n := w.size
	var out := PackedInt32Array()
	out.resize((n + 1) * (n + 1))
	var lv := w.level
	for y in n:
		var row := 0
		for x in n:
			var i := y * n + x
			var me := lv[i]
			var v := 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var qx := x + d.x
				var qy := y + d.y
				if qx < 0 or qy < 0 or qx >= n or qy >= n:
					continue
				var o := lv[qy * n + qx]
				if (me > 0) != (o > 0):
					v = maxi(v, 2)
				elif absi(me - o) >= 2:
					v = maxi(v, 4)
				elif me != o:
					v = maxi(v, 1)
			var m := marks[i] if marks.size() == n * n else MARK_NONE
			if m == MARK_WOOD:
				v += 1
			elif m != MARK_NONE:
				v += 2
			row += v
			out[(y + 1) * (n + 1) + x + 1] = out[y * (n + 1) + x + 1] + row
	return out


## Total ink over tiles in `r` (clipped to the world), from an ink_table.
static func ink_in(table: PackedInt32Array, n: int, r: Rect2i) -> int:
	if table.size() != (n + 1) * (n + 1):
		return 0
	var x0 := clampi(r.position.x, 0, n)
	var y0 := clampi(r.position.y, 0, n)
	var x1 := clampi(r.end.x, 0, n)
	var y1 := clampi(r.end.y, 0, n)
	if x1 <= x0 or y1 <= y0:
		return 0
	var w := n + 1
	return table[y1 * w + x1] - table[y0 * w + x1] - table[y1 * w + x0] + table[y0 * w + x0]
