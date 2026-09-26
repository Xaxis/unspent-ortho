extends TestCase
## THE FROZEN HOLD UNDER THE FROST SEA'S LEANING MAST
## (src/content/interiors/frozen_hold.gd): a refuge whose stove is out. Asked of
## every one seed 4 grows, of what a stove burns, and of the hold in a running
## game at night -- cold before the stove is lit, warm and a place to sleep
## after, and still lit when the player comes back.

const STEP := 0.2
const Sx := preload("res://tests/save/save_fixture.gd")

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


## EVERY MAST IN THE FROST SEA IS A TRAWLER WITH A HOLD, and no mast anywhere
## else opens: the landscape declares the host, not the landmark.
func test_every_frost_sea_mast_opens_on_a_frozen_hold() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var masts := 0
	var fs := BiomeRegistry.get_def(&"frost_sea").index
	for site: LandmarkSite in Landmarks.sites(w):
		if site.kind == &"leaning_mast" and w.country_at(floori(site.pos.x), floori(site.pos.y)) == fs:
			masts += 1
	gt(float(masts), 0.0, "seed 4 has masts in the frost sea")
	var holds := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"frozen_hold":
			holds += 1
			eq(t.land, fs, "%s: in the frost sea" % t.key)
			eq(InteriorGen.grow(4, t).layout.residents.size(), 0, "%s: nothing hunts in it" % t.key)
	eq(holds, masts, "one hold per mast")


## From the companionway a body gets to the stove, the table, the cable's panel,
## round the well without falling in it, into the fo'c'sle to the board and the
## sea chest.
func test_every_hold_can_be_walked_through() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"frozen_hold":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", _doors.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		var off := {&"stove": 0.9, &"cable_panel": 0.7, &"bunk_board": 0.7, &"strongbox": 0.8}
		for th: Dictionary in l.things:
			if off.has(th.kind):
				var goal := (th.at as Vector2) + (th.face as Vector2) * float(off[th.kind])
				check(_reached(reach, goal), "%s: the %s can be walked to" % [t.key, th.kind])
			if th.kind == &"sounding_well":
				var c := Vector2i(roundi((th.at as Vector2).x / STEP), roundi((th.at as Vector2).y / STEP))
				check(not reach.has(c), "%s: nobody walks into the well" % t.key)
		# Three are enough: every hold is laid to the one plan.
		if n >= 3:
			break
	gt(float(n), 0.0, "seed 4 has a hold to walk")


## WHAT A STOVE BURNS: what a campfire does, without its stones.
func test_a_stove_burns_what_a_campfire_does_without_the_stones() -> void:
	var inv := Inventory.new()
	eq((_doors.call(&"stove_fuel", inv) as Dictionary).size(), 0, "nothing carried, nothing to burn")
	inv.add(&"driftwood", 2)
	eq((_doors.call(&"stove_fuel", inv) as Dictionary).size(), 0, "two driftwood is not enough")
	inv.add(&"driftwood", 1)
	var f: Dictionary = _doors.call(&"stove_fuel", inv)
	eq(int(f.get(&"driftwood", 0)), 3, "three driftwood")
	check(not f.has(&"stone"), "and no stones: the stove is the stones")


## A REFUGE, in a running game at eleven at night: in the hold the cold bites,
## and nobody can sleep; fed three driftwood the stove is a fire, the cold is
## less than it was, and sleep is allowed; out and back in, it is still lit; and
## a save keeps it.
func test_the_stove_relit_makes_the_hold_a_refuge() -> void:
	Sx.use_root("frozen-hold")
	var g := Sx.game(tree, ["--seed=4", "--hour=23", "--weather=clear:0"])
	var d := Sx.system(g, "21_doors")
	var hz := Sx.system(g, "52_hazards")
	var p: Vector2 = d.call(&"tour_place", "door:frozen_hold")
	check(p != Vector2.INF, "seed 4 has a hold")
	g.player.hero.pos = p
	g.player.sync_view(0.0)
	var t: Threshold = null
	for h: Threshold in d.get("doors"):
		if h.kind == &"frozen_hold" and (t == null or h.door.distance_to(p) < t.door.distance_to(p)):
			t = h
	for i in 60:
		await tree.process_frame
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:frozen_hold")), "inside the hold")
	g.player.hero.pos = d.call(&"tour_place", "stove")
	g.player.sync_view(0.0)
	var cold_before := float(Hazards.felt(hz.call(&"place") as Hazards.Place).get(&"cold", 0.0))
	gt(cold_before, Hazards.FELT, "at the cold stove, the cold is felt (%.2f)" % cold_before)
	check(not bool(d.call(&"tour_seen", &"by_fire")), "no fire")
	# Awake since long enough, so only the fire decides.
	SurvivalState.of(g).woke_at = g.clock.minutes - 12.0 * 60.0
	eq(Survival.sleep_refusal(g), Condition.sleep_line(&"exposed"), "and no sleeping: no fire")
	g.inventory.add(&"driftwood", 3)
	d.call(&"_relight", 0)
	eq(g.inventory.count(&"driftwood"), 0, "it burned the three driftwood")
	check(bool(d.call(&"tour_seen", &"by_fire")), "the stove is a fire")
	var cold_after := float(Hazards.felt(hz.call(&"place") as Hazards.Place).get(&"cold", 0.0))
	lt(cold_after, cold_before - 0.3, "and the cold is less by it (%.2f -> %.2f)" % [cold_before, cold_after])
	eq(Survival.sleep_refusal(g), "", "a body can sleep by it")
	await d.call(&"go_out")
	for i in 10:
		await tree.process_frame
	await d.call(&"go_in", t)
	g.player.hero.pos = d.call(&"tour_place", "stove")
	g.player.sync_view(0.0)
	check(bool(d.call(&"tour_seen", &"by_fire")), "back in, it is still lit")
	var saved: Variant = d.call(&"_save")
	d.call(&"_load", {})
	check((d.get("_lit") as Dictionary).is_empty(), "a fresh load forgets it")
	d.call(&"_load", saved)
	check(not (d.get("_lit") as Dictionary).is_empty(), "the save keeps it")
	Sx.end(g)
