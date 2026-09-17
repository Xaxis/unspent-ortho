extends RefCounted
## Things that grow: pines, snow pines, broadleaf, dead trees, bushes, gorse,
## reeds. Grown things are MADE: uneven, leaning, never mirrored, hatched in
## their country's hand. Crowns, tiers and blades sway by height; trunks do not.
## The machine age shows as FOUND parts: an iron hoop a tree grew round, a
## crossarm with insulators on a dead tree, a cable split to the copper in reeds.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.PINE: pine(k, v, c, false)
		PropKind.SNOW_PINE: pine(k, v, Country.SNOWFIELD, true)
		PropKind.BROADLEAF: broadleaf(k, v, c)
		PropKind.DEAD_TREE: dead_tree(k, v, c)
		PropKind.BUSH: bush(k, v, c)
		PropKind.GORSE: gorse(k, v, c)
		PropKind.REEDS: reeds(k, v, c)


## Kinds whose silhouette leans with the prevailing wind in these countries:
## WorldView turns them to one bearing instead of a random one.
static func wind_bent(kind: int, c: int) -> bool:
	if c != Country.COAST and c != Country.BONELANDS:
		return false
	return kind == PropKind.BROADLEAF or kind == PropKind.PINE or kind == PropKind.GORSE or kind == PropKind.DEAD_TREE


static func pine(k: Kit, v: int, c: int, laden: bool) -> void:
	var s := 1000 + v * 17 + c * 3 + (500 if laden else 0)
	var height: float = [2.8, 2.3, 3.3, 2.6][v % 4]
	var base_r: float = [0.72, 0.82, 0.62, 0.7][v % 4]
	var tiers: int = [4, 3, 5, 4][v % 4]
	var points: int = [8, 9, 7, 8][v % 4]
	var lean := Vector2(Kit.j(s, 1, 0.04), Kit.j(s, 2, 0.04))
	var trunk := P.EARTH[1]
	var greens: Array[Color] = [P.SPRUCE[2], P.SPRUCE[3], P.SPRUCE[3].lerp(P.SPRUCE[4], 0.35)]
	var under := P.SPRUCE[1]
	var snow := laden or c == Country.SNOWFIELD
	match c:
		Country.MOSS:
			greens = [P.SPRUCE[2].lerp(P.MOSS[2], 0.35), P.SPRUCE[3].lerp(P.MOSS[3], 0.3), P.SPRUCE[3].lerp(P.MOSS[4], 0.3)]
		Country.COAST, Country.BONELANDS:
			# Wind-bent: the crown leans downwind and the top is cropped.
			lean = Vector2(0.09 if c == Country.COAST else 0.13, 0.02)
			height *= 0.85
		Country.BURNING:
			greens = [P.STONE[0], P.ASH[1], P.EARTH[1]]
			under = P.INK[1]
			trunk = P.INK[1]
			tiers = maxi(2, tiers - 1)
			base_r *= 0.72
			points = 6
		Country.SNOWFIELD:
			greens = [P.SPRUCE[1], P.SPRUCE[2], P.SPRUCE[2].lerp(P.SPRUCE[3], 0.5)]
			under = P.SPRUCE[0]
	if laden:
		greens = [P.SPRUCE[1], P.SPRUCE[1].lerp(P.SPRUCE[2], 0.5), P.SPRUCE[2]]
	var top := Vector3(lean.x * height, height * 0.92, lean.y * height)
	k.limb(Vector3.ZERO, top, 0.11, 0.03, 5, trunk, Vector3(Kit.j(s, 3, 0.05), 0, Kit.j(s, 4, 0.05)))
	for i in 3:
		var a := float(i) / 3.0 * TAU + Kit.j(s, 10 + i, 0.5)
		k.spike(Vector3(0, 0.14, 0), Vector3(cos(a) * 0.24, -0.02, sin(a) * 0.24), 0.05, 3, trunk)
	var start := k.made.vertex_count()
	var y0 := height * 0.2
	var y1 := height * 0.8
	for t in tiers:
		var f := float(t) / maxf(1.0, tiers - 1)
		var r := base_r * (1.0 - f * 0.68)
		var y := lerpf(y0, y1, f)
		var rise := (y1 - y0) / maxf(1.0, tiers - 1) * 1.6 + (0.35 if t == tiers - 1 else 0.0)
		var droop := 0.14 + r * 0.12
		var col := greens[mini(2, int(f * 2.99))]
		var cx := lean.x * y + Kit.j(s, 20 + t, 0.04)
		var cz := lean.y * y + Kit.j(s, 30 + t, 0.04)
		k.tier(cx, y, cz, r, rise, points, droop, s + t * 11, col, under if t == 0 else Color(0, 0, 0, 0))
		if snow and c != Country.BURNING:
			# Snow lies on the upper face of each tier; the green shows at the rim.
			var sr := r * (0.78 if laden else 0.62)
			k.tier(cx + Kit.j(s, 40 + t, 0.02), y + droop * 0.35 + 0.03, cz, sr, rise * 0.62, points, droop * 0.7, s + t * 11 + 5, P.RIME[5], Color(0, 0, 0, 0))
	k.sway_by_height(start, y0 - 0.1, height, 0.7)
	if v % 4 == 3 and not laden:
		# A dead spike where the leader broke.
		k.limb(top, top + Vector3(0.05, 0.45, -0.03), 0.03, 0.008, 3, P.ASH[2])
	if c == Country.MOSS:
		# Lichen beards hang from the lower tiers.
		var bs := k.made.vertex_count()
		for i in 5:
			var a := float(i) / 5.0 * TAU + 0.4
			var p := Vector3(cos(a) * base_r * 0.6, height * 0.24, sin(a) * base_r * 0.6)
			k.blade(p, p + Vector3(0.02, -0.28, 0), 0.07, a, P.ASH[3])
		k.sway_by_height(bs, -10.0, -9.0, 0.5)
	if c == Country.BURNING:
		k.made.prism(0.02, 0.0, 0.0, 0.12, 0.08, 0.1, 5, GroundColors.glow(P.EMBER[3], 0.7))


static func broadleaf(k: Kit, v: int, c: int) -> void:
	var s := 2000 + v * 31 + c * 5
	var trunk := P.EARTH[2]
	var leaves: Array[Color] = [P.MOSS[2], P.MOSS[3], P.MOSS[3].lerp(P.SPRUCE[3], 0.45), P.MOSS[3].lerp(P.MOSS[4], 0.35)]
	var crown := true
	var lean := Vector2(Kit.j(s, 1, 0.08), Kit.j(s, 2, 0.08))
	var h: float = [1.0, 1.15, 0.9, 1.05][v % 4]
	var spread := 1.0
	match c:
		Country.COAST:
			lean = Vector2(0.32, 0.06)
			spread = 1.1
		Country.MOSS:
			leaves = [P.MOSS[2].lerp(P.ASH[2], 0.4), P.MOSS[2], P.ASH[3].lerp(P.MOSS[3], 0.5), P.MOSS[3]]
			trunk = P.LINEN[2]
			spread = 0.85
		Country.PINEWOOD:
			leaves = [P.MOSS[1].lerp(P.SPRUCE[2], 0.5), P.MOSS[2], P.SPRUCE[3], P.MOSS[3]]
		Country.BONELANDS:
			# Hawthorn: low, wide, bleached, bent right over.
			leaves = [P.MOSS[3].lerp(P.SAND[4], 0.35), P.MOSS[3], P.MOSS[4].lerp(P.LINEN[4], 0.35), P.MOSS[3].lerp(P.SAND[3], 0.3)]
			lean = Vector2(0.45, 0.08)
			h = 0.72
			spread = 1.3
		Country.SNOWFIELD, Country.BURNING:
			crown = false
			trunk = P.INK[2] if c == Country.BURNING else P.EARTH[1]
	# A landscape that colours its own trees says so (BiomeDef.tree_tints), so a
	# new one is not drawn in the coast's greens by default.
	var own: Dictionary = BiomeRegistry.by_index(c).tree_tints
	if own.has(&"leaf"):
		leaves.assign(own[&"leaf"])
	if own.has(&"trunk"):
		trunk = (own[&"trunk"] as Array)[0]
	var top := Vector3(lean.x * 0.8, 0.9 * h, lean.y * 0.8)
	k.limb(Vector3.ZERO, top, 0.13, 0.07, 6, trunk, Vector3(-lean.x * 0.25, 0, Kit.j(s, 3, 0.05)))
	k.limb(Vector3(0, 0.08, 0), Vector3(0.2, -0.02, -0.12), 0.06, 0.02, 4, trunk)
	k.limb(Vector3(0, 0.08, 0), Vector3(-0.16, -0.02, 0.14), 0.05, 0.02, 4, trunk)
	var tips: Array[Vector3] = []
	var nb := 3 + v % 2
	for i in nb:
		var a := float(i) / nb * TAU + Kit.j(s, 20 + i, 0.6)
		var tip := top + Vector3(cos(a) * 0.46 * spread + lean.x * 0.3, 0.32 + Kit.j(s, 30 + i, 0.14), sin(a) * 0.46 * spread)
		k.limb(top, tip, 0.05, 0.025, 4, trunk)
		tips.append(tip)
	if crown:
		var start := k.made.vertex_count()
		for i in tips.size():
			var tip := tips[i]
			k.clump(tip.x, tip.y - 0.22, tip.z, 0.4 * spread + Kit.j(s, 40 + i, 0.06), 0.62 * h, s + i * 7, leaves[i % 3], 7, 0.35)
		k.clump(top.x + lean.x * 0.35, top.y + 0.2, top.z, 0.44 * spread, 0.78 * h, s + 99, leaves[3], 8, 0.35)
		k.sway_by_height(start, top.y - 0.2, top.y + 0.9, 0.55)
		if c == Country.BONELANDS:
			for i in 7:
				var a := float(i) * 1.1
				var p := top + Vector3(cos(a) * 0.52 * spread + lean.x * 0.4, 0.5 + Kit.j(s, 70 + i, 0.2), sin(a) * 0.5 * spread)
				k.fleck(p, p + Vector3(0.05, 0.02, 0.0), p + Vector3(0.02, 0.06, 0.03), P.RUST[3])
	else:
		for tip in tips:
			var twig := tip + Vector3(Kit.j(s, int(tip.x * 100.0), 0.2), 0.28, Kit.j(s, int(tip.z * 100.0), 0.2))
			var ts := k.made.vertex_count()
			k.limb(tip, twig, 0.022, 0.006, 3, trunk)
			k.limb(tip, tip + Vector3(0.18, 0.12, -0.1), 0.015, 0.005, 3, trunk)
			k.sway_by_height(ts, tip.y, twig.y, 0.35)
			if c == Country.SNOWFIELD:
				k.clump(tip.x, tip.y - 0.02, tip.z, 0.1, 0.07, s + int(tip.x * 50.0), P.RIME[5], 5)
		if c == Country.BURNING:
			k.made.prism(0.0, 0.0, 0.0, 0.13, 0.08, 0.1, 5, GroundColors.glow(P.EMBER[3], 0.6))
	if v % 4 == 2 and crown:
		# Grown round an iron hoop, a cable run from it into the ground.
		var hoop := Vector3(top.x * 0.5, 0.5 * h, top.z * 0.5)
		k.hoop(hoop, 0.17, 10, 0.022, P.PLATE[2])
		k.cable(hoop + Vector3(0.17, -0.02, 0.0), Vector3(1.0, 0.0, 0.5), 0.12, 5, 0.018, P.INK[2])


static func dead_tree(k: Kit, v: int, c: int) -> void:
	var s := 3000 + v * 13 + c * 7
	var wood := P.ASH[2].lerp(P.LINEN[2], 0.4)
	var dark := P.ASH[1]
	match c:
		Country.BURNING:
			# Charred, not black: against pale ash a near-black stick was the
			# highest-contrast mark in the frame (art review 14).
			wood = P.INK[3].lerp(P.ASH[1], 0.55)
			dark = P.INK[3]
		Country.MOSS:
			wood = P.LINEN[2].lerp(P.SPRUCE[2], 0.25)
	var h: float = [1.7, 1.55, 0.8, 1.9][v % 4]
	var lean := Vector2(Kit.j(s, 1, 0.12), Kit.j(s, 2, 0.12))
	var top := Vector3(lean.x, h, lean.y)
	# A trunk, not a wire: at the play camera 0.12 was a three-pixel stick, and a
	# stick with a knot on top and three splayed legs under it reads as a dead
	# insect in a pale frame (art review 14), not as a tree.
	k.limb(Vector3(0, -0.06, 0), top.lerp(Vector3.ZERO, 0.55), 0.21, 0.11, 6, wood, Vector3(Kit.j(s, 5, 0.05), 0, Kit.j(s, 6, 0.05)))
	k.limb(top.lerp(Vector3.ZERO, 0.55), top, 0.11, 0.055, 5, wood, Vector3(Kit.j(s, 7, 0.06), 0, Kit.j(s, 8, 0.06)))
	# A broken top: a jagged splinter.
	k.made.prism(top.x, top.y, top.z, 0.055, top.y + 0.22, 0.0, 4, dark, Color(0, 0, 0, 0), Kit.j(s, 3, 1.0))
	# The root flare: buttresses that swell out of the ground and stop, hugging
	# the foot. Never legs standing the trunk up off the land.
	for i in 4:
		var a := float(i) / 4.0 * TAU + 0.7
		var out := Vector3(cos(a) * 0.26, 0.0, sin(a) * 0.26)
		k.made.tri(Vector3(0, 0.34, 0), Vector3(out.x * 0.35, -0.05, out.z * 0.35), out + Vector3(0, -0.05, 0), wood)
		k.made.tri(Vector3(0, 0.34, 0), out + Vector3(0, -0.05, 0), Vector3(out.x * 0.35, -0.05, out.z * 0.35), GroundColors.down(wood, 0.3))
		k.stone(out.x * 0.8, -0.06, out.z * 0.8, 0.1, 0.07, s + 60 + i, GroundColors.down(wood, 0.5), 5)
	if v % 4 == 2:
		# A split snag.
		k.made.prism(0.05, h, 0.0, 0.06, h + 0.3, 0.0, 4, wood)
		k.made.prism(-0.06, h, 0.02, 0.05, h + 0.14, 0.0, 4, dark)
	else:
		for i in 3 + v % 2:
			var f := 0.45 + i * 0.13
			var a := float(i) * 2.2 + Kit.j(s, 10 + i, 0.4)
			var from := top * f
			var to := from + Vector3(cos(a) * 0.46, 0.34 + Kit.j(s, 20 + i, 0.12), sin(a) * 0.46)
			var bs := k.made.vertex_count()
			k.limb(from, to, 0.04, 0.01, 4, wood, Vector3(0, -0.06, 0))
			k.sway_by_height(bs, from.y, to.y, 0.15)
			if c == Country.SNOWFIELD:
				k.made.strut(from + Vector3(0, 0.045, 0), to + Vector3(0, 0.03, 0), 0.02, 3, P.RIME[5])
	if v % 4 == 1:
		# A crossarm with two clay insulators and a wire: the grid it once held.
		var arm_y := h * 0.84
		var ac := Vector3(top.x * 0.84, arm_y, top.z * 0.84)
		k.found.push(Transform3D(Basis.IDENTITY, ac))
		k.found.prism(0, -0.035, -0.46, 0.035, 0.035, 0.035, 4, P.PLATE[2], P.PLATE[3], PI * 0.25)
		k.found.pop()
		k.rod(ac + Vector3(0, 0, -0.46), ac + Vector3(0, 0, 0.46), 0.035, 4, P.PLATE[2])
		for side: float in [-0.36, 0.36]:
			var ip := ac + Vector3(0, 0.035, side)
			k.found.prism(ip.x, ip.y, ip.z, 0.035, ip.y + 0.1, 0.028, 6, P.RUST[3], P.RUST[4])
			k.found.prism(ip.x, ip.y + 0.04, ip.z, 0.05, ip.y + 0.055, 0.05, 6, P.RUST[2])
			k.cable(ip + Vector3(0, 0.1, 0), ip + Vector3(1.7, -0.7, side * 0.4), 0.2, 5, 0.01, P.INK[1])
	if c == Country.BURNING:
		k.fleck(Vector3(0.1, 0.2, 0.06), Vector3(0.1, 0.55, 0.05), Vector3(0.14, 0.2, 0.02), GroundColors.glow(P.EMBER[3], 1.0))
		k.fleck(Vector3(-0.08, 0.6, -0.08), Vector3(-0.06, 0.8, -0.1), Vector3(-0.1, 0.6, -0.12), GroundColors.glow(P.EMBER[4], 0.8))


static func bush(k: Kit, v: int, c: int) -> void:
	var s := 4000 + v * 19 + c * 11
	var cols: Array[Color] = [P.MOSS[2], P.MOSS[3], P.MOSS[2].lerp(P.SPRUCE[3], 0.5)]
	var berries := Color(0, 0, 0, 0)
	var cap := Color(0, 0, 0, 0)
	match c:
		Country.MOSS:
			cols = [P.SPRUCE[2], P.EARTH[2].lerp(P.MOSS[2], 0.5), P.SPRUCE[2].lerp(P.MOSS[3], 0.4)]
		Country.PINEWOOD:
			cols = [P.SPRUCE[1], P.SPRUCE[2], P.SPRUCE[2].lerp(P.SPRUCE[3], 0.5)]
			berries = P.BLOOM[1]
		Country.SNOWFIELD:
			cols = [P.SPRUCE[1], P.SPRUCE[1].lerp(P.ASH[2], 0.4), P.SPRUCE[2]]
			cap = P.RIME[5]
		Country.BONELANDS:
			cols = [P.MOSS[3].lerp(P.SAND[4], 0.35), P.MOSS[3], P.MOSS[4].lerp(P.LINEN[3], 0.35)]
			berries = P.RUST[3]
		Country.BURNING:
			cols = [P.EARTH[1], P.ASH[1], P.EARTH[1].lerp(P.RUST[1], 0.5)]
		Country.COAST:
			berries = P.BLOOM[2] if v % 2 == 1 else Color(0, 0, 0, 0)
	var own: Dictionary = BiomeRegistry.by_index(c).tree_tints
	if own.has(&"scrub"):
		cols.assign(own[&"scrub"])
	var start := k.made.vertex_count()
	var n := 2 + v % 3
	for i in n:
		var a := float(i) / n * TAU + Kit.j(s, i, 0.6)
		var rr := 0.16 + Kit.j(s, 10 + i, 0.06)
		var r := 0.3 - i * 0.02 + Kit.j(s, 20 + i, 0.05)
		k.clump(cos(a) * rr, -0.03, sin(a) * rr, r, 0.42 + Kit.j(s, 30 + i, 0.08), s + i * 5, cols[i % 3], 7, 0.35)
		if cap.a > 0.0:
			k.clump(cos(a) * rr, 0.24, sin(a) * rr, r * 0.66, 0.16, s + i * 5 + 1, cap, 6)
	if berries.a > 0.0:
		for i in 7:
			var a := float(i) * 1.37
			var p := Vector3(cos(a) * 0.24, 0.26 + Kit.j(s, 40 + i, 0.08), sin(a) * 0.24)
			k.fleck(p, p + Vector3(0.045, 0.0, 0.01), p + Vector3(0.02, 0.045, 0.0), berries)
	k.sway_by_height(start, 0.0, 0.5, 0.25)
	if c == Country.BURNING:
		for i in 4:
			var a := float(i) * 1.6
			k.limb(Vector3(0, 0.1, 0), Vector3(cos(a) * 0.3, 0.46, sin(a) * 0.3), 0.018, 0.005, 3, P.INK[2])
		k.made.prism(0.05, 0.02, 0.0, 0.07, 0.05, 0.05, 5, GroundColors.glow(P.EMBER[3], 0.5))


static func gorse(k: Kit, v: int, c: int) -> void:
	var s := 5000 + v * 23 + c
	var greens: Array[Color] = [P.SPRUCE[2], P.MOSS[2], P.SPRUCE[2].lerp(P.MOSS[3], 0.5)]
	if c == Country.BURNING:
		greens = [P.EARTH[1], P.ASH[1], P.EARTH[2]]
	elif c == Country.SNOWFIELD:
		greens = [P.SPRUCE[1], P.SPRUCE[1], P.SPRUCE[2]]
	var start := k.made.vertex_count()
	var n := 3 + v
	for i in n:
		var a := float(i) / n * TAU + Kit.j(s, i, 0.5)
		var rr := 0.2 + Kit.j(s, 10 + i, 0.06)
		k.clump(cos(a) * rr, -0.02, sin(a) * rr, 0.27, 0.5, s + i * 3, greens[i % 3], 6, 0.35)
	# Spines stick out of the mass.
	for i in 16:
		var a := float(i) * 2.39996
		var up := 0.14 + fmod(float(i) * 0.37, 0.3)
		var base := Vector3(cos(a) * 0.24, up, sin(a) * 0.24)
		k.blade(base, base + Vector3(cos(a) * 0.17, 0.14, sin(a) * 0.17), 0.03, a + 1.57, greens[i % 2])
	# Flowers: small hard yellow points, crowded on one variant.
	if c != Country.BURNING and c != Country.SNOWFIELD:
		var flowers: int = [22, 9, 15][v % 3]
		for i in flowers:
			var a := float(i) * 2.39996 + 0.3
			var r := 0.2 + fmod(float(i) * 0.113, 0.18)
			var y := 0.26 + fmod(float(i) * 0.071, 0.26)
			var p := Vector3(cos(a) * r, y, sin(a) * r)
			k.fleck(p, p + Vector3(0.05, 0.0, 0.02), p + Vector3(0.02, 0.05, -0.01), P.RUST[5] if i % 3 else P.SAND[5])
	k.sway_by_height(start, 0.0, 0.6, 0.3)


static func reeds(k: Kit, v: int, c: int) -> void:
	var s := 6000 + v * 29 + c * 13
	var stem: Array[Color] = [P.SAND[3], P.MOSS[3], P.SAND[4]]
	var head := P.EARTH[2]
	match c:
		Country.MOSS:
			stem = [P.MOSS[2], P.EARTH[3], P.MOSS[3]]
			head = P.EARTH[1]
		Country.COAST:
			stem = [P.SAND[4], P.MOSS[4].lerp(P.SAND[4], 0.5), P.SAND[3]]
			head = P.SAND[2]
		Country.SNOWFIELD:
			stem = [P.ASH[3], P.LINEN[3], P.ASH[4]]
			head = P.RIME[4]
		Country.BURNING:
			stem = [P.EARTH[2], P.ASH[2], P.EARTH[1]]
			head = P.INK[2]
	var start := k.made.vertex_count()
	var n := 15 + v * 3
	for i in n:
		var a := Rng.hash01(s, i) * TAU
		var r := sqrt(Rng.hash01(s, i, 1)) * 0.34
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var height := 0.55 + Rng.hash01(s, i, 2) * 0.5
		var bend := Vector3((Rng.hash01(s, i, 3) - 0.5) * 0.24 + 0.06, 0.0, (Rng.hash01(s, i, 4) - 0.5) * 0.24)
		var tip := base + bend + Vector3(0, height, 0)
		var mid := base + bend * 0.3 + Vector3(0, height * 0.55, 0)
		var col := stem[i % 3]
		k.blade(base, mid, 0.06, a, col)
		k.blade(mid + Vector3(0, -0.03, 0), tip, 0.04, a + 0.3, col)
		if i % 3 == 0:
			var hp := tip + Vector3(0, -0.12, 0)
			k.blade(hp + Vector3(0, -0.08, 0), hp + Vector3(0.01, 0.08, 0), 0.05, a + 1.57, head)
	if v % 3 == 2 and c != Country.SNOWFIELD:
		# Bog cotton among them.
		for i in 5:
			var a := float(i) * 1.3
			var p := Vector3(cos(a) * 0.25, 0.42 + Kit.j(s, 60 + i, 0.08), sin(a) * 0.25)
			k.clump(p.x, p.y, p.z, 0.05, 0.06, s + 70 + i, P.LINEN[5], 5)
	k.sway_by_height(start, 0.0, 1.0, 1.0)
	if v % 3 == 1:
		# A cable through the bed, its sheath split back to the copper.
		k.rod(Vector3(-0.75, 0.05, -0.16), Vector3(-0.1, 0.1, 0.0), 0.03, 6, P.INK[2])
		k.rod(Vector3(-0.1, 0.1, 0.0), Vector3(0.14, 0.11, 0.05), 0.02, 6, P.COPPER[3])
		k.rod(Vector3(0.14, 0.11, 0.05), Vector3(0.75, 0.04, 0.2), 0.03, 6, P.INK[2])
