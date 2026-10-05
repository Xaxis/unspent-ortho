extends TestCase
## The second keeper, the anvil (src/core/sentinel/designs/anvil.gd), taken every
## way it offers, by what a player does: the plate player through the game's
## input (tests/sentinel/keeper_fight.gd), on the nearest anvil to where a new
## game wakes, on seeds 1 and 7. Force is its three sides in order, from ground
## its skates keep to; founder is a lure out onto drift sand, far enough off that
## its charge, not its step, carries it there; starve is every rod of the strike
## field it keeps robbed by hand (KF.rob_larder), and the dark waited on.

const Sx := preload("res://tests/save/save_fixture.gd")
const KF := preload("res://tests/sentinel/keeper_fight.gd")
const PR := preload("res://tests/fight/plate_reader.gd")

## Tiles off its lair the lure stands, nearest first: close in, it bites from
## the edge of its plates and never steps off them; out to where it still sees
## him from its den (Sentinels.lure_reach, 18 for the anvil).
const LURE_AT: Array[float] = [10.0, 12.0, 8.0, 14.0, 16.0, 18.0]
## How far into the sand the lure stands: a run at him stops where its bite
## reaches (Brains.strike_range: its middle the two radii and four fifths of the
## reach off), and its middle there has to be on the sand with LURE_SPARE to
## spare. A flat three tiles was under the anvil's 3.12: on seed 7 its run ended
## a fifth of a tile short of the sand and it bit from its own ground, four
## tries (9d5d9919). Stood at the sand's very edge it never foundered at all
## (the drowned city's world, seeds 1 and 7).
const LURE_SPARE := 1.0
## The hour the force fights start: after the sun is down. By day the glass's
## glare (0.7), heat and thirst press a body past Hazards.BITE and his run falls
## to 59-71% at the strike field's den on seed 7, and no opening of the skating
## side lasts the walk to its back; a person comes at another hour. The glare goes
## only with the sun (Hazards._hour_shift, on Weather.night_fall), so no daylight
## hour is without it: it is 0.7 until 18:30 and under BITE from 19:16. At 20:00
## night_fall is 0.65, the glare 0.27, heat 0.35, thirst 0.43, none biting, and
## the light 73% of day (Weather.light_level, whose night floor is 58%): dusk-lit,
## nearer day than night, so a person still reads the anvil. A fight (1.4 clock
## minutes a second) only carries the glare further down, where one begun at
## dawn would walk into it by 06:00.
const FORCE_HOUR := 20.0


func _anvil(g: Game) -> SentinelState:
	var best: SentinelState = null
	for s: SentinelState in Sx.system(g, "44_sentinels").call(&"states"):
		if s.design == &"anvil" and (best == null or s.lair.distance_to(g.player.pos) < best.lair.distance_to(g.player.pos)):
			best = s
	return best


## Where a run at a player on the lure stops, plus the spare: the keeper's
## first-phase strike range (Brains.strike_range) and LURE_SPARE.
static func _lure_depth(s: SentinelState) -> float:
	var def := Sentinels.by_id(s.design)
	var reach := float(def.phase(0).bite.get("reach", 0.6))
	return float(Roster.row(def.kind).get("radius", 0.5)) + Tuning.PLAYER_RADIUS + reach * 0.8 + LURE_SPARE


## The fight on `seed_value`, `way` force or founder. Returns the tally, or {}
## with the reason checked.
func _take(seed_value: int, way: int) -> Dictionary:
	Sx.use_root("anvil-%d" % seed_value)
	var hour := FORCE_HOUR if way == SentinelWay.FORCE else 11.0
	var g := await Sx.played(tree, ["--seed=%d" % seed_value, "--hour=%s" % hour, "--weather=clear:0", "--held=knife_shear"])
	# Bodies numbered from the same place whatever ran before in this process:
	# the reader's hands are hashed on a body's id (Reader.human).
	MobState._next_id = 900000
	var s := _anvil(g)
	check(s != null, "seed %d holds an anvil" % seed_value)
	if s == null:
		Sx.end(g)
		return {}
	KF.calm(g)
	var sand: Array = Sentinels.by_id(s.design).way_of(SentinelWay.FOUNDER).grounds
	var r: Variant = PR.new(g.player.sim)
	r.human = 1
	var at := Vector2.INF
	if way == SentinelWay.FORCE:
		at = KF.stand(g, s, 6.0, sand, false)
		r.keep_off = sand
		r.home = at
	else:
		var lure := Vector2.INF
		for dist: float in LURE_AT:
			lure = KF.stand(g, s, dist, sand, true, _lure_depth(s))
			if lure.is_finite():
				break
		check(lure.is_finite(), "sand to draw it onto on seed %d" % seed_value)
		if lure.is_finite():
			at = s.lair + (lure - s.lair).normalized() * 5.0
			r.keep_on = sand
			r.lure = lure
			r.home = at
	if not at.is_finite():
		Sx.end(g)
		return {}
	var out: Dictionary = await KF.fight(tree, g, s, at, r, 240.0)
	Sx.end(g)
	return out


func _falls(seed_value: int, way: int) -> void:
	var out := await _take(seed_value, way)
	if out.is_empty():
		return
	var id := SentinelWay.make(way).id()
	print("  info anvil on seed %d by %s: %s" % [seed_value, id, out])
	check(out.fallen and out.how == id, "the anvil on seed %d falls by %s (%s)" % [seed_value, id, out])
	lt(float(out.tries), 3.5, "in a few tries (%d)" % out.tries)


func test_by_force_on_seed_1_it_falls_side_by_side() -> void:
	if not stepped_now():
		return
	await _falls(1, SentinelWay.FORCE)


func test_by_force_on_seed_7_it_falls_side_by_side() -> void:
	if not stepped_now():
		return
	await _falls(7, SentinelWay.FORCE)


func test_lured_onto_the_sand_on_seed_1_it_founders() -> void:
	if not stepped_now():
		return
	await _falls(1, SentinelWay.FOUNDER)


func test_lured_onto_the_sand_on_seed_7_it_founders() -> void:
	if not stepped_now():
		return
	await _falls(7, SentinelWay.FOUNDER)


## STARVE, by hand. The tally says what it cost against the force fight above:
## sim seconds, clock minutes and the tiles walked from rod to rod.
func _starves(seed_value: int) -> void:
	Sx.use_root("anvil-starve-%d" % seed_value)
	# A field's rods are hours of the clock (an 18-minute turn each): a player
	# going to rob them carries something to eat.
	var g := await Sx.played(tree, ["--seed=%d" % seed_value, "--hour=9", "--weather=clear:0", "--held=knife_shear", "--give=fish:6"])
	MobState._next_id = 900000
	var s := _anvil(g)
	check(s != null, "seed %d holds an anvil" % seed_value)
	if s == null:
		Sx.end(g)
		return
	KF.calm(g)
	var def := Sentinels.by_id(s.design)
	var out: Dictionary = await KF.rob_larder(tree, g, s)
	print("  info anvil on seed %d by starve: %s" % [seed_value, out])
	gt(float(out.works), float(SentinelWay.FEEDS_LEAST) - 0.5, "seed %d: its field feeds it %d rods" % [seed_value, out.works])
	eq(out.robbed, out.works, "seed %d: every rod is robbed out" % seed_value)
	g.player.place(s.lair + Vector2(Sentinels.PUT_OUT * 2.0, 0.0))
	var t0 := g.player.sim.now
	while not s.fallen and g.player.sim.now - t0 < 12000.0:
		await tree.physics_frame
	check(s.fallen and s.how == def.way_of(SentinelWay.STARVE).id(), "seed %d: and it stands dark (%s)" % [seed_value, s.how])
	Sx.end(g)


func test_robbed_of_its_rods_on_seed_1_it_starves() -> void:
	if not stepped_now():
		return
	await _starves(1)


func test_robbed_of_its_rods_on_seed_7_it_starves() -> void:
	if not stepped_now():
		return
	await _starves(7)
