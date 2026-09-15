extends MachineModel
## A runner: almost a person, and headless. A tapered torso with square
## shoulders and nothing above them but a capped socket; a satchel sits high on
## its back where a head would hang, and a visor slit runs across the chest
## instead of a face. It strides like a person, except that every step is the
## same step, the weight never shifts, and the arms hang still. The satchel is
## the working part (back).
##
## walk   a real stride with knees; no sway, no torso turn, arms hanging still
## alert  stops and squares up: stance set, arms up and out, satchel flap up
## dead   folds at the knees, goes down on its front; the satchel falls open

const HIP_Y := 0.72


func build() -> void:
	part_side = &"back"
	height = 1.3
	stride = 1.3
	nominal_speed = 2.5
	gallery_turn = 40.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hips := joint(&"hips", self, Vector3(0, HIP_Y, 0))
	var hk := FoundKit.kit()
	FoundKit.lathe(hk, Vector3.ZERO, Vector3.UP, [Vector2(0.09, -0.06), Vector2(0.13, -0.02), Vector2(0.13, 0.04), Vector2(0.1, 0.07)], 6, D, 0.0, Vector2(1.0, 0.72))
	body_mesh(hk, hips)
	for sz: float in [-1.0, 1.0]:
		var s := "r" if sz > 0 else "l"
		var thigh := joint(StringName("thigh_" + s), hips, Vector3(0, -0.03, sz * 0.1))
		var tk := FoundKit.kit()
		FoundKit.tbar(tk, Vector3.ZERO, Vector3(0, -0.34, 0), 0.05, 0.036, 6, D)
		FoundKit.disc(tk, Vector3(0, -0.35, 0), Vector3.BACK, 0.045, 0.08, 6, 0.012, R)
		body_mesh(tk, thigh)
		var shin := joint(StringName("shin_" + s), thigh, Vector3(0, -0.35, 0))
		var sk := FoundKit.kit()
		FoundKit.tbar(sk, Vector3.ZERO, Vector3(0, -0.32, 0), 0.034, 0.024, 6, DD)
		var foot: Array[Vector2] = [Vector2(-0.06, 0.0), Vector2(0.15, 0.0), Vector2(0.1, 0.035), Vector2(-0.04, 0.05)]
		FoundKit.slab(sk, Vector3(0, -0.34, 0), Vector3.RIGHT, Vector3.UP, foot, 0.08, DD, 0.01)
		body_mesh(sk, shin)

	var torso := joint(&"torso", hips, Vector3(0, 0.06, 0))
	var k := FoundKit.kit()
	# Narrow at the waist, square at the shoulders, a flat shoulder line and no head.
	var plan := FoundKit.plan_oct(0.18, 0.4, 0.05)
	FoundKit.loft(k, [FoundKit.ring(plan, 0.0, 0.0, Vector2(0.72, 0.45)), FoundKit.ring(plan, 0.14, 0.0, Vector2(0.8, 0.5)), FoundKit.ring(plan, 0.46, 0.0), FoundKit.ring(plan, 0.5, 0.03)], R, true)
	FoundKit.disc(k, Vector3(0, 0.515, 0), Vector3.UP, 0.055, 0.04, 8, 0.0, D, R[0], PI / 8.0)
	FoundKit.visor(k, Vector3(0.088, 0.38, 0), Vector3(0.998, 0.06, 0), Vector3.UP, 0.24, 0.03)
	FoundKit.streaks(k, Vector3(0.086, 0.34, 0), Vector3.RIGHT, 0.18, 0.18, 5, 151, R[1])
	for sz: float in [-1.0, 1.0]:
		FoundKit.rivets(k, Vector3(-0.06, 0.47, sz * 0.2), Vector3(0.06, 0.47, sz * 0.2), Vector3.BACK * sz, 3, R[5])
	body_mesh(k, torso)
	add_scan(torso, Vector3(0.088, 0.38, 0), Vector3.RIGHT, Vector3.BACK, 0.18, 0.026, 1.2)

	for sz: float in [-1.0, 1.0]:
		var s := "r" if sz > 0 else "l"
		var arm := joint(StringName("arm_" + s), torso, Vector3(0, 0.44, sz * 0.23))
		var ak := FoundKit.kit()
		FoundKit.disc(ak, Vector3.ZERO, Vector3.BACK, 0.05, 0.06, 6, 0.012, R)
		FoundKit.tbar(ak, Vector3.ZERO, Vector3(0, -0.46, 0), 0.034, 0.026, 6, D)
		var hand: Array[Vector2] = [Vector2(-0.03, 0.0), Vector2(0.03, 0.0), Vector2(0.025, -0.09), Vector2(-0.025, -0.08)]
		FoundKit.slab(ak, Vector3(0, -0.47, 0), Vector3.RIGHT, Vector3.UP, hand, 0.05, DD, 0.01)
		body_mesh(ak, arm)

	var satchel := joint(&"satchel", torso, Vector3(-0.08, 0.36, 0))
	var bk := FoundKit.kit()
	var bag: Array[Vector2] = [Vector2(-0.14, -0.12), Vector2(0.14, -0.12), Vector2(0.16, -0.07), Vector2(0.16, 0.13), Vector2(-0.16, 0.13), Vector2(-0.16, -0.07)]
	FoundKit.slab(bk, Vector3(-0.08, 0.02, 0), Vector3.BACK, Vector3.UP, bag, 0.14, R, 0.025)
	FoundKit.rivets(bk, Vector3(-0.14, -0.07, 0.161), Vector3(-0.02, -0.07, 0.161), Vector3.BACK, 3, R[5], 0.03)
	FoundKit.rivets(bk, Vector3(-0.14, -0.07, -0.161), Vector3(-0.02, -0.07, -0.161), Vector3.FORWARD, 3, R[5], 0.03)
	FoundKit.streaks(bk, Vector3(-0.151, -0.06, 0), Vector3.LEFT, 0.2, 0.05, 5, 152, R[1])
	body_mesh(bk, satchel)
	var pk := FoundKit.kit()
	FoundKit.mark(pk, Vector3(-0.151, 0.0, 0), Vector3.LEFT, Vector3.UP, 0.24, 0.07, Palette.LENS[0], 0.003)
	FoundKit.mark(pk, Vector3(-0.151, 0.0, 0), Vector3.LEFT, Vector3.UP, 0.2, 0.04, Palette.LENS[2], 0.007)
	FoundKit.mark(pk, Vector3(-0.151, 0.0, 0), Vector3.LEFT, Vector3.UP, 0.1, 0.018, Palette.LENS[3], 0.01)
	part_mesh(pk, satchel)
	set_part_anchor(satchel, Vector3(-0.16, 0.0, 0), 0.45)

	var flap := joint(&"flap", satchel, Vector3(-0.15, 0.15, 0))
	var fk := FoundKit.kit()
	var lid: Array[Vector2] = [Vector2(-0.16, 0.0), Vector2(0.16, 0.0), Vector2(0.15, -0.1), Vector2(0.0, -0.14), Vector2(-0.15, -0.1)]
	FoundKit.slab(fk, Vector3(-0.012, 0.0, 0), Vector3.BACK, Vector3.UP, lid, 0.025, R, 0.008)
	FoundKit.spot(fk, Vector3(-0.026, -0.13, 0), Vector3.LEFT, 0.025, 6, R[5], 0.002)
	body_mesh(fk, flap)

	# What it was carrying, once it is down: paper, the only made thing it holds.
	var spill := Node3D.new()
	add_child(spill)
	var ck := FoundKit.matter_kit(Ink.HAND)
	for j in 9:
		var a := Rng.hash01(153, j) * PI + PI * 0.5
		var dist := 0.2 + Rng.hash01(154, j) * 0.45
		var c := Vector3(-0.1 + cos(a) * dist * 0.5, 0.012 + j * 0.003, sin(a) * dist)
		ck.push(Transform3D(Basis(Vector3.UP, a * 2.3), c))
		ck.quad(Vector3(-0.07, 0, -0.05), Vector3(-0.07, 0, 0.05), Vector3(0.07, 0, 0.05), Vector3(0.07, 0, -0.05), Palette.LINEN[4] if j % 3 else Palette.LINEN[5])
		ck.pop()
	matter_mesh(ck, spill)
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
			d[&"hips"] = pr(Vector3(0.05, -0.54, 0))
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
