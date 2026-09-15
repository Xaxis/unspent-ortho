extends MachineModel
## A runner: almost a person, and headless. A satchel sits high on its back where
## shoulders and a head would be, and a visor slit runs across the chest instead
## of a face. It strides like a person, except that every step is the same step
## and the weight never shifts. The satchel is the working part (back).
##
## walk   a real stride with knees; no sway, no torso turn, arms hanging still
## alert  stops and squares up: stance set, arms up and out, satchel flap up
## dead   folds at the knees, goes down on its front; the satchel falls open

const HIP_Y := 0.74


func build() -> void:
	part_side = &"back"
	height = 1.3
	stride = 1.3
	nominal_speed = 2.5
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hips := joint(&"hips", self, Vector3(0, HIP_Y, 0))
	var hk := MeshKit.new()
	FoundKit.cbox(hk, Vector3.ZERO, Vector3(0.2, 0.12, 0.34), 0.03, D)
	body_mesh(hk, hips)
	for sz: float in [-1.0, 1.0]:
		var s := "r" if sz > 0 else "l"
		var thigh := joint(StringName("thigh_" + s), hips, Vector3(0, -0.03, sz * 0.1))
		var tk := MeshKit.new()
		FoundKit.bar(tk, Vector3.ZERO, Vector3(0, -0.36, 0), 0.09, 0.09, 0.02, D)
		FoundKit.cbox(tk, Vector3(0, -0.36, 0), Vector3(0.1, 0.06, 0.1), 0.015, R)
		body_mesh(tk, thigh)
		var shin := joint(StringName("shin_" + s), thigh, Vector3(0, -0.36, 0))
		var sk := MeshKit.new()
		FoundKit.bar(sk, Vector3.ZERO, Vector3(0, -0.34, 0), 0.07, 0.07, 0.015, DD)
		FoundKit.cbox(sk, Vector3(0.04, -0.345, 0), Vector3(0.2, 0.05, 0.09), 0.012, DD)
		body_mesh(sk, shin)

	var torso := joint(&"torso", hips, Vector3(0, 0.06, 0))
	var k := MeshKit.new()
	FoundKit.cbox(k, Vector3(0, 0.04, 0), Vector3(0.15, 0.1, 0.24), 0.025, D)
	FoundKit.cbox(k, Vector3(0, 0.29, 0), Vector3(0.2, 0.4, 0.36), 0.045, R, 2)
	FoundKit.cbox(k, Vector3(0, 0.5, 0), Vector3(0.24, 0.04, 0.44), 0.012, R)
	FoundKit.disc(k, Vector3(0, 0.535, 0), Vector3.UP, 0.065, 0.03, 8, 0.0, D, R[0])
	FoundKit.visor(k, Vector3(0.101, 0.4, 0), Vector3.RIGHT, Vector3.UP, 0.26, 0.035)
	FoundKit.streaks(k, Vector3(0.101, 0.36, 0), Vector3.RIGHT, 0.22, 0.2, 5, 151, R[2])
	FoundKit.seam(k, Vector3(0.101, 0.1, 0), Vector3(0.101, 0.3, 0), Vector3.RIGHT, R, 2)
	for sz: float in [-1.0, 1.0]:
		FoundKit.bar(k, Vector3(-0.12, 0.52, sz * 0.11), Vector3(0.105, 0.5, sz * 0.11), 0.02, 0.05, 0.0, [R[0], R[0], R[1], R[1], R[2], R[2]])
		FoundKit.bar(k, Vector3(0.105, 0.5, sz * 0.11), Vector3(0.105, 0.2, sz * 0.08), 0.015, 0.05, 0.0, [R[0], R[0], R[1], R[1], R[2], R[2]])
	body_mesh(k, torso)
	add_scan(torso, Vector3(0.101, 0.4, 0), Vector3.RIGHT, Vector3.BACK, 0.2, 0.03, 1.2)

	for sz: float in [-1.0, 1.0]:
		var s := "r" if sz > 0 else "l"
		var arm := joint(StringName("arm_" + s), torso, Vector3(0, 0.46, sz * 0.215))
		var ak := MeshKit.new()
		FoundKit.cbox(ak, Vector3.ZERO, Vector3(0.1, 0.08, 0.08), 0.02, R)
		FoundKit.bar(ak, Vector3.ZERO, Vector3(0, -0.46, 0), 0.055, 0.055, 0.012, D)
		FoundKit.cbox(ak, Vector3(0, -0.49, 0), Vector3(0.07, 0.07, 0.06), 0.015, DD)
		body_mesh(ak, arm)

	var satchel := joint(&"satchel", torso, Vector3(-0.1, 0.38, 0))
	var bk := MeshKit.new()
	FoundKit.cbox(bk, Vector3(-0.1, 0.08, 0), Vector3(0.2, 0.34, 0.34), 0.04, R, 2)
	FoundKit.rivets(bk, Vector3(-0.18, -0.05, 0.171), Vector3(-0.02, -0.05, 0.171), Vector3.BACK, 3, R[5])
	FoundKit.rivets(bk, Vector3(-0.18, -0.05, -0.171), Vector3(-0.02, -0.05, -0.171), Vector3.FORWARD, 3, R[5])
	FoundKit.streaks(bk, Vector3(-0.201, -0.04, 0), Vector3.LEFT, 0.22, 0.04, 5, 152, R[2])
	body_mesh(bk, satchel)
	var pk := MeshKit.new()
	FoundKit.mark(pk, Vector3(-0.201, 0.0, 0), Vector3.LEFT, Vector3.UP, 0.3, 0.08, Palette.LENS[0], 0.003)
	FoundKit.mark(pk, Vector3(-0.201, 0.0, 0), Vector3.LEFT, Vector3.UP, 0.26, 0.045, Palette.LENS[2], 0.007)
	FoundKit.mark(pk, Vector3(-0.201, 0.0, 0), Vector3.LEFT, Vector3.UP, 0.12, 0.02, Palette.LENS[3], 0.01)
	part_mesh(pk, satchel)
	set_part_anchor(satchel, Vector3(-0.21, 0.02, 0), 0.6)

	var flap := joint(&"flap", satchel, Vector3(-0.2, 0.25, 0))
	var fk := MeshKit.new()
	FoundKit.cbox(fk, Vector3(-0.015, -0.09, 0), Vector3(0.03, 0.18, 0.36), 0.01, R)
	FoundKit.mark(fk, Vector3(-0.031, -0.14, 0), Vector3.LEFT, Vector3.UP, 0.07, 0.05, R[5])
	body_mesh(fk, flap)

	# What it was carrying, once it is down.
	var spill := Node3D.new()
	add_child(spill)
	var ck := MeshKit.new()
	for j in 9:
		var a := Rng.hash01(153, j) * PI + PI * 0.5
		var dist := 0.15 + Rng.hash01(154, j) * 0.4
		var c := Vector3(-0.1 + cos(a) * dist * 0.4, 0.015 + j * 0.002, sin(a) * dist)
		ck.push(Transform3D(Basis(Vector3.UP, a * 2.3), c))
		FoundKit.cbox(ck, Vector3.ZERO, Vector3(0.14, 0.01, 0.1), 0.0, [Palette.LINEN[3], Palette.LINEN[3], Palette.LINEN[4], Palette.LINEN[4], Palette.LINEN[5], Palette.LINEN[5]])
		ck.pop()
	body_mesh(ck, spill)
	dead_only(spill, LIGHT_FIRST + 1.1)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"hips"] = pr(Vector3(0, -0.12, 0))
			d[&"thigh_l"] = r(Vector3(0.22, 0, 0.45))
			d[&"thigh_r"] = r(Vector3(-0.22, 0, 0.45))
			d[&"shin_l"] = r(Vector3(-0.12, 0, -0.8))
			d[&"shin_r"] = r(Vector3(0.12, 0, -0.8))
			d[&"torso"] = r(Vector3(0, 0, 0.12))
			# Arms up and out in a V, flap up: the shape stops being a person.
			d[&"arm_l"] = r(Vector3(2.35, 0, 0))
			d[&"arm_r"] = r(Vector3(-2.35, 0, 0))
			d[&"flap"] = r(Vector3(0, 0, -2.2))
		&"windup":
			d[&"torso"] = r(Vector3(0, 0, -0.22))
			d[&"arm_r"] = r(Vector3(-0.2, 0, -1.1))
			d[&"arm_l"] = r(Vector3(0.1, 0, 0.35))
			d[&"thigh_l"] = r(Vector3(0, 0, 0.35))
			d[&"shin_l"] = r(Vector3(0, 0, -0.35))
			d[&"thigh_r"] = r(Vector3(0, 0, -0.25))
			d[&"hips"] = pr(Vector3(0, -0.05, 0))
		&"strike":
			d[&"torso"] = pr(Vector3(0.06, 0, 0), Vector3(0, 0, -0.3))
			d[&"arm_r"] = r(Vector3(0, 0, 1.65))
			d[&"arm_l"] = r(Vector3(0, 0, -0.5))
			d[&"thigh_l"] = r(Vector3(0, 0, 0.5))
			d[&"shin_l"] = r(Vector3(0, 0, -0.2))
			d[&"thigh_r"] = r(Vector3(0, 0, -0.4))
			d[&"hips"] = pr(Vector3(0.1, -0.06, 0))
		&"dead":
			d[&"hips"] = pr(Vector3(0.05, -0.56, 0))
			d[&"thigh_l"] = r(Vector3(0, 0, 1.45))
			d[&"thigh_r"] = r(Vector3(0, 0, 1.4))
			d[&"shin_l"] = r(Vector3(0, 0, -2.95))
			d[&"shin_r"] = r(Vector3(0, 0, -2.9))
			d[&"torso"] = pr(Vector3(0.02, 0, 0), Vector3(0, 0, -1.4))
			d[&"arm_l"] = r(Vector3(0.2, 0, 0.3))
			d[&"arm_r"] = r(Vector3(-0.2, 0, 0.3))
			d[&"flap"] = r(Vector3(0, 0, -2.6))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		match j:
			&"torso", &"arm_l", &"arm_r": return Vector2(LIGHT_FIRST + 0.4, 0.4)
			&"flap": return Vector2(LIGHT_FIRST + 0.85, 0.3)
	return super(p, j)


## The same step every step: thigh swing, knee flex on the forward swing, and a
## bob at each mid-stance. Nothing else moves.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for side in 2:
		var s := "l" if side == 0 else "r"
		var ph := phase * TAU + side * PI
		d[StringName("thigh_" + s)] = r(Vector3(0, 0, sin(ph) * 0.46))
		d[StringName("shin_" + s)] = r(Vector3(0, 0, -maxf(0.0, cos(ph)) * 0.8))
	d[&"hips"] = pr(Vector3(0, -0.05 + absf(cos(phase * TAU)) * 0.035, 0))
	return d
