extends TestCase
## THE ANCHOR (GEAR.md G4): the mesas anchor's core on the jig, worn on the
## body. Stood still ANCHOR_MS, the player is rooted: a blow does not throw them
## and a grip does not take hold (a lineman's fails). Its cost: rooted, they
## cannot dodge; any step lifts the root.

const F := preload("res://tests/fight/fixture.gd")
const G := preload("res://tests/fight/test_crowd_reader.gd")


func test_the_anchors_core_becomes_the_anchor_on_the_jig() -> void:
	check(Gear.is_module(&"mod_anchor"), "the anchor is a module")
	eq(Items.def(&"mod_anchor").get("fits", []), [&"body"], "worn on the body")
	eq(GearTree.row(&"mod_anchor").get("grade", &""), &"relic", "a keeper's power is a relic")
	eq(GearTree.made_of(&"mod_anchor"), &"anchor_core", "made of the anchor's core")
	check(ModifierTable.costs(&"mod_anchor") != "", "it says what it costs")
	check(FightKit.of([&"mod_anchor"]).anchor, "the kit reads it")
	eq(UiRules.core_uses(&"anchor_core").size(), 2, "the anchor's core reads as a choice")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


func test_stood_still_it_roots_and_a_step_lifts_it() -> void:
	var sim := F.make_sim()
	sim.hero.kit = FightKit.of([&"mod_anchor"])
	F.ms(sim, FightKit.ANCHOR_MS - 100)
	check(not sim.hero.rooted(sim.now), "not yet")
	F.ms(sim, 200)
	check(sim.hero.rooted(sim.now), "stood still, rooted")
	eq(sim.hero.dodge_refusal(sim.now), &"rooted", "and rooted, no dodge")
	sim.hero.move = Vector2.RIGHT
	F.ms(sim, 100)
	check(sim.hero.rooted(sim.now), "a root takes a moment to pull up")
	eq(sim.hero.dodge_refusal(sim.now), &"rooted", "and no dodge while it does")
	F.ms(sim, FightKit.ANCHOR_LIFT_MS)
	check(not sim.hero.rooted(sim.now), "a few steps lift it")
	var bare := F.make_sim()
	F.ms(bare, 2000)
	check(not bare.hero.rooted(bare.now), "without the anchor, standing is only standing")


## A runner's bite lands on a rooted player: it hurts, and it does not throw
## them. A lineman's grip closes on nothing.
func test_rooted_a_blow_does_not_throw_and_a_grip_fails() -> void:
	for kit: Array[StringName] in [[] as Array[StringName], [&"mod_anchor"] as Array[StringName]]:
		var sim := F.make_sim()
		sim.hero.kit = FightKit.of(kit)
		F.ms(sim, FightKit.ANCHOR_MS + 100)
		var m := F.still(sim, &"runner", sim.hero.pos + Vector2(1.0, 0.0), PI)
		var at := sim.hero.pos
		m.set_mood(MobState.ATTACKING, sim.now)
		Brains.bite(m, sim)
		F.ms(sim, 700)
		var thrown := sim.hero.pos.distance_to(at)
		if kit.is_empty():
			gt(thrown, 0.2, "bare, the bite throws the player %.2f" % thrown)
		else:
			lt(thrown, 0.05, "rooted, it does not (%.2f)" % thrown)
		var g := F.make_sim()
		g.hero.kit = FightKit.of(kit)
		F.ms(g, FightKit.ANCHOR_MS + 100)
		var l := F.still(g, &"lineman", g.hero.pos + Vector2(1.2, 0.0), PI)
		l.set_mood(MobState.ATTACKING, g.now)
		Brains.bite(l, g)
		F.ms(g, 900)
		if kit.is_empty():
			check(g.hero.held(), "bare, the lineman's grip takes hold")
		else:
			check(not g.hero.held(), "rooted, its grip fails")
			check(l.landed_at != l.blow_at, "and the lineman stands as after a miss")


## THE BOUT: the crowd reader with the knife, 24 bouts (test_crowd_reader
## `gate`), bare and with the anchor (it lets the root take against grippers and
## stands through their bites; against anything whose bite hurts it keeps a
## step going and dodges as ever). Its identity: two linemen, whose whole blow
## is a grip, fall in half the time or less; two cutters, which bite, go as they
## did bare.
func _gate(kind: StringName, n: int, kit: Array[StringName]) -> Dictionary:
	var won := 0
	var t := 0.0
	for i in 24:
		var r := G.gate(true, i % 8, kind, n, kit, 120.0, &"knife", 0, 1000 + i / 8)
		won += int(r.won)
		if r.won:
			t += float(r.t)
	return {"won": won, "t": t / maxf(won, 1)}


func test_the_anchor_bout() -> void:
	var a: Array[StringName] = [&"mod_anchor"]
	var lb := _gate(&"lineman", 2, [])
	var la := _gate(&"lineman", 2, a)
	var cb := _gate(&"cutter", 2, [])
	var ca := _gate(&"cutter", 2, a)
	print("  info 2 linemen: bare %d/24 in %.1f s, anchored %d/24 in %.1f s; 2 cutters: bare %d/24 in %.1f s, anchor %d/24 in %.1f s"
		% [lb.won, lb.t, la.won, la.t, cb.won, cb.t, ca.won, ca.t])
	eq(la.won, lb.won, "the linemen are beaten as often")
	lt(float(la.t), float(lb.t) * 0.5, "in half the time or less: their grip closes on nothing")
	gt(float(ca.won), float(cb.won) - 2.5, "and two cutters are no harder with it than without")
