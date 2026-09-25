extends TestCase
## Whole fights, headless. A player who stands still is put down (a worker only
## once it has been struck); a player who reads the machine (reader.gd: human
## reactions, gets out of the tell, walks round to the working part while it is
## open) beats every kind with a knife and is never put down. If this fails
## after a change, the fight became unfair or trivial.

const F := preload("res://tests/fight/fixture.gd")
const Bot := preload("res://tests/fight/reader.gd")
const FirstMeetings := preload("res://tests/fight/test_first_meetings.gd")


func _bout(kind: StringName, use_bot: bool, seconds: float, heavy: bool = false, kit: Array[StringName] = []) -> Dictionary:
	var ground := Ground.WATER if kind == &"dredger" else Ground.GRASS
	var sim := F.make_sim(F.flat_world(96, ground), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	sim.hero.kit = FightKit.of(kit)
	var m := sim.add_mob(kind, Vector2(53.5, 48.5))
	m.facing = PI
	m.aim = PI
	if not use_bot and m.disposition == &"indifferent":
		# A worker leaves a still player be: this one has already been struck.
		m.disturbed = true
		m.set_mood(MobState.ATTACKING, sim.now)
	var bot := Bot.new(sim)
	bot.heavy = heavy
	var hurts := 0
	var outcome := &""
	var t := 0.0
	while t < seconds * 1000.0:
		if use_bot:
			bot.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hurt":
				hurts += 1
			elif e.type == &"outcome" and e.outcome != &"away":
				outcome = e.outcome
		if outcome != &"" or not m.alive:
			break
	return {"t": t / 1000.0, "alive": m.alive, "hurts": hurts, "outcome": outcome}


func test_standing_still_against_a_machine_ends_badly() -> void:
	for kind: StringName in [&"harvester", &"cutter", &"runner", &"dredger", &"dog.yard"]:
		var r := _bout(kind, false, 60.0)
		check(r.outcome == &"downed" or r.outcome == &"carried", "%s left a still player standing: %s" % [kind, r])


func test_a_player_who_reads_the_machine_beats_it_with_the_knife() -> void:
	for kind: StringName in [&"harvester", &"longlegs", &"cutter", &"hauler", &"runner", &"dredger", &"lineman", &"dog.yard", &"bull.field"]:
		var r := _bout(kind, true, 90.0)
		check(not r.alive, "%s was not beaten in 90 s: %s" % [kind, r])
		check(r.outcome != &"downed" and r.outcome != &"carried", "%s put a careful player down: %s" % [kind, r])
		# The same reader holding the swing when it fits: the heavy blow is never a way to lose.
		var h := _bout(kind, true, 90.0, true)
		check(not h.alive, "%s was not beaten in 90 s by the heavy reader: %s" % [kind, h])
		check(h.outcome != &"downed" and h.outcome != &"carried", "%s put the heavy reader down: %s" % [kind, h])


## The heavy blow's feel metric (mechanics pass 1c): a reader who holds the
## swing when the opening is long enough, or when only a heavy blow goes through
## the part, kills the harvester in at least a fifth less time than one who only
## taps, over the one bout here and over every first meeting's start; and is
## still never put down.
func test_the_heavy_blow_makes_a_reader_quicker_on_the_harvester() -> void:
	var light := _bout(&"harvester", true, 90.0)
	var hv := _bout(&"harvester", true, 90.0, true)
	print("  harvester, light %.2f s, heavy %.2f s" % [light.t, hv.t])
	check(not hv.alive and hv.outcome != &"downed" and hv.outcome != &"carried", "the heavy reader won: %s" % hv)
	check(hv.t <= light.t * 0.8, "heavy %.2f s against light %.2f s" % [hv.t, light.t])
	var starts := FirstMeetings.STARTS * 2
	var t_light := 0.0
	var t_heavy := 0.0
	for i in starts:
		var a := FirstMeetings.bout(&"harvester", true, i)
		var b := FirstMeetings.bout(&"harvester", true, i, 60.0, 220.0, 0, true)
		check(b.won and not b.downed, "start %d, the heavy reader: %s" % [i, b])
		t_light += float(a.t)
		t_heavy += float(b.t)
	print("  first meetings, mean light %.2f s, heavy %.2f s" % [t_light / starts, t_heavy / starts])
	check(t_heavy <= t_light * 0.8, "first meetings: heavy %.2f s against light %.2f s" % [t_heavy / starts, t_light / starts])


func test_a_player_who_only_holds_the_swing_still_loses() -> void:
	# The masher's own bar (test_first_meetings): walking in swinging loses to the
	# first machines, and holding every swing for the heavy blow must not change that.
	for kind: StringName in [&"runner", &"harvester"]:
		var losses := 0
		for i in FirstMeetings.STARTS:
			var r := FirstMeetings.bout(kind, false, i, 60.0, 220.0, 0, true)
			if r.downed or not r.won:
				losses += 1
		print("  info holding every swing against %s: lost %d of %d" % [kind, losses, FirstMeetings.STARTS])
		gt(float(losses), FirstMeetings.STARTS * 0.74, "%s beats a player who walks in holding the swing" % kind)


## The phase coil's feel metric (mechanics pass 2a): a reader who knows its
## first blow reads the working part through plate kills the harvester sooner
## than one without it, and is still never put down.
func test_a_phase_coil_shortens_a_reader_s_harvester() -> void:
	var bare := _bout(&"harvester", true, 90.0)
	var coil := _bout(&"harvester", true, 90.0, false, [&"mod_phase"] as Array[StringName])
	print("  harvester, bare %.2f s, phase coil %.2f s" % [bare.t, coil.t])
	check(not coil.alive and coil.outcome != &"downed" and coil.outcome != &"carried", "the reader with a coil won: %s" % coil)
	lt(float(coil.t), float(bare.t), "the coil shortened it (%.2f s against %.2f s)" % [coil.t, bare.t])
