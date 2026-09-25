extends TestCase
## Whole fights, headless. A player who stands still is put down (a worker only
## once it has been struck); a player who reads the machine (reader.gd: human
## reactions, gets out of the tell, walks round to the working part while it is
## open) beats every kind with a knife and is never put down. If this fails
## after a change, the fight became unfair or trivial.

const F := preload("res://tests/fight/fixture.gd")
const Bot := preload("res://tests/fight/reader.gd")
const FirstMeetings := preload("res://tests/fight/test_first_meetings.gd")


func _bout(kind: StringName, use_bot: bool, seconds: float, heavy: bool = false, kit: Array[StringName] = [], roused: bool = false, start: int = 0) -> Dictionary:
	var ground := Ground.WATER if kind == &"dredger" else Ground.GRASS
	var sim := F.make_sim(F.flat_world(96, ground), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	sim.hero.kit = FightKit.of(kit)
	var m := sim.add_mob(kind, Vector2(53.5, 48.5))
	m.facing = PI
	m.aim = PI
	if (roused or not use_bot) and m.disposition == &"indifferent":
		# A worker leaves a still player be: this one has already been struck.
		m.disturbed = true
		m.set_mood(MobState.ATTACKING, sim.now)
	if roused:
		# Met at close quarters at its front, its guard closed: a player who walked
		# into it rather than one it came at across a field.
		# Each `start` meets it a little off square, so one bout's timing is not the
		# whole of the measure.
		var skew := (float(start % 8) - 3.5) * 0.14
		var gap := 0.2 + 0.1 * float(start % 4)
		m.pos = sim.hero.pos + Vector2.from_angle(skew) * (m.radius + sim.hero.radius + gap)
		m.facing = skew + PI
		m.aim = m.facing
	var bot := Bot.new(sim)
	bot.heavy = heavy
	var hurts := 0
	var outcome := &""
	var t := 0.0
	# Part hits landed before the machine's second tell: what its first opening
	# was worth.
	var tells := 0
	var first_hits := 0
	while t < seconds * 1000.0:
		if use_bot:
			bot.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hurt":
				hurts += 1
			elif e.type == &"windup" and e.mob == m:
				tells += 1
			elif e.type == &"hit" and e.target == m and not bool(e.plate) and tells < 2:
				first_hits += 1
			elif e.type == &"outcome" and e.outcome != &"away":
				outcome = e.outcome
		if outcome != &"" or not m.alive:
			break
	return {"t": t / 1000.0, "alive": m.alive, "hurts": hurts, "outcome": outcome, "first_hits": first_hits}


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
		print("  bout %s: reader %.2f s (hurt %d), heavy reader %.2f s (hurt %d)" % [kind, r.t, r.hurts, h.t, h.hurts])
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


## The phase coil (mechanics pass 2a) is an opener, spent on first contact: a
## reader with one never does worse than one without, and is never put down.
## What it buys in time is printed, and it is small by design against a worker
## whose front is open to the first blow anyway.
func test_a_phase_coil_never_costs_a_reader_the_harvester() -> void:
	var bare := _bout(&"harvester", true, 90.0)
	var coil := _bout(&"harvester", true, 90.0, false, [&"mod_phase"] as Array[StringName])
	print("  harvester, bare %.2f s, phase coil %.2f s" % [bare.t, coil.t])
	check(not coil.alive and coil.outcome != &"downed" and coil.outcome != &"carried", "the reader with a coil won: %s" % coil)
	check(float(coil.t) <= float(bare.t) + 0.02, "no slower with it (%.2f s against %.2f s)" % [coil.t, bare.t])


## Where the coil earns its place: opening on a machine that is already roused,
## its guard closed, met at its front. The first blow goes through and stalls
## it; after that it is the machine as it is. The mean of eight meetings, each a
## little off square and at a different gap. They come out within 0.02 s of one
## another (the fight falls into the machine's own rhythm), so the mean is the
## guard against a start that does not, not a smoothing of noise.
const ROUSED_STARTS := 8


func test_a_phase_coil_opens_a_roused_harvester() -> void:
	var tb := 0.0
	var tc := 0.0
	var hb := 0
	var hc := 0
	for i in ROUSED_STARTS:
		var bare := _bout(&"harvester", true, 90.0, false, [] as Array[StringName], true, i)
		var coil := _bout(&"harvester", true, 90.0, false, [&"mod_phase"] as Array[StringName], true, i)
		check(not bare.alive and not coil.alive, "start %d: both readers take it: %s %s" % [i, bare, coil])
		check(coil.outcome != &"downed" and coil.outcome != &"carried", "start %d: the coil's reader is never put down: %s" % [i, coil])
		tb += float(bare.t)
		tc += float(coil.t)
		hb += int(bare.first_hits)
		hc += int(coil.first_hits)
	tb /= ROUSED_STARTS
	tc /= ROUSED_STARTS
	print("  roused harvester, mean of %d: bare %.2f s, phase coil %.2f s (%.0f%% less); first opening %.1f blows bare, %.1f with the coil"
		% [ROUSED_STARTS, tb, tc, (1.0 - tc / tb) * 100.0, float(hb) / ROUSED_STARTS, float(hc) / ROUSED_STARTS])
	# What the coil buys is the opening: a tell broken at close quarters leaves
	# the machine as open as a dodged one (FightSim._break_tell), the coil's reader
	# is already in reach, and its stall (FightKit.PHASE_STALL_MS) outlasts the
	# window so the reader is out of the box before the machine comes again.
	gt(float(hc), float(hb), "the coil's first opening is worth more blows (%d against %d over %d)" % [hc, hb, ROUSED_STARTS])
	lt(tc, tb * 0.9, "and the fight is at least a tenth shorter (%.2f s against %.2f s)" % [tc, tb])
	gt(tc, tb * 0.75, "and no more than a quarter: an opener, not a win")
