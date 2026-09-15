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
		k.hoop(Vector3(-0.36, 0.05, 0.3), 0.16, 10, 0.02, P.INK[2])
		k.hoop(Vector3(-0.34, 0.08, 0.31), 0.13, 10, 0.02, P.INK[3])


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


## FOUND: a machine's hull on its side, ribbed, banded violet and rust, its
## visor slit dark, a crane arm still up. Exact: straight members, rivet rows.
static func wreck(k: Kit, v: int, c: int) -> void:
	var body := P.PLATE[3]
	var dark := P.PLATE[1]
	var lit := P.PLATE[4]
	var drift := P.SAND[4] if c != Country.SNOWFIELD else P.RIME[5]
	if c == Country.BURNING:
		drift = P.ASH[2]
	if v % 2 == 0:
		k.chamfer(0.0, -0.15, 0.0, 2.7, 0.95, 1.1, 0.22, body, lit)
		k.chamfer(0.0, 0.8, 0.0, 2.2, 0.16, 0.8, 0.1, dark, body)
		for i in 7:
			var x := -1.2 + i * 0.4
			k.chamfer(x, -0.14, 0.0, 0.08, 1.0, 1.14, 0.02, dark, body)
		for i in 3:
			k.found.quad(Vector3(-0.95 + i * 0.8, 0.1, 0.556), Vector3(-0.65 + i * 0.8, 0.1, 0.556), Vector3(-0.65 + i * 0.8, 0.6, 0.556), Vector3(-0.95 + i * 0.8, 0.6, 0.556), P.RUST[2])
			k.found.quad(Vector3(-0.86 + i * 0.8, 0.12, 0.56), Vector3(-0.74 + i * 0.8, 0.12, 0.56), Vector3(-0.74 + i * 0.8, 0.42, 0.56), Vector3(-0.86 + i * 0.8, 0.42, 0.56), P.RUST[3])
		for i in 13:
			var x := -1.2 + i * 0.2
			k.found.quad(Vector3(x - 0.015, 0.64, 0.557), Vector3(x + 0.015, 0.64, 0.557), Vector3(x + 0.015, 0.67, 0.557), Vector3(x - 0.015, 0.67, 0.557), P.PLATE[5])
		# The visor slit, dark: the light went out.
		k.found.quad(Vector3(1.36, 0.35, 0.3), Vector3(1.36, 0.35, -0.3), Vector3(1.36, 0.45, -0.3), Vector3(1.36, 0.45, 0.3), P.COLD[0])
		# The crane arm, a straight lattice, broken off square.
		k.rod(Vector3(0.8, 0.95, 0), Vector3(1.3, 2.15, 0), 0.05, 4, body)
		k.rod(Vector3(0.95, 0.95, 0.12), Vector3(1.45, 2.05, 0.12), 0.03, 4, dark)
		k.rod(Vector3(0.95, 0.95, -0.12), Vector3(1.45, 2.05, -0.12), 0.03, 4, dark)
		for i in 4:
			var t := 0.2 + i * 0.2
			k.rod(Vector3(0.8, 0.95, 0).lerp(Vector3(1.3, 2.15, 0), t), Vector3(0.95, 0.95, 0.12).lerp(Vector3(1.45, 2.05, 0.12), t + 0.1), 0.015, 4, dark)
		k.chamfer(1.3, 2.05, 0.0, 0.16, 0.12, 0.16, 0.04, dark, lit)
		k.stone(-1.25, -0.14, 0.5, 0.6, 0.3, 10601, drift, 7, 0.0)
		k.stone(0.4, -0.14, -0.62, 0.5, 0.24, 10603, drift, 7, 0.0)
	else:
		# A cab half sunk and tipped, its visor slit dark.
		k.found.push(Transform3D(Basis(Vector3.BACK, 0.18), Vector3(0, -0.25, 0)))
		k.chamfer(0.0, 0.0, 0.0, 1.4, 1.2, 1.2, 0.2, body, lit)
		k.found.quad(Vector3(0.71, 0.72, 0.4), Vector3(0.71, 0.72, -0.4), Vector3(0.71, 0.86, -0.4), Vector3(0.71, 0.86, 0.4), P.COLD[0])
		k.found.quad(Vector3(0.715, 0.76, 0.34), Vector3(0.715, 0.76, -0.34), Vector3(0.715, 0.79, -0.34), Vector3(0.715, 0.79, 0.34), P.COLD[1])
		k.chamfer(0.0, 1.2, 0.0, 1.1, 0.12, 0.9, 0.08, dark, body)
		for i in 5:
			k.found.quad(Vector3(0.712, 0.2 + i * 0.18, -0.56), Vector3(0.712, 0.2 + i * 0.18, -0.53), Vector3(0.712, 0.23 + i * 0.18, -0.53), Vector3(0.712, 0.23 + i * 0.18, -0.56), P.PLATE[5])
		k.found.quad(Vector3(-0.3, 0.1, 0.61), Vector3(0.1, 0.1, 0.61), Vector3(0.1, 0.5, 0.61), Vector3(-0.3, 0.5, 0.61), P.RUST[2])
		k.found.pop()
		for i in 3:
			k.chamfer(-0.9 + i * 0.9, -0.08, -0.9, 0.12, 0.3, 0.9, 0.03, dark, body)
		k.stone(0.6, -0.14, 0.6, 0.72, 0.36, 10602, drift, 7, 0.0)


static func tip(k: Kit, v: int, _c: int) -> void:
	var s := 10800 + v * 17
	# A heap: soil and slag under (MADE), scrap on top (FOUND).
	k.stone(0, -0.12, 0, 1.4, 0.7, s, P.STONE[1], 9, 0.05, P.EARTH[1])
	k.stone(0.4, 0.18, -0.3, 0.8, 0.5, s + 1, P.EARTH[1], 7, 0.0, P.EARTH[2])
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
		# A vent in the ground: a clinker cone, a glowing mouth, a sulphur crust.
		k.stone(0, -0.06, 0, 0.65, 0.45, 11001, P.STONE[0], 8, 0.0, P.INK[2])
		k.stone(0.14, -0.06, 0.22, 0.4, 0.26, 11002, P.INK[2], 7, 0.2)
		k.made.prism(0, 0.32, 0, 0.2, 0.44, 0.14, 8, P.INK[1], GroundColors.glow(P.EMBER[3], 1.3))
		k.made.prism(0, 0.44, 0, 0.1, 0.446, 0.1, 8, P.EMBER[4], GroundColors.glow(P.EMBER[5], 1.6))
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
		k.stone(0, -0.08, 0, 0.55, 0.16, 11011, P.STONE[0], 8, 0.0, P.INK[3])
		k.found.prism(0, 0.0, 0, 0.22, 0.5, 0.22, 12, P.PLATE[2])
		k.found.prism(0, 0.5, 0, 0.3, 0.58, 0.3, 12, P.PLATE[3], P.PLATE[4])
		k.found.prism(0, 0.0, 0, 0.3, 0.06, 0.3, 12, P.PLATE[1], P.PLATE[2])
		for i in 8:
			var a := float(i) / 8.0 * TAU + PI / 8.0
			k.found.prism(cos(a) * 0.255, 0.58, sin(a) * 0.255, 0.02, 0.62, 0.02, 6, P.PLATE[5])
		k.found.quad(Vector3(-0.15, 0.08, 0.221), Vector3(0.15, 0.08, 0.221), Vector3(0.15, 0.42, 0.221), Vector3(-0.15, 0.42, 0.221), P.RUST[2])
		# The heat inside is not the machine's: it is drawn by hand, and it glows.
		k.made.prism(0, 0.57, 0, 0.17, 0.585, 0.17, 12, P.INK[0], GroundColors.glow(P.EMBER[3], 1.0))
