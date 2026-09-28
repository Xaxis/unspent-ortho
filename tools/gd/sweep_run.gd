extends RefCounted
## The sweep itself (tools/gd/sweep.gd launches it and says what it measures).

const G := preload("res://tests/fight/test_crowd_reader.gd")
const M := preload("res://tests/fight/test_matchups.gd")
const F := preload("res://tests/fight/fixture.gd")
const SR := preload("res://tests/fight/shoulder_reader.gd")

const SECONDS := 90.0
const CHARGES := 20
const TRIVIAL_S := 8.0
const CROWD_STARTS := 8
const CROWDS: Array = [
	[&"cutter", &"cutter", &"cutter"],
	[&"harvester", &"harvester", &"harvester", &"cutter", &"cutter"],
	[&"harvester", &"harvester"],
]
## A weapon's line, by the start of its id: the families a tuning target names.
const LINES: Array[String] = ["knife", "axe", "pick", "mattock", "hook", "boathook", "bill", "stave"]


## The reader's seed for --reader=human (Reader.human); -1 is the perfect reader.
static var human := -1


static func run(args: PackedStringArray) -> void:
	human = -1
	var singles := true
	var crowds := true
	var starts := 4
	var weapons: Array[StringName] = M.weapons()
	var machines: Array[StringName] = M.common_machines()
	for a: String in args:
		if a == "--singles":
			crowds = false
		elif a == "--crowds":
			singles = false
		elif a == "--reader=human":
			human = 17
		elif a.begins_with("--reader=human:"):
			human = a.trim_prefix("--reader=human:").to_int()
		elif a.begins_with("--starts="):
			starts = maxi(1, a.trim_prefix("--starts=").to_int())
		elif a.begins_with("--weapons="):
			weapons = _names(a.trim_prefix("--weapons="))
		elif a.begins_with("--machines="):
			machines = _names(a.trim_prefix("--machines="))
	var t0 := Time.get_ticks_msec()
	var summary: Array[String] = []
	if singles:
		summary.append_array(_singles(weapons, machines, starts))
	if crowds:
		summary.append_array(_crowds(weapons))
	print("summary (%s reader)" % ["human, seed %d" % human if human >= 0 else "perfect"])
	for line in summary:
		print("  " + line)
	print("sweep done in %d s" % ((Time.get_ticks_msec() - t0) / 1000))


static func _names(csv: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: String in csv.split(",", false):
		out.append(StringName(s.strip_edges()))
	return out


## A weapon's line: the first of LINES its id starts with, the hooks together.
static func line_of(tool: StringName) -> String:
	var s := String(tool)
	for l in LINES:
		if s.begins_with(l):
			return "hook" if l == "boathook" else l
	return "other"


static func _singles(weapons: Array[StringName], machines: Array[StringName], starts: int) -> Array[String]:
	var n := 0
	var trivial := 0
	var hopeless: Array[String] = []
	for k in machines:
		var kt := 0
		for tool in weapons:
			var won := 0
			var downed := 0
			var secs := 0.0
			var lost := 0.0
			for s in starts:
				var r: Dictionary = G.gate(true, s * 8 / starts, k, 1, [] as Array[StringName], SECONDS, tool, CHARGES, 1000, true, 0.0, human)
				won += int(r.won)
				downed += int(r.downed)
				secs += float(r.t)
				lost += float(r.lost)
			var t := secs / starts
			var is_trivial := won == starts and lost == 0.0 and t < TRIVIAL_S
			n += 1
			trivial += int(is_trivial)
			kt += int(is_trivial)
			if won == 0:
				hopeless.append("%s vs %s" % [tool, k])
			print("single %s %s won=%d/%d downed=%d t=%.1f lost=%.1f%s" % [k, tool, won, starts, downed, t, lost / starts, " trivial" if is_trivial else ""])
		print("single %s trivial for %d of %d weapons" % [k, kt, weapons.size()])
	var out: Array[String] = []
	out.append("singles: %d pairings, trivial %d (%.0f%%), hopeless %d %s" % [n, trivial, 100.0 * trivial / maxf(n, 1), hopeless.size(), hopeless])
	return out


static func _crowds(weapons: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for c: Array in CROWDS:
		var kinds: Array[StringName] = []
		kinds.assign(c)
		var name := "+".join(c)
		var won_all := 0
		var lost_all := 0.0
		var by_line := {}
		for tool in weapons:
			var won := 0
			var downed := 0
			var lost := 0.0
			for s in CROWD_STARTS:
				var r := crowd_bout(kinds, tool, s)
				won += int(r.won)
				downed += int(r.downed)
				lost += float(r.lost)
			won_all += won
			lost_all += lost
			var l := line_of(tool)
			var row: Array = by_line.get(l, [0, 0])
			by_line[l] = [int(row[0]) + won, int(row[1]) + CROWD_STARTS]
			print("crowd %s %s won=%d/%d downed=%d lost=%.1f" % [name, tool, won, CROWD_STARTS, downed, lost / CROWD_STARTS])
		var lines: Array[String] = []
		for l: String in by_line:
			lines.append("%s %d/%d" % [l, by_line[l][0], by_line[l][1]])
		out.append("%s: won %d/%d, mean lost %.2f; by line: %s" % [name, won_all, weapons.size() * CROWD_STARTS,
			lost_all / maxf(weapons.size() * CROWD_STARTS, 1), ", ".join(lines)])
	return out


## A mixed crowd side by side five tiles off along the start's bearing, roused,
## the shoulder reader holding `tool`: {won, downed, lost}.
static func crowd_bout(kinds: Array[StringName], tool: StringName, start: int) -> Dictionary:
	MobState._next_id = 1000
	var sim: FightSim = F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.hero.inventory.add(FightRules.CHARGE, CHARGES)
	sim.hero.inventory.add(tool)
	sim.hero.inventory.set_held(tool)
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
	player.human = human
	sim.hero.facing = (mid - sim.hero.pos).angle()
	var t := 0.0
	var lost := 0
	while t < SECONDS * 1000.0:
		player.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hurt":
				lost += int(e.damage)
			if e.type == &"outcome" and e.outcome in [&"downed", &"carried"]:
				return {"won": false, "downed": true, "lost": lost}
		var left := 0
		for m in crowd:
			left += int(m.alive and not m.stripped)
		if left == 0:
			return {"won": true, "downed": false, "lost": lost}
	return {"won": false, "downed": false, "lost": lost}
