class_name TerrainMesher
extends RefCounted
## Builds one CHUNK x CHUNK tile area of the world into meshes: terrain columns
## (a top at each tile's level, a banded cliff face toward each lower neighbour)
## and the sea sheet over it. Pure function of WorldData + chunk coords, so the
## same chunk always builds the same mesh.

const CHUNK := 32
const WATER_Y := 0.3
const SEA_FLOOR := -1.0

var world: WorldData
var _grade: FastNoiseLite
var _land_dist: PackedFloat32Array


func _init(w: WorldData) -> void:
	world = w
	_grade = FastNoiseLite.new()
	_grade.seed = Rng.hash_ints(w.seed_value, 31) & 0x7FFFFFFF
	_grade.frequency = 1.0 / 9.0
	_grade.fractal_octaves = 2
	# Distance from sea tiles to land, for water depth colour and foam.
	var land := PackedByteArray()
	land.resize(w.size * w.size)
	for i in land.size():
		land[i] = 1 if w.level[i] > 0 else 0
	_land_dist = WorldGen.distance_field(land, w.size)


func _h(l: int) -> float:
	if l > 0:
		return l * WorldData.STEP
	return 0.0 if l == 0 else SEA_FLOOR


func tile_grade(x: int, y: int) -> int:
	var v := _grade.get_noise_2d(x, y)
	if v < -0.28:
		return 0
	if v > 0.32:
		return 2
	return 1


func top_color(x: int, y: int) -> Color:
	var g := world.ground[y * world.size + x]
	var c := GroundColors.top(g, tile_grade(x, y))
	# A barely-there per-tile value wobble (<= ~2%), so flat fields are not dead.
	return Palette.wobble(c, Rng.hash01(world.seed_value, x, y, 13), 0.02)


## Returns [terrain: ArrayMesh, water: ArrayMesh or null].
func build_chunk(cx: int, cy: int) -> Array:
	var w := world
	var size := w.size
	var t := MeshKit.new()
	var sea := MeshKit.new()
	var x0 := cx * CHUNK
	var y0 := cy * CHUNK
	var x1 := mini(size, x0 + CHUNK)
	var y1 := mini(size, y0 + CHUNK)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * size + x
			var l := w.level[i]
			var top := _h(l)
			var g := w.ground[i]
			t.quad(Vector3(x, top, y), Vector3(x, top, y + 1), Vector3(x + 1, top, y + 1), Vector3(x + 1, top, y), top_color(x, y))
			# Cliff faces toward each lower neighbour. a -> b runs CCW seen from outside.
			_side(t, g, l, top, w.level_at(x + 1, y), Vector3(x + 1, 0, y + 1), Vector3(x + 1, 0, y), x, y, 0)
			_side(t, g, l, top, w.level_at(x - 1, y), Vector3(x, 0, y), Vector3(x, 0, y + 1), x, y, 1)
			_side(t, g, l, top, w.level_at(x, y + 1), Vector3(x, 0, y + 1), Vector3(x + 1, 0, y + 1), x, y, 2)
			_side(t, g, l, top, w.level_at(x, y - 1), Vector3(x + 1, 0, y), Vector3(x, 0, y), x, y, 3)
			if l <= 0:
				var d := _land_dist[i]
				var c := Palette.BRINE[3].lerp(Palette.BRINE[2], clampf((d - 1.0) / 5.0, 0.0, 1.0))
				c = c.lerp(Palette.BRINE[1], clampf((d - 6.0) / 14.0, 0.0, 1.0) * 0.8)
				if d <= 1.0:
					c = c.lerp(Palette.RIME[4], 0.28)
				sea.quad(Vector3(x, WATER_Y, y), Vector3(x, WATER_Y, y + 1), Vector3(x + 1, WATER_Y, y + 1), Vector3(x + 1, WATER_Y, y), c)
	var terrain := t.build()
	var water: ArrayMesh = sea.build() if sea.vertex_count() > 0 else null
	return [terrain, water]


func _side(k: MeshKit, g: int, l: int, top: float, nl: int, a: Vector3, b: Vector3, x: int, y: int, face: int) -> void:
	if nl >= l:
		return
	var bottom := _h(nl)
	var steps := maxi(1, roundi((top - bottom) / WorldData.STEP))
	var step_h := (top - bottom) / steps
	for s in steps:
		var yt := top - s * step_h
		var yb := yt - step_h
		# Alternate bands per level (counted from sea level, so neighbours agree).
		var band := (roundi(yt / WorldData.STEP)) % 2
		var col := GroundColors.side(g, band)
		col = Palette.wobble(col, Rng.hash01(world.seed_value, x, y, s * 4 + face), 0.03)
		if s == 0 and l > 0 and g != Ground.ROCK and g != Ground.SAND and g != Ground.BONE:
			# A lip of topsoil over the rock: the ground's own dark grade.
			var lip := yt - minf(0.12, step_h * 0.3)
			k.quad(Vector3(a.x, lip, a.z), Vector3(b.x, lip, b.z), Vector3(b.x, yt, b.z), Vector3(a.x, yt, a.z), GroundColors.top(g, 0).darkened(0.15))
			k.quad(Vector3(a.x, yb, a.z), Vector3(b.x, yb, b.z), Vector3(b.x, lip, b.z), Vector3(a.x, lip, a.z), col)
		else:
			k.quad(Vector3(a.x, yb, a.z), Vector3(b.x, yb, b.z), Vector3(b.x, yt, b.z), Vector3(a.x, yt, a.z), col)
