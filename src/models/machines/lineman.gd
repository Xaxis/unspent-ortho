extends MachineModel
## A lineman: a staple. A small coffin-shaped body with both arms straight up,
## made to hang from a span and work along it hand over hand. On the ground it
## still walks with its arms up, grips opening and closing on nothing. The motor
## in its front is the working part.
##
## alert  lets go and comes down: the arms telescope in and reach forward
## dead   the arms come down first, then the body goes over

const SLEEVE := 0.8
const FORE := 0.8

var _grip_t := 0.0


func build() -> void:
	part_side = &"front"
	height = 2.62
	stride = 0.8
	gallery_turn = 25.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var body := joint(&"body", self, Vector3(0, 0.3, 0))
	var k := FoundKit.kit()
	# Coffin plan: narrow at the foot, widest at the shoulders, a sloped lid.
	var plan := FoundKit.plan_oct(0.4, 0.62, 0.12)
	FoundKit.loft(k, [FoundKit.ring(plan, 0.0, 0.0, Vector2(0.8, 0.62)), FoundKit.ring(plan, 0.44, 0.0, Vector2(1.0, 1.0)), FoundKit.ring(plan, 0.56, 0.0, Vector2(0.96, 0.96)), FoundKit.ring(plan, 0.64, 0.08)], R, true)
	# The shoulder yoke the arms ride in.
	FoundKit.tbar(k, Vector3(0, 0.6, -0.46), Vector3(0, 0.6, 0.46), 0.05, 0.05, 8, R, 0.015)
	FoundKit.disc(k, Vector3(0.205, 0.3, 0), Vector3.RIGHT, 0.13, 0.05, 8, 0.015, R, R[1], PI / 8.0)
	FoundKit.streaks(k, Vector3(0.2, 0.16, 0), Vector3.RIGHT, 0.22, 0.12, 4, 131, R[1])
	FoundKit.visor(k, Vector3(-0.199, 0.46, 0), Vector3.LEFT, Vector3.UP, 0.36, 0.04)
	FoundKit.seam(k, Vector3(-0.185, 0.08, 0), Vector3(-0.199, 0.34, 0), Vector3.LEFT, R, 3)
	for sz: float in [-1.0, 1.0]:
		FoundKit.rivets(k, Vector3(-0.12, 0.5, sz * 0.311), Vector3(0.12, 0.5, sz * 0.311), Vector3.BACK * sz, 4, R[5])
		FoundKit.streaks(k, Vector3(0.0, 0.42, sz * 0.305), Vector3.BACK * sz, 0.24, 0.2, 4, 133 + int(sz), R[1])
	body_mesh(k, body)
	add_scan(body, Vector3(-0.199, 0.46, 0), Vector3.LEFT, Vector3.BACK, 0.3, 0.035, 2.8)
	var pk := FoundKit.kit()
	FoundKit.optic(pk, Vector3(0.231, 0.3, 0), Vector3.RIGHT, 0.075)
	FoundKit.mark(pk, Vector3(0.231, 0.3, 0), Vector3.RIGHT, Vector3.UP, 0.2, 0.02, Palette.LENS[1], 0.013)
	part_mesh(pk, body)
	set_part_anchor(body, Vector3(0.24, 0.3, 0), 0.55)

	for sz: float in [-1.0, 1.0]:
		var leg := joint(&"leg_r" if sz > 0 else &"leg_l", body, Vector3(0, 0.04, sz * 0.12))
		var lk := FoundKit.kit()
		FoundKit.tbar(lk, Vector3.ZERO, Vector3(0, -0.28, 0), 0.05, 0.04, 6, DD)
		var shoe: Array[Vector2] = [Vector2(-0.07, 0.0), Vector2(0.12, 0.0), Vector2(0.08, 0.04), Vector2(-0.05, 0.04)]
		FoundKit.slab(lk, Vector3(0, -0.3, 0), Vector3.RIGHT, Vector3.UP, shoe, 0.1, DD, 0.01)
		body_mesh(lk, leg)

		var side := "r" if sz > 0 else "l"
		var arm := joint(StringName("arm_" + side), body, Vector3(0, 0.6, sz * 0.5))
		var ak := FoundKit.kit()
		FoundKit.disc(ak, Vector3.ZERO, Vector3.BACK, 0.075, 0.1, 8, 0.02, R, Color(0, 0, 0, 0), PI / 8.0)
		FoundKit.tbar(ak, Vector3.ZERO, Vector3(0, SLEEVE, 0), 0.05, 0.042, 8, R, 0.015)
		FoundKit.disc(ak, Vector3(0, SLEEVE, 0), Vector3.UP, 0.058, 0.04, 8, 0.012, R, Color(0, 0, 0, 0), PI / 8.0)
		FoundKit.streaks(ak, Vector3(0.045, SLEEVE - 0.04, 0), Vector3.RIGHT, 0.0, 0.3, 1, 132, R[1])
		body_mesh(ak, arm)
		var fore := joint(StringName("fore_" + side), arm, Vector3(0, SLEEVE - 0.05, 0))
		var fk := FoundKit.kit()
		FoundKit.tbar(fk, Vector3(0, -0.4, 0), Vector3(0, FORE, 0), 0.03, 0.03, 6, D)
		FoundKit.ticks(fk, Vector3(0.03, 0.1, 0), Vector3(0.03, 0.6, 0), Vector3.RIGHT, 11, R[4], 0.02)
		body_mesh(fk, fore)
		var grip := joint(StringName("grip_" + side), fore, Vector3(0, FORE, 0))
		var gk := FoundKit.kit()
		FoundKit.disc(gk, Vector3(0, 0.03, 0), Vector3.UP, 0.055, 0.06, 6, 0.012, R)
		body_mesh(gk, grip)
		for sx: float in [-1.0, 1.0]:
			var prong := joint(StringName("prong_%s%d" % [side, int(sx > 0)]), grip, Vector3(sx * 0.035, 0.06, 0))
			var ck := FoundKit.kit()
			var pale: Array = [R[3], R[3], R[4], R[5], R[5], R[5]]
			FoundKit.tbar(ck, Vector3.ZERO, Vector3(sx * 0.03, 0.12, 0), 0.016, 0.014, 4, pale)
			FoundKit.tbar(ck, Vector3(sx * 0.03, 0.12, 0), Vector3(-sx * 0.03, 0.18, 0), 0.014, 0.006, 4, pale)
			body_mesh(ck, prong)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"body"] = pr(Vector3(0, -0.05, 0), Vector3(0, 0, -0.06))
			for s: String in ["l", "r"]:
				d[StringName("arm_" + s)] = r(Vector3(0, 0, -0.62))
				d[StringName("fore_" + s)] = pr(Vector3(0, -0.72, 0))
				d[StringName("grip_" + s)] = r(Vector3(0, 0, -0.5))
			d[&"prong_l0"] = r(Vector3(0, 0, 0.5))
			d[&"prong_l1"] = r(Vector3(0, 0, -0.5))
			d[&"prong_r0"] = r(Vector3(0, 0, 0.5))
			d[&"prong_r1"] = r(Vector3(0, 0, -0.5))
		&"windup":
			d[&"body"] = pr(Vector3(-0.04, -0.04, 0), Vector3(0, 0, 0.08))
			for s: String in ["l", "r"]:
				d[StringName("arm_" + s)] = r(Vector3(0, 0, -1.35))
				d[StringName("fore_" + s)] = pr(Vector3(0, -0.45, 0))
			d[&"prong_l0"] = r(Vector3(0, 0, 0.7))
			d[&"prong_l1"] = r(Vector3(0, 0, -0.7))
			d[&"prong_r0"] = r(Vector3(0, 0, 0.7))
			d[&"prong_r1"] = r(Vector3(0, 0, -0.7))
		&"strike":
			d[&"body"] = pr(Vector3(0.1, -0.02, 0), Vector3(0, 0, -0.1))
			for s: String in ["l", "r"]:
				d[StringName("arm_" + s)] = r(Vector3(0, 0, -1.5))
				d[StringName("fore_" + s)] = pr(Vector3(0, 0.3, 0))
		&"dead":
			d[&"arm_l"] = r(Vector3(-1.45, 0, 0))
			d[&"arm_r"] = r(Vector3(1.45, 0, 0))
			d[&"fore_l"] = pr(Vector3(0, -0.3, 0))
			d[&"fore_r"] = pr(Vector3(0, -0.3, 0))
			d[&"body"] = pr(Vector3(-0.12, -0.1, 0), Vector3(0, 0, 1.25))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		match j:
			&"arm_l", &"arm_r": return Vector2(LIGHT_FIRST, 0.45)
			&"fore_l", &"fore_r": return Vector2(LIGHT_FIRST + 0.2, 0.3)
			&"body": return Vector2(LIGHT_FIRST + 0.75, 0.55)
	return super(p, j)


func _gait_deltas(phase: float) -> Dictionary:
	var s := sin(phase * TAU)
	return {
		&"leg_l": r(Vector3(0, 0, s * 0.45)),
		&"leg_r": r(Vector3(0, 0, -s * 0.45)),
		&"body": pr(Vector3(0, absf(cos(phase * TAU)) * 0.03, 0)),
	}


## Hand over hand: one grip reaches up and closes while the other lets go.
func _routine(delta: float, on: bool) -> void:
	if not on or not (pose == &"stand" or pose == &"walk"):
		return
	_grip_t += delta
	var t := fposmod(_grip_t, 1.6) / 1.6
	for side in 2:
		var s := "l" if side == 0 else "r"
		var local := fposmod(t + side * 0.5, 1.0)
		var reach := smoothstep(0.0, 0.4, local) - smoothstep(0.5, 0.9, local)
		(joints[StringName("fore_" + s)] as Node3D).position.y += reach * 0.12
		var open := 0.45 * (1.0 - smoothstep(0.35, 0.45, local)) * smoothstep(0.0, 0.1, local)
		(joints[StringName("prong_%s0" % s)] as Node3D).rotation.z += open
		(joints[StringName("prong_%s1" % s)] as Node3D).rotation.z -= open
