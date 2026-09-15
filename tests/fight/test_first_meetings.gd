extends TestCase
## The first meetings, headless, with the start kit: a half-worn knife and a
## body at full health. A player with human reactions who reads the tell, gets
## out of its way and strikes the working side while the machine is spent
## (reader.gd) beats a runner, a yard dog and a harvester from every side they
## can be met on, never put down. A careless player (masher.gd) who walks in and
## swings loses to the machines. If either half fails after a change, the first
## hour is unfair or the reading is not the skill.

const F := preload("res://tests/fight/fixture.gd")
const Reader := preload("res://tests/fight/reader.gd")
const Masher := preload("res://tests/fight/masher.gd")

const START_EDGE := 5000
const FIRST: Array[StringName] = [&"runner", &"dog.yard", &"harvester"]
## Directions the body is met from and the way it faces (8 x 2 starts per kind).
const STARTS := 8


static func bout(kind: StringName, careful: bool, start: int, seconds: float = 60.0, react_ms: float = 220.0) -> Dictionary:
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	sim.hero.inventory.set_edge(&"knife", START_EDGE)
	var a := float(start % STARTS) / STARTS * TAU
	var at := sim.hero.pos + Vector2.from_angle(a) * 5.0
	var m := sim.add_mob(kind, at)
	# Half the starts it faces the player; half it is turned across.
	m.facing = (sim.hero.pos - at).angle() + (0.0 if start % 2 == 0 else PI * 0.5)
	m.aim = m.facing
	if m.disposition == &"indifferent":
		# A worker is met on its round: the player starts it by striking it.
		m.line_a = at - Vector2.from_angle(m.facing) * 3.0
		m.line_b = at + Vector2.from_angle(m.facing) * 3.0
	var player: Variant = Reader.new(sim) if careful else Masher.new(sim)
	if careful:
		player.react_ms = react_ms
	var hurts := 0
	var outcome := &""
	var t := 0.0
	var opened := 0
	var hits := 0
	while t < seconds * 1000.0:
		player.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			match e.type:
				&"hurt": hurts += int(e.damage)
				&"opened": opened += 1
				&"hit":
					if not e.plate and e.target == m:
						hits += 1
				&"outcome":
					if e.outcome != &"away":
						outcome = e.outcome
		if outcome != &"" or not m.alive:
			break
	var downed := outcome == &"downed" or outcome == &"carried"
	return {"kind": kind, "start": start, "won": not m.alive and not downed, "downed": downed,
		"t": snappedf(t / 1000.0, 0.1), "lost_health": hurts, "hits": hits, "opened": opened, "left": m.health}


func test_a_careful_first_hour_player_beats_each_first_meeting_from_every_start() -> void:
	for kind in FIRST:
		var lost := 0
		var longest := 0.0
		for i in STARTS * 2:
			var r := bout(kind, true, i)
			check(r.won, "%s from start %d was not beaten by a careful player: %s" % [kind, i, r])
			check(not r.downed, "%s put a careful player down: %s" % [kind, r])
			lost += int(r.lost_health)
			longest = maxf(longest, float(r.t))
		print("  info first meeting %s: careful player lost %.1f health a bout, longest %.1f s" % [kind, float(lost) / (STARTS * 2), longest])
		lt(float(lost) / (STARTS * 2), FightRules.HEALTH * 0.5, "%s is won with health to spare on average" % kind)


## Slow eyes still win most first meetings: a quarter of a second late to every
## tell is a player learning, not a player who cannot.
func test_a_slow_reader_still_wins_most_first_meetings() -> void:
	for kind in FIRST:
		var won := 0
		var lost := 0
		for i in STARTS:
			var r := bout(kind, true, i, 60.0, 320.0)
			won += int(r.won)
			lost += int(r.lost_health)
		print("  info slow reader against %s: won %d of %d, lost %d health" % [kind, won, STARTS, lost])
		gt(float(won), STARTS * 0.74, "%s is still fair to slow eyes" % kind)


func test_a_careless_player_loses_to_the_first_machines() -> void:
	for kind: StringName in [&"runner", &"harvester"]:
		var losses := 0
		for i in STARTS:
			var r := bout(kind, false, i)
			if r.downed or not r.won:
				losses += 1
		print("  info careless against %s: lost %d of %d" % [kind, losses, STARTS])
		gt(float(losses), STARTS * 0.74, "%s beats a player who walks in swinging" % kind)


## A knife outreaches a yard dog's bite: walking in swinging can win against a
## dog, but reading it never costs more than not.
func test_reading_a_dog_never_costs_more_than_rushing_it() -> void:
	var careful := 0
	var careless := 0
	for i in STARTS:
		careful += int(bout(&"dog.yard", true, i).lost_health)
		careless += int(bout(&"dog.yard", false, i).lost_health)
	print("  info dog: careful lost %d, careless lost %d over %d bouts" % [careful, careless, STARTS])
	check(careful <= careless, "the careful player lost %d, the careless %d" % [careful, careless])


func test_the_half_worn_start_knife_out_damages_fists() -> void:
	gt(float(Blow.for_item(&"knife", START_EDGE).dmg), float(Blow.fists().dmg), "the start knife")
	eq(FightRules.damage_at_edge(2, START_EDGE), 2, "half an edge keeps its bite")
	eq(FightRules.damage_at_edge(2, FightRules.KEEN_EDGE - 1), 1, "a truly dull knife is a fist")
	eq(FightRules.damage_at_edge(4, 0), 1, "a dull edge still does 1")
	eq(FightRules.damage_at_edge(1, 10000), 1, "the floor never lifts a tool past its own bite")
