extends MachineModel
## A dredger: a low hull with something moving underneath. The hull rides with
## its underside at the waterline; six legs splay out low from its flanks and
## work the bed half-drowned. The jaw is a notch cut into the middle of the prow,
## between two blunt mandibles, lined with amber: mouth and weak place at once.
##
## Origin is the bed it walks on; `waterline` is where the water should stand.
##
## alert  heaves up out of the water, prow lifted, jaw thrown wide
## dead   the fen closes over it: it settles down onto the bed, legs slack
##
## lights a hunter runs dark: a status lamp burning low and steady on the keel,
##        two eyes either side of the prow slit; at rest its jaws chew slowly
## wear   weed and silt trailing from its knees, a long bone caught across a
##        mandible, plates off other machines on the carapace, a cable spliced
##        down the stack

const WATERLINE := 0.22
const HULL_Y := 0.3
## Knee and foot relative to the hip, in the leg's own frame (+X outward).
const KNEE := Vector3(0.24, 0.02, 0.0)
const FOOT := Vector3(0.68, 0.03 - HULL_Y, 0.0)
const LEG_X := [0.3, -0.06, -0.42]

var waterline := WATERLINE


func build() -> void:
	part_side = &"front"
	height = 0.75
	stride = 1.3
	gallery_turn = 30.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hull := joint(&"hull", self, Vector3(0, HULL_Y, 0))
	# A low carapace with a flat-cut prow; the mandibles make the notch.
	var plan: Array[Vector2] = [Vector2(0.6, 0.22), Vector2(0.44, 0.46), Vector2(-0.42, 0.52), Vector2(-0.72, 0.3), Vector2(-0.72, -0.3), Vector2(-0.42, -0.52), Vector2(0.44, -0.46), Vector2(0.6, -0.22)]
	var k := FoundKit.kit()
	FoundKit.loft(k, [FoundKit.ring(plan, -0.06, 0.1), FoundKit.ring(plan, 0.02), FoundKit.ring(plan, 0.14), FoundKit.ring(plan, 0.22, 0.12), FoundKit.ring(plan, 0.25, 0.24)], R, true, true)
	# The skirt: a lip standing out round the hull just above the water.
	FoundKit.loft(k, [FoundKit.ring(plan, -0.04, -0.02), FoundKit.ring(plan, 0.0, -0.05)], D)
	# A dorsal keel down the middle and a stubby stack.
	var keel: Array[Vector2] = [Vector2(0.44, 0), Vector2(0.2, 0.11), Vector2(-0.46, 0.13), Vector2(-0.6, 0.0), Vector2(-0.46, -0.13), Vector2(0.2, -0.11)]
	FoundKit.loft(k, [FoundKit.ring(keel, 0.24), FoundKit.ring(keel, 0.31, 0.03), FoundKit.ring(keel, 0.33, 0.07)], R)
	FoundKit.tbar(k, Vector3(-0.44, 0.3, 0), Vector3(-0.44, 0.44, 0), 0.05, 0.045, 6, D, 0.012)
	FoundKit.spot(k, Vector3(-0.44, 0.441, 0), Vector3.UP, 0.032, 6, R[0], 0.002)
	for x: float in [-0.3, -0.1, 0.1]:
		FoundKit.mark(k, Vector3(x, 0.331, 0), Vector3.UP, Vector3.BACK, 0.2, 0.018, R[2], 0.002)
	# The prow face over the notch carries the slit: a face above a mouth.
	FoundKit.visor(k, Vector3(0.601, 0.1, 0), Vector3.RIGHT, Vector3.UP, 0.22, 0.03)
	FoundKit.streaks(k, Vector3(0.601, 0.07, 0), Vector3.RIGHT, 0.2, 0.06, 4, 120, R[1])
	for sz: float in [-1.0, 1.0]:
		# Along each flank: wet below, a pale tide mark, streaks from the shoulder.
		var a := Vector2(0.44, 0.46 * sz)
		var b := Vector2(-0.42, 0.52 * sz)
		var along := (b - a).normalized()
		var out2 := Vector2(-along.y, along.x)
		if out2.y * sz < 0.0:
			out2 = -out2
		var n := Vector3(out2.x, 0, out2.y)
		var along3 := Vector3(along.x, 0, along.y)
		var mid := (a + b) * 0.5
		var c := Vector3(mid.x, 0.0, mid.y)
		FoundKit.mark(k, c + Vector3(0, 0.05, 0), n, Vector3.UP, 0.82, 0.05, R[1], 0.003)
		FoundKit.mark(k, c + Vector3(0, 0.08, 0), n, Vector3.UP, 0.82, 0.014, Palette.BRINE[4], 0.004)
		FoundKit.streaks(k, c + Vector3(0, 0.13, 0), n, 0.66, 0.05, 6, 121 + int(sz), R[1])
		FoundKit.rivets(k, c + along3 * 0.34 + Vector3(0, 0.115, 0), c - along3 * 0.34 + Vector3(0, 0.115, 0), n, 5, R[5])
		FoundKit.seam(k, Vector3(-0.4, 0.26, sz * 0.22), Vector3(0.3, 0.26, sz * 0.2), Vector3(0, 0.9, sz * 0.4).normalized(), R, 4)
		# A mandible each side of the notch, blunt, pointing ahead.
		var mand: Array[Vector2] = [Vector2(0.56, sz * 0.1), Vector2(0.56, sz * 0.27), Vector2(0.84, sz * 0.23), Vector2(0.98, sz * 0.13)]
		FoundKit.slab(k, Vector3(0, 0.03, 0), Vector3.RIGHT, Vector3.BACK, mand, 0.17, R, 0.02)
		FoundKit.rivets(k, Vector3(0.64, 0.121, sz * 0.19), Vector3(0.86, 0.121, sz * 0.17), Vector3.UP, 3, R[5], 0.03)
	# The notch's dark throat.
	FoundKit.cbox(k, Vector3(0.6, -0.0, 0), Vector3(0.12, 0.14, 0.2), 0.0, FoundKit.flat(R[0]))
	body_mesh(k, hull)
	# The carapace it shows the sky all day: the plate the camera sees most of.
	day_wear(hull, Vector3(-0.08, 0.253, 0.3), Vector3.UP, Vector3.RIGHT, 0.34, 0.7, 128, 2)
	add_scan(hull, Vector3(0.601, 0.1, 0), Vector3.RIGHT, Vector3.BACK, 0.16, 0.025, 1.8)
	add_lamp(hull, Vector3(0.15, 0.332, 0), Vector3.UP, Vector3.RIGHT, 0.04, 0.04, &"status")
	for sz: float in [-1.0, 1.0]:
		add_lamp(hull, Vector3(0.602, 0.1, sz * 0.172), Vector3.RIGHT, Vector3.UP, 0.03, 0.03, &"optic")
	var hw := FoundKit.kit()
	FoundKit.patch(hw, Vector3(-0.1, 0.253, 0.3), Vector3(0, 0.95, 0.3).normalized(), Vector3.RIGHT, 0.24, 0.12, Palette.MACHINE["runner"], 81)
	FoundKit.patch(hw, Vector3(0.2, 0.253, -0.28), Vector3(0, 0.95, -0.3).normalized(), Vector3.RIGHT, 0.14, 0.1, Palette.MACHINE["hauler"], 82)
	FoundKit.cable(hw, Vector3(-0.47, 0.42, 0.03), Vector3(-0.3, 0.3, 0.16), 0.03, 0.012, Palette.INK[2], Palette.MACHINE["sweeper"], 4)
	FoundKit.scorch(hw, Vector3(-0.44, 0.335, -0.08), Vector3.UP, 0.05, 83)
	wear_mesh(hw, hull)
	# A long bone, caught across the left mandible and carried.
	var catch := FoundKit.matter_kit(Ink.HAND)
	FoundKit.bone(catch, Vector3(0.3, 0.2, -0.66), Vector3(1.0, 0.18, -0.14), 0.048, 84)
	wear_matter(catch, hull)

	# Amber lining the notch: its floor, seen from above, and both inner walls.
	var pk := FoundKit.kit()
	FoundKit.mark(pk, Vector3(0.76, -0.04, 0), Vector3.UP, Vector3.RIGHT, 0.22, 0.4, Palette.LENS[0], 0.002)
	FoundKit.mark(pk, Vector3(0.74, -0.04, 0), Vector3.UP, Vector3.RIGHT, 0.16, 0.34, Palette.LENS[2], 0.006)
	FoundKit.mark(pk, Vector3(0.7, -0.04, 0), Vector3.UP, Vector3.RIGHT, 0.07, 0.18, Palette.LENS[3], 0.01)
	for sz: float in [-1.0, 1.0]:
		var wall := Vector3(0.77, 0.03, sz * 0.1)
		FoundKit.mark(pk, wall, Vector3.BACK * -sz, Vector3.UP, 0.38, 0.13, Palette.LENS[2], 0.004)
	part_mesh(pk, hull)
	set_part_anchor(hull, Vector3(0.82, 0.0, 0), 0.75)

	for sz: float in [-1.0, 1.0]:
		var jaw := joint(&"jaw_r" if sz > 0 else &"jaw_l", hull, Vector3(0.6, -0.02, sz * 0.05))
		var jk := FoundKit.kit()
		var blade: Array[Vector2] = [Vector2(0.0, -0.04), Vector2(0.3, -0.02), Vector2(0.32, 0.03), Vector2(0.0, 0.04)]
		FoundKit.slab(jk, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, blade, 0.035, D, 0.008)
		body_mesh(jk, jaw)
		var tk := FoundKit.kit()
		for t in 3:
			FoundKit.mark(tk, Vector3(0.08 + t * 0.08, 0.0, -sz * 0.0185), Vector3.BACK * -sz, Vector3.UP, 0.04, 0.06, Palette.LENS[3], 0.004)
		part_mesh(tk, jaw)

	# Legs: out from under the lip, knee low, foot out on the bed.
	for i in 6:
		var sz := -1.0 if i < 3 else 1.0
		var x: float = LEG_X[i % 3]
		var fan: float = [0.5, 0.0, -0.48][i % 3]
		var leg := joint(StringName("leg%d" % i), hull, Vector3(x, -0.03, sz * 0.36), Vector3(0, -sz * (PI * 0.5 - fan), 0))
		var lk := FoundKit.kit()
		FoundKit.disc(lk, Vector3.ZERO, Vector3.UP, 0.05, 0.06, 6, 0.012, D)
		FoundKit.tbar(lk, Vector3.ZERO, KNEE, 0.034, 0.028, 6, R)
		FoundKit.disc(lk, KNEE, Vector3.BACK, 0.038, 0.05, 6, 0.01, R)
		FoundKit.tbar(lk, KNEE, FOOT, 0.028, 0.016, 6, DD)
		FoundKit.tbar(lk, FOOT, FOOT + Vector3(0.03, 0.0, 0), 0.014, 0.0, 4, DD)
		body_mesh(lk, leg)
		if i % 2 == 0:
			# Weed and silt off the bed, hanging from the knee.
			# Draped along the shin, so it lies on the bed with the leg, never under it.
			var weed := FoundKit.matter_kit(Ink.STIPPLE)
			var shin := (FOOT - KNEE).normalized()
			weed.push(Transform3D(Basis(shin.cross(Vector3.BACK), -shin, Vector3.BACK), KNEE + Vector3(0.0, 0.03, 0.0)))
			FoundKit.rag(weed, Vector3(0.0, 0.0, 0.0), 0.3, 0.06, Palette.MOSS[3], 85 + i, Vector3(0, 0, 1))
			FoundKit.rag(weed, Vector3(0.025, -0.12, 0.02), 0.2, 0.045, Palette.SPRUCE[3], 91 + i, Vector3(0, 0, 1))
			weed.pop()
			wear_matter(weed, leg)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			# Heaves up out of the water on straightened legs, prow raised so the
			# notch shows, jaw thrown wide.
			d[&"hull"] = pr(Vector3(-0.04, 0.3, 0), Vector3(0, 0, 0.16))
			d[&"jaw_l"] = r(Vector3(0, 0.95, 0))
			d[&"jaw_r"] = r(Vector3(0, -0.95, 0))
			_plant(d, -0.46, 0.16)
		&"windup":
			d[&"hull"] = pr(Vector3(-0.12, 0.16, 0), Vector3(0, 0, 0.24))
			d[&"jaw_l"] = r(Vector3(0, 0.8, 0))
			d[&"jaw_r"] = r(Vector3(0, -0.8, 0))
			_plant(d, -0.23, 0.24)
		&"strike":
			d[&"hull"] = pr(Vector3(0.3, 0.02, 0), Vector3(0, 0, -0.08))
			_plant(d, 0.0, -0.08)
			d[&"jaw_l"] = r(Vector3(0, -0.1, 0))
			d[&"jaw_r"] = r(Vector3(0, 0.1, 0))
		&"dead":
			# Settles down through the water onto the bed, legs gone slack.
			d[&"hull"] = pr(Vector3(0, -0.22, 0), Vector3(0.03, 0.06, -0.03))
			for i in 6:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.42))
			d[&"jaw_l"] = r(Vector3(0, 0.35, 0))
			d[&"jaw_r"] = r(Vector3(0, -0.12, 0))
	return d


## Legs pushed down by `base`, each corrected for where it sits along a hull
## pitched by `pitch`, so all six feet stay on the bed.
func _plant(d: Dictionary, base: float, pitch: float) -> void:
	for i in 6:
		var x: float = LEG_X[i % 3]
		d[StringName("leg%d" % i)] = r(Vector3(0, 0, base - (x + 0.06) * 2.4 * pitch))


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead" and j == &"hull":
		return Vector2(LIGHT_FIRST + 0.3, 1.6)
	return super(p, j)


## At rest the jaws chew: open slowly, snap shut, the same every time.
func _routine(_delta: float, on: bool) -> void:
	if not on or pose != &"stand":
		return
	var t := fposmod(clock, 2.8)
	var open := smoothstep(0.0, 1.6, t) * (1.0 - smoothstep(2.3, 2.4, t)) * 0.3
	(joints[&"jaw_l"] as Node3D).rotation.y += open
	(joints[&"jaw_r"] as Node3D).rotation.y -= open


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
