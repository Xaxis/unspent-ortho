extends TestCase
## THE FLOODS READ OFF A WINDOW ANSWER AS THE PLAIN ONES DID. `Sentinels.opens`
## and `_founder_flood` read a TileWindow's level and ground; the plain
## versions they replaced (`opens_plainly`, `founder_flood_plainly`) read through
## the world's methods and are kept only to be compared against them, the way
## Works.room_at_plainly is. Asked of every den the station rule and the lairs
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
				var o2 := Sentinels.opens_plainly(w, p, def)
				var f2 := Sentinels.founder_flood_plainly(w, p, def, Sentinels.FOUNDER_LEAST, false, def.reach)
				var spot2 := Sentinels.founder_flood_plainly(w, p, def, 1 << 30, true, -1.0)
				fast_us += t1 - t0
				plain_us += Time.get_ticks_usec() - t1
				eq(o, o2, "seed %d: the %s's room at %s opens as plainly" % [s, def.id, p])
				eq(f, f2, "and its founder ground counts as plainly")
				eq(spot, spot2, "and its founder spot is the plain one's")
	print("       %d rooms asked: %.3f ms a room read off a window, %.3f ms plainly" % [asked, fast_us / 1000.0 / maxf(1.0, asked), plain_us / 1000.0 / maxf(1.0, asked)])
	gt(float(asked), 500.0, "four worlds' keepers' rooms were asked (%d)" % asked)
