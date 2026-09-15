extends MachineModel
## A cutter: the only circle in the world. A toothed disc on edge, carried out in
## front of a compact upright body on a boom, over six fanned legs. It cuts
## stone and cannot hear you while it does. The drive on its back is the working
## part.
##
## alert  the blade lifts on its boom
## dead   the disc stops, the legs give, and the body sinks onto its own spoil

const DISC_R := 0.5
const SIDES := [-1.0, 1.0]
const LEG_X := [0.2, -0.05, -0.3]

var _spin := 0.0


func build() -> void:
	part_side = &"back"
	height = 1.4
	gallery_turn = 70.0
	stride = 0.9
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var body := joint(&"body", self, Vector3(0, 0.42, 0))
	var k := MeshKit.new()
	FoundKit.cbox(k, Vector3(-0.1, 0, 0), Vector3(0.66, 0.07, 0.5), 0.025, D)
	FoundKit.cbox(k, Vector3(-0.34, 0.2, 0), Vector3(0.36, 0.4, 0.34), 0.05, R, 2)
	FoundKit.cbox(k, Vector3(-0.34, 0.42, 0), Vector3(0.26, 0.05, 0.24), 0.02, R)
	FoundKit.visor(k, Vector3(-0.159, 0.28, 0), Vector3.RIGHT, Vector3.UP, 0.22, 0.04)
	FoundKit.streaks(k, Vector3(-0.159, 0.24, 0), Vector3.RIGHT, 0.2, 0.16, 4, 41, R[2])
	FoundKit.seam(k, Vector3(-0.5, 0.2, 0.171), Vector3(-0.18, 0.2, 0.171), Vector3.BACK, R, 3)
	FoundKit.seam(k, Vector3(-0.5, 0.2, -0.171), Vector3(-0.18, 0.2, -0.171), Vector3.FORWARD, R, 3)
	# The drive housing on the back, and the shaft cover over the top to the boom.
	FoundKit.cbox(k, Vector3(-0.58, 0.18, 0), Vector3(0.14, 0.26, 0.26), 0.03, R)
	FoundKit.cbox(k, Vector3(-0.36, 0.47, 0), Vector3(0.34, 0.05, 0.09), 0.015, D)
	FoundKit.rivets(k, Vector3(-0.651, 0.29, -0.09), Vector3(-0.651, 0.29, 0.09), Vector3.LEFT, 3, R[5])
	body_mesh(k, body)
	add_scan(body, Vector3(-0.159, 0.28, 0), Vector3.RIGHT, Vector3.BACK, 0.16, 0.035, 1.6)

	var pk := MeshKit.new()
	FoundKit.lens(pk, Vector3(-0.651, 0.16, 0), Vector3.LEFT, Vector3.UP, 0.13, 0.13)
	for y: float in [0.1, 0.16, 0.22]:
		FoundKit.mark(pk, Vector3(-0.651, y, 0), Vector3.LEFT, Vector3.UP, 0.19, 0.012, Palette.LENS[0], 0.016)
	part_mesh(pk, body)
	set_part_anchor(body, Vector3(-0.66, 0.16, 0), 0.6)

	for si in 2:
		var s: float = SIDES[si]
		for xi in 3:
			var fan := (xi - 1) * 0.55
			var leg := joint(StringName("leg%d" % (si * 3 + xi)), body, Vector3(LEG_X[xi], -0.01, s * 0.22), Vector3(0, -s * PI * 0.5 - s * fan, 0))
			var lk := MeshKit.new()
			FoundKit.bar(lk, Vector3.ZERO, Vector3(0.2, 0.16, 0), 0.045, 0.045, 0.01, R)
			FoundKit.cbox(lk, Vector3(0.2, 0.16, 0), Vector3(0.07, 0.07, 0.07), 0.018, R)
			FoundKit.bar(lk, Vector3(0.2, 0.16, 0), Vector3(0.44, -0.41, 0), 0.035, 0.035, 0.008, D)
			body_mesh(lk, leg)

	var arm := joint(&"arm", body, Vector3(-0.2, 0.42, 0))
	var ak := MeshKit.new()
	for sz: float in [-1.0, 1.0]:
		FoundKit.bar(ak, Vector3(0, 0, sz * 0.07), Vector3(0.56, 0.04, sz * 0.07), 0.06, 0.03, 0.01, R)
	FoundKit.cbox(ak, Vector3(0, 0, 0), Vector3(0.12, 0.12, 0.2), 0.03, R)
	FoundKit.disc(ak, Vector3(0.56, 0.04, 0), Vector3.BACK, 0.07, 0.2, 8, 0.015, R, R[4])
	body_mesh(ak, arm)

	var disc := joint(&"disc", arm, Vector3(0.56, 0.04, 0))
	var dk := MeshKit.new()
	# A dark face and a bright ground rim: the circle has to read at any distance.
	FoundKit.disc(dk, Vector3.ZERO, Vector3.BACK, DISC_R, 0.05, 16, 0.012, [R[1], R[1], R[2], R[4], R[5], R[5]], R[4], PI / 16.0)
	FoundKit.disc(dk, Vector3.ZERO, Vector3.BACK, DISC_R - 0.09, 0.056, 16, 0.0, R, R[1], PI / 16.0)
	FoundKit.disc(dk, Vector3.ZERO, Vector3.BACK, 0.12, 0.08, 8, 0.02, R, R[3])
	var pale: Array = [R[2], R[3], R[4], R[4], R[5], R[5]]
	for j in 8:
		var a := float(j) / 8.0 * TAU
		dk.push(Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * (DISC_R + 0.02)))
		FoundKit.cbox(dk, Vector3(0.0, 0.0, 0), Vector3(0.08, 0.07, 0.04), 0.0, pale)
		dk.pop()
		for sz: float in [-1.0, 1.0]:
			var mid := Vector3(cos(a + PI / 8.0), sin(a + PI / 8.0), 0) * 0.3
			FoundKit.mark(dk, mid + Vector3(0, 0, sz * 0.029), Vector3.BACK * sz, Vector3(cos(a + PI / 8.0), sin(a + PI / 8.0), 0), 0.035, 0.16, R[3], 0.002)
			FoundKit.mark(dk, Vector3(cos(a), sin(a), 0) * (DISC_R - 0.045) + Vector3(0, 0, sz * 0.026), Vector3.BACK * sz, Vector3(cos(a), sin(a), 0), 0.03, 0.03, R[1], 0.003)
	body_mesh(dk, disc)

	# Spoil under it, only once it has sunk onto it.
	var spoil := Node3D.new()
	add_child(spoil)
	var sk := MeshKit.new()
	for j in 6:
		var a := float(j) / 6.0 * TAU + 0.3
		sk.rock(-0.2 + cos(a) * 0.3, 0.0, sin(a) * 0.3, 0.13 + Rng.hash01(81, j) * 0.06, 0.12, 810 + j, Palette.LINEN[3] if j % 2 == 0 else Palette.STONE[3], 5)
	body_mesh(sk, spoil)
	dead_only(spoil, LIGHT_FIRST)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"arm"] = pr(Vector3(0, 0.1, 0), Vector3(0, 0, 0.55))
			d[&"body"] = pr(Vector3(0, 0.2, 0), Vector3(0, 0, 0.08))
			# Up on the tips of its legs.
			for i in 6:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.42))
		&"windup":
			d[&"arm"] = pr(Vector3(0, 0.08, 0), Vector3(0, 0, 0.95))
			d[&"body"] = pr(Vector3(-0.06, 0.02, 0), Vector3(0, 0, 0.12))
		&"strike":
			d[&"arm"] = r(Vector3(0, 0, -0.5))
			d[&"body"] = pr(Vector3(0.14, -0.04, 0), Vector3(0, 0, -0.1))
		&"dead":
			d[&"body"] = pr(Vector3(0, -0.26, 0), Vector3(0.06, 0, -0.04))
			d[&"arm"] = r(Vector3(0, 0, -0.34))
			for i in 6:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.75))
	return d


## Alternating tripods; each swinging leg lifts at the knee.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for i in 6:
		var tripod := 1.0 if (i % 2 == 0) == (i < 3) else -1.0
		var sw := sin(phase * TAU) * tripod
		var lift := maxf(0.0, cos(phase * TAU) * tripod)
		var s := -1.0 if i < 3 else 1.0
		d[StringName("leg%d" % i)] = r(Vector3(0, sw * 0.22 * s, lift * 0.22))
	d[&"body"] = pr(Vector3(0, absf(sin(phase * TAU)) * 0.02, 0))
	return d


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	var rate := 2.5
	match pose:
		&"walk": rate = 6.0
		&"alert": rate = 4.0
		&"windup", &"strike": rate = 16.0
	_spin += delta * rate
	(joints[&"disc"] as Node3D).rotation.z = -_spin
