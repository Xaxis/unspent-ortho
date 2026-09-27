extends TestCase
## THE DATA HALL UNDER THE SERVER FIELDS' SUMP (src/content/interiors/data_hall.gd):
## where the machines think. Asked of every one the world grows on seed 4, with
## the real query and the room's real blocks (21_doors._walls), the sentries'
## real lines (21_doors.screened), and the real loot.

const STEP := 0.2

var _doors := load("res://src/systems/21_doors.gd") as GDScript


func _halls(w: WorldData) -> Array[Threshold]:
	var out: Array[Threshold] = []
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"data_hall":
			out.append(t)
	return out


func _reach(q: WorldQuery, from: Vector2) -> Dictionary:
	var seen := {Vector2i(roundi(from.x / STEP), roundi(from.y / STEP)): true}
	var todo: Array[Vector2i] = [seen.keys()[0]]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n):
				continue
			var a := Vector2(c) * STEP
			var b := Vector2(n) * STEP
			if q.move_body(a, b - a, Tuning.PLAYER_RADIUS).distance_to(b) < 0.02:
				seen[n] = true
				todo.append(n)
	return seen


func _reached(reach: Dictionary, at: Vector2) -> bool:
	var c := Vector2i(roundi(at.x / STEP), roundi(at.y / STEP))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if reach.has(c + Vector2i(dx, dy)):
				return true
	return false


func _things(l: InteriorLayout, kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in l.things:
		if t.kind == kind:
			out.append(t)
	return out


## Where a body stands in the lee of each rack's south end, on the cross-aisle,
## and where it stands in each aisle's mouth, between two rows.
func _lee_and_mouths(l: InteriorLayout) -> Array:
	var rows := _things(l, &"rack_row")
	var lee: Array[Vector2] = []
	var mouths: Array[Vector2] = []
	for r: Dictionary in rows:
		var f: Vector2 = r.face
		var along := Vector2(-f.y, f.x)
		# The south end: the end of the row nearer the way in.
		var a := (r.at as Vector2) + along * float(r.long) * 0.5
		var b := (r.at as Vector2) - along * float(r.long) * 0.5
		var south := a if a.distance_to(l.door) < b.distance_to(l.door) else b
		var out := (south - (r.at as Vector2)).normalized()
		lee.append(south + out * 1.0)
	for i in rows.size() - 1:
		var m := ((lee[i] as Vector2) + (lee[i + 1] as Vector2)) * 0.5
		mouths.append(m)
	return [lee, mouths]


## THE HATCH STANDS ON DRY GROUND BY THE SUMP. Every sump of the server fields
## on seed 4 keeps a data hall, and its door and the step out of it are ground a
## body stands on, clear of the sump's own mass.
func test_every_server_fields_sump_keeps_a_hall_on_dry_ground() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var q := WorldQuery.new(w)
	var sumps: Array[LandmarkSite] = []
	for site: LandmarkSite in Landmarks.sites(w):
		var d := BiomeRegistry.by_index(w.country_at(floori(site.pos.x), floori(site.pos.y)))
		if site.kind == &"sump_pump" and d != null and d.interiors.has(&"landmark:sump_pump"):
			sumps.append(site)
	gt(float(sumps.size()), 0.0, "seed 4 has a sump in the server fields")
	var halls := _halls(w)
	eq(halls.size(), sumps.size(), "one hall door per sump")
	var exit_out := float(_doors.get_script_constant_map()["EXIT_OUT"])
	for site: LandmarkSite in sumps:
		var t: Threshold = null
		for h: Threshold in halls:
			if h.host.distance_to(site.pos) < Threshold.IN_RING + 0.1:
				t = h
		check(t != null, "the sump at %s has its hall" % site.pos)
		if t == null:
			continue
		for p: Vector2 in [t.door, t.door + t.out * exit_out]:
			check(q.standable(floori(p.x), floori(p.y)), "%s: %s is ground a body stands on" % [t.key, p])
			for c: Vector3 in LandmarkModels.blocks(&"sump_pump"):
				var at := site.pos + Vector2(c.x, c.y).rotated(site.facing)
				check(p.distance_to(at) > c.z + Tuning.PLAYER_RADIUS, "%s: %s is clear of the sump at %s" % [t.key, p, at])


## BOTH WAYS GO. From the hatch a body gets along the south cross-aisle in each
## rack's lee, into the tape room to its box and its shelf of paper, and up an
## aisle to the console and the watcher's post.
func test_every_data_hall_can_be_walked_through() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in _halls(w):
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", _doors.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		var box: Dictionary = _things(l, &"strongbox")[0]
		var ledger: Dictionary = _things(l, &"paper_log")[0]
		var console: Dictionary = _things(l, &"console")[0]
		check(_reached(reach, (box.at as Vector2) + (box.face as Vector2) * 0.8), "the tape room's box")
		check(_reached(reach, (ledger.at as Vector2) + (ledger.face as Vector2) * 0.7), "the paper on its shelf")
		check(_reached(reach, (console.at as Vector2) + (console.face as Vector2) * 0.8), "the console at the head")
		for at: Vector2 in _lee_and_mouths(l)[0]:
			check(_reached(reach, at), "in a rack's lee at %s" % at)
	gt(float(n), 0.0, "seed 4 has a data hall to walk")


## THE AISLES ARE SIGHTLINES AND NOTHING ELSE: from each sentry on the head
## wall, a body in a rack's lee on the cross-aisle is behind the rack; in an
## aisle's mouth, it is down the aisle, in the open.
func test_the_racks_leave_the_aisles_and_hide_their_lee() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	for t: Threshold in _halls(w):
		var l := InteriorGen.grow(4, t).layout
		var pts: Array = _lee_and_mouths(l)
		var sentries := _things(l, &"turret")
		eq(sentries.size(), 3, "a sentry at the head of each aisle")
		for s: Dictionary in sentries:
			# The lee of the rows between the ends: the outer rows' lee is open to
			# a sentry across the hall, round the hall's own corner.
			for i in range(1, (pts[0] as Array).size() - 1):
				var at: Vector2 = pts[0][i]
				check(bool(_doors.call(&"screened", l, s.at, at)), "the sentry at %s does not see %s in a rack's lee" % [s.at, at])
		var open := 0
		for m: Vector2 in pts[1]:
			for s: Dictionary in sentries:
				if not bool(_doors.call(&"screened", l, s.at, m)):
					open += 1
					break
		eq(open, (pts[1] as Array).size(), "every aisle's mouth is down some sentry's line")


## THE TAPE ROOM KEEPS THE MACHINES' OWN FILES, every box, and a damper in some.
func test_the_tape_room_keeps_records_and_sometimes_a_damper() -> void:
	Interiors.declare_loot(true)
	var damps := 0
	for instance in 40:
		var got := {}
		for row: Dictionary in Drops.roll(Interiors.loot_source(&"data_hall"), 4, instance, &"server_fields"):
			got[row.item] = int(row.count)
		check(int(got.get(&"record", 0)) >= 2, "box %d: the machines' records (%s)" % [instance, got])
		if got.has(&"mod_damp"):
			damps += 1
	gt(float(damps), 0.0, "a damper in some box")
	lt(float(damps), 40.0, "and not in every one")


## THE HUM COVERS A STEP, in a running game: walking in the data hall, the
## player is only (1 - hush) as loud as the same walk anywhere else
## (32_disposition, through 21_doors `room_hush`); and on the cross-aisle, the
## watcher at the head, which hears a walk that far off, does not hear it here.
func test_the_hum_covers_a_walk_in_a_running_game() -> void:
	const Sx := preload("res://tests/save/save_fixture.gd")
	Sx.use_root("data-hall-hum")
	var g := Sx.game(tree, ["--seed=4", "--hour=15", "--weather=clear:0"])
	var d := Sx.system(g, "21_doors")
	var p: Vector2 = d.call(&"tour_place", "door:data_hall")
	check(p != Vector2.INF, "seed 4 has a data hall door")
	g.player.hero.pos = p
	g.player.sync_view(0.0)
	var t: Threshold = null
	for h: Threshold in d.get("doors"):
		if h.kind == &"data_hall" and (t == null or h.door.distance_to(p) < t.door.distance_to(p)):
			t = h
	for i in 60:
		await tree.process_frame
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:data_hall")), "inside the data hall")
	var hush := (Interiors.kind(&"data_hall") as InteriorKind).hush
	gt(hush, 0.0, "the hall hums")
	g.scripted_move = Vector2(1, 0)
	g.scripted_run = false
	g.scripted_seconds = 0.5
	for i in 12:
		await tree.physics_frame
	var sim: FightSim = g.player.sim
	var hero := sim.hero
	var ground := g.world.ground_at(floori(hero.pos.x), floori(hero.pos.y))
	var walk := StealthNoise.loudness(hero.speed, ground, g.body.crouched, sim.moment.laden_tier)
	gt(walk, 0.0, "the player is walking")
	near(sim.moment.loudness, walk * (1.0 - hush), 0.02, "a walk in here is (1 - hush) as loud as anywhere else")
	# The watcher at the head, and a place on the cross-aisle.
	var l := (d.get("pocket") as InteriorGen.Pocket).layout
	var post: Vector2 = l.residents[0].at
	var across: Vector2 = _lee_and_mouths(l)[1][1]
	var row := Roster.row(&"warden")
	# Asked of a full walk (StealthNoise's own unit), not of the steps just
	# taken, which were still coming up to speed.
	var loud := Moment.new()
	loud.loudness = 1.0
	var hushed := Moment.new()
	hushed.loudness = 1.0 - hush
	check(StealthQuery.hears(row, post, across, loud), "a walk would be heard from the head at %s" % across)
	check(not StealthQuery.hears(row, post, across, hushed), "under the hum it is not")
	Sx.end(g)
