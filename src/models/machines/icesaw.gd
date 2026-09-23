extends MachineModel
## An icesaw: the Frost Sea's own worker (docs/LANDSCAPES.md §2, roster.gd
## `icesaw`). A low sled on two runners with a circular saw slung off its stern
## and one amber lens in its bow. It works the ice for the soundings line: the
## blade drops through the sheet behind it and the cut opens where it has been.
##
## Why a SLED. Every other worker in the game walks, and on a plain of ice a
## thing that walks is the wrong shape: the plan built a thing that slides, so
## the sled's whole silhouette is horizontal — two runners, a low hull, and the
## one vertical it owns is the saw standing up out of the ice behind it. Beside
## the listener (its keeper, six legs and a crown) it reads as a different
## animal at any distance, which is what a landscape's own two machines are for.
##
## Its colour is the CUTTER's ramp, on purpose: `src/render/palette.gd` is
## frozen to the form wave and holds one ramp per coast kind, a machine's colour
## is its ROLE, and this is a worker that cuts. When the palette is open again
## it wants a violet of its own on the worker arc.
##
## Welded where it curves (the hull's walls, the arm, the blade's rim) and hard
## where it is meant to be (the runners' corners, the hull's chamfer lines, the
## teeth). Six-sided members state a crease of 66 (sentinel_listener.gd says why).
##
## stand  stopped on the ice: the blade lifted clear, spinning down
## walk   CUTTING: the blade down through the sheet, the hull swaying on its
##        runners, the cut opening behind
## alert  the arm swings the blade up and forward over the hull at you
## windup the arm cocks high
## strike it comes down through where you were
## hurt   the arm jams half-way
## dead   the sled goes over on one runner with the blade out to the side
##
## lights the amber lens in its bow (the working part), the plan strip on the
##        hull's top, a work lamp on the arm lighting the cut behind
## wear   rime caked on both runners, a patch off a hauler in the hull, a cable
##        spliced down the arm

const HULL_Y := 0.24
const RUNNER_Z := 0.24
const CREASE_SIX := 66.0

var _spin := 0.0


func build() -> void:
	part_side = &"front"
	# The arm raised on alert, blade and all.
	height = 0.95
	stride = 1.6
	gallery_turn = 32.0
	begin_rig()
	ramp = Palette.MACHINE["cutter"]
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hull := joint(&"hull", self, Vector3(0, HULL_Y, 0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.98, 0.54, 0.12)
	k.smooth_begin()
	FoundKit.loft(k, [FoundKit.ring(plan, -0.08, 0.06), FoundKit.ring(plan, -0.02), FoundKit.ring(plan, 0.12), FoundKit.ring(plan, 0.18, 0.09)], R, true, true)
	k.smooth_end()
	# The housing over the drive, aft of the middle: the only thing on the hull
	# that stands up, so from above the sled reads bow-to-stern.
	var house := FoundKit.plan_oct(0.36, 0.34, 0.08)
	var aft := Vector2(-0.16, 0.0)
	k.smooth_begin()
	FoundKit.loft(k, [FoundKit.ring(house, 0.18, 0.0, Vector2.ONE, aft), FoundKit.ring(house, 0.4, 0.02, Vector2.ONE, aft), FoundKit.ring(house, 0.46, 0.08, Vector2.ONE, aft)], R, true)
	k.smooth_end()
	FoundKit.seam(k, Vector3(0.4, 0.181, 0.0), Vector3(0.06, 0.181, 0.0), Vector3.UP, R, 3)
	FoundKit.rivets(k, Vector3(0.36, 0.181, -0.2), Vector3(-0.3, 0.181, -0.2), Vector3.UP, 4, R[5])
	FoundKit.rivets(k, Vector3(0.36, 0.181, 0.2), Vector3(-0.3, 0.181, 0.2), Vector3.UP, 4, R[5])
	FoundKit.ticks(k, Vector3(0.492, 0.02, -0.1), Vector3(0.492, 0.02, 0.1), Vector3.RIGHT, 3, R[1])
	# Two runners under the hull on struts, each with its nose turned up: the
	# runners are what say it slides, so their corners stay hard.
	for sz: float in [-1.0, 1.0]:
		var sole := Vector3(0.0, -HULL_Y + 0.06, sz * RUNNER_Z)
		FoundKit.bar(k, sole + Vector3(-0.56, 0, 0), sole + Vector3(0.5, 0, 0), 0.05, 0.12, 0.01, DD)
		FoundKit.slab(k, sole + Vector3(0.48, 0, 0), Vector3.RIGHT, Vector3.UP,
			[Vector2(0.0, -0.025), Vector2(0.18, 0.1), Vector2(0.18, 0.14), Vector2(0.0, 0.025)], 0.12, DD)
		for x: float in [-0.36, 0.3]:
			FoundKit.tbar(k, Vector3(x, -0.08, sz * RUNNER_Z), Vector3(x, -HULL_Y + 0.08, sz * RUNNER_Z), 0.035, 0.03, 4, D)
	body_mesh(k, hull)
	add_lamp(hull, Vector3(0.1, 0.183, 0.14), Vector3.UP, Vector3.RIGHT, 0.05, 0.05, &"status")
	day_wear(hull, Vector3(-0.02, 0.183, -0.16), Vector3.UP, Vector3.RIGHT, 0.34, 0.18, 271, 1)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(0.24, 0.182, -0.12), Vector3.UP, Vector3.RIGHT, 0.2, 0.16, Palette.MACHINE["hauler"], 272)
	FoundKit.streaks(w, Vector3(-0.34, 0.46, 0.0), Vector3.LEFT, 0.24, 0.2, 3, 273, Palette.RIME[5])
	for sz: float in [-1.0, 1.0]:
		FoundKit.grime(w, Vector3(0.3, -HULL_Y + 0.1, sz * RUNNER_Z), Vector3.RIGHT, 0.1, 0.16, 2, 274 + int(sz),
			[Palette.RIME[4], Palette.RIME[5], Palette.RIME[3], Palette.RIME[5], Palette.RIME[5], Palette.RIME[4]])
	wear_mesh(w, hull)

	# The one amber lens in the bow: the working part. It reads the ice ahead
	# and it is the only saturated thing on the sled.
	var pk := FoundKit.kit()
	FoundKit.optic(pk, Vector3(0.493, 0.05, 0.0), Vector3.RIGHT, 0.07)
	FoundKit.mark(pk, Vector3(0.493, -0.04, 0.0), Vector3.RIGHT, Vector3.UP, 0.2, 0.014, Palette.LENS[1], 0.016)
	part_mesh(pk, hull)
	set_part_anchor(hull, Vector3(0.5, 0.05, 0.0), 0.5)

	# The arm off the stern, and the blade on its end: down through the ice
	# while it works, up and forward when it turns on you.
	var arm := joint(&"arm", hull, Vector3(-0.46, 0.06, 0.0))
	var ak := FoundKit.kit()
	ak.smooth_begin()
	FoundKit.tbar(ak, Vector3.ZERO, Vector3(-0.34, -0.12, 0.0), 0.06, 0.05, 6, R, 0.015)
	ak.smooth_end(CREASE_SIX)
	FoundKit.disc(ak, Vector3.ZERO, Vector3.BACK, 0.07, 0.14, 8, 0.015, R, R[4], PI / 8.0)
	FoundKit.tbar(ak, Vector3(-0.06, 0.04, 0.05), Vector3(-0.3, -0.08, 0.05), 0.02, 0.018, 4, DD)
	body_mesh(ak, arm)
	add_lamp(arm, Vector3(-0.16, 0.0, -0.06), Vector3.FORWARD, Vector3.UP, 0.05, 0.04, &"work")
	add_beam(arm, Vector3(-0.3, -0.02, 0.0), Vector3(-1.0, -0.4, 0.0), 1.3, 0.9, &"work")
	var aw := FoundKit.kit()
	FoundKit.cable(aw, Vector3(-0.02, 0.05, -0.04), Vector3(-0.3, -0.06, -0.05), 0.02, 0.011, Palette.INK[2], Palette.MACHINE["lineman"], 3)
	wear_mesh(aw, arm)

	var blade := joint(&"blade", arm, Vector3(-0.34, -0.12, 0.0))
	var bk := FoundKit.kit()
	bk.smooth_begin()
	FoundKit.disc(bk, Vector3.ZERO, Vector3.BACK, 0.27, 0.026, 14, 0.0, D)
	bk.smooth_end()
	for j in 10:
		var a := float(j) / 10.0 * TAU
		var out := Vector3(cos(a), sin(a), 0.0)
		FoundKit.slab(bk, out * 0.29, out, Vector3.BACK,
			[Vector2(-0.03, 0.025), Vector2(0.055, 0.008), Vector2(0.055, -0.016), Vector2(-0.03, -0.025)], 0.022, DD)
	FoundKit.spot(bk, Vector3(0.0, 0.0, -0.015), Vector3.FORWARD, 0.07, 8, R[5], 0.003)
	FoundKit.spot(bk, Vector3(0.0, 0.0, 0.015), Vector3.BACK, 0.07, 8, R[5], 0.003)
	body_mesh(bk, blade)
	finish_rig()


## The arm is the vocabulary: where the blade is says what the sled is doing.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Stopped: the blade lifted clear of the ice.
			d[&"arm"] = r(Vector3(0, 0, -0.5))
		&"alert":
			# It has you: the blade comes up and forward over the hull.
			d[&"arm"] = r(Vector3(0, 0, -1.0))
			d[&"hull"] = pr(Vector3(-0.04, 0.03, 0), Vector3(0, 0, 0.08))
		&"windup":
			d[&"arm"] = r(Vector3(0, 0, -1.5))
			d[&"hull"] = pr(Vector3(-0.08, 0.04, 0), Vector3(0, 0, 0.14))
		&"strike":
			d[&"arm"] = r(Vector3(0, 0, 0.3))
			d[&"hull"] = pr(Vector3(0.14, -0.02, 0), Vector3(0, 0, -0.1))
		&"hurt":
			d[&"arm"] = r(Vector3(0.2, 0, -0.3))
		&"dead":
			# Over on one runner, the blade out to the side.
			d[&"hull"] = pr(Vector3(0, -0.1, 0.06), Vector3(0.55, 0, 0.1))
			d[&"arm"] = r(Vector3(0.4, 0, -0.35))
	return d


## A sled does not step: the hull sways on its runners with the cut, exactly,
## and the blade throws the hull a little as it bites.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	return {
		&"hull": pr(Vector3(0, absf(a) * 0.012, 0), Vector3(a * 0.04, 0, absf(a) * 0.02)),
		&"arm": r(Vector3(0, 0, a * 0.03)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	var rate := 2.0
	match pose:
		&"walk": rate = 9.0
		&"alert": rate = 4.5
		&"windup", &"strike": rate = 14.0
	_spin += delta * rate
	(joints[&"blade"] as Node3D).rotation.z = -_spin
