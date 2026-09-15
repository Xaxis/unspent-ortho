extends MachineModel
## A sweeper: a T. A low wide deck with a tall hopper over the middle, the only
## silhouette with a corner. It goes along the tracks in the early morning behind
## the wardens, brushes turning, and comes over you, not after you. The hopper
## vent on its back glows: the working part.
##
## alert  the hopper lifts on its ram and leans out over the front
## dead   the hopper tips off backwards and what it swept spills out

const WHEEL_R := 0.14

var _travel := 0.0
var _brush_t := 0.0
var _wheels: Array[Node3D] = []
var _roller: Node3D
var _side: Array[Node3D] = []


func build() -> void:
	part_side = &"back"
	height = 1.2
	stride = 1.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var deck := joint(&"deck", self, Vector3(0, 0.24, 0))
	var k := MeshKit.new()
	FoundKit.cbox(k, Vector3(0, 0, 0), Vector3(0.66, 0.1, 1.2), 0.03, R, 2)
	FoundKit.cbox(k, Vector3(0.31, -0.07, 0), Vector3(0.08, 0.14, 1.14), 0.02, D)
	FoundKit.cbox(k, Vector3(-0.31, -0.05, 0), Vector3(0.06, 0.1, 1.0), 0.02, D)
	for sz: float in [-1.0, 1.0]:
		FoundKit.bar(k, Vector3(0, 0.05, sz * 0.1), Vector3(0, 0.7, sz * 0.1), 0.05, 0.05, 0.01, D)
		FoundKit.seam(k, Vector3(-0.28, 0.051, sz * 0.42), Vector3(0.28, 0.051, sz * 0.42), Vector3.UP, R, 3)
		FoundKit.streaks(k, Vector3(0.0, 0.03, sz * 0.601), Vector3.BACK * sz, 0.5, 0.06, 4, 101, R[2])
		FoundKit.cbox(k, Vector3(0.3, -0.1, sz * 0.56), Vector3(0.14, 0.04, 0.14), 0.02, D)
	body_mesh(k, deck)
	for sz: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(-0.12, WHEEL_R - 0.24, sz * 0.52)
		deck.add_child(w)
		var wk := MeshKit.new()
		FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.08, 8, 0.015, DD, D[2])
		FoundKit.mark(wk, Vector3(0, 0.08, sz * 0.041), Vector3.BACK * sz, Vector3.UP, 0.03, 0.06, R[1], 0.002)
		FoundKit.mark(wk, Vector3(0, 0, sz * 0.041), Vector3.BACK * sz, Vector3.UP, 0.05, 0.05, R[4], 0.003)
		body_mesh(wk, w)
		_wheels.append(w)
		# Side brushes turn in mirror at the front corners.
		var sb := Node3D.new()
		sb.position = Vector3(0.36, -0.2, sz * 0.58)
		deck.add_child(sb)
		var bk := MeshKit.new()
		FoundKit.disc(bk, Vector3.ZERO, Vector3.UP, 0.08, 0.04, 6, 0.01, D, D[3])
		for j in 8:
			var a := float(j) / 8.0 * TAU
			FoundKit.bar(bk, Vector3(cos(a), 0, sin(a)) * 0.05, Vector3(cos(a), -0.02, sin(a)) * 0.2, 0.02, 0.012, 0.0, [R[3], R[3], R[4], R[4], R[5], R[5]])
		body_mesh(bk, sb)
		_side.append(sb)
	_roller = Node3D.new()
	_roller.position = Vector3(0.24, -0.14, 0)
	deck.add_child(_roller)
	var rk := MeshKit.new()
	FoundKit.disc(rk, Vector3.ZERO, Vector3.BACK, 0.1, 0.96, 8, 0.02, DD, D[1])
	for j in 8:
		var a := float(j) / 8.0 * TAU
		FoundKit.bar(rk, Vector3(cos(a) * 0.09, sin(a) * 0.09, -0.42), Vector3(cos(a) * 0.09, sin(a) * 0.09, 0.42), 0.02, 0.02, 0.0, [R[2], R[2], R[3], R[3], R[4], R[4]])
	body_mesh(rk, _roller)

	var hopper := joint(&"hopper", deck, Vector3(-0.04, 0.06, 0))
	var hk := MeshKit.new()
	FoundKit.cbox(hk, Vector3(0, 0.43, 0), Vector3(0.4, 0.84, 0.4), 0.05, R, 0)
	FoundKit.cbox(hk, Vector3(0, 0.88, 0), Vector3(0.48, 0.06, 0.48), 0.02, R)
	FoundKit.cbox(hk, Vector3(0.02, 0.925, 0), Vector3(0.28, 0.04, 0.28), 0.012, D)
	FoundKit.cbox(hk, Vector3(0.24, 0.12, 0), Vector3(0.08, 0.2, 0.24), 0.02, D)
	FoundKit.visor(hk, Vector3(0.201, 0.68, 0), Vector3.RIGHT, Vector3.UP, 0.26, 0.04)
	FoundKit.streaks(hk, Vector3(0.201, 0.64, 0), Vector3.RIGHT, 0.24, 0.3, 4, 102, R[2])
	for sz: float in [-1.0, 1.0]:
		FoundKit.seam(hk, Vector3(-0.1, 0.06, sz * 0.201), Vector3(-0.1, 0.8, sz * 0.201), Vector3.BACK * sz, R, 5)
		FoundKit.mark(hk, Vector3(0.08, 0.06, sz * 0.201), Vector3.BACK * sz, Vector3.UP, 0.2, 0.08, R[2])
	# The vent: louvres over the glow.
	for j in 4:
		FoundKit.mark(hk, Vector3(-0.201, 0.3 + j * 0.06, 0), Vector3.LEFT, Vector3.UP, 0.26, 0.022, R[1], 0.014)
	FoundKit.rivets(hk, Vector3(-0.201, 0.2, -0.15), Vector3(-0.201, 0.2, 0.15), Vector3.LEFT, 3, R[5])
	FoundKit.streaks(hk, Vector3(-0.201, 0.24, 0), Vector3.LEFT, 0.2, 0.16, 3, 103, R[2])
	body_mesh(hk, hopper)
	add_scan(hopper, Vector3(0.201, 0.68, 0), Vector3.RIGHT, Vector3.BACK, 0.2, 0.035, 2.2)
	var pk := MeshKit.new()
	FoundKit.mark(pk, Vector3(-0.201, 0.39, 0), Vector3.LEFT, Vector3.UP, 0.3, 0.26, Palette.LENS[0], 0.003)
	FoundKit.mark(pk, Vector3(-0.201, 0.39, 0), Vector3.LEFT, Vector3.UP, 0.24, 0.2, Palette.LENS[2], 0.007)
	FoundKit.mark(pk, Vector3(-0.201, 0.39, 0), Vector3.LEFT, Vector3.UP, 0.12, 0.08, Palette.LENS[3], 0.01)
	part_mesh(pk, hopper)
	set_part_anchor(hopper, Vector3(-0.21, 0.39, 0), 0.65)

	# What it swept, only when the hopper has tipped.
	var spill := Node3D.new()
	add_child(spill)
	var sk := MeshKit.new()
	var grit: Array[Color] = [Palette.EARTH[2], Palette.EARTH[3], Palette.SPRUCE[2], Palette.EARTH[4]]
	for j in 22:
		var a := PI * (0.55 + Rng.hash01(111, j) * 0.9)
		var dist := 0.3 + Rng.hash01(112, j) * 0.6
		var base := Vector3(-0.35 + cos(a) * dist, 0.02, sin(a) * dist * 0.8)
		var tip := base + Vector3(cos(a * 3.0), 0, sin(a * 3.0)) * 0.12
		var c := grit[j % 4]
		FoundKit.bar(sk, base, tip, 0.03, 0.025, 0.0, [c, c, c, c, c, c])
	sk.rock(-0.62, 0.0, 0.05, 0.16, 0.1, 113, Palette.EARTH[2], 5)
	body_mesh(sk, spill)
	dead_only(spill, LIGHT_FIRST + 0.6)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"hopper"] = pr(Vector3(0.08, 0.3, 0), Vector3(0, 0, -0.34))
		&"windup":
			d[&"hopper"] = pr(Vector3(-0.04, 0.16, 0), Vector3(0, 0, 0.2))
		&"strike":
			d[&"hopper"] = pr(Vector3(0.16, 0.12, 0), Vector3(0, 0, -0.6))
			d[&"deck"] = pr(Vector3(0.1, 0, 0))
		&"dead":
			d[&"hopper"] = pr(Vector3(-0.3, -0.12, 0.06), Vector3(0.25, 0, 1.25))
			d[&"deck"] = pr(Vector3(0, -0.03, 0), Vector3(0.04, 0, 0))
	return d


func _gait_deltas(phase: float) -> Dictionary:
	return {&"deck": pr(Vector3(0, absf(sin(phase * TAU)) * 0.01, 0)), &"hopper": r(Vector3(sin(phase * TAU) * 0.02, 0, 0))}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_travel += delta * maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	_brush_t += delta
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
	_roller.rotation.z = -_brush_t * 9.0
	_side[0].rotation.y = _brush_t * 6.0
	_side[1].rotation.y = -_brush_t * 6.0
