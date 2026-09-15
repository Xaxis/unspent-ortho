extends MachineModel
## A harvester: a slab. Wide, low and square on two tracks, working a field row
## by row to the headland and back. Across its front a hood runs down to a row of
## pointed dividers with an amber comb between them: the dangerous end and the
## working part at once. It never stops combing.
##
## walk   the hull pitches and yaws over the ground on an exact cycle
## alert  the intake drops and two lamp masts rise out of the hull
## hurt   lamps out, comb stops
## dead   lists onto one track, intake on the ground, the comb dropped askew in
##        front of it, lamps and stacks folded; the row spills out

const WHEEL_R := 0.13
const HULL_Y := 0.5
const TRACK_Z := 1.06

var _travel := 0.0
var _comb_t := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"front"
	height = 1.25
	stride = 1.6
	gallery_turn = 35.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	# Tracks and road wheels ride on the root: they never pitch with the hull.
	var track: Array[Vector2] = [Vector2(0.98, 0.3), Vector2(0.82, 0.46), Vector2(-0.86, 0.46), Vector2(-1.02, 0.3), Vector2(-1.02, 0.16), Vector2(-0.86, 0.0), Vector2(0.82, 0.0), Vector2(0.98, 0.16)]
	for sz: float in [-1.0, 1.0]:
		var tk := FoundKit.kit()
		FoundKit.slab(tk, Vector3(0, 0, sz * TRACK_Z), Vector3.RIGHT, Vector3.UP, track, 0.42, DD, 0.02)
		for j in 12:
			FoundKit.mark(tk, Vector3(-0.8 + j * 0.145, 0.462, sz * TRACK_Z), Vector3.UP, Vector3.BACK, 0.4, 0.035, R[0], 0.002)
		FoundKit.mark(tk, Vector3(-0.02, 0.23, sz * (TRACK_Z + 0.211)), Vector3.BACK * sz, Vector3.UP, 1.64, 0.26, R[0], 0.002)
		body_mesh(tk, self)
		for x: float in [-0.66, -0.02, 0.62]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.23, sz * (TRACK_Z + 0.23))
			add_child(w)
			var wk := FoundKit.kit()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.05, 8, 0.012, D, D[2], PI / 8.0)
			FoundKit.spot(wk, Vector3(0, 0, sz * 0.026), Vector3.BACK * sz, 0.045, 6, R[4], 0.002)
			FoundKit.mark(wk, Vector3(0, 0.08, sz * 0.026), Vector3.BACK * sz, Vector3.UP, 0.025, 0.06, R[1], 0.003)
			body_mesh(wk, w)
			_wheels.append(w)

	var hull := joint(&"hull", self, Vector3(0, HULL_Y, 0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(1.86, 1.72, 0.34)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.22, 0.05), FoundKit.ring(plan, -0.14), FoundKit.ring(plan, 0.22, 0.01), FoundKit.ring(plan, 0.3, 0.09)], R, true)
	# Skirts over the tracks.
	for sz: float in [-1.0, 1.0]:
		var skirt: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.9, 0.06), Vector2(-0.9, 0.06), Vector2(-1.04, 0.0), Vector2(-0.98, -0.04), Vector2(0.94, -0.04)]
		FoundKit.slab(k, Vector3(0, 0.0, sz * TRACK_Z), Vector3.RIGHT, Vector3.BACK * sz, skirt, 0.05, R)
		FoundKit.rivets(k, Vector3(-0.8, 0.04, sz * (TRACK_Z + 0.03)), Vector3(0.8, 0.04, sz * (TRACK_Z + 0.03)), Vector3.UP, 9, R[5])
		FoundKit.streaks(k, Vector3(0.1, 0.12, sz * 0.861), Vector3.BACK * sz, 1.3, 0.2, 8, 31 + int(sz), R[1])
	# The rear housing: low, so the whole stays a slab; a cold slit across its
	# face like a cab window with nobody behind it, louvres on top.
	var cab := FoundKit.plan_oct(0.66, 1.26, 0.2)
	FoundKit.loft(k, [FoundKit.ring(cab, 0.28, 0.0, Vector2.ONE, Vector2(-0.5, 0)), FoundKit.ring(cab, 0.42, 0.02, Vector2.ONE, Vector2(-0.5, 0)), FoundKit.ring(cab, 0.47, 0.07, Vector2.ONE, Vector2(-0.5, 0))], R)
	FoundKit.visor(k, Vector3(-0.169, 0.36, 0), Vector3.RIGHT, Vector3.UP, 0.7, 0.04)
	FoundKit.streaks(k, Vector3(-0.169, 0.33, 0), Vector3.RIGHT, 0.64, 0.05, 7, 33, R[1])
	for j in 9:
		FoundKit.mark(k, Vector3(-0.5, 0.472, -0.4 + j * 0.1), Vector3.UP, Vector3.RIGHT, 0.36, 0.024, R[1], 0.002)
	FoundKit.seam(k, Vector3(-0.12, 0.301, 0), Vector3(0.66, 0.301, 0), Vector3.UP, R, 4)
	FoundKit.panel(k, Vector3(0.3, 0.301, -0.46), Vector3.UP, Vector3.RIGHT, 0.5, 0.36, R)
	FoundKit.panel(k, Vector3(0.3, 0.301, 0.46), Vector3.UP, Vector3.RIGHT, 0.5, 0.36, R)
	body_mesh(k, hull)
	add_scan(hull, Vector3(-0.169, 0.36, 0), Vector3.RIGHT, Vector3.BACK, 0.6, 0.035, 3.0)
	# Two short stacks behind the housing on a hinged foot, the way a stack is
	# made to fold for a low bridge; dead, they fold.
	var stacks := joint(&"stacks", hull, Vector3(-0.8, 0.3, 0))
	var sk2 := FoundKit.kit()
	FoundKit.tbar(sk2, Vector3(0, 0.0, -0.56), Vector3(0, 0.0, 0.56), 0.03, 0.03, 6, D)
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(sk2, Vector3(0, 0.0, sz * 0.5), Vector3(0, 0.32, sz * 0.5), 0.045, 0.04, 6, R, 0.015)
		FoundKit.spot(sk2, Vector3(0, 0.321, sz * 0.5), Vector3.UP, 0.028, 6, R[0], 0.002)
	body_mesh(sk2, stacks)

	for sz: float in [-1.0, 1.0]:
		var lamp := joint(&"lamp_r" if sz > 0 else &"lamp_l", hull, Vector3(0.62, 0.1, sz * 0.66))
		var mk := FoundKit.kit()
		FoundKit.tbar(mk, Vector3(0, -0.1, 0), Vector3(0, 0.3, 0), 0.026, 0.022, 6, D)
		FoundKit.lathe(mk, Vector3(0, 0.34, 0), Vector3.RIGHT, [Vector2(0.04, -0.07), Vector2(0.07, -0.02), Vector2(0.07, 0.05)], 6, R)
		body_mesh(mk, lamp)
		var ck := FoundKit.kit()
		FoundKit.spot(ck, Vector3(0.05, 0.34, 0), Vector3.RIGHT, 0.05, 6, Palette.COLD[3], 0.004)
		cold_mesh(ck, lamp)

	var intake := joint(&"intake", hull, Vector3(0.86, 0.22, 0))
	var ik := FoundKit.kit()
	var hood: Array[Vector2] = [Vector2(0.0, 0.08), Vector2(0.5, -0.36), Vector2(0.5, -0.52), Vector2(0.08, -0.5)]
	# The hood is the biggest plate on it: body fill, so the lit rim stays on bevels.
	var hood_r: Array = [R[0], R[1], R[2], R[3], R[3], R[5]]
	FoundKit.slab(ik, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, hood, 2.46, hood_r, 0.03)
	FoundKit.rivets(ik, Vector3(0.1, 0.01, -1.1), Vector3(0.1, 0.01, 1.1), Vector3(0.66, 0.75, 0), 12, R[5])
	for sz: float in [-1.0, 1.0]:
		FoundKit.seam(ik, Vector3(0.1, 0.0, sz * 0.4), Vector3(0.46, -0.32, sz * 0.4), Vector3(0.66, 0.75, 0), R, 3)
	# Pointed dividers along the lip: the saw-edge you see coming.
	for j in 7:
		var z := -1.08 + j * 0.36
		FoundKit.lathe(ik, Vector3(0.44, -0.46, z), Vector3(1, -0.22, 0), [Vector2(0.075, 0.0), Vector2(0.06, 0.06), Vector2(0.0, 0.22)], 4, R, PI * 0.25)
	body_mesh(ik, intake)

	# The comb: long amber teeth running out past the dividers, lit on top, so the
	# dangerous end reads as the soft one from wherever you stand.
	var comb := joint(&"comb", intake, Vector3(0.5, -0.5, 0))
	var ck2 := FoundKit.kit()
	var amber: Array = [Palette.LENS[0], Palette.LENS[1], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	for j in 13:
		var z := -1.08 + j * 0.18
		var tooth: Array[Vector2] = [Vector2(-0.04, 0.05), Vector2(0.3, 0.012), Vector2(0.3, -0.012), Vector2(-0.04, -0.05)]
		FoundKit.slab(ck2, Vector3(0, 0, z), Vector3.RIGHT, Vector3.BACK, tooth, 0.045, amber)
	FoundKit.tbar(ck2, Vector3(-0.03, 0, -1.12), Vector3(-0.03, 0, 1.12), 0.035, 0.035, 4, [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[2]])
	part_mesh(ck2, comb)
	set_part_anchor(intake, Vector3(0.7, -0.48, 0), 1.0)

	# The row it was cutting, only once it is dead: made of the field, drawn by the hand.
	var spill := Node3D.new()
	add_child(spill)
	var sk := FoundKit.matter_kit(Ink.HAND)
	var stalk: Array[Color] = [Palette.SAND[3], Palette.SAND[4], Palette.MOSS[3], Palette.LINEN[3]]
	for j in 22:
		var a := Rng.hash01(71, j) * TAU
		var dist := 0.2 + Rng.hash01(72, j) * 0.7
		var base := Vector3(1.75 + cos(a) * dist * 0.6, 0.03, sin(a) * dist * 1.5)
		var tip := base + Vector3(cos(a + 1.3), 0.02, sin(a + 1.3)) * (0.22 + Rng.hash01(73, j) * 0.16)
		sk.push(Transform3D(Basis.IDENTITY, Vector3.ZERO))
		FoundKit.bar(sk, base, tip, 0.035, 0.03, 0.0, FoundKit.flat(stalk[j % 4]))
		sk.pop()
	matter_mesh(sk, spill)
	dead_only(spill, LIGHT_FIRST + 0.5)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"intake"] = pr(Vector3(0, -0.08, 0), Vector3(0, 0, -0.2))
			d[&"lamp_l"] = pr(Vector3(0, 0.42, 0))
			d[&"lamp_r"] = pr(Vector3(0, 0.42, 0))
		&"windup":
			d[&"intake"] = r(Vector3(0, 0, 0.36))
			d[&"hull"] = pr(Vector3(-0.06, 0.02, 0), Vector3(0, 0, 0.05))
			d[&"lamp_l"] = pr(Vector3(0, 0.36, 0))
			d[&"lamp_r"] = pr(Vector3(0, 0.36, 0))
		&"strike":
			d[&"intake"] = pr(Vector3(0, 0.05, 0), Vector3(0, 0, -0.26))
			d[&"hull"] = pr(Vector3(0.22, -0.02, 0), Vector3(0, 0, -0.05))
			d[&"lamp_l"] = pr(Vector3(0, 0.36, 0))
			d[&"lamp_r"] = pr(Vector3(0, 0.36, 0))
		&"dead":
			# Settles listing onto one track; the intake comes down on the ground,
			# the comb drops off it askew, lamps and stacks fold over.
			d[&"hull"] = pr(Vector3(0, -0.05, 0), Vector3(0.13, 0.04, 0.05))
			d[&"intake"] = pr(Vector3(0.02, -0.08, 0), Vector3(-0.1, 0, -0.26))
			d[&"comb"] = pr(Vector3(0.22, 0.1, 0.1), Vector3(-0.03, 0.28, 0.21))
			d[&"lamp_l"] = r(Vector3(-0.7, 0, 0.25))
			d[&"lamp_r"] = r(Vector3(0.45, 0, -0.35))
			d[&"stacks"] = r(Vector3(0, 0, 1.2))
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
	(joints[&"comb"] as Node3D).position.z = (0.05 if fposmod(_comb_t, 0.34) < 0.17 else -0.05)
