extends RefCounted
## What washes up and what is left: driftwood, wrack, bones, wrecks of
## machines, tips of scrap, and vents. The wreck's hull, the scrap plate, the
## float and cable, the flanged pipe are FOUND: exact, symmetric, clean. The
## wood, the weed, the bones and the ground they lie in are MADE.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.DRIFTWOOD: driftwood(k, v, c)
		PropKind.WRACK: wrack(k, v, c)
		PropKind.BONES: bones(k, v, c)
		PropKind.WRECK: wreck(k, v, c)
		PropKind.TIP: tip(k, v, c)
		PropKind.VENT: vent(k, v, c)


## Sea-worn wood is the one thing on a beach with no edges left on it, and it was
## the hardest-faceted model in the game at 91% of its corners. The rounding now
## comes from `Kit.limb` itself (see `Kit.GROWN`), which welds each limb
## separately -- finer than the bracket that used to sit here, which spanned the
## whole build.
static func driftwood(k: Kit, v: int, _c: int) -> void:

	var s := 10000 + v * 13
	# TIMBER (row 80): sea-silvered wood is still sawn and split wood, and the
	# grain the row draws is what a stripped log on a tide line is all surface of.
	var woods: Array[Color] = [GroundColors.made(P.LINEN[3], GroundColors.TIMBER),
		GroundColors.made(P.ASH[3], GroundColors.TIMBER), GroundColors.made(P.LINEN[2], GroundColors.TIMBER)]
	if v % 3 == 2:
		# One big trunk, silvered, with its root plate.
		k.limb(Vector3(-0.8, 0.1, 0.1), Vector3(0.7, 0.07, -0.15), 0.13, 0.06, 6, woods[0], Vector3(0, 0.04, 0.08))
		for i in 7:
			var a := float(i) / 7.0 * TAU
			k.limb(Vector3(-0.85, 0.12, 0.1), Vector3(-0.98, 0.14 + sin(a) * 0.32, 0.1 + cos(a) * 0.32), 0.04, 0.01, 3, woods[1])
		k.limb(Vector3(0.1, 0.13, -0.05), Vector3(0.36, 0.38, 0.16), 0.035, 0.01, 3, woods[2])
		return
	for i in 4:
		var a := Kit.j(s, i, 1.5) + i * 0.8
		var l := 0.46 + Kit.j(s, 10 + i, 0.15)
		var y := 0.06 + i * 0.05
		var cx := Kit.j(s, 20 + i, 0.2)
		var cz := Kit.j(s, 30 + i, 0.2)
		k.limb(Vector3(cx - cos(a) * l, y, cz - sin(a) * l), Vector3(cx + cos(a) * l, y + 0.03, cz + sin(a) * l), 0.06 + i * 0.008, 0.035, 5, woods[i % 3], Vector3(0, 0.02, Kit.j(s, 40 + i, 0.05)))
	if v % 3 == 1:
		# A float and a coil of cable among the wood.
		k.found.prism(0.36, 0.0, 0.3, 0.1, 0.06, 0.14, 10, P.RUST[4])
		k.found.prism(0.36, 0.06, 0.3, 0.14, 0.2, 0.14, 10, P.RUST[4])
		k.found.prism(0.36, 0.2, 0.3, 0.14, 0.27, 0.07, 10, P.RUST[4], P.RUST[5])
		# A coil of cable, not a black puck: two loose turns in the sheath's own
		# grey with the ground showing between them, and an end lying out of it.
		# At the play camera the old pair filled a sixteen-pixel disc, which read
		# as a hole in the beach (docs/LOOK.md section 6).
		k.hoop(Vector3(-0.36, 0.05, 0.3), 0.19, 12, 0.014, P.PLATE[1])
		k.hoop(Vector3(-0.33, 0.08, 0.31), 0.12, 12, 0.014, P.INK[3])
		k.sag(Vector3(-0.2, 0.06, 0.42), Vector3(0.06, 0.04, 0.56), -0.02, 3, 0.013, P.PLATE[1])


static func wrack(k: Kit, v: int, _c: int) -> void:
	var s := 10200 + v * 7
	var cols: Array[Color] = [P.EARTH[1], P.SPRUCE[1], P.MOSS[1], P.EARTH[2]]
	# Strands of kelp lying in a line along the tide mark.
	for i in 11:
		var x := -0.9 + i * 0.18 + Kit.j(s, i, 0.05)
		var z := Kit.j(s, 10 + i, 0.14)
		var a := Kit.j(s, 20 + i, 1.2)
		var l := 0.18 + Kit.j(s, 30 + i, 0.08)
		var d := Vector3(cos(a), 0, sin(a)) * l
		var side := Vector3(-sin(a), 0, cos(a)) * 0.06
		var y := 0.02 + i * 0.002
		var c := Vector3(x, y, z)
		k.made.quad(c - d - side, c - d + side, c + d + side * 0.5, c + d - side * 0.5, cols[i % 4])
	for i in 5:
		k.stone(-0.7 + i * 0.35, -0.02, 0.1 + Kit.j(s, 40 + i, 0.1), 0.05, 0.06, s + 50 + i, P.EARTH[2], 5)
	if v % 3 == 1:
		k.sag(Vector3(-0.95, 0.04, -0.2), Vector3(0.95, 0.04, 0.26), 0.0, 5, 0.008, P.LINEN[5])
		k.found.prism(0.55, 0.0, 0.18, 0.07, 0.1, 0.07, 8, P.RUST[4], P.RUST[5])
	elif v % 3 == 2:
		# A shell of a crab and a whelk.
		k.fleck(Vector3(0.3, 0.03, -0.1), Vector3(0.42, 0.03, 0.0), Vector3(0.3, 0.06, 0.08), P.RUST[3])
		k.stone(-0.3, -0.01, -0.12, 0.05, 0.08, s + 60, P.LINEN[4], 5, 0.3)


static func bones(k: Kit, v: int, c: int) -> void:
	# BONE (row 90) — the one row named for exactly the thing using it, drawing
	# the long fibre of it and the odd pit. `pale` is what this landscape
	# bleaches, and every use below is a limb or a slab on the MADE pen.
	var pale := BiomeDressing.of(c).pale
	var bone := GroundColors.made(pale[0], GroundColors.BONE_MADE)
	var old := pale[1]
	var s := 10400 + v * 3
	k.hand(Ink.hand_of(c))
	match v % 3:
		0:
			# A ribcage half sunk, the spine along the ground.
			k.limb(Vector3(-0.62, 0.05, 0), Vector3(0.56, 0.07, 0.05), 0.04, 0.025, 5, old)
			for i in 6:
				var x := -0.38 + i * 0.16
				var h := 0.34 - absf(i - 2.5) * 0.05
				for side: float in [-1.0, 1.0]:
					var mid := Vector3(x + 0.04, h, side * 0.18)
					k.limb(Vector3(x, 0.07, 0.02), mid, 0.022, 0.018, 4, bone)
					k.limb(mid, Vector3(x + 0.08, 0.02, side * 0.3), 0.018, 0.01, 4, bone)
		1:
			# A long skull and a leg bone.
			k.slab(0.0, -0.02, 0.0, 0.42, 0.16, 0.2, s, bone, P.LINEN[5], 0.02, 0.2)
			k.slab(0.29, -0.02, 0.0, 0.22, 0.1, 0.13, s + 1, bone, P.LINEN[5], 0.015, 0.3)
			k.made.quad(Vector3(-0.1, 0.07, 0.105), Vector3(-0.02, 0.07, 0.105), Vector3(-0.02, 0.12, 0.105), Vector3(-0.1, 0.12, 0.105), P.INK[1])
			k.limb(Vector3(-0.42, 0.04, 0.36), Vector3(0.42, 0.04, 0.46), 0.035, 0.03, 5, bone)
			k.stone(-0.44, -0.01, 0.36, 0.06, 0.08, s + 2, P.LINEN[5], 5)
			k.stone(0.44, -0.01, 0.46, 0.06, 0.08, s + 3, P.LINEN[5], 5)
		_:
			for i in 6:
				var a := Kit.j(s, i, 1.6)
				var cx := Kit.j(s, 10 + i, 0.4)
				var cz := Kit.j(s, 20 + i, 0.4)
				var d := Vector3(cos(a), 0, sin(a)) * (0.15 + Kit.j(s, 30 + i, 0.05))
				k.limb(Vector3(cx, 0.03, cz) - d, Vector3(cx, 0.03, cz) + d, 0.025, 0.02, 4, bone if i % 2 else old)
			k.stone(0.1, -0.01, -0.1, 0.1, 0.1, s + 3, P.LINEN[5], 5)


## FOUND: a machine's hull run aground years ago: tilted, half sunk in the
## drift, one end torn open to its ribs. Exact even in ruin: straight members,
## rivet rows, the plate banded weathered violet and rust. The drift that
## buried it is MADE.
static func wreck(k: Kit, v: int, c: int) -> void:
	var body := P.PLATE[2]
	var dark := P.PLATE[1]
	var lit := P.PLATE[3]
	var rust := P.RUST[2]
	# Whatever banks against a thing left on this shore: sand, snow, ash, peat.
	var drift := BiomeDressing.of(c).drift[0]
	if v % 2 == 0:
		# The hull, rolled 20 degrees and nose down, its back third gone.
		k.found.push(Transform3D(Basis(Vector3.UP, 0.25) * Basis(Vector3.RIGHT, 0.36) * Basis(Vector3.BACK, -0.1), Vector3(0.0, -0.3, 0.0)))
		const LEN := 3.0
		const SEG := 10
		# The hull's section: eight sides, flat bottom, rounded shoulders.
		var sec: Array[Vector2] = [Vector2(0.62, 0.0), Vector2(0.66, 0.3), Vector2(0.66, 0.8), Vector2(0.44, 1.18),
			Vector2(-0.44, 1.18), Vector2(-0.66, 0.8), Vector2(-0.66, 0.3), Vector2(-0.62, 0.0)]
		for i in SEG:
			var x0 := -LEN * 0.5 + i * LEN / SEG
			var x1 := x0 + LEN / SEG
			if i < 3:
				# The torn end: ribs standing, a few ragged plates hanging on.
				var rib := PackedVector3Array()
				for q in sec:
					rib.append(Vector3(x1 - 0.02, q.y, q.x) * Vector3(1.0, 1.0 - (2 - i) * 0.04, 1.0))
				for e in rib.size() - 1:
					if i == 0 and e == 3:
						continue
					k.rod(rib[e], rib[e + 1], 0.03, 4, dark)
				if i == 2:
					k.found.quad(Vector3(x0, 0.3, 0.66), Vector3(x1, 0.3, 0.66), Vector3(x1, 0.8, 0.66), Vector3(x0 + 0.1, 0.72, 0.66), rust)
				if i == 1:
					# Wound to face UP: in the order its corners were written this
					# deck plate faced the ground, and found.gdshader culls a
					# back face, so the one piece of plate still hanging on over
					# the torn end drew from no bearing at all.
					k.found.quad(Vector3(x0 + 0.1, 1.1, 0.1), Vector3(x1, 1.18, 0.2), Vector3(x1, 1.18, -0.44), Vector3(x0 + 0.06, 1.12, -0.3), body)
				continue
			# Bands: every third plate rust, the rest weathered violet, alternating.
			var col := rust if i % 3 == 1 else (body if i % 2 == 0 else lit)
			for e in sec.size() - 1:
				var a := sec[e]
				var b2 := sec[e + 1]
				var shade := col if e >= 2 and e <= 4 else GroundColors.down(col, 0.1)
				k.found.quad(Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b2.y, b2.x), Vector3(x0, b2.y, b2.x), shade)
			# A rib standing proud between plates, with its rivet row.
			for e in sec.size() - 1:
				var a := sec[e] * 1.03
				var b2 := sec[e + 1] * 1.03
				k.found.quad(Vector3(x1 - 0.025, a.y, a.x), Vector3(x1 + 0.025, a.y, a.x), Vector3(x1 + 0.025, b2.y, b2.x), Vector3(x1 - 0.025, b2.y, b2.x), dark)
			for rr in 3:
				k.found.quad(Vector3(x0 + 0.06, 0.4 + rr * 0.2, 0.667), Vector3(x0 + 0.1, 0.4 + rr * 0.2, 0.667), Vector3(x0 + 0.1, 0.43 + rr * 0.2, 0.667), Vector3(x0 + 0.06, 0.43 + rr * 0.2, 0.667), P.PLATE[5])
		# The nose cap.
		for e in range(1, sec.size() - 1):
			k.found.tri(Vector3(LEN * 0.5, sec[0].y, sec[0].x), Vector3(LEN * 0.5, sec[e].y, sec[e].x), Vector3(LEN * 0.5, sec[e + 1].y, sec[e + 1].x), GroundColors.down(body, 0.2))
		# The visor slit at the nose, dark: the light went out.
		# Wound to face OUT of the nose, and set in a hood that stands clear of
		# the cap: taken in corner order the slit faced back into the hull, and
		# at four thousandths proud there was no bearing it could be seen from.
		for sy: float in [0.58, 0.78]:
			k.found.quad(Vector3(LEN * 0.5, sy, -0.38), Vector3(LEN * 0.5, sy, 0.38), Vector3(LEN * 0.5 + 0.05, sy, 0.38), Vector3(LEN * 0.5 + 0.05, sy, -0.38), GroundColors.down(body, 0.25) if sy < 0.7 else dark)
		k.found.quad(Vector3(LEN * 0.5 + 0.05, 0.76, -0.36), Vector3(LEN * 0.5 + 0.05, 0.76, 0.36), Vector3(LEN * 0.5 + 0.05, 0.6, 0.36), Vector3(LEN * 0.5 + 0.05, 0.6, -0.36), P.COLD[0])
		# The crane arm, a straight lattice snapped and folded back on the hull.
		k.rod(Vector3(0.8, 1.15, 0), Vector3(1.2, 1.9, 0), 0.05, 4, body)
		k.rod(Vector3(1.2, 1.9, 0), Vector3(0.3, 1.5, 0.25), 0.04, 4, body)
		k.rod(Vector3(0.95, 1.15, 0.12), Vector3(1.3, 1.82, 0.12), 0.025, 4, dark)
		k.found.pop()
		# The drift over its lower side and its torn end.
		_drift(k, [[-1.3, 0.2, 0.8, 0.5], [-0.4, 0.75, 0.7, 0.4], [0.5, 0.8, 0.8, 0.36], [1.3, 0.55, 0.5, 0.3], [-1.0, -0.6, 0.5, 0.26]], drift, 10601)
	else:
		# A cab sunk to its shoulders and tipped hard over, bands of rust on its
		# violet, the visor slit dark, a leg sticking up out of the drift.
		k.found.push(Transform3D(Basis(Vector3.BACK, 0.42) * Basis(Vector3.RIGHT, -0.15), Vector3(0, -0.5, 0)))
		k.chamfer(0.0, 0.0, 0.0, 1.5, 1.3, 1.3, 0.24, body, lit)
		for yy: float in [0.3, 0.7]:
			k.chamfer(0.0, yy, 0.0, 1.52, 0.16, 1.32, 0.24, rust, P.RUST[3])
		k.found.quad(Vector3(0.761, 0.96, 0.4), Vector3(0.761, 0.96, -0.4), Vector3(0.761, 1.1, -0.4), Vector3(0.761, 1.1, 0.4), P.COLD[0])
		k.chamfer(0.0, 1.3, 0.0, 1.2, 0.14, 1.0, 0.1, dark, body)
		for i in 5:
			k.found.quad(Vector3(0.762, 0.2 + i * 0.22, -0.6), Vector3(0.762, 0.2 + i * 0.22, -0.56), Vector3(0.762, 0.24 + i * 0.22, -0.56), Vector3(0.762, 0.24 + i * 0.22, -0.6), P.PLATE[5])
		k.found.pop()
		# The leg: two exact members and a foot, jammed up at an angle.
		k.rod(Vector3(-0.9, -0.1, -0.7), Vector3(-1.2, 0.9, -0.95), 0.07, 6, body)
		k.rod(Vector3(-1.2, 0.9, -0.95), Vector3(-0.95, 1.4, -1.25), 0.055, 6, dark)
		k.hoop(Vector3(-1.2, 0.9, -0.95), 0.09, 8, 0.02, rust, Vector3(0.3, 1.0, -0.2))
		_drift(k, [[0.5, 0.5, 0.8, 0.5], [0.9, -0.2, 0.6, 0.36], [-0.7, -0.5, 0.6, 0.3], [-0.2, 0.8, 0.5, 0.26]], drift, 10602)


## Drifted sand, snow or ash banked against a wreck: soft lumps [x, z, r, h],
## lit on top and shaded under, their feet sunk into the ground.
static func _drift(k: Kit, lumps: Array, col: Color, seed_value: int) -> void:
	for i in lumps.size():
		var l: Array = lumps[i]
		k.clump(l[0], -0.2, l[1], l[2], float(l[3]) + 0.2, seed_value + i, col if i % 2 == 0 else GroundColors.down(col, 0.08), 9)


## The three heaps of a tip, as (x, z, radius, height, foot).
const HEAPS: Array[Array] = [[0.0, 0.0, 1.3, 0.72, -0.12], [0.45, -0.3, 0.75, 0.55, 0.1], [-0.7, 0.5, 0.5, 0.3, -0.1]]


## Where the spoil actually is at (x, z). The scrap was laid on an imagined cone
## (`0.55 - r * 0.35`) that sits well inside the heaps the clumps make, so five
## of the sheets on a tip were buried in it and drew from no bearing
## (tests/render/test_found_drawn.gd).
static func _heap_y(x: float, z: float) -> float:
	var top := 0.0
	for l: Array in HEAPS:
		var d := Vector2(x - float(l[0]), z - float(l[1])).length()
		top = maxf(top, float(l[4]) + float(l[3]) * Kit.clump_top(d / float(l[2])))
	return top


static func tip(k: Kit, v: int, _c: int) -> void:
	var s := 10800 + v * 17
	# A heap: soil and slag under (MADE), scrap on top (FOUND).
	k.clump(0, -0.12, 0, 1.3, 0.72, s, P.STONE[1], 10)
	k.clump(0.45, 0.1, -0.3, 0.75, 0.55, s + 1, P.EARTH[1], 8)
	k.clump(-0.7, -0.1, 0.5, 0.5, 0.3, s + 2, P.STONE[2], 7)
	for i in 9:
		var a := float(i) * 2.39996 + v
		var r := 0.3 + fmod(float(i) * 0.19, 0.8)
		var y := _heap_y(cos(a) * r, sin(a) * r)
		var col: Color = [P.PLATE[2], P.RUST[2], P.STONE[2], P.RUST[3], P.PLATE[3], P.STONE[1]][i % 6]
		k.found.push(Transform3D(Basis(Vector3(cos(a), 0.5, sin(a)).normalized(), 0.6 + i * 0.3), Vector3(cos(a) * r, y, sin(a) * r)))
		k.chamfer(0, 0, 0, 0.36 + fmod(i * 0.13, 0.25), 0.05 + (i % 3) * 0.04, 0.24 + fmod(i * 0.09, 0.2), 0.03, col)
		k.found.pop()
	# A wheel, and cable in loops.
	k.found.push(Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3(-0.5, 0.45, 0.45)))
	k.found.prism(0, -0.05, 0, 0.26, 0.05, 0.26, 12, P.INK[2], P.STONE[2])
	k.found.prism(0, 0.05, 0, 0.07, 0.09, 0.07, 8, P.STONE[3])
	k.found.pop()
	k.cable(Vector3(-0.9, 0.1, -0.4), Vector3(0.3, 0.7, 0.2), -0.1, 5, 0.025, P.INK[2])
	k.cable(Vector3(0.3, 0.7, 0.2), Vector3(1.1, 0.05, 0.6), 0.1, 4, 0.025, P.INK[2])
	if v % 2 == 1:
		k.chamfer(0.2, _heap_y(0.2, 0.1), 0.1, 0.9, 0.05, 0.6, 0.06, P.PLATE[3], P.PLATE[4])


## A hole in the ground with fire under it (art findings 16 and 2, twice asked
## for). What was here was a solid pure-white disc 14x10 native px on a neat
## octagonal collar, nine identical ones to a frame and the only pure white in
## the landscape: fried eggs punched in the page. Three things were wrong and
## each is answered here.
##
## 1. THE HEAT READS IN STEPS, NOT AS A DISC. Clinker crust at the lip, deep red
##    down the throat wall, an amber floor, and a white core a THIRD the width
##    of the old disc — so the eye reads hot-centre-to-cool-edge, which is what a
##    hole into fire looks like, instead of one flat value.
## 2. THE CIRCLE IS BROKEN. The collar is seven clinker blocks at their own
##    radii and heights with two of them fallen away, the glow shows through the
##    gaps, and slabs of crust still lie across the mouth. Nothing about it is a
##    ring of eight equal facets.
## 3. NO TWO ARE ALIKE. VENT now carries four variants (PropModels.variants), so
##    the nine in one Burning frame are four different holes, each turned.
static func vent(k: Kit, v: int, _c: int) -> void:
	if v % 2 == 0:
		_vent_hole(k, v)
	else:
		_vent_pipe(k, v)


## Widest to hottest, in five steps: crust, collar, throat, floor, core. The core
## is the only step near the page and it is 0.11 across against the old 0.34.
static func _vent_hole(k: Kit, v: int) -> void:
	var s := 11000 + v * 17
	var big := v % 4 == 0
	var lip := 0.60 if big else 0.48
	var deep := 0.22 if big else 0.17
	# The crust the vent burnt through: a low, wide, uneven mound, not a cone.
	k.stone(0, -0.08, 0, lip + 0.16, 0.20 if big else 0.15, s + 1, P.STONE[1], 9, 0.0, P.RUST[1])
	k.stone(0.16, -0.06, 0.20, lip * 0.62, 0.13, s + 2, P.ASH[2], 7, 0.18)
	# The collar: blocks of clinker heaved up round the mouth, two of them gone.
	# The gap is where the glow gets out sideways, and it is what breaks the ring.
	var gap_a := int(Rng.hash01(s, 5) * 7.0)
	var gap_b := (gap_a + 3 + int(Rng.hash01(s, 6) * 2.0)) % 7
	for i in 7:
		if i == gap_a or i == gap_b:
			continue
		var a := float(i) / 7.0 * TAU + Rng.hash01(s, i, 3) * 0.5
		var rr := lip * (0.92 + Rng.hash01(s, i, 4) * 0.22)
		var h := (0.16 + Rng.hash01(s, i, 5) * 0.20) * (1.15 if big else 1.0)
		k.stone(cos(a) * rr, 0.04, sin(a) * rr, lip * 0.32, h, s + 20 + i,
			P.ASH[1] if i % 2 else P.STONE[2], 5, 0.0, P.INK[2])
	# Down the throat, which is SHALLOW. A deep bowl at this camera hides its own
	# floor behind the near rim and shows nothing but one wall — which is how the
	# first attempt at this traded a flat white disc for a flat red one.
	k.made.prism(0, 0.10, 0, lip * 0.80, deep * 0.35, lip * 0.68, 9, P.INK[1], P.EMBER[0])
	# The fire, laid in three rings and then largely COVERED: what the eye reads
	# is the seams between the crust plates, not a disc.
	k.made.prism(0, deep * 0.35, 0, lip * 0.72, deep * 0.4, lip * 0.68, 9,
		P.EMBER[1], GroundColors.glow(P.EMBER[3], 0.75))
	k.made.prism(0, deep * 0.4, 0, lip * 0.28, deep * 0.44, lip * 0.24, 8,
		GroundColors.glow(P.EMBER[4], 0.9), GroundColors.glow(P.EMBER[4], 1.0))
	# The hottest step stops SHORT of the page: `EMBER[5]` is already within a
	# breath of white and the emission carries it the rest of the way, so a
	# strength that clips is a fried egg again at a third the size.
	k.made.prism(0, deep * 0.44, 0, lip * 0.12, deep * 0.48, lip * 0.08, 7,
		GroundColors.glow(P.EMBER[5], 0.8), GroundColors.glow(P.EMBER[5], 0.9))
	# The crust that has not fallen in: five clinker plates floating on the fire in
	# a broken ring, so the amber comes up between them and the white shows only
	# through the one gap they leave. THIS is the broken circle the reviews asked
	# for twice, and it is why nothing here is a disc of one value.
	var open := int(Rng.hash01(s, 14) * 5.0)
	for i in 5:
		if i == open:
			continue
		var a := float(i) / 5.0 * TAU + Rng.hash01(s, i, 15) * 0.6
		var rr := lip * (0.34 + Rng.hash01(s, i, 16) * 0.20)
		k.stone(cos(a) * rr, deep * 0.36, sin(a) * rr, lip * (0.30 + Rng.hash01(s, i, 17) * 0.14),
			0.07 + Rng.hash01(s, i, 18) * 0.05, s + 40 + i, P.INK[1], 5, 0.0, P.ASH[0])
	# Sulphur burnt out on the lip, and the cracks the heat opened in the crust
	# running away from it: the broken circle, carried on outside the collar.
	for i in 6:
		var a := float(i) * 1.13 + Rng.hash01(s, i, 11)
		var p := Vector3(cos(a) * lip * 1.02, 0.12, sin(a) * lip * 1.02)
		k.fleck(p, p + Vector3(0.06, 0.0, 0.02), p + Vector3(0.02, 0.03, 0.06),
			P.SAND[5] if i % 2 else P.RUST[5])
	for i in 4:
		var a := Rng.hash01(s, i, 12) * TAU
		var run := lip * (1.3 + Rng.hash01(s, i, 13) * 0.9)
		var d := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-d.z, 0.0, d.x) * 0.035
		k.fleck(d * (lip * 0.95) + Vector3(0, 0.015, 0), d * run + side + Vector3(0, 0.015, 0),
			d * run - side + Vector3(0, 0.015, 0), GroundColors.glow(P.EMBER[2], 0.6))


## FOUND: a flanged pipe, bolted, still breathing heat. Variant 3 is the same
## pipe standing lower and gone over on its flange, so a frame of these is two
## pipes and not one stamped twice.
static func _vent_pipe(k: Kit, v: int) -> void:
	var tall := v % 4 == 1
	var y1 := 0.5 if tall else 0.33
	var lean := 0.0 if tall else 0.055
	k.stone(0, -0.08, 0, 0.55, 0.16, 11011 + v, P.STONE[0], 8, 0.0, P.STONE[1])
	k.found.push(Transform3D(Basis(Vector3.FORWARD, lean), Vector3.ZERO))
	k.found.prism(0, 0.0, 0, 0.22, y1, 0.22, 12, P.PLATE[2])
	# The top flange is a RING, not a lid. A solid cap put a pale disc over the
	# whole mouth, and what the camera then read was a grey drum with a grey lid —
	# a can, which is the one shape docs/LOOK.md forbids outright.
	k.found.prism(0, y1, 0, 0.3, y1 + 0.05, 0.3, 12, P.PLATE[3], P.PLATE[3])
	k.found.prism(0, y1, 0, 0.215, y1 + 0.06, 0.215, 12, P.PLATE[1], P.PLATE[1])
	k.hoop(Vector3(0, y1 + 0.06, 0), 0.265, 12, 0.03, P.PLATE[4])
	k.found.prism(0, 0.0, 0, 0.3, 0.06, 0.3, 12, P.PLATE[1], P.PLATE[2])
	for i in 8:
		var a := float(i) / 8.0 * TAU + PI / 8.0
		k.found.prism(cos(a) * 0.272, y1 + 0.05, sin(a) * 0.272, 0.02, y1 + 0.09, 0.02, 6, P.PLATE[5])
	k.found.quad(Vector3(-0.15, 0.08, 0.221), Vector3(0.15, 0.08, 0.221),
		Vector3(0.15, y1 - 0.08, 0.221), Vector3(-0.15, y1 - 0.08, 0.221), P.RUST[2])
	k.found.pop()
	# The lip is gone on one side: the pipe has burnt through and split, so it is
	# never a clean can standing in a field. Clinker has grown out of the split.
	var split := Rng.hash01(11011 + v, 2) * TAU
	for i in 3:
		var a := split + (i - 1) * 0.42
		var rr := 0.30 + Rng.hash01(11011 + v, i, 3) * 0.05
		k.stone(cos(a) * rr, y1 + 0.02 + Rng.hash01(11011 + v, i, 4) * 0.05, sin(a) * rr,
			0.09, 0.09 + Rng.hash01(11011 + v, i, 5) * 0.07, 11031 + v * 7 + i,
			P.INK[1], 5, 0.0, P.ASH[0])
	# The heat inside is not the machine's: it is drawn by hand, and it glows —
	# a shallow bore in three steps, not a bright disc filling the mouth. The
	# steps sit high because a deep bore seen from this camera shows only its own
	# dark wall, and then nothing tells the player the thing is alight at all.
	var mouth := y1 + 0.06
	k.made.prism(0, mouth, 0, 0.205, mouth - 0.10, 0.17, 11, P.INK[0], P.EMBER[0])
	k.made.prism(0, mouth - 0.10, 0, 0.17, mouth - 0.13, 0.13, 10,
		P.EMBER[1], GroundColors.glow(P.EMBER[3], 0.7))
	k.made.prism(0, mouth - 0.13, 0, 0.13, mouth - 0.15, 0.07, 9,
		GroundColors.glow(P.EMBER[4], 0.9), GroundColors.glow(P.EMBER[4], 1.0))
	k.made.prism(0, mouth - 0.15, 0, 0.07, mouth - 0.17, 0.035, 8,
		GroundColors.glow(P.EMBER[5], 0.75), GroundColors.glow(P.EMBER[5], 0.85))
	# What is getting out through the split, on the shell.
	for i in 3:
		var a := split + (i - 1) * 0.5
		var y := y1 * (0.30 + Rng.hash01(11011 + v, i, 6) * 0.45)
		var p := Vector3(cos(a) * 0.235, y, sin(a) * 0.235)
		k.fleck(p, p + Vector3(0.0, 0.09, 0.0), p + Vector3(cos(a) * 0.05, 0.03, sin(a) * 0.05),
			GroundColors.glow(P.EMBER[2], 0.6))
