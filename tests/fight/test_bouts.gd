extends TestCase
## Whole fights, headless. A player who stands still is put down (a worker only
## once it has been struck); a player who reads the machine (reader.gd: human
## reactions, gets out of the tell, walks round to the working part while it is
## open) beats every kind with a knife and is never put down. If this fails
## after a change, the fight became unfair or trivial.

const F := preload("res://tests/fight/fixture.gd")
const Bot := preload("res://tests/fight/reader.gd")


func _bout(kind: StringName, use_bot: bool, seconds: float) -> Dictionary:
	var ground := Ground.WATER if kind == &"dredger" else Ground.GRASS
	var sim := F.make_sim(F.flat_world(96, ground), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	var m := sim.add_mob(kind, Vector2(53.5, 48.5))
	m.facing = PI
	m.aim = PI
	if not use_bot and m.disposition == &"indifferent":
		# A worker leaves a still player be: this one has already been struck.
		m.disturbed = true
		m.set_mood(MobState.ATTACKING, sim.now)
	var bot := Bot.new(sim)
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
