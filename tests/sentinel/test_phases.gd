extends TestCase
## A phase is the BODY, and the body is the only thing anything reads. These tests
## drive a keeper through its phases in the real simulation, headless, and then
## ask the things a player asks: what side is open, what can it do to me, what is
## it thinking (`TargetRead`, the enemy read under `z`).

const F := preload("res://tests/fight/fixture.gd")


func _keeper(sim: FightSim, def: SentinelDef, at: Vector2 = Vector2(20.5, 20.5)) -> MobState:
	var m := F.still(sim, def.kind, at, 0.0)
	Sentinels.own_row(m)
	Sentinels.wear_phase(m, def, 0)
	return m


func test_a_phase_rewrites_the_row_and_the_roster_is_left_alone() -> void:
	var def := Sentinels.for_land(&"coast")
	var sim := F.make_sim()
	var m := _keeper(sim, def)
	var before := SaveCodec.canonical(Roster.DEFS[def.kind])
	for i in def.phases.size():
		Sentinels.wear_phase(m, def, i)
		var p := def.phase(i)
		eq(m.part, p.part, "phase %s: the body's working side" % p.id)
		eq(StringName(str(m.row.part)), p.part, "phase %s: and its row says the same, which is what the read reads" % p.id)
		eq(m.row.get("guarded", false), p.guarded, "phase %s: guarded" % p.id)
		eq(m.bite.dmg, int(p.bite.get("dmg", 0)), "phase %s: its bite is the phase's" % p.id)
		near(m.bite.reach, float(p.bite.get("reach", 0.0)), 1e-4, "phase %s: and its reach" % p.id)
	eq(SaveCodec.canonical(Roster.DEFS[def.kind]), before, "the roster table itself was never touched")


func test_every_phase_leaves_the_working_side_reachable_by_walking_round_it() -> void:
	# The rule the fight rests on (tests/fight/test_openings): a machine must turn
	# slower than a player walks round it at close quarters, or its side cannot be
	# reached and the only answer left is trading hits.
	var knife := Blow.for_item(&"knife", 5000)
	for def: SentinelDef in Sentinels.all():
		var m := MobState.new(def.kind, Vector2(10, 10))
		var circle := m.radius + Tuning.PLAYER_RADIUS + knife.reach * 0.5
		for i in def.phases.size():
			Sentinels.wear_phase(m, def, i)
			lt(m.turn_rate, Tuning.WALK_SPEED / circle,
				"%s phase %s tracks a walking player (%.2f rad/s, bound %.2f)" % [def.id, def.phase(i).id, m.turn_rate, Tuning.WALK_SPEED / circle])


func test_a_guarded_phase_rings_off_the_front_and_opens_after_a_bite_that_missed() -> void:
	var def := Sentinels.for_land(&"coast")
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	# Far to one side: its bite goes past nobody.
	sim.hero.pos = Vector2(20.5, 40.5)
	var m := _keeper(sim, def, Vector2(20.5, 20.5))
	check(bool(m.row.get("guarded", false)), "the reaper's first phase guards its drum")
	m.set_mood(MobState.ATTACKING, sim.now)
	check(not sim.reaches_part(m, m.pos + Vector2(2, 0)), "a blow into the drum of a roused keeper rings off")
	m.start_blow(m.bite, sim.now)
	F.ms(sim, m.bite.windup + m.bite.active + 8)
	eq(F.count(sim.drain(), &"opened"), 1, "it says when its bite is spent")
	check(m.spent(sim.now), "spent")
	check(sim.reaches_part(m, m.pos + Vector2(2, 0)), "and the drum is open while it winds back")
	F.ms(sim, m.bite.recovery + 16)
	check(m.spent(sim.now), "still spent through the whole cooldown")
	lt(m.turn_rate_at(sim.now), FightRules.RECOVER_TURN + 0.001, "turning slowly, so the opening can be walked to")


func test_the_read_under_the_key_changes_with_the_phase() -> void:
	var def := Sentinels.for_land(&"coast")
	var sim := F.make_sim()
	var m := _keeper(sim, def)
	var moment := sim.moment
	var reads: Array[Dictionary] = []
	for i in def.phases.size():
		Sentinels.wear_phase(m, def, i)
		reads.append(TargetRead.of(m, sim.hero.pos, moment, sim.world, sim.query, sim.now))
	eq(reads[0].part, "front", "phase one reads as a front")
	eq(reads[reads.size() - 1].part, String(def.phase(def.phases.size() - 1).part), "and the last as its own side")
	var first: PackedStringArray = reads[0].powers
	var last: PackedStringArray = reads[reads.size() - 1].powers
	check(Array(first).has("throws blows off its front"), "the read says the drum is guarded while it is")
	check(not Array(last).has("throws blows off its front"), "and stops saying it when it is not")
	check(Array(last).has("holds you"), "the reaper's last phase takes hold, and the read says so")
	for r: Dictionary in reads:
		check(Array(r.powers as PackedStringArray).has("charges in a line"), "a keeper's run is on the read throughout")
		check(String(r.name) != "", "it has a name to show")
	eq(reads[0].max_health, Roster.health_of(def.kind), "the health on the read is the roster's own")


func test_its_thinking_is_the_bodys_own_mood_and_nothing_invented() -> void:
	var def := Sentinels.for_land(&"salt_flats")
	var sim := F.make_sim()
	var m := _keeper(sim, def)
	eq(TargetRead.thinking(m, sim.now), "at its work, looking up often", "a keeper is wary: at its work and looking up")
	m.set_mood(MobState.ATTACKING, sim.now)
	m.disturbed = true
	m.start_blow(m.bite, sim.now)
	eq(TargetRead.thinking(m, sim.now + 10.0), "winding up", "and its tell is read off the blow it has thrown")
	eq(TargetRead.thinking(m, sim.now + m.bite.windup + m.bite.active + m.bite.recovery + 10.0), "spent, its part open",
		"a keeper standing spent says so")


func test_a_keeper_is_the_biggest_thing_on_its_landscapes_roster() -> void:
	for def: SentinelDef in Sentinels.all():
		var mine := Roster.health_of(def.kind)
		for kind: StringName in BiomeRegistry.get_def(def.land).roster:
			gt(float(mine), float(Roster.health_of(kind)), "%s outlasts the %s that work its land" % [def.kind, kind])
