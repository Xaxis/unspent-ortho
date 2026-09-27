extends TestCase
## THE SAW HALL UNDER THE PINEWOOD'S WORKS (src/content/interiors/saw_hall.gd):
## a hall that keeps hours. On the shift the line runs lit and loud and the
## warden holds it; at the curfew the line is dark and quiet, the warden is
## gone, and the haulers sleep in their docks -- blind, but they hear. Asked of
## the room as seed 4 grows it, of a machine asleep in the fight's own senses,
## and of the hall in a running game by day and by night.

const STEP := 0.2
const F := preload("res://tests/fight/fixture.gd")
const Sx := preload("res://tests/save/save_fixture.gd")
const SawHall := preload("res://src/content/interiors/saw_hall.gd")

var _doors := load("res://src/systems/21_doors.gd") as GDScript


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


## EVERY PINEWOOD DEPOT OPENS ON A SAW HALL, one per works yard there.
func test_every_pinewood_depot_opens_on_a_saw_hall() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"saw_hall":
			n += 1
			eq(BiomeRegistry.by_index(t.land).id, &"pinewood", "%s: in the pinewood" % t.key)
	gt(float(n), 0.0, "seed 4 has a saw hall")


## THE QUIET WAY AT THE CURFEW: from the hatch a body gets to the kiln's box,
## the saw's panel and the plate over the docks; and the way along the middle of
## the hall to the kiln keeps further off every dock than a crouched step is
## heard (a hauler's `hears` times a crouched walk's loudness on the floor), so
## crouching past the sleepers is a way, and walking upright past them is not.
## And the kiln's box, lifted crouched, is out of their hearing; standing, not.
func test_the_hall_can_be_crossed_crouched_past_the_docks() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	var row := Roster.row(&"hauler")
	# How far a crouched walk on a hall's floor is heard, and a standing one.
	var crouched := float(row.hears) * StealthNoise.loudness(Tuning.WALK_SPEED, Ground.FLOOR, true, 0)
	var walked := float(row.hears) * StealthNoise.loudness(Tuning.WALK_SPEED, Ground.FLOOR, false, 0)
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"saw_hall":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", _doors.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		var sleepers: Array[Vector2] = []
		for r: Dictionary in l.residents:
			if r.get("docks", false):
				sleepers.append(r.at)
		eq(sleepers.size(), 3, "%s: three haulers dock here" % t.key)
		for th: Dictionary in l.things:
			var off := {&"strongbox": 0.8, &"saw_panel": 0.7, &"dock_plate": 0.9}
			if off.has(th.kind):
				var goal := (th.at as Vector2) + (th.face as Vector2) * float(off[th.kind])
				check(_reached(reach, goal), "%s: the %s can be walked to" % [t.key, th.kind])
		var walk: PackedVector2Array = l.walks[0]
		var from := walk[0]
		for i in range(1, walk.size()):
			var to := walk[i]
			var steps := ceili(from.distance_to(to) / STEP)
			for k in steps:
				var at := from.lerp(to, float(k + 1) / float(steps))
				check(_reached(reach, at), "%s: the way is open at %s" % [t.key, at])
				for s: Vector2 in sleepers:
					check(Senses.chebyshev(at, s) > crouched,
						"%s: crouched at %s is not heard from the dock at %s" % [t.key, at, s])
			from = to
		# The take: lifting the kiln's boards is a `work` noise, crouched out of
		# the docks' hearing, standing not (StealthQuery.hears_noise).
		var m := Moment.new()
		for th: Dictionary in l.things:
			if th.kind != &"strongbox":
				continue
			var at := (th.at as Vector2) + (th.face as Vector2) * 0.8
			var ground := p.world.ground_at(floori(at.x), floori(at.y))
			var heard_low := false
			var heard_up := false
			for sl: Vector2 in sleepers:
				heard_low = heard_low or StealthQuery.hears_noise(row, sl, at, StealthNoise.radius(&"work", ground, true), m)
				heard_up = heard_up or StealthQuery.hears_noise(row, sl, at, StealthNoise.radius(&"work", ground, false), m)
			check(not heard_low, "%s: the kiln's box lifted crouched is not heard in the docks" % t.key)
			check(heard_up, "%s: lifted standing, it is" % t.key)
		var mid := walk[1].lerp(walk[2], 0.5)
		var near_any := false
		for s: Vector2 in sleepers:
			near_any = near_any or Senses.chebyshev(mid, s) <= walked
		check(near_any, "%s: upright on the same way, the docks hear it" % t.key)
	gt(float(n), 0.0, "seed 4 has a saw hall to walk")


## IT KEEPS HOURS: at work from five to eight at night, the curfew after.
func test_the_hall_works_its_shift_and_keeps_the_curfew() -> void:
	var k := Interiors.kind(&"saw_hall") as InteriorKind
	check(k.working(5.0), "at five the line starts")
	check(k.working(12.0), "at noon it runs")
	check(not k.working(20.0), "at eight the curfew")
	check(not k.working(23.5), "and all night")
	check(not k.working(4.9), "until five")
	check((Interiors.kind(&"foundry") as InteriorKind).working(3.0), "a room with no shift never stops")
	var l := SawHall.lay(Rng.make(4, 0x5A3))
	var lit := Vector2(SawHall.SAW_AT.x, SawHall.SAW_AT.y + 1.0)
	lt(float(_doors.call(&"dark_at", k, l, lit, true)), k.dark * 0.5, "on the shift, by the saw, a body is lit")
	near(float(_doors.call(&"dark_at", k, l, lit, false)), k.dark, 0.001, "at the curfew the saw is dark as the rest")


## ASLEEP, A MACHINE SEES NOTHING AND HEARS: stood in plain sight in front of a
## hauler three tiles off and holding still, a body wakes nothing; the same body
## a tile and a half off, close enough to be heard breathing, wakes it in a few
## seconds.
func test_a_machine_asleep_hears_but_does_not_see() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	sim.moment.loudness = StealthNoise.STILL
	var awake := F.still(sim, &"hauler", Vector2(23.5, 20.5), PI)
	awake.calm_until = 0.0
	F.ms(sim, 600)
	check(awake.suspicion >= 1.0, "awake, it has them at once in plain sight")
	var sim2 := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	sim2.moment.loudness = StealthNoise.STILL
	var sleeper := F.still(sim2, &"hauler", Vector2(23.5, 20.5), PI)
	sleeper.calm_until = 0.0
	sleeper.asleep = true
	F.ms(sim2, 3000)
	lt(sleeper.suspicion, 0.05, "asleep, three tiles off in plain sight and still, nothing")
	check(sleeper.asleep, "and it sleeps on")
	sim2.hero.pos = Vector2(22.0, 20.5)
	F.ms(sim2, 8000)
	check(not sleeper.asleep, "a tile and a half off, it hears them and wakes")


func _game(hour: String, key: String) -> Array:
	Sx.use_root(key)
	var g := Sx.game(tree, ["--seed=4", "--hour=" + hour, "--weather=clear:0"])
	var d := Sx.system(g, "21_doors")
	var p: Vector2 = d.call(&"tour_place", "door:saw_hall")
	check(p != Vector2.INF, "seed 4 has a saw hall door")
	g.player.hero.pos = p
	g.player.sync_view(0.0)
	var t: Threshold = null
	for h: Threshold in d.get("doors"):
		if h.kind == &"saw_hall" and (t == null or h.door.distance_to(p) < t.door.distance_to(p)):
			t = h
	for i in 60:
		await tree.process_frame
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:saw_hall")), "inside the saw hall")
	return [g, d]


func _kinds(d: Node) -> Dictionary:
	var out := {}
	for pair: Array in d.get("_residents"):
		var m: MobState = pair[1]
		var k := "%s%s" % [m.kind, " asleep" if m.asleep else ""]
		out[k] = int(out.get(k, 0)) + 1
	return out


## ON THE SHIFT, in a running game at noon: the warden at the saw and a hauler
## at the stacks, awake; nobody docked; the saw's howl over a step; the box shut.
func test_on_the_shift_the_warden_holds_a_loud_hall() -> void:
	var gd: Array = await _game("12", "saw-hall-day")
	var g: Game = gd[0]
	var d: Node = gd[1]
	var who := _kinds(d)
	eq(int(who.get("warden", 0)), 1, "the warden stands its shift (%s)" % who)
	eq(int(who.get("hauler", 0)), 1, "one hauler at the stacks")
	check(not bool(d.call(&"tour_seen", &"asleep")), "nobody sleeps on the shift")
	near(float(d.call(&"room_hush")), (Interiors.kind(&"saw_hall") as InteriorKind).hush, 0.001, "the saw howls")
	var before := g.inventory.count(&"seasoned_timber")
	d.call(&"_open_box", 0)
	eq(g.inventory.count(&"seasoned_timber"), before, "while the warden stands, the kiln's box stays shut")
	Sx.end(g)


## AT THE CURFEW, in a running game at eleven at night: no warden, three
## haulers asleep in the docks, the hall silent and dark, and the kiln's box
## open: 6 to 10 seasoned timber. When the shift comes round, the sleepers wake.
func test_at_the_curfew_the_haulers_sleep_and_the_kiln_is_open() -> void:
	var gd: Array = await _game("23", "saw-hall-night")
	var g: Game = gd[0]
	var d: Node = gd[1]
	var who := _kinds(d)
	eq(int(who.get("warden", 0)), 0, "the warden is out walking the wood (%s)" % who)
	eq(int(who.get("hauler", 0)), 0, "nobody awake")
	eq(int(who.get("hauler asleep", 0)), 3, "three haulers asleep in the docks")
	check(bool(d.call(&"tour_seen", &"unwoken")), "none has woken")
	eq(float(d.call(&"room_hush")), 0.0, "the saw is still")
	var l := (d.get("pocket") as InteriorGen.Pocket).layout
	var k := Interiors.kind(&"saw_hall") as InteriorKind
	near(float(d.call(&"room_dark", l.hearth + Vector2(0.0, 1.0))), k.dark, 0.001, "and dark by it")
	var before := g.inventory.count(&"seasoned_timber")
	d.call(&"_open_box", 0)
	var got := g.inventory.count(&"seasoned_timber") - before
	check(got >= 6 and got <= 10, "the kiln's box gives 6 to 10 seasoned timber (%d)" % got)
	g.clock.skip(6.5 * 60.0)
	for i in 4:
		await tree.process_frame
	check(not bool(d.call(&"tour_seen", &"asleep")), "at the shift the sleepers wake")
	Sx.end(g)
