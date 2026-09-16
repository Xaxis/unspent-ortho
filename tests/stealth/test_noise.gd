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
