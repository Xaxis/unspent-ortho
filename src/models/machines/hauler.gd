extends MachineModel
## A hauler: a line. Two ore boxes on six wheels a side, pivoting on a hinge,
## carrying stone that is never loaded level. It will not turn for you. The
## hinge is open on the LEFT flank only; the right carries a cover plate, so the
## body is deliberately not mirrored there.
##
## walk   the rear box swings on the hinge in an exact sway; wheels turn with distance
## alert  both boxes jack up on their struts
## dead   the hinge folds and the rear box tips its load out

const WHEEL_R := 0.12
const SEG_L := 1.05
const SEG_W := 0.62

var _travel := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"left"
	height = 0.95
	stride = 1.4
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var front := joint(&"front", self, Vector3(0.58, 0, 0))
	_segment(front, true)
	var rear := joint(&"rear", front, Vector3(-0.6, 0, 0))
	var rear_seg := joint(&"rear_seg", rear, Vector3(-0.58, 0, 0))
	_segment(rear_seg, false)

	# The hinge: a post between the boxes, open on the left, plated on the right.
	var hk := MeshKit.new()
	FoundKit.cbox(hk, Vector3(0, 0.42, 0), Vector3(0.14, 0.52, 0.14), 0.03, R)
	FoundKit.cbox(hk, Vector3(0, 0.2, 0), Vector3(0.36, 0.08, 0.2), 0.02, D)
	FoundKit.cbox(hk, Vector3(0, 0.44, -0.28), Vector3(0.3, 0.3, 0.16), 0.03, R)
	FoundKit.cbox(hk, Vector3(0, 0.44, 0.27), Vector3(0.34, 0.34, 0.12), 0.03, R, 0)
	FoundKit.visor(hk, Vector3(0, 0.46, 0.331), Vector3.BACK, Vector3.UP, 0.2, 0.035)
	FoundKit.rivets(hk, Vector3(-0.13, 0.31, 0.331), Vector3(0.13, 0.31, 0.331), Vector3.BACK, 4, R[5])
	FoundKit.streaks(hk, Vector3(0, 0.42, 0.331), Vector3.BACK, 0.16, 0.12, 3, 51, R[2])
	body_mesh(hk, rear)
	add_scan(rear, Vector3(0, 0.46, 0.331), Vector3.BACK, Vector3.RIGHT, 0.14, 0.03, 2.0)
	var pk := MeshKit.new()
	FoundKit.mark(pk, Vector3(0, 0.44, -0.361), Vector3.FORWARD, Vector3.UP, 0.24, 0.24, Palette.LENS[0], 0.002)
	FoundKit.mark(pk, Vector3(0, 0.44, -0.361), Vector3.FORWARD, Vector3.UP, 0.08, 0.22, Palette.LENS[2], 0.006)
	FoundKit.mark(pk, Vector3(0, 0.52, -0.361), Vector3.FORWARD, Vector3.UP, 0.18, 0.04, Palette.LENS[2], 0.008)
	FoundKit.mark(pk, Vector3(0, 0.36, -0.361), Vector3.FORWARD, Vector3.UP, 0.18, 0.04, Palette.LENS[2], 0.008)
	FoundKit.mark(pk, Vector3(0, 0.44, -0.361), Vector3.FORWARD, Vector3.UP, 0.05, 0.05, Palette.LENS[3], 0.01)
	part_mesh(pk, rear)
	set_part_anchor(rear, Vector3(0, 0.44, -0.37), 0.7)
	finish_rig()


## One ore box: chassis, wheels, struts, the box on its jack, and its load.
func _segment(seg: Node3D, is_front: bool) -> void:
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)
	var tag := "f" if is_front else "r"
	var ck := MeshKit.new()
	FoundKit.cbox(ck, Vector3(0, 0.13, 0), Vector3(SEG_L * 0.94, 0.06, SEG_W * 0.7), 0.02, DD)
	for x: float in [-0.34, 0.34]:
		for sz: float in [-1.0, 1.0]:
			FoundKit.bar(ck, Vector3(x, 0.14, sz * 0.2), Vector3(x, 0.58, sz * 0.2), 0.05, 0.05, 0.01, D)
	body_mesh(ck, seg)
	for x: float in [-0.36, 0.0, 0.36]:
		for sz: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(x, WHEEL_R, sz * (SEG_W * 0.5 + 0.02))
			seg.add_child(w)
			var wk := MeshKit.new()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.07, 8, 0.012, DD, D[2])
			FoundKit.mark(wk, Vector3(0, 0.07, sz * 0.036), Vector3.BACK * sz, Vector3.UP, 0.025, 0.05, R[1], 0.002)
			FoundKit.mark(wk, Vector3(0, 0, sz * 0.036), Vector3.BACK * sz, Vector3.UP, 0.04, 0.04, R[4], 0.003)
			body_mesh(wk, w)
			_wheels.append(w)

	# The box pivots on its right bottom edge, so it can tip over that edge.
	var box := joint(StringName("box_" + tag), seg, Vector3(0, 0.24, SEG_W * 0.5))
	var bk := MeshKit.new()
	bk.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, -SEG_W * 0.5)))
	FoundKit.cbox(bk, Vector3(0, 0.2, 0), Vector3(SEG_L, 0.36, SEG_W), 0.05, R, 2 if is_front else -1)
	FoundKit.cbox(bk, Vector3(0, 0.39, 0), Vector3(SEG_L + 0.04, 0.04, SEG_W + 0.04), 0.015, R)
	for sz: float in [-1.0, 1.0]:
		FoundKit.seam(bk, Vector3(-0.2, 0.05, sz * (SEG_W * 0.5 + 0.001)), Vector3(-0.2, 0.34, sz * (SEG_W * 0.5 + 0.001)), Vector3.BACK * sz, R, 3)
		FoundKit.seam(bk, Vector3(0.2, 0.05, sz * (SEG_W * 0.5 + 0.001)), Vector3(0.2, 0.34, sz * (SEG_W * 0.5 + 0.001)), Vector3.BACK * sz, R, 3)
		FoundKit.streaks(bk, Vector3(0, 0.36, sz * (SEG_W * 0.5 + 0.001)), Vector3.BACK * sz, SEG_L * 0.8, 0.14, 6, 52 if is_front else 53, R[2])
		FoundKit.mark(bk, Vector3(0, 0.05, sz * (SEG_W * 0.5 + 0.001)), Vector3.BACK * sz, Vector3.UP, SEG_L - 0.1, 0.06, R[2], 0.002)
	if is_front:
		FoundKit.cbox(bk, Vector3(SEG_L * 0.5 + 0.06, 0.16, 0), Vector3(0.14, 0.26, SEG_W * 0.8), 0.04, R)
		FoundKit.visor(bk, Vector3(SEG_L * 0.5 + 0.131, 0.19, 0), Vector3.RIGHT, Vector3.UP, 0.36, 0.045)
		FoundKit.rivets(bk, Vector3(SEG_L * 0.5 + 0.131, 0.08, -0.18), Vector3(SEG_L * 0.5 + 0.131, 0.08, 0.18), Vector3.RIGHT, 4, R[5])
	bk.pop()
	body_mesh(bk, box)
	if is_front:
		add_scan(box, Vector3(SEG_L * 0.5 + 0.131, 0.19, -SEG_W * 0.5), Vector3.RIGHT, Vector3.BACK, 0.3, 0.035, 2.6)

	# The load: stone heaped to one side, never level.
	var ld := joint(StringName("load_" + tag), box, Vector3(0, 0.38, -SEG_W * 0.5))
	var lk := MeshKit.new()
	var sgn := 1.0 if is_front else -1.0
	for j in 7:
		var a := float(j) / 7.0 * TAU
		var rx := cos(a) * 0.32
		var rz := sin(a) * 0.17 + sgn * 0.05
		var hgt := 0.16 + 0.12 * (0.5 + 0.5 * sin(a * sgn + 0.6)) + Rng.hash01(61, j, int(is_front)) * 0.05
		lk.rock(rx, 0.0, rz, 0.16, hgt, 600 + j * 3 + int(is_front), Palette.STONE[2] if j % 3 == 0 else Palette.STONE[3], 5)
	lk.rock(0.02, 0.0, sgn * 0.06, 0.24, 0.3, 640 + int(is_front), Palette.STONE[3], 6)
	body_mesh(lk, ld)


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
