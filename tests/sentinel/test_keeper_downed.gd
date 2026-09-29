extends TestCase
## DOWNED BY A KEEPER, THE NEXT TRY IS A TRY (Sentinels.arena_edge, 40_fight's
## downed outcome): the player comes to at the edge of the ground round its lair
## that puts it out, on ground joined to it, hours later, and the keeper keeps
## what the last try cost it. Woken where they fell (seed 1, the Tide Reaper),
## it was put out again on top of a player at 3 health: every try after the first
## was one bite long.

const Sx := preload("res://tests/save/save_fixture.gd")


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func test_a_player_the_reaper_downs_comes_to_at_the_edge_of_its_ground() -> void:
	Sx.use_root("keeper-downed")
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
	var at := Vector2.INF
	for k in 16:
		var p := reaper.lair + Vector2.from_angle(TAU * k / 16.0) * 6.0
		if g.query.standable(floori(p.x), floori(p.y)) and g.world.same_body(p, reaper.lair):
			at = p
			break
	g.player.place(at)
	await _frames(4)
	var m: MobState = reaper.body
	check(m != null, "it is out")
	if m == null:
		Sx.end(g)
		return
	m.health -= 9
	var wounds := m.health
	var before := g.clock.minutes
	# Its bite takes the last of the player's health.
	sim.hero.last_hit_by = m
	sim.hero.last_hit_at = sim.now
	sim.hero.health = 0
	sim._end(&"downed")
	await _frames(4)
	var here := g.player.pos
	gt(g.clock.minutes - before, 60.0, "hours have gone (%.0f min)" % (g.clock.minutes - before))
	gt(Senses.chebyshev(here, reaper.lair), Sentinels.PUT_OUT, "they come to past the ground that puts it out (%.1f tiles off its lair)" % Senses.chebyshev(here, reaper.lair))
	lt(here.distance_to(reaper.lair), Sentinels.PUT_OUT * 2.0, "at its edge, not somewhere else (%.1f)" % here.distance_to(reaper.lair))
	check(g.world.same_body(here, reaper.lair), "on ground joined to its lair")
	check(g.query.body_fits(here, Tuning.PLAYER_RADIUS, null, true, FightSim.HERO_TALL), "stood whole")
	await _frames(10)
	check(reaper.body == null, "and it is not put out on top of them")
	eq(reaper.health, wounds, "it keeps what the try cost it")
	Sx.end(g)


## Downed by something else (hunger, the cold) long after the keeper's last
## blow, the player is not the keeper's: they come to where they fell, and its
## toll is not charged. The last blow the body took was read as the down's cause
## however old it was, so a player starving at the far end of a pipe woke at the
## Reaper's edge (test_ways, starving it by hand).
func test_a_down_long_after_its_blow_is_not_the_keepers() -> void:
	Sx.use_root("keeper-downed-late")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	var sim: FightSim = g.player.sim
	var reaper: SentinelState = null
	for s: SentinelState in Sx.system(g, "44_sentinels").call(&"states"):
		if s.land == &"coast" and not s.fallen and s.region >= 0:
			reaper = s
			break
	var at := reaper.lair + Vector2(Sentinels.PUT_OUT + 6.0, 0.0)
	for k in 16:
		var p := reaper.lair + Vector2.from_angle(TAU * k / 16.0) * (Sentinels.PUT_OUT + 6.0)
		if g.query.standable(floori(p.x), floori(p.y)):
			at = p
			break
	var m := sim.add_mob(Sentinels.for_land(&"coast").kind, reaper.lair)
	g.player.place(at)
	await frames(3)
	var here := g.player.pos
	# Its blow, a minute of the fight ago; then the body gives out.
	sim.hero.last_hit_by = m
	sim.hero.last_hit_at = sim.now - 60000.0
	sim.hero.health = 0
	sim._end(&"downed")
	await frames(4)
	lt(g.player.pos.distance_to(here), 2.0, "they come to where they fell (%.1f tiles off)" % g.player.pos.distance_to(here))
	Sx.end(g)
