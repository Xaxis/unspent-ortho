extends TestCase
## THE PLOUGH (src/core/sentinel/designs/plough.gd): the Snowfield's keeper and
## its ground rule (FightSim furrows). A body whose row `bogs` in a ground wallows
## there -- half its pace, no run -- unless it stands on a furrow; everywhere it
## goes it leaves a furrow behind it, packed ice it runs on at full speed; a run
## carried off its furrow into the drifts bogs and stalls (once per
## STALL_EVERY_MS). The fight is played on its lanes: stand off them.

const F := preload("res://tests/fight/fixture.gd")


func _sim() -> FightSim:
	return F.make_sim(F.flat_world(64, Ground.SNOW), Vector2(32.5, 32.5))


func _plough(sim: FightSim, at: Vector2, facing: float) -> MobState:
	var def := Sentinels.for_land(&"snowfield")
	var m := sim.add_mob(def.kind, at)
	Sentinels.own_row(m)
	Sentinels.wear_phase(m, def, 0)
	m.facing = facing
	m.aim = facing
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	return m


func test_the_snowfield_keeps_a_plough() -> void:
	var def := Sentinels.for_land(&"snowfield")
	check(def != null and def.id == &"plough", "the snowfield names the plough")
	if def != null:
		check((Roster.row(def.kind).get("bogs", []) as Array).has(Ground.SNOW), "its body bogs in snow")


func test_it_leaves_a_furrow_where_it_goes() -> void:
	var sim := _sim()
	var m := _plough(sim, sim.hero.pos + Vector2(10.0, 0.0), PI)
	var from := m.pos
	F.ms(sim, 3000)
	check(m.pos.distance_to(from) > 1.5, "it came on (%.1f tiles)" % m.pos.distance_to(from))
	check(sim.on_furrow(from.lerp(m.pos, 0.3)), "and left a furrow where it went")
	check(not sim.on_furrow(sim.hero.pos + Vector2(0.0, 8.0)), "and nowhere it did not")


func test_in_the_drifts_it_wallows_and_on_its_furrow_it_runs() -> void:
	var sim := _sim()
	var m := _plough(sim, sim.hero.pos + Vector2(10.0, 0.0), PI)
	check(sim.bogged(m), "in untouched snow it is bogged")
	var ran := false
	for i in 120:
		sim.slices(1)
		ran = ran or m.charging
	check(not ran, "and no run starts there")
	# A lane ploughed ahead of it, all the way to the player: now it runs.
	var lane := _sim()
	var p := _plough(lane, lane.hero.pos + Vector2(10.0, 0.0), PI)
	for x in range(-1, 12):
		lane.plough_at(lane.hero.pos + Vector2(float(x), 0.0))
	check(not lane.bogged(p), "on its furrow it is not")
	var ran2 := false
	for i in 240:
		lane.slices(1)
		ran2 = ran2 or p.charging
	check(ran2, "and it runs along it")


func test_a_run_carried_off_its_furrow_bogs_and_stalls() -> void:
	var sim := _sim()
	var m := _plough(sim, sim.hero.pos + Vector2(10.0, 0.0), PI)
	# A short lane under it, then drifts between it and the player.
	for x in range(7, 12):
		sim.plough_at(sim.hero.pos + Vector2(float(x), 0.0))
	var stalled_in_snow := false
	var bogs := 0
	for i in 400:
		sim.slices(1)
		stalled_in_snow = stalled_in_snow or (m.stunned(sim.now) and sim.bogged(m))
		for e in sim.drain():
			bogs += int(e.type == &"bogged")
	gt(float(bogs), 0.5, "the run off its lane bogs (%d)" % bogs)
	check(stalled_in_snow, "and it stands stalled in the drift")
