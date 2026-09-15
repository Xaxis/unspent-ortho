extends RefCounted
## Things that grow: pines, snow pines, broadleaf, dead trees, bushes, gorse,
## reeds. Grown things are MADE-idiom: uneven, leaning, never mirrored. Crowns,
## tiers and blades carry sway weights (higher moves more).

const Craft := preload("res://src/models/props/craft.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: MeshKit, kind: int, v: int, c: int) -> void:
	match kind:
		PropKind.PINE: pine(k, v, c, false)
		PropKind.SNOW_PINE: pine(k, v + 7, Country.SNOWFIELD, true)
		PropKind.BROADLEAF: broadleaf(k, v, c)
		PropKind.DEAD_TREE: dead_tree(k, v, c)
		PropKind.BUSH: bush(k, v, c)
		PropKind.GORSE: gorse(k, v, c)
		PropKind.REEDS: reeds(k, v, c)


static func pine(k: MeshKit, v: int, c: int, laden: bool) -> void:
	var s := 1000 + v * 17 + c * 3
	var tiers: int = [4, 3, 5, 4, 3, 5, 4, 3, 4, 3][v % 10]
	var height: float = [2.6, 2.1, 3.0, 2.5, 2.2, 3.1, 2.4, 2.3, 2.8, 2.2][v % 10]
	var base_r: float = [0.62, 0.74, 0.5, 0.6, 0.7, 0.52, 0.64, 0.66, 0.58, 0.7][v % 10]
	var lean := Vector2(Craft.j(s, 1, 0.08), Craft.j(s, 2, 0.08))
	var trunk := P.EARTH[1]
	var greens: Array[Color] = [P.SPRUCE[2], P.SPRUCE[3], P.SPRUCE[3].lerp(P.SPRUCE[4], 0.35)]
	var snow := laden or c == Country.SNOWFIELD
	match c:
		Country.MOSS:
			greens = [P.SPRUCE[2].lerp(P.MOSS[2], 0.3), P.SPRUCE[3].lerp(P.MOSS[3], 0.25), P.SPRUCE[3].lerp(P.MOSS[4], 0.3)]
		Country.BONELANDS, Country.COAST:
			# Wind-bent: the crown leans away from the weather and the top is cropped.
			lean = Vector2(0.22, 0.05) if c == Country.BONELANDS else Vector2(0.14, 0.04)
			height *= 0.88
		Country.BURNING:
			greens = [P.INK[2], P.INK[3], P.EARTH[1]]
			trunk = P.INK[1]
			tiers = maxi(2, tiers - 1)
			base_r *= 0.7
		Country.SNOWFIELD:
			greens = [P.SPRUCE[1], P.SPRUCE[2], P.SPRUCE[2].lerp(P.SPRUCE[3], 0.5)]
	if laden:
		greens = [P.SPRUCE[1], P.SPRUCE[1].lerp(P.SPRUCE[2], 0.5), P.SPRUCE[2]]
	var trunk_top := height * 0.35
	k.prism(0, 0, 0, 0.1, trunk_top + 0.1, 0.06, 5, trunk, Color(0, 0, 0, 0), 0.3)
	# Roots flare into the ground.
	for i in 3:
		var a := float(i) / 3.0 * TAU + Craft.j(s, 10 + i, 0.5)
		k.strut(Vector3(0, 0.12, 0), Vector3(cos(a) * 0.22, 0.0, sin(a) * 0.22), 0.035, 3, trunk)
	var y := height * 0.18
	var top_y := height
	for t in tiers:
		var f := float(t) / tiers
		var r := base_r * (1.0 - f * 0.62)
		var y1 := y + (top_y - y) * (0.55 if t < tiers - 1 else 1.0) + 0.1
		var col: Color = greens[mini(2, int(f * 3.0))] if t % 2 == 0 else greens[mini(2, int(f * 3.0 + 0.5))]
		var w := 0.25 + 0.75 * (float(t + 1) / tiers)
		var tl := lean * f
		Craft.tier(k, tl.x, y, tl.y, r, y1, s + t * 11, PropModels.sway(col, w), 7)
		if snow and c != Country.BURNING:
			# Snow sits on the upper half of each tier, lipping over the rim.
			var yc := lerpf(y, y1, 0.42)
			Craft.tier(k, tl.x + lean.x * 0.1, yc, tl.y, r * 0.66, y1 + 0.03, s + t * 11 + 5, PropModels.sway(P.RIME[5], w), 6)
			if laden:
				Craft.tier(k, tl.x, y + 0.02, tl.y, r * 1.02, lerpf(y, y1, 0.3), s + t * 13, PropModels.sway(P.RIME[4], w), 7)
		y += (top_y - y) * 0.36
	if v % 3 == 2 and not laden:
		# A dead spike where the leader broke.
		k.strut(Vector3(lean.x, top_y - 0.2, lean.y), Vector3(lean.x + 0.08, top_y + 0.35, lean.y - 0.04), 0.025, 3, P.ASH[2])
	if c == Country.MOSS:
		# Lichen beards hang from the lower tiers.
		for i in 4:
			var a := float(i) / 4.0 * TAU + 0.4
			var p := Vector3(cos(a) * base_r * 0.7, height * 0.3, sin(a) * base_r * 0.7)
			Craft.blade(k, p, p + Vector3(0, -0.3, 0), 0.07, a, PropModels.sway(P.ASH[3], 0.5))
	if c == Country.BURNING:
		k.prism(0.02, 0.0, 0.0, 0.11, 0.1, 0.1, 5, PropModels.glow(P.EMBER[3], 0.6), Color(0, 0, 0, 0), 0.1)


static func broadleaf(k: MeshKit, v: int, c: int) -> void:
	var s := 2000 + v * 31 + c * 5
	var trunk := P.EARTH[2]
	var leaves: Array[Color] = [P.MOSS[2], P.MOSS[3], P.MOSS[3].lerp(P.SPRUCE[3], 0.5), P.MOSS[3].lerp(P.MOSS[4], 0.4)]
	var crown := true
	var lean := Vector2(Craft.j(s, 1, 0.1), Craft.j(s, 2, 0.1))
	var h := 1.0 + v * 0.12
	var spread := 1.0
	match c:
		Country.COAST:
			lean = Vector2(0.28, 0.08)
			spread = 1.1
		Country.MOSS:
			leaves = [P.MOSS[2].lerp(P.ASH[2], 0.4), P.MOSS[2], P.ASH[3].lerp(P.MOSS[3], 0.5), P.MOSS[3]]
			trunk = P.LINEN[2]
		Country.PINEWOOD:
			leaves = [P.MOSS[1].lerp(P.SPRUCE[2], 0.5), P.MOSS[2], P.SPRUCE[3], P.MOSS[3]]
		Country.BONELANDS:
			# Hawthorn: low, wide, bleached, bent right over.
			leaves = [P.MOSS[3].lerp(P.SAND[4], 0.35), P.MOSS[3], P.MOSS[4].lerp(P.LINEN[4], 0.4), P.MOSS[3].lerp(P.SAND[3], 0.3)]
			lean = Vector2(0.42, 0.12)
			h = 0.72
			spread = 1.25
		Country.SNOWFIELD, Country.BURNING:
			crown = false
			trunk = P.INK[2] if c == Country.BURNING else P.EARTH[1]
	var top := Vector3(lean.x * 0.7, 0.85 * h, lean.y * 0.7)
	k.strut(Vector3(0, 0, 0), top, 0.1, 5, trunk)
	k.strut(Vector3(0, 0, 0), Vector3(0.18, 0.05, -0.1), 0.05, 3, trunk)
	var branch_tips: Array[Vector3] = []
	for i in 3 + v % 2:
		var a := float(i) / (3 + v % 2) * TAU + Craft.j(s, 20 + i, 0.6)
		var tip := top + Vector3(cos(a) * 0.45 * spread, 0.35 + Craft.j(s, 30 + i, 0.15), sin(a) * 0.45 * spread)
		k.strut(top, tip, 0.045, 4, trunk if crown else PropModels.sway(trunk, 0.25))
		branch_tips.append(tip)
	if crown:
		var n := 4 + v
		for i in n:
			var a := float(i) / n * TAU + Craft.j(s, 40 + i, 0.4)
			var rr := 0.34 * spread + Craft.j(s, 50 + i, 0.08)
			var cy := top.y + 0.1 + Craft.j(s, 60 + i, 0.18)
			var col: Color = leaves[i % leaves.size()]
			Craft.blob(k, top.x + cos(a) * rr + lean.x * 0.4, cy, top.z + sin(a) * rr + lean.y * 0.4, 0.42 * spread, 0.72 * h, s + i * 7, PropModels.sway(col, 0.55), 7)
		Craft.blob(k, top.x + lean.x * 0.5, top.y + 0.35, top.z + lean.y * 0.5, 0.46 * spread, 0.8 * h, s + 99, PropModels.sway(leaves[3], 0.8), 7)
		if c == Country.BONELANDS:
			for i in 6:
				var a := float(i) * 1.1
				var p := top + Vector3(cos(a) * 0.5 + lean.x * 0.5, 0.55 + Craft.j(s, 70 + i, 0.2), sin(a) * 0.5)
				k.block(p.x, p.y, p.z, 0.06, 0.06, 0.06, PropModels.sway(P.RUST[3], 0.6))
	else:
		for tip in branch_tips:
			var twig := tip + Vector3(Craft.j(s, int(tip.x * 100.0), 0.2), 0.25, Craft.j(s, int(tip.z * 100.0), 0.2))
			k.strut(tip, twig, 0.02, 3, PropModels.sway(trunk, 0.6))
			if c == Country.SNOWFIELD:
				Craft.blob(k, tip.x, tip.y - 0.02, tip.z, 0.1, 0.07, s + int(tip.x * 50.0), PropModels.sway(P.RIME[5], 0.4), 5)
		if c == Country.BURNING:
			k.prism(0.0, 0.0, 0.0, 0.12, 0.08, 0.1, 5, PropModels.glow(P.EMBER[3], 0.5))
	if v == 2:
		# Grown round an iron hoop, a cable run from it into the ground.
		var hoop := Vector3(top.x * 0.55, 0.5, top.z * 0.55)
		Craft.ring(k, hoop, 0.17, 8, 0.025, P.STONE[1])
		k.block(hoop.x + 0.17, hoop.y - 0.04, hoop.z, 0.05, 0.08, 0.05, P.RUST[2])
		Craft.cable(k, hoop + Vector3(0.16, -0.02, 0.05), Vector3(0.95, 0.0, 0.55), 0.12, 4, 0.022, P.INK[2])


static func dead_tree(k: MeshKit, v: int, c: int) -> void:
	var s := 3000 + v * 13 + c * 7
	var wood := P.ASH[2].lerp(P.LINEN[2], 0.4)
	var dark := P.ASH[1]
	match c:
		Country.BURNING:
			wood = P.INK[2]
			dark = P.INK[1]
		Country.MOSS:
			wood = P.LINEN[2].lerp(P.SPRUCE[2], 0.25)
	var h := 1.6 if v != 2 else 0.75
	var lean := Vector2(Craft.j(s, 1, 0.12), Craft.j(s, 2, 0.12))
	var top := Vector3(lean.x, h, lean.y)
	k.strut(Vector3.ZERO, top * Vector3(0.5, 0.6, 0.5), 0.11, 5, wood)
	k.strut(top * Vector3(0.5, 0.6, 0.5), top, 0.07, 5, wood)
	# Broken top: a jagged splinter.
	k.prism(top.x, top.y, top.z, 0.07, top.y + 0.18, 0.0, 4, dark, Color(0, 0, 0, 0), Craft.j(s, 3, 1.0))
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.7
		k.strut(Vector3(0, 0.08, 0), Vector3(cos(a) * 0.3, -0.02, sin(a) * 0.3), 0.04, 3, wood)
	if v == 2:
		# A split snag: two jagged halves.
		k.prism(0.05, h, 0.0, 0.06, h + 0.3, 0.0, 4, wood)
		k.prism(-0.06, h, 0.02, 0.05, h + 0.14, 0.0, 4, dark)
	else:
		for i in 3 + v:
			var f := 0.45 + i * 0.14
			var a := float(i) * 2.2 + Craft.j(s, 10 + i, 0.4)
			var from := top * f
			var to := from + Vector3(cos(a) * 0.45, 0.3 + Craft.j(s, 20 + i, 0.12), sin(a) * 0.45)
			k.strut(from, to, 0.035, 4, PropModels.sway(wood, 0.2))
			if c == Country.SNOWFIELD:
				k.strut(from + Vector3(0, 0.045, 0), to + Vector3(0, 0.035, 0), 0.02, 3, PropModels.sway(P.RIME[5], 0.2))
	if v == 1:
		# One in three carries a crossarm with two clay insulators, and wire.
		var arm_y := h * 0.86
		k.block(top.x * 0.86, arm_y, top.z * 0.86, 0.08, 0.07, 0.9, P.EARTH[2])
		for side: float in [-0.38, 0.38]:
			var ip := Vector3(top.x * 0.86, arm_y + 0.07, top.z * 0.86 + side)
			k.prism(ip.x, ip.y, ip.z, 0.04, ip.y + 0.1, 0.03, 5, P.RUST[3], P.RUST[4])
			Craft.cable(k, ip + Vector3(0, 0.1, 0), ip + Vector3(1.6, -0.6, side * 0.5), 0.2, 4, 0.012, P.INK[1])
	if c == Country.BURNING:
		k.block(0.06, 0.25, 0.1, 0.02, 0.3, 0.02, PropModels.glow(P.EMBER[3], 0.8))
		k.block(-0.08, 0.5, -0.02, 0.02, 0.2, 0.02, PropModels.glow(P.EMBER[4], 0.6))


static func bush(k: MeshKit, v: int, c: int) -> void:
	var s := 4000 + v * 19 + c * 11
	var cols: Array[Color] = [P.MOSS[2], P.MOSS[3], P.MOSS[2].lerp(P.SPRUCE[3], 0.5)]
	var berries := Color(0, 0, 0, 0)
	var cap := Color(0, 0, 0, 0)
	match c:
		Country.MOSS:
			cols = [P.SPRUCE[2], P.EARTH[2].lerp(P.MOSS[2], 0.5), P.SPRUCE[2].lerp(P.MOSS[3], 0.4)]
		Country.PINEWOOD:
			cols = [P.SPRUCE[1], P.SPRUCE[2], P.SPRUCE[2].lerp(P.SPRUCE[3], 0.5)]
		Country.SNOWFIELD:
			cols = [P.SPRUCE[1], P.SPRUCE[1].lerp(P.ASH[2], 0.4), P.SPRUCE[2]]
			cap = P.RIME[5]
		Country.BONELANDS:
			cols = [P.MOSS[3].lerp(P.SAND[4], 0.35), P.MOSS[3], P.MOSS[4].lerp(P.LINEN[3], 0.35)]
			berries = P.RUST[3]
		Country.BURNING:
			cols = [P.EARTH[1], P.ASH[1], P.EARTH[1].lerp(P.RUST[1], 0.5)]
		Country.COAST:
			berries = P.BLOOM[1] if v == 1 else Color(0, 0, 0, 0)
	var n := 2 + v
	for i in n:
		var a := float(i) / n * TAU + Craft.j(s, i, 0.6)
		var rr := 0.14 + Craft.j(s, 10 + i, 0.06)
		var r := 0.3 - i * 0.03 + Craft.j(s, 20 + i, 0.05)
		var col: Color = cols[i % 3]
		Craft.blob(k, cos(a) * rr, -0.03, sin(a) * rr, r, 0.34 + Craft.j(s, 30 + i, 0.08), s + i * 5, PropModels.sway(col, 0.3), 6)
		if cap.a > 0.0:
			Craft.blob(k, cos(a) * rr, 0.2, sin(a) * rr, r * 0.7, 0.18, s + i * 5 + 1, PropModels.sway(cap, 0.3), 6)
	if berries.a > 0.0:
		for i in 5:
			var a := float(i) * 1.37
			k.block(cos(a) * 0.22, 0.24 + Craft.j(s, 40 + i, 0.06), sin(a) * 0.22, 0.05, 0.05, 0.05, PropModels.sway(berries, 0.3))
	if c == Country.BURNING:
		for i in 4:
			var a := float(i) * 1.6
			k.strut(Vector3(0, 0.1, 0), Vector3(cos(a) * 0.3, 0.45, sin(a) * 0.3), 0.015, 3, PropModels.sway(P.INK[2], 0.4))
		k.block(0.05, 0.02, 0.0, 0.08, 0.04, 0.08, PropModels.glow(P.EMBER[3], 0.5))


static func gorse(k: MeshKit, v: int, c: int) -> void:
	var s := 5000 + v * 23 + c
	var greens: Array[Color] = [P.SPRUCE[2], P.MOSS[2], P.SPRUCE[2].lerp(P.MOSS[3], 0.5)]
	if c == Country.BURNING:
		greens = [P.EARTH[1], P.INK[3], P.EARTH[2]]
	elif c == Country.SNOWFIELD:
		greens = [P.SPRUCE[1], P.SPRUCE[1], P.SPRUCE[2]]
	var n := 3 + v
	for i in n:
		var a := float(i) / n * TAU + Craft.j(s, i, 0.5)
		var rr := 0.18 + Craft.j(s, 10 + i, 0.06)
		Craft.blob(k, cos(a) * rr, -0.02, sin(a) * rr, 0.26, 0.42, s + i * 3, PropModels.sway(greens[i % 3], 0.3), 5, 0.35)
	# Spines stick out of the mass.
	for i in 14:
		var a := float(i) * 2.39996
		var up := 0.12 + fmod(float(i) * 0.37, 0.3)
		var base := Vector3(cos(a) * 0.2, up, sin(a) * 0.2)
		k.strut(base, base + Vector3(cos(a) * 0.18, 0.12, sin(a) * 0.18), 0.012, 3, PropModels.sway(greens[i % 2], 0.45))
	# Flowers: small hard yellow points, many in one variant, few in the other.
	if c != Country.BURNING and c != Country.SNOWFIELD:
		var flowers := 16 if v == 0 else 6
		for i in flowers:
			var a := float(i) * 2.39996 + 0.3
			var r := 0.18 + fmod(float(i) * 0.113, 0.16)
			var y := 0.22 + fmod(float(i) * 0.071, 0.24)
			k.block(cos(a) * r, y, sin(a) * r, 0.055, 0.045, 0.055, PropModels.sway(P.RUST[5] if i % 3 else P.SAND[5], 0.4))


static func reeds(k: MeshKit, v: int, c: int) -> void:
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
	var n := 13 + v * 3
	for i in n:
		var a := Rng.hash01(s, i) * TAU
		var r := sqrt(Rng.hash01(s, i, 1)) * 0.32
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var height := 0.55 + Rng.hash01(s, i, 2) * 0.45
		var bend := Vector3((Rng.hash01(s, i, 3) - 0.5) * 0.24 + 0.06, 0.0, (Rng.hash01(s, i, 4) - 0.5) * 0.24)
		var tip := base + bend + Vector3(0, height, 0)
		var mid := base + bend * 0.35 + Vector3(0, height * 0.55, 0)
		var col: Color = stem[i % 3]
		Craft.blade(k, base, mid, 0.07, a, PropModels.sway(col, 0.0))
		Craft.blade(k, mid + Vector3(0, -0.04, 0), tip, 0.045, a + 0.3, PropModels.sway(col, 1.0))
		if i % 3 == 0:
			k.block(tip.x, tip.y - 0.16, tip.z, 0.05, 0.15, 0.05, PropModels.sway(head, 0.95))
	if v == 1:
		# A cable through the bed, its sheath split back to the copper.
		k.strut(Vector3(-0.7, 0.05, -0.15), Vector3(-0.1, 0.1, 0.0), 0.03, 4, P.INK[2])
		k.strut(Vector3(-0.1, 0.1, 0.0), Vector3(0.12, 0.11, 0.05), 0.022, 4, P.COPPER[3])
		k.strut(Vector3(0.12, 0.11, 0.05), Vector3(0.7, 0.04, 0.2), 0.03, 4, P.INK[2])
