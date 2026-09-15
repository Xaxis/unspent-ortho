extends MachineModel
## A warden: a bollard that walks. A solid column under a broad head, on two
## straight legs at one unhurried speed. The band round its front at a person's
## chest height is what reads you and the working part (front). It turns its head
## a quarter and holds it, and back, all night.
##
## alert  squares up: stance wide, head up, the brims slide out, band at full
## hurt   the band goes out and nothing else moves
## dead   it falls over backwards and is still a column

const HIP_Y := 0.56

var _yaw: Node3D


func build() -> void:
	part_side = &"front"
	height = 1.68
	stride = 1.2
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var base := joint(&"base", self, Vector3.ZERO)
	var hips := joint(&"hips", base, Vector3(0, HIP_Y, 0))
	var hk := MeshKit.new()
	FoundKit.cbox(hk, Vector3(0, 0, 0), Vector3(0.3, 0.14, 0.44), 0.03, D)
	body_mesh(hk, hips)
	for sz: float in [-1.0, 1.0]:
		var leg := joint(&"leg_r" if sz > 0 else &"leg_l", hips, Vector3(0, -0.05, sz * 0.13))
		var lk := MeshKit.new()
		FoundKit.bar(lk, Vector3.ZERO, Vector3(0, -0.44, 0), 0.13, 0.13, 0.025, D)
		FoundKit.mark(lk, Vector3(0.066, -0.22, 0), Vector3.RIGHT, Vector3.UP, 0.1, 0.03, R[1])
		FoundKit.cbox(lk, Vector3(0.04, -0.475, 0), Vector3(0.27, 0.07, 0.17), 0.02, FoundKit.dirty(R, 2))
		body_mesh(lk, leg)

	var column := joint(&"column", hips, Vector3(0, 0.07, 0))
	var ck := MeshKit.new()
	FoundKit.disc(ck, Vector3(0, 0.37, 0), Vector3.UP, 0.225, 0.74, 8, 0.03, R, R[3], PI / 8.0)
	FoundKit.disc(ck, Vector3(0, 0.03, 0), Vector3.UP, 0.25, 0.06, 8, 0.015, D, D[3], PI / 8.0)
	FoundKit.disc(ck, Vector3(0, 0.6, 0), Vector3.UP, 0.24, 0.035, 8, 0.0, R, R[3], PI / 8.0)
	var apo := 0.225 * cos(PI / 8.0) + 0.002
	for j in 8:
		var a := float(j) / 8.0 * TAU
		var n := Vector3(cos(a), 0, sin(a))
		FoundKit.rivets(ck, n * apo + Vector3(0, 0.16, 0), n * apo + Vector3(0, 0.16, 0), n, 1, R[5])
		FoundKit.rivets(ck, n * apo + Vector3(0, 0.68, 0), n * apo + Vector3(0, 0.68, 0), n, 1, R[5])
		if cos(a) > 0.5:
			FoundKit.streaks(ck, n * apo + Vector3(0, 0.37, 0), n, 0.12, 0.18, 2, 90 + j, R[2])
		else:
			FoundKit.mark(ck, n * apo + Vector3(0, 0.42, 0), n, Vector3.UP, 0.15, 0.1, R[2])
	body_mesh(ck, column)
	var bk := MeshKit.new()
	for j: int in [-1, 0, 1]:
		var a := float(j) / 8.0 * TAU
		var n := Vector3(cos(a), 0, sin(a))
		FoundKit.mark(bk, n * apo + Vector3(0, 0.42, 0), n, Vector3.UP, 0.17, 0.11, Palette.LENS[0], 0.002)
		FoundKit.mark(bk, n * apo + Vector3(0, 0.42, 0), n, Vector3.UP, 0.17, 0.065, Palette.LENS[2], 0.005)
		FoundKit.mark(bk, n * apo + Vector3(0, 0.42, 0), n, Vector3.UP, 0.17, 0.02, Palette.LENS[3], 0.008)
	part_mesh(bk, column)
	set_part_anchor(column, Vector3(apo, 0.42, 0), 0.75)

	_yaw = Node3D.new()
	_yaw.name = "yaw"
	_yaw.position = Vector3(0, 0.74, 0)
	column.add_child(_yaw)
	var head := joint(&"head", _yaw, Vector3.ZERO)
	var k := MeshKit.new()
	FoundKit.cbox(k, Vector3(0, 0.0, 0), Vector3(0.56, 0.05, 0.94), 0.015, D)
	FoundKit.cbox(k, Vector3(0, 0.14, 0), Vector3(0.5, 0.24, 0.8), 0.07, R, 2)
	FoundKit.cbox(k, Vector3(0, 0.285, 0), Vector3(0.32, 0.06, 0.5), 0.02, R)
	FoundKit.seam(k, Vector3(0.251, 0.04, 0), Vector3(0.251, 0.22, 0), Vector3.RIGHT, R, 2)
	FoundKit.panel(k, Vector3(0.251, 0.13, -0.24), Vector3.RIGHT, Vector3.UP, 0.22, 0.14, R)
	FoundKit.panel(k, Vector3(0.251, 0.13, 0.24), Vector3.RIGHT, Vector3.UP, 0.22, 0.14, R)
	FoundKit.visor(k, Vector3(-0.251, 0.15, 0), Vector3.LEFT, Vector3.UP, 0.5, 0.04)
	FoundKit.streaks(k, Vector3(-0.251, 0.1, 0), Vector3.LEFT, 0.44, 0.07, 5, 93, R[2])
	FoundKit.panel(k, Vector3(0, 0.266, 0), Vector3.UP, Vector3.RIGHT, 0.4, 0.66, R)
	body_mesh(k, head)
	add_scan(head, Vector3(-0.251, 0.15, 0), Vector3.LEFT, Vector3.BACK, 0.42, 0.035, 4.0)
	for sz: float in [-1.0, 1.0]:
		var brim := joint(&"brim_r" if sz > 0 else &"brim_l", head, Vector3(0, 0.14, sz * 0.3))
		var mk := MeshKit.new()
		FoundKit.cbox(mk, Vector3(0, 0, sz * 0.02), Vector3(0.42, 0.16, 0.12), 0.03, R, 2 if sz > 0 else 3)
		FoundKit.mark(mk, Vector3(0.211, 0, sz * 0.02), Vector3.RIGHT, Vector3.UP, 0.06, 0.06, R[5])
		body_mesh(mk, brim)
	finish_rig()


func _light_scale() -> float:
	return 2.0 if pose == &"alert" or pose == &"windup" else 1.0


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"leg_l"] = r(Vector3(0.1, 0, 0))
			d[&"leg_r"] = r(Vector3(-0.1, 0, 0))
			d[&"hips"] = pr(Vector3(0, -0.02, 0))
			d[&"column"] = pr(Vector3(0, 0.08, 0))
			d[&"head"] = pr(Vector3(0, 0.1, 0))
			d[&"brim_l"] = pr(Vector3(0, 0.02, -0.26))
			d[&"brim_r"] = pr(Vector3(0, 0.02, 0.26))
		&"windup":
			d[&"hips"] = r(Vector3(0, 0, -0.1))
			d[&"head"] = pr(Vector3(0, 0.06, 0), Vector3(0, 0, -0.18))
			d[&"brim_l"] = pr(Vector3(0, 0, -0.18))
			d[&"brim_r"] = pr(Vector3(0, 0, 0.18))
		&"strike":
			d[&"hips"] = pr(Vector3(0.12, 0, 0), Vector3(0, 0, -0.22))
			d[&"head"] = pr(Vector3(0, 0.06, 0), Vector3(0, 0, -0.1))
			d[&"brim_l"] = pr(Vector3(0, 0, -0.26))
			d[&"brim_r"] = pr(Vector3(0, 0, 0.26))
		&"dead":
			d[&"base"] = pr(Vector3(0, 0.24, 0), Vector3(0, 0, PI * 0.5))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead" and j == &"base":
		return Vector2(LIGHT_FIRST + 0.2, 0.7)
	return super(p, j)


func _gait_deltas(phase: float) -> Dictionary:
	var s := sin(phase * TAU)
	return {
		&"leg_l": r(Vector3(0, 0, s * 0.32)),
		&"leg_r": r(Vector3(0, 0, -s * 0.32)),
		&"hips": pr(Vector3(0, -absf(s) * 0.03, 0)),
	}


func _routine(_delta: float, on: bool) -> void:
	if not on:
		return
	if pose == &"stand" or pose == &"walk":
		# A quarter turn, hold; back, hold; the other quarter, hold; back.
		var t := fposmod(clock, 9.0) / 9.0
		var slot := int(t * 4.0)
		var within := smoothstep(0.0, 1.0, clampf((t * 4.0 - slot) / 0.3, 0.0, 1.0))
		var bearings := [0.0, 0.9, 0.0, -0.9]
		_yaw.rotation.y = lerpf(float(bearings[(slot + 3) % 4]), float(bearings[slot]), within)
	else:
		_yaw.rotation.y = 0.0
