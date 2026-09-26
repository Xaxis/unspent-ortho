extends TestCase
## THE CROWD READER (tests/fight/crowd_reader.gd): the measure every
## multi-machine number is taken with. Two cutters roused shoulder to shoulder,
## a careful player with the start knife, eight starts round the compass.
## The one-machine reader locks on the nearest and is flanked; a player who
## keeps the crowd on one side and strikes only the open one wins it.

const F := preload("res://tests/fight/fixture.gd")
const Reader := preload("res://tests/fight/reader.gd")
const CrowdReader := preload("res://tests/fight/crowd_reader.gd")

const TOOL := &"knife"


## One gate bout: {won, downed, t, health_lost}. `kit` is what is fitted.
static func gate(crowd_reader: bool, start: int, kind: StringName = &"runner", count: int = 2,
		kit: Array[StringName] = [], seconds: float = 120.0, tool: StringName = TOOL, charges: int = 0) -> Dictionary:
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	if charges > 0:
		sim.hero.inventory.add(FightRules.CHARGE, charges)
	sim.hero.inventory.add(tool)
	sim.hero.inventory.set_held(tool)
	sim.hero.kit = FightKit.of(kit)
	var a := float(start) / 8.0 * TAU
	var mid := sim.hero.pos + Vector2.from_angle(a) * 5.0
	var side := Vector2.from_angle(a).orthogonal()
	var crowd: Array[MobState] = []
	for k in count:
		var m := sim.add_mob(kind, mid + side * (float(k) - 0.5 * float(count - 1)) * 1.1)
		m.facing = (sim.hero.pos - m.pos).angle()
		m.aim = m.facing
		m.set_mood(MobState.CHASING, sim.now)
		crowd.append(m)
	var player: Variant = CrowdReader.new(sim) if crowd_reader else Reader.new(sim)
	var t := 0.0
	var lost := 0
	while t < seconds * 1000.0:
		player.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hurt":
				lost += int(e.damage)
			if e.type == &"outcome" and e.outcome in [&"downed", &"carried"]:
				return {"won": false, "downed": true, "t": t / 1000.0, "lost": lost}
		var left := 0
		for m in crowd:
			left += int(m.alive)
		if left == 0:
			return {"won": true, "downed": false, "t": t / 1000.0, "lost": lost}
	return {"won": false, "downed": false, "t": t / 1000.0, "lost": lost}


func test_the_crowd_reader_wins_what_the_single_reader_loses() -> void:
	var single := 0
	var crowd := 0
	var times := 0.0
	for s in 8:
		single += int(gate(false, s, &"cutter", 2).won)
		var r := gate(true, s, &"cutter", 2)
		crowd += int(r.won)
		if r.won:
			times += float(r.t)
	print("  info two cutters at a gate, knife: the single reader wins %d of 8, the crowd reader %d of 8 (mean %.1f s)" % [single, crowd, times / maxf(crowd, 1)])
	lt(single, 5, "the one-machine reader loses a crowd it should win")
	gt(crowd, 5, "a player who keeps the crowd on one side wins it")

