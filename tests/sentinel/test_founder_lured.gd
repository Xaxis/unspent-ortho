extends TestCase
## THE FLATS TAKE A KEEPER THAT IS LURED ONTO THEM, NOT ONE A FIGHT SPILLS ONTO
## (44_sentinels look_at, SentinelWay FOUNDER). Standing spent after a bite (its
## recovery and cooldown, MobState.spent) or stopped by a blow, its hold on the
## ground it founders in does not count: on seed 1's shore a fight by force
## overran into the shallows and stood there its 1.7 s, and the Reaper foundered
## about 20 s into a fight nobody meant as a lure. Standing there with the stand
## over, it founders as it always did.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_it_founders_where_it_stands_not_where_its_bite_spent_it() -> void:
	Sx.use_root("founder-lured")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	var sys := Sx.system(g, "44_sentinels")
	var sim: FightSim = g.player.sim
	var reaper: SentinelState = null
	for s: SentinelState in sys.call(&"states"):
		if s.land == &"coast" and not s.fallen and s.region >= 0:
			reaper = s
			break
	check(reaper != null, "seed 1 holds a reaper")
	if reaper == null:
		Sx.end(g)
		return
	var def := Sentinels.by_id(reaper.design)
	var way := def.way_of(SentinelWay.FOUNDER)
	# A tile of the ground it founders in, near its lair, that it can stand on.
	var flat := Vector2.INF
	for r in range(1, 14):
		for k in 24:
			var p := reaper.lair + Vector2.from_angle(TAU * k / 24.0) * float(r)
			if way.grounds.has(g.world.ground_at(floori(p.x), floori(p.y))):
				flat = Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
				break
		if flat.is_finite():
			break
	check(flat.is_finite(), "its shore has flats")
	var near := reaper.lair + (flat - reaper.lair).normalized() * -8.0
	g.player.place(near)
	await frames(4)
	var m: MobState = reaper.body
	check(m != null, "it is out")
	if m == null or not flat.is_finite():
		Sx.end(g)
		return
	# Stood spent on the flats, well past its hold, the stand renewed each frame.
	var b: Blow = m.bite
	var t0 := sim.now
	while sim.now - t0 < way.hold_ms * 2.5:
		m.pos = flat
		m.want = Vector2.ZERO
		m.calm_until = INF
		m.blow = b
		m.blow_at = sim.now - float(b.windup + b.active) - 16.0
		m.landed_at = -INF
		await tree.physics_frame
	check(not reaper.fallen, "spent on the flats after a bite, it does not founder (%.1f s there)" % ((sim.now - t0) / 1000.0))
	# Its stand over, still stood there: the flats take it.
	m.blow = null
	t0 = sim.now
	while sim.now - t0 < way.hold_ms * 2.5 and not reaper.fallen:
		m.pos = flat
		m.want = Vector2.ZERO
		await tree.physics_frame
	check(reaper.fallen and reaper.how == way.id(), "stood there with its stand over, it founders (%s)" % reaper.how)
	Sx.end(g)
