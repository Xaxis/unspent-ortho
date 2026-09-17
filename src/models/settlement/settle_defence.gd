extends RefCounted
## What a holding puts between itself and the machines (docs/VISION.md §9,
## docs/ART.md §10): sharpened stakes, plate lashed to posts, and netting on
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
