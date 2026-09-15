extends MachineModel
## A cutter: the only circle in the world. A toothed disc on edge, wider than the
## body, carried out in front of a compact upright housing on a boom, over six
## fanned legs. It cuts stone and cannot hear you while it does. The drive on its
## back is the working part.
##
## alert  the blade lifts on its boom and the body rises on its legs
## dead   the disc stops, the legs give, and the body sinks onto its own spoil
##
## lights a work lamp low on the chassis lighting the cut, one over the drive
##        that goes hot through a windup, a status lamp blinking once
## wear   blocks of the stone it cut lashed on the chassis, stone dust caked
##        pale up the legs and along the chassis, a tooth off
##        another machine's disc, a spliced cable, the housing scorched by the
##        drive

const BODY_Y := 0.3
const DISC_R := 0.47
const ARM_TIP := Vector3(0.36, 0.62, 0.0)
const KNEE := Vector3(0.2, 0.2, 0.0)
const LEG_X := [0.16, -0.06, -0.28]

var _spin := 0.0


func build() -> void:
	part_side = &"back"
	height = 1.85
	# Show the disc nearly face-on: the circle is the read; the drive shows as a sliver.
	gallery_turn = -78.0
	stride = 0.9
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var body := joint(&"body", self, Vector3(0, BODY_Y, 0))
	var k := FoundKit.kit()
	var chassis := FoundKit.plan_oct(0.66, 0.5, 0.16)
	FoundKit.loft(k, [FoundKit.ring(chassis, -0.05, 0.03), FoundKit.ring(chassis, -0.02), FoundKit.ring(chassis, 0.03, 0.02)], D)
	var house := FoundKit.plan_oct(0.36, 0.34, 0.1)
	var sh := Vector2(-0.1, 0)
	FoundKit.loft(k, [FoundKit.ring(house, 0.03, 0.0, Vector2.ONE, sh), FoundKit.ring(house, 0.34, 0.02, Vector2.ONE, sh), FoundKit.ring(house, 0.42, 0.09, Vector2.ONE, sh)], R, true)
	FoundKit.visor(k, Vector3(0.081, 0.25, 0), Vector3.RIGHT, Vector3.UP, 0.18, 0.035)
	FoundKit.streaks(k, Vector3(0.081, 0.21, 0), Vector3.RIGHT, 0.16, 0.14, 4, 41, R[1])
	for sz: float in [-1.0, 1.0]:
		FoundKit.seam(k, Vector3(-0.24, 0.12, sz * 0.171), Vector3(0.02, 0.12, sz * 0.171), Vector3.BACK * sz, R, 3)
	# The drive on the back: a drum, and a cover over the shaft to the boom.
	FoundKit.disc(k, Vector3(-0.3, 0.17, 0), Vector3.RIGHT, 0.13, 0.08, 8, 0.02, R, R[2], PI / 8.0)
	FoundKit.cbox(k, Vector3(-0.12, 0.44, 0), Vector3(0.24, 0.05, 0.08), 0.015, D)
	body_mesh(k, body)
	add_lamp(body, Vector3(0.02, 0.422, 0.1), Vector3.UP, Vector3.RIGHT, 0.04, 0.04, &"status")
	add_lamp(body, Vector3(0.332, -0.01, 0), Vector3.RIGHT, Vector3.UP, 0.08, 0.035, &"work")
	add_beam(body, Vector3(0.4, -0.02, 0), Vector3(1.0, -0.3, 0), 1.1, 0.8, &"work")
	add_lamp(body, Vector3(-0.282, 0.34, 0), Vector3.LEFT, Vector3.UP, 0.05, 0.04, &"work", true)
	var dust: Array = [Palette.LINEN[2], Palette.LINEN[3], Palette.LINEN[3], Palette.LINEN[4], Palette.LINEN[4], Palette.LINEN[4]]
	var bw := FoundKit.kit()
	for sz: float in [-1.0, 1.0]:
		FoundKit.dirt_line(bw, Vector3(-0.28, -0.035, sz * 0.251), Vector3(0.28, -0.035, sz * 0.251), Vector3.BACK * sz, 0.03, Palette.LINEN[3])
	FoundKit.dirt_line(bw, Vector3(0.331, -0.04, -0.15), Vector3(0.331, -0.04, 0.15), Vector3.RIGHT, 0.025, Palette.LINEN[3])
	FoundKit.scorch(bw, Vector3(-0.281, 0.25, 0.0), Vector3.LEFT, 0.06, 51)
	FoundKit.cable(bw, Vector3(-0.2, 0.36, 0.172), Vector3(0.0, 0.1, 0.24), 0.03, 0.013, Palette.INK[2], Palette.MACHINE["harvester"], 4)
	FoundKit.grime(bw, Vector3(-0.1, 0.4, -0.171), Vector3.FORWARD, 0.2, 0.2, 3, 52, D)
	wear_mesh(bw, body)
	# Blocks of what it cuts, carried on the chassis either side of the housing,
	# under the disc where the camera sees them, lashed down with line.
	var blocks := FoundKit.matter_kit(Ink.CONTOUR)
	for b: Vector3 in [Vector3(0.2, 0.02, 0.19), Vector3(-0.16, 0.02, -0.19)]:
		blocks.rock(b.x, b.y, b.z, 0.16, 0.2, 57 + int(b.z * 10.0), Palette.LINEN[4], 4)
		blocks.strut(b + Vector3(-0.12, 0.09, 0.0), b + Vector3(0.12, 0.09, 0.0), 0.014, 4, Palette.INK[2])
	wear_matter(blocks, body)
	add_scan(body, Vector3(0.081, 0.25, 0), Vector3.RIGHT, Vector3.BACK, 0.13, 0.03, 1.6)

	var pk := FoundKit.kit()
	FoundKit.optic(pk, Vector3(-0.341, 0.17, 0), Vector3.LEFT, 0.075)
	for y: float in [0.12, 0.22]:
		FoundKit.mark(pk, Vector3(-0.341, y, 0), Vector3.LEFT, Vector3.UP, 0.2, 0.014, Palette.LENS[1], 0.016)
	part_mesh(pk, body)
	set_part_anchor(body, Vector3(-0.35, 0.17, 0), 0.55)

	for si in 2:
		var s := -1.0 if si == 0 else 1.0
		for xi in 3:
			var fan := (xi - 1) * 0.55
			var leg := joint(StringName("leg%d" % (si * 3 + xi)), body, Vector3(LEG_X[xi], 0.0, s * 0.22), Vector3(0, -s * PI * 0.5 - s * fan, 0))
			var lk := FoundKit.kit()
			FoundKit.disc(lk, Vector3.ZERO, Vector3.UP, 0.04, 0.05, 6, 0.01, R)
			FoundKit.tbar(lk, Vector3.ZERO, KNEE, 0.024, 0.02, 6, R)
			FoundKit.spot(lk, KNEE + Vector3(0, 0, 0.021), Vector3.BACK, 0.026, 6, R[4], 0.001)
			var foot := Vector3(0.44, -BODY_Y, 0)
			FoundKit.tbar(lk, KNEE, foot, 0.02, 0.012, 6, D)
			FoundKit.tbar(lk, foot, foot + Vector3(0.012, -0.02, 0), 0.014, 0.0, 4, DD)
			body_mesh(lk, leg)
			# Stone dust caked pale up the lower leg.
			var lw := FoundKit.kit()
			FoundKit.tbar(lw, KNEE.lerp(foot, 0.55), foot, 0.022, 0.015, 4, dust)
			wear_mesh(lw, leg)

	# The boom carries the disc up and over the front of the housing, clear of it.
	var arm := joint(&"arm", body, Vector3(-0.12, 0.44, 0))
	var ak := FoundKit.kit()
	for sz: float in [-1.0, 1.0]:
		# A plate from the pivot to the hub, 0.12 wide at the root and 0.1 at the tip.
		var along := Vector2(ARM_TIP.x, ARM_TIP.y).normalized()
		var across := Vector2(-along.y, along.x)
		var tip := Vector2(ARM_TIP.x, ARM_TIP.y)
		var side: Array[Vector2] = [-across * 0.06, tip - across * 0.05, tip + across * 0.05, across * 0.06]
		FoundKit.slab(ak, Vector3(0, 0, sz * 0.075), Vector3.RIGHT, Vector3.UP, side, 0.03, R)
		FoundKit.rivets(ak, ARM_TIP * 0.15 + Vector3(0, 0, sz * 0.091), ARM_TIP * 0.8 + Vector3(0, 0, sz * 0.091), Vector3.BACK * sz, 5, R[5], 0.03)
	FoundKit.disc(ak, Vector3.ZERO, Vector3.BACK, 0.065, 0.2, 8, 0.015, R, R[4], PI / 8.0)
	FoundKit.disc(ak, ARM_TIP, Vector3.BACK, 0.08, 0.22, 8, 0.02, R, R[4], PI / 8.0)
	body_mesh(ak, arm)

	var disc := joint(&"disc", arm, ARM_TIP)
	var dk := FoundKit.kit()
	var face_r: Array = [R[0], R[0], R[1], R[1], R[4], R[5]]
	# A dark face inside a bright ground rim: the circle has to read at any distance.
	FoundKit.lathe(dk, Vector3.ZERO, Vector3.BACK, [Vector2(DISC_R - 0.05, -0.022), Vector2(DISC_R, -0.01), Vector2(DISC_R, 0.01), Vector2(DISC_R - 0.05, 0.022)], 16, [R[4], R[4], R[5], R[4], R[5], R[5]], PI / 16.0, Vector2.ONE, Color(0, 0, 0, 0), -1, false)
	FoundKit.disc(dk, Vector3.ZERO, Vector3.BACK, DISC_R - 0.05, 0.03, 16, 0.0, face_r, R[1], PI / 16.0)
	FoundKit.disc(dk, Vector3.ZERO, Vector3.BACK, 0.16, 0.07, 8, 0.02, R, R[3], PI / 8.0)
	for j in 8:
		var a := float(j) / 8.0 * TAU
		var dir := Vector3(cos(a), sin(a), 0)
		var tan := Vector3(-sin(a), cos(a), 0)
		var tooth: Array[Vector2] = [Vector2(-0.07, 0.0), Vector2(0.05, 0.0), Vector2(0.02, 0.1), Vector2(-0.02, 0.09)]
		if j == 5:
			# One tooth came off another machine's disc: wear, like any patch.
			var tw := FoundKit.kit()
			FoundKit.slab(tw, dir * (DISC_R - 0.02), tan, dir, tooth, 0.05, FoundKit.dirty(Palette.MACHINE["runner"], 1))
			wear_mesh(tw, disc)
		else:
			FoundKit.slab(dk, dir * (DISC_R - 0.02), tan, dir, tooth, 0.05, [R[3], R[3], R[4], R[4], R[5], R[5]])
		for sz: float in [-1.0, 1.0]:
			var mid := Vector3(cos(a + PI / 8.0), sin(a + PI / 8.0), 0)
			FoundKit.mark(dk, mid * 0.34 + Vector3(0, 0, sz * 0.016), Vector3.BACK * sz, mid, 0.03, 0.3, R[2], 0.002)
	body_mesh(dk, disc)

	# Spoil under it, only once it has sunk onto it: stone, drawn by the hand.
	var spoil := Node3D.new()
	add_child(spoil)
	var sk := FoundKit.matter_kit(Ink.CONTOUR)
	for j in 7:
		var a := float(j) / 7.0 * TAU + 0.3
		sk.rock(-0.1 + cos(a) * 0.36, 0.0, sin(a) * 0.34, 0.13 + Rng.hash01(81, j) * 0.07, 0.11 + Rng.hash01(82, j) * 0.06, 810 + j, Palette.LINEN[3] if j % 2 == 0 else Palette.STONE[3], 5)
	matter_mesh(sk, spoil)
	dead_only(spoil, LIGHT_FIRST)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"arm"] = pr(Vector3(0, 0.12, 0), Vector3(0, 0, 0.62))
			d[&"body"] = pr(Vector3(0, 0.2, 0), Vector3(0, 0, 0.06))
			for i in 6:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.36))
		&"windup":
			d[&"arm"] = pr(Vector3(0, 0.08, 0), Vector3(0, 0, 1.0))
			d[&"body"] = pr(Vector3(-0.06, 0.04, 0), Vector3(0, 0, 0.12))
		&"strike":
			d[&"arm"] = r(Vector3(0, 0, -0.48))
			d[&"body"] = pr(Vector3(0.16, 0.0, 0), Vector3(0, 0, -0.1))
			# The fore legs take the dip.
			for i: int in [0, 3]:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.16))
			for i: int in [1, 4]:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.08))
		&"dead":
			d[&"body"] = pr(Vector3(0, -0.24, 0), Vector3(0.06, 0, -0.04))
			d[&"arm"] = r(Vector3(0, 0, -0.3))
			for i in 6:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.62))
	return d


## Alternating tripods; each swinging leg lifts at the hip.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for i in 6:
		var tripod := 1.0 if (i % 2 == 0) == (i < 3) else -1.0
		var sw := sin(phase * TAU) * tripod
		var lift := maxf(0.0, cos(phase * TAU) * tripod)
		var s := -1.0 if i < 3 else 1.0
		d[StringName("leg%d" % i)] = r(Vector3(0, sw * 0.24 * s, lift * 0.22))
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
