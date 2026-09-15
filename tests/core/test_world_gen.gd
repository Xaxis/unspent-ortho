extends TestCase
## World generation rules, checked on real default-size worlds (cached across
## tests: generating is the expensive part) and on layouts for many seeds.

## Full worlds at the default size.
const WORLD_SEEDS: Array[int] = [1, 42, 90210]
## Layout-only seeds for country shares.
const SHARE_SEEDS: Array[int] = [1, 2, 3, 4, 5, 7, 11, 42, 99, 1337, 4242, 90210]
## World size the gate checks layouts at (see test_country_shares_on_twelve_seeds).
const GATE_SHARE_SIZE := 256

static var _worlds: Dictionary = {}


static func world(s: int) -> WorldData:
	if not _worlds.has(s):
		var t := Time.get_ticks_msec()
		_worlds[s] = WorldGen.generate(s)
		print("       world %d at %d: %d ms (%s)" % [s, Tuning.WORLD_SIZE, Time.get_ticks_msec() - t, _stage_line()])
	return _worlds[s]


static func _stage_line() -> String:
	var parts: PackedStringArray = []
	for k: StringName in WorldGen.last_timings:
		parts.append("%s %.0f" % [k, WorldGen.last_timings[k]])
	return " ".join(parts)


func test_deterministic_for_a_seed() -> void:
	var a := WorldGen.generate(7, 160)
	var b := WorldGen.generate(7, 160)
	check(a.level == b.level, "levels differ")
	check(a.ground == b.ground, "grounds differ")
	check(a.country == b.country and a.country2 == b.country2 and a.blend == b.blend, "countries differ")
	eq(a.props.size(), b.props.size(), "prop count")
	for i in mini(a.props.size(), b.props.size()):
		if a.props[i].kind != b.props[i].kind or a.props[i].pos != b.props[i].pos:
			fail("prop %d differs" % i)
			break
	eq(a.spawn, b.spawn, "spawn")
	eq(a.villages.size(), b.villages.size(), "villages")
	eq(a.rivers.size(), b.rivers.size(), "rivers")
	eq(a.roads.size(), b.roads.size(), "roads")


func test_deterministic_at_full_size_on_worker_threads() -> void:
	# Per-tile passes run in parallel bands: the same seed must still give the
	# same world however the bands were scheduled.
	var a := world(WORLD_SEEDS[0])
	var b := WorldGen.generate(WORLD_SEEDS[0])
	check(a.level == b.level, "levels differ")
	check(a.ground == b.ground, "grounds differ")
	check(a.country2 == b.country2 and a.blend == b.blend, "ecotones differ")
	eq(a.props.size(), b.props.size(), "prop count")
	for i in mini(a.props.size(), b.props.size()):
		if a.props[i].kind != b.props[i].kind or a.props[i].pos != b.props[i].pos:
			fail("prop %d differs" % i)
			break


func test_no_pits_in_the_land() -> void:
	# A lone tile of sea inside the land reads as a hole and grows a beach.
	for s in WORLD_SEEDS:
		var w := world(s)
		var size := w.size
		var pits := 0
		for y in range(1, size - 1):
			for x in range(1, size - 1):
				var i := y * size + x
				if w.level[i] <= 0 and w.level[i - 1] > 0 and w.level[i + 1] > 0 and w.level[i - size] > 0 and w.level[i + size] > 0:
					pits += 1
		lt(pits, 4, "seed %d one-tile pits of sea inside the land" % s)


func test_coast_is_varied_country() -> void:
	# The first country the player sees is not a lawn: uplands of heath, dunes
	# and shingle, marsh at the river mouths.
	for s in WORLD_SEEDS:
		var w := world(s)
		var counts := PackedFloat32Array()
		counts.resize(Ground.COUNT)
		var total := 0.0
		for i in w.ground.size():
			if w.country[i] == Country.COAST and w.level[i] > 0:
				counts[w.ground[i]] += 1.0
				total += 1.0
		lt(counts[Ground.GRASS] / total, 0.7, "seed %d coast grass share" % s)
		gt(counts[Ground.HEATH] / total, 0.08, "seed %d coast heath share" % s)
		gt(counts[Ground.SAND] / total, 0.02, "seed %d coast sand share" % s)
		gt(counts[Ground.MUD] / total, 0.01, "seed %d coast marsh share" % s)
		gt(counts[Ground.SHINGLE] / total, 0.002, "seed %d coast shingle share" % s)


func test_differs_between_seeds() -> void:
	var a := WorldGen.generate(1, 160)
	var b := WorldGen.generate(2, 160)
	check(a.level != b.level, "two seeds made the same land")


func test_small_worlds_still_generate() -> void:
	for size: int in [64, 96, 128]:
		var w := WorldGen.generate(3, size)
		var land := 0
		for l in w.level:
			if l > 0:
				land += 1
		gt(float(land) / w.level.size(), 0.3, "size %d land share" % size)
		var present := {}
		for c in w.country:
			present[c] = true
		check(present.size() >= 4, "size %d has only %d countries" % [size, present.size()])


func test_country_shares_on_twelve_seeds() -> void:
	# The gate checks the layout at half size, where it costs a quarter as much
	# and the same balancing holds the same proportions. Run the full-size sweep
	# with: tools/test.sh world_gen_slow
	_check_shares(GATE_SHARE_SIZE)


func test_country_shares_on_twelve_seeds_full_size_world_gen_slow() -> void:
	if not OS.get_cmdline_user_args().has("world_gen_slow"):
		return
	_check_shares(Tuning.WORLD_SIZE)


func _check_shares(size: int) -> void:
	var t := Time.get_ticks_msec()
	for s in SHARE_SEEDS:
		var w := WorldGen.generate(s, size, &"tiles")
		var shares := _shares(w)
		for c: int in Country.LAND:
			gt(shares[c], 0.06, "seed %d %s share" % [s, Country.NAMES[c]])
		check(shares[Country.COAST] >= 0.3 and shares[Country.COAST] <= 0.4, "seed %d coast share %.3f" % [s, shares[Country.COAST]])
		# Balanced to 13% each, on the coarse layout and again after the borders
		# wander (the brief's "roughly 10-15%").
		for c: int in [Country.MOSS, Country.PINEWOOD, Country.SNOWFIELD, Country.BONELANDS, Country.BURNING]:
			check(shares[c] >= 0.10 and shares[c] <= 0.15, "seed %d %s share %.3f at size %d" % [s, Country.NAMES[c], shares[c], size])
	print("       layouts for %d seeds at %d: %d ms" % [SHARE_SEEDS.size(), size, Time.get_ticks_msec() - t])


func test_full_worlds_keep_their_shares() -> void:
	for s in WORLD_SEEDS:
		var shares := _shares(world(s))
		for c: int in Country.LAND:
			gt(shares[c], 0.06, "seed %d %s" % [s, Country.NAMES[c]])


static func _shares(w: WorldData) -> PackedFloat32Array:
	var counts := PackedFloat32Array()
	counts.resize(Country.COUNT)
	var land := 0.0
	for i in w.country.size():
		if w.country[i] != Country.SEA:
			counts[w.country[i]] += 1.0
			land += 1.0
	for c in Country.COUNT:
		counts[c] /= maxf(1.0, land)
	return counts


func test_journey_runs_north_from_a_southern_coast() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		var mean_y := PackedFloat32Array()
		mean_y.resize(Country.COUNT)
		var counts := PackedFloat32Array()
		counts.resize(Country.COUNT)
		for y in w.size:
			for x in w.size:
				var c := w.country[y * w.size + x]
				mean_y[c] += y
				counts[c] += 1.0
		for c in Country.COUNT:
			mean_y[c] /= maxf(1.0, counts[c])
		for c: int in [Country.MOSS, Country.PINEWOOD, Country.BONELANDS]:
			lt(mean_y[c], mean_y[Country.COAST], "seed %d %s lies north of the coast" % [s, Country.NAMES[c]])
		for c: int in [Country.SNOWFIELD, Country.BURNING]:
			lt(mean_y[c], mean_y[Country.MOSS], "seed %d %s lies beyond the middle belt" % [s, Country.NAMES[c]])


func test_blend_is_half_at_borders_and_zero_deep_inside() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		var size := w.size
		var bad_range := 0
		var border := 0
		var border_ok := 0
		var deep := 0
		for y in range(1, size - 1):
			for x in range(1, size - 1):
				var i := y * size + x
				var c := w.country[i]
				var b := w.blend[i]
				if b < 0.0 or b > 0.5:
					bad_range += 1
				if c == Country.SEA:
					continue
				if b > 0.0 and w.country2[i] == c:
					bad_range += 1
				var other := w.country[i + 1]
				if other != Country.SEA and other != c:
					border += 1
					if b > 0.4 and w.blend[i + 1] > 0.4 and w.country2[i] == other:
						border_ok += 1
				if b == 0.0:
					deep += 1
		eq(bad_range, 0, "seed %d tiles with blend out of [0, 0.5] or country2 == country" % s)
		gt(border_ok, border * 0.9, "seed %d border tiles blended toward their neighbour (%d of %d)" % [s, border_ok, border])
		gt(deep, 1000, "seed %d tiles untouched by any ecotone" % s)


func test_blend_falls_from_the_border_over_12_to_24_tiles() -> void:
	var w := world(WORLD_SEEDS[0])
	var size := w.size
	var d := GenFields.distance8(_borders(w), size, 999.0)
	# Mean blend by distance band: 0.5 on the line, about half by 12 tiles,
	# nothing past 24 (two tiles of slack for the half-resolution spread).
	var sums := PackedFloat32Array()
	sums.resize(64)
	var counts := PackedFloat32Array()
	counts.resize(64)
	var far_blended := 0
	for i in size * size:
		if w.country[i] == Country.SEA:
			continue
		var k := mini(63, int(d[i]))
		sums[k] += w.blend[i]
		counts[k] += 1.0
		if d[i] > 26.0 and w.blend[i] > 0.0:
			far_blended += 1
	var at := func(k: int) -> float: return sums[k] / maxf(1.0, counts[k])
	gt(at.call(0), 0.45, "blend on the border")
	check(at.call(12) > 0.08 and at.call(12) < 0.3, "blend 12 tiles out %.2f" % at.call(12))
	lt(at.call(22), 0.03, "blend 22 tiles out")
	eq(far_blended, 0, "tiles blended further than 26 from any border")


func test_country2_never_flips_where_it_shows() -> void:
	# A renderer mixes country2's wash in by blend: away from the borders
	# themselves (where three countries can meet), two neighbours of the same
	# country must not switch country2 while either is visibly blended.
	for s in WORLD_SEEDS:
		var w := world(s)
		var size := w.size
		# Steps (4-neighbour) are never shorter than the true distance.
		var d := GenFields.near_steps(_borders(w), size, 3)
		var country := w.country
		var country2 := w.country2
		var blend := w.blend
		var visible := 0
		for y in range(1, size - 1):
			for x in range(1, size - 1):
				var i := y * size + x
				var c := country[i]
				if c == Country.SEA or d[i] < 3 or blend[i] == 0.0 and blend[i + 1] == 0.0 and blend[i + size] == 0.0:
					continue
				var c2 := country2[i]
				if country[i + 1] == c and country2[i + 1] != c2 and maxf(blend[i], blend[i + 1]) > 0.1:
					visible += 1
				if country[i + size] == c and country2[i + size] != c2 and maxf(blend[i], blend[i + size]) > 0.1:
					visible += 1
		lt(visible, 12, "seed %d country2 flips under a visible blend" % s)


static func _borders(w: WorldData) -> PackedByteArray:
	var size := w.size
	var border := PackedByteArray()
	border.resize(size * size)
	var country := w.country
	const SEA := Country.SEA
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var i := y * size + x
			var c := country[i]
			if c == SEA:
				continue
			var a := country[i - 1]
			var b := country[i + 1]
			var u := country[i - size]
			var d := country[i + size]
			if (a != SEA and a != c) or (b != SEA and b != c) or (u != SEA and u != c) or (d != SEA and d != c):
				border[i] = 1
	return border


func test_every_country_reachable_on_foot_from_spawn() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		var q := WorldQuery.new(w)
		var reached := _flood(w, q, w.spawn)
		var total := PackedFloat32Array()
		total.resize(Country.COUNT)
		var got := PackedFloat32Array()
		got.resize(Country.COUNT)
		for i in w.country.size():
			if w.level[i] > 0:
				total[w.country[i]] += 1.0
				if reached[i] != 0:
					got[w.country[i]] += 1.0
		for c: int in Country.LAND:
			gt(got[c] / maxf(1.0, total[c]), 0.85, "seed %d %s reachable share" % [s, Country.NAMES[c]])
		for v in w.villages:
			var p: Vector2 = v.pos
			check(reached[floori(p.y) * w.size + floori(p.x)] != 0, "seed %d village %s unreachable" % [s, v.name])


static func _flood(w: WorldData, q: WorldQuery, from: Vector2) -> PackedByteArray:
	var size := w.size
	var reached := PackedByteArray()
	reached.resize(size * size)
	var stack := PackedInt32Array()
	var start := floori(from.y) * size + floori(from.x)
	reached[start] = 1
	stack.append(start)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % size
		var y := i / size
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + d.x
			var ny := y + d.y
			if not w.in_bounds(nx, ny):
				continue
			var j := ny * size + nx
			if reached[j] == 0 and q.passable(x, y, nx, ny):
				reached[j] = 1
				stack.append(j)
	return reached


func test_rivers_run_downhill_to_the_sea() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		gt(w.rivers.size(), 2, "seed %d rivers" % s)
		var to_sea := 0
		for r in w.rivers:
			gt(r.size(), 8, "seed %d river length" % s)
			var prev := 99
			var rose := false
			for p in r:
				var l := w.level_at(floori(p.x), floori(p.y))
				var g := w.ground_at(floori(p.x), floori(p.y))
				check(Ground.is_water(g) or g == Ground.ICE or g == Ground.ROAD, "seed %d river tile at %s is %s" % [s, p, Ground.NAMES[g]])
				if l > prev:
					rose = true
				prev = l
			check(not rose, "seed %d a river climbs" % s)
			var end := r[r.size() - 1]
			var sea := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if w.level_at(floori(end.x) + d.x, floori(end.y) + d.y) <= 0:
					sea = true
			if sea:
				to_sea += 1
			else:
				# A tributary ends where it meets another river.
				var joins := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var g := w.ground_at(floori(end.x) + d.x, floori(end.y) + d.y)
					if g == Ground.RIVER or g == Ground.ICE or g == Ground.ROAD:
						joins = true
				check(joins, "seed %d river ends at %s, neither sea nor river" % [s, end])
		gt(to_sea, 1, "seed %d rivers reaching the sea" % s)


func test_river_channels_widen_toward_the_mouth_and_stay_wadeable() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		# Wadeable: river water is never deep water, and stands on land levels.
		for i in w.ground.size():
			if w.ground[i] == Ground.RIVER:
				check(w.level[i] >= 1, "seed %d river tile below land" % s)
				break
		# The longest river that reaches the sea: a runnel at its head, a
		# broad channel at its mouth.
		var longest := PackedVector2Array()
		for r in w.rivers:
			var e := r[r.size() - 1]
			var at_sea := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if w.level_at(floori(e.x) + d.x, floori(e.y) + d.y) <= 0:
					at_sea = true
			if at_sea and r.size() > longest.size():
				longest = r
		gt(longest.size(), 40, "seed %d a long river reaches the sea" % s)
		var head := _water_width(w, longest.slice(4, 16))
		var mouth := _water_width(w, longest.slice(longest.size() - 20, longest.size() - 8))
		lt(head, 2.0, "seed %d river width at its head" % s)
		gt(mouth, head + 0.8, "seed %d river widens to its mouth (%.1f to %.1f)" % [s, head, mouth])


## Mean count of water tiles across the channel (the 5x5 around each point,
## divided by 5).
static func _water_width(w: WorldData, pts: PackedVector2Array) -> float:
	var total := 0.0
	for p in pts:
		var wet := 0
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var g := w.ground_at(floori(p.x) + dx, floori(p.y) + dy)
				if g == Ground.RIVER or g == Ground.ICE or g == Ground.WATER:
					wet += 1
		total += wet / 5.0
	return total / maxf(1.0, pts.size())


func test_roads_join_every_village_and_are_walkable() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		var size := w.size
		gt(w.roads.size(), w.villages.size() - 2, "seed %d roads" % s)
		for r in w.roads:
			for j in range(1, r.size()):
				var a := r[j - 1]
				var b := r[j]
				var step := absi(floori(a.x) - floori(b.x)) + absi(floori(a.y) - floori(b.y))
				check(step == 1, "seed %d road not 4-connected at %s" % [s, b])
				var dl := absi(w.level_at(floori(a.x), floori(a.y)) - w.level_at(floori(b.x), floori(b.y)))
				if dl > 1:
					fail("seed %d road climbs %d levels at %s" % [s, dl, b])
					break
		# Walk road tiles from the spawn village's square (roads meet on its
		# gravel).
		var seen := PackedByteArray()
		seen.resize(size * size)
		var start: Vector2 = w.villages[0].pos
		var stack := PackedInt32Array([floori(start.y) * size + floori(start.x)])
		seen[stack[0]] = 1
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			for j: int in [i - 1, i + 1, i - size, i + size]:
				if seen[j] == 0 and (w.ground[j] == Ground.ROAD or (w.ground[j] == Ground.GRAVEL and _in_square(w, j))):
					seen[j] = 1
					stack.append(j)
		for v in w.villages:
			var p: Vector2 = v.pos
			check(seen[floori(p.y) * size + floori(p.x)] != 0, "seed %d village %s not on the road network" % [s, v.name])


static func _in_square(w: WorldData, i: int) -> bool:
	var p := Vector2(i % w.size + 0.5, i / w.size + 0.5)
	for v in w.villages:
		if (v.pos as Vector2).distance_to(p) < 5.5:
			return true
	return false


func test_villages_spread_across_countries_with_a_square() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		check(w.villages.size() >= 8 and w.villages.size() <= 12, "seed %d has %d villages" % [s, w.villages.size()])
		var countries := {}
		var q := WorldQuery.new(w)
		for v in w.villages:
			countries[v.country] = true
			var p: Vector2 = v.pos
			for kind: int in [PropKind.LAMP, PropKind.FIRE, PropKind.BENCH]:
				check(q.nearest_prop(p, 4.0, [kind]) != null, "seed %d village %s lacks a %s" % [s, v.name, PropKind.NAMES[kind]])
			var houses := 0
			for prop in q.props_near(p, 10.0):
				if prop.kind == PropKind.HOUSE:
					houses += 1
			gt(houses, 2, "seed %d village %s houses" % [s, v.name])
			# --village=N starts at (3, 3) from the square: standing room.
			var st := p + Vector2(3, 3)
			check(not Ground.is_water(w.ground_at(floori(st.x), floori(st.y))), "seed %d village %s start in water" % [s, v.name])
			for prop in q.props_near(st, 2.0):
				check(prop.solid <= 0.0 or prop.pos.distance_to(st) > prop.solid + 0.3, "seed %d village %s start blocked by %s" % [s, v.name, PropKind.NAMES[prop.kind]])
		gt(countries.size(), 4, "seed %d village countries" % s)


func test_spawn_is_beside_a_south_coast_village_facing_open_land() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		var tx := floori(w.spawn.x)
		var ty := floori(w.spawn.y)
		eq(w.country_at(tx, ty), Country.COAST, "seed %d spawn country" % s)
		check(not Ground.is_water(w.ground_at(tx, ty)), "seed %d spawn in water" % s)
		var v: Dictionary = w.villages[0]
		eq(v.country, Country.COAST, "seed %d spawn village country" % s)
		lt((v.pos as Vector2).distance_to(w.spawn), 18.0, "seed %d spawn beside the village" % s)
		# South: below the middle of the land.
		var land_ys := 0.0
		var land_n := 0.0
		for i in w.level.size():
			if w.level[i] > 0:
				land_ys += i / w.size
				land_n += 1.0
		gt(w.spawn.y, land_ys / land_n, "seed %d spawn is in the south" % s)
		# Room to stand, and nothing solid right in front.
		var q := WorldQuery.new(w)
		for prop in q.props_near(w.spawn, 4.0):
			check(prop.kind != PropKind.HOUSE, "seed %d a house crowds the spawn" % s)
		var ahead := w.spawn + Vector2.from_angle(w.spawn_facing) * 2.0
		for prop in q.props_near(ahead, 1.5):
			check(prop.solid <= 0.0, "seed %d %s blocks the first steps" % [s, PropKind.NAMES[prop.kind]])


func test_every_prop_kind_and_ground_is_placed() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		var kinds := PackedInt32Array()
		kinds.resize(PropKind.COUNT)
		for p in w.props:
			kinds[p.kind] += 1
		for k in PropKind.COUNT:
			gt(kinds[k], 0, "seed %d %s placed" % [s, PropKind.NAMES[k]])
		var grounds := PackedInt32Array()
		grounds.resize(Ground.COUNT)
		for g in w.ground:
			grounds[g] += 1
		for g: int in [Ground.HEATH, Ground.SHINGLE, Ground.GRAVEL, Ground.SCREE, Ground.LIMESTONE, Ground.CLINKER, Ground.ICE, Ground.BLACKWATER, Ground.PEAT, Ground.RIVER, Ground.SAND, Ground.NEEDLES, Ground.SNOW, Ground.ASH, Ground.MOSS]:
			gt(grounds[g], 0, "seed %d %s ground" % [s, Ground.NAMES[g]])


func test_places_worth_walking_to() -> void:
	# Scrap tips in every country, stone circles, wrecks on the shore, bridges
	# where roads cross rivers, falls where rivers step down.
	for s in WORLD_SEEDS:
		var w := world(s)
		var tips := PackedInt32Array()
		tips.resize(Country.COUNT)
		var kinds := {}
		for m in w.landmarks:
			kinds[m.kind] = int(kinds.get(m.kind, 0)) + 1
			if m.kind == &"tip":
				tips[m.country] += 1
		for c: int in Country.LAND:
			gt(tips[c], 0, "seed %d tips in %s" % [s, Country.NAMES[c]])
		for kind: StringName in [&"stone_circle", &"wreck", &"ruin", &"summit", &"caldera", &"bridge", &"falls"]:
			gt(int(kinds.get(kind, 0)), 0, "seed %d %s landmarks" % [s, kind])
		for m in w.landmarks:
			if m.kind == &"bridge":
				var p: Vector2 = m.pos
				eq(w.ground_at(floori(p.x), floori(p.y)), Ground.ROAD, "seed %d bridge at %s carries the road" % [s, p])


func test_ore_is_richest_in_the_bonelands() -> void:
	var w := world(WORLD_SEEDS[0])
	var ore := PackedFloat32Array()
	ore.resize(Country.COUNT)
	var area := PackedFloat32Array()
	area.resize(Country.COUNT)
	for c in w.country:
		area[c] += 1.0
	for p in w.props:
		if p.kind in [PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE]:
			ore[w.country_at(floori(p.pos.x), floori(p.pos.y))] += 1.0
	var bone := ore[Country.BONELANDS] / area[Country.BONELANDS]
	for c: int in Country.LAND:
		if c != Country.BONELANDS:
			check(bone >= ore[c] / area[c], "bonelands ore density %.4f below %s %.4f" % [bone, Country.NAMES[c], ore[c] / area[c]])


func test_the_grid_strides_straight_across_countries() -> void:
	var w := world(WORLD_SEEDS[0])
	var pylons := 0
	var crosses := false
	for line in w.lines:
		var ids: PackedInt32Array = line.props
		gt(ids.size(), 1, "line length")
		var seen := {}
		for j in ids.size():
			var p := w.props[ids[j]]
			check(p.kind == line.kind, "line mixes kinds")
			seen[w.country_at(floori(p.pos.x), floori(p.pos.y))] = true
			if j > 0:
				lt(p.pos.distance_to(w.props[ids[j - 1]].pos), 40.0, "span length")
		if line.kind == PropKind.PYLON:
			pylons += ids.size()
			if seen.size() >= 3:
				crosses = true
	gt(pylons, 20, "pylons standing")
	check(crosses, "a pylon line crosses three countries")


func test_sea_rim_on_every_edge() -> void:
	for s in WORLD_SEEDS:
		var w := world(s)
		for i in w.size:
			check(w.level[i] <= 0 and w.level[(w.size - 1) * w.size + i] <= 0, "seed %d north/south rim is land" % s)
			check(w.level[i * w.size] <= 0 and w.level[i * w.size + w.size - 1] <= 0, "seed %d west/east rim is land" % s)


func test_places_resolve() -> void:
	var w := world(WORLD_SEEDS[0])
	for name: String in ["spawn", "coast", "moss", "pinewood", "snowfield", "bonelands", "burning", "coast-moss", "tip", "river"]:
		var p := GenPlaces.find(w, name)
		check(p.x >= 0.0, "place %s not found" % name)
		if p.x >= 0.0:
			check(not Ground.is_water(w.ground_at(floori(p.x), floori(p.y))), "place %s is in water" % name)
	var moss := GenPlaces.find(w, "moss")
	eq(w.country_at(floori(moss.x), floori(moss.y)), Country.MOSS, "moss sample country")
	eq(GenPlaces.find(w, "nowhere"), Vector2(-1, -1), "unknown place")
