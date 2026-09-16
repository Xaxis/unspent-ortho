extends MachineModel
## A clerk: an archway walking, all head and all legs. A six-sided filing case
## carried between two long legs that rise above it at the knee, stooped, head
## down at hip height, reading the ground. It was never built to be near
## anything: no working part. What it sees goes through the slit in its face.
##
## alert  the head comes up on a graduated neck that was not there
## dead   the legs go out sideways; the head comes down last
##
## lights a status lamp on the lid blinking three (observant); the face throws a
##        stipple beam down onto the ground it reads, and up at you on alert
## wear   records stuffed into the filing slot and fanned out of it, tags of FOUND stock hanging off
##        the lid rim, a cable spliced down its neck, a crack across the slit

const HIP_Y := 0.6

var _read_t := 0.0


func build() -> void:
	part_side = &"none"
	height = 1.05
	stride = 0.7
	nominal_speed = 1.2
	gallery_turn = 20.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hips := joint(&"hips", self, Vector3(0, HIP_Y, 0))
	for sz: float in [-1.0, 1.0]:
		var s := "r" if sz > 0 else "l"
		var thigh := joint(StringName("thigh_" + s), hips, Vector3(0, 0.0, sz * 0.31))
		var tk := FoundKit.kit()
		FoundKit.disc(tk, Vector3.ZERO, Vector3.BACK, 0.05, 0.07, 6, 0.012, R)
		FoundKit.tbar(tk, Vector3.ZERO, Vector3(0, 0.42, sz * 0.22), 0.03, 0.024, 6, R)
		FoundKit.disc(tk, Vector3(0, 0.42, sz * 0.22), Vector3.BACK, 0.04, 0.06, 6, 0.01, R)
		body_mesh(tk, thigh)
		var shin := joint(StringName("shin_" + s), thigh, Vector3(0, 0.42, sz * 0.22))
		var sk := FoundKit.kit()
		FoundKit.tbar(sk, Vector3.ZERO, Vector3(0, -0.98, -sz * 0.03), 0.024, 0.014, 6, D)
		FoundKit.tbar(sk, Vector3(0, -0.98, -sz * 0.03), Vector3(0.0, -1.02, -sz * 0.03), 0.016, 0.0, 4, DD)
		FoundKit.tbar(sk, Vector3(-0.04, -0.94, -sz * 0.03), Vector3(0.08, -0.94, -sz * 0.03), 0.01, 0.01, 4, DD)
		body_mesh(sk, shin)

	# The case hangs stooped from the hips: front edge down.
	var lid := joint(&"lid", hips, Vector3(0.02, 0.02, 0), Vector3(0, 0, -0.32))
	var k := FoundKit.kit()
	var hexa: Array[Vector2] = []
	for j in 6:
		var a := float(j) / 6.0 * TAU + PI / 6.0
		hexa.append(Vector2(cos(a) * 0.3, sin(a) * 0.32))
	FoundKit.loft(k, [FoundKit.ring(hexa, -0.12, 0.03), FoundKit.ring(hexa, -0.08), FoundKit.ring(hexa, 0.14), FoundKit.ring(hexa, 0.2, 0.05)], R, true, true)
	FoundKit.loft(k, [FoundKit.ring(hexa, 0.2, 0.08), FoundKit.ring(hexa, 0.235, 0.1)], R)
	FoundKit.mark(k, Vector3(0.0, 0.237, 0), Vector3.UP, Vector3.RIGHT, 0.26, 0.018, R[2], 0.002)
	# The filing slot across the front, paper edges showing in it.
	FoundKit.mark(k, Vector3(0.262, 0.04, 0), Vector3.RIGHT, Vector3.UP, 0.3, 0.045, R[0], 0.003)
	FoundKit.mark(k, Vector3(0.262, 0.05, 0), Vector3.RIGHT, Vector3.UP, 0.24, 0.012, Palette.LINEN[4], 0.005)
	FoundKit.streaks(k, Vector3(0.262, 0.01, 0), Vector3.RIGHT, 0.24, 0.08, 5, 161, R[1])
	FoundKit.rivets(k, Vector3(0.262, 0.12, -0.12), Vector3(0.262, 0.12, 0.12), Vector3.RIGHT, 4, R[5])
	for sz: float in [-1.0, 1.0]:
		var n := Vector3(0.5, 0, sz * 0.866)
		FoundKit.panel(k, Vector3(0.13, 0.03, sz * 0.23), n, Vector3.UP, 0.18, 0.14, R)
	FoundKit.seam(k, Vector3(-0.262, -0.06, 0.0), Vector3(-0.262, 0.14, 0.0), Vector3.LEFT, R, 2)
	body_mesh(k, lid)
	# The lid of the case: the plate a clerk shows the world it files.
	day_wear(lid, Vector3(0.02, 0.238, 0), Vector3.UP, Vector3.RIGHT, 0.22, 0.24, 131, 1)
	add_lamp(lid, Vector3(-0.1, 0.237, 0.1), Vector3.UP, Vector3.RIGHT, 0.04, 0.04, &"status")
	var lw := FoundKit.kit()
	for j in 3:
		var a := -0.9 - j * 0.35
		FoundKit.tag(lw, Vector3(cos(a) * 0.28, 0.14, sin(a) * 0.3), 0.08 + j * 0.03, 0.05, 0.06, Palette.MACHINE["watcher"] if j != 1 else Palette.MACHINE["lineman"], a)
	FoundKit.grime(lw, Vector3(0.262, 0.0, 0.08), Vector3.RIGHT, 0.14, 0.1, 3, 161, D)
	wear_mesh(lw, lid)
	var papers := FoundKit.matter_kit(Ink.HAND)
	for j in 5:
		var z := -0.13 + j * 0.065
		# Fanned up out of the slot: each sheet turned a little further up and over.
		var tilt := 0.35 + (Rng.hash01(162, j) - 0.2) * 0.7
		var turn := (Rng.hash01(163, j) - 0.5) * 0.5
		papers.push(Transform3D(Basis(Vector3.UP, turn) * Basis(Vector3.BACK, tilt), Vector3(0.25, 0.05 + j * 0.006, z)))
		papers.quad(Vector3(-0.02, 0, -0.05), Vector3(-0.02, 0, 0.05), Vector3(0.2, 0, 0.05), Vector3(0.2, 0, -0.05), Palette.LINEN[4] if j % 2 else Palette.LINEN[5])
		papers.quad(Vector3(-0.02, 0, -0.05), Vector3(0.2, 0, -0.05), Vector3(0.2, 0, 0.05), Vector3(-0.02, 0, 0.05), Palette.LINEN[3])
		papers.pop()
	wear_matter(papers, lid)

	var neck := joint(&"neck", lid, Vector3(0, 0.2, 0))
	var nk := FoundKit.kit()
	FoundKit.tbar(nk, Vector3(0, -0.34, 0), Vector3(0, 0.0, 0), 0.04, 0.04, 8, D)
	FoundKit.ticks(nk, Vector3(0.04, -0.3, 0), Vector3(0.04, -0.02, 0), Vector3.RIGHT, 8, R[5], 0.02)
	body_mesh(nk, neck)
	var nw := FoundKit.kit()
	FoundKit.cable(nw, Vector3(-0.045, -0.02, 0.02), Vector3(-0.045, -0.3, 0.01), 0.0, 0.012, Palette.INK[2], Palette.MACHINE["hauler"], 3)
	wear_mesh(nw, neck)
	var head := joint(&"head", neck, Vector3.ZERO)
	var ek := FoundKit.kit()
	FoundKit.lathe(ek, Vector3(0.02, 0.0, 0), Vector3.UP, [Vector2(0.16, 0.0), Vector2(0.26, 0.04), Vector2(0.26, 0.08), Vector2(0.2, 0.11)], 6, R, PI / 6.0, Vector2(1.0, 1.0), Color(0, 0, 0, 0), 2)
	FoundKit.visor(ek, Vector3(0.245, 0.06, 0), Vector3.RIGHT, Vector3.UP, 0.18, 0.026)
	body_mesh(ek, head)
	add_scan(head, Vector3(0.245, 0.06, 0), Vector3.RIGHT, Vector3.BACK, 0.14, 0.022, 1.6)
	add_beam(head, Vector3(0.25, 0.04, 0), Vector3(1.0, -1.25, 0), 1.35, 0.9)
	var hw := FoundKit.kit()
	FoundKit.mark(hw, Vector3(0.247, 0.06, 0.03), Vector3.RIGHT, Vector3(0, 1, 0.9), 0.008, 0.05, Palette.INK[0], 0.012)
	wear_mesh(hw, head)
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
			d[&"neck"] = pr(Vector3(0, 0.36, 0))
			d[&"head"] = r(Vector3(0, 0, 0.12))
		&"windup":
			# A clerk does not strike, it files. Where a warden squares up, this
			# one stoops INTO you with the lid gaping: the opposite shape to alert,
			# so the two are never confused at a glance.
			d[&"hips"] = pr(Vector3(0.16, -0.06, 0))
			d[&"thigh_l"] = r(Vector3(0.45, 0, 0))
			d[&"thigh_r"] = r(Vector3(-0.45, 0, 0))
			d[&"shin_l"] = r(Vector3(-0.35, 0, 0))
			d[&"shin_r"] = r(Vector3(0.35, 0, 0))
			d[&"lid"] = r(Vector3(0, 0, 0.66))
			d[&"neck"] = pr(Vector3(0.2, 0.12, 0))
			d[&"head"] = r(Vector3(0, 0, -0.5))
		&"strike":
			d[&"lid"] = r(Vector3(0, 0, 0.1))
			d[&"neck"] = pr(Vector3(0.2, 0.24, 0))
			d[&"head"] = r(Vector3(0, 0, -0.6))
			d[&"hips"] = pr(Vector3(0.08, -0.04, 0))
		&"dead":
			d[&"hips"] = pr(Vector3(0, -0.44, 0))
			d[&"thigh_l"] = r(Vector3(-0.9, 0, 0))
			d[&"thigh_r"] = r(Vector3(0.9, 0, 0))
			d[&"shin_l"] = r(Vector3(-0.55, 0, 0))
			d[&"shin_r"] = r(Vector3(0.55, 0, 0))
			d[&"lid"] = pr(Vector3(0, 0.02, 0), Vector3(0.1, 0, 0.26))
			d[&"neck"] = pr(Vector3(0.1, 0.12, 0))
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
	if looking_round():
		(joints[&"head"] as Node3D).rotation.y += (0.12 if fposmod(_read_t, 2.0) < 1.0 else -0.12)
