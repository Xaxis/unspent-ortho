extends TestCase
## PLATING (roster `plating`, FightRules.bites): a keeper whose plate is harder
## than the edge in hand rings every blow off, even in its open part. The Tide
## Reaper is plated in steel: the iron knife the player wakes with does not bite
## it, and that is the reason the next thing made is a steel edge.

const F := preload("res://tests/fight/fixture.gd")


## A struck reaper, open and facing away (its part bared), hit once with `tool`:
## {hurt, plating}.
func _strike(tool: StringName) -> Dictionary:
	MobState._next_id = 5000
	var sim := F.make_sim(F.flat_world(48), Vector2(20.5, 20.5))
	if tool != &"":
		sim.hero.inventory.add(tool)
		sim.hero.inventory.set_held(tool)
	var def := Sentinels.for_land(&"coast")
	var m := F.still(sim, def.kind, sim.hero.pos + Vector2(1.8, 0.0), 0.0)
	Sentinels.own_row(m)
	Sentinels.wear_phase(m, def, 0)
	# Its part is its front and guarded: turned to the player and spent, it is open.
	m.facing = PI
	m.aim = PI
	m.start_blow(m.bite, sim.now - float(m.bite.windup + m.bite.active + 10))
	sim.hero.facing = 0.0
	var before := m.health
	var plating := 0
	sim.press_swing()
	for i in 40:
		sim.slices(1)
		for e in sim.drain():
			if e.type == &"plating":
				plating += 1
	return {"hurt": before - m.health, "plating": plating}


func test_the_knife_does_not_bite_the_reapers_plating() -> void:
	eq(Roster.row(&"sentinel.coast").get("plating", &""), &"steel", "the reaper is plated in steel")
	var knife := _strike(&"knife")
	eq(knife.hurt, 0, "the iron knife rings off its open part")
	eq(knife.plating, 1, "and the plating is said")
	var steel := _strike(&"knife_shear")
	gt(float(steel.hurt), 0.0, "a steel edge bites it (%d)" % steel.hurt)
	eq(steel.plating, 0, "and nothing rings")


func test_the_rule_reads_the_edge_against_the_plate() -> void:
	var row := {"plating": &"steel"}
	check(not FightRules.bites(row, &"knife"), "iron does not bite steel plate")
	check(not FightRules.bites(row, &""), "nor bare hands")
	check(FightRules.bites(row, &"knife_shear"), "steel does")
	check(FightRules.bites(row, &"axe_felling"), "any steel")
	check(FightRules.bites({}, &"knife"), "a body with no plating is bitten by anything")
	check(FightRules.bites({}, &""), "bare hands too")
