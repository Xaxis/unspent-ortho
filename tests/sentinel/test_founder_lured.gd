extends TestCase
## THE FLATS TAKE A KEEPER THAT IS LURED ONTO THEM, NOT ONE A FIGHT SPILLS ONTO
## (44_sentinels look_at, SentinelWay FOUNDER). Its hold on the ground it
## founders in counts only while the player is out there drawing it (or was, a
## moment ago) and it is not standing spent after a bite or stopped by a blow: on
## seed 1's shore a fight by force overran into the shallows and the Reaper
## foundered about 20 s into a fight nobody meant as a lure.

const Sx := preload("res://tests/save/save_fixture.gd")
const F := preload("res://tests/fight/fixture.gd")


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
	# A second tile of it, where a player drawing it out stands.
	var out_there := Vector2.INF
	for k in 24:
		var p := flat + Vector2.from_angle(TAU * k / 24.0) * 3.0
		if way.grounds.has(g.world.ground_at(floori(p.x), floori(p.y))) and g.query.standable(floori(p.x), floori(p.y)):
			out_there = p
			break
	check(out_there.is_finite(), "room out on the flats for the player")
	var b: Blow = m.bite
	# 1. A fight that spilled there: the player on firm ground, it stands on the
	# flats, its stand over. It does not founder.
	var t0 := sim.now
	while sim.now - t0 < way.hold_ms * 2.5:
		g.player.hero.pos = near
		m.pos = flat
		m.want = Vector2.ZERO
		m.calm_until = INF
		m.blow = null
		await tree.physics_frame
	check(not reaper.fallen, "spilled onto the flats with the player on firm ground, it does not founder")
	# 2. Drawn out, but standing spent after a bite: not yet.
	t0 = sim.now
	while sim.now - t0 < way.hold_ms * 2.5:
		g.player.hero.pos = out_there
		m.pos = flat
		m.want = Vector2.ZERO
		m.blow = b
		m.blow_at = sim.now - float(b.windup + b.active) - 16.0
		m.landed_at = -INF
		await tree.physics_frame
	check(not reaper.fallen, "drawn out but spent after a bite, it does not founder yet")
	# 3. Drawn out, its stand over, held there: the flats take it.
	m.blow = null
	t0 = sim.now
	while sim.now - t0 < way.hold_ms * 2.5 and not reaper.fallen:
		g.player.hero.pos = out_there
		m.pos = flat
		m.want = Vector2.ZERO
		await tree.physics_frame
	check(reaper.fallen and reaper.how == way.id(), "drawn out and held there with its stand over, it founders (%s)" % reaper.how)
	Sx.end(g)


## Where a lure draws a keeper out (Sentinels.founder_spot, a tour's `near
## keeper_flats`), its run at a player standing there stops on the ground it
## founders in: where its bite reaches (Sentinels.lure_stop) back toward its den.
## At the sand's edge the anvil's run stopped on its own rock and it bit from
## there, never foundering (the strike field's den, second-keeper).
func test_the_lure_stands_where_its_run_ends_on_the_ground_it_founders_in() -> void:
	var w := F.flat_world(64, Ground.ROCK, Country.COAST, 7)
	for y in 64:
		for x in 64:
			if x >= 30:
				w.ground[y * 64 + x] = Ground.SAND
	var def := Sentinels.by_id(&"anvil")
	var den := Vector2(15.5, 30.5)
	var spot := Sentinels.founder_spot(w, den, def)
	check(spot.is_finite(), "there is a spot on the sand")
	if not spot.is_finite():
		return
	var sink := Sentinels.founders(def)
	var stop := spot - (spot - den).normalized() * Sentinels.lure_stop(def)
	check(sink.has(w.ground_at(floori(spot.x), floori(spot.y))), "the spot is on the sand (%s)" % spot)
	check(sink.has(w.ground_at(floori(stop.x), floori(stop.y))), "and its run at the player there ends on the sand too (stops at %s)" % stop)
