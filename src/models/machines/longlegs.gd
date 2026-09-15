extends MachineModel
## A long-legs: a gantry. A flat slab slung between four legs that rise above it
## at the knee before they come down to the ground, so what you see first, over a
## dyke, is the legs; and then the daylight under the body. It comes on without
## changing course. The hub where the legs' conduits meet is its working part, on
## the back.
##
## walk   diagonal pairs; the swinging pair lifts at the knee
## alert  stands taller: knees straighten and the legs splay
## dead   the legs splay outward and the slab drops flat between them

const BODY_Y := 1.5
const HIP := Vector2(0.44, 0.3)
## Knee and foot relative to the hip, in the leg's own frame (+X outward).
const KNEE := Vector3(0.3, 0.78, 0.0)
const FOOT_OUT := 0.42


func build() -> void:
	part_side = &"back"
	height = BODY_Y + 0.85
	stride = 2.4
	nominal_speed = 3.0
	gallery_turn = 40.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var body := joint(&"body", self, Vector3(0, BODY_Y, 0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(1.24, 0.9, 0.24)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.13, 0.1), FoundKit.ring(plan, -0.07), FoundKit.ring(plan, 0.07), FoundKit.ring(plan, 0.1, 0.035)], R, true, true)
	# The spine plate, the conduits from each hip to the hub, rivets along the lip.
	var spine := FoundKit.plan_oct(0.74, 0.28, 0.08)
	FoundKit.loft(k, [FoundKit.ring(spine, 0.11), FoundKit.ring(spine, 0.16, 0.03)], R)
	FoundKit.panel(k, Vector3(0.0, 0.161, 0), Vector3.UP, Vector3.RIGHT, 0.54, 0.16, R)
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(HIP.x - 0.08, 0.14, sz * (HIP.y - 0.05)), Vector3(-0.5, 0.14, sz * 0.08), 0.018, 0.018, 4, D)
		FoundKit.tbar(k, Vector3(-HIP.x + 0.08, 0.14, sz * (HIP.y - 0.05)), Vector3(-0.52, 0.14, sz * 0.05), 0.018, 0.018, 4, D)
		FoundKit.rivets(k, Vector3(-0.36, 0.0, sz * 0.451), Vector3(0.36, 0.0, sz * 0.451), Vector3.BACK * sz, 7, R[5])
		FoundKit.streaks(k, Vector3(0.0, -0.06, sz * 0.451), Vector3.BACK * sz, 0.7, 0.06, 6, 21 + int(sz), R[2])
	# Front: the plated face with its visor slit, streaks running down from it.
	FoundKit.visor(k, Vector3(0.621, 0.0, 0), Vector3.RIGHT, Vector3.UP, 0.3, 0.045)
	FoundKit.streaks(k, Vector3(0.621, -0.04, 0), Vector3.RIGHT, 0.26, 0.08, 4, 22, R[2])
	# The hub: a drum on the back face.
	FoundKit.disc(k, Vector3(-0.66, 0.0, 0), Vector3.RIGHT, 0.17, 0.1, 8, 0.03, R, R[2], PI / 8.0)
	# A plumb weight hung under the slab on a line: the only thing that sways, and exactly.
	FoundKit.tbar(k, Vector3(0, -0.13, 0), Vector3(0, -0.36, 0), 0.008, 0.008, 4, D)
	FoundKit.lathe(k, Vector3(0, -0.36, 0), Vector3.DOWN, [Vector2(0.0, -0.02), Vector2(0.05, 0.03), Vector2(0.0, 0.14)], 6, R)
	body_mesh(k, body)
	add_scan(body, Vector3(0.621, 0.0, 0), Vector3.RIGHT, Vector3.BACK, 0.2, 0.035, 3.2)

	var hub := joint(&"hub", body, Vector3(-0.715, 0, 0))
	var pk := FoundKit.kit()
	FoundKit.optic(pk, Vector3.ZERO, Vector3.LEFT, 0.1)
	FoundKit.mark(pk, Vector3.ZERO, Vector3.LEFT, Vector3.UP, 0.02, 0.26, Palette.LENS[1], 0.014)
	FoundKit.mark(pk, Vector3.ZERO, Vector3.LEFT, Vector3.UP, 0.26, 0.02, Palette.LENS[1], 0.015)
	part_mesh(pk, hub)
	set_part_anchor(body, Vector3(-0.73, 0, 0), 0.7)

	for i in 4:
		var sx := 1.0 if i < 2 else -1.0
		var sz := -1.0 if i % 2 == 0 else 1.0
		var yaw := atan2(-sz * 0.8, sx)
		var leg := joint(StringName("leg%d" % i), body, Vector3(sx * HIP.x, 0.02, sz * HIP.y), Vector3(0, yaw, 0))
		var lk := FoundKit.kit()
		FoundKit.disc(lk, Vector3.ZERO, Vector3.UP, 0.075, 0.09, 6, 0.018, R)
		FoundKit.tbar(lk, Vector3(0, 0.02, 0), KNEE, 0.042, 0.03, 6, R)
		FoundKit.disc(lk, KNEE, Vector3.BACK, 0.055, 0.07, 6, 0.015, R)
		FoundKit.mark(lk, KNEE + Vector3(0, 0, 0.036), Vector3.BACK, Vector3.UP, 0.03, 0.03, R[5], 0.003)
		FoundKit.mark(lk, KNEE - Vector3(0, 0, 0.036), Vector3.FORWARD, Vector3.UP, 0.03, 0.03, R[5], 0.003)
		body_mesh(lk, leg)
		var shin := joint(StringName("shin%d" % i), leg, KNEE)
		var foot := Vector3(FOOT_OUT, -(BODY_Y + 0.02 + KNEE.y), 0)
		var sk := FoundKit.kit()
		FoundKit.tbar(sk, Vector3.ZERO, foot * 0.96, 0.028, 0.014, 6, D)
		FoundKit.ticks(sk, foot * 0.2 + Vector3(0, 0, 0.022), foot * 0.5 + Vector3(0, 0, 0.022), Vector3.BACK, 6, R[4], 0.02)
		FoundKit.tbar(sk, foot * 0.96, foot, 0.024, 0.0, 6, FoundKit.dirty(R, 2))
		body_mesh(sk, shin)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"body"] = pr(Vector3(0, 0.36, 0))
			for i in 4:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.28))
				d[StringName("shin%d" % i)] = r(Vector3(0, 0, 0.22))
		&"windup":
			d[&"body"] = pr(Vector3(-0.12, 0.1, 0), Vector3(0, 0, 0.16))
			for i in 4:
				if i < 2:
					d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.3))
					d[StringName("shin%d" % i)] = r(Vector3(0, 0, -0.2))
				else:
					d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.12))
		&"strike":
			d[&"body"] = pr(Vector3(0.26, -0.18, 0), Vector3(0, 0, -0.14))
			for i in 4:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.14))
				d[StringName("shin%d" % i)] = r(Vector3(0, 0, 0.1 if i < 2 else -0.08))
		&"dead":
			d[&"body"] = pr(Vector3(0, -BODY_Y + 0.14, 0), Vector3(0.04, 0, -0.03))
			for i in 4:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.32))
				d[StringName("shin%d" % i)] = r(Vector3(0, 0, 1.06))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead" and j == &"body":
		return Vector2(LIGHT_FIRST + 0.1, 0.5)
	return super(p, j)


## Diagonal pairs swing together; the pair in the air lifts at the knee.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	var s := sin(phase * TAU)
	for i in 4:
		var pair := 1.0 if i == 0 or i == 3 else -1.0
		var sx := 1.0 if i < 2 else -1.0
		d[StringName("leg%d" % i)] = r(Vector3(0, s * pair * 0.3 * sx, 0))
		var lift := maxf(0.0, cos(phase * TAU) * pair)
		d[StringName("shin%d" % i)] = r(Vector3(0, 0, -lift * 0.14))
	d[&"body"] = pr(Vector3(0, -absf(s) * 0.05, 0))
	return d
