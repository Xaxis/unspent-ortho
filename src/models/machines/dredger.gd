extends MachineModel
## A dredger: a low hull with something moving underneath, six legs working the
## bed below the waterline. The jaw is a notch in the middle of the underside at
## the prow, lined with amber: mouth and weak place at once.
##
## Origin is the bed it walks on; `waterline` is where the water should stand.
##
## alert  heaves up out of the water and opens the jaw wider
## dead   the fen closes over it: it settles down through the surface

const WATERLINE := 0.36
const KNEE := Vector3(0.3, 0.3, 0.0)

var waterline := WATERLINE


func build() -> void:
	part_side = &"front"
	height = 0.95
	stride = 1.3
	gallery_turn = 30.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hull := joint(&"hull", self, Vector3(0, 0.4, 0))
	# A low carapace with a prow, not a box: waterline full, shoulders sloped in.
	var plan: Array[Vector2] = [Vector2(0.92, 0), Vector2(0.55, 0.5), Vector2(-0.5, 0.58), Vector2(-0.84, 0.34), Vector2(-0.84, -0.34), Vector2(-0.5, -0.58), Vector2(0.55, -0.5)]
	var k := FoundKit.kit()
	FoundKit.loft(k, [FoundKit.ring(plan, -0.06, 0.12), FoundKit.ring(plan, 0.04), FoundKit.ring(plan, 0.18), FoundKit.ring(plan, 0.27, 0.12), FoundKit.ring(plan, 0.31, 0.26)], R)
	# A dorsal keel down the middle and a stubby stack.
	var keel: Array[Vector2] = [Vector2(0.5, 0), Vector2(0.2, 0.12), Vector2(-0.46, 0.14), Vector2(-0.6, 0.0), Vector2(-0.46, -0.14), Vector2(0.2, -0.12)]
	FoundKit.loft(k, [FoundKit.ring(keel, 0.3), FoundKit.ring(keel, 0.38, 0.03), FoundKit.ring(keel, 0.41, 0.07)], R)
	FoundKit.tbar(k, Vector3(-0.44, 0.38, 0), Vector3(-0.44, 0.56, 0), 0.05, 0.045, 6, D, 0.012)
	FoundKit.spot(k, Vector3(-0.44, 0.561, 0), Vector3.UP, 0.032, 6, R[0], 0.002)
	FoundKit.visor(k, Vector3(0.27, 0.36, 0), Vector3(0.6, 0.8, 0), Vector3(-0.8, 0.6, 0), 0.16, 0.03)
	for x: float in [-0.3, -0.1, 0.1]:
		FoundKit.mark(k, Vector3(x, 0.411, 0), Vector3.UP, Vector3.BACK, 0.2, 0.018, R[2], 0.002)
	for sz: float in [-1.0, 1.0]:
		# Along each flank: wet below the waterline, a pale tide mark, streaks from the shoulder.
		var a := Vector2(0.55, 0.5 * sz)
		var b := Vector2(-0.5, 0.58 * sz)
		var along := (b - a).normalized()
		var out2 := Vector2(-along.y, along.x)
		if out2.y * sz < 0.0:
			out2 = -out2
		var n := Vector3(out2.x, 0, out2.y)
		var along3 := Vector3(along.x, 0, along.y)
		var mid := (a + b) * 0.5
		var c := Vector3(mid.x, 0.0, mid.y)
		FoundKit.mark(k, c + Vector3(0, 0.08, 0), n, Vector3.UP, 0.98, 0.08, R[1], 0.003)
		FoundKit.mark(k, c + Vector3(0, 0.125, 0), n, Vector3.UP, 0.98, 0.014, Palette.BRINE[4], 0.004)
		FoundKit.streaks(k, c + Vector3(0, 0.18, 0), n, 0.8, 0.06, 6, 121 + int(sz), R[1])
		FoundKit.rivets(k, c + along3 * 0.4 + Vector3(0, 0.165, 0), c - along3 * 0.4 + Vector3(0, 0.165, 0), n, 6, R[5])
		FoundKit.seam(k, Vector3(-0.4, 0.32, sz * 0.24), Vector3(0.36, 0.32, sz * 0.2), Vector3(0, 0.9, sz * 0.4).normalized(), R, 4)
	# The jaw cavity under the prow.
	FoundKit.cbox(k, Vector3(0.7, -0.03, 0), Vector3(0.3, 0.1, 0.3), 0.0, FoundKit.flat(R[0]))
	body_mesh(k, hull)
	add_scan(hull, Vector3(0.27, 0.36, 0), Vector3(0.6, 0.8, 0), Vector3.BACK, 0.1, 0.025, 1.8)

	var pk := FoundKit.kit()
	FoundKit.mark(pk, Vector3(0.851, -0.03, 0), Vector3.RIGHT, Vector3.UP, 0.28, 0.08, Palette.LENS[2], 0.004)
	FoundKit.mark(pk, Vector3(0.851, -0.03, 0), Vector3.RIGHT, Vector3.UP, 0.16, 0.025, Palette.LENS[3], 0.008)
	FoundKit.mark(pk, Vector3(0.72, 0.021, 0), Vector3.UP, Vector3.RIGHT, 0.22, 0.2, Palette.LENS[1], 0.004)
	part_mesh(pk, hull)
	set_part_anchor(hull, Vector3(0.9, -0.02, 0), 0.7)

	for sz: float in [-1.0, 1.0]:
		var jaw := joint(&"jaw_r" if sz > 0 else &"jaw_l", hull, Vector3(0.78, -0.03, sz * 0.13))
		var jk := FoundKit.kit()
		var blade: Array[Vector2] = [Vector2(0.0, -0.05), Vector2(0.28, -0.03), Vector2(0.3, 0.03), Vector2(0.0, 0.05)]
		FoundKit.slab(jk, Vector3(0, 0, sz * 0.02), Vector3.RIGHT, Vector3.UP, blade, 0.04, D, 0.01)
		body_mesh(jk, jaw)
		var tk := FoundKit.kit()
		for t in 3:
			FoundKit.mark(tk, Vector3(0.06 + t * 0.08, -0.01, -sz * 0.001), Vector3.BACK * -sz, Vector3.UP, 0.035, 0.06, Palette.LENS[2], 0.004)
		part_mesh(tk, jaw)

	# Legs like a strider's: knee above the deck, foot far out on the bed.
	for i in 6:
		var sz := -1.0 if i < 3 else 1.0
		var x: float = [0.36, -0.06, -0.46][i % 3]
		var fan: float = [0.55, 0.0, -0.5][i % 3]
		var leg := joint(StringName("leg%d" % i), hull, Vector3(x, 0.12, sz * 0.52), Vector3(0, -sz * (PI * 0.5 - fan), 0))
		var lk := FoundKit.kit()
		FoundKit.disc(lk, Vector3.ZERO, Vector3.UP, 0.05, 0.06, 6, 0.012, D)
		FoundKit.tbar(lk, Vector3.ZERO, KNEE, 0.03, 0.024, 6, R)
		FoundKit.disc(lk, KNEE, Vector3.BACK, 0.035, 0.05, 6, 0.01, R)
		var foot := Vector3(0.7, -0.52, 0)
		FoundKit.tbar(lk, KNEE, foot, 0.022, 0.014, 6, DD)
		FoundKit.tbar(lk, foot, foot + Vector3(0.02, -0.04, 0), 0.016, 0.0, 4, DD)
		body_mesh(lk, leg)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"hull"] = pr(Vector3(0, 0.24, 0), Vector3(0, 0, 0.1))
			d[&"jaw_l"] = r(Vector3(0, 0.6, 0))
			d[&"jaw_r"] = r(Vector3(0, -0.6, 0))
			for i in 6:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.32))
		&"windup":
			d[&"hull"] = pr(Vector3(-0.1, 0.16, 0), Vector3(0, 0, 0.22))
			d[&"jaw_l"] = r(Vector3(0, 0.8, 0))
			d[&"jaw_r"] = r(Vector3(0, -0.8, 0))
			for i in 6:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.2))
		&"strike":
			d[&"hull"] = pr(Vector3(0.3, -0.04, 0), Vector3(0, 0, -0.14))
		&"dead":
			d[&"hull"] = pr(Vector3(0, -0.5, 0), Vector3(0.1, 0.05, -0.06))
			for i in 6:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.55))
			d[&"jaw_l"] = r(Vector3(0, 0.3, 0))
			d[&"jaw_r"] = r(Vector3(0, -0.12, 0))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead" and j == &"hull":
		return Vector2(LIGHT_FIRST + 0.3, 1.6)
	return super(p, j)


## Rowing tripods: each leg sweeps back along the bed, then lifts and reaches.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for i in 6:
		var tripod := 1.0 if (i % 2 == 0) == (i < 3) else -1.0
		var s := -1.0 if i < 3 else 1.0
		var sw := sin(phase * TAU) * tripod
		var lift := maxf(0.0, cos(phase * TAU) * tripod)
		d[StringName("leg%d" % i)] = r(Vector3(0, sw * 0.28 * s, lift * 0.22))
	d[&"hull"] = pr(Vector3(0, absf(sin(phase * TAU)) * 0.02, 0), Vector3(sin(phase * TAU) * 0.025, 0, 0))
	return d
