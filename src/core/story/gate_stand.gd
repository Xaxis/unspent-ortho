class_name GateStand
## Where a gate into the Before stands off the place it opens from (StoryGates).
##
##   GateStand.of(world, row) -> Vector2    the spot, for a slot's cast row
##   GateStand.clear_before(era, cast)      the Before's own things off its gates
##
## A slot is cast at its place's HEART, and the heart is where the place's own
## mass stands: a works yard's raised deck, a landmark's tower, the platform in the
## sea. A gate stood there was inside the deck on every seed (the player warped to
## it stood with his head through the plate, and nothing of the gate showed under
## it), and nobody could walk into its reach at all. So a gate stands on the
## nearest open ground OUTSIDE its place: a body can stand anywhere in its reach,
## its light lies flat and under the sky, nothing the place holds answers `use`
## there first, and a body can walk to it.
##
## Asked once per world, by the surface's casting (StoryCasting), which keeps the
## spot in the slot's row: the Before's twin rows are copies of the surface's, so
## a gate is one spot in both years. Its place's mass is read off the surface,
## where it stands (the Before has no yard yet), and only generated props are read,
## so nothing built or felled in play ever moves a gate and a loaded game stands it
## where a new one does. Windowed: the tiles round the place and the props of the
## sections they lie in (WorldSections), never the whole world.
##
## It names nothing of the story's words or beats: casting compiles before the
## game's autoloads stand, and anything that reaches `Story` from here breaks it.

## How near a body must be to a gate to step through it (20_realms GATE_REACH),
## and so how far round it the ground must be open: no wall, nothing solid, nothing
## else that answers `use`. The lit oval (EraGate.WIDE across) lies inside it.
const REACH := 1.5
## How far round a gate its light lies on one level: half EraGate.WIDE and a hair.
## A patch of daylight laid over a terrace lip is half buried in the step.
const LIGHT := 1.2
## The farthest off its place a gate is looked for, in tiles. The black site's
## platform stands in the sea moated by deep water (BlackSite.MOAT), so its gate is
## the nearest dry ground to it, which can be the beach it is seen from
## (BlackSite.FURTHEST off the spawn).
const SEEK := 44
## How far on from a gate a body must be able to walk, in tiles: a gate on a
## pocket of ground shut in by cliffs, water or walls is a gate nobody reaches.
const WALK_OUT := 12.0
## How far a gate's middle keeps from a door: past its own reach and a door's
## (21_doors REACH, 1.4) together, so `use` in the gate never opens the door; the
## key's reach (StoryProps.REACH), as 49_cast keeps a door off a person.
## tests/story/test_gate_stand.gd holds it to both.
const DOOR_KEEP := 3.0
## How far a gate's middle keeps from the road: its reach, and a hold's barrier
## across the road and its verges (24_holds: blocks of BLOCK 0.6 at ACROSS 3.2
## apart, on a road tile's middle), so no barrier ever comes down inside a gate.
## The road is the plan's and the carts', and the barrier stands where the
## chapters fall, which a gate cannot know. tests/story/test_gate_stand.gd holds
## it to 24_holds.
const ROAD_KEEP := 3.7
## A hatch's housing (21_doors stands one at a depot's back end and inside a
## landmark's ground): its reach is what stops a body there.
const Hatch := preload("res://src/models/interior/hatch_model.gd")
const PlayView := preload("res://src/core/view/play_view.gd")


## THE SPOT, off the place cast in `row`: the nearest tile middle whose reach is
## open ground (`_open`), outside everything the place is built of and clear of
## all it holds that answers `use` (`_place`), off the road (ROAD_KEEP), clear of
## every solid prop, ruin wall and door round it, from which a body can walk on
## WALK_OUT tiles. Nearest by whole tiles;
## within one tile's band, the side the play camera looks from
## (PlayView.toward_eye), so the place never stands between the eye and its own
## gate. Where nothing within SEEK has its light lying flat, the first whose reach
## is only walkable; where nothing at all, the place itself.
static func of(world: WorldData, row: Dictionary) -> Vector2:
	var at: Vector2 = row.get("pos", Vector2.INF)
	if world == null or not at.is_finite():
		return at
	var place := _place(world, row)
	var walls: Array[Vector3] = place[0]
	var keep: Array[Vector3] = place[1]
	var near := _Near.new(world, at, float(SEEK) + WALK_OUT + REACH + 2.0, walls)
	var tile := Vector2i(at.floor())
	for flat: bool in [true, false]:
		for o: Vector2i in _rings():
			var p := Vector2(tile + o) + Vector2(0.5, 0.5)
			if _open(world, p, flat) and not _within(p, keep) and not _surrounded(p, walls) \
					and not _by_road(world, p) and near.clear(p, REACH) and not near.by_door(p) \
					and near.walks_out(p):
				return p
	return at


## IN THE BEFORE, NOTHING OF ITS OWN STANDS IN A GATE'S REACH. A gate's spot is
## worked out on the surface, where its place stands (`of`), and the Before is
## dressed otherwise round a 2098 place (no plan, no yard: seed 1's camp gate
## stood half under a 2029 pine), while its own world is not grown when the
## surface is cast. So what the Before's generation stood in a gate's reach is
## taken in that world's own record (`depleted`, as a tread's pads crush what
## they come down on: 19_colossi.prepare_world) before any view draws it, and
## the gate's ground is open in both years. `cast` is the Before's casting: its
## twin rows carry the gates. A wall (a landmark's mass) is no prop and stays;
## a body still stands in the gate.
static func clear_before(w: WorldData, cast: Dictionary) -> void:
	if w == null or w.realm != Realm.ERA:
		return
	var t := w.table
	var top := (w.size - 1) / WorldSections.SIZE
	for slot: Variant in cast:
		var row: Dictionary = cast[slot]
		if not row.has("gate"):
			continue
		var at: Vector2 = row.gate
		var reach := REACH + 4.0
		var s0 := WorldSections.of(at - Vector2(reach, reach))
		var s1 := WorldSections.of(at + Vector2(reach, reach))
		for sy in range(clampi(s0.y, 0, top), clampi(s1.y, 0, top) + 1):
			for sx in range(clampi(s0.x, 0, top), clampi(s1.x, 0, top) + 1):
				for r in WorldSections.rows_in(w, Vector2i(sx, sy)):
					if (t.id[r] & WorldData.BUILT_BIT) != 0 or t.pos[r].distance_to(at) > reach:
						continue
					if _stands_in(w, r, at):
						w.depleted[t.id[r]] = INF


## Whether the prop on table row `r` comes within REACH of `at`: its own circle,
## or a ruin's walls.
static func _stands_in(w: WorldData, r: int, at: Vector2) -> bool:
	var t := w.table
	if t.solid[r] > 0.0 and t.pos[r].distance_to(at) - t.solid[r] < REACH:
		return true
	if RuinWalls.KINDS.has(int(t.kind[r])):
		for c: Vector3 in RuinWalls.of_row(w, r):
			if Vector2(c.x, c.y).distance_to(at) - c.z < REACH:
				return true
	return false


## The place's own mass and what it holds that answers `use`, from its cast row:
## [walls (x, y, radius), keep (x, y, how far a gate's middle keeps off it)]. A
## depot's yard and parts (Works.walls), its deck's ramp, its hatch and the
## parts' own reach; a
## landmark's mass (Landmarks.walls), its hatch and its cache's reach; the black
## site's platform. A village's mass is its houses, which are props (`_Near`).
## A hatch is counted whether or not this landscape keeps a room under it: the
## gate keeps off the spot either way.
static func _place(world: WorldData, row: Dictionary) -> Array:
	var walls: Array[Vector3] = []
	var keep: Array[Vector3] = []
	var at: Vector2 = row.pos
	var facing := float(row.get("facing", 0.0))
	match StringName(str(row.get("site", &""))):
		StorySlot.WORKS:
			var s := WorksSite.new()
			s.pos = at
			s.facing = facing
			s.land = StringName(str(row.get("land", &"")))
			s.region = int(row.get("region", -1))
			walls = Works.walls(world, s)
			if Works.form(s) == WorksDepot.DECK:
				# The ramp onto the deck stops nobody and is drawn: a gate's light
				# lying over its foot reads as the deck's own.
				var half := Vector2(WorksDepot.RAMP_LONG * 0.5, WorksDepot.DECK_WIDE * 0.5 - WorksDepot.RAMP_IN)
				var foot := at + Vector2.from_angle(facing) * (WorksDepot.DECK_LONG * 0.5 + half.x)
				keep.append(Vector3(foot.x, foot.y, half.length() + LIGHT))
			for i in Works.PART_NAMES.size():
				var part := s.part(i)
				keep.append(Vector3(part.x, part.y, Works.PART_REACH + REACH))
			_hatch(Threshold.of_depot(s, &"", 0), walls, keep)
		StorySlot.LANDMARK:
			var l := LandmarkSite.new()
			l.pos = at
			l.facing = facing
			l.kind = StringName(str(row.get("kind", &"")))
			walls = Landmarks.walls(l)
			var cache := Landmarks.cache_of(l)
			keep.append(Vector3(cache.x, cache.y, Landmarks.OPEN_REACH + REACH))
			_hatch(Threshold.of_landmark(l, &"", 0), walls, keep)
		StorySlot.BLACK_SITE:
			walls.append(Vector3(at.x, at.y, BlackSite.WALL))
	for w: Vector3 in walls:
		keep.append(Vector3(w.x, w.y, w.z + REACH))
	return [walls, keep]


static func _hatch(t: Threshold, walls: Array[Vector3], keep: Array[Vector3]) -> void:
	walls.append(Vector3(t.host.x, t.host.y, Hatch.REACH))
	keep.append(Vector3(t.door.x, t.door.y, DOOR_KEEP))


## Whether `p` is nearer one of `keep`'s points than it keeps.
static func _within(p: Vector2, keep: Array[Vector3]) -> bool:
	for k: Vector3 in keep:
		if p.distance_to(Vector2(k.x, k.y)) <= k.z:
			return true
	return false


## Whether the place's mass stands all round `p`: no half-turn of open bearing
## between its walls as seen from there, which is being inside the place (under a
## firewatch's legs, between a hulk's feet, in a ring of stones) however far the
## nearest wall is.
static func _surrounded(p: Vector2, walls: Array[Vector3]) -> bool:
	if walls.size() < 3:
		return false
	var turns := PackedFloat32Array()
	for w: Vector3 in walls:
		turns.append((Vector2(w.x, w.y) - p).angle())
	turns.sort()
	var gap := turns[0] + TAU - turns[turns.size() - 1]
	for i in range(1, turns.size()):
		gap = maxf(gap, turns[i] - turns[i - 1])
	return gap < PI


## Whether a road tile's middle lies within ROAD_KEEP of `p`.
static func _by_road(world: WorldData, p: Vector2) -> bool:
	var r := ceili(ROAD_KEEP)
	var cx := floori(p.x)
	var cy := floori(p.y)
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if world.on_road(x, y) and p.distance_to(Vector2(x + 0.5, y + 0.5)) < ROAD_KEEP:
				return true
	return false


## Open ground for a gate at `p`: its tile dry and under the sky; every tile its
## reach covers walkable (not deep water) within a step of it; and, when `flat`,
## every tile its light covers dry and on its own level.
static func _open(world: WorldData, p: Vector2, flat: bool) -> bool:
	var x := floori(p.x)
	var y := floori(p.y)
	if not world.in_bounds(x, y) or Ground.is_water(world.ground_at(x, y)):
		return false
	if world.has_overhead() and world.overhead_at(x, y) != WorldData.NO_OVERHEAD:
		return false
	var level := world.level_at(x, y)
	for i in 8:
		var d := Vector2.from_angle(TAU * float(i) / 8.0)
		var r := Vector2i((p + d * REACH).floor())
		if Ground.is_deep(world.ground_at(r.x, r.y)) or absi(world.level_at(r.x, r.y) - level) > 1:
			return false
		if flat:
			var l := Vector2i((p + d * LIGHT).floor())
			if Ground.is_water(world.ground_at(l.x, l.y)) or world.level_at(l.x, l.y) != level:
				return false
	return true


## Tile offsets out to SEEK, in the order a gate's spot is looked for: by whole
## tiles out, then toward the eye, then nearest, then by row and column. Worked out
## once a process; casting runs on workers too, so it is made under a lock.
static var _ring_order: Array[Vector2i] = []
static var _ring_lock := Mutex.new()


static func _rings() -> Array[Vector2i]:
	_ring_lock.lock()
	if _ring_order.is_empty():
		var eye := PlayView.toward_eye()
		var rows: Array[Vector2i] = []
		for dy in range(-SEEK, SEEK + 1):
			for dx in range(-SEEK, SEEK + 1):
				if dx * dx + dy * dy <= SEEK * SEEK:
					rows.append(Vector2i(dx, dy))
		rows.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var la := Vector2(a).length()
			var lb := Vector2(b).length()
			if floori(la) != floori(lb):
				return la < lb
			var ea := Vector2(a).normalized().dot(eye)
			var eb := Vector2(b).normalized().dot(eye)
			if not is_equal_approx(ea, eb):
				return ea > eb
			if la != lb:
				return la < lb
			return a.y < b.y if a.y != b.y else a.x < b.x)
		_ring_order = rows
	var out := _ring_order
	_ring_lock.unlock()
	return out


## What stands round a place, read once for its gate: the solid generated props of
## the sections the search covers and the ruins' walls (RuinWalls.of_row), filed
## by tile, the houses' doors, and the place's own walls, so each spot asks only
## the tiles round it.
class _Near:
	var world: WorldData
	var walls: Array[Vector3]
	## Tile index -> Array of (x, y, solid).
	var cells := {}
	var widest := 0.0
	var doors: Array[Vector2] = []
	## Tile index -> whether a body's middle may stand at that tile's middle.
	var _open_tile := {}

	func _init(w: WorldData, at: Vector2, reach: float, place_walls: Array[Vector3]) -> void:
		world = w
		walls = place_walls
		var lo := Vector2(at.x - reach, at.y - reach)
		var hi := Vector2(at.x + reach, at.y + reach)
		var top := (w.size - 1) / WorldSections.SIZE
		var s0 := WorldSections.of(lo)
		var s1 := WorldSections.of(hi)
		var t := w.table
		for sy in range(clampi(s0.y, 0, top), clampi(s1.y, 0, top) + 1):
			for sx in range(clampi(s0.x, 0, top), clampi(s1.x, 0, top) + 1):
				for row in WorldSections.rows_in(w, Vector2i(sx, sy)):
					if (t.id[row] & WorldData.BUILT_BIT) != 0:
						continue
					var p := t.pos[row]
					if p.x < lo.x or p.y < lo.y or p.x > hi.x or p.y > hi.y:
						continue
					var solid := t.solid[row]
					if solid > 0.0:
						_file(Vector3(p.x, p.y, solid))
					# A ruin's own circle is half a tile; its walls are a house's.
					if RuinWalls.KINDS.has(int(t.kind[row])):
						for c: Vector3 in RuinWalls.of_row(w, row):
							_file(c)
					if t.kind[row] == PropKind.HOUSE:
						# Where Threshold.of_house stands a house's door.
						doors.append(p + Vector2.from_angle(t.rot[row]) * (solid + 0.4))
		for c: Vector3 in walls:
			widest = maxf(widest, c.z)

	func _file(c: Vector3) -> void:
		var k := floori(c.y) * world.size + floori(c.x)
		if not cells.has(k):
			cells[k] = []
		(cells[k] as Array).append(c)
		widest = maxf(widest, c.z)

	## Whether nothing solid comes within `room` of `p`, edge to edge.
	func clear(p: Vector2, room: float) -> bool:
		for c: Vector3 in walls:
			if p.distance_to(Vector2(c.x, c.y)) - c.z < room:
				return false
		var r := ceili(room + widest)
		var cx := floori(p.x)
		var cy := floori(p.y)
		for y in range(cy - r, cy + r + 1):
			for x in range(cx - r, cx + r + 1):
				if not world.in_bounds(x, y):
					continue
				var k := y * world.size + x
				for c: Vector3 in cells.get(k, []):
					if p.distance_to(Vector2(c.x, c.y)) - c.z < room:
						return false
		return true

	func by_door(p: Vector2) -> bool:
		for d: Vector2 in doors:
			if p.distance_to(d) <= GateStand.DOOR_KEEP:
				return true
		return false

	## Whether a body can walk WALK_OUT tiles on from `p`, tile to tile on foot:
	## never into deep water, a step at most, and never onto a tile whose middle
	## something solid stands within a body's radius of.
	func walks_out(p: Vector2) -> bool:
		var start := Vector2i(p.floor())
		var seen := {start: true}
		var edge: Array[Vector2i] = [start]
		var head := 0
		while head < edge.size():
			var t: Vector2i = edge[head]
			head += 1
			if (Vector2(t) + Vector2(0.5, 0.5)).distance_to(p) >= GateStand.WALK_OUT:
				return true
			var level := world.level_at(t.x, t.y)
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = t + o
				if seen.has(n):
					continue
				if not _walkable(n):
					seen[n] = true
					continue
				if absi(world.level_at(n.x, n.y) - level) > 1:
					continue
				seen[n] = true
				edge.append(n)
		return false

	func _walkable(t: Vector2i) -> bool:
		if not world.in_bounds(t.x, t.y) or Ground.is_deep(world.ground_at(t.x, t.y)):
			return false
		var k := t.y * world.size + t.x
		if not _open_tile.has(k):
			_open_tile[k] = clear(Vector2(t) + Vector2(0.5, 0.5), Tuning.PLAYER_RADIUS)
		return bool(_open_tile[k])
