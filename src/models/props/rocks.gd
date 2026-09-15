extends RefCounted
## Stone: boulders, ore nodes, standing stones, clints, cairns, mussel rock and
## peat banks. The rock takes the country's geology: slate on the coast, mossy
## in the wet, snow-capped in the cold, pale limestone on the bones, basalt in
## the burning. Ore shows as bright facets on the faces toward the camera.
## What the machine age cast (a standing stone that is a concrete leg with bent
## rebar, a lens set on a cairn, a pipe through a peat face) is FOUND.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.COUNTRY_STYLE[c] if kind != PropKind.PEAT_BANK else Ink.STIPPLE)
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


## Rock colour of a country: [body, shadowed body, what lies on top].
static func geology(c: int) -> Array[Color]:
	match c:
		Country.MOSS: return [P.SLATE[2], P.SLATE[1], P.MOSS[2]]
		Country.PINEWOOD: return [P.SLATE[2].lerp(P.SPRUCE[2], 0.3), P.SLATE[1], P.MOSS[2].lerp(P.SPRUCE[3], 0.4)]
		Country.SNOWFIELD: return [P.SLATE[3].lerp(P.RIME[3], 0.3), P.SLATE[2], P.RIME[5]]
		Country.BONELANDS: return [P.LINEN[3], P.LINEN[2], P.LINEN[4]]
		Country.BURNING: return [P.STONE[1], P.STONE[0], P.RUST[2]]
	return [P.SLATE[3], P.SLATE[2], P.LINEN[3]]


static func boulder(k: Kit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 7000 + v * 37 + c
	var sides := 5 if c == Country.BONELANDS else 7
	var top := 0.0
	match v % 4:
		0:
			k.stone(0, -0.06, 0, 0.52, 0.72, s, g[0], sides, 0.12)
			top = 0.66
		1:
			k.stone(-0.12, -0.06, 0.05, 0.42, 0.6, s, g[0], sides, -0.1)
			k.stone(0.34, -0.06, -0.2, 0.26, 0.36, s + 1, g[1], 5, 0.2)
			top = 0.54
		2:
			# A flat slab split along its bedding, one half slipped.
			k.stone(-0.08, -0.06, 0, 0.6, 0.34, s, g[0], sides, 0.05)
			k.stone(0.26, -0.04, 0.12, 0.34, 0.3, s + 2, g[1], 5, 0.3)
			top = 0.3
		_:
			k.stone(0.02, -0.06, 0, 0.36, 1.05, s, g[0], sides, 0.18)
			k.stone(-0.34, -0.06, 0.24, 0.2, 0.3, s + 3, g[1], 5, -0.2)
			top = 0.95
	var cap_r: float = [0.32, 0.26, 0.4, 0.18][v % 4]
	match c:
		Country.SNOWFIELD:
			k.clump(0.06, top - 0.06, 0.0, cap_r + 0.04, 0.14, s + 9, P.RIME[5], 6)
		Country.MOSS, Country.PINEWOOD:
			k.clump(-0.06, top - 0.08, 0.03, cap_r, 0.12, s + 9, g[2], 6)
		Country.BURNING:
			k.fleck(Vector3(0.3, 0.02, 0.16), Vector3(0.36, 0.02, 0.04), Vector3(0.24, top * 0.7, 0.08), GroundColors.glow(P.EMBER[2], 0.4))
		_:
			# Lichen blooms on the weather side.
			for i in 3:
				var a := float(i) * 2.1 + v
				var p := Vector3(cos(a) * cap_r * 0.6 - 0.05, top + 0.005, sin(a) * cap_r * 0.6)
				k.fleck(p, p + Vector3(0.08, 0.02, 0.06), p + Vector3(0.1, 0.0, -0.03), g[2] if i != 1 else P.MOSS[4])


static func ore(k: Kit, v: int, c: int, host: Color, bits: Array, sparkle: bool) -> void:
	var g := geology(c)
	var rock := host.lerp(g[0], 0.35)
	var s := 7500 + v * 41 + int(host.r * 100.0)
	k.stone(0, -0.06, 0, 0.48, 0.7, s, rock, 6, 0.08)
	if v == 1:
		k.stone(0.3, -0.06, 0.24, 0.24, 0.34, s + 1, GroundColors.down(rock, 0.4), 5, 0.2)
	# Ore facets on the faces toward the camera and the light.
	for i in 6:
		var a := -0.9 + i * 0.5 + Kit.j(s, i, 0.2)
		var r := 0.36 + Kit.j(s, 10 + i, 0.05)
		var y := 0.14 + Kit.j(s, 20 + i, 0.1) + (0.16 if i % 2 else 0.0)
		var col: Color = bits[i % bits.size()]
		if sparkle and i % 2 == 0:
			col = GroundColors.glint(col)
		var p := Vector3(cos(a) * r, y, sin(a) * r)
		var out := Vector3(cos(a), 0.3, sin(a)).normalized() * 0.1
		var side := Vector3(-sin(a), 0.0, cos(a)) * 0.08
		k.made.tri(p + out, p - side, p + Vector3(0, 0.1, 0), col)
		k.made.tri(p + out, p + Vector3(0, 0.1, 0), p + side, GroundColors.down(col, 0.3))
		k.made.tri(p + out, p + side, p - side + Vector3(0, -0.04, 0), GroundColors.down(col, 0.6))
	# A seam across the top.
	var seam: Color = bits[0]
	k.made.quad(Vector3(-0.2, 0.58, -0.1), Vector3(-0.18, 0.56, 0.08), Vector3(0.16, 0.52, 0.12), Vector3(0.14, 0.55, -0.06), seam)


static func standing_stone(k: Kit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 8000 + v * 43 + c
	var cap_y := 0.0
	match v % 3:
		0:
			# Quarried long ago: a tall leaning slab, lichen on the weather side.
			k.slab(0.0, -0.08, 0.0, 0.52, 1.8, 0.3, s, g[0], GroundColors.up(g[0], 0.2), 0.05, 0.35, 0.06)
			k.made.quad(Vector3(-0.19, 1.05, 0.13), Vector3(0.02, 1.07, 0.12), Vector3(0.04, 1.3, 0.1), Vector3(-0.16, 1.28, 0.11), P.LINEN[3])
			k.made.quad(Vector3(0.02, 0.44, 0.155), Vector3(0.2, 0.46, 0.155), Vector3(0.2, 0.62, 0.15), Vector3(0.02, 0.6, 0.15), P.MOSS[4])
			cap_y = 1.7
		1:
			# Cast, not quarried: a leg with bent bars and a rust run. Exact.
			var concrete := P.STONE[3].lerp(g[0], 0.2)
			k.found.push(Transform3D(Basis(Vector3.BACK, 0.07), Vector3.ZERO))
			k.chamfer(0.0, -0.1, 0.0, 0.44, 1.65, 0.36, 0.06, concrete, GroundColors.up(concrete, 0.2))
			k.chamfer(0.0, 1.18, 0.0, 0.47, 0.07, 0.39, 0.06, GroundColors.down(concrete, 0.4))
			for i in 3:
				var x := -0.12 + i * 0.12
				k.rod(Vector3(x, 1.5, 0.05), Vector3(x, 1.72, 0.05), 0.018, 4, P.RUST[2])
				k.rod(Vector3(x, 1.72, 0.05), Vector3(x + 0.12 + i * 0.06, 1.95, -0.08 * (i - 1)), 0.018, 4, P.RUST[2])
			k.found.quad(Vector3(0.03, 0.2, 0.182), Vector3(0.09, 0.2, 0.182), Vector3(0.07, 1.45, 0.182), Vector3(0.04, 1.45, 0.182), P.RUST[3])
			k.found.pop()
			cap_y = 1.5
		_:
			# A cast foot with cut bolts.
			var concrete := P.STONE[3].lerp(g[0], 0.2)
			k.chamfer(0.0, -0.08, 0.0, 0.84, 0.56, 0.72, 0.1, concrete, GroundColors.up(concrete, 0.2))
			k.chamfer(0.0, 0.48, 0.0, 0.6, 0.12, 0.5, 0.07, GroundColors.down(concrete, 0.3), concrete)
			for bx: float in [-0.2, 0.2]:
				for bz: float in [-0.16, 0.16]:
					k.found.prism(bx, 0.6, bz, 0.035, 0.7, 0.035, 6, P.STONE[1], P.STONE[4])
			k.found.quad(Vector3(-0.1, 0.1, 0.362), Vector3(0.0, 0.1, 0.362), Vector3(-0.02, 0.44, 0.362), Vector3(-0.08, 0.44, 0.362), P.RUST[3])
			cap_y = 0.55
	# Turf round the foot.
	k.clump(0.3, -0.05, 0.12, 0.16, 0.16, s + 30, P.MOSS[2], 5)
	k.clump(-0.28, -0.05, -0.1, 0.13, 0.14, s + 31, P.MOSS[3], 5)
	if c == Country.SNOWFIELD:
		k.clump(0.0, cap_y, 0.0, 0.2, 0.12, s + 5, P.RIME[5], 6)


static func clints(k: Kit, v: int, c: int) -> void:
	var stone := P.LINEN[4] if c != Country.BURNING else P.ASH[3]
	var side := P.LINEN[3] if c != Country.BURNING else P.ASH[2]
	var s := 8500 + v * 7
	var blocks := [[-0.36, -0.2, 0.62, 0.48], [0.32, -0.26, 0.52, 0.4], [-0.08, 0.34, 0.8, 0.36], [0.46, 0.3, 0.3, 0.38]]
	for i in blocks.size():
		if v == 2 and i == 3:
			continue
		var b: Array = blocks[i]
		var h := 0.22 + Kit.j(s, i, 0.05)
		k.slab(b[0], -0.06, b[1], b[2], h, b[3], s + i * 9, side, stone if i % 2 == 0 else P.LINEN[5], 0.03, 0.08)
		# A row of drill holes along one edge.
		if (i + v) % 2 == 0:
			for d in 4:
				var x: float = b[0] - b[2] * 0.3 + d * b[2] * 0.2
				k.made.quad(Vector3(x - 0.015, h - 0.07, b[1] + b[3] * 0.5 + 0.004), Vector3(x + 0.015, h - 0.07, b[1] + b[3] * 0.5 + 0.004), Vector3(x + 0.015, h - 0.035, b[1] + b[3] * 0.5 + 0.004), Vector3(x - 0.015, h - 0.035, b[1] + b[3] * 0.5 + 0.004), P.LINEN[1])
	if v == 1:
		# A block split by a wedge, the halves apart.
		k.slab(-0.02, 0.16, -0.05, 0.2, 0.14, 0.3, s + 50, side, P.LINEN[5], 0.02)
		k.slab(0.2, 0.16, -0.05, 0.2, 0.12, 0.3, s + 51, side, P.LINEN[5], 0.02)
		k.found.prism(0.09, 0.2, -0.05, 0.03, 0.34, 0.01, 4, P.PLATE[2], P.PLATE[3], PI * 0.25)
	# Ferns in the grikes.
	k.hand(Ink.COUNTRY_STYLE[c], 0.0)
	var fs := k.made.vertex_count()
	for i in 3:
		var p := Vector3(-0.05 + i * 0.3, -0.02, 0.05 - i * 0.15)
		for f in 4:
			var a := float(f) * 1.57 + i
			k.blade(p, p + Vector3(cos(a) * 0.14, 0.14, sin(a) * 0.14), 0.06, a + 1.57, P.MOSS[3] if f % 2 else P.SPRUCE[3])
	k.sway_by_height(fs, 0.0, 0.14, 0.5)


static func cairn(k: Kit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 8700 + v * 3 + c
	var y := -0.06
	var r := 0.44
	for i in 5:
		var n := maxi(1, 4 - i)
		for jj in n:
			var a := float(jj) / n * TAU + i * 0.7
			var rr := r * (0.55 if n > 1 else 0.0)
			k.stone(cos(a) * rr, y, sin(a) * rr, r * 0.55, r * 0.62, s + i * 10 + jj, g[0] if (i + jj) % 2 == 0 else g[1], 6, Kit.j(s, i * 7 + jj, 0.15))
		y += r * 0.5
		r *= 0.8
	match v % 3:
		1:
			# Someone set a lens from a machine on top, looking out.
			var top := Vector3(0.0, y + 0.18, 0.0)
			k.rod(Vector3(0, y - 0.05, 0), top, 0.025, 6, P.STONE[1])
			var rc := top + Vector3(0, 0.1, 0.02)
			k.hoop(rc, 0.11, 12, 0.02, P.PLATE[3], Vector3.RIGHT)
			k.found.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), rc))
			k.found.prism(0, -0.01, 0, 0.09, 0.01, 0.09, 10, P.COLD[1], P.COLD[2])
			k.found.pop()
			k.fleck(rc + Vector3(0.02, 0.03, 0.02), rc + Vector3(0.02, 0.06, 0.05), rc + Vector3(0.02, 0.02, 0.05), GroundColors.glint(P.COLD[3]))
		2:
			# A crane arm off a machine, stood up as a marker.
			k.rod(Vector3(0, y - 0.1, 0), Vector3(0.1, y + 0.7, 0), 0.03, 4, P.PLATE[3])
			k.rod(Vector3(0.1, y + 0.7, 0), Vector3(0.45, y + 0.62, 0), 0.025, 4, P.PLATE[3])
			k.found.prism(0.45, y + 0.5, 0, 0.04, y + 0.62, 0.04, 4, P.PLATE[2], P.PLATE[4], PI * 0.25)
	if c == Country.SNOWFIELD:
		k.clump(0, y - 0.08, 0, 0.16, 0.1, s + 60, P.RIME[5], 6)


static func mussel_rock(k: Kit, v: int, _c: int) -> void:
	var s := 8900 + v * 11
	k.hand(Ink.WIND)
	k.stone(0, -0.1, 0, 0.55, 0.36, s, P.SLATE[1], 7, 0.1, P.SLATE[2])
	if v % 3 == 1:
		k.stone(0.44, -0.1, 0.26, 0.3, 0.26, s + 1, P.SLATE[1], 6, 0.2)
	# Mussels in clumps: small dark blue-black shells, a few gaping.
	for i in 18:
		var a := float(i) * 2.39996
		var r := 0.18 + fmod(float(i) * 0.137, 0.3)
		var y := 0.2 - r * 0.28
		var p := Vector3(cos(a) * r, y, sin(a) * r)
		var d := Vector3(cos(a + 1.1), 0.0, sin(a + 1.1)) * 0.06
		var col := P.INK[2] if i % 3 else P.BRINE[1]
		k.fleck(p, p + d + Vector3(0, 0.03, 0), p + d * 0.3 + Vector3(0.02, 0.05, 0.02), col)
		k.fleck(p, p + d * 0.3 + Vector3(0.02, 0.05, 0.02), p - d * 0.2 + Vector3(0, 0.02, 0.03), P.BRINE[2] if i % 4 == 0 else col)
	for i in 9:
		var a := float(i) * 1.71 + 0.2
		var p := Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.3)
		k.fleck(p, p + Vector3(0.03, 0.0, 0.01), p + Vector3(0.0, 0.02, 0.03), P.LINEN[4])
	# Weed fringe at the waterline.
	var ws := k.made.vertex_count()
	for i in 11:
		var a := float(i) / 11.0 * TAU
		var base := Vector3(cos(a) * 0.52, -0.03, sin(a) * 0.52)
		k.blade(base, base + Vector3(cos(a) * 0.16, 0.07, sin(a) * 0.16), 0.08, a + 1.57, P.MOSS[1] if i % 2 else P.EARTH[2])
	k.sway_by_height(ws, -0.03, 0.05, 0.5)


static func peat_bank(k: Kit, v: int, _c: int) -> void:
	var s := 9100 + v * 5
	# A cut bank: a long low hump of moor, one side sliced back to a dark face
	# with spade marks, heather grown over the top.
	var n := 7
	var len := 1.2
	var top: Array[Vector3] = []
	var back: Array[Vector3] = []
	var face_top: Array[Vector3] = []
	var face_bot: Array[Vector3] = []
	for i in n:
		var t := float(i) / (n - 1)
		var x := (t - 0.5) * len
		var bow := sin(t * PI) * 0.12
		var hh := 0.28 + sin(t * PI) * 0.22 + Kit.j(s, i, 0.04)
		face_bot.append(Vector3(x, -0.04, 0.16 + bow))
		face_top.append(Vector3(x + Kit.j(s, i + 10, 0.03), hh, 0.12 + bow + Kit.j(s, i + 20, 0.02)))
		top.append(Vector3(x, hh + 0.04, -0.12 + bow * 0.5))
		back.append(Vector3(x * 0.9, -0.04, -0.5 + bow * 0.3))
	for i in n - 1:
		# The cut face, dark, and the moor on top and behind.
		k.made.quad(face_bot[i], face_bot[i + 1], face_top[i + 1], face_top[i], P.EARTH[1])
		k.made.quad(face_top[i], face_top[i + 1], top[i + 1], top[i], P.MOSS[1])
		k.made.quad(top[i], top[i + 1], back[i + 1], back[i], P.EARTH[1].lerp(P.MOSS[1], 0.5))
	k.fleck(face_bot[0], back[0], top[0], P.EARTH[1])
	k.fleck(face_bot[0], top[0], face_top[0], P.EARTH[1])
	k.fleck(back[n - 1], face_bot[n - 1], top[n - 1], P.EARTH[1])
	k.fleck(top[n - 1], face_bot[n - 1], face_top[n - 1], P.EARTH[1])
	# Spade marks: short dark cuts down the face.
	for i in 9:
		var t := 0.08 + i * 0.105
		var seg := clampi(int(t * (n - 1)), 0, n - 2)
		var f := t * (n - 1) - seg
		var a := face_top[seg].lerp(face_top[seg + 1], f).lerp(face_bot[seg].lerp(face_bot[seg + 1], f), 0.25) + Vector3(0, 0, 0.02)
		var b := face_top[seg].lerp(face_top[seg + 1], f).lerp(face_bot[seg].lerp(face_bot[seg + 1], f), 0.7 + Kit.j(s, 60 + i, 0.15)) + Vector3(0, 0, 0.02)
		k.made.quad(b + Vector3(0.03, 0, 0), b, a, a + Vector3(0.03, 0, 0), P.EARTH[0])
	var hs := k.made.vertex_count()
	for i in 6:
		var p := top[1 + i % (n - 2)].lerp(top[mini(n - 1, 2 + i % (n - 2))], Kit.j(s, 40 + i, 0.5) + 0.5)
		k.clump(p.x, p.y - 0.08, p.z + Kit.j(s, 30 + i, 0.08), 0.2, 0.2, s + 10 + i, P.EARTH[2].lerp(P.MOSS[2], 0.6) if i % 2 else P.MOSS[2], 6)
		k.fleck(p + Vector3(0.02, 0.08, 0.02), p + Vector3(0.06, 0.09, 0.03), p + Vector3(0.03, 0.12, 0.0), P.BLOOM[2] if i % 2 else P.BLOOM[1])
	k.sway_by_height(hs, 0.3, 0.6, 0.2)
	# Black water gathered at the foot of the cut.
	k.made.tri(Vector3(-0.3, 0.004, 0.22), Vector3(0.2, 0.004, 0.24), Vector3(-0.05, 0.004, 0.38), P.BRINE[0])
	# Cut peats stood up in a little cone to dry.
	for i in 4:
		var a := float(i) / 4.0 * TAU + 0.4
		var foot := Vector3(0.95 + cos(a) * 0.12, -0.03, 0.4 + sin(a) * 0.12)
		k.limb(foot, Vector3(0.95, 0.24, 0.4), 0.05, 0.03, 4, P.EARTH[1] if i % 2 else P.EARTH[2])
	if v % 3 == 1:
		# A pipe through the face, an ochre stain fanning from it.
		k.rod(Vector3(-0.2, 0.3, -0.35), Vector3(-0.2, 0.3, 0.2), 0.07, 8, P.PLATE[2])
		k.hoop(Vector3(-0.2, 0.3, 0.2), 0.085, 8, 0.015, P.PLATE[3], Vector3.BACK)
		k.found.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.2, 0.3, 0.205)))
		k.found.prism(0, 0, 0, 0.055, 0.004, 0.055, 8, P.INK[1])
		k.found.pop()
		k.fleck(Vector3(-0.2, 0.25, 0.2), Vector3(-0.44, -0.02, 0.24), Vector3(0.04, -0.02, 0.24), P.RUST[4])
		k.made.tri(Vector3(-0.2, 0.006, 0.25), Vector3(-0.42, 0.006, 0.5), Vector3(0.02, 0.006, 0.54), P.RUST[2])
