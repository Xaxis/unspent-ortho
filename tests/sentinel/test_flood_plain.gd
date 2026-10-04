extends TestCase
## THE FLOODS READ OFF A WINDOW ANSWER AS THE PLAIN ONES DID. `Sentinels.opens`
## and `_founder_flood` read a TileWindow's level and ground; the bodies they
## replaced read through the world's methods, and are kept here, below, only to
## be compared against them. Asked of every den the station rule and the lairs
## ask on four worlds at full size, and of rooms spread over every keeper's
## region, with the founder spot's patch search as well as its count.

const Worlds := preload("res://tests/core/test_world_gen.gd")
const SEEDS: Array[int] = [1, 7, 42, 90210]
## Rooms asked per region besides its keeper's dens, on a grid over its bounds.
const SPREAD := 24
static var _made := {}


func _world(s: int) -> WorldData:
	if Worlds.WORLD_SEEDS.has(s):
		return Worlds.world(s)
	if not _made.has(s):
		_made[s] = WorldGen.generate(s)
	return _made[s]


func test_the_floods_read_off_a_window_answer_as_the_plain_ones() -> void:
	var asked := 0
	var fast_us := 0
	var plain_us := 0
	for s: int in SEEDS:
		var w := _world(s)
		var landings: Array[Vector2] = []
		for row: Dictionary in w.continents:
			if bool(row.get("landfall", false)) and row.has("from"):
				landings.append(row["from"] as Vector2)
		var lair_of := {}
		for st: SentinelState in Sentinels.states(w):
			lair_of[st.region] = st.lair
		for r: Dictionary in w.regions:
			var def := Sentinels.for_land(StringName(str(r.get("type", &""))))
			if def == null:
				continue
			var id := int(r.get("id", -1))
			var spots: Array[Vector2] = []
			if lair_of.has(id):
				spots.append(lair_of[id])
			for m: Dictionary in w.landmarks:
				var p: Vector2 = m.get("pos", Vector2.ZERO)
				if def.stations.has(StringName(str(m.get("kind", &"")))) and w.region_at(floori(p.x), floori(p.y)) == id:
					var den := Sentinels.den_at(w, p, def, landings)
					spots.append(p)
					if den.is_finite():
						spots.append(den)
			var b: Rect2 = r.get("bounds", Rect2())
			var cols := maxi(1, int(sqrt(float(SPREAD))))
			for i in cols:
				for j in cols:
					spots.append(b.position + Vector2((i + 0.5) * b.size.x / cols, (j + 0.5) * b.size.y / cols))
			for p: Vector2 in spots:
				asked += 1
				var t0 := Time.get_ticks_usec()
				var o := Sentinels.opens(w, p, def)
				var f := Sentinels._founder_flood(w, p, def, Sentinels.FOUNDER_LEAST, false, def.reach)
				var spot := Sentinels._founder_flood(w, p, def, 1 << 30, true, -1.0)
				var t1 := Time.get_ticks_usec()
				var o2 := opens_plainly(w, p, def)
				var f2 := founder_flood_plainly(w, p, def, Sentinels.FOUNDER_LEAST, false, def.reach)
				var spot2 := founder_flood_plainly(w, p, def, 1 << 30, true, -1.0)
				fast_us += t1 - t0
				plain_us += Time.get_ticks_usec() - t1
				eq(o, o2, "seed %d: the %s's room at %s opens as plainly" % [s, def.id, p])
				eq(f, f2, "and its founder ground counts as plainly")
				eq(spot, spot2, "and its founder spot is the plain one's")
	print("       %d rooms asked: %.3f ms a room read off a window, %.3f ms plainly" % [asked, fast_us / 1000.0 / maxf(1.0, asked), plain_us / 1000.0 / maxf(1.0, asked)])
	gt(float(asked), 500.0, "four worlds' keepers' rooms were asked (%d)" % asked)


## THE REPLACED BODIES, as Sentinels had them: every tile asked of the world
## through its methods. Nothing in the game calls these.
static func opens_plainly(world: WorldData, at: Vector2, def: SentinelDef) -> int:
	var row := Roster.row(def.kind)
	var step := maxi(1, int(row.get("climbs", 1)))
	var tall := int(ceil(float(row.get("height", 1.0)) / WorldData.STEP))
	var cx := floori(at.x)
	var cy := floori(at.y)
	if not Sentinels._keeper_ground(world, cx, cy, tall):
		return 0
	var side := Sentinels.OPEN_TO * 2 + 1
	var seen := PackedByteArray()
	seen.resize(side * side)
	seen[Sentinels.OPEN_TO * side + Sentinels.OPEN_TO] = 1
	var queue: Array[Vector2i] = [Vector2i(cx, cy)]
	var head := 0
	var n := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		if maxi(absi(t.x - cx), absi(t.y - cy)) >= Sentinels.OPEN_FROM:
			n += 1
		var level := world.level_at(t.x, t.y)
		for d: Vector2i in Sentinels.STEPS4:
			var u := t + d
			var lx := u.x - cx + Sentinels.OPEN_TO
			var ly := u.y - cy + Sentinels.OPEN_TO
			if lx < 0 or ly < 0 or lx >= side or ly >= side or seen[ly * side + lx] != 0:
				continue
			if not Sentinels._keeper_ground(world, u.x, u.y, tall) or absi(world.level_at(u.x, u.y) - level) > step:
				continue
			seen[ly * side + lx] = 1
			queue.append(u)
	return n


static func founder_flood_plainly(world: WorldData, at: Vector2, def: SentinelDef, enough: int, patch: bool, within: float = -1.0) -> Array:
	var sink := Sentinels.founders(def)
	var start := Vector2i(floori(at.x), floori(at.y))
	if sink.is_empty() or not world.in_bounds(start.x, start.y):
		return [0, Vector2i(-1, -1)]
	var row := Roster.row(def.kind)
	var step := maxi(1, int(row.get("climbs", 1)))
	var tall := int(ceil(float(row.get("height", 1.0)) / WorldData.STEP))
	var reach := within if within >= 0.0 else def.reach
	var r2 := reach * reach
	var r := ceili(reach)
	# None of the ground anywhere in reach: no flood. Most of a region's rooms are
	# this, and the room search asks dozens of them.
	var any := false
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r2 and sink.has(world.ground_at(start.x + dx, start.y + dy)):
				any = true
				break
		if any:
			break
	if not any:
		return [0, Vector2i(-1, -1)]
	var side := r * 2 + 1
	var seen := PackedByteArray()
	seen.resize(side * side)
	seen[r * side + r] = 1
	var todo: Array[Vector2i] = [start]
	var head := 0
	var n := 0
	while head < todo.size() and n < enough:
		var t := todo[head]
		head += 1
		var l := world.level_at(t.x, t.y)
		for d: Vector2i in Sentinels.STEPS4:
			var u := t + d
			var lx := u.x - start.x + r
			var ly := u.y - start.y + r
			if lx < 0 or ly < 0 or lx >= side or ly >= side or seen[ly * side + lx] != 0 or not world.in_bounds(u.x, u.y) \
					or (Vector2(u) + Vector2(0.5, 0.5)).distance_squared_to(at) > r2:
				continue
			seen[ly * side + lx] = 1
			if not Sentinels._keeper_ground(world, u.x, u.y, tall) or absi(world.level_at(u.x, u.y) - l) > step:
				continue
			if sink.has(world.ground_at(u.x, u.y)):
				n += 1
				if patch and Sentinels._all_of(world, u, sink):
					return [n, u]
			todo.append(u)
	return [n, Vector2i(-1, -1)]
