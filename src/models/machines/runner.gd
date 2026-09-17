extends MachineModel
## A runner: almost a person, and headless. A tapered torso with square flat
## shoulders and nothing above them but a bolted plate; a satchel rides on a rack
## off its back at the shoulder line, and a visor slit runs across the chest
## instead of a face. It strides like a person, except that every step is the
## same step, the weight never shifts, and the arms hang still. The satchel is
## the working part (back).
##
## stand  holds the step it stopped on: it never brings its feet together
## walk   a real stride with knees; no sway, no torso turn, arms hanging still
## alert  stops and squares up: planted wide, arms held out still, flap open
## dead   folds at the knees, goes down on its front; the satchel falls open
##
## lights a hunter runs dark: a status lamp burning low and steady on the
##        shoulder plate, two pin eyes at the ends of the chest slit
## wear   a scrap of someone's coat tied round its upper arm, a strap mended
##        with cable, a plate off another machine on the chest, grime

const HIP_Y := 0.72
## How far the satchel's face stands off the torso's spine on its rack.
const SATCHEL_OFF := 0.18
## How deep the satchel is, face to back.
const SATCHEL_D := 0.18
## The step it holds when it stops: front thigh forward with the shin brought
## back upright under the knee, back leg straight behind, and the hips down by
## what that costs so both feet stay on the ground.
const STANCE_FRONT := 0.36
const STANCE_BACK := 0.256
const STANCE_DROP := -0.022


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
	# Nothing above the shoulders: a flat plate bolted over where a neck would be.
	FoundKit.mark(k, Vector3(0, 0.501, 0), Vector3.UP, Vector3.RIGHT, 0.2, 0.09, R[2], 0.002)
	FoundKit.rivets(k, Vector3(0, 0.503, -0.04), Vector3(0, 0.503, 0.04), Vector3.UP, 2, R[5], 0.025)
	FoundKit.visor(k, Vector3(0.088, 0.38, 0), Vector3(0.998, 0.06, 0), Vector3.UP, 0.24, 0.03)
	FoundKit.streaks(k, Vector3(0.086, 0.34, 0), Vector3.RIGHT, 0.18, 0.18, 5, 151, R[1])
	for sz: float in [-1.0, 1.0]:
		FoundKit.rivets(k, Vector3(-0.06, 0.47, sz * 0.2), Vector3(0.06, 0.47, sz * 0.2), Vector3.BACK * sz, 3, R[5])
	body_mesh(k, torso)
	add_scan(torso, Vector3(0.088, 0.38, 0), Vector3.RIGHT, Vector3.BACK, 0.18, 0.026, 1.2)
	add_lamp(torso, Vector3(0.0, 0.503, 0.0), Vector3.UP, Vector3.RIGHT, 0.032, 0.036, &"status")
	for sz: float in [-1.0, 1.0]:
		add_lamp(torso, Vector3(0.095, 0.43, sz * 0.1), Vector3(0.998, 0.06, 0), Vector3.UP, 0.022, 0.026, &"optic")
	# The ground it is closing across, lit from the pair of eyes: a dust of
	# pixels by day on anything still about its round, plain on anything sent.
	add_beam(self, Vector3(0.1, HIP_Y + 0.46, 0), Vector3(2.0, -2.2, 0), 1.8, 0.9)
	var tw := FoundKit.kit()
	FoundKit.patch(tw, Vector3(0.089, 0.2, 0.06), Vector3.RIGHT, Vector3.UP, 0.1, 0.12, Palette.MACHINE["longlegs"], 151)
	FoundKit.grime(tw, Vector3(0.0, 0.46, 0.201), Vector3.BACK, 0.16, 0.2, 3, 152, D)
	wear_mesh(tw, torso)
	# A hunter runs dark, and at noon that made it a flat slab: the chest below
	# the slit is the biggest face it turns to the camera, and it carries the
	# years like a hull does — plate stepped over plate, a well, a rubbed edge,
	# grime off the bottom lip.
	day_marks(torso, Vector3(0.086, 0.18, -0.045), Vector3.RIGHT, Vector3.UP, 0.13, 0.2, 153, 2.0)

	for sz: float in [-1.0, 1.0]:
		var s := "r" if sz > 0 else "l"
		var arm := joint(StringName("arm_" + s), torso, Vector3(0, 0.44, sz * 0.23))
		var ak := FoundKit.kit()
		FoundKit.disc(ak, Vector3.ZERO, Vector3.BACK, 0.05, 0.06, 6, 0.012, R)
		FoundKit.tbar(ak, Vector3.ZERO, Vector3(0, -0.46, 0), 0.034, 0.026, 6, D)
		var hand: Array[Vector2] = [Vector2(-0.03, 0.0), Vector2(0.03, 0.0), Vector2(0.025, -0.09), Vector2(-0.025, -0.08)]
		FoundKit.slab(ak, Vector3(0, -0.47, 0), Vector3.RIGHT, Vector3.UP, hand, 0.05, DD, 0.01)
		body_mesh(ak, arm)
		if sz < 0.0:
			# A scrap of someone's coat, tied round the arm.
			var ck2 := FoundKit.matter_kit(Ink.HAND)
			ck2.strut(Vector3(0, -0.08, 0), Vector3(0, -0.18, 0), 0.05, 6, Palette.SAND[4])
			FoundKit.rag(ck2, Vector3(0.02, -0.12, -0.08), 0.36, 0.17, Palette.SAND[4], 153, Vector3(0.5, 0, -0.87))
			wear_matter(ck2, arm)

	# The satchel rides on the back below the shoulder line, so the top of the
	# figure stays flat: headless, not hooded. It is carried on a RACK standing
	# off the spine, not strapped flat to it: seen side-on, a satchel against the
	# back and arms hanging inside the torso's outline made the runner one filled
	# column (0.65 of its own box), and the slot between spine and load is the
	# daylight a courier's frame has always had.
	var satchel := joint(&"satchel", torso, Vector3(-SATCHEL_OFF, 0.3, 0))
	var bk := FoundKit.kit()
	var bag: Array[Vector2] = [Vector2(-0.15, -0.16), Vector2(0.15, -0.16), Vector2(0.17, -0.11), Vector2(0.17, 0.12), Vector2(-0.17, 0.12), Vector2(-0.17, -0.11)]
	FoundKit.slab(bk, Vector3(-SATCHEL_D * 0.5, 0.0, 0), Vector3.BACK, Vector3.UP, bag, SATCHEL_D, R, 0.025)
	FoundKit.rivets(bk, Vector3(-SATCHEL_D + 0.01, -0.1, 0.171), Vector3(-0.01, -0.1, 0.171), Vector3.BACK, 3, R[5], 0.03)
	FoundKit.rivets(bk, Vector3(-SATCHEL_D + 0.01, -0.1, -0.171), Vector3(-0.01, -0.1, -0.171), Vector3.FORWARD, 3, R[5], 0.03)
	FoundKit.streaks(bk, Vector3(-SATCHEL_D - 0.001, -0.1, 0), Vector3.LEFT, 0.22, 0.05, 5, 152, R[1])
	# The rack: two stays over the shoulders down onto the load, and two struts
	# from the small of the back to its foot, each pair clear of the other.
	var back_x := SATCHEL_OFF - 0.09
	for sz: float in [-1.0, 1.0]:
		FoundKit.bar(bk, Vector3(back_x + 0.03, 0.2, sz * 0.11), Vector3(-0.02, 0.11, sz * 0.11), 0.026, 0.03, 0.006, D)
		FoundKit.bar(bk, Vector3(back_x + 0.02, -0.12, sz * 0.12), Vector3(-0.02, -0.12, sz * 0.12), 0.022, 0.026, 0.006, DD)
	body_mesh(bk, satchel)
	var sw := FoundKit.kit()
	FoundKit.cable(sw, Vector3(-0.02, 0.125, -0.13), Vector3(-0.06, -0.12, -0.172), 0.02, 0.012, Palette.INK[2], Palette.MACHINE["clerk"], 3)
	wear_mesh(sw, satchel)
	var pk := FoundKit.kit()
	var pc := Vector3(-SATCHEL_D - 0.001, -0.03, 0)
	FoundKit.mark(pk, pc, Vector3.LEFT, Vector3.UP, 0.28, 0.14, Palette.LENS[0], 0.003)
	FoundKit.mark(pk, pc, Vector3.LEFT, Vector3.UP, 0.24, 0.1, Palette.LENS[2], 0.007)
	FoundKit.mark(pk, pc, Vector3.LEFT, Vector3.UP, 0.14, 0.035, Palette.LENS[3], 0.01)
	part_mesh(pk, satchel)
	set_part_anchor(satchel, pc + Vector3(-0.01, 0, 0), 0.5)

	var flap := joint(&"flap", satchel, Vector3(-SATCHEL_D, 0.12, 0))
	var fk := FoundKit.kit()
	var lid: Array[Vector2] = [Vector2(-0.17, 0.0), Vector2(0.17, 0.0), Vector2(0.16, -0.08), Vector2(0.0, -0.11), Vector2(-0.16, -0.08)]
	FoundKit.slab(fk, Vector3(-0.012, 0.0, 0), Vector3.BACK, Vector3.UP, lid, 0.025, R, 0.008)
	FoundKit.spot(fk, Vector3(-0.026, -0.1, 0), Vector3.LEFT, 0.025, 6, R[5], 0.002)
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
		&"stand":
			# It does not bring its feet together when it stops, because it is
			# never finished going: it holds the step it was on, the front knee
			# over the front foot and the back leg straight behind, weight on
			# neither. Two straight legs side by side were the other half of the
			# filled column; the stride leaves daylight between them.
			d[&"thigh_r"] = r(Vector3(0, 0, STANCE_FRONT))
			d[&"shin_r"] = r(Vector3(0, 0, -STANCE_FRONT))
			d[&"thigh_l"] = r(Vector3(0, 0, -STANCE_BACK))
			d[&"hips"] = pr(Vector3(0, STANCE_DROP, 0))
		&"alert":
			# Stops and squares up: feet planted wide and flat, knees set, arms
			# held out from the sides and still, the satchel flap thrown open.
			d[&"hips"] = pr(Vector3(0, -0.085, 0))
			d[&"thigh_l"] = r(Vector3(0.3, 0, 0.45))
			d[&"thigh_r"] = r(Vector3(-0.3, 0, 0.45))
			d[&"shin_l"] = r(Vector3(-0.3, 0, -0.45))
			d[&"shin_r"] = r(Vector3(0.3, 0, -0.45))
			d[&"arm_l"] = r(Vector3(0.8, 0, 0))
			d[&"arm_r"] = r(Vector3(-0.8, 0, 0))
			d[&"flap"] = r(Vector3(0, 0, -2.4))
		&"windup":
			d[&"torso"] = r(Vector3(0, 0, -0.22))
			d[&"arm_r"] = r(Vector3(-0.2, 0, -1.1))
			d[&"arm_l"] = r(Vector3(0.1, 0, 0.35))
			d[&"thigh_l"] = r(Vector3(0, 0, 0.35))
			d[&"shin_l"] = r(Vector3(0, 0, -0.35))
			d[&"thigh_r"] = r(Vector3(0, 0, -0.25))
			d[&"shin_r"] = r(Vector3(0, 0, 0.2))
			d[&"hips"] = pr(Vector3(0, -0.05, 0))
		&"strike":
			d[&"torso"] = pr(Vector3(0.06, 0, 0), Vector3(0, 0, -0.3))
			d[&"arm_r"] = r(Vector3(0, 0, 1.65))
			d[&"arm_l"] = r(Vector3(0, 0, -0.5))
			d[&"thigh_l"] = r(Vector3(0, 0, 0.5))
			d[&"shin_l"] = r(Vector3(0, 0, -0.2))
			d[&"thigh_r"] = r(Vector3(0, 0, -0.4))
			d[&"shin_r"] = r(Vector3(0, 0, 0.32))
			d[&"hips"] = pr(Vector3(0.1, -0.06, 0))
		&"dead":
			d[&"hips"] = pr(Vector3(0.05, -0.48, 0))
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
