extends TestCase
## The middens' slot canyons (GenSlots, BiomeDef.relief `slots`), measured on a
## generated world rather than on the plan: floor share and width, walls that
## stand as one face, a floor network a body can walk end to end with dead ends
## in it, and no way up onto the plateau but the ramps.

const SEED := 1
const SIZE := 768
## Tiles from any other landscape before a middens tile is measured: the plateau
## runs down into its neighbours over the blend, which is a border, not a way up.
const CORE_FROM := 8.0

static var _w: WorldData = null


static func _world() -> WorldData:
	if _w == null:
		_w = WorldGen.generate(SEED, SIZE)
	return _w


## [core mask, up field] for the middens of the test world.
static func _read() -> Array:
	var w := _world()
	var size := w.size
	var mid := BiomeRegistry.index_of(&"the_middens")
	var edge := PackedByteArray()
	edge.resize(size * size)
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var i := y * size + x
			var c := w.country[i]
			if c != mid or w.level[i] <= 0:
				continue
			if w.country[i - 1] != c or w.country[i + 1] != c or w.country[i - size] != c or w.country[i + size] != c:
				edge[i] = 1
	for i in edge.size():
		if w.country[i] != mid:
			edge[i] = 1
	var d := WorldGen.distance_field(edge, size)
	var core := PackedByteArray()
	core.resize(size * size)
	for i in core.size():
		core[i] = 1 if d[i] > CORE_FROM and w.country[i] == mid and w.level[i] > 0 else 0
	var plan := GenSlots.plan(SEED, size)
	return [core, plan]


## The plan's floors in the core (`up` 0; a ramp's floor is not counted). What
## the world made of them is held by the walls test: each stands a wall under
## its plateau neighbour.
static func _floors(w: WorldData, core: PackedByteArray) -> PackedByteArray:
	var up := _up()
	var out := PackedByteArray()
	out.resize(w.size * w.size)
	for i in out.size():
		out[i] = 1 if core[i] != 0 and up[i] <= 0.02 else 0
	return out


static var _up_cache := PackedFloat32Array()


static func _up() -> PackedFloat32Array:
	if _up_cache.is_empty():
		_up_cache = GenSlots.plan(SEED, SIZE).field(SEED, SIZE, _ones(SIZE))
	return _up_cache


func test_the_middens_are_a_labyrinth_of_slot_floors() -> void:
	var w := _world()
	var size := w.size
	var r := _read()
	var core: PackedByteArray = r[0]
	var plan: GenSlots = r[1]
	var area := 0
	for i in core.size():
		area += core[i]
	gt(float(area), 1500.0, "seed %d at %d has a middens core to measure (%d tiles)" % [SEED, SIZE, area])
	var floors := _floors(w, core)
	var floor_n := 0
	for i in floors.size():
		floor_n += floors[i]
	var share := float(floor_n) / float(area)
	print("       middens core %d tiles, floor %d (%.3f)" % [area, floor_n, share])
	check(share >= 0.30 and share <= 0.45, "floor is 30-45%% of the middens: %.3f" % share)
	# Width: the shorter of a floor tile's row run and column run of floor.
	var widths: Array[int] = []
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var i := y * size + x
			if floors[i] == 0:
				continue
			var rx := 1
			var k := i - 1
			while floors[k] != 0 and rx < 40:
				rx += 1
				k -= 1
			k = i + 1
			while floors[k] != 0 and rx < 40:
				rx += 1
				k += 1
			var ry := 1
			k = i - size
			while k >= 0 and floors[k] != 0 and ry < 40:
				ry += 1
				k -= size
			k = i + size
			while k < floors.size() and floors[k] != 0 and ry < 40:
				ry += 1
				k += size
			widths.append(mini(rx, ry))
	widths.sort()
	var median := widths[widths.size() / 2]
	print("       median floor width %d" % median)
	check(median >= 3 and median <= 6, "median floor width is 3-6 tiles: %d" % median)
	# Rooms: nodes where three or more floors meet, inside the core.
	var rooms := 0
	var dead := 0
	var ramps := 0
	for k in plan.centre.size():
		var c := plan.centre[k]
		var i := clampi(int(c.y), 0, size - 1) * size + clampi(int(c.x), 0, size - 1)
		if core[i] == 0:
			continue
		if plan.degree[k] >= 3:
			rooms += 1
		elif plan.degree[k] == 1:
			dead += 1
			if plan.ramp[k] != 0:
				ramps += 1
		# Blind alleys: a dead end each.
		for f: float in [plan.east_stub[k], plan.south_stub[k]]:
			if f != 0.0:
				dead += 1
	var per_k := float(dead) * 1000.0 / float(area)
	print("       rooms %d, dead ends %d (%.1f per 1000 tiles), ramps %d" % [rooms, dead, per_k, ramps])
	gt(float(rooms), 0.0, "floors open into rooms where they cross")
	gt(per_k, 1.0, "at least one dead end per 1000 tiles")
	gt(float(ramps), 0.0, "some dead ends ramp up")


func test_slot_walls_stand_as_one_face() -> void:
	var w := _world()
	var size := w.size
	var core: PackedByteArray = _read()[0]
	var up := _up()
	# Every floor tile of the plan beside a plateau tile of the plan: the world
	# drops the whole wall in that one step, not down a stair of terraces.
	var faces := 0
	var sheer := 0
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var i := y * size + x
			if core[i] == 0 or up[i] > 0.02:
				continue
			for j: int in [i - 1, i + 1, i - size, i + size]:
				if core[j] == 0 or up[j] < 0.98:
					continue
				faces += 1
				if w.level[j] - w.level[i] >= 4:
					sheer += 1
	var share := float(sheer) / maxf(1.0, float(faces))
	print("       wall faces %d, sheer %d (%.3f)" % [faces, sheer, share])
	gt(share, 0.8, "slot walls stand in one step: %.3f" % share)


## Walkable from any of `from`: 4-connected, a step of at most one level, only
## over `allowed` (and any step at all where `level_free`, to find a lobe).
static func _fill(w: WorldData, from: PackedInt32Array, allowed: PackedByteArray, level_free := false) -> PackedByteArray:
	var size := w.size
	var seen := PackedByteArray()
	seen.resize(size * size)
	var stack := PackedInt32Array()
	for f in from:
		if seen[f] == 0:
			seen[f] = 1
			stack.append(f)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % size
		for j: int in [i - 1 if x > 0 else -1, i + 1 if x < size - 1 else -1, i - size, i + size]:
			if j < 0 or j >= seen.size() or seen[j] != 0 or allowed[j] == 0:
				continue
			if not level_free and absi(w.level[j] - w.level[i]) > 1:
				continue
			seen[j] = 1
			stack.append(j)
	return seen


## The tile nearest `p` (a point of the plan, before the warp moves it) that is
## floor (`floor`) or plateau (not), within four tiles; -1 if none.
static func _near(up: PackedFloat32Array, size: int, p: Vector2, floor: bool) -> int:
	var best := -1
	var bd := 1e9
	for oy in range(-4, 5):
		for ox in range(-4, 5):
			var x := int(p.x) + ox
			var y := int(p.y) + oy
			if x < 0 or y < 0 or x >= size or y >= size:
				continue
			var i := y * size + x
			if (floor and up[i] > 0.02) or (not floor and up[i] < 0.98):
				continue
			var d := float(ox * ox + oy * oy)
			if d < bd:
				bd = d
				best = i
	return best


func test_each_lobe_is_one_network_of_floors() -> void:
	var w := _world()
	var size := w.size
	var core: PackedByteArray = _read()[0]
	var floors := _floors(w, core)
	var up := _up()
	var mid := BiomeRegistry.index_of(&"the_middens")
	var land := PackedByteArray()
	land.resize(size * size)
	var walk := PackedByteArray()
	walk.resize(size * size)
	for i in land.size():
		land[i] = 1 if w.country[i] == mid and w.level[i] > 0 else 0
		# The floors and the ramps' floors: never the plateau.
		walk[i] = 1 if land[i] != 0 and up[i] < 0.98 else 0
	# A lobe is one piece of the middens' land; each keeps its own maze, so
	# each is measured on its own. The floors of each big one are one network.
	var lobed := PackedByteArray()
	lobed.resize(size * size)
	var lobes := 0
	for i in floors.size():
		if floors[i] == 0 or lobed[i] != 0:
			continue
		var lobe := _fill(w, PackedInt32Array([i]), land, true)
		var in_lobe := 0
		for j in lobe.size():
			if lobe[j] != 0:
				lobed[j] = 1
				in_lobe += floors[j]
		if in_lobe < 300:
			continue
		lobes += 1
		var done := PackedByteArray()
		done.resize(size * size)
		var best := 0
		for j in lobe.size():
			if lobe[j] == 0 or floors[j] == 0 or done[j] != 0:
				continue
			var reach := _fill(w, PackedInt32Array([j]), walk)
			var got := 0
			for q in reach.size():
				if reach[q] != 0 and floors[q] != 0:
					got += 1
					done[q] = 1
			best = maxi(best, got)
		var share := float(best) / float(in_lobe)
		print("       lobe of %d floor tiles: largest walkable network %d (%.3f)" % [in_lobe, best, share])
		gt(share, 0.85, "a lobe's floors are one network: %.3f of %d" % [share, in_lobe])
	gt(float(lobes), 0.0, "a lobe big enough to measure")


func test_only_ramps_climb_out_of_the_slots() -> void:
	var w := _world()
	var size := w.size
	var core: PackedByteArray = _read()[0]
	var plan: GenSlots = _read()[1]
	var floors := _floors(w, core)
	var up := _up()
	# EVERY RAMP CLIMBS: its foot at the junction and its top in the plateau are
	# joined by a walk a level at a time.
	var ramps := 0
	var climbed := 0
	for k in plan.ramp.size():
		if plan.ramp[k] == 0:
			continue
		var foot := _near(up, size, plan.ramp_from[k], true)
		var top := _near(up, size, plan.ramp_to[k], false)
		if foot < 0 or top < 0 or core[foot] == 0 or core[top] == 0:
			continue
		ramps += 1
		climbed += _fill(w, PackedInt32Array([foot]), core)[top]
	print("       ramps in the core %d, climbable %d" % [ramps, climbed])
	gt(float(ramps), 0.0, "the core has ramps")
	gt(float(climbed), float(ramps) * 0.8, "its ramps climb: %d of %d" % [climbed, ramps])
	# NOTHING ELSE DOES: from every floor of the core, with the ramps taken away,
	# next to none of the core's plateau is reached. A village levels its own
	# ground and apron (GenSettle._flatten) and a road is graded a level a step:
	# those are the settled ways in, made by settling, and are left out here.
	var settled := _settled(w)
	var starts := PackedInt32Array()
	var no_ramps := PackedByteArray()
	no_ramps.resize(size * size)
	var plateau := 0
	for i in up.size():
		if core[i] == 0 or settled[i] != 0:
			continue
		if floors[i] != 0:
			starts.append(i)
		if up[i] <= 0.02 or up[i] >= 0.98:
			no_ramps[i] = 1
		if up[i] >= 0.98:
			plateau += 1
	var shut := _fill(w, starts, no_ramps)
	var got := 0
	for i in up.size():
		if core[i] != 0 and settled[i] == 0 and up[i] >= 0.98:
			got += shut[i]
	# The ways in that are not drawn ramps: plateau tiles a floor steps onto,
	# gathered into places (8 tiles apart is another place). GenAccess cuts a
	# scree breach onto any plateau island no drawn ramp reached, and that is
	# a ramp too; what this bars is a wall anywhere that is not a wall.
	var entries: Array[Vector2i] = []
	for i in up.size():
		if core[i] == 0 or settled[i] != 0 or up[i] < 0.98 or shut[i] == 0:
			continue
		var x := i % size
		for j: int in [i - 1 if x > 0 else -1, i + 1 if x < size - 1 else -1, i - size, i + size]:
			if j >= 0 and j < up.size() and up[j] <= 0.02 and shut[j] != 0 and absi(w.level[j] - w.level[i]) <= 1:
				entries.append(Vector2i(x, i / size))
				break
	var places: Array[Vector2i] = []
	for e in entries:
		var near := false
		for q in places:
			near = near or (e - q).length_squared() <= 64
		if not near:
			places.append(e)
	var area := 0
	for i in core.size():
		area += core[i]
	var per_k := float(places.size()) * 1000.0 / float(area)
	var a := float(got) / maxf(1.0, float(plateau))
	print("       plateau %d, reached without the drawn ramps %d (%.3f) through %d other ways in (%.2f per 1000 tiles): %s" % [plateau, got, a, places.size(), per_k, str(places)])
	lt(per_k, 1.5, "the ways up besides the drawn ramps are a few breaches: %.2f per 1000 tiles" % per_k)


static func _settled(w: WorldData) -> PackedByteArray:
	var size := w.size
	var out := PackedByteArray()
	out.resize(size * size)
	for v: Dictionary in w.villages:
		var p: Vector2 = v.pos
		for y in range(maxi(0, int(p.y) - 26), mini(size, int(p.y) + 27)):
			for x in range(maxi(0, int(p.x) - 26), mini(size, int(p.x) + 27)):
				if Vector2(x, y).distance_to(p) <= 26.0:
					out[y * size + x] = 1
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			if w.road[y * size + x] == 0:
				continue
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					out[(y + oy) * size + x + ox] = 1
	return out


static func _ones(size: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(size * size)
	a.fill(1.0)
	return a


## `GenSlots.node` reads one node without the plan; it has to say what the plan
## says, node for node, or an interior sited from it opens into a wall.
func test_one_node_read_alone_agrees_with_the_plan() -> void:
	var plan := GenSlots.plan(SEED, SIZE)
	var w := plan.width
	var told := 0
	for q in 300:
		var gx := int(Rng.hash01(SEED, q, 0, 77) * w)
		var gy := int(Rng.hash01(SEED, q, 1, 77) * w)
		var k := gy * w + gx
		var n := GenSlots.node(SEED, SIZE, gx, gy)
		eq(int(n.degree), int(plan.degree[k]), "node %d,%d degree" % [gx, gy])
		eq(bool(n.ramp), plan.ramp[k] != 0, "node %d,%d ramp" % [gx, gy])
		eq(n.centre, plan.centre[k], "node %d,%d centre" % [gx, gy])
		check(absf(float(n.radius) - plan.radius[k]) < 1e-5, "node %d,%d radius" % [gx, gy])
		var open: Array = n.open
		eq(open[0], gx < w - 1 and plan.east[k] != 0, "node %d,%d east" % [gx, gy])
		eq(open[1], gy < w - 1 and plan.south[k] != 0, "node %d,%d south" % [gx, gy])
		eq(open[2], gx > 0 and plan.east[k - 1] != 0, "node %d,%d west" % [gx, gy])
		eq(open[3], gy > 0 and plan.south[k - w] != 0, "node %d,%d north" % [gx, gy])
		told += 1 if int(n.degree) >= 3 or bool(n.dead_end) else 0
	gt(float(told), 50.0, "the sample holds rooms and dead ends: %d" % told)
