extends TestCase
## What ten awake machines cost to draw a frame, and that drawing them less often
## changes only how often, never what. A machine standing or walking is posed at
## Mob.POSE_HZ; one in a tell, a strike, a hurt or a death every frame, since the
## fight is read off those.

const F := preload("res://tests/fight/fixture.gd")
const KINDS: Array[StringName] = [&"harvester", &"cutter", &"hauler", &"sweeper", &"watcher"]


func _ten(sim: FightSim) -> Array[Mob]:
	var out: Array[Mob] = []
	for i in 10:
		var m := F.still(sim, KINDS[i % KINDS.size()], Vector2(12.5 + float(i) * 3.0, 30.5), 0.0)
		var mob := Mob.new()
		tree.root.add_child(mob)
		mob.setup(m, sim.world, null)
		out.append(mob)
	return out


func _pose_of(m: MachineModel) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for b in m.skeleton.get_bone_count():
		out.append(m.skeleton.get_bone_pose(b))
	return out


## Calibrated 2026-09-25 (TestCase.yard_sample against the rig yardstick):
## ten standing machines a frame 4.8 shipped, 9.6 doubled, 8.3 posed every frame
## (Mob.POSE_HZ 0); the bar between.
const AWAKE_BAR := 7.0


func test_ten_awake_machines_are_cheap_to_draw() -> void:
	var sim := F.make_sim(F.flat_world(64))
	var mobs := _ten(sim)
	var frames_of := func(n: int) -> void:
		for i in n:
			for mob in mobs:
				mob.sync_view(1.0 / 60.0, 0.0)
	frames_of.call(30)
	var got := yard_sample(frames_of.bind(10), frames_of.bind(20), bone_work())
	yard_lt(got[0] / 10.0, got[1] / 10.0, got[2], AWAKE_BAR, "a frame of ten awake machines")
	for mob in mobs:
		mob.free()


func test_a_stepped_machine_is_where_an_unstepped_one_is() -> void:
	var a := FigureModel.create(&"harvester") as MachineModel
	var b := FigureModel.create(&"harvester") as MachineModel
	tree.root.add_child(a)
	tree.root.add_child(b)
	b.pose_hz = 30.0
	for m: MachineModel in [a, b]:
		m.set_pose(&"walk")
	var drawn := 0
	var last := _pose_of(b)
	for i in 60:
		a.animate(1.0 / 60.0, 1.5)
		b.animate(1.0 / 60.0, 1.5)
		var now := _pose_of(b)
		if now != last:
			drawn += 1
			# Drawn on this frame: the same pose the every-frame machine has.
			var ab := _pose_of(a)
			var worst := 0.0
			for k in ab.size():
				worst = maxf(worst, ab[k].origin.distance_to(now[k].origin))
			lt(worst, 1e-4, "frame %d: a stepped machine drawn where the unstepped one is" % i)
		last = now
	check(drawn >= 28 and drawn <= 31, "walking at 30 Hz on a 60 Hz screen, drawn %d frames of 60" % drawn)
	# A tell is what the fight is read by: drawn every frame, so on every frame
	# where the every-frame machine is.
	for m: MachineModel in [a, b]:
		m.set_pose(&"windup")
	var off := 0
	for i in 20:
		a.animate(1.0 / 60.0, 0.0)
		b.animate(1.0 / 60.0, 0.0)
		var ab := _pose_of(a)
		var bb := _pose_of(b)
		for k in ab.size():
			if ab[k].origin.distance_to(bb[k].origin) > 1e-4:
				off += 1
				break
	eq(off, 0, "frames of the tell a stepped machine is drawn behind")
	a.free()
	b.free()
