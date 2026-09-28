extends MachineModel
## THE DRIP-WARDEN: the Limestone Caves' keeper. The plan cut in from above for
## the stone, and water is what stops a face being worked: this keeps the
## cuttings dry. It stands on three short raked legs splayed from a hip at a
## person's knee, and from the hip one riser mast goes up to the DRIP CROWN, the
## flared metering head that lays the lime it seals the galleries with. A pump
## pack squats on the mast's back at the hip; a spray lance rides the mast on a
## swivel and hoses the side a body keeps to.
##
## Why a MAST ON A LOW TRIPOD. The crags' plumb is a tall tripod whose legs meet
## overhead, a triangle over a pendulum. This one's legs meet LOW and a single
## vertical rises out of them: a standpipe, a riser, the one plumbing shape in a
## cave full of stone that grew. Its top is the widest thing on it, a bell, and
## from the bell's rim the lime it drips has begun to grow stalactites on the
## keeper itself.
##
## LIMED TO THE KNEES. It stands in what it sprays: from the feet up to the knee
## collars every leg is sleeved in pale calcite, lumped and uneven, on the
## world's lit material, so it reads pale in the lamp where the body's keeper
## ramp goes dark. Streaks of lime run down the mast from the crown.
##
## Poses.
## walk   the three legs step a third of a stride apart; the mast sways
## stand  the lance lowered, the crown turning slowly on its bearing
## alert  the legs plant wider and the crown cants toward the player
## windup the lance swings up and back on its swivel, the mast leaning away
## strike the lance comes round: the hose
## hurt   the crown judders
## dead   the back leg folds and the mast goes over forwards, the crown down on
##        the floor it kept dry

const HIP_Y := 1.05
const HIP_R := 0.22
const FOOT_R := 1.5
## Low under a cave's roof: the crown's top stands 4.5 tall at SIZE, under
## the headroom most of its halls give (tests/sentinel/test_keeper_headroom.gd).
const MAST_TOP := 2.85
const CROWN_R := 1.0
## The lance's swivel up the mast, and how far out and down its nozzle reaches.
const SWIVEL_Y := 2.35
const LANCE := Vector3(1.55, -0.95, 0.0)
## The whole body, grown to a keeper's scale: at 1.0 it read at eye level as a
## lamp on stilts, a thing far off and slight, not the cave's keeper.
const SIZE := 1.3

var _t := 0.0


func build() -> void:
	part_side = &"back"
	height = 4.5
	stride = 1.6
	gallery_turn = 30.0
	emission = 0.28
	begin_rig()
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)
	var hip := joint(&"hip", self, Vector3(0, HIP_Y, 0))
	_legs(hip, R, D, DD)
	var mast := joint(&"mast", hip, Vector3.ZERO)
	_mast(mast, R, D, DD)
	_pack(mast, R, D, DD)
	_lance(mast, R, D, DD)
	var crown := joint(&"crown", mast, Vector3(0, MAST_TOP - HIP_Y, 0))
	_crown(crown, R, D)
	finish_rig()
	scale = Vector3.ONE * SIZE


## Calcite, lit as the world is: pale, warm off white, never snow.
static func _lime() -> Array:
	return [Palette.LINEN[3], Palette.LINEN[4], Palette.LINEN[5], Palette.SAND[5], Palette.LINEN[5], Palette.LINEN[5]]


## Three short legs raked out from the hip, each a tube to a knee collar and a
## lower member to a broad foot; sleeved in lime from the foot to the collar.
func _legs(hip: Node3D, R: Array, D: Array, DD: Array) -> void:
	var specs := [[PI, &"leg_b"], [PI / 3.0, &"leg_r"], [-PI / 3.0, &"leg_l"]]
	var lime := _lime()
	for spec: Array in specs:
		var a: float = spec[0]
		var dir := Vector3(cos(a), 0.0, sin(a))
		var leg := joint(spec[1], hip, dir * HIP_R)
		var foot := dir * (FOOT_R - HIP_R) + Vector3(0, -HIP_Y, 0)
		var knee := foot * 0.48 + Vector3(0, 0.12, 0) + dir * 0.08
		var k := FoundKit.kit()
		var s0 := k.vertex_count()
		FoundKit.tbar(k, Vector3.ZERO, knee, 0.17, 0.14, 8, R)
		FoundKit.tbar(k, knee, foot, 0.14, 0.12, 8, D)
		k.smooth_range(s0, k.vertex_count(), 70.0)
		FoundKit.lathe(k, knee, foot - knee, [Vector2(0.17, -0.1), Vector2(0.2, 0.0), Vector2(0.2, 0.18), Vector2(0.16, 0.26)], 8, DD, PI / 8.0)
		# A broad foot, a pad a machine this heavy stands on in wet.
		FoundKit.disc(k, foot + Vector3(0, 0.04, 0), Vector3.UP, 0.32, 0.09, 10, 0.02, DD, Color(0, 0, 0, 0), PI / 10.0)
		body_mesh(k, leg)
		# Lime from the foot to the collar: a sleeve grown up the lower member,
		# thick and lumped at the foot where it has stood in its own spray
		# longest, thinning to a ragged lip under the collar, with drips run
		# back down it.
		var m := FoundKit.matter_kit(Ink.NONE)
		var up := knee - foot
		var run := up.length()
		var seed_a := int(a * 10.0)
		var prof: Array[Vector2] = []
		for j in 8:
			var t := float(j) / 7.0
			var lump := Rng.hash01(311, j, seed_a) * 0.05
			prof.append(Vector2(lerpf(0.27, 0.16, t) + lump, t * run * 1.02))
		prof.append(Vector2(0.0, run * 1.03))
		FoundKit.lathe(m, foot, up, prof, 8, lime, Rng.hash01(313, seed_a) * TAU)
		# And on up past the collar, thinning, in a ragged tide line: it has
		# stood to the knee in its own spray and been splashed above it.
		var thigh := -knee
		var tprof: Array[Vector2] = []
		for j in 5:
			var t := float(j) / 4.0
			tprof.append(Vector2(lerpf(0.19, 0.155, t) + Rng.hash01(315, j, seed_a) * 0.03, t * thigh.length() * 0.4))
		tprof.append(Vector2(0.0, thigh.length() * 0.41))
		FoundKit.lathe(m, knee, thigh, tprof, 8, lime, Rng.hash01(316, seed_a) * TAU)
		for j in 4:
			var at := foot + up * (0.2 + 0.22 * j)
			m.rock(at.x, at.y, at.z, 0.15, 0.1, 600 + j + seed_a, lime[3 + j % 2], 6)
		# Drips of lime hanging off the knee collar's lip, set as they fell.
		for j in 3:
			var a2 := a + (float(j) - 1.0) * 0.9
			var lip := knee + Vector3(cos(a2), 0, sin(a2)) * 0.2 + Vector3(0, -0.06, 0)
			var len := 0.12 + Rng.hash01(317, j, seed_a) * 0.16
			FoundKit.lathe(m, lip, Vector3.DOWN, [Vector2(0.035, 0.0), Vector2(0.018, len * 0.6), Vector2(0.0, len)], 5, lime)
		# The skirt it stands in: the floor round the foot limed pale.
		m.rock(foot.x, 0.01 - HIP_Y, foot.z, 0.42, 0.06, 620 + seed_a, lime[3], 8)
		wear_matter(m, leg)


## The riser: one thick mast from the hip to the crown, banded where its sections
## bolt together, with lime run down it from the crown and a slit optic under the
## bell. It works by ear; the slit is a meter, not an eye.
func _mast(mast: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var top := MAST_TOP - HIP_Y
	# The hip housing the legs and the mast meet in: a turned drum.
	FoundKit.lathe(k, Vector3(0, -0.28, 0), Vector3.UP, [Vector2(0.32, 0.0), Vector2(0.44, 0.08), Vector2(0.44, 0.42), Vector2(0.3, 0.52)], 12, D, PI / 12.0)
	var s0 := k.vertex_count()
	FoundKit.tbar(k, Vector3(0, 0.1, 0), Vector3(0, top, 0), 0.23, 0.18, 10, R)
	k.smooth_range(s0, k.vertex_count(), 70.0)
	for b: float in [0.7, 1.45, 2.1]:
		FoundKit.lathe(k, Vector3(0, b, 0), Vector3.UP, [Vector2(0.25, 0.0), Vector2(0.28, 0.03), Vector2(0.28, 0.12), Vector2(0.25, 0.15)], 10, DD, PI / 10.0)
	FoundKit.rivets(k, Vector3(0.23, 0.4, 0), Vector3(0.19, 2.2, 0), Vector3.RIGHT, 6, R[5])
	body_mesh(k, mast)
	var head := joint(&"head", mast, Vector3(0, top - 0.42, 0))
	var hk := FoundKit.kit()
	FoundKit.lathe(hk, Vector3(0, -0.14, 0), Vector3.UP, [Vector2(0.26, 0.0), Vector2(0.29, 0.05), Vector2(0.29, 0.24), Vector2(0.26, 0.28)], 10, R, PI / 10.0)
	FoundKit.visor(hk, Vector3(0.291, 0.0, 0.0), Vector3.RIGHT, Vector3.UP, 0.3, 0.05)
	body_mesh(hk, head)
	add_scan(head, Vector3(0.293, 0.0, 0.0), Vector3.RIGHT, Vector3.BACK, 0.26, 0.04, 2.5)
	# Lime run down the mast from under the bell: long pale streaks on the lit
	# material, thickest on the side the drip falls.
	var m := FoundKit.matter_kit(Ink.NONE)
	var lime := _lime()
	for j in 5:
		var a := j * TAU / 5.0 + 0.3
		var n := Vector3(cos(a), 0, sin(a))
		var len := 0.5 + Rng.hash01(317, j) * 0.9
		FoundKit.tbar(m, n * 0.2 + Vector3(0, top - 0.05, 0), n * 0.21 + Vector3(0, top - 0.05 - len, 0), 0.05, 0.02, 4, lime)
	wear_matter(m, mast)


## The pump pack: a squat barrel on the mast's back at the hip, ribbed, its hose
## looping up to the lance's swivel. What a blow reaches while it is open.
func _pack(mast: Node3D, R: Array, D: Array, DD: Array) -> void:
	var pack := joint(&"pack", mast, Vector3(-0.62, 0.36, 0))
	var k := FoundKit.kit()
	FoundKit.lathe(k, Vector3(0, -0.46, 0), Vector3.UP, [Vector2(0.36, 0.0), Vector2(0.46, 0.08), Vector2(0.46, 0.86), Vector2(0.34, 0.98)], 12, R, PI / 12.0)
	for y: float in [-0.26, -0.02, 0.22]:
		FoundKit.lathe(k, Vector3(0, y, 0), Vector3.UP, [Vector2(0.47, 0.0), Vector2(0.49, 0.04)], 12, D, PI / 12.0)
	# The slurry tank on its back, turned across it: what the lance lays.
	FoundKit.lathe(k, Vector3(-0.2, 0.72, -0.44), Vector3.BACK, [Vector2(0.18, 0.0), Vector2(0.28, 0.1), Vector2(0.28, 0.78), Vector2(0.18, 0.88)], 10, D, PI / 10.0)
	FoundKit.tbar(k, Vector3(-0.2, 0.52, -0.3), Vector3(-0.2, 0.46, 0.3), 0.05, 0.05, 6, DD)
	# The hose, in three runs from the pack's crown up to the swivel.
	var hose := FoundKit.flat(Palette.INK[2])
	var pts := [Vector3(0.0, 0.52, 0.0), Vector3(0.18, 1.0, 0.28), Vector3(0.42, 1.5, 0.24), Vector3(0.62, SWIVEL_Y - HIP_Y - 0.36, 0.14)]
	for i in pts.size() - 1:
		FoundKit.tbar(k, pts[i], pts[i + 1], 0.07, 0.07, 6, hose)
	body_mesh(k, pack)
	add_lamp(pack, Vector3(-0.463, 0.1, 0.0), Vector3.LEFT, Vector3.UP, 0.08, 0.08, &"status")
	# Lime slopped down the pack from the tank's filler.
	var m := FoundKit.matter_kit(Ink.NONE)
	var lime := _lime()
	for j in 3:
		var at := Vector3(-0.47, 0.3 - j * 0.28, -0.2 + j * 0.2)
		FoundKit.tbar(m, at, at + Vector3(0, -0.35, 0.02), 0.045, 0.02, 4, lime)
	wear_matter(m, pack)


## The spray lance on its swivel: a long barrel out and down to a nozzle, the
## nozzle's lip crusted with lime.
func _lance(mast: Node3D, R: Array, D: Array, DD: Array) -> void:
	var arm := joint(&"lance", mast, Vector3(0, SWIVEL_Y - HIP_Y, 0))
	var k := FoundKit.kit()
	FoundKit.lathe(k, Vector3(0, -0.14, 0), Vector3.UP, [Vector2(0.27, 0.0), Vector2(0.31, 0.05), Vector2(0.31, 0.24), Vector2(0.27, 0.28)], 10, DD, PI / 10.0)
	FoundKit.tbar(k, Vector3(0.2, 0.0, 0.0), LANCE, 0.1, 0.075, 8, D)
	FoundKit.tbar(k, Vector3(0.12, -0.08, 0.0), LANCE * 0.55 + Vector3(0, -0.02, 0), 0.03, 0.03, 4, DD)
	FoundKit.lathe(k, LANCE, LANCE - Vector3(0.12, 0.0, 0.0), [Vector2(0.05, 0.0), Vector2(0.09, -0.14), Vector2(0.1, -0.2)], 8, DD, PI / 8.0)
	body_mesh(k, arm)
	var m := FoundKit.matter_kit(Ink.NONE)
	var lime := _lime()
	m.rock(LANCE.x + 0.12, LANCE.y - 0.04, 0.0, 0.14, 0.08, 640, lime[4], 6)
	m.rock(LANCE.x + 0.06, LANCE.y - 0.1, 0.05, 0.1, 0.06, 641, lime[3], 5)
	wear_matter(m, arm)


## The drip crown: a flared bell on a bearing, a ring of meters under its rim
## that glow as it lays lime (the working part), and the keeper's own stalactites
## grown from the rim where the lime it drips has set.
func _crown(crown: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	FoundKit.lathe(k, Vector3(0, -0.12, 0), Vector3.UP, [Vector2(0.22, 0.0), Vector2(0.32, 0.16), Vector2(CROWN_R, 0.38), Vector2(CROWN_R + 0.06, 0.48), Vector2(0.72, 0.6), Vector2(0.3, 0.72)], 14, R, PI / 14.0)
	FoundKit.seam(k, Vector3(-0.6, 0.55, 0.0), Vector3(0.6, 0.55, 0.0), Vector3.UP, R, 4)
	body_mesh(k, crown)
	day_wear(crown, Vector3(0.0, 0.45, 0.0), Vector3.UP, Vector3.RIGHT, 0.5, 0.3, 211, 1)
	var pk := FoundKit.kit()
	var glow: Array = [Palette.LENS[0], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3]]
	for j in 10:
		var a := j * TAU / 10.0
		var at := Vector3(cos(a) * (CROWN_R - 0.2), 0.22, sin(a) * (CROWN_R - 0.2))
		FoundKit.lathe(pk, at, Vector3.DOWN, [Vector2(0.07, 0.0), Vector2(0.055, 0.1)], 6, glow)
	part_mesh(pk, crown)
	set_part_anchor(crown, Vector3(0, 0.2, 0), 1.0)
	# The keeper's own dripstone: stalactites from the rim, long and uneven.
	var m := FoundKit.matter_kit(Ink.NONE)
	var lime := _lime()
	for j in 16:
		var a := j * TAU / 16.0 + 0.2
		var rim := Vector3(cos(a) * CROWN_R, 0.36, sin(a) * CROWN_R)
		var len := 0.25 + Rng.hash01(331, j) * 0.5
		FoundKit.lathe(m, rim, Vector3.DOWN, [Vector2(0.085, 0.0), Vector2(0.05, len * 0.5), Vector2(0.018, len * 0.85), Vector2(0.0, len)], 6, lime)
		# Every other one still dripping: a thread of wet lime off its point and
		# the bead gathering at its end.
		if j % 2 == 0:
			var tip := rim + Vector3(0, -len, 0)
			var fall := 0.18 + Rng.hash01(333, j) * 0.3
			FoundKit.tbar(m, tip, tip + Vector3(0, -fall, 0), 0.01, 0.008, 4, lime)
			FoundKit.lathe(m, tip + Vector3(0, -fall, 0), Vector3.DOWN, [Vector2(0.0, -0.03), Vector2(0.03, 0.0), Vector2(0.0, 0.05)], 6, lime)
	# Lime crusted over the bell's shoulder where the drip wells up.
	for j in 5:
		var a := j * TAU / 5.0 + 0.6
		m.rock(cos(a) * (CROWN_R - 0.08), 0.44, sin(a) * (CROWN_R - 0.08), 0.2, 0.06, 660 + j, lime[3 + j % 2], 6)
	wear_matter(m, crown)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			d[&"lance"] = r(Vector3(0, 0, -0.1))
		&"alert":
			d[&"leg_b"] = r(Vector3(0, 0, -0.08))
			d[&"leg_r"] = r(Vector3(-0.08, 0, 0))
			d[&"leg_l"] = r(Vector3(0.08, 0, 0))
			d[&"crown"] = r(Vector3(0, 0, -0.14))
		&"windup":
			d[&"lance"] = r(Vector3(0, 0.9, 0.35))
			d[&"mast"] = r(Vector3(0, 0, 0.08))
			d[&"crown"] = r(Vector3(0, 0, -0.1))
		&"strike":
			d[&"lance"] = r(Vector3(0, -0.8, -0.1))
			d[&"mast"] = r(Vector3(0, 0, -0.06))
		&"hurt":
			d[&"crown"] = r(Vector3(0.12, 0, 0.08))
		&"dead":
			d[&"hip"] = pr(Vector3(0.3, -0.62, 0), Vector3(0, 0, -0.4))
			d[&"mast"] = r(Vector3(0.1, 0, -1.05))
			d[&"leg_b"] = r(Vector3(0, 0, 0.8))
			d[&"lance"] = r(Vector3(0, 0.6, 0.3))
	return d


func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	var b := sin(phase * TAU + TAU / 3.0)
	var c := sin(phase * TAU + 2.0 * TAU / 3.0)
	return {
		&"leg_b": r(Vector3(0, 0, a * 0.14)),
		&"leg_r": r(Vector3(0, 0, b * 0.14)),
		&"leg_l": r(Vector3(0, 0, c * 0.14)),
		&"hip": pr(Vector3(0, (absf(a) + absf(b) + absf(c)) * 0.015, 0)),
		&"mast": r(Vector3(a * 0.02, 0, b * 0.02)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on or pose == &"dead":
		return
	_t += delta
	# The crown turns slowly on its bearing while it works, and stops dead when it
	# has you.
	(joints[&"crown"] as Node3D).rotation.y = 0.0 if locked() else _t * 0.35
