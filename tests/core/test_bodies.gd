extends TestCase
## The bodies a world is made of, and the void between them (docs/WORLD.md).
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
## docs/WORLD.md §3 asks for, because a rule that is only in a header is a rule
## until the first hurry. `tests/render/test_one_writer.gd` does this for the sky
## globals and caught a real bypass by somebody who knew the rule.
func test_gen_bodies_is_the_only_thing_that_writes_a_body_id() -> void:
	var writers := PackedStringArray()
	var dir := DirAccess.open("res://src/")
	check(dir != null, "src/ exists")
	_walk("res://src", writers)
	for f: String in writers:
		check(f.ends_with("gen_bodies.gd") or f.ends_with("world_data.gd"),
			"%s writes WorldData.continent; GenBodies is its one writer" % f)


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
## returns the surface's footprints (docs/WORLD.md §5).
func test_the_underground_is_the_surface_seen_from_below() -> void:
	for s: int in SEEDS:
		var up := GenBodies.plan(s, Realm.SURFACE)
		var down := GenBodies.plan(s, Realm.UNDERGROUND)
		eq(down.size, up.size, "seed %d: the same square" % s)
		eq((down.bodies as Array).size(), (up.bodies as Array).size(), "seed %d: the same bodies" % s)
		for i in (up.bodies as Array).size():
			eq(str(down.bodies[i].at), str(up.bodies[i].at), "seed %d body %d stands in the same place" % [s, i])


## Two bodies at one latitude are the same place unless they are dealt different
## weather, which is the whole of why the band exists (docs/WORLD.md §4a).
func test_every_body_is_dealt_a_climate_band() -> void:
	var seen := {}
	for s: int in SEEDS:
		for b: Dictionary in GenBodies.plan(s, Realm.SURFACE, 2048).bodies:
			var band: Vector2 = b.band
			check(absf(band.x) <= GenBodies.BAND + 1e-5 and absf(band.y) <= GenBodies.BAND + 1e-5,
				"seed %d body %d: a band inside its spread" % [s, int(b.id)])
			seen["%.4f,%.4f" % [band.x, band.y]] = true
	gt(float(seen.size()), 2.0, "the bands are not all the same deal")
