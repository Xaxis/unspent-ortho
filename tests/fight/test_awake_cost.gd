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


## In FIGURE yardsticks: ten dogs walking, each posed once (`_dogs_work`). A
## frame of awake machines is mostly their figures being posed -- script and
## bone writes in the same mix -- and a ruler of other work drifts with the CPU
## under it. Measured on CI's three runner CPUs and this laptop, the frame read
## (2026-09-27, tests alone):
##   ruler                  laptop  EPYC 9V74  EPYC 7763  EPYC 9V45  spread
##   interpreted (yard)       7.6      7.2       10.0       10.9      1.51x
##   rig (bone)               4.9      4.3        5.6        5.7      1.33x
##   ten dogs walking         2.7      2.5        2.9        2.6      1.19x
## The interpreted ruler put a 7763 under gate load at 13-14 against a bar of
## 11.5 that the laptop's doubling reads 15 on: no bar sat between them on
## every host. With the dogs, on all four CPUs alone and beside two running
## shards (54 readings), shipped read 2.27-3.04 and doubled 4.36-6.07 (laptop
## 2.84 / 5.74); load slows the dogs more than the frame, so it only lowers the
## reading. The bar sits between, about 1.2x clear of each. Dogs are figures
## too, so a cost shared by every figure moves both and is not seen here; what
## this bar holds is the machines' own share.
const AWAKE_BAR := 3.7


func _dogs() -> Array[FigureModel]:
	var out: Array[FigureModel] = []
	for i in 10:
		var d := FigureModel.create(&"dog")
		tree.root.add_child(d)
		d.set_pose(&"walk")
		out.append(d)
	return out


func test_ten_awake_machines_are_cheap_to_draw() -> void:
	var sim := F.make_sim(F.flat_world(64))
	var mobs := _ten(sim)
	var dogs := _dogs()
	var frames_of := func(n: int) -> void:
		for i in n:
			for mob in mobs:
				mob.sync_view(1.0 / 60.0, 0.0)
	var dogs_work := func() -> void:
		for d in dogs:
			d.animate(1.0 / 60.0, 1.5)
	frames_of.call(30)
	var got := yard_sample(frames_of.bind(10), frames_of.bind(20), dogs_work)
	yard_lt(got[0] / 10.0, got[1] / 10.0, got[2], AWAKE_BAR, "a frame of ten awake machines")
	for mob in mobs:
		mob.free()
	for d in dogs:
		d.free()


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
