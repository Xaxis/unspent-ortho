extends TestCase
## THE UNDERTOW (GEAR.md G4): the tide reaper's core on the jig, worn on the
## hands. The grapple takes hold of a machine in front and drags it one
## body-length in, out of its line: a tell it was winding up is broken and it
## stands stalled, as a jammed part stalls it. The haul costs double wind.

const F := preload("res://tests/fight/fixture.gd")
const Fx := preload("res://tests/survival/fixture.gd")
const G := preload("res://tests/fight/test_crowd_reader.gd")


func test_the_reapers_core_becomes_the_undertow_on_the_jig() -> void:
	check(Gear.is_module(&"mod_undertow"), "the undertow is a module")
	eq(Items.def(&"mod_undertow").get("fits", []), [&"hands"], "worn on the hands")
	eq(GearTree.row(&"mod_undertow").get("grade", &""), &"relic", "a keeper's power is a relic")
	eq(GearTree.made_of(&"mod_undertow"), &"reaper_core", "made of the tide reaper's core")
	var r: Dictionary = {}
	for row: Dictionary in Recipes.LIST:
		if row.get("id", &"") == &"mod_undertow":
			r = row
	check(not r.is_empty(), "there is a recipe for it")
	check((r.get("needs", {}) as Dictionary).has(&"reaper_core"), "and it spends the core")
	check((r.get("keeps", {}) as Dictionary).has(&"fab_jig"), "on the jig")
	check(ModifierTable.decision(&"mod_undertow") != "", "it says what it decides")
	check(FightKit.of([&"mod_undertow"]).undertow, "and the kit reads it")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


## A harvester six tiles out, winding up: hauled in one body-length, its tell
## broken, stalled. A dog is not a machine and is not taken hold of.
func test_the_haul_drags_a_machine_in_and_breaks_its_line() -> void:
	var sim := F.make_sim()
	sim.hero.kit = FightKit.of([&"mod_undertow"])
	var m := F.still(sim, &"harvester", sim.hero.pos + Vector2(6.0, 0.0), PI)
	m.set_mood(MobState.ATTACKING, sim.now)
	Brains.bite(m, sim)
	eq(m.blow_phase(sim.now), &"windup", "winding up")
	var before := m.pos.distance_to(sim.hero.pos)
	check(sim.undertow(m), "the line takes it")
	var after := m.pos.distance_to(sim.hero.pos)
	near(before - after, m.radius * 2.0, 0.05, "one body-length in")
	check(m.blow_phase(sim.now) != &"windup", "its tell is broken")
	check(m.stunned(sim.now), "and it stands stalled")
	var d := F.still(sim, &"dog.yard", sim.hero.pos + Vector2(0.0, 3.0), -PI * 0.5)
	check(not sim.undertow(d), "a dog is no machine to haul")
	# Not closer than touching: a machine already at arm's length is not pulled
	# into the player.
	var c := F.still(sim, &"runner", sim.hero.pos + Vector2(-1.3, 0.0), 0.0)
	sim.undertow(c)
	gt(c.pos.distance_to(sim.hero.pos), c.radius + sim.hero.radius, "never pulled inside the player")


## Without the undertow the grapple never takes hold of a machine; with it, the
## machine ahead is the hold, and the haul spends twice the grapple's wind.
func test_the_grapple_hauls_a_machine_for_double_wind() -> void:
	var g := Fx.flat(48)
	var sim := F.make_sim(g.world, g.player.pos)
	g.player.sim = sim
	g.player.hero = sim.hero
	g.player.facing = 0.0
	var m := F.still(sim, &"harvester", g.player.pos + Vector2(5.0, 0.0), PI)
	eq(AbilityGrapple.anchor(g.world, g.query, g.player.pos, Vector2.RIGHT, sim).get("what", &""), &"",
		"bare, a machine is not a hold")
	sim.hero.kit = FightKit.of([&"mod_undertow"])
	var a := AbilityGrapple.anchor(g.world, g.query, g.player.pos, Vector2.RIGHT, sim)
	eq(a.get("what", &""), &"machine", "with the undertow it is")
	var book := AbilityBook.new()
	book.fit([&"grapple"] as Array[StringName])
	var ctx := AbilityCtx.new()
	ctx.game = g
	ctx.now = 100.0
	var wind := sim.hero.wind
	var before := m.pos.distance_to(g.player.pos)
	eq(book.press(&"grapple", ctx), &"", "the haul goes")
	near(wind - sim.hero.wind, AbilityGrapple.WIND * 2.0, 0.5, "for double the grapple's wind")
	lt(m.pos.distance_to(g.player.pos), before - 1.0, "and the machine comes in")
	check(ctx.motion == null, "the player is not the one who moves")
	sim.hero.wind = AbilityGrapple.WIND * 1.5
	eq(book.press(&"grapple", _ctx_at(g, 200.0)), &"winded", "short of double wind, no haul")
	g.player.sim = null
	g.player.hero = null
	Fx.done(g)


func _ctx_at(g: Game, now: float) -> AbilityCtx:
	var c := AbilityCtx.new()
	c.game = g
	c.now = now
	return c


## THE BOUT: one machine roused five tiles off, the crowd reader with the knife
## (tests/fight/test_crowd_reader `gate`), 24 bouts, bare and with the undertow
## (the reader hauls a machine it faces alone that stands out of reach). The
## decision it makes: a harvester that charges from afar is hauled onto the
## knife and falls a fifth sooner or more; a hauler, which comes on anyway, is
## hauled for nothing and the breath is gone, so it is slower. A tool, not a win.
func _bout(kind: StringName, kit: Array[StringName]) -> Dictionary:
	var won := 0
	var t := 0.0
	for i in 24:
		var r := G.gate(true, i % 8, kind, 1, kit, 90.0, &"knife", 0, 1000 + i / 8)
		won += int(r.won)
		if r.won:
			t += float(r.t)
	return {"won": won, "t": t / maxf(won, 1)}


func test_the_undertow_bout() -> void:
	var u: Array[StringName] = [&"mod_undertow"]
	var hb := _bout(&"harvester", [])
	var hu := _bout(&"harvester", u)
	var ab := _bout(&"hauler", [])
	var au := _bout(&"hauler", u)
	print("  info harvester: bare %.1f s, undertow %.1f s; hauler: bare %.1f s, undertow %.1f s (won %d %d %d %d of 24)"
		% [hb.t, hu.t, ab.t, au.t, hb.won, hu.won, ab.won, au.won])
	lt(float(hu.t), float(hb.t) * 0.8, "a harvester hauled onto the knife falls a fifth sooner or more")
	gt(float(au.t), float(ab.t), "a hauler hauled for nothing is slower: the haul is a choice")
