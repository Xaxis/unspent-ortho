extends TestCase
## THE VEIL (mod_veil, AbilityVeil, FightSim.veils): the drip-warden's core,
## turned. A curtain of water falls ahead for 12 s that a machine's sight does
## not pass, and nothing else notices: a dart that loses you breaks off, a
## thrower cannot aim across it, and bodies, blows and sound go through. It soaks
## you and puts your lamp out while it falls.
##
## Its bar, set before it was built, over the shoulder (16 bouts a crowd): two
## darts take fewer things than bare; a thrower with a cutter costs less health;
## three harvesters and two cutters no worse; and a walk past twelve hunters
## rouses no more of them.

const F := preload("res://tests/fight/fixture.gd")
const Sx := preload("res://tests/save/save_fixture.gd")
const SR := preload("res://tests/fight/shoulder_reader.gd")


func test_their_sight_does_not_pass_it_and_nothing_else_notices_it() -> void:
	var sim := F.make_sim(F.flat_world(48), Vector2(20.5, 20.5))
	var ahead := Vector2(26.5, 20.5)
	var aside := Vector2(20.5, 26.5)
	check(Senses.line_clear(sim.world, sim.query, ahead, sim.hero.pos), "bare, a body ahead sees the player")
	sim.veil(Vector2.RIGHT)
	check(not Senses.line_clear(sim.world, sim.query, ahead, sim.hero.pos), "veiled, it does not")
	check(Senses.line_clear(sim.world, sim.query, aside, sim.hero.pos), "one off to the side still does")
	var row := Roster.row(&"runner")
	var near_ahead := Vector2(22.5, 20.5)
	check(not Senses.sees(row, near_ahead, sim.hero.pos, sim.moment, sim.world, sim.query, PI), "a runner two tiles off cannot see through it")
	check(Senses.hears(row, near_ahead, sim.hero.pos, sim.moment), "but hears as through air")
	check(Senses.notices(row, near_ahead, sim.hero.pos, sim.moment, sim.world, sim.query, PI), "and so still notices")
	# A body walks through it.
	var m := F.still(sim, &"runner", ahead, PI)
	m.want = Vector2.LEFT * 3.0
	m.calm_until = INF
	var before := m.pos.x
	for i in 60:
		m.want = Vector2.LEFT * 3.0
		F.ms(sim, 16)
	lt(m.pos.x, before - 2.0, "a body walks through the water (%.2f from %.2f)" % [m.pos.x, before])
	F.ms(sim, FightSim.VEIL_MS)
	check(Senses.line_clear(sim.world, sim.query, ahead, sim.hero.pos), "and after its time it has fallen")
	eq(sim.veils.size(), 0, "gone")


func test_a_dart_that_loses_you_breaks_off() -> void:
	var bare := _dart_run(false)
	var veiled := _dart_run(true)
	print("  info a dart diving from 7 tiles: %d snatches bare, %d behind the veil" % [bare, veiled])
	gt(float(bare), 0.0, "bare, the dart gets its snatch")
	eq(veiled, 0, "behind the veil it breaks off")


func _dart_run(veil: bool) -> int:
	MobState._next_id = 3000
	var sim := F.make_sim(F.flat_world(48), Vector2(20.5, 20.5))
	sim.hero.inventory.add(&"scrap", 3)
	var m := sim.add_mob(&"flock", Vector2(27.5, 20.5))
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	if veil:
		sim.veil(Vector2.RIGHT)
	var n := 0
	for i in 150:
		F.ms(sim, 16)
		n += F.count(sim.drain(), &"snatch")
	return n


func test_a_thrower_does_not_throw_across_it() -> void:
	MobState._next_id = 3100
	var sim := F.make_sim(F.flat_world(48), Vector2(20.5, 20.5))
	var m := sim.add_mob(&"sorter", Vector2(25.0, 20.5))
	m.disturbed = true
	m.set_mood(MobState.ATTACKING, sim.now)
	sim.veil(Vector2.RIGHT)
	var across := 0
	for i in 200:
		var was := m.blow_at
		F.ms(sim, 16)
		if m.blow_at != was and sim.veiled(m.pos, sim.hero.pos):
			across += 1
	eq(across, 0, "no throw is begun with the veil between")


func test_the_key_lets_it_fall_and_it_soaks_you() -> void:
	Sx.use_root("veil")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0", "--fit=cloak_vane,mod_veil", "--give=wick:4,lamp:1,oil:2"])
	var gear := Sx.system(g, "54_gear")
	var sim: FightSim = g.player.sim
	g.body.wet = 0.0
	g.body.lamp_lit = true
	eq(gear.call(&"fire", &"veil"), &"", "the veil falls")
	eq(sim.veils.size(), 1, "a veil stands")
	eq(g.inventory.count(&"wick"), 2, "for two charges")
	gt(g.body.wet, 0.29, "it soaks you")
	check(not g.body.lamp_lit, "and puts your lamp out")
	var lights := Sx.system(g, "15_lights")
	lights.call(&"toggle_lantern")
	check(not g.body.lamp_lit, "which will not light while the water falls")
	eq(gear.call(&"fire", &"veil"), &"cooling", "and it has to come back")
	Sx.end(g)


## THE BAR. A bout over the shoulder against a mixed crowd, bare or with the veil
## (and the charges to let it fall), 16 bouts of at most `ms`: {won, lost,
## taken, veils}. With `any` the reader lets it fall on whatever comes.
func _bouts(kinds: Array[StringName], veil: bool, ms: float = 60000.0, any: bool = false) -> Dictionary:
	var won := 0
	var lost := 0
	var taken := 0
	var let := 0
	for i in 16:
		var r := _bout(kinds, veil, i % 8, 1000 + i / 8, ms, any)
		won += int(r.won)
		lost += int(r.lost)
		taken += int(r.taken)
		let += int(r.veils)
	return {"won": won, "lost": float(lost) / 16.0, "taken": float(taken) / 16.0, "veils": float(let) / 16.0}


func _bout(kinds: Array[StringName], veil: bool, start: int, ids: int, ms: float, any: bool) -> Dictionary:
	MobState._next_id = ids
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	sim.hero.inventory.add(&"scrap", 4)
	if veil:
		sim.hero.inventory.add(FightRules.CHARGE, 8)
		sim.hero.kit = FightKit.of([&"mod_veil"] as Array[StringName])
	var a := float(start) / 8.0 * TAU
	var mid := sim.hero.pos + Vector2.from_angle(a) * 5.0
	var side := Vector2.from_angle(a).orthogonal()
	var crowd: Array[MobState] = []
	for k in kinds.size():
		var m := sim.add_mob(kinds[k], mid + side * (float(k) - 0.5 * float(kinds.size() - 1)) * 1.1)
		m.facing = (sim.hero.pos - m.pos).angle()
		m.aim = m.facing
		m.disturbed = true
		m.set_mood(MobState.CHASING, sim.now)
		crowd.append(m)
	var player := SR.new(sim)
	player.veil_any = any
	sim.hero.facing = (mid - sim.hero.pos).angle()
	var t := 0.0
	var lost := 0
	var taken := 0
	while t < ms:
		player.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hurt":
				lost += int(e.damage)
			if e.type == &"snatch":
				taken += 1
			if e.type == &"outcome" and e.outcome in [&"downed", &"carried"]:
				return {"won": false, "lost": lost, "taken": taken, "veils": player.veils_let}
		var left := 0
		for m in crowd:
			left += int(m.alive and not m.snatched)
		if left == 0:
			return {"won": true, "lost": lost, "taken": taken, "veils": player.veils_let}
	return {"won": false, "lost": lost, "taken": taken, "veils": player.veils_let}


## A flock snatches once and is gone with it (MobState.snatched is the flock's),
## so over a whole minute the veil can only put the snatch off: the bar is the
## dive it meets, the veil's own time.
func test_the_veil_bout() -> void:
	var darts: Array[StringName] = [&"flock", &"flock"]
	var b := _bouts(darts, false, FightSim.VEIL_MS)
	var w := _bouts(darts, true, FightSim.VEIL_MS)
	var bm := _bouts(darts, false)
	var wm := _bouts(darts, true)
	print("  info 2 darts, the veil's 12 s: bare took %.2f; veiled took %.2f (%.1f veils a bout). Over a minute: %.2f and %.2f" % [b.taken, w.taken, w.veils, bm.taken, wm.taken])
	lt(w.taken, b.taken, "two darts take fewer things in the dive the veil meets")
	var thrower: Array[StringName] = [&"sorter", &"cutter"]
	b = _bouts(thrower, false)
	w = _bouts(thrower, true)
	print("  info a thrower and a cutter: bare won %d/16 losing %.2f; veiled won %d/16 losing %.2f (%.1f veils)" % [b.won, b.lost, w.won, w.lost, w.veils])
	lt(w.lost, b.lost, "a thrower with a cutter costs less health")
	var crowd: Array[StringName] = [&"harvester", &"harvester", &"harvester", &"cutter", &"cutter"]
	b = _bouts(crowd, false)
	w = _bouts(crowd, true, 60000.0, true)
	print("  info 3 harvesters and 2 cutters: bare won %d/16 losing %.2f; veiled won %d/16 losing %.2f (%.1f veils)" % [b.won, b.lost, w.won, w.lost, w.veils])
	gt(w.veils, 0.5, "it was let fall on them")
	gt(float(w.won), float(b.won) - 1.5, "chargers and biters: no fewer won")
	lt(w.lost, b.lost + 0.35, "and no more lost")


## THE WALK: past twelve idle hunters off the path, the veil let fall ahead every
## time it is ready, as the listener's cost test walks: it rouses no more of them.
func _walk(veil: bool) -> int:
	MobState._next_id = 2000
	var sim := F.make_sim(F.flat_world(96), Vector2(20.5, 48.5))
	var mobs: Array[MobState] = []
	for k in 12:
		var s := 1.0 if k % 2 == 0 else -1.0
		var m := sim.add_mob(&"runner", Vector2(26.0 + k * 4.0, 48.5 + s * (11.0 + (k % 4) * 1.2)))
		m.facing = s * PI * 0.5
		m.aim = m.facing
		mobs.append(m)
	sim.hero.facing = 0.0
	sim.hero.move = Vector2.RIGHT
	var t := 0.0
	var next := 0.0
	while t < 16000.0:
		if veil and t >= next:
			sim.veil(Vector2.RIGHT)
			next = t + AbilityVeil.COOLDOWN * 1000.0
		F.ms(sim, 100)
		t += 100.0
	var roused := 0
	for m in mobs:
		roused += int(m.mood != MobState.IDLE and m.mood != MobState.WORKING)
	return roused


func test_a_walk_past_hunters_is_no_louder_for_it() -> void:
	var bare := _walk(false)
	var veiled := _walk(true)
	print("  info a walk past twelve hunters: %d come bare, %d with the veil" % [bare, veiled])
	lt(float(veiled), float(bare) + 0.5, "the veil rouses no more of them")
