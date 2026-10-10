extends TestCase
## What the player does carries, and how far: the one thing a machine always
## has, whatever the dark and the weather.


func test_the_louder_the_act_the_further_it_goes() -> void:
	var g := Ground.GRASS
	gt(StealthNoise.radius(&"kill", g), StealthNoise.radius(&"break", g), "a machine going down")
	gt(StealthNoise.radius(&"break", g), StealthNoise.radius(&"run", g), "breaking rock")
	gt(StealthNoise.radius(&"run", g), StealthNoise.radius(&"walk", g), "running")
	gt(StealthNoise.radius(&"walk", g), StealthNoise.radius(&"crouch_unknown_act", g) + 0.001,
		"an act nothing knows about makes no noise at all")
	eq(StealthNoise.radius(&"nothing", g), 0.0)


func test_the_ground_underfoot_decides_half_of_it() -> void:
	var walk := &"walk"
	gt(StealthNoise.radius(walk, Ground.SHINGLE), StealthNoise.radius(walk, Ground.GRASS), "shingle rattles")
	lt(StealthNoise.radius(walk, Ground.MOSS), StealthNoise.radius(walk, Ground.GRASS), "moss swallows")
	lt(StealthNoise.radius(walk, Ground.SNOW), StealthNoise.radius(walk, Ground.GRASS), "so does snow")
	gt(StealthNoise.radius(walk, Ground.WATER), StealthNoise.radius(walk, Ground.SHINGLE), "wading is worst")
	near(StealthNoise.ground_factor(Ground.ROCK), 1.1, 1e-5)


func test_crouching_quietens_the_body_far_more_than_the_tool() -> void:
	var g := Ground.GRASS
	var walk := StealthNoise.radius(&"walk", g)
	var crept := StealthNoise.radius(&"walk", g, true)
	near(crept / walk, StealthNoise.CROUCH_BODY, 1e-5, "creeping is a third as loud")
	var swing := StealthNoise.radius(&"swing", g)
	var crouched_swing := StealthNoise.radius(&"swing", g, true)
	near(crouched_swing / swing, StealthNoise.CROUCH_TOOL, 1e-5, "a blow is a blow, crouched or not")
	gt(crouched_swing, crept, "you cannot hide a swing behind a crouch")


func test_a_heavy_load_carries() -> void:
	var g := Ground.GRASS
	gt(StealthNoise.radius(&"walk", g, false, 2), StealthNoise.radius(&"walk", g, false, 0), "laden")
	near(StealthNoise.radius(&"walk", g, false, 2) / StealthNoise.radius(&"walk", g, false, 0),
		1.0 + StealthNoise.LADEN * 2, 1e-5)


func test_loudness_is_one_for_a_plain_walk_and_a_fraction_standing_still() -> void:
	var g := Ground.GRASS
	near(StealthNoise.loudness(Tuning.WALK_SPEED, g, false, 0), StealthNoise.ground_factor(g), 0.02,
		"walking on grass is about a walk")
	var still := StealthNoise.loudness(0.0, g, false, 0)
	lt(still, 0.4, "standing still, next to nothing")
	gt(still, 0.0, "but a body is still a body")
	gt(StealthNoise.loudness(Tuning.RUN_SPEED, Ground.SHINGLE, false, 0), 2.0, "running on shingle")
	lt(StealthNoise.loudness(Tuning.WALK_SPEED, Ground.MOSS, true, 0), 0.3,
		"creeping through moss is a quarter of a walk")
	lt(StealthNoise.loudness(99.0, Ground.WATER, false, 3), StealthNoise.LOUDEST + 1e-5, "and it is capped")


## A TAKE IS AS LOUD AS WHAT IT DOES (docs/SALVAGE.md): a hand gathering is
## barely heard and a pick on concrete rings across a field. Every verb counted as
## one `work` before, so picking berries carried as far as digging out scrap.
func test_a_take_is_as_loud_as_its_verb() -> void:
	var g := Ground.GRASS
	lt(StealthNoise.radius(&"gather", g), StealthNoise.radius(&"walk", g), "a hand gathering, quieter than a walk")
	lt(StealthNoise.radius(&"cut", g), StealthNoise.radius(&"turn", g), "a blade cutting, quieter than plate being turned over")
	lt(StealthNoise.radius(&"turn", g), StealthNoise.radius(&"dig", g), "turning a heap over, quieter than digging into it")
	lt(StealthNoise.radius(&"dig", g), StealthNoise.radius(&"break", g), "digging, quieter than a pick on concrete")


## THE PROMPT SAYS SO BEFORE THE PRESS: with a machine in earshot of a pick on a
## slab, the take reads that it will be heard; with it out of earshot, it does
## not; and the same machine at the same distance does not hear a hand gathering.
func test_the_take_prompt_says_a_machine_will_hear_it() -> void:
	var o := BootOptions.parse(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	await frames(4)
	var at := g.player.pos
	g.player.facing = 0.0
	g.player.hero.facing = 0.0
	g.inventory.add(&"pick", 1)
	g.inventory.held = &"pick"
	var slab := Survival.add_prop(g, PropKind.REBAR_SLAB, at + Vector2(0.9, 0.0), 0.0, 0.4)
	check(slab != null, "a rebar slab in reach")
	await frames(2)
	check(not Survival.describe_target(g).contains("will hear"), "nothing near, nothing said: %s" % Survival.describe_target(g))
	var r := Survival.noise_radius(g, &"break")
	gt(r, 6.0, "a pick on a slab carries (%.1f tiles)" % r)
	var m := g.player.sim.add_mob(&"harvester", at + Vector2(0.0, minf(r * 0.5, 7.0)))
	m.alive = true
	await frames(2)
	check(Survival.describe_target(g).contains("(a machine will hear)"), "a harvester in earshot: %s" % Survival.describe_target(g))
	check(not Survival.would_be_heard(g, &"gather"), "but a hand gathering there is not heard")
	m.pos = at + Vector2(0.0, r * 3.0)
	await frames(2)
	check(not Survival.describe_target(g).contains("will hear"), "out of earshot again: %s" % Survival.describe_target(g))
	g.queue_free()
	await frames(1)
