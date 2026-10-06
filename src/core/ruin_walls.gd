class_name RuinWalls
## What a ruin stops a body with. A RUIN prop's own circle (PropKind.SOLID) is
## half a tile at its middle, and the thing drawn round it is a house's walls
## two tiles across, or in a city a tower's stump nearly three: a body walked
## straight through the walls and stood inside the stump (the camera with it).
##
## So each ruin hands WorldQuery its walls as a chain of small circles along
## every wall the model draws (Houses.ruin, FallenTower.stump), in the prop's own
## turn and scale, so a croft's doorway gap and open side are still walked
## through and its walls are not. Derived from the world like the landmarks'
## mass, never saved; a ruin taken down takes its walls with it.
##
## Contract:
##   RuinWalls.model(variant, tower) -> Array[Vector3]   (x, z, radius), model space
##   RuinWalls.drowned(kind, variant) -> Array[Vector3]  the same, a drowned block or roof
##   RuinWalls.of_world(world) -> Array[Vector3]        (x, y, radius), tile space
##   RuinWalls.of_row(world, row) -> Array[Vector3]     one ruin's, tile space

## The drowned city's block and roof plans (models/props/drowned_city.gd).
const DrownedCity := preload("res://src/models/props/drowned_city.gd")
## The circles along a wall stand this far apart (less than a body's width).
const STEP := 0.22
## A croft wall's half thickness, and a little for its rough face.
const WALL_R := 0.22
## A tower stump's footprint (FallenTower W x D) and the circles that fill it.
const STUMP_HALF := Vector2(1.25, 1.45)
const STUMP_R := 0.42

## The croft ruins' walls (Houses.ruin), per variant: [a, b] in model x/z.
const CROFT: Array = [
	[[Vector2(-1.0, -0.6), Vector2(1.1, -0.7)], [Vector2(-1.0, -0.43), Vector2(-0.9, 0.95)]],
	[[Vector2(-1.0, 0.0), Vector2(1.0, 0.05)]],
	[[Vector2(-1.2, -0.75), Vector2(1.1, -0.8)], [Vector2(1.1, -0.8), Vector2(1.15, 0.85)],
		[Vector2(1.15, 0.85), Vector2(0.15, 0.8)], [Vector2(-0.45, 0.8), Vector2(-1.2, 0.78)],
		[Vector2(-1.2, 0.95), Vector2(-1.2, -0.9)]],
]


## The walls of one ruin in its own model space.
static func model(variant: int, tower: bool) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if tower:
		return _filled(Vector2.ZERO, STUMP_HALF, STUMP_R)
	for wall: Array in CROFT[variant % CROFT.size()]:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		var n := maxi(1, ceili(a.distance_to(b) / STEP))
		for i in n + 1:
			var p := a.lerp(b, float(i) / float(n))
			out.append(Vector3(p.x, p.y, WALL_R))
	return out


## The drowned city's blocks (DrownedCity.SHELLS) and its roofs in the shallows
## (DrownedCity.ROOFS) are the same case as a stump: a box nearly three tiles
## across answered by one circle, and a body (the shoulder camera with it)
## walked into the box. Each is filled to its own plan, a front standing on its
## block's canal face.
static func drowned(kind: int, variant: int) -> Array[Vector3]:
	var shell := kind == PropKind.DROWNED_SHELL
	var shapes: Array[Dictionary] = DrownedCity.SHELLS if shell else DrownedCity.ROOFS
	var shape: Dictionary = shapes[variant % shapes.size()]
	var half := Vector2(float(shape.w) * 0.5, float(shape.d) * 0.5)
	var at := Vector2(DrownedCity.BLOCK_DEEP * 0.5 - half.x if shell else 0.0, 0.0)
	return _filled(at, half, minf(STUMP_R, half.x))


## Circles of radius r filling the rectangle of half extents `half` round `at`.
static func _filled(at: Vector2, half: Vector2, r: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var nx := maxi(1, ceili(half.x * 2.0 / (r * 1.3)))
	var nz := maxi(1, ceili(half.y * 2.0 / (r * 1.3)))
	for i in nx + 1:
		for j in nz + 1:
			var x := -half.x + r * 0.6 + (half.x * 2.0 - r * 1.2) * float(i) / float(nx)
			var z := -half.y + r * 0.6 + (half.y * 2.0 - r * 1.2) * float(j) / float(nz)
			out.append(Vector3(at.x + x, at.y + z, r))
	return out


## The kinds whose walls this file hands WorldQuery.
const KINDS: Array[int] = [PropKind.RUIN, PropKind.DROWNED_SHELL, PropKind.DROWNED_ROOF]


## Every standing ruin's walls in this world, in tile space.
## The prop ids of every ruin in `w`, standing or fallen.
static func ids_of(w: WorldData) -> PackedInt32Array:
	var out := PackedInt32Array()
	w.sync_table()
	var t := w.table
	for row in t.size():
		if KINDS.has(int(t.kind[row])):
			out.append(t.id[row])
	return out


static func of_world(w: WorldData) -> Array[Vector3]:
	var out: Array[Vector3] = []
	w.sync_table()
	var t := w.table
	for row in t.size():
		if KINDS.has(int(t.kind[row])) and not w.depleted.has(t.id[row]):
			out.append_array(of_row(w, row))
	return out


## One ruin's walls in tile space, by its row in the world's table: [] for a row
## that is no ruin. What `of_world` hands WorldQuery, one ruin at a time, for a
## reader that wants the walls of the ruins round one spot (GateStand).
static func of_row(w: WorldData, row: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var t := w.table
	var kind := int(t.kind[row])
	if not KINDS.has(kind):
		return out
	var pos: Vector2 = t.pos[row]
	var p := w.prop_at(row)
	var c := w.built_country(p)
	var v := PropModels.variant_of(p, w.seed_value, c)
	var s := float(t.scale[row])
	var walls := model(v, BiomeDressing.of(c).ruin_form == &"tower") if kind == PropKind.RUIN else drowned(kind, v)
	for m: Vector3 in walls:
		var at := pos + Vector2(m.x, m.y).rotated(float(t.rot[row])) * s
		out.append(Vector3(at.x, at.y, m.z * s))
	return out
