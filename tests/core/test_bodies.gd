extends TestCase
## The bodies a world is made of, and the void between them (docs/DESIGN.md).
## Today one island gives one body; this holds the recording honest so that the
## day the planning half inverts the stage, what broke is obvious.

const SEEDS: Array[int] = [1, 42, 90210]


func test_every_land_tile_is_on_a_body_and_no_sea_tile_is() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 256)
		eq(w.continent.size(), w.level.size(), "seed %d: a body id per tile" % s)
		var land := 0
		var stray := 0
		for i in w.level.size():
			var on_land := w.level[i] > 0
			var id := w.continent[i]
			if on_land:
				land += 1
				if id == GenBodies.VOID:
					stray += 1
			elif id != GenBodies.VOID:
				stray += 1
		gt(float(land), 1000.0, "seed %d: there is land to be on" % s)
		eq(stray, 0, "seed %d: land is on a body and the sea is the void" % s)


func test_the_bodies_describe_themselves() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 256)
		check(not w.continents.is_empty(), "seed %d: a world is made of something" % s)
		var counted := {}
		for i in w.continent.size():
			var id := w.continent[i]
			if id != GenBodies.VOID:
				counted[id] = int(counted.get(id, 0)) + 1
		var last := 1 << 30
		for b: Dictionary in w.continents:
			var id := int(b.id)
			eq(int(b.tiles), int(counted.get(id, -1)), "seed %d body %d: says how big it is" % [s, id])
			check(int(b.tiles) <= last, "seed %d: biggest first" % s)
			last = int(b.tiles)
			var r: Rect2 = b.bounds
			check(r.has_point(b.centre as Vector2), "seed %d body %d: its middle is inside it" % [s, id])
		eq(w.continents.size(), counted.size(), "seed %d: every body on the ground is described" % s)


## ONE WRITER, and a test that fails when a second appears — the discipline
## docs/DESIGN.md asks for, because a rule that is only in a header is a rule
## until the first hurry. `tests/render/test_one_writer.gd` does this for the sky
## globals and caught a real bypass by somebody who knew the rule.
func test_gen_bodies_is_the_only_thing_that_writes_a_body_id() -> void:
	var writers := PackedStringArray()
	var dir := DirAccess.open("res://src/")
	check(dir != null, "src/ exists")
	_walk("res://src", writers)
	for f: String in writers:
		# Reads count too, on purpose: an index read is how a write starts, and
		# the accessor is the idiom everything else already uses. The message
		# said "writes" of two plain reads once and sent someone hunting for a
		# write that did not exist.
		check(f.ends_with("gen_bodies.gd") or f.ends_with("world_data.gd"),
			"%s reads or writes WorldData.continent directly; use continent_at (GenBodies is its one writer)" % f)


static func _walk(path: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_walk(path.path_join(sub), out)
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var whole := path.path_join(f)
		var text := FileAccess.get_file_as_string(whole)
		if text.is_empty():
			continue
		for line: String in text.split("\n"):
			var t := line.strip_edges()
			if t.begins_with("#"):
				continue
			if t.contains(".continent =") or t.contains(".continent[") or t.contains(".continents ="):
				out.append(whole)
				break


## The planning half: pure, cheap, and not yet wired into generation.
func test_a_plan_is_the_same_plan_every_time() -> void:
	for s: int in SEEDS:
		var a := GenBodies.plan(s)
		var b := GenBodies.plan(s)
		eq(a.size, b.size, "seed %d: the same square" % s)
		eq((a.bodies as Array).size(), (b.bodies as Array).size(), "seed %d: the same count" % s)
		for i in (a.bodies as Array).size():
			eq(str(a.bodies[i]), str(b.bodies[i]), "seed %d body %d is dealt the same" % [s, i])


func test_a_realm_says_how_many_bodies_it_has() -> void:
	for realm: StringName in [Realm.SURFACE, Realm.ORBITAL]:
		var least: int = (GenBodies.COUNT[realm] as Vector2i).x
		var most: int = (GenBodies.COUNT[realm] as Vector2i).y
		for s: int in SEEDS:
			var p := GenBodies.plan(s, realm)
			var n: int = (p.bodies as Array).size()
			check(n >= least and n <= most, "%s seed %d: %d bodies, wanted %d..%d" % [realm, s, n, least, most])
			gt(float(p.size), 63.0, "%s seed %d: a square to hold them" % [realm, s])
			var home := 0
			for b: Dictionary in p.bodies:
				if bool(b.home):
					home += 1
			eq(home, 1, "%s seed %d: exactly one body is woken on" % [realm, s])


## THE LINE THAT KEEPS THE REPOSITORY WORKING. Every --size=64 and --size=256 in
## the tests and tours has to go on meaning what it meant, and one body is exactly
## the island this game has always had.
func test_a_small_world_is_one_body_as_it_always_was() -> void:
	for s: int in SEEDS:
		for want: int in [64, 128, 256]:
			var p := GenBodies.plan(s, Realm.SURFACE, want)
			eq((p.bodies as Array).size(), 1, "seed %d at %d: one island" % [s, want])
			eq(p.size, want, "seed %d: the size that was asked for" % s)
		# And a square big enough is allowed more than one.
		var big := GenBodies.plan(s, Realm.SURFACE, 2048)
		gt(float((big.bodies as Array).size()), 1.0, "seed %d: room for continents" % s)


## A shaft has to come up where it went down, so the underground is the surface's
## map. The rule lives in `plan`, not in the caller: asking for the underground
## returns the surface's footprints (docs/DESIGN.md).
func test_the_underground_is_the_surface_seen_from_below() -> void:
	for s: int in SEEDS:
		var up := GenBodies.plan(s, Realm.SURFACE)
		var down := GenBodies.plan(s, Realm.UNDERGROUND)
		eq(down.size, up.size, "seed %d: the same square" % s)
		eq((down.bodies as Array).size(), (up.bodies as Array).size(), "seed %d: the same bodies" % s)
		for i in (up.bodies as Array).size():
			eq(str(down.bodies[i].at), str(up.bodies[i].at), "seed %d body %d stands in the same place" % [s, i])


## Two bodies at one latitude are the same place unless they are dealt different
## weather, which is the whole of why the band exists (docs/DESIGN.md).
func test_every_body_is_dealt_a_climate_band() -> void:
	var seen := {}
	for s: int in SEEDS:
		for b: Dictionary in GenBodies.plan(s, Realm.SURFACE, 2048).bodies:
			var band: Vector2 = b.band
			check(absf(band.x) <= GenBodies.BAND + 1e-5 and absf(band.y) <= GenBodies.BAND + 1e-5,
				"seed %d body %d: a band inside its spread" % [s, int(b.id)])
			seen["%.4f,%.4f" % [band.x, band.y]] = true
	gt(float(seen.size()), 2.0, "the bands are not all the same deal")


## A SMALL SQUARE IS STILL ONE ISLAND, CENTRED, EXACTLY AS IT ALWAYS WAS.
##
## This used to include `Tuning.WORLD_SIZE` and read "the stage is a no-op on
## every world this project generates today" — true while the game was played on
## one island, and a lie the moment the owner asked for five continents. The
## promise it was protecting is still worth keeping and is now the OTHER half: a
## 64-tile test fixture is not a small world with five continents in it. Flooring
## the count at the realm's least instead of at one put five continents on a
## 64-tile square and took thirty tests down, every one of them a true statement
## about a world nobody meant to make.
func test_a_small_square_is_still_one_island() -> void:
	for s: int in SEEDS:
		for want: int in [64, 128, 256, 512]:
			var p := GenBodies.plan(s, Realm.SURFACE, want)
			eq((p.bodies as Array).size(), 1, "seed %d at %d: one island" % [s, want])
			var at: Vector2 = (p.bodies as Array)[0].at
			check(at.is_equal_approx(Vector2(0.5, 0.5)), "seed %d at %d: centred" % [s, want])
			near(float((p.bodies as Array)[0].share), 1.0, 1e-6, "seed %d at %d: the whole share" % [s, want])


## AND THE SIZE A GAME IS PLAYED AT IS FIVE CONTINENTS, each a whole island.
## `Tuning.WORLD_SIZE` is 1300 because that is what five bodies of a full island's
## share need (`GenBodies._square_for`), and "at least five" is the shape of the
## journey: `StoryPlan.SPINE` crosses them in order and has carried a `leg` per
## slot since before this stage could lay them.
func test_the_size_a_game_is_played_at_is_five_continents() -> void:
	for s: int in SEEDS:
		var p := GenBodies.plan(s, Realm.SURFACE, Tuning.WORLD_SIZE)
		var bodies: Array = p.bodies
		gt(float(bodies.size()), 4.0, "seed %d: at least five continents" % s)
		for b: Dictionary in bodies:
			# Each is a whole island's worth, not a share of one: a body's share of
			# this square times this square is about a 512 island's tiles.
			var tiles := float(b.share) * float(Tuning.WORLD_SIZE) * float(Tuning.WORLD_SIZE)
			near(tiles / (512.0 * 512.0), 1.0, 0.25,
				"seed %d: a continent is an island's worth of land" % s)


## And when the square IS big enough, the bodies are really separate land, not one
## mass with arms. Both of those were real failures on the way here: the headlands
## bridged the straits, and `GenShape._clean` drowned every mass but the largest.
func test_a_big_square_holds_separate_continents() -> void:
	# ASKED OF THE PLAN, NOT PINNED AT FOUR. The count a square holds is what fits
	# in it at FULL island size (`GenBodies._square_for`), so 1024 held four while
	# a body was a fifth of an island and holds three now that it is a whole one.
	# Pinning the number made this a test of a constant; what it is for is that
	# every body the plan laid came out as a landmass of its own.
	var w := WorldGen.generate(1, 1024)
	var want: int = (GenBodies.plan(1, Realm.SURFACE, 1024).bodies as Array).size()
	gt(float(want), 1.0, "1024 is big enough for more than one")
	var big := 0
	for b: Dictionary in w.continents:
		if int(b.tiles) > 20000:
			big += 1
	eq(big, want, "every one of the %d planned is a landmass of its own" % want)
	for b: Dictionary in w.continents:
		if int(b.tiles) > 20000:
			gt(float(b.tiles), 50000.0, "continent %d is a place, not a spit" % int(b.id))


## The door callers ask through, rather than indexing the array themselves.
func test_a_world_says_which_body_a_place_is_on() -> void:
	var w := WorldGen.generate(1, 256)
	eq(w.continent_at(-1, 0), GenBodies.VOID, "off the map is the void")
	eq(w.continent_at(w.size, 0), GenBodies.VOID, "and so is past the far edge")
	# The spawn is on land, so it is on a body, and it shares that body with itself.
	var sp := w.spawn
	gt(float(w.continent_at(floori(sp.x), floori(sp.y))), 0.0, "the player wakes on a body")
	check(w.same_body(sp, sp), "a place is on the same body as itself")
	# Open sea is nobody's: the void is not a place two things can share.
	var sea := Vector2.ZERO
	check(not w.same_body(sp, sea), "the spawn does not share a landmass with the open sea")
	check(not w.same_body(sea, sea), "and two points in the void share nothing")


## On one island everything walkable shares a body; the question only gets
## interesting when there is water in the middle.
func test_two_places_on_one_island_share_it_and_on_four_they_may_not() -> void:
	var one := WorldGen.generate(1, 256)
	var a := one.spawn
	var b := Vector2.ZERO
	for r: Dictionary in one.regions:
		b = r.centre
		break
	check(one.same_body(a, b), "one island: the spawn and a region are the same land")
	var many := WorldGen.generate(1, 1024)
	var apart := 0
	var seen: Array[Vector2] = []
	for r: Dictionary in many.regions:
		seen.append(r.centre)
	for i in mini(seen.size(), 12):
		if not many.same_body(seen[0], seen[i]):
			apart += 1
	gt(float(apart), 0.0, "four continents: some regions are across water from each other")


## Which landscapes a continent was dealt, recorded on the world so nothing has to
## infer it. One body takes every type, which is what a world has always done.
func test_a_body_is_dealt_the_landscapes_it_may_carry() -> void:
	var one := WorldGen.generate(1, 256)
	var types: PackedInt32Array = one.continents[0].get("types", PackedInt32Array())
	gt(float(types.size()), 4.0, "one island carries every landscape the world has")
	var many := WorldGen.generate(1, 1024)
	var dealt := 0
	for b: Dictionary in many.continents:
		if not b.has("types"):
			continue
		dealt += 1
		gt(float((b.get("types") as PackedInt32Array).size()), 0.0,
			"continent %d is not left barren" % int(b.id))
	eq(dealt, (GenBodies.plan(1, Realm.SURFACE, 1024).bodies as Array).size(),
		"every planned continent was dealt, and the skerries were left alone")


## EXCLUSIVITY, PROVED RATHER THAN DECLARED. A landscape that naturally spans
## every continent is confined to one by `spread`, which is the whole point of
## the field and the thing the owner asked for.
func test_spread_confines_a_landscape_to_one_continent() -> void:
	var d := BiomeRegistry.get_def(&"snowfield")
	if d == null:
		return
	var was := d.spread
	# **NOTHING CONFINING IT HAS TO BE SAID, NOT LEFT UNSAID.** This arm used to
	# measure the snowfield's DECLARED spread, which is the default `(0, 0)` — and
	# the default is not "everywhere", it is `GenBodies.MOST_BODIES`, about half
	# the continents. At this world's continent count half rounds to ONE, so the
	# control arm and the confined arm were measuring the same thing and the test
	# could never fail for the reason it names. It failed for a different one:
	# the world grew, the count changed, and 1 stopped being greater than 1.
	var planned: int = (GenBodies.plan(1, Realm.SURFACE, 1024).bodies as Array).size()
	d.spread = Vector2i(0, planned)
	var wide := _continents_holding(&"snowfield", 1, 1024)
	d.spread = Vector2i(0, 1)
	var narrow := _continents_holding(&"snowfield", 1, 1024)
	d.spread = was
	gt(float(planned), 1.0, "this world plans more than one continent, or the test proves nothing")
	gt(float(wide), 1.0, "the snowfield spans several continents when nothing confines it")
	eq(narrow, 1, "and exactly one when spread says at most one")


## CONTINENTS AS `GenBodies` DEFINES THEM, NOT BY A NUMBER OF THIS TEST'S OWN.
## A continent is a mass at least `GenBodies.CONTINENT_SHARE` of the biggest one;
## anything smaller is a skerry. This counted any mass holding 400 tiles of the
## landscape, which never read that declaration, and seed 1 at 1024 has a
## 676-tile skerry -- 0.5% of the biggest body -- that it then called a second
## continent once the deal was enforced (abd628f).
##
## THE CONSEQUENCE, WRITTEN DOWN SO NOBODY REDISCOVERS IT: the deal governs the
## planned continents and a skerry is open to every type (`_dealt_here`), so a
## `(0, 1)` landscape -- "the rare thing you cross an ocean for" -- may also
## stand on a skerry near some other continent. That skerry's 676 tiles were
## snowfield. It is deliberate and small; if the owner wants a skerry to take its
## nearest continent's deal, that is a world change with its own GEN bump.
static func _continents_holding(id: StringName, seed_value: int, size: int) -> int:
	var w := WorldGen.generate(seed_value, size)
	var most := 0
	for row: Dictionary in w.continents:
		most = maxi(most, int(row.get("tiles", 0)))
	var continent := {}
	for row: Dictionary in w.continents:
		if float(row.get("tiles", 0)) >= GenBodies.CONTINENT_SHARE * float(most):
			continent[int(row.get("id", 0))] = true
	var per := {}
	for i in w.country.size():
		if BiomeRegistry.name_of(w.country[i]) != String(id):
			continue
		var b := w.continent_at(i % w.size, i / w.size)
		if continent.has(b):
			per[b] = int(per.get(b, 0)) + 1
	var n := 0
	for b: int in per:
		if int(per[b]) > 400:
			n += 1
	return n
