extends TestCase
## A PLAYED FIGHT PLAYS THE SAME WHEREVER IN A FRAME ITS TEST BEGAN (Sx.played).
## The runner starts each test at whatever point of a frame the last one left
## off. A game booted just after a physics step takes that step at once, one
## booted after a process frame does not, and the hands that drive it are then a
## frame apart from the fight for the rest of it: seed 1's Reaper against reader
## 2 over the shoulder, locked, fell in 101.9 s as the first test of its process
## and in 181.2 s after any other. Booted from both points, the first seconds of
## the same fight go frame for frame alike.

const Sx := preload("res://tests/save/save_fixture.gd")
const KF := preload("res://tests/sentinel/keeper_fight.gd")
const PR := preload("res://tests/fight/plate_reader.gd")
const GD := preload("res://tests/fight/game_driver.gd")

## Frames of the fight compared: the walk in and the first bites.
const FRAMES := 240


func test_a_played_fight_booted_after_a_physics_step_or_a_frame_goes_alike() -> void:
	if not stepped_now():
		return
	var after_step: Array[String] = await _played(true)
	var after_frame: Array[String] = await _played(false)
	eq(after_step.size(), FRAMES, "the fight after a physics step was played")
	eq(after_frame.size(), FRAMES, "and the one after a frame")
	var apart := -1
	for i in mini(after_step.size(), after_frame.size()):
		if after_step[i] != after_frame[i]:
			apart = i
			break
	eq(apart, -1, "frame for frame alike (%s)" % ("" if apart < 0 else
		"first apart at frame %d: %s against %s" % [apart, after_step[apart], after_frame[apart]]))


## The fight clock, the body and the keeper at each of FRAMES frames of reader 2
## at seed 1's Reaper over the shoulder, the game booted just after a physics
## step (`after_step`) or just after a process frame.
func _played(after_step: bool) -> Array[String]:
	var out: Array[String] = []
	if after_step:
		await tree.physics_frame
	else:
		await tree.process_frame
	Sx.use_root("played-boot")
	var g := await Sx.played(tree, ["--seed=1", "--hour=11", "--weather=clear:0", "--held=knife_shear", "--view=shoulder"])
	# Bodies numbered from the same place whatever ran before (Reader.human).
	MobState._next_id = 900000
	var s: SentinelState = null
	for q: SentinelState in Sx.system(g, "44_sentinels").call(&"states"):
		if q.land == &"coast" and not q.fallen and q.region >= 0:
			s = q
	check(s != null, "seed 1 holds a reaper")
	if s == null:
		Sx.end(g)
		return out
	KF.calm(g)
	var flats: Array = Sentinels.by_id(s.design).way_of(SentinelWay.FOUNDER).grounds
	var at := KF.stand(g, s, 6.0, flats, false)
	var sim: FightSim = g.player.sim
	var r: Variant = PR.new(sim)
	r.human = 2
	r.keep_off = flats
	r.home = at
	g.player.place(at, (s.lair - at).angle())
	var d: Variant = GD.new(g, r)
	for i in FRAMES:
		d.step()
		await tree.physics_frame
		var m: MobState = s.body
		out.append("%.0f ms, at %.3f,%.3f facing %.3f; keeper %s" % [sim.now, sim.hero.pos.x, sim.hero.pos.y,
			sim.hero.facing, "out" if m == null else "%.3f,%.3f facing %.3f" % [m.pos.x, m.pos.y, m.facing]])
	d.release()
	Sx.end(g)
	return out
