extends RefCounted
## What washes up and what is left: driftwood, wrack, bones, wrecks of
## machines, tips of scrap, and vents. The wreck's hull, the scrap plate, the
## float and cable, the flanged pipe are FOUND: exact, symmetric, clean. The
## wood, the weed, the bones and the ground they lie in are MADE.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.COUNTRY_STYLE[c])
	match kind:
		PropKind.DRIFTWOOD: driftwood(k, v, c)
		PropKind.WRACK: wrack(k, v, c)
		PropKind.BONES: bones(k, v, c)
		PropKind.WRECK: wreck(k, v, c)
		PropKind.TIP: tip(k, v, c)
		PropKind.VENT: vent(k, v, c)


static func driftwood(k: Kit, v: int, _c: int) -> void:
	var s := 10000 + v * 13
	var woods: Array[Color] = [P.LINEN[3], P.ASH[3], P.LINEN[2]]
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
		# as a hole in the beach (docs/ART.md section 6).
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
	var bone := P.LINEN[4] if c != Country.BURNING else P.ASH[3]
	var old := P.LINEN[3] if c != Country.BURNING else P.ASH[2]
	var s := 10400 + v * 3
	k.hand(Ink.CROSS if c == Country.BONELANDS else Ink.HAND)
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
	var drift := P.SAND[4] if c != Country.SNOWFIELD else P.RIME[5]
	if c == Country.BURNING:
		drift = P.ASH[2]
	elif c == Country.MOSS or c == Country.PINEWOOD:
		drift = P.EARTH[2]
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
					k.found.quad(Vector3(x0 + 0.06, 1.12, -0.3), Vector3(x1, 1.18, -0.44), Vector3(x1, 1.18, 0.2), Vector3(x0 + 0.1, 1.1, 0.1), body)
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
		k.found.quad(Vector3(LEN * 0.5 + 0.004, 0.62, -0.34), Vector3(LEN * 0.5 + 0.004, 0.62, 0.34), Vector3(LEN * 0.5 + 0.004, 0.74, 0.34), Vector3(LEN * 0.5 + 0.004, 0.74, -0.34), P.COLD[0])
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


static func tip(k: Kit, v: int, _c: int) -> void:
	var s := 10800 + v * 17
	# A heap: soil and slag under (MADE), scrap on top (FOUND).
	k.clump(0, -0.12, 0, 1.3, 0.72, s, P.STONE[1], 10)
	k.clump(0.45, 0.1, -0.3, 0.75, 0.55, s + 1, P.EARTH[1], 8)
	k.clump(-0.7, -0.1, 0.5, 0.5, 0.3, s + 2, P.STONE[2], 7)
	for i in 9:
		var a := float(i) * 2.39996 + v
		var r := 0.3 + fmod(float(i) * 0.19, 0.8)
		var y := 0.55 - r * 0.35
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
		k.chamfer(0.2, 0.55, 0.1, 0.9, 0.05, 0.6, 0.06, P.PLATE[3], P.PLATE[4])


static func vent(k: Kit, v: int, _c: int) -> void:
	if v % 2 == 0:
		# A vent in the ground: a rusted clinker cone (never a black hole seen from
		# above), a wide glowing mouth, a sulphur crust round its lip.
		k.stone(0, -0.06, 0, 0.65, 0.42, 11001, P.STONE[1], 8, 0.0, P.RUST[1])
		k.stone(0.14, -0.06, 0.22, 0.4, 0.26, 11002, P.ASH[2], 7, 0.2)
		k.made.prism(0, 0.3, 0, 0.26, 0.4, 0.2, 8, P.RUST[2], GroundColors.glow(P.EMBER[3], 1.3))
		k.made.prism(0, 0.4, 0, 0.17, 0.41, 0.17, 8, GroundColors.glow(P.EMBER[4], 1.4), GroundColors.glow(P.EMBER[5], 1.6))
		for i in 7:
			var a := float(i) * 0.9
			var p := Vector3(cos(a) * 0.27, 0.37, sin(a) * 0.27)
			k.fleck(p, p + Vector3(0.07, 0.0, 0.02), p + Vector3(0.02, 0.03, 0.06), P.SAND[5] if i % 2 else P.RUST[5])
		for i in 3:
			var a := float(i) * 2.1 + 0.4
			var p := Vector3(cos(a) * 0.52, 0.01, sin(a) * 0.52)
			k.fleck(p, p + Vector3(0.05, 0.0, 0.02), p + Vector3(0.01, 0.02, 0.05), GroundColors.glow(P.EMBER[3], 0.8))
	else:
		# FOUND: a flanged pipe, bolted, still breathing heat.
		k.stone(0, -0.08, 0, 0.55, 0.16, 11011, P.STONE[0], 8, 0.0, P.STONE[1])
		k.found.prism(0, 0.0, 0, 0.22, 0.5, 0.22, 12, P.PLATE[2])
		k.found.prism(0, 0.5, 0, 0.3, 0.58, 0.3, 12, P.PLATE[3], P.PLATE[4])
		k.found.prism(0, 0.0, 0, 0.3, 0.06, 0.3, 12, P.PLATE[1], P.PLATE[2])
		for i in 8:
			var a := float(i) / 8.0 * TAU + PI / 8.0
			k.found.prism(cos(a) * 0.255, 0.58, sin(a) * 0.255, 0.02, 0.62, 0.02, 6, P.PLATE[5])
		k.found.quad(Vector3(-0.15, 0.08, 0.221), Vector3(0.15, 0.08, 0.221), Vector3(0.15, 0.42, 0.221), Vector3(-0.15, 0.42, 0.221), P.RUST[2])
		# The heat inside is not the machine's: it is drawn by hand, and it glows.
		k.made.prism(0, 0.57, 0, 0.17, 0.585, 0.17, 12, P.INK[0], GroundColors.glow(P.EMBER[3], 1.0))
