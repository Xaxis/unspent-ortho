extends MachineModel
## A clerk: an archway walking, all head and all legs. A filing case carried
## between two long legs that rise above it at the knee, stooped, head down at
## hip height, reading the ground. It was never built to be near anything: no
## working part. What it sees goes through the slit in its face.
##
## alert  the head comes up on a neck that was not there
## dead   the legs go out sideways; the head comes down last

const HIP_Y := 0.6

var _read_t := 0.0


func build() -> void:
	part_side = &"none"
	height = 1.05
	stride = 0.7
	nominal_speed = 1.2
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hips := joint(&"hips", self, Vector3(0, HIP_Y, 0))
	for sz: float in [-1.0, 1.0]:
		var s := "r" if sz > 0 else "l"
		var thigh := joint(StringName("thigh_" + s), hips, Vector3(0, 0.0, sz * 0.31))
		var tk := MeshKit.new()
		FoundKit.cbox(tk, Vector3.ZERO, Vector3(0.1, 0.1, 0.08), 0.025, R)
		FoundKit.bar(tk, Vector3.ZERO, Vector3(0, 0.42, sz * 0.22), 0.055, 0.055, 0.012, R)
		FoundKit.cbox(tk, Vector3(0, 0.42, sz * 0.22), Vector3(0.085, 0.085, 0.085), 0.022, R)
		body_mesh(tk, thigh)
		var shin := joint(StringName("shin_" + s), thigh, Vector3(0, 0.42, sz * 0.22))
		var sk := MeshKit.new()
		FoundKit.bar(sk, Vector3.ZERO, Vector3(0, -1.0, -sz * 0.03), 0.045, 0.045, 0.01, D)
		FoundKit.cbox(sk, Vector3(0.02, -1.005, -sz * 0.03), Vector3(0.14, 0.03, 0.08), 0.01, DD)
		body_mesh(sk, shin)

	# The case hangs stooped from the hips: front edge down.
	var lid := joint(&"lid", hips, Vector3(0.02, 0.02, 0), Vector3(0, 0, -0.32))
	var k := MeshKit.new()
	FoundKit.cbox(k, Vector3(0, 0.06, 0), Vector3(0.54, 0.26, 0.54), 0.05, R, 2)
	FoundKit.cbox(k, Vector3(0, -0.1, 0), Vector3(0.5, 0.05, 0.5), 0.02, D)
	FoundKit.mark(k, Vector3(0.291, 0.02, 0), Vector3.RIGHT, Vector3.UP, 0.4, 0.04, R[0], 0.003)
	FoundKit.mark(k, Vector3(0.291, 0.04, 0), Vector3.RIGHT, Vector3.UP, 0.32, 0.012, Palette.LINEN[4], 0.005)
	FoundKit.streaks(k, Vector3(0.291, 0.0, 0), Vector3.RIGHT, 0.36, 0.1, 6, 161, R[2])
	FoundKit.rivets(k, Vector3(0.291, 0.16, -0.22), Vector3(0.291, 0.16, 0.22), Vector3.RIGHT, 5, R[5])
	for sz: float in [-1.0, 1.0]:
		FoundKit.panel(k, Vector3(0, 0.06, sz * 0.281), Vector3.BACK * sz, Vector3.UP, 0.44, 0.18, R)
	FoundKit.seam(k, Vector3(-0.291, -0.04, 0.0), Vector3(-0.291, 0.16, 0.0), Vector3.LEFT, R, 2)
	body_mesh(k, lid)

	var neck := joint(&"neck", lid, Vector3(0, 0.2, 0))
	var nk := MeshKit.new()
	FoundKit.cbox(nk, Vector3(0, -0.14, 0), Vector3(0.1, 0.3, 0.1), 0.02, D)
	for y: float in [-0.08, -0.02]:
		FoundKit.mark(nk, Vector3(0.051, y, 0), Vector3.RIGHT, Vector3.UP, 0.06, 0.012, R[1])
	body_mesh(nk, neck)
	var head := joint(&"head", neck, Vector3.ZERO)
	var ek := MeshKit.new()
	FoundKit.cbox(ek, Vector3(0.02, 0.05, 0), Vector3(0.5, 0.1, 0.52), 0.03, R, 0)
	FoundKit.cbox(ek, Vector3(0.25, 0.04, 0), Vector3(0.04, 0.06, 0.44), 0.012, R)
	FoundKit.visor(ek, Vector3(0.271, 0.04, 0), Vector3.RIGHT, Vector3.UP, 0.38, 0.03)
	FoundKit.panel(ek, Vector3(0.0, 0.101, 0), Vector3.UP, Vector3.RIGHT, 0.36, 0.38, R)
	body_mesh(ek, head)
	add_scan(head, Vector3(0.271, 0.04, 0), Vector3.RIGHT, Vector3.BACK, 0.32, 0.028, 1.6)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"hips"] = pr(Vector3(0, 0.44, 0))
			d[&"thigh_l"] = r(Vector3(-1.2, 0, 0))
			d[&"thigh_r"] = r(Vector3(1.2, 0, 0))
			d[&"shin_l"] = r(Vector3(1.2, 0, 0))
			d[&"shin_r"] = r(Vector3(-1.2, 0, 0))
			d[&"lid"] = r(Vector3(0, 0, 0.32))
			d[&"neck"] = pr(Vector3(0, 0.4, 0))
			d[&"head"] = r(Vector3(0, 0, 0.12))
		&"windup":
			d[&"lid"] = r(Vector3(0, 0, 0.22))
			d[&"neck"] = pr(Vector3(0.04, 0.3, 0))
			d[&"head"] = r(Vector3(0, 0, -0.45))
		&"strike":
			d[&"lid"] = r(Vector3(0, 0, 0.1))
			d[&"neck"] = pr(Vector3(0.2, 0.26, 0))
			d[&"head"] = r(Vector3(0, 0, -0.6))
			d[&"hips"] = pr(Vector3(0.08, -0.04, 0))
		&"dead":
			d[&"hips"] = pr(Vector3(0, -0.44, 0))
			d[&"thigh_l"] = r(Vector3(-0.9, 0, 0))
			d[&"thigh_r"] = r(Vector3(0.9, 0, 0))
			d[&"shin_l"] = r(Vector3(-0.55, 0, 0))
			d[&"shin_r"] = r(Vector3(0.55, 0, 0))
			d[&"lid"] = pr(Vector3(0, 0.02, 0), Vector3(0.1, 0, 0.26))
			d[&"neck"] = pr(Vector3(0.1, 0.14, 0))
			d[&"head"] = pr(Vector3(0.12, -0.24, 0.05), Vector3(0.3, 0, -1.1))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	match p:
		&"dead":
			match j:
				&"neck": return Vector2(LIGHT_FIRST + 0.7, 0.3)
				&"head": return Vector2(LIGHT_FIRST + 1.2, 0.35)
		&"alert":
			# The neck comes up after the legs have straightened.
			if j == &"neck" or j == &"head":
				return Vector2(0.14, 0.2)
	return super(p, j)


## Short exact steps; the case bobs twice a stride and never sways.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for side in 2:
		var s := "l" if side == 0 else "r"
		var ph := phase * TAU + side * PI
		d[StringName("thigh_" + s)] = r(Vector3(0, 0, sin(ph) * 0.3))
		d[StringName("shin_" + s)] = r(Vector3(0, 0, -sin(ph) * 0.26 + maxf(0.0, cos(ph)) * 0.12))
	d[&"hips"] = pr(Vector3(0, absf(cos(phase * TAU)) * 0.025, 0))
	return d


## The slit reads in short exact passes while it stoops.
func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_read_t += delta
	if pose == &"stand" or pose == &"walk":
		(joints[&"head"] as Node3D).rotation.y += (0.12 if fposmod(_read_t, 2.0) < 1.0 else -0.12)
