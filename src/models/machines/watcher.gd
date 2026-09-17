extends MachineModel
## A watcher: a cross on a tripod, the only cross-shaped thing in the world. A
## surveyor's instrument that nobody is standing behind. It stands on rises and
## looks, indexing its head through the same bearings forever. The optic at the
## front of the head is its working part. The head bar is a long spindle across
## the line of sight, so end-on it is as thin as the mast: its width shows which
## way it looks.
##
## alert  the inner mast runs up out of its sleeve, showing its graduations, and
##        fins stand out above and below the bar ends; the beam stops and narrows
## dead   the light dies, the legs fold shut up the mast and the post is left
##        standing on its plumb point
##
## lights a status lamp on the drum blinks three (observant); two rangefinder
##        eyes on the bar ends; a stipple beam thrown from under the objective
##        onto the ground it is surveying
## wear   a plate off another machine on the drum, a taped cable up the mast, a
##        cracked back slit, and a pale strip of someone's cloth knotted high on a
##        leg as a survey flag

const HUB_Y := 0.64
const FOOT := Vector3(0.5, -0.6, 0.0)
const BEARINGS := [PI, PI / 3.0, -PI / 3.0]
const FIN_Z := 0.31
## The drum's radius and the survey shade's half-size: the two flat things a
## camera that looks down can see the area of (see build()).
const DRUM := 0.21
## Half-size of the survey shade. Small enough that the cross bar and both
## rangefinder eyes still stand out past it: a watcher IS a cross on a tripod,
## and a shade wide enough to swallow the cross buys mass by throwing away the
## one silhouette in the roster nothing else makes.
const SHADE := Vector2(0.125, 0.17)


func build() -> void:
	part_side = &"front"
	height = 1.78
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var hub := joint(&"hub", self, Vector3(0, HUB_Y, 0))
	var hk := FoundKit.kit()
	# A six-sided drum, a plumb point under it, and the sleeve of the mast.
	#
	# The drum is WIDE, and that is the fix for art finding 3. Close up a watcher
	# is the best-drawn thing in the roster; the one a player sees from a hill
	# away was a thin mast and three splayed legs of scattered pixels, because
	# every member on it is two screen pixels across and two pixels carry no
	# chamfer, no rivet row and no slit. The game's camera looks DOWN, so the two
	# things it can see the area of are the drum's deck and the shade over the
	# head, and both are now wide enough to be a mass instead of a scribble.
	FoundKit.disc(hk, Vector3.ZERO, Vector3.UP, DRUM, 0.15, 6, 0.035, R, Color(0, 0, 0, 0), PI / 6.0)
	FoundKit.lathe(hk, Vector3(0, -0.075, 0), Vector3.UP, [Vector2(0.08, 0.0), Vector2(0.0, -0.17)], 6, D, PI / 6.0)
	FoundKit.tbar(hk, Vector3(0, 0.07, 0), Vector3(0, 0.6, 0), 0.052, 0.044, 8, R)
	FoundKit.disc(hk, Vector3(0, 0.6, 0), Vector3.UP, 0.066, 0.04, 8, 0.012, R, Color(0, 0, 0, 0), PI / 8.0)
	FoundKit.disc(hk, Vector3(0, 0.1, 0), Vector3.UP, 0.075, 0.03, 8, 0.01, R, Color(0, 0, 0, 0), PI / 8.0)
	for j in range(1, 6):
		var a := float(j) / 6.0 * TAU
		var n := Vector3(cos(a), 0, sin(a))
		FoundKit.mark(hk, n * (DRUM - 0.019), n, Vector3.UP, 0.03, 0.03, R[5], 0.004)
	# A rivet row round the deck's rim, which is the one place on this instrument
	# with room for one and the place the camera is looking.
	for j in 6:
		var a0 := float(j) / 6.0 * TAU
		var a1 := float(j + 1) / 6.0 * TAU
		FoundKit.rivets(hk, Vector3(cos(a0), 0, sin(a0)) * (DRUM - 0.03) + Vector3(0, 0.076, 0),
			Vector3(cos(a1), 0, sin(a1)) * (DRUM - 0.03) + Vector3(0, 0.076, 0), Vector3.UP, 2, R[5])
	FoundKit.streaks(hk, Vector3(0.047, 0.56, 0.0), Vector3.RIGHT, 0.05, 0.3, 2, 11, R[2])
	body_mesh(hk, hub)
	# The plan strip lies on the drum's deck, the one flat thing on a watcher and
	# the thing the high camera looks straight down at: a tally across it, clear
	# of the mast, is what says from a hill away what the instrument makes of you.
	add_lamp(hub, Vector3(-0.03, 0.1515, 0.10), Vector3.UP, Vector3.BACK, 0.04, 0.035, &"status")
	var hw := FoundKit.kit()
	var back_face := Vector3(cos(TAU / 3.0), 0, sin(TAU / 3.0))
	FoundKit.patch(hw, back_face * (DRUM - 0.018), back_face, Vector3.UP, 0.12, 0.1, Palette.MACHINE["lineman"], 17)
	FoundKit.grime(hw, Vector3(-(DRUM - 0.019), -0.02, 0), Vector3.LEFT, 0.08, 0.14, 3, 18, D)
	# The drum's deck is the one flat thing on a watcher, and the camera looks
	# straight down at it. The instrument is too thin anywhere else for a hull's
	# marks — its members are two screen pixels wide — so the daylight it has is
	# here: the deck stepped a value down round the mast, a well worn into it
	# where something was unbolted, and a second run of grime down a facet.
	FoundKit.plate(hw, Vector3(0, 0.1505, 0), Vector3.UP, Vector3.RIGHT, 0.24, 0.20, R, -2)
	FoundKit.recess(hw, Vector3(0.075, 0.1515, 0.0), Vector3.UP, Vector3.RIGHT, 0.07, 0.07, R, 0.012, 1.4)
	var wet := Vector3(cos(TAU / 6.0), 0, sin(TAU / 6.0))
	FoundKit.grime(hw, wet * (DRUM - 0.019) + Vector3(0, -0.02, 0), wet, 0.07, 0.1, 2, 21, D)
	wear_mesh(hw, hub)

	for i in 3:
		var leg := joint(StringName("leg%d" % i), hub, Vector3(0.1, -0.02, 0), Vector3(0, BEARINGS[i], 0))
		# The joint sits at the knuckle; bearings rotate the knuckle round the hub.
		leg.position = Basis(Vector3.UP, BEARINGS[i]) * Vector3(0.1, -0.02, 0)
		var lk := FoundKit.kit()
		FoundKit.disc(lk, Vector3.ZERO, Vector3.BACK, 0.036, 0.07, 6, 0.01, R)
		FoundKit.tbar(lk, Vector3.ZERO, FOOT, 0.028, 0.019, 6, R)
		# A shoe with a peg and a point, as on a surveyor's legs.
		FoundKit.tbar(lk, FOOT * 0.86, FOOT * 0.86 + Vector3(0.05, 0.0, 0), 0.012, 0.012, 4, D)
		FoundKit.lathe(lk, FOOT, Vector3.DOWN, [Vector2(0.024, 0.0), Vector2(0.0, 0.06)], 6, D)
		body_mesh(lk, leg)
		if i == 2:
			# Someone's cloth, knotted high on a leg: a flag on a surveyed point. It
			# hangs clear inside the tripod, pale against the ground under it.
			var rk := FoundKit.matter_kit(Ink.HAND)
			var knot := FOOT * 0.26
			rk.strut(knot + Vector3(0, 0.03, -0.05), knot + Vector3(0, 0.03, 0.05), 0.045, 5, Palette.LINEN[4])
			FoundKit.rag(rk, knot + Vector3(-0.01, 0.0, 0.0), 0.44, 0.23, Palette.LINEN[5], 23, Vector3(0.5, 0, 1))
			wear_matter(rk, leg)

	var mast := joint(&"mast", hub, Vector3(0, 0.6, 0))
	var mk := FoundKit.kit()
	FoundKit.tbar(mk, Vector3(0, -0.36, 0), Vector3(0, 0.5, 0), 0.03, 0.03, 8, R)
	# Graduations: hidden in the sleeve until the mast runs up.
	FoundKit.ticks(mk, Vector3(0.03, -0.3, 0), Vector3(0.03, 0.42, 0), Vector3.RIGHT, 16, R[5], 0.022)
	FoundKit.ticks(mk, Vector3(0, -0.3, 0.03), Vector3(0, 0.42, 0.03), Vector3.BACK, 16, R[5], 0.022)
	body_mesh(mk, mast)
	# A cable up the mast, taped at two points by whatever mended it.
	var mw := FoundKit.kit()
	FoundKit.cable(mw, Vector3(-0.036, 0.46, -0.018), Vector3(-0.036, 0.02, -0.03), 0.0, 0.011, Palette.INK[2], Palette.MACHINE["hauler"], 4)
	wear_mesh(mw, mast)

	# The scan yaw sits between mast and head and is driven by the routine, not the pose.
	var yaw := Node3D.new()
	yaw.name = "yaw"
	yaw.position = Vector3(0, 0.52, 0)
	mast.add_child(yaw)
	var head := joint(&"head", yaw, Vector3.ZERO)
	var bk := FoundKit.kit()
	# The cross bar: a straight eight-sided bar with a terminal at each end, and a
	# HOUSING over its middle. The bar alone is two screen pixels: the housing is
	# what a chamfer and a slit can be cut into, and it is still thin end-on, so
	# the bar's width goes on saying which way the instrument is looking.
	FoundKit.tbar(bk, Vector3(0, 0, -0.42), Vector3(0, 0, 0.42), 0.046, 0.046, 8, R, 0.02)
	FoundKit.cbox(bk, Vector3(-0.005, 0.005, 0), Vector3(0.115, 0.13, 0.44), 0.028, R, 2)
	FoundKit.visor(bk, Vector3(0, 0.02, 0.222), Vector3.BACK, Vector3.UP, 0.22, 0.026)
	FoundKit.rivets(bk, Vector3(-0.045, 0.07, -0.19), Vector3(-0.045, 0.07, 0.19), Vector3.UP, 5, R[5])
	FoundKit.seam(bk, Vector3(0.04, 0.071, -0.2), Vector3(0.04, 0.071, 0.2), Vector3.UP, R, 4)
	for sz: float in [-1.0, 1.0]:
		FoundKit.disc(bk, Vector3(0, 0, sz * 0.43), Vector3.BACK, 0.064, 0.05, 8, 0.014, R, Color(0, 0, 0, 0), PI / 8.0)
		FoundKit.mark(bk, Vector3(0.0, 0.047, sz * 0.2), Vector3.UP, Vector3.BACK, 0.016, 0.26, R[2], 0.002)
	# The rubbed edge: along the top of the bar, where it has been handled.
	FoundKit.mark(bk, Vector3(0.012, 0.047, 0.28), Vector3.UP, Vector3.BACK, 0.014, 0.2, R[5], 0.003)
	# The instrument: an eight-sided barrel on the line of sight.
	# It flares to a hood at the front round a wide objective.
	FoundKit.lathe(bk, Vector3.ZERO, Vector3.RIGHT, [Vector2(0.07, -0.19), Vector2(0.1, -0.15), Vector2(0.1, 0.05), Vector2(0.14, 0.12), Vector2(0.14, 0.17)], 8, R, PI / 8.0)
	# Upper arm of the cross and its cap; a collar under the barrel.
	FoundKit.tbar(bk, Vector3(0, 0.09, 0), Vector3(0, 0.42, 0), 0.028, 0.022, 8, R)
	FoundKit.disc(bk, Vector3(0, 0.43, 0), Vector3.UP, 0.045, 0.03, 8, 0.01, R, Color(0, 0, 0, 0), PI / 8.0)
	# THE SURVEY SHADE: a sheet of plate bolted over the head on two stays, so the
	# sun is off the objective. It is the one thing on a watcher with real area
	# under a camera that looks down, and it is where its chamfer and its rivet
	# row live. It reaches FORWARD, over the optic, so from above the instrument
	# points, and the amber eye shows under its near edge.
	FoundKit.cbox(bk, Vector3(0.13, 0.46, 0), Vector3(SHADE.x * 2.0, 0.034, SHADE.y * 2.0), 0.042, R, 0)
	FoundKit.rivets(bk, Vector3(0.13 - SHADE.x * 0.8, 0.478, -SHADE.y * 0.84),
		Vector3(0.13 - SHADE.x * 0.8, 0.478, SHADE.y * 0.84), Vector3.UP, 3, R[5])
	FoundKit.rivets(bk, Vector3(0.13 + SHADE.x * 0.8, 0.478, -SHADE.y * 0.84),
		Vector3(0.13 + SHADE.x * 0.8, 0.478, SHADE.y * 0.84), Vector3.UP, 3, R[5])
	FoundKit.seam(bk, Vector3(0.13, 0.479, -SHADE.y * 0.9), Vector3(0.13, 0.479, SHADE.y * 0.9), Vector3.UP, R, 3)
	FoundKit.streaks(bk, Vector3(0.13 + SHADE.x * 0.95, 0.455, 0.0), Vector3.RIGHT, 0.07, 0.06, 3, 29, R[2])
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(bk, Vector3(0.03, 0.26, sz * 0.09), Vector3(0.15, 0.44, sz * SHADE.y * 0.7), 0.017, 0.014, 5, R)
	FoundKit.disc(bk, Vector3(0, -0.1, 0), Vector3.UP, 0.05, 0.04, 8, 0.01, D, Color(0, 0, 0, 0), PI / 8.0)
	# Plate at the back of the barrel with its cold slit; rivets round the bezel.
	FoundKit.visor(bk, Vector3(-0.19, 0.0, 0), Vector3.LEFT, Vector3.UP, 0.1, 0.022)
	for j in 8:
		var a := float(j) / 8.0 * TAU + PI / 8.0
		FoundKit.mark(bk, Vector3(0.171, sin(a) * 0.122, cos(a) * 0.122), Vector3.RIGHT, Vector3.UP, 0.02, 0.02, R[5], 0.004)
	FoundKit.streaks(bk, Vector3(0.14, -0.06, 0.0), Vector3.RIGHT, 0.08, 0.05, 3, 12, R[2])
	# Rangefinder housings on the bar ends, an eye in each.
	for sz: float in [-1.0, 1.0]:
		FoundKit.cbox(bk, Vector3(0.06, 0.0, sz * 0.43), Vector3(0.07, 0.07, 0.06), 0.012, R)
	body_mesh(bk, head)
	for sz: float in [-1.0, 1.0]:
		add_lamp(head, Vector3(0.096, 0.0, sz * 0.43), Vector3.RIGHT, Vector3.UP, 0.035, 0.035, &"optic")
	add_scan(head, Vector3(-0.19, 0.0, 0), Vector3.LEFT, Vector3.BACK, 0.07, 0.02, 2.4)
	add_beam(head, Vector3(0.18, -0.05, 0), Vector3(2.2, -1.6, 0), 2.6, 1.5)
	var cw := FoundKit.kit()
	# The back slit took a blow: a crack across it, never replaced.
	FoundKit.mark(cw, Vector3(-0.19, 0.0, 0.01), Vector3.LEFT, Vector3(0, 1, 0.8), 0.008, 0.07, Palette.INK[0], 0.012)
	FoundKit.scorch(cw, Vector3(-0.14, -0.08, -0.05), Vector3(-0.5, -0.4, -0.7), 0.04, 19)
	wear_mesh(cw, head)

	var iris := joint(&"iris", head, Vector3(0.172, 0, 0))
	var ik := FoundKit.kit()
	FoundKit.optic(ik, Vector3.ZERO, Vector3.RIGHT, 0.085)
	# The level vial along the top of the barrel, lit with the optic: from the
	# game's high camera it is the part of the eye you always see.
	var vial := Vector3(-0.1, 0.1 * cos(PI / 8.0) + 0.001, 0.0) - Vector3(0.172, 0, 0)
	FoundKit.mark(ik, vial, Vector3.UP, Vector3.RIGHT, 0.08, 0.12, Palette.LENS[0], 0.003)
	FoundKit.mark(ik, vial, Vector3.UP, Vector3.RIGHT, 0.05, 0.09, Palette.LENS[2], 0.006)
	FoundKit.mark(ik, vial + Vector3(0.015, 0, 0), Vector3.UP, Vector3.RIGHT, 0.024, 0.03, Palette.LENS[3], 0.009)
	part_mesh(ik, iris)
	# The spill round the optic, kept to about the barrel's own size: at 0.55 the
	# halo was wider than the whole instrument and read as a sprite laid over it.
	set_part_anchor(head, Vector3(0.18, 0, 0), 0.38)

	# Fins: blades folded flat along the bar at rest, stood out on alert.
	for i in 4:
		var up := i < 2
		var sz := 1.0 if i % 2 == 0 else -1.0
		var dir := 1.0 if up else -1.0
		var fin := joint(StringName("fin%d" % i), head, Vector3(0, dir * 0.05, sz * FIN_Z))
		var fk := FoundKit.kit()
		var blade: Array[Vector2] = [Vector2(-0.045, 0.0), Vector2(0.045, 0.0), Vector2(0.018, 0.25), Vector2(-0.018, 0.25)]
		if not up:
			blade = [Vector2(-0.045, 0.0), Vector2(-0.018, -0.2), Vector2(0.018, -0.2), Vector2(0.045, 0.0)]
		FoundKit.slab(fk, Vector3.ZERO, Vector3.BACK, Vector3.UP, blade, 0.018, R)
		FoundKit.mark(fk, Vector3(0.01, dir * 0.12, 0), Vector3.RIGHT, Vector3.UP, 0.012, 0.14, R[5], 0.002)
		body_mesh(fk, fin)
	_fold_fins()
	finish_rig()


## Fin rest: lying along the bar toward its middle.
func _fold_fins() -> void:
	for i in 4:
		var up := i < 2
		var sz := 1.0 if i % 2 == 0 else -1.0
		# Rotating about X carries +Y toward +Z; fold each fin toward the centre.
		(joints[StringName("fin%d" % i)] as Node3D).rotation.x = sz * PI * 0.5 * (1.0 if up else -1.0)


func _fins_out(amount: float) -> Dictionary:
	var d := {}
	for i in 4:
		var up := i < 2
		var sz := 1.0 if i % 2 == 0 else -1.0
		var s := 1.0 if up else -1.0
		# From folded (sz*s*90deg) to standing a little outward (-sz*s*16deg).
		d[StringName("fin%d" % i)] = r(Vector3(-sz * s * (PI * 0.5 + 0.28) * amount, 0, 0))
	return d


func _pose_deltas(p: StringName) -> Dictionary:
	match p:
		&"alert":
			var d := _fins_out(1.0)
			d[&"mast"] = pr(Vector3(0, 0.3, 0))
			for i in 3:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.1))
			d[&"hub"] = pr(Vector3(0, 0.05, 0))
			return d
		&"windup":
			# The post leans back on its tripod; the feet stay where they are.
			var d := _fins_out(0.6)
			d[&"mast"] = pr(Vector3(0, 0.2, 0), Vector3(0, 0, 0.14))
			d[&"head"] = r(Vector3(0, 0, -0.36))
			return d
		&"strike":
			var d := _fins_out(1.0)
			d[&"mast"] = pr(Vector3(0.04, 0.08, 0), Vector3(0, 0, -0.3))
			d[&"head"] = r(Vector3(0, 0, -0.55))
			d[&"hub"] = pr(Vector3(0.04, 0.0, 0))
			return d
		&"dead":
			# Folded shut like a put-away tripod, the plumb point in the ground:
			# the post stays standing.
			var d := {}
			d[&"hub"] = pr(Vector3(0, -HUB_Y + 0.2, 0))
			for i in 3:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 2.18))
			d[&"mast"] = pr(Vector3(0, -0.3, 0))
			d[&"head"] = r(Vector3(0.0, 0, -0.42))
			return d
	return {}


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		match j:
			&"mast": return Vector2(LIGHT_FIRST + 0.5, 0.5)
			&"head": return Vector2(LIGHT_FIRST + 1.1, 0.35)
	return super(p, j)


## The three legs lift in turn, one at a time: a slow exact tripod walk.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for i in 3:
		var t := fposmod(phase * 3.0 - i, 3.0)
		var lift := sin(t * PI) if t < 1.0 else 0.0
		d[StringName("leg%d" % i)] = r(Vector3(0, 0, lift * 0.24))
	d[&"hub"] = pr(Vector3(0, absf(sin(phase * TAU * 1.5)) * 0.02, 0))
	return d


func _routine(_delta: float, on: bool) -> void:
	var yaw := (joints[&"head"] as Node3D).get_parent() as Node3D
	if not on:
		return
	if looking_round():
		# Centre, left, centre, right: an exact hold, then a servo move to the next.
		var t := fposmod(clock, 6.0) / 6.0
		var slot := int(t * 4.0)
		var within := t * 4.0 - slot
		var bearings := [0.0, 0.55, 0.0, -0.55]
		var from: float = bearings[slot]
		var to: float = bearings[(slot + 1) % 4]
		yaw.rotation.y = lerpf(from, to, smoothstep(0.0, 1.0, clampf((within - 0.75) / 0.25, 0.0, 1.0)))
	else:
		yaw.rotation.y = move_toward(yaw.rotation.y, 0.0, 0.15)
