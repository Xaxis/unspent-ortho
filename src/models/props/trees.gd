extends RefCounted
## Things that grow: pines, snow pines, broadleaf, dead trees, bushes, gorse,
## reeds. Grown things are MADE: uneven, leaning, never mirrored. Crowns, tiers
## and blades sway by height; trunks do not. The machine age shows as FOUND
## parts: an iron hoop a tree grew round, a crossarm with insulators on a dead
## tree, a cable split to the copper in reeds.
##
## What colour anything here is comes off the landscape (`BiomeDef.tree_tints`,
## the keys in `BiomeDressing.RAMPS`), and where a landscape has not said, off
## what it HAS said: nothing green survives a scorched one, snow lies in the
## needles of a cold one, and a wind it declares crops every crown in it.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.PINE: pine(k, v, c, false)
		PropKind.SNOW_PINE: pine(k, v, c, true)
		PropKind.BROADLEAF:
			broadleaf(k, v, c)
			_grow_lamp(k, v, c)
		PropKind.DEAD_TREE: dead_tree(k, v, c)
		PropKind.BUSH: bush(k, v, c)
		PropKind.GORSE: gorse(k, v, c)
		PropKind.REEDS: reeds(k, v, c)


## Where a land lights its trees from below after dark (`BiomeDef.underlight`),
## the lamp that does it: a stake at the foot with its head turned up into the
## crown, lamp-coded so it burns only at night. What the crown's underside is
## lit by has to be standing somewhere, or the leaves are only tinted.
static func _grow_lamp(k: Kit, v: int, c: int) -> void:
	var u := BiomeRegistry.by_index(c).underlight
	if u.a <= 0.0:
		return
	var a := Rng.hash01(v, 7, 81) * TAU
	var foot := Vector3(cos(a) * 0.32, 0.0, sin(a) * 0.32)
	var head := foot + Vector3(0.0, 0.16, 0.0)
	k.rod(foot, head, 0.012, 4, P.PLATE[1])
	# MADE, not FOUND: the lamp code is a lamp only on the made surface (on FOUND
	# metal a low alpha is a beacon's blink).
	k.slab(head.x, head.y, head.z, 0.1, 0.04, 0.1, v * 13 + 5, P.PLATE[1], GroundColors.lamp(Color(u.r, u.g, u.b), 2.0), 0.0)


## Kinds whose silhouette leans with the prevailing wind where a landscape
## declares one (`BiomeDressing.wind`): WorldView turns those to one bearing
## instead of a random one, so a whole stand leans the same way.
static func wind_bent(kind: int, c: int) -> bool:
	if BiomeDressing.of(c).wind <= 0.0:
		return false
	return kind == PropKind.BROADLEAF or kind == PropKind.PINE or kind == PropKind.GORSE or kind == PropKind.DEAD_TREE


## How much of a tier's reach its solid keeps once its needles are cards.
const PINE_CORE := 0.74
## How much of the gap to the next tier a tier's solid rises (see `pine`).
const PINE_CORE_RISE := 0.7
## How laden a snow pine's needles are, and a pine that merely stands in the
## snowfield (kit.gd `sprays`, leaf.gdshader). The old lids covered 0.78 and 0.62
## of a tier's reach; these are the same two falls, said as snow.
const PINE_LADEN := 1.0
const PINE_SNOW := 0.62
## What a snowfield bush and a snowfield gorse hold on their tops.
const SCRUB_SNOW := 0.7


## What a pine's tiers are where a landscape has not said: ash and dead where
## nothing green survives, the dark blue-green end of the spruce where snow
## lies, the ordinary spruce anywhere else.
static func needles_of(c: int) -> Array[Color]:
	if BiomeDressing.burnt(c):
		return [P.STONE[0], P.ASH[1], P.EARTH[1]]
	if BiomeDressing.of(c).cold():
		return [P.SPRUCE[1], P.SPRUCE[2], P.SPRUCE[2].lerp(P.SPRUCE[3], 0.5)]
	return [P.SPRUCE[2], P.SPRUCE[3], P.SPRUCE[3].lerp(P.SPRUCE[4], 0.35)]


## A bush's three tones, and a thicket of spines' three.
static func scrub_of(c: int) -> Array[Color]:
	if BiomeDressing.burnt(c):
		return [P.EARTH[1], P.ASH[1], P.EARTH[1].lerp(P.RUST[1], 0.5)]
	if BiomeDressing.of(c).cold():
		return [P.SPRUCE[1], P.SPRUCE[1].lerp(P.ASH[2], 0.4), P.SPRUCE[2]]
	return [P.MOSS[2], P.MOSS[3], P.MOSS[2].lerp(P.SPRUCE[3], 0.5)]


static func gorse_of(c: int) -> Array[Color]:
	if BiomeDressing.burnt(c):
		return [P.EARTH[1], P.ASH[1], P.EARTH[2]]
	if BiomeDressing.of(c).cold():
		return [P.SPRUCE[1], P.SPRUCE[1], P.SPRUCE[2]]
	return [P.SPRUCE[2], P.MOSS[2], P.SPRUCE[2].lerp(P.MOSS[3], 0.5)]


## A standing dead trunk: [the wood, the dark of the break].
static func dead_of(c: int) -> Array[Color]:
	if BiomeDressing.burnt(c):
		# Charred, not black: against pale ash a near-black stick was the
		# highest-contrast mark in the frame (art review 14).
		return [P.INK[3].lerp(P.ASH[1], 0.55), P.INK[3]]
	return [P.ASH[2].lerp(P.LINEN[2], 0.4), P.ASH[1]]


static func reed_of(c: int) -> Array[Color]:
	if BiomeDressing.burnt(c):
		return [P.EARTH[2], P.ASH[2], P.EARTH[1]]
	if BiomeDressing.of(c).cold():
		return [P.ASH[3], P.LINEN[3], P.ASH[4]]
	return [P.SAND[3], P.MOSS[3], P.SAND[4]]


static func pine(k: Kit, v: int, c: int, laden: bool) -> void:
	var d := BiomeDressing.of(c)
	var burnt := BiomeDressing.burnt(c)
	var s := 1000 + v * 17 + c * 3 + (500 if laden else 0)
	var height: float = [2.8, 2.3, 3.3, 2.6][v % 4]
	var base_r: float = [0.72, 0.82, 0.62, 0.7][v % 4]
	var tiers: int = [4, 3, 5, 4][v % 4]
	var points: int = [8, 9, 7, 8][v % 4]
	var lean := Vector2(Kit.j(s, 1, 0.04), Kit.j(s, 2, 0.04))
	var trunk: Color = P.INK[1] if burnt else P.EARTH[1]
	var greens := BiomeDressing.tint(c, &"needle", needles_of(c))
	var under := BiomeDressing.tint1(c, &"under", P.INK[1] if burnt else (P.SPRUCE[0] if d.cold() else P.SPRUCE[1]))
	var snow := laden or d.cold()
	if d.wind > 0.0:
		# Wind-bent: the crown leans downwind and the top is cropped.
		lean = Vector2(d.wind, 0.02)
		height *= 0.85
	if burnt:
		# A burnt pine has fewer tiers, and they are drawn in.
		tiers = maxi(2, tiers - 1)
		base_r *= 0.72
		points = 6
	if laden:
		greens = [P.SPRUCE[1], P.SPRUCE[1].lerp(P.SPRUCE[2], 0.5), P.SPRUCE[2]]
	var top := Vector3(lean.x * height, height * 0.92, lean.y * height)
	k.limb(Vector3.ZERO, top, 0.11, 0.03, 5, trunk, Vector3(Kit.j(s, 3, 0.05), 0, Kit.j(s, 4, 0.05)))
	for i in 3:
		var a := float(i) / 3.0 * TAU + Kit.j(s, 10 + i, 0.5)
		k.spike(Vector3(0, 0.14, 0), Vector3(cos(a) * 0.24, -0.02, sin(a) * 0.24), 0.05, 3, trunk)
	var start := k.made.vertex_count()
	var leaf_start := k.leaf.vertex_count()
	var y0 := height * 0.2
	var y1 := height * 0.8
	# A burnt pine has lost its needles: it keeps the tiers of dead twig and no
	# sprays. Everywhere else the needles are cards.
	var needled := not burnt
	# Snow lies in the needles themselves (leaf.gdshader), never as a lid over
	# them: a laden pine is carrying all it can hold, a snowfield pine a lighter
	# fall the wind has thinned.
	var snowed := (PINE_LADEN if laden else PINE_SNOW) if snow else 0.0
	# The top tier first, because it covers the ones under it (kit.gd `canopy`).
	for t in range(tiers - 1, -1, -1):
		var f := float(t) / maxf(1.0, tiers - 1)
		var r := base_r * (1.0 - f * 0.68)
		var y := lerpf(y0, y1, f)
		var rise := (y1 - y0) / maxf(1.0, tiers - 1) * 1.6 + (0.35 if t == tiers - 1 else 0.0)
		var droop := 0.14 + r * 0.12
		var col := greens[mini(2, int(f * 2.99))]
		var cx := lean.x * y + Kit.j(s, 20 + t, 0.04)
		var cz := lean.y * y + Kit.j(s, 30 + t, 0.04)
		if needled:
			# The tier is the bough's shade now, not its needles: drawn a size in
			# and a step darker, so the sprays reaching past it are what the light
			# finds, and a gap between two sprays shows the inside of the tree.
			# And it is a SKIRT, not a cone: its rise is a share of the gap to
			# the next tier, so from the side there is dark air and trunk
			# between one bough and the next, and a pine reads as stacked
			# drooping tiers. At the full rise the cores overlapped into one
			# tall dark cone, which LOOK.md forbids in so many words.
			var core_rise := minf(rise, (y1 - y0) / maxf(1.0, tiers - 1) * PINE_CORE_RISE) + (0.2 if t == tiers - 1 else 0.0)
			k.tier(cx, y, cz, r * PINE_CORE, core_rise, points, droop * 1.1, s + t * 11, Kit.tone(col, 0.72), under if t == 0 else Color(0, 0, 0, 0))
			var mass: Array[Color] = [Kit.tone(col, NEEDLE_TONE), Kit.tone(col, NEEDLE_TONE), Kit.tone(greens[mini(2, int(f * 2.99) + 1)], NEEDLE_TONE)]
			k.sprays(cx, y, cz, r, rise, droop, points, s + t * 13, mass, Kit.LEAF_NEEDLE, snowed)
		else:
			k.tier(cx, y, cz, r, rise, points, droop, s + t * 11, col, under if t == 0 else Color(0, 0, 0, 0))
	k.sway_by_height(start, y0 - 0.1, height, 0.7)
	k.sway_by_height(leaf_start, y0 - 0.1, height, 0.7, k.leaf)
	if v % 4 == 3 and not laden:
		# A dead spike where the leader broke.
		k.limb(top, top + Vector3(0.05, 0.45, -0.03), 0.03, 0.008, 3, P.ASH[2])
	if BiomeDressing.reedy(c):
		# Lichen beards hang from the lower tiers where the air never dries.
		var bs := k.made.vertex_count()
		for i in 5:
			var a := float(i) / 5.0 * TAU + 0.4
			var p := Vector3(cos(a) * base_r * 0.6, height * 0.24, sin(a) * base_r * 0.6)
			k.blade(p, p + Vector3(0.02, -0.28, 0), 0.07, a, P.ASH[3])
		k.sway_by_height(bs, -10.0, -9.0, 0.5)
	if burnt:
		k.made.prism(0.02, 0.0, 0.0, 0.12, 0.08, 0.1, 5, GroundColors.glow(P.EMBER[3], 0.7))


## A broadleaf's card, edge in tiles: about nineteen pixels at the play camera,
## which is a sprig of five leaves each still a few pixels across.
const BROAD_CARD := 0.26
## A bush's: a sprig of seven small leaves. As big a card as a broadleaf's, because
## at 0.2 each leaf was three pixels at the play camera and a bush came back as
## a speckle of blue-green noise rather than a shrub.
const SMALL_CARD := 0.26
## Gorse: a spray of spines, and deeper, because gorse is a thicket you cannot
## see into, not a crown with daylight in it.
const SPINE_CARD := 0.26
const SPINE_LAYERS := 3.6
## The needles of a pine are a step under the tier's old wash: the pinewood is
## dark under its canopy, and a spray lit on both faces came back a shade of
## teal the wood never was.
const NEEDLE_TONE := 0.82
## Cards per unit of shell, as a multiple of what would tile it once. Above one
## so the outer cards overlap and the gaps show sunk cards in the crown's own
## shade rather than the ground through it; not so far above that the fill is
## paid three times over for nothing the eye can tell apart.
const LAYERS := 2.4


## How many cards a mass of radius `r` and height `h` wants at card size `size`:
## the upper shell's area over a card's, `layers` deep.
static func leaf_cards(r: float, h: float, size: float, layers: float = LAYERS) -> int:
	var shell := TAU * r * (r + h * 0.5) * 0.66
	return clampi(roundi(shell * layers / (size * size)), 6, 90)


static func broadleaf(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var burnt := BiomeDressing.burnt(c)
	var s := 2000 + v * 31 + c * 5
	# A landscape colours its own trees (BiomeDef.tree_tints), so a new one is
	# never drawn in the coast's greens; what it has not said follows from
	# whether anything green survives there and whether snow lies on it.
	var bare_trunk: Color = P.INK[2] if burnt else (P.EARTH[1] if d.cold() else P.EARTH[2])
	var trunk := BiomeDressing.tint1(c, &"trunk", bare_trunk)
	var leaves := BiomeDressing.tint(c, &"leaf",
		[P.MOSS[2], P.MOSS[3], P.MOSS[3].lerp(P.SPRUCE[3], 0.45), P.MOSS[3].lerp(P.MOSS[4], 0.35)])
	# Nothing keeps a leaf where nothing green survives, or under snow.
	var crown := d.crown != &"bare"
	var lean := Vector2(Kit.j(s, 1, 0.08), Kit.j(s, 2, 0.08))
	var h: float = [1.0, 1.15, 0.9, 1.05][v % 4]
	var spread := d.spread
	if d.wind > 0.0:
		# Bent right over downwind, and the harder it blows the further over.
		lean = Vector2(d.wind * 3.5, 0.06 + d.wind * 0.2)
	if d.crown == &"low":
		# A thorn: low, wide and wind-cropped, with haws on it.
		h = 0.72
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
		# Leaf cards, not a lobed solid (kit.gd `canopy` says why). Each mass keeps
		# the one wash it always had, with the crown's top wash through it, so the
		# masses still read apart.
		var start := k.leaf.vertex_count()
		for i in tips.size():
			var tip := tips[i]
			var r := 0.4 * spread + Kit.j(s, 40 + i, 0.06)
			var mass: Array[Color] = [leaves[i % 3], leaves[i % 3], leaves[3]]
			k.canopy(tip.x, tip.y - 0.22, tip.z, r, 0.62 * h, s + i * 7, mass, Kit.LEAF_BROAD, BROAD_CARD, leaf_cards(r, 0.62 * h, BROAD_CARD))
		var crest: Array[Color] = [leaves[3], leaves[3], leaves[0]]
		k.canopy(top.x + lean.x * 0.35, top.y + 0.2, top.z, 0.44 * spread, 0.78 * h, s + 99, crest, Kit.LEAF_BROAD, BROAD_CARD, leaf_cards(0.44 * spread, 0.78 * h, BROAD_CARD))
		k.sway_by_height(start, top.y - 0.2, top.y + 0.9, 0.55, k.leaf)
		if d.crown == &"low" and d.berry.a > 0.0:
			# Haws on the thorn.
			for i in 7:
				var a := float(i) * 1.1
				var p := top + Vector3(cos(a) * 0.52 * spread + lean.x * 0.4, 0.5 + Kit.j(s, 70 + i, 0.2), sin(a) * 0.5 * spread)
				k.fleck(p, p + Vector3(0.05, 0.02, 0.0), p + Vector3(0.02, 0.06, 0.03), d.berry)
	else:
		for tip in tips:
			var twig := tip + Vector3(Kit.j(s, int(tip.x * 100.0), 0.2), 0.28, Kit.j(s, int(tip.z * 100.0), 0.2))
			var ts := k.made.vertex_count()
			k.limb(tip, twig, 0.022, 0.006, 3, trunk)
			k.limb(tip, tip + Vector3(0.18, 0.12, -0.1), 0.015, 0.005, 3, trunk)
			k.sway_by_height(ts, tip.y, twig.y, 0.35)
			if d.cold():
				k.clump(tip.x, tip.y - 0.02, tip.z, 0.1, 0.07, s + int(tip.x * 50.0), d.snow[0], 5)
		if burnt:
			k.made.prism(0.0, 0.0, 0.0, 0.13, 0.08, 0.1, 5, GroundColors.glow(P.EMBER[3], 0.6))
	if v % 4 == 2 and crown:
		# Grown round an iron hoop, a cable run from it into the ground.
		var hoop := Vector3(top.x * 0.5, 0.5 * h, top.z * 0.5)
		k.hoop(hoop, 0.17, 10, 0.022, P.PLATE[2])
		k.cable(hoop + Vector3(0.17, -0.02, 0.0), Vector3(1.0, 0.0, 0.5), 0.12, 5, 0.018, P.INK[2])


static func dead_tree(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var burnt := BiomeDressing.burnt(c)
	var s := 3000 + v * 13 + c * 7
	# TIMBER (row 80), and ONLY here among the things that grow. A snag has lost
	# its bark; what is left is weathered wood, which is what the row is for
	# ("sawn board, weathered post"). The living trees keep the default and that
	# is a measurement, not an oversight: at the play camera a pine or broadleaf
	# is its CANOPY, the trunk is occluded by leaf cards from above, and a bark
	# row would be cost with nothing on the glass to show for it. A dead tree is
	# the one bare trunk a player actually sees -- 0.42 units at the base, about
	# 30 pixels at play zoom -- and it was drawn with no material identity at all.
	var dw := BiomeDressing.tint(c, &"dead", dead_of(c))
	var wood := GroundColors.made(dw[0], GroundColors.TIMBER)
	var dark := dw[1]
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
			if d.cold():
				k.made.strut(from + Vector3(0, 0.045, 0), to + Vector3(0, 0.03, 0), 0.02, 3, d.snow[0])
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
	if burnt:
		k.fleck(Vector3(0.1, 0.2, 0.06), Vector3(0.1, 0.55, 0.05), Vector3(0.14, 0.2, 0.02), GroundColors.glow(P.EMBER[3], 1.0))
		k.fleck(Vector3(-0.08, 0.6, -0.08), Vector3(-0.06, 0.8, -0.1), Vector3(-0.1, 0.6, -0.12), GroundColors.glow(P.EMBER[4], 0.8))


static func bush(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var burnt := BiomeDressing.burnt(c)
	var s := 4000 + v * 19 + c * 11
	var cols := BiomeDressing.tint(c, &"scrub", scrub_of(c))
	# What the scrub here carries, if anything: crowberries, haws, hips.
	var berries := d.berry
	var snow := SCRUB_SNOW if d.cold() else 0.0
	var start := k.made.vertex_count()
	var leaf_start := k.leaf.vertex_count()
	var n := 2 + v % 3
	# What the leaves grow on, seen only through the gaps between them, which is
	# exactly where a bush of cards would otherwise show the ground straight
	# through and read as a hovering cloud.
	for i in 2 + n:
		var a := float(i) * 2.2 + Kit.j(s, 50 + i, 0.4)
		var to := Vector3(cos(a) * 0.22, 0.3 + Kit.j(s, 60 + i, 0.06), sin(a) * 0.22)
		k.limb(Vector3(cos(a) * 0.03, -0.02, sin(a) * 0.03), to, 0.028, 0.01, 3, P.EARTH[1])
	for i in n:
		var a := float(i) / n * TAU + Kit.j(s, i, 0.6)
		var rr := 0.16 + Kit.j(s, 10 + i, 0.06)
		var r := 0.3 - i * 0.02 + Kit.j(s, 20 + i, 0.05)
		var bh := 0.42 + Kit.j(s, 30 + i, 0.08)
		var mass: Array[Color] = [cols[i % 3], cols[i % 3], cols[(i + 1) % 3]]
		# A snowfield bush carries its snow on its leaves, not as a white clump
		# on top of them, which from above was a dome.
		k.canopy(cos(a) * rr, -0.03, sin(a) * rr, r, bh, s + i * 5, mass, Kit.LEAF_SMALL, SMALL_CARD, leaf_cards(r, bh, SMALL_CARD), snow)
	if berries.a > 0.0:
		for i in 7:
			var a := float(i) * 1.37
			var p := Vector3(cos(a) * 0.24, 0.26 + Kit.j(s, 40 + i, 0.08), sin(a) * 0.24)
			k.fleck(p, p + Vector3(0.045, 0.0, 0.01), p + Vector3(0.02, 0.045, 0.0), berries)
	k.sway_by_height(start, 0.0, 0.5, 0.25)
	k.sway_by_height(leaf_start, 0.0, 0.5, 0.25, k.leaf)
	if burnt:
		for i in 4:
			var a := float(i) * 1.6
			k.limb(Vector3(0, 0.1, 0), Vector3(cos(a) * 0.3, 0.46, sin(a) * 0.3), 0.018, 0.005, 3, P.INK[2])
		k.made.prism(0.05, 0.02, 0.0, 0.07, 0.05, 0.05, 5, GroundColors.glow(P.EMBER[3], 0.5))


static func gorse(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 5000 + v * 23 + c
	var greens := BiomeDressing.tint(c, &"gorse", gorse_of(c))
	# A thicket under snow carries it in its spines, never as a lid on top.
	var snow := SCRUB_SNOW if d.cold() else 0.0
	var start := k.made.vertex_count()
	var leaf_start := k.leaf.vertex_count()
	var n := 3 + v
	for i in n:
		var a := float(i) / n * TAU + Kit.j(s, i, 0.5)
		var rr := 0.2 + Kit.j(s, 10 + i, 0.06)
		var mass: Array[Color] = [greens[i % 3], greens[(i + 1) % 3]]
		k.canopy(cos(a) * rr, -0.02, sin(a) * rr, 0.27, 0.5, s + i * 3, mass, Kit.LEAF_SPINE, SPINE_CARD, leaf_cards(0.27, 0.5, SPINE_CARD, SPINE_LAYERS), snow)
	# Spines stick out of the mass.
	for i in 16:
		var a := float(i) * 2.39996
		var up := 0.14 + fmod(float(i) * 0.37, 0.3)
		var base := Vector3(cos(a) * 0.24, up, sin(a) * 0.24)
		k.blade(base, base + Vector3(cos(a) * 0.17, 0.14, sin(a) * 0.17), 0.03, a + 1.57, greens[i % 2])
	# Flowers: small hard yellow points, crowded on one variant.
	if not BiomeDressing.burnt(c) and not d.cold():
		var flowers: int = [22, 9, 15][v % 3]
		for i in flowers:
			var a := float(i) * 2.39996 + 0.3
			# On the skin of the thicket, where the light is: under a mass of spine
			# cards a flower at the old depth was a flower nobody saw.
			var r := 0.36 + fmod(float(i) * 0.113, 0.14)
			var y := 0.32 + fmod(float(i) * 0.071, 0.26)
			var p := Vector3(cos(a) * r, y, sin(a) * r)
			k.fleck(p, p + Vector3(0.05, 0.0, 0.02), p + Vector3(0.02, 0.05, -0.01), P.RUST[5] if i % 3 else P.SAND[5])
	k.sway_by_height(start, 0.0, 0.6, 0.3)
	k.sway_by_height(leaf_start, 0.0, 0.6, 0.3, k.leaf)


static func reeds(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 6000 + v * 29 + c * 13
	var stem := BiomeDressing.tint(c, &"reed", reed_of(c))
	var bare_head: Color = P.INK[2] if BiomeDressing.burnt(c) else (P.RIME[4] if d.cold() else P.EARTH[2])
	var head := BiomeDressing.tint1(c, &"reed_head", bare_head)
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
	if v % 3 == 2 and not d.cold():
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
