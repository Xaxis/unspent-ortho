extends MachineModel
## A watcher: a cross on a tripod, the only cross-shaped thing in the world. It
## stands on rises and looks, indexing its head through the same three bearings
## forever. The optic in the head is its working part (front). The head bar is
## as wide as the mast end-on, so its width shows which way it looks.
##
## alert  rises on the telescoping mast and throws fins out above and below the head
## dead   the light dies, the legs fold flat, the post stays standing

const HUB_Y := 0.66
const LEG_OUT := Vector3(0.46, -0.66, 0.0)
const BEARINGS := [PI, PI / 3.0, -PI / 3.0]


func build() -> void:
	part_side = &"front"
	height = 1.75
	begin_rig()
	var R := ramp

	var hub := joint(&"hub", self, Vector3(0, HUB_Y, 0))
	var hk := MeshKit.new()
	FoundKit.cbox(hk, Vector3(0, 0, 0), Vector3(0.3, 0.16, 0.3), 0.05, R)
	FoundKit.disc(hk, Vector3(0, -0.1, 0), Vector3.UP, 0.1, 0.06, 6, 0.015, R)
	# Lower mast with its collar: the fixed half of the telescope.
	FoundKit.cbox(hk, Vector3(0, 0.36, 0), Vector3(0.11, 0.56, 0.11), 0.025, R, 0)
	FoundKit.cbox(hk, Vector3(0, 0.64, 0), Vector3(0.15, 0.05, 0.15), 0.015, R)
	FoundKit.streaks(hk, Vector3(0.056, 0.6, 0), Vector3.RIGHT, 0.06, 0.34, 2, 11, R[2])
	FoundKit.rivets(hk, Vector3(0.151, 0.0, -0.08), Vector3(0.151, 0.0, 0.08), Vector3.RIGHT, 3, R[5])
	FoundKit.rivets(hk, Vector3(-0.08, 0.0, 0.151), Vector3(0.08, 0.0, 0.151), Vector3.BACK, 3, R[5])
	body_mesh(hk, hub)

	for i in 3:
		var leg := joint(StringName("leg%d" % i), hub, Vector3(0, -0.02, 0), Vector3(0, BEARINGS[i], 0))
		var lk := MeshKit.new()
		FoundKit.cbox(lk, Vector3(0.1, 0, 0), Vector3(0.09, 0.08, 0.09), 0.02, R)
		FoundKit.bar(lk, Vector3(0.1, 0, 0), LEG_OUT + Vector3(0, 0.03, 0), 0.05, 0.05, 0.012, [R[0], R[1], R[2], R[2], R[3], R[4]])
		FoundKit.cbox(lk, LEG_OUT + Vector3(0.0, 0.015, 0), Vector3(0.13, 0.03, 0.1), 0.01, [R[0], R[0], R[1], R[1], R[2], R[3]])
		body_mesh(lk, leg)

	var mast := joint(&"mast", hub, Vector3(0, 0.44, 0))
	var mk := MeshKit.new()
	FoundKit.cbox(mk, Vector3(0, 0.26, 0), Vector3(0.075, 0.52, 0.075), 0.015, R)
	for y: float in [0.3, 0.42]:
		FoundKit.mark(mk, Vector3(0.038, y, 0), Vector3.RIGHT, Vector3.UP, 0.05, 0.012, R[1])
	body_mesh(mk, mast)

	# The scan yaw sits between mast and head and is driven by the routine, not the pose.
	var yaw := Node3D.new()
	yaw.name = "yaw"
	yaw.position = Vector3(0, 0.44, 0)
	mast.add_child(yaw)
	var head := joint(&"head", yaw, Vector3.ZERO)
	var bk := MeshKit.new()
	FoundKit.cbox(bk, Vector3.ZERO, Vector3(0.21, 0.19, 0.76), 0.045, R, 2)
	FoundKit.cbox(bk, Vector3(0, 0.26, 0), Vector3(0.08, 0.34, 0.08), 0.018, R)
	FoundKit.cbox(bk, Vector3(0, 0.44, 0), Vector3(0.11, 0.03, 0.11), 0.01, R)
	FoundKit.panel(bk, Vector3(0, 0.096, -0.2), Vector3.UP, Vector3.RIGHT, 0.26, 0.15, R)
	FoundKit.panel(bk, Vector3(0, 0.096, 0.2), Vector3.UP, Vector3.RIGHT, 0.26, 0.15, R)
	FoundKit.cbox(bk, Vector3(0, -0.13, 0), Vector3(0.12, 0.07, 0.12), 0.02, R)
	# Optic barrel, the dark socket round it, rivets at the bar ends.
	FoundKit.disc(bk, Vector3(0.125, 0, 0), Vector3.RIGHT, 0.085, 0.05, 8, 0.012, R, R[1], PI / 8.0)
	FoundKit.rivets(bk, Vector3(0.106, 0.045, -0.3), Vector3(0.106, -0.045, -0.3), Vector3.RIGHT, 2, R[5])
	FoundKit.rivets(bk, Vector3(0.106, 0.045, 0.3), Vector3(0.106, -0.045, 0.3), Vector3.RIGHT, 2, R[5])
	FoundKit.seam(bk, Vector3(0.106, 0.06, -0.19), Vector3(0.106, 0.06, 0.19), Vector3.RIGHT, R, 1)
	FoundKit.streaks(bk, Vector3(0.106, -0.07, 0), Vector3.RIGHT, 0.34, 0.03, 4, 12, R[2])
	FoundKit.visor(bk, Vector3(-0.106, 0.01, 0), Vector3.LEFT, Vector3.UP, 0.5, 0.035)
	FoundKit.rivets(bk, Vector3(-0.106, -0.05, -0.25), Vector3(-0.106, -0.05, 0.25), Vector3.LEFT, 5, R[5])
	body_mesh(bk, head)
	add_scan(head, Vector3(-0.106, 0.01, 0), Vector3.LEFT, Vector3.BACK, 0.4, 0.03)

	var iris := joint(&"iris", head, Vector3(0.151, 0, 0))
	var ik := MeshKit.new()
	FoundKit.disc(ik, Vector3.ZERO, Vector3.RIGHT, 0.06, 0.012, 8, 0.0, R, Palette.LENS[2], PI / 8.0)
	FoundKit.mark(ik, Vector3(0.007, 0, 0), Vector3.RIGHT, Vector3.UP, 0.045, 0.045, Palette.LENS[3], 0.002)
	part_mesh(ik, iris)
	set_part_anchor(head, Vector3(0.16, 0, 0), 0.62)

	# Fins: folded flat along the bar at rest, thrown out on alert.
	for i in 4:
		var up := i < 2
		var sz := 1.0 if i % 2 == 0 else -1.0
		var fin := joint(StringName("fin%d" % i), head, Vector3(0, 0.095 if up else -0.095, sz * 0.36))
		var fk := MeshKit.new()
		var dir := 1.0 if up else -1.0
		FoundKit.cbox(fk, Vector3(0, dir * 0.13, 0), Vector3(0.03, 0.26, 0.07), 0.01, R, 2 if sz > 0 else 3)
		FoundKit.mark(fk, Vector3(0.016, dir * 0.19, 0), Vector3.RIGHT, Vector3.UP, 0.03, 0.08, R[5])
		body_mesh(fk, fin)
	_fold_fins()
	finish_rig()


## Fin rest: lying along the bar toward its middle.
func _fold_fins() -> void:
	for i in 4:
		var up := i < 2
		var sz := 1.0 if i % 2 == 0 else -1.0
		# Rotating about X carries +Y toward +Z; fold each fin toward the centre.
		var fold := -sz * PI * 0.5 * (1.0 if up else -1.0)
		(joints[StringName("fin%d" % i)] as Node3D).rotation.x = fold


func _fins_out(amount: float) -> Dictionary:
	var d := {}
	for i in 4:
		var up := i < 2
		var sz := 1.0 if i % 2 == 0 else -1.0
		var s := (1.0 if up else -1.0)
		# From folded (-sz*s*90deg) to out (+sz*s*28deg).
		d[StringName("fin%d" % i)] = r(Vector3(sz * s * (PI * 0.5 + 0.5) * amount, 0, 0))
	return d


func _pose_deltas(p: StringName) -> Dictionary:
	match p:
		&"alert":
			var d := _fins_out(1.0)
			d[&"mast"] = pr(Vector3(0, 0.22, 0))
			d[&"hub"] = pr(Vector3(0, 0.02, 0))
			return d
		&"windup":
			var d := _fins_out(0.55)
			d[&"mast"] = pr(Vector3(0, 0.16, 0))
			d[&"head"] = r(Vector3(0, 0, -0.32))
			d[&"hub"] = r(Vector3(0, 0, 0.1))
			return d
		&"strike":
			var d := _fins_out(1.0)
			d[&"mast"] = pr(Vector3(0, 0.1, 0))
			d[&"head"] = r(Vector3(0, 0, -0.5))
			d[&"hub"] = pr(Vector3(0.08, -0.03, 0), Vector3(0, 0, -0.22))
			return d
		&"dead":
			var d := {}
			d[&"hub"] = pr(Vector3(0, -HUB_Y + 0.07, 0))
			for i in 3:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.96))
			d[&"mast"] = pr(Vector3(0, -0.12, 0))
			d[&"head"] = r(Vector3(0.0, 0, -0.28))
			return d
	return {}


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		match j:
			&"mast": return Vector2(LIGHT_FIRST + 0.5, 0.5)
			&"head": return Vector2(LIGHT_FIRST + 1.1, 0.35)
	return super(p, j)


## The three legs lift in turn, one at a time: a slow exact tripod walk.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for i in 3:
		var t := fposmod(phase * 3.0 - i, 3.0)
		var lift := sin(t * PI) if t < 1.0 else 0.0
		d[StringName("leg%d" % i)] = r(Vector3(0, 0, lift * 0.22))
	d[&"hub"] = pr(Vector3(0, absf(sin(phase * TAU * 1.5)) * 0.02, 0))
	return d


func _routine(_delta: float, on: bool) -> void:
	var yaw := (joints[&"head"] as Node3D).get_parent() as Node3D
	var iris: Node3D = joints[&"iris"]
	if not on:
		return
	var target := 0.0
	if pose == &"stand" or pose == &"walk":
		# Centre, left, centre, right: a servo move then an exact hold.
		var period := 6.0
		var t := fposmod(clock, period) / period
		var slot := int(t * 4.0)
		var within := t * 4.0 - slot
		var bearings := [0.0, 0.55, 0.0, -0.55]
		var from: float = bearings[(slot + 3) % 4]
		var to: float = bearings[slot]
		target = lerpf(from, to, smoothstep(0.0, 1.0, clampf(within / 0.25, 0.0, 1.0)))
		yaw.rotation.y = target
	else:
		yaw.rotation.y = move_toward(yaw.rotation.y, 0.0, 0.15)
	iris.position.z = sin(clock * 1.7) * 0.02 if pose != &"alert" else 0.0
