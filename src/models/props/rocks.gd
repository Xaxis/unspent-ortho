extends RefCounted
## Stone: boulders, ore nodes, standing stones, clints, cairns, mussel rock and
## peat banks. The rock takes the country's geology: slate on the coast, mossy
## in the wet, snow-capped in the cold, pale limestone on the bones, basalt in
## the burning. Ore nodes show their ore as bright pieces facing the camera.

const Craft := preload("res://src/models/props/craft.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: MeshKit, kind: int, v: int, c: int) -> void:
	match kind:
		PropKind.BOULDER: boulder(k, v, c)
		PropKind.STONE_ORE: ore(k, v, c, P.STONE[3], [P.LINEN[4], P.LINEN[5], P.STONE[4]], false)
		PropKind.IRON_ORE: ore(k, v, c, P.SLATE[2], [P.RUST[3], P.RUST[4], P.RUST[2]], false)
		PropKind.COPPER_ORE: ore(k, v, c, P.SLATE[2], [P.SPRUCE[4], P.SPRUCE[5], P.RUST[4]], false)
		PropKind.COAL_ORE: ore(k, v, c, P.STONE[1], [P.INK[1], P.INK[2], P.INK[0]], true)
		PropKind.TIN_ORE: ore(k, v, c, P.STONE[2], [P.ASH[4], P.STONE[5], P.ASH[3]], true)
		PropKind.STANDING_STONE: standing_stone(k, v, c)
		PropKind.CLINTS: clints(k, v, c)
		PropKind.CAIRN: cairn(k, v, c)
		PropKind.MUSSEL_ROCK: mussel_rock(k, v, c)
		PropKind.PEAT_BANK: peat_bank(k, v, c)


## Rock colour of a country, and what grows or lies on top of it.
static func geology(c: int) -> Array[Color]:
	match c:
		Country.MOSS: return [P.SLATE[2], P.SLATE[1], P.MOSS[2]]
		Country.PINEWOOD: return [P.SLATE[2].lerp(P.SPRUCE[2], 0.3), P.SLATE[1], P.MOSS[2].lerp(P.SPRUCE[3], 0.4)]
		Country.SNOWFIELD: return [P.SLATE[3].lerp(P.RIME[3], 0.3), P.SLATE[2], P.RIME[5]]
		Country.BONELANDS: return [P.LINEN[3], P.LINEN[2], P.LINEN[4]]
		Country.BURNING: return [P.INK[3], P.STONE[0], P.RUST[2]]
	return [P.SLATE[3], P.SLATE[2], P.LINEN[3]]


static func boulder(k: MeshKit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 7000 + v * 37 + c
	var sides := 5 if c == Country.BONELANDS else 7
	match v:
		0:
			k.rock(0, -0.05, 0, 0.5, 0.72, s, g[0], sides)
		1:
			k.rock(-0.12, -0.05, 0.05, 0.42, 0.62, s, g[0], sides)
			k.rock(0.3, -0.05, -0.18, 0.26, 0.38, s + 1, g[1], sides)
		2:
			k.rock(0, -0.05, 0, 0.62, 0.36, s, g[0], sides)
			k.rock(0.2, 0.18, 0.1, 0.22, 0.22, s + 2, g[0], 5)
		_:
			k.rock(0.02, -0.05, 0, 0.36, 1.0, s, g[0], sides)
			k.rock(-0.3, -0.05, 0.22, 0.2, 0.28, s + 3, g[1], 5)
	var top: float = [0.62, 0.52, 0.3, 0.9][v]
	var cap_r: float = [0.34, 0.28, 0.4, 0.2][v]
	match c:
		Country.SNOWFIELD:
			k.rock(0.0, top - 0.14, 0.0, cap_r + 0.04, 0.2, s + 9, g[2], 6)
		Country.MOSS, Country.PINEWOOD:
			k.rock(-0.05, top - 0.16, 0.03, cap_r, 0.2, s + 9, g[2], 6)
		Country.BURNING:
			k.quad(Vector3(0.36, 0.05, 0.1), Vector3(0.44, 0.05, -0.05), Vector3(0.28, top * 0.8, -0.02), Vector3(0.22, top * 0.8, 0.12), g[2])
		Country.BONELANDS:
			# A split along the bedding.
			k.quad(Vector3(-0.4, top * 0.45, 0.2), Vector3(0.4, top * 0.5, 0.3), Vector3(0.4, top * 0.53, 0.29), Vector3(-0.4, top * 0.48, 0.19), g[1])
		_:
			for i in 3:
				var a := float(i) * 2.1 + v
				k.quad(Vector3(cos(a) * 0.18 - 0.05, top - 0.02 + i * 0.01, sin(a) * 0.18),
					Vector3(cos(a) * 0.18 - 0.05, top - 0.02 + i * 0.01, sin(a) * 0.18 + 0.09),
					Vector3(cos(a) * 0.18 + 0.05, top - 0.02 + i * 0.01, sin(a) * 0.18 + 0.09),
					Vector3(cos(a) * 0.18 + 0.05, top - 0.02 + i * 0.01, sin(a) * 0.18), g[2] if i != 1 else P.MOSS[4])


static func ore(k: MeshKit, v: int, c: int, host: Color, bits: Array, sparkle: bool) -> void:
	var g := geology(c)
	var rock := host.lerp(g[0], 0.4)
	var s := 7500 + v * 41 + int(host.r * 100.0)
	k.rock(0, -0.05, 0, 0.46, 0.66, s, rock, 6)
	if v == 1:
		k.rock(0.28, -0.05, 0.22, 0.24, 0.34, s + 1, rock.darkened(0.1), 5)
	# Ore pieces on the faces toward the camera and the light.
	for i in 5:
		var a := -0.6 + i * 0.55 + Craft.j(s, i, 0.2)
		var r := 0.3 + Craft.j(s, 10 + i, 0.06)
		var y := 0.18 + Craft.j(s, 20 + i, 0.14) + (0.12 if i % 2 else 0.0)
		var col: Color = bits[i % bits.size()]
		if sparkle and i % 2 == 0:
			col = PropModels.glint(col)
		k.rock(cos(a) * r, y, sin(a) * r + 0.05, 0.1 + Craft.j(s, 30 + i, 0.03), 0.16, s + 40 + i, col, 5)
	# A seam running across the top.
	var seam: Color = bits[0]
	k.quad(Vector3(-0.22, 0.52, -0.12), Vector3(-0.2, 0.5, 0.1), Vector3(0.2, 0.46, 0.14), Vector3(0.18, 0.49, -0.08), seam)


static func standing_stone(k: MeshKit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 8000 + v * 43 + c
	match v:
		0:
			# Quarried long ago: a leaning slab, lichen on the weather side, grass at the foot.
			k.push(Transform3D(Basis(Vector3.BACK, 0.09) * Basis(Vector3.UP, 0.2), Vector3.ZERO))
			Craft.rough_box(k, 0, -0.05, 0, 0.5, 1.75, 0.3, g[0], g[0].lightened(0.06), s, 0.06)
			k.quad(Vector3(-0.2, 1.1, 0.152), Vector3(0.05, 1.1, 0.152), Vector3(0.05, 1.35, 0.152), Vector3(-0.2, 1.32, 0.152), P.LINEN[3])
			k.quad(Vector3(0.0, 0.5, 0.152), Vector3(0.18, 0.52, 0.152), Vector3(0.18, 0.66, 0.152), Vector3(0.0, 0.64, 0.152), P.MOSS[4])
			k.pop()
		1:
			# Cast, not quarried: a leg with bent bars and a rust run.
			var concrete := P.STONE[3].lerp(g[0], 0.25)
			k.block(0, -0.05, 0, 0.44, 1.6, 0.36, concrete, concrete.lightened(0.08))
			k.block(0, 1.2, 0, 0.46, 0.06, 0.38, concrete.darkened(0.12))
			for i in 3:
				var x := -0.12 + i * 0.12
				var bend := Vector3(0.1 + i * 0.05, 0.25, -0.08 * (i - 1))
				k.strut(Vector3(x, 1.55, 0.05), Vector3(x, 1.72, 0.05), 0.02, 4, P.RUST[2])
				k.strut(Vector3(x, 1.72, 0.05), Vector3(x, 1.72, 0.05) + bend, 0.02, 4, P.RUST[2])
			k.quad(Vector3(0.02, 0.2, 0.181), Vector3(0.09, 0.2, 0.181), Vector3(0.07, 1.5, 0.181), Vector3(0.03, 1.5, 0.181), P.RUST[3])
		_:
			# A cast foot with cut bolts.
			var concrete := P.STONE[3].lerp(g[0], 0.25)
			k.block(0, -0.05, 0, 0.8, 0.55, 0.7, concrete, concrete.lightened(0.08))
			k.block(0, 0.5, 0, 0.6, 0.12, 0.5, concrete.darkened(0.08), concrete)
			for bx: float in [-0.2, 0.2]:
				for bz: float in [-0.16, 0.16]:
					k.prism(bx, 0.62, bz, 0.035, 0.7, 0.035, 6, P.STONE[1], P.STONE[4])
			k.quad(Vector3(-0.1, 0.1, 0.351), Vector3(0.0, 0.1, 0.351), Vector3(-0.02, 0.5, 0.351), Vector3(-0.08, 0.5, 0.351), P.RUST[3])
	if c == Country.SNOWFIELD:
		k.rock(0, [1.62, 1.6, 0.6][v], 0, 0.22, 0.14, s + 5, P.RIME[5], 6)


static func clints(k: MeshKit, v: int, c: int) -> void:
	var stone := P.LINEN[4] if c != Country.BURNING else P.ASH[3]
	var s := 8500 + v * 7
	var blocks := [[-0.35, -0.2, 0.62, 0.5], [0.3, -0.25, 0.5, 0.42], [-0.1, 0.35, 0.8, 0.36], [0.45, 0.28, 0.3, 0.4]]
	for i in blocks.size():
		var b: Array = blocks[i]
		var h := 0.26 + Craft.j(s, i, 0.05)
		Craft.rough_box(k, b[0], -0.05, b[1], b[2], h, b[3], P.LINEN[3], stone if i % 2 == 0 else P.LINEN[5], s + i * 9, 0.025)
		# Drill holes in a row along one edge.
		if (i + v) % 2 == 0:
			for d in 4:
				var x: float = b[0] - b[2] * 0.35 + d * b[2] * 0.22
				k.block(x, h - 0.045, b[1] + b[3] * 0.5 + 0.001, 0.035, 0.035, 0.01, P.LINEN[1])
	if v == 1:
		# A block split by a wedge, the halves apart.
		Craft.rough_box(k, 0.0, 0.2, -0.05, 0.22, 0.14, 0.3, P.LINEN[3], P.LINEN[5], s + 50, 0.02)
		k.block(0.0, 0.33, -0.05, 0.04, 0.05, 0.1, P.STONE[1])


static func cairn(k: MeshKit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 8700 + v * 3 + c
	var y := -0.05
	var r := 0.42
	for i in 5:
		var n := maxi(1, 4 - i)
		for j in n:
			var a := float(j) / n * TAU + i * 0.7
			var rr := r * (0.55 if n > 1 else 0.0)
			k.rock(cos(a) * rr, y, sin(a) * rr, r * 0.55, r * 0.7, s + i * 10 + j, g[0] if (i + j) % 2 == 0 else g[1], 6)
		y += r * 0.5
		r *= 0.8
	if v == 1:
		# Someone set a lens from a machine on top, looking out.
		var top := Vector3(0.0, y + 0.18, 0.0)
		k.strut(Vector3(0, y - 0.05, 0), top, 0.025, 4, P.STONE[1])
		var ring_c := top + Vector3(0, 0.1, 0.02)
		Craft.ring(k, ring_c, 0.11, 8, 0.02, P.PLATE[3], Vector3.BACK)
		k.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), ring_c + Vector3(0, 0, 0.012)))
		k.prism(0, 0, 0, 0.09, 0.01, 0.09, 8, P.COLD[1], P.COLD[2])
		k.pop()
		k.block(ring_c.x + 0.03, ring_c.y + 0.03, ring_c.z + 0.03, 0.03, 0.03, 0.01, PropModels.glint(P.COLD[3]))


static func mussel_rock(k: MeshKit, v: int, _c: int) -> void:
	var s := 8900 + v * 11
	k.rock(0, -0.08, 0, 0.52, 0.34, s, P.SLATE[1], 7)
	if v == 1:
		k.rock(0.4, -0.08, 0.25, 0.3, 0.24, s + 1, P.SLATE[1], 6)
	for i in 14:
		var a := float(i) * 2.39996
		var r := 0.2 + fmod(float(i) * 0.137, 0.26)
		var y := 0.16 - r * 0.25
		var col := P.INK[2] if i % 3 else P.BRINE[1]
		k.push(Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r, y, sin(a) * r)))
		k.prism(0, 0, 0, 0.045, 0.06, 0.02, 4, col, P.BRINE[2] if i % 4 == 0 else col)
		k.pop()
	for i in 8:
		var a := float(i) * 1.71 + 0.2
		k.block(cos(a) * 0.3, 0.16, sin(a) * 0.3, 0.03, 0.02, 0.03, P.LINEN[4])
	# Weed fringe at the waterline.
	for i in 9:
		var a := float(i) / 9.0 * TAU
		var base := Vector3(cos(a) * 0.5, -0.02, sin(a) * 0.5)
		Craft.blade(k, base, base + Vector3(cos(a) * 0.14, 0.08, sin(a) * 0.14), 0.08, a + 1.57, PropModels.sway(P.MOSS[1] if i % 2 else P.EARTH[2], 0.6))


static func peat_bank(k: MeshKit, v: int, _c: int) -> void:
	var s := 9100 + v * 5
	# A cut bank: two steps, dark faces with spade marks, heather on top.
	Craft.rough_box(k, 0.0, -0.05, -0.2, 1.3, 0.5, 0.6, P.EARTH[1], P.MOSS[1], s, 0.03)
	Craft.rough_box(k, 0.05, -0.05, 0.25, 1.1, 0.26, 0.35, P.EARTH[0], P.EARTH[1], s + 1, 0.03)
	for i in 7:
		var x := -0.55 + i * 0.18
		k.quad(Vector3(x, 0.05, 0.101), Vector3(x + 0.03, 0.05, 0.101), Vector3(x + 0.03, 0.42, 0.101), Vector3(x, 0.42, 0.101), P.EARTH[0])
	for i in 5:
		Craft.blob(k, -0.5 + i * 0.26, 0.42, -0.25 + Craft.j(s, i, 0.1), 0.16, 0.14, s + 10 + i, PropModels.sway(P.BLOOM[1] if i % 2 else P.MOSS[2], 0.2), 5)
	# Cut peats stacked to dry.
	for i in 3:
		Craft.rough_box(k, 0.85, -0.02 + i * 0.1, 0.2 + (i % 2) * 0.04, 0.24, 0.09, 0.14, P.EARTH[1], P.EARTH[2], s + 20 + i, 0.015)
	if v == 1:
		# A pipe through the face, an ochre stain fanning from it.
		k.strut(Vector3(-0.2, 0.3, -0.3), Vector3(-0.2, 0.3, 0.2), 0.07, 8, P.PLATE[2])
		k.prism(-0.2, 0.3, 0.2, 0.0, 0.3, 0.0, 8, P.INK[1])
		k.tri(Vector3(-0.2, 0.25, 0.12), Vector3(-0.42, -0.02, 0.12), Vector3(0.02, -0.02, 0.12), P.RUST[4])
		k.tri(Vector3(-0.2, 0.2, 0.121), Vector3(-0.32, 0.0, 0.121), Vector3(-0.08, 0.0, 0.121), P.RUST[3])
		k.quad(Vector3(-0.5, 0.0, 0.2), Vector3(-0.5, 0.0, 0.7), Vector3(0.1, 0.0, 0.7), Vector3(0.1, 0.0, 0.2), P.RUST[3])
