extends RefCounted
## What washes up and what is left: driftwood, wrack, bones, wrecks of machines,
## tips of scrap, and vents. Wreck plate and pipe flanges are FOUND: exact,
## symmetric, machine plate. Everything else lies where it fell.

const Craft := preload("res://src/models/props/craft.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: MeshKit, kind: int, v: int, c: int) -> void:
	match kind:
		PropKind.DRIFTWOOD: driftwood(k, v, c)
		PropKind.WRACK: wrack(k, v, c)
		PropKind.BONES: bones(k, v, c)
		PropKind.WRECK: wreck(k, v, c)
		PropKind.TIP: tip(k, v, c)
		PropKind.VENT: vent(k, v, c)


static func driftwood(k: MeshKit, v: int, _c: int) -> void:
	var s := 10000 + v * 13
	var woods: Array[Color] = [P.LINEN[3], P.ASH[3], P.LINEN[2]]
	if v == 2:
		# One big trunk with its root plate.
		k.strut(Vector3(-0.8, 0.1, 0.1), Vector3(0.6, 0.08, -0.15), 0.11, 6, woods[0])
		for i in 6:
			var a := float(i) / 6.0 * TAU
			k.strut(Vector3(-0.85, 0.12, 0.1), Vector3(-0.95, 0.12 + sin(a) * 0.3, 0.1 + cos(a) * 0.3), 0.035, 3, woods[1])
		k.strut(Vector3(0.1, 0.12, -0.05), Vector3(0.35, 0.35, 0.15), 0.03, 3, woods[2])
		return
	for i in 4:
		var a := Craft.j(s, i, 1.5) + i * 0.8
		var l := 0.45 + Craft.j(s, 10 + i, 0.15)
		var y := 0.06 + i * 0.05
		var cx := Craft.j(s, 20 + i, 0.2)
		var cz := Craft.j(s, 30 + i, 0.2)
		k.strut(Vector3(cx - cos(a) * l, y, cz - sin(a) * l), Vector3(cx + cos(a) * l, y + 0.03, cz + sin(a) * l), 0.055 + i * 0.008, 5, woods[i % 3])
	if v == 1:
		# A float and a coil of cable among the wood.
		k.prism(0.35, 0.0, 0.3, 0.13, 0.22, 0.13, 7, P.RUST[4], P.RUST[5])
		k.prism(0.35, 0.22, 0.3, 0.13, 0.28, 0.06, 7, P.RUST[4])
		Craft.ring(k, Vector3(-0.35, 0.05, 0.3), 0.16, 8, 0.02, P.INK[2])
		Craft.ring(k, Vector3(-0.33, 0.08, 0.31), 0.13, 8, 0.02, P.INK[3])


static func wrack(k: MeshKit, v: int, _c: int) -> void:
	var s := 10200 + v * 7
	var cols: Array[Color] = [P.EARTH[1], P.SPRUCE[1], P.MOSS[1], P.EARTH[2]]
	# Strands of kelp lying in a line along the tide mark.
	for i in 9:
		var x := -0.8 + i * 0.2 + Craft.j(s, i, 0.05)
		var z := Craft.j(s, 10 + i, 0.12)
		var a := Craft.j(s, 20 + i, 1.2)
		var l := 0.18 + Craft.j(s, 30 + i, 0.08)
		var w := 0.06
		var d := Vector3(cos(a), 0, sin(a)) * l
		var side := Vector3(-sin(a), 0, cos(a)) * w
		var y := 0.02 + i * 0.002
		k.quad(Vector3(x, y, z) - d - side, Vector3(x, y, z) - d + side, Vector3(x, y, z) + d + side * 0.5, Vector3(x, y, z) + d - side * 0.5, cols[i % 4])
	for i in 4:
		k.block(-0.6 + i * 0.4, 0.02, 0.1 + Craft.j(s, 40 + i, 0.1), 0.06, 0.04, 0.05, P.EARTH[2])
	if v == 1:
		Craft.cable(k, Vector3(-0.9, 0.04, -0.2), Vector3(0.9, 0.04, 0.25), 0.0, 5, 0.008, P.LINEN[5])
		k.prism(0.55, 0.0, 0.18, 0.07, 0.1, 0.07, 6, P.RUST[4], P.RUST[5])


static func bones(k: MeshKit, v: int, c: int) -> void:
	var bone := P.LINEN[4] if c != Country.BURNING else P.ASH[3]
	var old := P.LINEN[3]
	var s := 10400 + v * 3
	match v:
		0:
			# A ribcage half sunk, the spine along the ground.
			k.strut(Vector3(-0.6, 0.05, 0), Vector3(0.55, 0.07, 0.05), 0.035, 4, old)
			for i in 5:
				var x := -0.35 + i * 0.18
				var h := 0.32 - absf(i - 2) * 0.05
				for side: float in [-1.0, 1.0]:
					k.strut(Vector3(x, 0.07, 0.02), Vector3(x + 0.04, h, side * 0.18), 0.022, 3, bone)
					k.strut(Vector3(x + 0.04, h, side * 0.18), Vector3(x + 0.08, 0.02, side * 0.3), 0.02, 3, bone)
		1:
			# A long skull and a leg bone.
			Craft.rough_box(k, 0.0, -0.02, 0.0, 0.42, 0.16, 0.2, bone, P.LINEN[5], s, 0.02)
			k.block(0.28, -0.02, 0.0, 0.2, 0.1, 0.13, bone, P.LINEN[5])
			k.block(-0.08, 0.1, 0.101, 0.07, 0.05, 0.01, P.INK[1])
			k.block(-0.08, 0.1, -0.101, 0.07, 0.05, 0.01, P.INK[1])
			k.strut(Vector3(-0.4, 0.04, 0.35), Vector3(0.4, 0.04, 0.45), 0.035, 4, bone)
			k.rock(-0.42, 0.0, 0.35, 0.06, 0.08, s + 1, P.LINEN[5], 5)
			k.rock(0.42, 0.0, 0.45, 0.06, 0.08, s + 2, P.LINEN[5], 5)
		_:
			for i in 5:
				var a := Craft.j(s, i, 1.6)
				var cx := Craft.j(s, 10 + i, 0.4)
				var cz := Craft.j(s, 20 + i, 0.4)
				var d := Vector3(cos(a), 0, sin(a)) * (0.15 + Craft.j(s, 30 + i, 0.05))
				k.strut(Vector3(cx, 0.03, cz) - d, Vector3(cx, 0.03, cz) + d, 0.025, 3, bone if i % 2 else old)
			k.rock(0.1, 0.0, -0.1, 0.1, 0.1, s + 3, P.LINEN[5], 5)


## FOUND: a machine's hull on its side, ribbed, banded violet and rust, a crane
## arm still up. Exact: straight members, centred features, rivet rows.
static func wreck(k: MeshKit, v: int, _c: int) -> void:
	var body := P.PLATE[3]
	var dark := P.PLATE[1]
	var lit := P.PLATE[4]
	if v == 0:
		k.block(0, -0.1, 0, 2.6, 0.9, 1.0, body, lit)
		k.block(0, 0.8, 0, 2.2, 0.16, 0.8, dark, body)
		for i in 7:
			var x := -1.2 + i * 0.4
			k.block(x, -0.1, 0, 0.08, 1.0, 1.04, dark, body)
		for i in 3:
			k.block(-0.8 + i * 0.8, 0.1, 0.51, 0.3, 0.5, 0.01, P.RUST[2])
			k.block(-0.8 + i * 0.8, 0.12, 0.515, 0.12, 0.3, 0.01, P.RUST[3])
		for i in 13:
			k.block(-1.2 + i * 0.2, 0.62, 0.505, 0.03, 0.03, 0.01, P.PLATE[5])
		# The crane arm, a straight lattice, broken off square.
		k.strut(Vector3(0.8, 0.9, 0), Vector3(1.3, 2.1, 0), 0.05, 4, body)
		k.strut(Vector3(0.95, 0.9, 0.12), Vector3(1.45, 2.0, 0.12), 0.03, 4, dark)
		k.strut(Vector3(0.95, 0.9, -0.12), Vector3(1.45, 2.0, -0.12), 0.03, 4, dark)
		for i in 4:
			var t := 0.2 + i * 0.2
			k.strut(Vector3(0.8, 0.9, 0).lerp(Vector3(1.3, 2.1, 0), t), Vector3(0.95, 0.9, 0.12).lerp(Vector3(1.45, 2.0, 0.12), t + 0.1), 0.015, 3, dark)
		k.block(1.3, 2.05, 0, 0.14, 0.12, 0.14, dark, lit)
		k.rock(-1.2, -0.12, 0.45, 0.55, 0.3, 10601, P.SAND[4], 6)
	else:
		# A cab half sunk, its visor slit dark: the light went out.
		k.push(Transform3D(Basis(Vector3.BACK, 0.16), Vector3(0, -0.2, 0)))
		k.block(0, 0, 0, 1.4, 1.2, 1.2, body, lit)
		k.block(0, 0.75, 0.605, 1.0, 0.14, 0.01, P.COLD[0])
		k.block(0, 0.77, 0.61, 0.9, 0.03, 0.01, P.COLD[1])
		k.block(0, 1.2, 0, 1.1, 0.12, 0.9, dark, body)
		for side: float in [-0.71, 0.71]:
			for i in 5:
				k.block(side, 0.2 + i * 0.2, 0.55, 0.01, 0.03, 0.03, P.PLATE[5])
		k.block(-0.3, 0.1, 0.605, 0.4, 0.4, 0.01, P.RUST[2])
		k.pop()
		for i in 3:
			k.block(-0.9 + i * 0.9, -0.05, -0.9, 0.12, 0.3, 0.9, dark, body)
		k.rock(0.6, -0.1, 0.6, 0.7, 0.35, 10602, P.SAND[4], 6)


static func tip(k: MeshKit, v: int, _c: int) -> void:
	var s := 10800 + v * 17
	# A heap: soil and slag under, scrap on top.
	k.rock(0, -0.1, 0, 1.4, 0.7, s, P.STONE[1], 8)
	k.rock(0.4, 0.2, -0.3, 0.8, 0.5, s + 1, P.EARTH[1], 7)
	for i in 9:
		var a := float(i) * 2.39996 + v
		var r := 0.3 + fmod(float(i) * 0.19, 0.8)
		var y := 0.55 - r * 0.35
		var col: Color = [P.PLATE[2], P.RUST[2], P.STONE[2], P.RUST[3], P.PLATE[3], P.STONE[1]][i % 6]
		k.push(Transform3D(Basis(Vector3(cos(a), 0.4, sin(a)).normalized(), 0.6 + i * 0.3), Vector3(cos(a) * r, y, sin(a) * r)))
		k.block(0, 0, 0, 0.35 + fmod(i * 0.13, 0.25), 0.06 + (i % 3) * 0.05, 0.22 + fmod(i * 0.09, 0.2), col)
		k.pop()
	# A wheel, and cable in loops.
	k.push(Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3(-0.5, 0.45, 0.45)))
	k.prism(0, -0.05, 0, 0.26, 0.05, 0.26, 10, P.INK[2], P.STONE[2])
	k.prism(0, 0.05, 0, 0.06, 0.08, 0.06, 6, P.STONE[3])
	k.pop()
	Craft.cable(k, Vector3(-0.9, 0.1, -0.4), Vector3(0.3, 0.7, 0.2), -0.1, 5, 0.025, P.INK[2])
	Craft.cable(k, Vector3(0.3, 0.7, 0.2), Vector3(1.1, 0.05, 0.6), 0.1, 4, 0.025, P.INK[2])
	if v == 1:
		k.block(0.2, 0.55, 0.1, 0.9, 0.05, 0.6, P.PLATE[3], P.PLATE[4])
		k.block(0.2, 0.61, 0.1, 0.5, 0.01, 0.3, P.RUST[2])


static func vent(k: MeshKit, v: int, _c: int) -> void:
	if v == 0:
		# A natural vent: a cone of clinker, a glowing mouth, a sulphur crust.
		Craft.blob(k, 0, -0.05, 0, 0.62, 0.45, 11001, P.STONE[0], 8, 0.4)
		Craft.blob(k, 0.1, -0.05, 0.2, 0.4, 0.25, 11002, P.INK[2], 7, 0.4)
		k.prism(0, 0.3, 0, 0.2, 0.42, 0.14, 8, P.INK[1], PropModels.glow(P.EMBER[3], 1.3))
		k.prism(0, 0.42, 0, 0.09, 0.425, 0.09, 8, P.EMBER[4], PropModels.glow(P.EMBER[5], 1.5))
		for i in 6:
			var a := float(i) * 1.05
			k.block(cos(a) * 0.26, 0.36, sin(a) * 0.26, 0.08, 0.04, 0.08, P.RUST[5] if i % 2 else P.SAND[5])
		for i in 3:
			var a := float(i) * 2.1 + 0.4
			k.block(cos(a) * 0.5, 0.0, sin(a) * 0.5, 0.05, 0.03, 0.05, PropModels.glow(P.EMBER[3], 0.7))
	else:
		# FOUND: a flanged pipe, bolted, still breathing heat.
		k.block(0, -0.05, 0, 0.9, 0.12, 0.9, P.STONE[0], P.INK[3])
		k.prism(0, 0.0, 0, 0.22, 0.5, 0.22, 12, P.PLATE[2])
		k.prism(0, 0.5, 0, 0.3, 0.58, 0.3, 12, P.PLATE[3], P.PLATE[4])
		k.prism(0, 0.58, 0, 0.17, 0.585, 0.17, 12, P.INK[0], PropModels.glow(P.EMBER[3], 0.9))
		for i in 8:
			var a := float(i) / 8.0 * TAU + PI / 8.0
			k.prism(cos(a) * 0.255, 0.58, sin(a) * 0.255, 0.02, 0.62, 0.02, 6, P.PLATE[5])
		k.block(0, 0.08, 0.225, 0.3, 0.35, 0.01, P.RUST[2])
		k.prism(0, 0.0, 0, 0.3, 0.06, 0.3, 12, P.PLATE[1])
