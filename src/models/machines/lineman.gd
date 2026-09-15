extends MachineModel
## A lineman: a staple. A small body with both arms straight up, made to hang
## from a span and work along it hand over hand. On the ground it still walks
## with its arms up, grips opening and closing on nothing. The motor in its front
## is the working part.
##
## alert  lets go and comes down: the arms telescope in and reach forward
## dead   the arms come down first, then the body goes over

const SLEEVE := 0.78
const FORE := 0.8

var _grip_t := 0.0


func build() -> void:
	part_side = &"front"
	height = 2.62
	stride = 0.8
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var body := joint(&"body", self, Vector3(0, 0.3, 0))
	var k := MeshKit.new()
	FoundKit.cbox(k, Vector3(0, 0.3, 0), Vector3(0.42, 0.58, 0.6), 0.07, R, 2)
	FoundKit.cbox(k, Vector3(0, 0.62, 0), Vector3(0.3, 0.09, 0.9), 0.03, R)
	FoundKit.cbox(k, Vector3(0, 0.02, 0), Vector3(0.34, 0.06, 0.46), 0.02, D)
	FoundKit.disc(k, Vector3(0.225, 0.34, 0), Vector3.RIGHT, 0.14, 0.05, 8, 0.015, R, R[1], PI / 8.0)
	FoundKit.streaks(k, Vector3(0.211, 0.19, 0), Vector3.RIGHT, 0.3, 0.12, 4, 131, R[2])
	FoundKit.visor(k, Vector3(-0.211, 0.42, 0), Vector3.LEFT, Vector3.UP, 0.4, 0.045)
	FoundKit.seam(k, Vector3(-0.211, 0.1, 0), Vector3(-0.211, 0.34, 0), Vector3.LEFT, R, 3)
	for sz: float in [-1.0, 1.0]:
		FoundKit.panel(k, Vector3(0, 0.3, sz * 0.301), Vector3.BACK * sz, Vector3.UP, 0.26, 0.4, R)
	body_mesh(k, body)
	add_scan(body, Vector3(-0.211, 0.42, 0), Vector3.LEFT, Vector3.BACK, 0.34, 0.04, 2.8)
	var pk := MeshKit.new()
	FoundKit.disc(pk, Vector3(0.252, 0.34, 0), Vector3.RIGHT, 0.1, 0.01, 8, 0.0, R, Palette.LENS[2], PI / 8.0)
	FoundKit.mark(pk, Vector3(0.258, 0.34, 0), Vector3.RIGHT, Vector3.UP, 0.12, 0.03, Palette.LENS[3], 0.002)
	FoundKit.mark(pk, Vector3(0.258, 0.34, 0), Vector3.RIGHT, Vector3.UP, 0.03, 0.12, Palette.LENS[3], 0.003)
	part_mesh(pk, body)
	set_part_anchor(body, Vector3(0.26, 0.34, 0), 0.6)

	for sz: float in [-1.0, 1.0]:
		var leg := joint(&"leg_r" if sz > 0 else &"leg_l", body, Vector3(0, 0.02, sz * 0.16))
		var lk := MeshKit.new()
		FoundKit.bar(lk, Vector3.ZERO, Vector3(0, -0.27, 0), 0.09, 0.09, 0.015, DD)
		FoundKit.cbox(lk, Vector3(0.03, -0.285, 0), Vector3(0.2, 0.04, 0.12), 0.01, DD)
		body_mesh(lk, leg)

		var side := "r" if sz > 0 else "l"
		var arm := joint(StringName("arm_" + side), body, Vector3(0, 0.62, sz * 0.46))
		var ak := MeshKit.new()
		FoundKit.cbox(ak, Vector3.ZERO, Vector3(0.14, 0.14, 0.12), 0.03, R)
		FoundKit.bar(ak, Vector3.ZERO, Vector3(0, SLEEVE, 0), 0.085, 0.085, 0.015, R)
		FoundKit.cbox(ak, Vector3(0, SLEEVE, 0), Vector3(0.11, 0.05, 0.11), 0.015, R)
		FoundKit.streaks(ak, Vector3(0.043, SLEEVE - 0.04, 0), Vector3.RIGHT, 0.0, 0.3, 1, 132, R[2])
		body_mesh(ak, arm)
		var fore := joint(StringName("fore_" + side), arm, Vector3(0, SLEEVE - 0.05, 0))
		var fk := MeshKit.new()
		FoundKit.bar(fk, Vector3(0, -0.4, 0), Vector3(0, FORE, 0), 0.055, 0.055, 0.01, D)
		for y: float in [0.2, 0.45]:
			FoundKit.mark(fk, Vector3(0.028, y, 0), Vector3.RIGHT, Vector3.UP, 0.04, 0.02, R[1])
		body_mesh(fk, fore)
		var grip := joint(StringName("grip_" + side), fore, Vector3(0, FORE, 0))
		var gk := MeshKit.new()
		FoundKit.cbox(gk, Vector3(0, 0.03, 0), Vector3(0.12, 0.07, 0.1), 0.02, R)
		body_mesh(gk, grip)
		for sx: float in [-1.0, 1.0]:
			var prong := joint(StringName("prong_%s%d" % [side, int(sx > 0)]), grip, Vector3(sx * 0.04, 0.06, 0))
			var ck := MeshKit.new()
			var pale: Array = [R[3], R[3], R[4], R[5], R[5], R[5]]
			FoundKit.bar(ck, Vector3.ZERO, Vector3(sx * 0.02, 0.11, 0), 0.03, 0.04, 0.0, pale)
			FoundKit.bar(ck, Vector3(sx * 0.02, 0.11, 0), Vector3(-sx * 0.035, 0.16, 0), 0.028, 0.04, 0.0, pale)
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
			d[&"body"] = pr(Vector3(-0.12, -0.08, 0), Vector3(0, 0, 1.2))
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
