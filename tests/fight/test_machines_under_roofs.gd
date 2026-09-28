extends TestCase
## A MACHINE TALLER THAN THE ROOM STOPS AT THE LIP (teammate1's ruling on the
## crouch, 2026-09-27). A crouched player fits under a roof at 1.5
## (Tuning.PLAYER_CROUCH_HEIGHT); a machine goes wherever its own roster height
## fits and nowhere else, however it is moved: its own chase, and a line hauling
## it in (FightSim.undertow). Asked on the one crouch-only roof the game has, a
## container warren's buckled bay (the caves keep six levels of room everywhere,
## test_cave_roofs): a longlegs, 2.0 tall, comes up to the lip and no further;
## a runner, 1.3, fits and follows in.

const F := preload("res://tests/fight/fixture.gd")

var _doors := load("res://src/systems/21_doors.gd") as GDScript


## A warren behind some door with a buckled bay: the pocket, and the bay.
func _bay() -> Array:
	var land := BiomeRegistry.index_of(&"the_middens")
	for i in 80:
		var t := Threshold.of_face(Vector2(40.0 + 7.0 * i, 60.0 + 3.0 * (i % 5)), Vector2(0, 1), &"container_warren", land)
		var p := InteriorGen.grow(1, t)
		for th: Dictionary in p.layout.things:
			if th.kind == &"buckled":
				return [p, th]
	return []


## A hero crouched in the middle of the bay, and a machine of `kind` roused on
## the open deck `off` tiles away along the run.
func _sim(p: InteriorGen.Pocket, bay: Dictionary, kind: StringName, off: float) -> Array:
	var mid: Vector2 = bay.at
	var f: Vector2 = bay.face
	var sim := F.make_sim(p.world, mid)
	sim.query.set_blocks(&"rooms", _doors.call(&"_walls", p.layout) as Array[Vector3])
	sim.hero.body.crouched = true
	var m := sim.add_mob(kind, mid + f * off)
	m.facing = (-f).angle()
	m.aim = m.facing
	m.disturbed = true
	m.set_mood(MobState.ATTACKING, sim.now)
	return [sim, m]


func _under_roof(sim: FightSim, at: Vector2, tall: int) -> bool:
	return sim.world.headroom_at(floori(at.x), floori(at.y)) < tall


func test_a_tall_machine_chasing_stops_at_the_lip_and_a_small_one_follows_in() -> void:
	var found := _bay()
	check(not found.is_empty(), "a warren with a buckled bay is grown")
	if found.is_empty():
		return
	var p: InteriorGen.Pocket = found[0]
	var bay: Dictionary = found[1]
	var mid: Vector2 = bay.at
	var tall := _sim(p, bay, &"longlegs", 2.6)
	var sim: FightSim = tall[0]
	var m: MobState = tall[1]
	var need := FightSim.tall_of(m.row)
	gt(float(need), float(FightSim.HERO_CROUCH_TALL), "a longlegs is taller than the room under the bay")
	var nearest := INF
	for i in 120:
		F.ms(sim, 50.0)
		check(not _under_roof(sim, m.pos, need), "the longlegs never stands under the buckle")
		nearest = minf(nearest, m.pos.distance_to(mid))
	lt(nearest, 1.9, "it did come up to the lip")
	var small := _sim(p, bay, &"runner", 2.6)
	var sim2: FightSim = small[0]
	var r: MobState = small[1]
	gt(float(sim2.world.headroom_at(floori(mid.x), floori(mid.y))), float(FightSim.tall_of(r.row)) - 1.0, "a runner fits under the bay")
	var went := false
	for i in 120:
		F.ms(sim2, 50.0)
		went = went or _under_roof(sim2, r.pos, FightSim.HERO_TALL)
	check(went, "and a runner follows the player in")


func test_a_line_never_hauls_a_tall_machine_under_a_roof_it_cannot_stand_under() -> void:
	var found := _bay()
	if found.is_empty():
		check(false, "a warren with a buckled bay is grown")
		return
	var p: InteriorGen.Pocket = found[0]
	var bay: Dictionary = found[1]
	var f: Vector2 = bay.face
	var at := _sim(p, bay, &"longlegs", 1.3)
	var sim: FightSim = at[0]
	var m: MobState = at[1]
	sim.hero.kit = FightKit.of([&"mod_undertow"])
	# The player at the far edge of the bay, the machine just past its near one, so
	# a haul to UNDERTOW_GAP off them would land it under the fold.
	sim.hero.pos = (bay.at as Vector2) - f * 0.95
	m.pos = (bay.at as Vector2) + f * 1.3
	var need := FightSim.tall_of(m.row)
	check(not _under_roof(sim, m.pos, need), "the longlegs starts on the open deck at the lip")
	check(_under_roof(sim, sim.hero.pos, FightSim.HERO_TALL), "the player is under the fold")
	sim.undertow(m)
	check(not _under_roof(sim, m.pos, need), "hauled, it still stands on the open deck")


## And the player's own dash, which is upright: a standing body dashed at the
## bay stops at its lip as a walk does (the crouch is what gets under it).
func test_a_dash_stops_at_the_lip_of_a_roof_too_low_to_stand_under() -> void:
	var found := _bay()
	if found.is_empty():
		check(false, "a warren with a buckled bay is grown")
		return
	var p: InteriorGen.Pocket = found[0]
	var bay: Dictionary = found[1]
	var f: Vector2 = bay.face
	var q := WorldQuery.new(p.world)
	q.set_blocks(&"rooms", _doors.call(&"_walls", p.layout) as Array[Vector3])
	var pos := (bay.at as Vector2) + f * 2.5
	var dash := AbilityMotion.dash(-f, 9.0, 0.6)
	for i in 60:
		pos = dash.step(1.0 / 60.0, pos, p.world, q, Tuning.PLAYER_RADIUS)
		check(p.world.headroom_at(floori(pos.x), floori(pos.y)) >= FightSim.HERO_TALL, "the dash never carries a standing body under the fold")
	lt(pos.distance_to(bay.at as Vector2), 2.0, "it did come up to the lip")
