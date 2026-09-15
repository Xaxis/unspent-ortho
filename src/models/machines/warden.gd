extends MachineModel
## A warden: a bollard that walks. An eight-sided column under a broad flat cap,
## on two short straight legs at one unhurried speed. The amber band round its
## front at a person's chest height is what reads you, and the working part
## (front). It turns its head a quarter and holds it, and back, all night.
##
## alert  squares up: stance wide, cap up on its collar, the brims slide out, band at full
## hurt   the band goes out and nothing else moves
## dead   it falls over backwards and is still a column

const HIP_Y := 0.5
const COL_R := 0.22

var _yaw: Node3D


func build() -> void:
	part_side = &"front"
	height = 1.66
	stride = 1.2
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var base := joint(&"base", self, Vector3.ZERO)
	var hips := joint(&"hips", base, Vector3(0, HIP_Y, 0))
	var hk := FoundKit.kit()
	FoundKit.disc(hk, Vector3(0, -0.02, 0), Vector3.UP, 0.2, 0.08, 8, 0.02, D, Color(0, 0, 0, 0), PI / 8.0)
	body_mesh(hk, hips)
	for sz: float in [-1.0, 1.0]:
		var leg := joint(&"leg_r" if sz > 0 else &"leg_l", hips, Vector3(0, -0.05, sz * 0.12))
		var lk := FoundKit.kit()
		FoundKit.tbar(lk, Vector3.ZERO, Vector3(0, -0.4, 0), 0.07, 0.06, 8, D, 0.02)
		FoundKit.mark(lk, Vector3(0.066, -0.2, 0), Vector3.RIGHT, Vector3.UP, 0.05, 0.02, R[5], 0.004)
		var shoe: Array[Vector2] = [Vector2(-0.1, 0.0), Vector2(0.16, 0.0), Vector2(0.12, 0.05), Vector2(-0.08, 0.06)]
		FoundKit.slab(lk, Vector3(0, -HIP_Y + 0.05, 0), Vector3.RIGHT, Vector3.UP, shoe, 0.13, DD, 0.012)
		body_mesh(lk, leg)

	var column := joint(&"column", hips, Vector3(0, 0.04, 0))
	var ck := FoundKit.kit()
	# The column: eight flat sides, a plinth ring at the foot and a collar at the top.
	FoundKit.lathe(ck, Vector3.ZERO, Vector3.UP, [Vector2(0.2, 0.0), Vector2(0.24, 0.04), Vector2(0.24, 0.1), Vector2(COL_R, 0.13), Vector2(COL_R, 0.72), Vector2(0.235, 0.74), Vector2(0.235, 0.8), Vector2(0.18, 0.84)], 8, R, PI / 8.0)
	var apo := COL_R * cos(PI / 8.0) + 0.002
	for j in 8:
		var a := float(j) / 8.0 * TAU
		var n := Vector3(cos(a), 0, sin(a))
		FoundKit.mark(ck, n * apo + Vector3(0, 0.2, 0), n, Vector3.UP, 0.035, 0.035, R[5], 0.004)
		FoundKit.mark(ck, n * apo + Vector3(0, 0.62, 0), n, Vector3.UP, 0.035, 0.035, R[5], 0.004)
		if cos(a) < -0.5:
			FoundKit.visor(ck, n * apo + Vector3(0, 0.44, 0), n, Vector3.UP, 0.12, 0.03)
		elif cos(a) > 0.5:
			FoundKit.streaks(ck, n * apo + Vector3(0, 0.38, 0), n, 0.1, 0.18, 2, 90 + j, R[1])
	body_mesh(ck, column)
	add_scan(column, Vector3(-apo, 0.44, 0), Vector3.LEFT, Vector3.BACK, 0.08, 0.025, 4.0)
	# The band: three front faces of the column, amber at chest height.
	var bk := FoundKit.kit()
	for j: int in [-1, 0, 1]:
		var a := float(j) / 8.0 * TAU
		var n := Vector3(cos(a), 0, sin(a))
		var along := Vector3.UP.cross(n)
		FoundKit.mark(bk, n * apo + Vector3(0, 0.46, 0), n, Vector3.UP, 0.175, 0.1, Palette.LENS[0], 0.003)
		FoundKit.mark(bk, n * apo + Vector3(0, 0.46, 0), n, Vector3.UP, 0.175, 0.055, Palette.LENS[2], 0.006)
		FoundKit.mark(bk, n * apo + Vector3(0, 0.46, 0) + along * 0.0, n, Vector3.UP, 0.12 if j == 0 else 0.05, 0.018, Palette.LENS[3], 0.009)
	part_mesh(bk, column)
	set_part_anchor(column, Vector3(apo, 0.46, 0), 0.7)

	_yaw = Node3D.new()
	_yaw.name = "yaw"
	_yaw.position = Vector3(0, 0.84, 0)
	column.add_child(_yaw)
	var head := joint(&"head", _yaw, Vector3.ZERO)
	var k := FoundKit.kit()
	# The cap: broad, flat, oval across the shoulders, eight-sided like the column.
	FoundKit.lathe(k, Vector3.ZERO, Vector3.UP, [Vector2(0.18, 0.0), Vector2(0.4, 0.05), Vector2(0.43, 0.09), Vector2(0.43, 0.13), Vector2(0.34, 0.2), Vector2(0.16, 0.24)], 8, R, PI / 8.0, Vector2(1.0, 0.62), Color(0, 0, 0, 0), 3)
	FoundKit.disc(k, Vector3(0, 0.26, 0), Vector3.UP, 0.08, 0.04, 8, 0.012, R, Color(0, 0, 0, 0), PI / 8.0)
	for sz: float in [-1.0, 1.0]:
		FoundKit.rivets(k, Vector3(-0.1, 0.19, sz * 0.24), Vector3(0.1, 0.19, sz * 0.24), Vector3(0, 0.8, sz * 0.6).normalized(), 3, R[5])
	FoundKit.streaks(k, Vector3(0.255, 0.06, 0), Vector3.RIGHT, 0.2, 0.05, 4, 93, R[1])
	body_mesh(k, head)
	for sz: float in [-1.0, 1.0]:
		var brim := joint(&"brim_r" if sz > 0 else &"brim_l", head, Vector3(0, 0.09, sz * 0.33))
		var mk := FoundKit.kit()
		var blade: Array[Vector2] = [Vector2(-0.2, 0.0), Vector2(0.2, 0.0), Vector2(0.14, 0.14), Vector2(-0.14, 0.14)]
		FoundKit.slab(mk, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK * sz, blade, 0.04, R, 0.01)
		FoundKit.mark(mk, Vector3(0, 0.021, sz * 0.12), Vector3.UP, Vector3.RIGHT, 0.26, 0.016, R[5], 0.002)
		body_mesh(mk, brim)
	finish_rig()


func _light_scale() -> float:
	return 2.0 if pose == &"alert" or pose == &"windup" else 1.0


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"leg_l"] = r(Vector3(0.14, 0, 0))
			d[&"leg_r"] = r(Vector3(-0.14, 0, 0))
			d[&"hips"] = pr(Vector3(0, -0.03, 0))
			d[&"column"] = pr(Vector3(0, 0.06, 0))
			d[&"head"] = pr(Vector3(0, 0.16, 0))
			d[&"brim_l"] = pr(Vector3(0, 0.02, -0.05), Vector3(0.75, 0, 0))
			d[&"brim_r"] = pr(Vector3(0, 0.02, 0.05), Vector3(-0.75, 0, 0))
		&"windup":
			d[&"hips"] = r(Vector3(0, 0, -0.1))
			d[&"head"] = pr(Vector3(0, 0.08, 0), Vector3(0, 0, -0.16))
			d[&"brim_l"] = r(Vector3(0.45, 0, 0))
			d[&"brim_r"] = r(Vector3(-0.45, 0, 0))
		&"strike":
			d[&"hips"] = pr(Vector3(0.12, 0, 0), Vector3(0, 0, -0.22))
			d[&"head"] = pr(Vector3(0, 0.06, 0), Vector3(0, 0, -0.1))
			d[&"brim_l"] = r(Vector3(0.75, 0, 0))
			d[&"brim_r"] = r(Vector3(-0.75, 0, 0))
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
		&"leg_l": r(Vector3(0, 0, s * 0.34)),
		&"leg_r": r(Vector3(0, 0, -s * 0.34)),
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
