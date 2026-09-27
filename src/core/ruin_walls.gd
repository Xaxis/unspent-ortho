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
##   RuinWalls.of_world(world) -> Array[Vector3]        (x, y, radius), tile space

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
		var nx := ceili(STUMP_HALF.x * 2.0 / (STUMP_R * 1.3))
		var nz := ceili(STUMP_HALF.y * 2.0 / (STUMP_R * 1.3))
		for i in nx + 1:
			for j in nz + 1:
				var x := -STUMP_HALF.x + STUMP_R * 0.6 + (STUMP_HALF.x * 2.0 - STUMP_R * 1.2) * float(i) / float(nx)
				var z := -STUMP_HALF.y + STUMP_R * 0.6 + (STUMP_HALF.y * 2.0 - STUMP_R * 1.2) * float(j) / float(nz)
				out.append(Vector3(x, z, STUMP_R))
		return out
	for wall: Array in CROFT[variant % CROFT.size()]:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		var n := maxi(1, ceili(a.distance_to(b) / STEP))
		for i in n + 1:
			var p := a.lerp(b, float(i) / float(n))
			out.append(Vector3(p.x, p.y, WALL_R))
	return out


## Every standing ruin's walls in this world, in tile space.
## The prop ids of every ruin in `w`, standing or fallen.
static func ids_of(w: WorldData) -> PackedInt32Array:
	var out := PackedInt32Array()
	w.sync_table()
	var t := w.table
	for row in t.size():
		if t.kind[row] == PropKind.RUIN:
			out.append(t.id[row])
	return out


static func of_world(w: WorldData) -> Array[Vector3]:
	var out: Array[Vector3] = []
	w.sync_table()
	var t := w.table
	for row in t.size():
		if t.kind[row] != PropKind.RUIN or w.depleted.has(t.id[row]):
			continue
		var pos: Vector2 = t.pos[row]
		var c := maxi(Country.COAST, w.country_at(floori(pos.x), floori(pos.y)))
		var tower := BiomeDressing.of(c).ruin_form == &"tower"
		var p := w.prop_at(row)
		var v := PropModels.variant_of(p, w.seed_value, c)
		var s := float(t.scale[row])
		for m: Vector3 in model(v, tower):
			var at := pos + Vector2(m.x, m.y).rotated(float(t.rot[row])) * s
			out.append(Vector3(at.x, at.y, m.z * s))
	return out
