extends MachineModel
## A harvester: a slab. Wide, low and square on two tracks, working a field row
## by row to the headland and back. The intake across its front is both the
## dangerous end and the working part: an amber comb that never stops combing.
##
## walk   the hull pitches and yaws over the ground on an exact cycle
## alert  the intake drops and two lamp masts rise out of the hull
## hurt   lamps out, comb stops
## dead   settles on its tracks, intake down, and the row spills out in front

const WHEEL_R := 0.14

var _travel := 0.0
var _comb_t := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"front"
	height = 1.25
	stride = 1.6
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	# Tracks and road wheels ride on the root: they never pitch with the hull.
	for sz: float in [-1.0, 1.0]:
		var tk := MeshKit.new()
		FoundKit.cbox(tk, Vector3(-0.05, 0.24, sz * 0.95), Vector3(1.94, 0.46, 0.36), 0.17, DD)
		FoundKit.mark(tk, Vector3(-0.05, 0.22, sz * 1.131), Vector3.BACK * sz, Vector3.UP, 1.5, 0.2, R[0], 0.002)
		body_mesh(tk, self)
		for x: float in [-0.62, -0.05, 0.52]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.22, sz * 1.14)
			add_child(w)
			var wk := MeshKit.new()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.05, 8, 0.0, D, D[2])
			FoundKit.mark(wk, Vector3(0, 0, sz * 0.026), Vector3.BACK * sz, Vector3.UP, 0.05, 0.05, R[4], 0.002)
			FoundKit.mark(wk, Vector3(0, 0.09, sz * 0.026), Vector3.BACK * sz, Vector3.UP, 0.03, 0.05, R[1], 0.002)
			body_mesh(wk, w)
			_wheels.append(w)

	var hull := joint(&"hull", self, Vector3(0, 0.44, 0))
	var k := MeshKit.new()
	FoundKit.cbox(k, Vector3(-0.05, 0.27, 0), Vector3(1.8, 0.54, 1.56), 0.08, R, 2)
	for sz: float in [-1.0, 1.0]:
		FoundKit.cbox(k, Vector3(-0.05, 0.08, sz * 0.95), Vector3(2.0, 0.06, 0.44), 0.02, D)
		FoundKit.cbox(k, Vector3(-0.86, 0.66, sz * 0.58), Vector3(0.1, 0.26, 0.1), 0.025, R)
		FoundKit.streaks(k, Vector3(0.3, 0.05, sz * 1.171), Vector3.BACK * sz, 1.4, 0.0, 1, 1, R[2])
	# The rear hopper, its lid and seams.
	FoundKit.cbox(k, Vector3(-0.48, 0.67, 0), Vector3(0.74, 0.26, 1.1), 0.05, R, 0)
	FoundKit.seam(k, Vector3(-0.83, 0.801, -0.3), Vector3(-0.13, 0.801, -0.3), Vector3.UP, R, 4)
	FoundKit.seam(k, Vector3(-0.83, 0.801, 0.3), Vector3(-0.13, 0.801, 0.3), Vector3.UP, R, 4)
	FoundKit.panel(k, Vector3(0.42, 0.541, 0), Vector3.UP, Vector3.RIGHT, 0.62, 1.1, R)
	FoundKit.seam(k, Vector3(0.851, 0.06, -0.7), Vector3(0.851, 0.06, 0.7), Vector3.RIGHT, R, 7)
	# Front: visor band, lamps, streaks down from the band.
	FoundKit.visor(k, Vector3(0.851, 0.34, 0), Vector3.RIGHT, Vector3.UP, 1.1, 0.07)
	FoundKit.streaks(k, Vector3(0.851, 0.28, 0), Vector3.RIGHT, 1.0, 0.18, 9, 31, R[2])
	FoundKit.streaks(k, Vector3(-0.2, 0.2, 0.781), Vector3.BACK, 1.2, 0.16, 7, 32, R[2])
	FoundKit.rivets(k, Vector3(-0.2, 0.46, 0.781), Vector3(0.7, 0.46, 0.781), Vector3.BACK, 6, R[5])
	body_mesh(k, hull)
	add_scan(hull, Vector3(0.851, 0.34, 0), Vector3.RIGHT, Vector3.BACK, 0.9, 0.06, 3.0)

	for sz: float in [-1.0, 1.0]:
		var lamp := joint(&"lamp_r" if sz > 0 else &"lamp_l", hull, Vector3(0.7, 0.5, sz * 0.6))
		var mk := MeshKit.new()
		FoundKit.cbox(mk, Vector3(0, -0.1, 0), Vector3(0.06, 0.3, 0.06), 0.012, D)
		FoundKit.cbox(mk, Vector3(0, 0.1, 0), Vector3(0.14, 0.11, 0.18), 0.03, R)
		body_mesh(mk, lamp)
		var ck := MeshKit.new()
		FoundKit.mark(ck, Vector3(0.071, 0.1, 0), Vector3.RIGHT, Vector3.UP, 0.12, 0.06, Palette.COLD[3], 0.004)
		cold_mesh(ck, lamp)

	var intake := joint(&"intake", hull, Vector3(0.82, 0.12, 0))
	var ik := MeshKit.new()
	FoundKit.cbox(ik, Vector3(0.4, -0.16, 0), Vector3(0.32, 0.3, 2.34), 0.05, R, 0)
	for sz: float in [-1.0, 1.0]:
		FoundKit.cbox(ik, Vector3(0.2, -0.05, sz * 1.12), Vector3(0.5, 0.26, 0.07), 0.02, D)
	FoundKit.mark(ik, Vector3(0.561, -0.2, 0), Vector3.RIGHT, Vector3.UP, 2.1, 0.12, R[0], 0.003)
	FoundKit.rivets(ik, Vector3(0.561, -0.05, -1.0), Vector3(0.561, -0.05, 1.0), Vector3.RIGHT, 9, R[5])
	body_mesh(ik, intake)

	var comb := joint(&"comb", intake, Vector3(0.58, -0.2, 0))
	var ck2 := MeshKit.new()
	var amber: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3]]
	for j in 13:
		var z := -1.02 + j * 0.17
		FoundKit.cbox(ck2, Vector3(0.02, 0, z), Vector3(0.13, 0.05, 0.05), 0.0, amber)
		FoundKit.mark(ck2, Vector3(0.085, 0, z), Vector3.RIGHT, Vector3.UP, 0.04, 0.04, Palette.LENS[3], 0.002)
	part_mesh(ck2, comb)
	set_part_anchor(intake, Vector3(0.62, -0.18, 0), 0.9)

	# The row it was cutting, only once it is dead.
	var spill := Node3D.new()
	add_child(spill)
	var sk := MeshKit.new()
	var stalk: Array[Color] = [Palette.SAND[3], Palette.SAND[4], Palette.MOSS[3], Palette.LINEN[3]]
	for j in 18:
		var a := Rng.hash01(71, j) * TAU
		var dist := 0.2 + Rng.hash01(72, j) * 0.7
		var base := Vector3(1.45 + cos(a) * dist * 0.7, 0.03, sin(a) * dist * 1.6)
		var tip := base + Vector3(cos(a + 1.3), 0, sin(a + 1.3)) * (0.22 + Rng.hash01(73, j) * 0.14)
		FoundKit.bar(sk, base, tip, 0.035, 0.03, 0.0, [stalk[j % 4], stalk[j % 4], stalk[j % 4], stalk[j % 4], stalk[j % 4], stalk[j % 4]])
	body_mesh(sk, spill)
	dead_only(spill, LIGHT_FIRST + 0.5)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"intake"] = pr(Vector3(0, -0.07, 0), Vector3(0, 0, -0.26))
			d[&"lamp_l"] = pr(Vector3(0, 0.36, 0))
			d[&"lamp_r"] = pr(Vector3(0, 0.36, 0))
		&"windup":
			d[&"intake"] = r(Vector3(0, 0, 0.42))
			d[&"hull"] = pr(Vector3(-0.06, 0.02, 0), Vector3(0, 0, 0.05))
			d[&"lamp_l"] = pr(Vector3(0, 0.3, 0))
			d[&"lamp_r"] = pr(Vector3(0, 0.3, 0))
		&"strike":
			d[&"intake"] = pr(Vector3(0, -0.04, 0), Vector3(0, 0, -0.34))
			d[&"hull"] = pr(Vector3(0.2, -0.02, 0), Vector3(0, 0, -0.05))
			d[&"lamp_l"] = pr(Vector3(0, 0.3, 0))
			d[&"lamp_r"] = pr(Vector3(0, 0.3, 0))
		&"dead":
			d[&"hull"] = pr(Vector3(0, -0.035, 0), Vector3(0.03, 0.0, -0.04))
			d[&"intake"] = pr(Vector3(0, -0.04, 0), Vector3(0, 0, -0.3))
	return d


func _gait_deltas(phase: float) -> Dictionary:
	return {&"hull": pr(Vector3(0, absf(sin(phase * TAU)) * 0.015, 0), Vector3(0, cos(phase * TAU) * 0.02, sin(phase * TAU) * 0.025))}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	var v := maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	_travel += delta * v
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
	_comb_t += delta
	(joints[&"comb"] as Node3D).position.z = (0.04 if fposmod(_comb_t, 0.34) < 0.17 else -0.04)
