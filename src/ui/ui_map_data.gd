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
var ready := false
var build_ms := 0

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
	_images.clear()
	ready = true


func _build_images() -> void:
	var t0 := Time.get_ticks_msec()
	var n := world.size
	_images.ground = Image.create_from_data(n, n, false, Image.FORMAT_L8, world.ground)
	_images.level = Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, world.level.to_byte_array())
	_images.coast = Image.create_from_data(n, n, false, Image.FORMAT_L8, shore_distance(world))
	_images.marks = Image.create_from_data(n, n, false, Image.FORMAT_L8, mark_bytes(world))
	var pal := Image.create_empty(32, 1, false, Image.FORMAT_RGBA8)
	for g in Ground.COUNT:
		pal.set_pixel(g, 0, GroundColors.top(g, 1))
	_images.palette = pal
	build_ms = Time.get_ticks_msec() - t0


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
static func mark_bytes(w: WorldData) -> PackedByteArray:
	var n := w.size
	var out := PackedByteArray()
	out.resize(n * n)
	const RANK := [0, 2, 2, 3, 1, 6, 5, 4, 0]
	for p in w.props:
		var m := mark_of(p.kind)
		if m == MARK_NONE:
			continue
		var x := floori(p.pos.x)
		var y := floori(p.pos.y)
		if not w.in_bounds(x, y):
			continue
		var i := y * n + x
		if RANK[m] >= RANK[out[i]]:
			out[i] = m
		if m == MARK_CONIFER or m == MARK_TREE:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if w.in_bounds(x + d.x, y + d.y) and out[i + d.y * n + d.x] == MARK_NONE:
					out[i + d.y * n + d.x] = MARK_WOOD
	return out
