extends TestCase
## THE HUSH WRAP (GEAR.md §6, G8): a warm wrap lined with crags hush slate at
## the hem and the soles. Its hook is StealthNoise (radius, moving, loudness):
## what the body itself does (BODY_ACTS) is heard as if on moss, on any land.
## A tool's noise is not, and neither is swimming.

const F := preload("res://tests/fight/fixture.gd")


func test_the_hush_wrap_is_a_rare_wrap_of_hush_slate() -> void:
	eq(Gear.slot_of(&"wrap_hush"), &"body", "worn on the body")
	eq(GearTree.row(&"wrap_hush").get("grade", &""), &"rare", "a rare piece")
	eq(GearTree.made_of(&"wrap_hush"), &"hush_slate", "made of the crags' hush slate")
	check(Crafting.recipe(&"wrap_hush").get("at", &"") == &"bench", "made at a bench")
	check(FightKit.of([&"wrap_hush"]).hush, "the kit reads it")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


func test_steps_on_any_land_are_as_quiet_as_on_moss() -> void:
	var moss := StealthNoise.radius(&"walk", Ground.MOSS)
	for g: int in [Ground.SHINGLE, Ground.ROAD, Ground.GRAVEL, Ground.GRASS]:
		gt(StealthNoise.radius(&"walk", g), moss, "bare, a walk on %d is louder than on moss" % g)
		near(StealthNoise.radius(&"walk", g, false, 0, true), moss, 1e-4, "hushed, a walk on %d is moss" % g)
		near(StealthNoise.radius(&"run", g, false, 0, true), StealthNoise.radius(&"run", Ground.MOSS), 1e-4, "and so is a run")
	near(StealthNoise.radius(&"walk", Ground.MOSS, false, 0, true), moss, 1e-4, "moss itself is as quiet as it was")
	near(StealthNoise.radius(&"hit", Ground.SHINGLE, false, 0, true), StealthNoise.radius(&"hit", Ground.SHINGLE), 1e-4, "a tool's noise is not hushed")
	near(StealthNoise.radius(&"walk", Ground.WATER, false, 0, true), StealthNoise.radius(&"walk", Ground.WATER), 1e-4, "nor a stroke in the water")
	lt(StealthNoise.loudness(Tuning.WALK_SPEED, Ground.SHINGLE, false, 0, true), StealthNoise.loudness(Tuning.WALK_SPEED, Ground.SHINGLE, false, 0), "the loudness a machine hears by comes down with it")


## THE BOUT: a walk across shingle past twelve idle hunters standing 12 to 15
## tiles off the path with their backs to it (a runner hears a walk 10 tiles on
## plain ground: 14 on shingle, 6 on moss), the player's steps as loud as StealthNoise says
## for shingle, bare and hushed. Its identity: fewer of them hear and come.
func _walk(hushed: bool) -> int:
	MobState._next_id = 2000
	var sim := F.make_sim(F.flat_world(96, Ground.SHINGLE), Vector2(20.5, 48.5))
	sim.moment.loudness = StealthNoise.loudness(Tuning.WALK_SPEED, Ground.SHINGLE, false, 0, hushed)
	var mobs: Array[MobState] = []
	for k in 12:
		var side := 1.0 if k % 2 == 0 else -1.0
		var m := sim.add_mob(&"runner", Vector2(26.0 + k * 4.0, 48.5 + side * (12.0 + (k % 4) * 1.0)))
		m.facing = side * PI * 0.5
		m.aim = m.facing
		mobs.append(m)
	sim.hero.facing = 0.0
	sim.hero.move = Vector2.RIGHT
	F.ms(sim, 16000)
	var roused := 0
	for m in mobs:
		roused += int(m.mood != MobState.IDLE and m.mood != MobState.WORKING)
	return roused


func test_the_hush_wrap_bout() -> void:
	var bare := _walk(false)
	var hushed := _walk(true)
	print("  info a walk across shingle past twelve hunters: %d come bare, %d hushed" % [bare, hushed])
	lt(float(hushed), float(bare) - 1.5, "fewer of them hear the steps and come")
