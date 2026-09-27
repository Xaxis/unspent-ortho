extends RefCounted
## What a holding puts between itself and the machines (docs/VISION.md,
## docs/LOOK.md): sharpened stakes, plate lashed to posts, and netting on
## leaning poles. **Obviously hand-made and obviously desperate.** Nothing here
## looks issued, nothing is the same length as its neighbour, and a run of wall
## is a run of what was to hand rather than a repeated tile.
##
## Each piece is a SHORT RUN, set down across the way somebody is coming from:
## it faces +X and its length goes along Z, so a player lays a line of them and
## the line is theirs, not the game's.

const Parts := preload("res://src/models/settlement/settle_parts.gd")
const P := preload("res://src/render/palette.gd")


## Stakes driven in and sharpened, braced with two rails. No two the same height
## and none of them plumb.
static func palisade(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var n := 6
	var heights := PackedFloat32Array()
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var z := lerpf(-0.72, 0.72, t) + Parts.lean(v, 10 + i, 0.05)
		var h := 0.92 + Parts.wob(v, 20 + i) * 0.34
		var down := ruined and Parts.wob(v, 30 + i) < 0.45
		if down:
			h *= 0.3
		heights.append(h)
		var foot := Vector3(Parts.lean(v, 40 + i, 0.06), 0.0, z)
		var head := foot + Vector3(Parts.lean(v, 50 + i, 0.12), h, Parts.lean(v, 60 + i, 0.05))
		var col := Parts.pick(Parts.TIMBER, v, 70 + i)
		Parts.post(k, foot, head, 0.062, col)
		if not down:
			# The sharpened end: a stake is a point, and the point is the drawing.
			k.prism(head.x, head.y - 0.02, head.z, 0.062, head.y + 0.2, 0.006, 5, col, col)
	if ruined:
		return
	# Two rails lashed across the backs of the stakes, neither of them level.
	for rail in 2:
		var y := 0.3 + 0.42 * float(rail)
		k.strut(Vector3(-0.1, y, -0.78), Vector3(-0.08, y + Parts.lean(v, 80 + rail, 0.06), 0.78), 0.04, 4,
			Parts.pick(Parts.TIMBER, v, 90 + rail))
		for i in n:
			if float(heights[i]) > y + 0.08:
				Parts.lash(k, Vector3(0.02, y, lerpf(-0.72, 0.72, (float(i) + 0.5) / float(n))),
					Vector3(-0.12, y - 0.03, lerpf(-0.72, 0.72, (float(i) + 0.5) / float(n))), v, 100 + rail * 6 + i, 0.022)


## A gate: two heavier posts with a crossbar pegged over them, and a hurdle of
## woven stakes hung off one post on rope hinges, swung half open -- the length
## of the ring a body walks through. Wrecked, the crossbar is down and the
## hurdle lies flat in the gap.
static func gate(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var h := 1.25 + Parts.wob(v, 1) * 0.12
	for side: float in [-1.0, 1.0]:
		var z := side * 0.72
		var top := h * (0.4 if ruined and side > 0.0 else 1.0)
		Parts.post(k, Vector3(Parts.lean(v, 2 + int(side), 0.04), 0.0, z), Vector3(Parts.lean(v, 4 + int(side), 0.08), top, z), 0.085,
			Parts.pick(Parts.TIMBER, v, 6 + int(side)))
		Parts.stone(k, Vector3(0.0, 0.0, z), 0.13, v, 8 + int(side))
	if not ruined:
		k.strut(Vector3(0.0, h - 0.05, -0.82), Vector3(0.0, h - 0.02 + Parts.lean(v, 10, 0.05), 0.82), 0.05, 4, Parts.pick(Parts.TIMBER, v, 11))
	# The hurdle: hung off the -Z post, swung out toward +X by a third of a turn;
	# wrecked, lying flat in the gap.
	var hinge := Vector3(0.0, 0.1, -0.64)
	var swing := Vector3(sin(1.0), 0.0, cos(1.0)) if not ruined else Vector3(0, 0, 1)
	var width := 1.2
	var n := 7
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var at := hinge + swing * width * t
		if ruined:
			k.strut(at + Vector3(-0.35, 0.02, 0.0), at + Vector3(0.35, 0.05, 0.0), 0.025, 4, Parts.pick(Parts.TIMBER, v, 20 + i))
		else:
			Parts.post(k, at, at + Vector3(Parts.lean(v, 30 + i, 0.03), 0.95 + Parts.wob(v, 40 + i) * 0.15, 0.0), 0.028,
				Parts.pick(Parts.TIMBER, v, 20 + i))
	if not ruined:
		for rail in 2:
			var y := 0.35 + 0.4 * float(rail)
			k.strut(hinge + Vector3(0, y, 0), hinge + swing * width + Vector3(0, y, 0), 0.03, 4, Parts.pick(Parts.TIMBER, v, 50 + rail))
		# Rope hinges: two lashings at the post.
		for y: float in [0.45, 0.85]:
			Parts.lash(k, hinge + Vector3(0.04, y, -0.06), hinge + Vector3(-0.04, y - 0.03, 0.06), v, 60 + int(y * 10.0), 0.03)


## The made half of a plate wall: the posts, the rails and every lashing that
## holds a panel somebody could not lift alone.
static func plate_wall_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var high := 1.32 if not ruined else 0.6
	for i in 3:
		var t := float(i) / 2.0
		var z := lerpf(-0.76, 0.76, t)
		var h := high * (0.88 + Parts.wob(v, 10 + i) * 0.2)
		Parts.post(k, Vector3(Parts.lean(v, 20 + i, 0.05), 0.0, z), Vector3(Parts.lean(v, 30 + i, 0.1), h, z), 0.075,
			Parts.pick(Parts.TIMBER, v, 40 + i))
		Parts.stone(k, Vector3(0.0, 0.0, z), 0.12, v, 50 + i)
	# A brace out to the back, jammed against a stone: this wall was pushed on.
	k.strut(Vector3(-0.04, high * 0.8, 0.3), Vector3(-0.42, 0.05, 0.4), 0.05, 4, Parts.pick(Parts.TIMBER, v, 60))
	Parts.bank(k, Vector3(0.0, 0.0, 0.0), 0.7, 0.2, v, 5)
	if ruined:
		return
	# The lashings, laid over the panels and across their rivet rows.
	for i in 6:
		var z := lerpf(-0.7, 0.7, (float(i) + 0.5) / 6.0)
		Parts.lash(k, Vector3(0.14, 0.34 + Parts.wob(v, 70 + i) * 0.6, z), Vector3(-0.12, 0.3 + Parts.wob(v, 80 + i) * 0.6, z), v, 90 + i, 0.03)


## The machine's half: three panels, none of them the same, cut off three
## different machines and stood on their ends.
static func plate_wall_found(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.ruled(k)
	var high := 1.32 if not ruined else 0.6
	for i in 3:
		if ruined and Parts.wob(v, 100 + i) < 0.4:
			continue
		var z := lerpf(-0.52, 0.52, float(i) / 2.0)
		var w := 0.28 + Parts.wob(v, 110 + i) * 0.06
		var h := high * (0.7 + Parts.wob(v, 120 + i) * 0.34)
		Parts.panel(k, Vector3(0.09, 0.0, z), Parts.lean(v, 130 + i, 0.06))
		Parts.plate(k, w, h, v, 140 + i)
		k.pop()


## Netting strung on leaning poles, weighted with stones, rag tied in it. It hides
## what a holding gives off (it is a `mask` in StructureKind.SIGNS), and it looks
## like what it is: the last thing anybody had time to do.
static func netting(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var n := 3
	var tops := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for i in n:
		var t := float(i) / float(n - 1)
		var z := lerpf(-0.8, 0.8, t) + Parts.lean(v, 10 + i, 0.06)
		var h := (1.0 + Parts.wob(v, 20 + i) * 0.3) * (0.45 if ruined else 1.0)
		zs.append(z)
		tops.append(h)
		Parts.post(k, Vector3(0.0, 0.0, z), Vector3(Parts.lean(v, 30 + i, 0.16), h, z + Parts.lean(v, 40 + i, 0.08)), 0.05,
			Parts.pick(Parts.TIMBER, v, 50 + i))
		Parts.stone(k, Vector3(0.06, 0.0, z), 0.1, v, 60 + i)
	# The net: cords between the poles, sagging, crossed by cords that hang off
	# them. A net drawn taut and even would be a grid, and a grid is the machines'.
	for bay in n - 1:
		var z0 := float(zs[bay])
		var z1 := float(zs[bay + 1])
		var h0 := float(tops[bay])
		var h1 := float(tops[bay + 1])
		var lines := 3 if not ruined else 1
		for line in lines:
			var t := (float(line) + 0.7) / float(lines + 1)
			var sag := 0.07 + 0.05 * sin(PI * t)
			var y0 := lerpf(0.2, h0 - 0.06, t)
			var y1 := lerpf(0.2, h1 - 0.06, t)
			k.strut(Vector3(0.0, y0, z0), Vector3(0.02, (y0 + y1) * 0.5 - sag, (z0 + z1) * 0.5), 0.016, 3, Parts.CORD)
			k.strut(Vector3(0.02, (y0 + y1) * 0.5 - sag, (z0 + z1) * 0.5), Vector3(0.0, y1, z1), 0.016, 3, Parts.CORD_DARK)
		# Rag knotted into it, which is what actually breaks up a silhouette.
		var rags := 3 if not ruined else 1
		for r in rags:
			var t := (float(r) + 0.5) / float(rags)
			var z := lerpf(z0, z1, t)
			var y := lerpf(0.4, minf(h0, h1) - 0.1, Parts.wob(v, 70 + bay * 3 + r))
			k.sway = 0.7
			k.sway_phase = Parts.wob(v, 80 + bay * 3 + r) * TAU
			Parts.flag(k, Vector3(0.0, y, z - 0.05), Vector3(0.0, y, z + 0.05),
				Vector3(Parts.lean(v, 90 + r, 0.05), y - 0.26, z + 0.04), Vector3(Parts.lean(v, 91 + r, 0.05), y - 0.3, z - 0.04),
				Parts.pick(Parts.CLOTH, v, 100 + bay * 3 + r), P.SAND[1])
			k.sway = 0.0


# --- decoy mast ---------------------------------------------------------------

## Where a decoy's crosstrees hang, so the made half and the machine's half agree.
const DECOY_TREE := 2.24

## The two arms of a decoy's crosstrees, in its own frame. Crossed at a quarter
## turn so it reads the same whichever way it was put up: one arm along the line
## of sight collapses into the pole at this camera, and a decoy that vanishes
## when it is turned the wrong way is not a lure.
static func _decoy_arms(v: int) -> Array[Vector3]:
	var lean_x := Parts.lean(v, 1, 0.12)
	var lean_z := Parts.lean(v, 2, 0.08)
	var tree := Vector3(lean_x * 0.82, DECOY_TREE, lean_z * 0.82)
	return [
		tree + Vector3(0.06, Parts.lean(v, 40, 0.07), -0.66), tree + Vector3(-0.05, Parts.lean(v, 41, 0.07), 0.62),
		tree + Vector3(-0.62, 0.12 + Parts.lean(v, 42, 0.06), 0.05), tree + Vector3(0.64, 0.12 + Parts.lean(v, 43, 0.06), -0.04),
	]


## The made half of a decoy: two spars spliced into one pole taller than anything
## else the holding has, two crosstrees lashed across it askew, guys to two pegs,
## a cairn at its foot and long rag streaming off every arm. A lure has to be seen
## before the place it stands for, so it is all height and movement.
static func decoy_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var lean_x := Parts.lean(v, 1, 0.12)
	var lean_z := Parts.lean(v, 2, 0.08)
	for i in 3:
		var a := TAU * float(i) / 3.0 + Parts.lean(v, 3 + i, 0.3)
		Parts.stone(k, Vector3(cos(a) * 0.16, 0.0, sin(a) * 0.16), 0.11, v, 10 + i)
	if ruined:
		# Snapped at the splice: the stump stands, the top lies along the ground with
		# a crosstree still lashed on and its rag in the grass.
		Parts.post(k, Vector3.ZERO, Vector3(lean_x * 0.4, 1.02, lean_z * 0.4), 0.06, Parts.pick(Parts.TIMBER, v, 20))
		var along := Vector3(cos(Parts.wob(v, 21) * TAU), 0.0, sin(Parts.wob(v, 21) * TAU))
		var base := along * 0.35 + Vector3(0.0, 0.05, 0.0)
		k.strut(base, base + along * 1.6 + Vector3(0.0, 0.04, 0.0), 0.05, 5, Parts.pick(Parts.TIMBER, v, 22))
		var across := Vector3(-along.z, 0.0, along.x)
		var tree := base + along * 1.2
		k.strut(tree - across * 0.55 + Vector3(0, 0.03, 0), tree + across * 0.5 + Vector3(0, 0.05, 0), 0.035, 4, Parts.pick(Parts.TIMBER, v, 23))
		Parts.flag(k, tree + across * 0.3 + Vector3(0, 0.04, 0), tree + across * 0.46 + Vector3(0, 0.04, 0),
			tree + across * 0.56 + along * 0.6 + Vector3(0, 0.03, 0), tree + across * 0.34 + along * 0.66 + Vector3(0, 0.03, 0),
			P.LINEN[4], P.LINEN[2])
		return
	# Two spars and the splice between them, lashed three times.
	var splice := Vector3(lean_x * 0.45, 1.25, lean_z * 0.45)
	var head := Vector3(lean_x, 2.72 + Parts.wob(v, 30) * 0.22, lean_z)
	Parts.post(k, Vector3.ZERO, splice + Vector3(0.0, 0.18, 0.0), 0.066, Parts.pick(Parts.TIMBER, v, 31))
	Parts.post(k, splice - Vector3(0.05, 0.2, 0.0), head, 0.052, Parts.pick(Parts.TIMBER, v, 32))
	for i in 3:
		var y := splice.y - 0.14 + 0.13 * float(i)
		Parts.lash(k, Vector3(splice.x + 0.07, y, splice.z - 0.05), Vector3(splice.x - 0.08, y + 0.03, splice.z + 0.05), v, 33 + i, 0.026)
	# Two crosstrees, neither square to the pole nor level, lashed where they cross.
	var arms := _decoy_arms(v)
	for i in 2:
		k.strut(arms[i * 2], arms[i * 2 + 1], 0.036, 4, Parts.pick(Parts.TIMBER, v, 44 + i))
		var mid: Vector3 = (arms[i * 2] + arms[i * 2 + 1]) * 0.5
		Parts.lash(k, mid + Vector3(0.08, 0.06, -0.06), mid + Vector3(-0.08, -0.06, 0.06), v, 46 + i, 0.024)
	# Guys to two pegs behind it: it is the one piece nobody wants blown over.
	for side: int in [-1, 1]:
		var peg := Vector3(-0.85, 0.0, side * 0.7)
		Parts.lash(k, head + Vector3(0.0, -0.45, 0.0), peg, v, 50 + side, 0.018)
		k.strut(peg, peg + Vector3(0.0, 0.15, 0.0), 0.026, 4, Parts.pick(Parts.TIMBER, v, 55 + side))
	# Rag off every arm: long, pale and never the same length. Pale because a lure
	# is a thing that is SEEN, and the movement is what the eye catches at the edge
	# of a frame — and at the edge of a machine's reading.
	for i in arms.size():
		var at: Vector3 = arms[i]
		var long := 0.7 + Parts.wob(v, 60 + i) * 0.4
		var wide := 0.09 + Parts.wob(v, 64 + i) * 0.04
		k.sway = 0.95
		k.sway_phase = Parts.wob(v, 70 + i) * TAU
		var out := Vector3(at.x, 0.0, at.z).normalized() * 0.12
		Parts.flag(k, at + Vector3(0.0, 0.0, -wide), at + Vector3(0.0, 0.0, wide),
			at + out + Vector3(Parts.lean(v, 80 + i, 0.16), -long, wide * 0.6), at + out + Vector3(Parts.lean(v, 90 + i, 0.16), -long * 0.84, -wide * 0.8),
			P.LINEN[3 + i % 2], P.LINEN[2])
		k.sway = 0.0


## The machine's half of a decoy: shards of plate hung off the crosstrees on cord,
## each turned a different way so something on it catches the light from wherever
## a machine is standing, and a mirror plate at the head tipped at the sky — the
## part a machine flying over, or a camera looking down, cannot miss.
static func decoy_found(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.ruled(k)
	if ruined:
		# Shards in the grass round the stump, face up, the way they fell.
		for i in 4:
			var a := Parts.wob(v, 110 + i) * TAU
			var r := 0.4 + 0.6 * Parts.wob(v, 120 + i)
			Parts.panel(k, Vector3(cos(a) * r, 0.02, sin(a) * r), PI * 0.5 - 0.1)
			Parts.plate(k, 0.1, 0.2, v, 130 + i)
			k.pop()
		return
	var arms := _decoy_arms(v)
	for bar in 2:
		var a: Vector3 = arms[bar * 2]
		var b: Vector3 = arms[bar * 2 + 1]
		for i in 3:
			var t := (float(i) + 0.5) / 3.0
			var top := a.lerp(b, t)
			var hang := 0.22 + Parts.wob(v, 150 + bar * 3 + i) * 0.28
			var at := top + Vector3(0.0, -hang, 0.0)
			k.strut(top + Vector3(0.0, -0.02, 0.0), at + Vector3(0.0, 0.26, 0.0), 0.012, 3, P.PLATE[1])
			var turn := Parts.wob(v, 160 + bar * 3 + i) * TAU
			Parts.panel_facing(k, at, Vector3(cos(turn), 0.0, sin(turn)))
			# The top of the ramp: a shard that did not catch the light would be a
			# shard nobody bothered to hang.
			k.quad(Vector3(-0.1, 0.0, 0.0), Vector3(0.1, 0.03, 0.0), Vector3(0.08, 0.26, 0.0), Vector3(-0.07, 0.22, 0.0), P.PLATE[5])
			k.quad(Vector3(-0.07, 0.22, -0.02), Vector3(0.08, 0.26, -0.02), Vector3(0.1, 0.03, -0.02), Vector3(-0.1, 0.0, -0.02), P.PLATE[3])
			k.pop()
	# The mirror at the head: a cut panel tipped back most of the way to flat.
	var lean_x := Parts.lean(v, 1, 0.12)
	var lean_z := Parts.lean(v, 2, 0.08)
	var head := Vector3(lean_x, 2.72 + Parts.wob(v, 30) * 0.22, lean_z)
	Parts.panel(k, head + Vector3(0.02, 0.02, 0.0), PI * 0.36)
	k.quad(Vector3(-0.26, 0.0, 0.0), Vector3(0.26, 0.0, 0.0), Vector3(0.22, 0.4, 0.0), Vector3(-0.2, 0.44, 0.0), P.PLATE[5])
	k.quad(Vector3(-0.2, 0.44, -0.02), Vector3(0.22, 0.4, -0.02), Vector3(0.26, 0.0, -0.02), Vector3(-0.26, 0.0, -0.02), P.PLATE[2])
	k.block(0.0, 0.2, 0.012, 0.5, 0.02, 0.012, P.PLATE[4])
	k.pop()
	# A can rattle at the splice, for the day when there is no light to catch.
	for i in 3:
		var y := 1.0 + 0.1 * float(i)
		k.prism(lean_x * 0.4 + 0.1, y, lean_z * 0.4 + Parts.lean(v, 170 + i, 0.06), 0.045, y + 0.09, 0.04, 6, P.PLATE[2], P.PLATE[4])


# --- spoofer ------------------------------------------------------------------

## Where the box sits, so the stand and the box agree.
const SPOOFER_BOX := 0.84

## The hand's half of a spoofer: three stakes lashed into a stand, stones on the
## feet, and cord wound round the box that the machine's half sits in. What holds
## the stolen thing up is the only part of it anybody here could have made.
static func spoofer_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var high := SPOOFER_BOX if not ruined else 0.34
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4 + Parts.lean(v, 10 + i, 0.2)
		var foot := Vector3(cos(a) * 0.34, 0.0, sin(a) * 0.34)
		var top := Vector3(cos(a) * 0.12, high, sin(a) * 0.12)
		if ruined and i == 0:
			# One leg kicked out: the stand went over sideways.
			top = foot + Vector3(0.5, 0.06, 0.2)
		Parts.post(k, foot, top, 0.04, Parts.pick(Parts.TIMBER, v, 20 + i))
		Parts.stone(k, foot, 0.09, v, 30 + i)
	if ruined:
		return
	# The cord round the box: over it twice, knotted to the stakes.
	for i in 2:
		var y := high + 0.08 + 0.14 * float(i)
		Parts.lash(k, Vector3(-0.2, y, -0.18), Vector3(0.2, y + 0.02, 0.18), v, 40 + i, 0.02)
	# A rag tied over the back against the rain, which is how people keep the
	# machines' things working.
	k.sway = 0.4
	k.sway_phase = Parts.wob(v, 50) * TAU
	Parts.flag(k, Vector3(-0.2, high + 0.4, -0.2), Vector3(-0.2, high + 0.4, 0.2),
		Vector3(-0.3, high + 0.02, 0.24), Vector3(-0.28, high - 0.02, -0.22), Parts.pick(Parts.CLOTH, v, 51), P.SAND[1])
	k.sway = 0.0


## The machine's half: a relay's voice box, ruled and riveted, three whips splayed
## off its top, a cut vane turned along the plan's own air, the cable out to the
## holding's power, and a tell-tale that burns while it is answering for the place.
static func spoofer_found(k: MeshKit, v: int, ruined: bool, lit: bool) -> void:
	Parts.ruled(k)
	if ruined:
		# Split and on its side in the grass, whips bent flat.
		k.prism(0.34, 0.0, 0.12, 0.16, 0.2, 0.13, 6, P.PLATE[1], P.PLATE[2])
		k.prism(0.62, 0.0, -0.06, 0.1, 0.12, 0.08, 6, P.PLATE[1], P.PLATE[1])
		k.strut(Vector3(0.4, 0.05, 0.1), Vector3(1.1, 0.04, 0.42), 0.012, 4, P.PLATE[3])
		k.strut(Vector3(0.42, 0.06, 0.14), Vector3(0.9, 0.03, -0.3), 0.012, 4, P.PLATE[3])
		k.prism(0.56, 0.12, 0.0, 0.03, 0.17, 0.022, 6, P.LENS[0], P.LENS[0])
		return
	var y := SPOOFER_BOX
	# The box: tapered, six-sided, a band where it was cut out of its bay.
	k.prism(0.0, y, 0.0, 0.2, y + 0.36, 0.16, 6, P.PLATE[2], P.PLATE[3], PI / 6.0)
	k.prism(0.0, y + 0.15, 0.0, 0.205, y + 0.19, 0.2, 6, P.PLATE[4], P.PLATE[4], PI / 6.0)
	# Three whips, none the same length, one bent where it was forced off its mount.
	for i in 3:
		var a := TAU * float(i) / 3.0 + Parts.lean(v, 60 + i, 0.4)
		var from := Vector3(cos(a) * 0.08, y + 0.36, sin(a) * 0.08)
		var long := 0.55 + Parts.wob(v, 70 + i) * 0.35
		var to := from + Vector3(cos(a) * 0.22, long, sin(a) * 0.22)
		if i == 2:
			var knee := from + Vector3(cos(a) * 0.08, long * 0.5, sin(a) * 0.08)
			k.strut(from, knee, 0.012, 4, P.PLATE[4])
			k.strut(knee, to + Vector3(cos(a) * 0.2, -0.1, sin(a) * 0.2), 0.011, 4, P.PLATE[4])
		else:
			k.strut(from, to, 0.012, 4, P.PLATE[4])
	# The vane: a cut ear off a relay, turned to face along the ground.
	Parts.panel_facing(k, Vector3(0.18, y + 0.2, 0.0), Vector3(1.0, 0.0, Parts.lean(v, 80, 0.5)))
	Parts.plate(k, 0.1, 0.24, v, 81)
	k.pop()
	# The cable down to the ground and away to wherever the power is.
	k.strut(Vector3(-0.12, y + 0.04, 0.06), Vector3(-0.3, 0.02, 0.2), 0.016, 4, P.PLATE[1])
	k.strut(Vector3(-0.3, 0.02, 0.2), Vector3(-0.9, 0.01, 0.34 + Parts.lean(v, 82, 0.2)), 0.016, 4, P.PLATE[1])
	if lit:
		Parts.tell_tale(k, Vector3(0.17, y + 0.26, -0.1), 0.03)
	else:
		k.prism(0.17, y + 0.26, -0.1, 0.03, y + 0.31, 0.022, 6, P.LENS[0], P.LENS[0])


# --- turret -------------------------------------------------------------------

## Where the gun turns, on top of its crib, and where a bolt leaves it in the
## head's own frame (the head faces +X), so the model and the shot agree.
const TURRET_PIVOT := Vector3(0.0, 0.7, 0.0)
const TURRET_MUZZLE := Vector3(0.7, 0.16, 0.0)

## The hand's half of a turret: a crib of logs laid two by two, notched and
## crossed, with sacks of earth banked against it. The only thing about it anybody
## here could make is what holds the stolen gun up off the ground.
static func turret_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var layers := 4 if not ruined else 2
	for layer in layers:
		var y := 0.07 + 0.16 * float(layer)
		var across := layer % 2 == 1
		for side: int in [-1, 1]:
			var off := 0.3 * float(side) + Parts.lean(v, 10 + layer * 2 + side, 0.03)
			var a := Vector3(off, y, -0.42) if not across else Vector3(-0.42, y, off)
			var b := Vector3(off, y + Parts.lean(v, 20 + layer, 0.03), 0.42) if not across else Vector3(0.42, y + Parts.lean(v, 20 + layer, 0.03), off)
			k.strut(a, b, 0.075, 5, Parts.pick(Parts.TIMBER, v, 30 + layer * 2 + side))
	# Sacks of earth against two sides of it: rag stuffed and tied.
	for i in 3:
		var a := PI * 0.6 + float(i) * 0.55 + Parts.lean(v, 40 + i, 0.15)
		var at := Vector3(cos(a) * 0.56, 0.0, sin(a) * 0.56)
		k.rock(at.x, 0.0, at.z, 0.17, 0.2 + Parts.wob(v, 50 + i) * 0.06, v * 13 + i, Parts.pick(Parts.CLOTH, v, 60 + i), 6)
	if ruined:
		# Two logs rolled off into the grass.
		for i in 2:
			var a := Parts.wob(v, 70 + i) * TAU
			var at := Vector3(cos(a) * 0.7, 0.07, sin(a) * 0.7)
			var dir := Vector3(cos(a + 1.2), 0.0, sin(a + 1.2)) * 0.42
			k.strut(at - dir, at + dir, 0.075, 5, Parts.pick(Parts.TIMBER, v, 80 + i))


## The machine's half that does not turn: the ring it pivots on, bolted down
## through the top logs, the cable run down the crib and away to the power, and
## the tell-tale that says it is armed. Wrecked, the gun lies beside the crib.
static func turret_found(k: MeshKit, v: int, ruined: bool, lit: bool) -> void:
	Parts.ruled(k)
	if ruined:
		k.strut(Vector3(0.5, 0.08, 0.3), Vector3(1.1, 0.05, 0.62), 0.035, 6, P.PLATE[3])
		k.strut(Vector3(0.2, 0.1, 0.18), Vector3(0.56, 0.09, 0.34), 0.09, 6, P.PLATE[2])
		k.prism(-0.2, 0.36, 0.1, 0.16, 0.42, 0.15, 8, P.PLATE[1], P.PLATE[2])
		k.prism(0.52, 0.02, 0.5, 0.03, 0.07, 0.02, 6, P.LENS[0], P.LENS[0])
		return
	var y := TURRET_PIVOT.y
	k.prism(0.0, y - 0.06, 0.0, 0.2, y, 0.18, 8, P.PLATE[2], P.PLATE[3])
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI / 4.0
		k.prism(cos(a) * 0.16, y - 0.02, sin(a) * 0.16, 0.022, y + 0.01, 0.02, 6, P.PLATE[4], P.PLATE[4])
	k.strut(Vector3(-0.16, y - 0.04, 0.12), Vector3(-0.36, 0.06, 0.3), 0.018, 4, P.PLATE[1])
	k.strut(Vector3(-0.36, 0.06, 0.3), Vector3(-1.0, 0.01, 0.46 + Parts.lean(v, 90, 0.2)), 0.018, 4, P.PLATE[1])
	if lit:
		Parts.tell_tale(k, Vector3(0.0, y - 0.03, -0.2), 0.035)
	else:
		k.prism(0.0, y - 0.03, -0.2, 0.035, y + 0.03, 0.026, 6, P.LENS[0], P.LENS[0])


## The gun, drawn round its own pivot and facing +X so a node can turn it: the
## repeater's receiver, its barrel and shroud, the lens it fires through, and a
## cut plate bolted on as a shield — the one thing about it a person added.
static func turret_head(k: MeshKit, v: int) -> void:
	Parts.ruled(k)
	# The yoke it sits in.
	k.prism(0.0, 0.0, 0.0, 0.1, 0.08, 0.09, 6, P.PLATE[2], P.PLATE[3])
	# Receiver and barrel, along +X.
	k.strut(Vector3(-0.22, 0.16, 0.0), Vector3(0.14, 0.16, 0.0), 0.1, 6, P.PLATE[3])
	k.strut(Vector3(0.12, 0.16, 0.0), Vector3(TURRET_MUZZLE.x - 0.02, TURRET_MUZZLE.y, 0.0), 0.034, 6, P.PLATE[4])
	k.strut(Vector3(0.3, 0.16, 0.0), Vector3(0.44, 0.16, 0.0), 0.05, 6, P.PLATE[2])
	# The lens at the muzzle, cold amber: it catches when the gun picks a body.
	k.strut(Vector3(TURRET_MUZZLE.x - 0.04, TURRET_MUZZLE.y, 0.0), TURRET_MUZZLE, 0.045, 6, P.LENS[1])
	# The feed drum under the receiver, and the cable out of its back.
	k.prism(-0.06, 0.02, 0.0, 0.07, 0.1, 0.065, 6, P.PLATE[2], P.PLATE[3])
	k.strut(Vector3(-0.22, 0.16, 0.0), Vector3(-0.36, 0.05, 0.08), 0.016, 4, P.PLATE[1])
	# The shield: a cut plate stood up across the front of the receiver, the
	# barrel run through a gap nobody squared.
	Parts.panel_facing(k, Vector3(0.18, 0.02, -0.06 + Parts.lean(v, 100, 0.02)), Vector3(1.0, 0.0, 0.0))
	Parts.plate(k, 0.17, 0.3, v, 101)
	k.pop()
