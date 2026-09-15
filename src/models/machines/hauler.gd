extends MachineModel
## A hauler: a line. Two flared ore hoppers on six wheels a side, pivoting on a
## hinge, carrying stone that is never loaded level. It will not turn for you.
## The hinge is open on the LEFT flank only; the right carries a cover plate with
## a cold slit, so the body is deliberately not mirrored there.
##
## walk   the rear hopper swings on the hinge in an exact sway; wheels turn with distance
## alert  both hoppers jack up on their rams
## dead   the hinge folds and the rear hopper tips its load out

const WHEEL_R := 0.11
const SEG_L := 1.0
const SEG_W := 0.58

var _travel := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"left"
	height = 0.9
	stride = 1.4
	gallery_turn = 20.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var front := joint(&"front", self, Vector3(0.6, 0, 0))
	_segment(front, true)
	var rear := joint(&"rear", front, Vector3(-0.62, 0, 0))
	var rear_seg := joint(&"rear_seg", rear, Vector3(-0.6, 0, 0))
	_segment(rear_seg, false)

	# The hinge: a post between the hoppers, open on the left, plated on the right.
	var hk := FoundKit.kit()
	FoundKit.tbar(hk, Vector3(0, 0.12, 0), Vector3(0, 0.66, 0), 0.07, 0.06, 8, R, 0.02)
	FoundKit.disc(hk, Vector3(0, 0.68, 0), Vector3.UP, 0.09, 0.04, 8, 0.012, R, Color(0, 0, 0, 0), PI / 8.0)
	FoundKit.disc(hk, Vector3(0, 0.2, 0), Vector3.UP, 0.12, 0.06, 8, 0.015, D, Color(0, 0, 0, 0), PI / 8.0)
	FoundKit.tbar(hk, Vector3(-0.22, 0.16, 0), Vector3(0.22, 0.16, 0), 0.035, 0.035, 6, D)
	# Left: the open socket, a dark frame round the hinge.
	var sock: Array[Vector2] = [Vector2(-0.14, -0.12), Vector2(0.14, -0.12), Vector2(0.17, 0.0), Vector2(0.14, 0.14), Vector2(-0.14, 0.14), Vector2(-0.17, 0.0)]
	FoundKit.slab(hk, Vector3(0, 0.42, -0.2), Vector3.RIGHT, Vector3.UP, sock, 0.1, FoundKit.dirty(R, 2), 0.02)
	# Right: the cover plate, riveted, with its slit.
	var cover: Array[Vector2] = [Vector2(-0.16, -0.16), Vector2(0.16, -0.16), Vector2(0.2, -0.08), Vector2(0.2, 0.12), Vector2(0.14, 0.18), Vector2(-0.14, 0.18), Vector2(-0.2, 0.12), Vector2(-0.2, -0.08)]
	FoundKit.slab(hk, Vector3(0, 0.42, 0.19), Vector3.RIGHT, Vector3.UP, cover, 0.07, R, 0.02)
	FoundKit.visor(hk, Vector3(0, 0.47, 0.226), Vector3.BACK, Vector3.UP, 0.22, 0.03)
	FoundKit.rivets(hk, Vector3(-0.15, 0.3, 0.226), Vector3(0.15, 0.3, 0.226), Vector3.BACK, 4, R[5])
	FoundKit.streaks(hk, Vector3(0, 0.44, 0.226), Vector3.BACK, 0.18, 0.12, 3, 51, R[1])
	body_mesh(hk, rear)
	add_scan(rear, Vector3(0, 0.47, 0.226), Vector3.BACK, Vector3.RIGHT, 0.16, 0.025, 2.0)
	var pk := FoundKit.kit()
	FoundKit.optic(pk, Vector3(0, 0.42, -0.251), Vector3.FORWARD, 0.08)
	FoundKit.mark(pk, Vector3(0, 0.42, -0.251), Vector3.FORWARD, Vector3.UP, 0.03, 0.24, Palette.LENS[1], 0.014)
	part_mesh(pk, rear)
	set_part_anchor(rear, Vector3(0, 0.42, -0.27), 0.6)
	finish_rig()


## One hopper: chassis, wheels, rams, the flared hopper on its hinge, and its load.
func _segment(seg: Node3D, is_front: bool) -> void:
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)
	var tag := "f" if is_front else "r"
	var ck := FoundKit.kit()
	var beam := FoundKit.plan_oct(SEG_L * 0.92, 0.3, 0.08)
	FoundKit.loft(ck, [FoundKit.ring(beam, 0.09), FoundKit.ring(beam, 0.16, 0.02)], DD)
	for x: float in [-0.3, 0.3]:
		FoundKit.tbar(ck, Vector3(x, 0.14, 0), Vector3(x, 0.3, 0), 0.04, 0.04, 6, D)
	FoundKit.tbar(ck, Vector3(0, WHEEL_R, -SEG_W * 0.5 - 0.02), Vector3(0, WHEEL_R, SEG_W * 0.5 + 0.02), 0.02, 0.02, 4, DD)
	body_mesh(ck, seg)
	for x: float in [-0.34, 0.0, 0.34]:
		for sz: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(x, WHEEL_R, sz * (SEG_W * 0.5 + 0.02))
			seg.add_child(w)
			var wk := FoundKit.kit()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.06, 8, 0.012, DD, D[2], PI / 8.0)
			FoundKit.spot(wk, Vector3(0, 0, sz * 0.031), Vector3.BACK * sz, 0.04, 6, R[4], 0.002)
			FoundKit.mark(wk, Vector3(0, 0.07, sz * 0.031), Vector3.BACK * sz, Vector3.UP, 0.02, 0.04, R[1], 0.003)
			body_mesh(wk, w)
			_wheels.append(w)

	# The hopper pivots on its right bottom edge, so it can tip over that edge.
	var box := joint(StringName("box_" + tag), seg, Vector3(0, 0.26, SEG_W * 0.5))
	var bk := FoundKit.kit()
	bk.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, -SEG_W * 0.5)))
	var plan := FoundKit.plan_oct(SEG_L, SEG_W, 0.12)
	FoundKit.loft(bk, [FoundKit.ring(plan, 0.0, 0.0, Vector2(0.82, 0.8)), FoundKit.ring(plan, 0.04, 0.0, Vector2(0.86, 0.84)), FoundKit.ring(plan, 0.32), FoundKit.ring(plan, 0.36, 0.035)], R, is_front)
	FoundKit.mark(bk, Vector3(0, 0.362, 0), Vector3.UP, Vector3.RIGHT, SEG_W - 0.1, SEG_L - 0.14, R[0], 0.002)
	for sz: float in [-1.0, 1.0]:
		var n := Vector3(0, -0.16, sz).normalized()
		for x: float in [-0.26, 0.0, 0.26]:
			FoundKit.mark(bk, Vector3(x, 0.18, sz * 0.265), n, Vector3(0, 1, sz * 0.16), 0.022, 0.26, R[1], 0.003)
		FoundKit.rivets(bk, Vector3(-0.4, 0.3, sz * 0.291), Vector3(0.4, 0.3, sz * 0.291), n, 8, R[5], 0.03)
		FoundKit.streaks(bk, Vector3(0.13, 0.28, sz * 0.285), n, 0.16, 0.14, 3, 52 + int(sz) + int(is_front) * 4, R[1])
	if is_front:
		# A sloped nose plate with the slit.
		var nose: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.14, 0.02), Vector2(0.1, 0.26), Vector2(0.0, 0.3)]
		FoundKit.slab(bk, Vector3(SEG_L * 0.5 - 0.02, 0.02, 0), Vector3.RIGHT, Vector3.UP, nose, SEG_W * 0.8, R, 0.02)
		FoundKit.visor(bk, Vector3(SEG_L * 0.5 + 0.1, 0.18, 0), Vector3(0.99, 0.16, 0), Vector3(-0.16, 0.99, 0), 0.3, 0.035)
	bk.pop()
	body_mesh(bk, box)
	if is_front:
		add_scan(box, Vector3(SEG_L * 0.5 + 0.1, 0.18, -SEG_W * 0.5), Vector3(0.99, 0.16, 0), Vector3.BACK, 0.24, 0.03, 2.6)

	# The load: stone heaped to one side, never level. The land's, not the machine's.
	var ld := joint(StringName("load_" + tag), box, Vector3(0, 0.36, -SEG_W * 0.5))
	var lk := FoundKit.matter_kit(Ink.CONTOUR)
	var sgn := 1.0 if is_front else -1.0
	for j in 7:
		var a := float(j) / 7.0 * TAU
		var rx := cos(a) * 0.3
		var rz := sin(a) * 0.15 + sgn * 0.04
		var hgt := 0.12 + 0.12 * (0.5 + 0.5 * sin(a * sgn + 0.6)) + Rng.hash01(61, j, int(is_front)) * 0.05
		lk.rock(rx, -0.02, rz, 0.14, hgt, 600 + j * 3 + int(is_front), Palette.STONE[2] if j % 3 == 0 else Palette.STONE[3], 5)
	lk.rock(0.03 * sgn, -0.02, sgn * 0.06, 0.22, 0.28, 640 + int(is_front), Palette.STONE[4], 6)
	matter_mesh(lk, ld)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"box_f"] = pr(Vector3(0, 0.34, 0))
			d[&"box_r"] = pr(Vector3(0, 0.34, 0))
		&"windup":
			d[&"front"] = pr(Vector3(-0.08, 0.05, 0), Vector3(0, 0, 0.12))
			d[&"box_f"] = pr(Vector3(0, 0.14, 0))
			d[&"box_r"] = pr(Vector3(0, 0.08, 0))
			d[&"rear"] = r(Vector3(0, 0, -0.12))
		&"strike":
			d[&"front"] = pr(Vector3(0.22, -0.02, 0), Vector3(0, 0, -0.06))
			d[&"box_f"] = pr(Vector3(0, 0.1, 0))
			d[&"rear"] = r(Vector3(0, 0, 0.06))
		&"dead":
			d[&"rear"] = r(Vector3(0, 0.78, 0))
			d[&"box_r"] = pr(Vector3(0, -0.2, 0.04), Vector3(1.3, 0, 0))
			d[&"load_r"] = pr(Vector3(0.05, -0.2, 0.62), Vector3(0.3, 0.4, 0))
			d[&"box_f"] = pr(Vector3(0, -0.06, 0))
			d[&"front"] = r(Vector3(-0.03, 0, 0))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		match j:
			&"box_r": return Vector2(LIGHT_FIRST + 0.45, 0.45)
			&"load_r": return Vector2(LIGHT_FIRST + 0.7, 0.4)
	return super(p, j)


func _gait_deltas(phase: float) -> Dictionary:
	return {
		&"rear": r(Vector3(0, sin(phase * TAU) * 0.06, 0)),
		&"box_f": pr(Vector3(0, absf(sin(phase * TAU * 2.0)) * 0.012, 0)),
		&"box_r": pr(Vector3(0, absf(cos(phase * TAU * 2.0)) * 0.012, 0)),
		&"load_f": r(Vector3(sin(phase * TAU * 2.0) * 0.03, 0, 0)),
		&"load_r": r(Vector3(cos(phase * TAU * 2.0) * 0.03, 0, 0)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_travel += delta * maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
