extends TestCase
## Climbing (mechanics improvement 5a; Climb, AbilityMotion.climb_face, the jump
## key at a rock face). Up a rock face too tall to jump at a level a second and a
## bit, on breath; turf gives nothing to hold; short of breath the arms give out
## and the body comes back down, and past a jump's drop that hurts; and on the
## face the body is at the level it has climbed to, so a machine at the foot
## reaches it only within a ledge of the ground (the height rule, 1a).

const F := preload("res://tests/fight/fixture.gd")
## A rock face FACE levels tall along x = LIP, and a turf one along y = TURF.
const LIP := 30
const FACE := 5
const TURF := 50


func _world() -> WorldData:
	var w := F.flat_world(64)
	for y in 64:
		for x in 64:
			if x >= LIP and y < TURF - 4:
				w.level[y * 64 + x] = 2 + FACE
				w.ground[y * 64 + x] = Ground.ROCK
			elif y >= TURF:
				w.level[y * 64 + x] = 2 + FACE
				w.ground[y * 64 + x] = Ground.GRASS
	return w


func test_a_rock_face_is_climbed_and_turf_is_not() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	var p := Climb.plan(w, q, Vector2(LIP - 0.5, 20.5), Vector2.RIGHT, FightRules.WIND)
	check(p != null, "a rock face five levels tall has a climb")
	if p == null:
		return
	eq(p.levels, FACE, "five levels")
	eq(p.reached, FACE, "all of them on full breath")
	check(not p.slides, "and over the top")
	eq(p.wind, FACE * Climb.WIND_PER_LEVEL, "at %d breath a level" % int(Climb.WIND_PER_LEVEL))
	lt(absf(p.seconds - (FACE / Climb.RATE + Climb.LIP_SECONDS)), 1e-4, "a level every %.2f s" % (1.0 / Climb.RATE))
	eq(w.level_at(floori(p.top.x), floori(p.top.y)), 2 + FACE, "the top is on the shelf")
	check(Climb.plan(w, q, Vector2(20.5, TURF - 0.5), Vector2.DOWN, FightRules.WIND) == null, "a turf bank of the same height gives nothing to hold")
	check(Climb.plan(w, q, Vector2(20.5, 20.5), Vector2.RIGHT, FightRules.WIND) == null, "and open ground is no face")


func test_short_of_breath_the_arms_give_out_and_a_long_fall_hurts() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	var p := Climb.plan(w, q, Vector2(LIP - 0.5, 20.5), Vector2.RIGHT, Climb.WIND_PER_LEVEL * 3.5)
	eq(p.reached, 3, "three levels of breath climb three levels")
	check(p.slides, "and come back down")
	eq(p.fall_damage, 0, "three levels is a jump's drop: no harm")
	var end: Array = p.at(p.seconds)
	lt((end[0] as Vector2).distance_to(p.from), 0.01, "back where it started")
	eq(Climb.fall_damage(4), 1, "four levels down: one")
	eq(Climb.fall_damage(6), 1, "six: still one")
	eq(Climb.fall_damage(7), 2, "seven: two")


func test_on_the_face_a_machine_below_reaches_only_the_first_ledge() -> void:
	var sim := F.make_sim(_world(), Vector2(LIP - 0.5, 20.5))
	var m := F.still(sim, &"runner", Vector2(LIP - 1.4, 20.5), 0.0)
	check(sim.meets_hero(m.pos), "at the foot, it reaches")
	sim.hero_level = 2 + 1
	check(sim.meets_hero(m.pos), "a level up, it still reaches")
	sim.hero_level = 2 + FightRules.LEDGE_LEVELS
	check(not sim.meets_hero(m.pos), "a ledge up the face, it does not")


## In a running game, on the jump key: up and over, breath spent, no swing on
## the face; and turned toward the face, the route up it is ruled before trying.
func test_the_jump_key_at_a_rock_face_climbs_it() -> void:
	var o := BootOptions.parse(PackedStringArray(["--seed=1", "--size=48", "--hour=11"]))
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	var gear: Node = null
	for s in g.systems:
		if s.name == "54_gear":
			gear = s
	var found := Climb.find(g.world, g.query, g.player.pos, 60.0)
	check(not found.is_empty(), "the world has a rock face too tall to jump near the spawn")
	if found.is_empty():
		g.queue_free()
		return
	var hero: Hero = g.player.hero
	g.player.sim.clear_mobs()
	hero.pos = found.at
	g.player.pos = found.at
	hero.facing = (found.dir as Vector2).angle()
	g.player.facing = hero.facing
	await frames(20)
	check(gear.get("_route") != null, "turned toward it, the route up the face is ruled")
	var plan: Climb.Plan = found.plan
	var wind := hero.wind
	eq(gear.call("fire", &"jump"), &"", "the jump key takes")
	var on_face := false
	var refused := &""
	for i in 240:
		await frames(1)
		if hero.airborne and g.player.lift > 0.5 and not on_face:
			on_face = true
			refused = hero.swing_refusal(g.player.sim.now)
		if not hero.airborne and on_face:
			break
	check(on_face, "it went up the face")
	eq(refused, &"airborne", "and nothing may be swung on it")
	eq(g.world.level_at(floori(hero.pos.x), floori(hero.pos.y)), plan.to_level, "it stands on the top")
	lt(hero.wind, wind - plan.levels * Climb.WIND_PER_LEVEL + FightRules.WIND_REGEN * 6.0, "and the breath went on it")
	g.queue_free()
	await frames(2)
