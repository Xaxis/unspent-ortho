extends RefCounted
## Things people make and use, and what the machines left standing. The
## stations (fire, bench, kiln) must read at a glance from across a screen, so
## each has one unmistakable shape: flames and a pot on a tripod, a heavy table
## with a vice and a saw, a bottle of brick with a glowing mouth.
##
## MADE (lamp, fire, bench, kiln): uneven, worn, hand-hatched. FOUND (pylon,
## pole): exact, symmetric, clean, violet plate with cold insulators.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
## The grid is the machines' order: it lights itself in their colours, never its own.
const Works := preload("res://src/models/props/works.gd")


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.HAND)
	match kind:
		PropKind.LAMP: lamp_post(k, c)
		PropKind.FIRE: fire(k, c)
		PropKind.BENCH: bench(k)
		PropKind.KILN: kiln(k, v)
		PropKind.PYLON: pylon(k, c)
		PropKind.POLE: pole(k, c)


static func lamp_post(k: Kit, c: int) -> void:
	var wood := P.EARTH[1]
	k.limb(Vector3.ZERO, Vector3(0.05, 1.8, 0.0), 0.07, 0.045, 5, wood)
	k.limb(Vector3(0.04, 1.66, 0.0), Vector3(0.4, 1.7, 0.02), 0.03, 0.022, 4, wood)
	k.limb(Vector3(0.05, 1.38, 0.0), Vector3(0.26, 1.68, 0.02), 0.02, 0.016, 3, P.EARTH[2])
	var lx := 0.4
	k.made.strut(Vector3(lx, 1.7, 0.02), Vector3(lx, 1.6, 0.02), 0.008, 3, P.INK[2])
	# The lantern: a copper cage, glass that is lit when the light goes.
	k.made.prism(lx, 1.28, 0.02, 0.1, 1.3, 0.1, 6, P.COPPER[1])
	k.made.prism(lx, 1.3, 0.02, 0.085, 1.52, 0.085, 6, GroundColors.lamp(P.COPPER[4], 1.6), Color(0, 0, 0, 0), 0.26)
	k.made.prism(lx, 1.52, 0.02, 0.11, 1.62, 0.02, 6, P.INK[2], Color(0, 0, 0, 0), 0.26)
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.26
		k.made.strut(Vector3(lx + cos(a) * 0.09, 1.3, 0.02 + sin(a) * 0.09), Vector3(lx + cos(a) * 0.09, 1.52, 0.02 + sin(a) * 0.09), 0.01, 3, P.COPPER[2])
	k.stone(0.02, -0.06, 0.0, 0.17, 0.14, 1801, P.STONE[2], 5)
	if c == Country.SNOWFIELD:
		k.clump(lx, 1.6, 0.02, 0.1, 0.06, 1802, P.RIME[5], 5)


## The fire station: a ring of stones, logs, a bed of embers, flames, and a pot
## on a tripod. Readable from across a screen by its glow and its tripod.
static func fire(k: Kit, _c: int) -> void:
	for i in 10:
		var a := float(i) / 10.0 * TAU + Kit.j(1901, i, 0.15)
		var r := 0.48 + Kit.j(1902, i, 0.04)
		k.stone(cos(a) * r, -0.05, sin(a) * r, 0.13 + Kit.j(1903, i, 0.03), 0.2, 1910 + i, P.STONE[2] if i % 3 else P.STONE[3], 5)
	k.made.prism(0, -0.02, 0, 0.42, 0.02, 0.4, 9, P.INK[2], P.ASH[1])
	for i in 4:
		var a := float(i) / 4.0 * TAU + 0.3
		k.limb(Vector3(cos(a) * 0.4, 0.04, sin(a) * 0.4), Vector3(cos(a) * 0.04, 0.26, sin(a) * 0.04), 0.05, 0.035, 5, P.EARTH[1] if i % 2 else P.INK[2])
	# Embers: unhatched, glowing.
	for i in 9:
		var a := float(i) * 2.39996
		var r := 0.05 + fmod(i * 0.07, 0.24)
		var p := Vector3(cos(a) * r, 0.03, sin(a) * r)
		k.fleck(p, p + Vector3(0.07, 0.0, 0.03), p + Vector3(0.02, 0.04, 0.07), GroundColors.glow(P.EMBER[3] if i % 2 else P.EMBER[4], 1.4))
	# Flames: tall tongues in two colours, flickering.
	k.hand(Ink.HAND, 0.9, 0.3)
	var fs := k.made.vertex_count()
	for i in 6:
		var a := float(i) / 6.0 * TAU
		var base := Vector3(cos(a) * 0.12, 0.04, sin(a) * 0.12)
		var tip := Vector3(cos(a + 0.6) * 0.04, 0.5 + fmod(i * 0.13, 0.22), sin(a + 0.6) * 0.04)
		k.blade(base, tip, 0.18, a + 1.2, GroundColors.glow(P.EMBER[4], 1.6))
		k.blade(base * 0.5 + Vector3(0, 0.02, 0), tip * Vector3(1, 0.62, 1), 0.1, a + 0.4, GroundColors.glow(P.EMBER[5], 2.0))
	k.sway_by_height(fs, 0.05, 0.7, 0.9)
	k.hand(Ink.HAND)
	# Tripod and pot.
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.9
		k.limb(Vector3(cos(a) * 0.64, 0.0, sin(a) * 0.64), Vector3(0.0, 1.12, 0.0), 0.028, 0.02, 4, P.EARTH[2])
	k.made.strut(Vector3(0, 1.1, 0), Vector3(0, 0.8, 0), 0.008, 3, P.INK[2])
	k.made.prism(0, 0.56, 0, 0.1, 0.62, 0.15, 8, P.INK[2], P.INK[1], 0.0, true)
	k.made.prism(0, 0.62, 0, 0.15, 0.78, 0.12, 8, P.INK[2], P.INK[1])
	k.made.prism(0, 0.78, 0, 0.14, 0.8, 0.14, 8, P.STONE[1], P.INK[0])


## The workbench: a heavy scarred top on splayed legs, a vice, tools, a saw
## hung on its side, and a chopping block with an axe in it.
static func bench(k: Kit) -> void:
	var top := 0.74
	for lx: float in [-0.24, 0.24]:
		for lz: float in [-0.64, 0.64]:
			k.limb(Vector3(lx * 1.25, 0.0, lz * 1.08), Vector3(lx, top, lz), 0.05, 0.04, 4, P.EARTH[2])
	k.slab(0, 0.22, 0, 0.5, 0.05, 1.22, 2000, P.EARTH[2], P.EARTH[3], 0.01)
	k.slab(0, top, 0, 0.64, 0.11, 1.54, 2001, P.EARTH[3], P.EARTH[4], 0.012, 0.0, 0.0)
	k.made.quad(Vector3(0.3, top + 0.116, 0.74), Vector3(0.3, top + 0.116, -0.74), Vector3(0.25, top + 0.116, -0.74), Vector3(0.25, top + 0.116, 0.74), P.EARTH[3])
	# The vice at one end: iron, but a smith's, so drawn by hand.
	k.slab(0.2, top + 0.1, -0.62, 0.14, 0.2, 0.18, 2002, P.STONE[1], P.STONE[2], 0.01)
	k.slab(0.34, top + 0.1, -0.62, 0.08, 0.2, 0.18, 2003, P.STONE[1], P.STONE[3], 0.01)
	k.made.strut(Vector3(0.39, top + 0.18, -0.62), Vector3(0.52, top + 0.18, -0.62), 0.02, 5, P.STONE[3])
	k.made.strut(Vector3(0.52, top + 0.1, -0.62), Vector3(0.52, top + 0.26, -0.62), 0.015, 4, P.EARTH[3])
	# A hammer and offcuts on top.
	k.limb(Vector3(-0.05, top + 0.14, 0.05), Vector3(0.16, top + 0.14, 0.36), 0.02, 0.018, 4, P.EARTH[4])
	k.slab(-0.06, top + 0.11, 0.03, 0.14, 0.07, 0.07, 2004, P.STONE[3], P.STONE[4], 0.005)
	k.slab(-0.1, top + 0.11, 0.46, 0.12, 0.05, 0.3, 2005, P.EARTH[4], P.EARTH[5], 0.01)
	k.slab(0.12, top + 0.11, -0.22, 0.2, 0.03, 0.08, 2006, P.LINEN[4], P.LINEN[5], 0.005)
	# The saw hung on the front.
	var sx := 0.34
	k.made.tri(Vector3(sx, top - 0.05, 0.56), Vector3(sx, top - 0.3, 0.06), Vector3(sx, top - 0.05, 0.06), P.STONE[4])
	k.made.tri(Vector3(sx - 0.003, top - 0.05, 0.06), Vector3(sx - 0.003, top - 0.3, 0.06), Vector3(sx - 0.003, top - 0.05, 0.56), P.STONE[3])
	k.slab(sx, top - 0.14, 0.64, 0.03, 0.14, 0.12, 2007, P.EARTH[4], P.EARTH[4], 0.005)
	# Chopping block with the axe in it, chips about.
	k.made.prism(0.16, 0.0, 1.06, 0.23, 0.38, 0.21, 7, P.EARTH[2], P.EARTH[4])
	k.limb(Vector3(0.19, 0.4, 1.0), Vector3(0.46, 0.73, 1.12), 0.024, 0.02, 4, P.EARTH[4])
	k.made.push(Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.BACK, -0.8), Vector3(0.19, 0.41, 1.02)))
	k.made.tri(Vector3(-0.1, -0.03, 0), Vector3(0.1, -0.05, 0), Vector3(0.1, 0.06, 0), P.STONE[4])
	k.made.tri(Vector3(0.1, 0.06, 0.005), Vector3(0.1, -0.05, 0.005), Vector3(-0.1, -0.03, 0.005), P.STONE[3])
	k.made.pop()
	for i in 7:
		var a := float(i) * 1.9
		var p := Vector3(cos(a) * 0.5 + 0.1, 0.008, sin(a) * 0.4 + 0.62)
		k.fleck(p, p + Vector3(0.06, 0.0, 0.02), p + Vector3(0.02, 0.0, -0.03), P.LINEN[4])


## The kiln: a brick bottle kiln on the coast, a squat lime kiln on the bones.
## Its mouth glows.
static func kiln(k: Kit, v: int) -> void:
	if v % 2 == 0:
		var brick := P.RUST[2]
		k.made.prism(0, 0, 0, 0.74, 0.55, 0.72, 11, brick, brick, 0.1)
		k.made.prism(0, 0.55, 0, 0.72, 1.25, 0.42, 11, P.RUST[3], P.RUST[3], 0.1)
		k.made.prism(0, 1.25, 0, 0.42, 1.72, 0.22, 11, brick, P.INK[1], 0.1)
		k.made.prism(0, 1.72, 0, 0.27, 1.8, 0.27, 11, P.RUST[3], P.INK[0], 0.1)
		# Brick courses, a little uneven.
		for i in 4:
			var y := 0.14 + i * 0.3
			var r := lerpf(0.74, 0.5, y / 1.4) + 0.012
			k.made.prism(Kit.j(2090, i, 0.01), y, 0, r, y + 0.025, r, 11, P.RUST[1], P.RUST[1], 0.1)
		# The arched mouth on the front, glowing.
		var fx := 0.73
		k.made.quad(Vector3(fx, 0.02, 0.24), Vector3(fx, 0.02, -0.24), Vector3(fx, 0.34, -0.24), Vector3(fx, 0.34, 0.24), P.INK[1])
		k.made.tri(Vector3(fx, 0.34, 0.24), Vector3(fx, 0.34, -0.24), Vector3(fx - 0.01, 0.5, 0.0), P.INK[1])
		k.made.quad(Vector3(fx + 0.01, 0.03, 0.17), Vector3(fx + 0.01, 0.03, -0.17), Vector3(fx + 0.01, 0.25, -0.17), Vector3(fx + 0.01, 0.25, 0.17), GroundColors.glow(P.EMBER[3], 1.4))
		k.made.quad(Vector3(fx + 0.012, 0.03, 0.1), Vector3(fx + 0.012, 0.03, -0.1), Vector3(fx + 0.012, 0.14, -0.1), Vector3(fx + 0.012, 0.14, 0.1), GroundColors.glow(P.EMBER[4], 1.8))
		k.made.quad(Vector3(fx - 0.02, 0.5, 0.2), Vector3(fx - 0.02, 0.5, -0.12), Vector3(fx - 0.12, 1.1, -0.06), Vector3(fx - 0.12, 1.1, 0.12), P.INK[2])
		# Fired pots and bricks stacked by the door.
		for i in 3:
			k.made.prism(0.98, 0.0, 0.56 - i * 0.27, 0.08, 0.1, 0.1, 7, P.RUST[4])
			k.made.prism(0.98, 0.1, 0.56 - i * 0.27, 0.1, 0.22, 0.06, 7, P.RUST[4], P.RUST[3])
		for i in 4:
			k.slab(0.92, i * 0.07, -0.6, 0.26, 0.07, 0.13, 2095 + i, P.RUST[3] if i % 2 else P.RUST[2], P.RUST[3], 0.01)
	else:
		var stone := P.LINEN[3]
		k.hand(Ink.CROSS)
		# A squat battered drum of rubble with a dark charging hole, built into
		# the slope, its draw arch standing out in front.
		k.stone(-0.05, -0.06, 0, 0.8, 1.1, 2101, stone, 9, 0.0, P.LINEN[2])
		k.made.prism(-0.05, 1.0, 0, 0.26, 1.03, 0.24, 8, P.INK[1], P.INK[0])
		k.slab(0.6, -0.05, 0, 0.3, 0.72, 0.72, 2103, P.LINEN[2], P.LINEN[3], 0.04, 0.15)
		var fx := 0.755
		k.made.quad(Vector3(fx, 0.0, 0.26), Vector3(fx, 0.0, -0.26), Vector3(fx, 0.42, -0.26), Vector3(fx, 0.42, 0.26), P.INK[1])
		k.made.tri(Vector3(fx, 0.42, 0.26), Vector3(fx, 0.42, -0.26), Vector3(fx - 0.01, 0.64, 0.0), P.INK[1])
		k.made.quad(Vector3(fx + 0.01, 0.02, 0.16), Vector3(fx + 0.01, 0.02, -0.16), Vector3(fx + 0.01, 0.22, -0.16), Vector3(fx + 0.01, 0.22, 0.16), GroundColors.glow(P.EMBER[3], 1.3))
		for i in 5:
			k.stone(1.0 + i * 0.12, -0.05, -0.5 + i * 0.25, 0.14, 0.14, 2110 + i, P.LINEN[4], 5)
		k.made.quad(Vector3(0.75, 0.006, 0.7), Vector3(1.5, 0.006, 0.5), Vector3(1.5, 0.006, -0.6), Vector3(0.75, 0.006, -0.7), P.LINEN[5])


## FOUND: a lattice mast, exact and symmetric, still carrying.
static func pylon(k: Kit, c: int = Country.COAST) -> void:
	var m := P.PLATE[3]
	var br := P.PLATE[2]
	var top := 4.0
	var legs: Array[Vector2] = [Vector2(-0.52, -0.52), Vector2(0.52, -0.52), Vector2(0.52, 0.52), Vector2(-0.52, 0.52)]
	var levels: Array[float] = [0.0, 1.0, 1.9, 2.7, 3.4, 4.0]
	for i in 4:
		var l := legs[i]
		var n := legs[(i + 1) % 4]
		k.rod(_leg(l, 0.0, top), _leg(l, top, top), 0.045, 4, m)
		for li in levels.size():
			var y := levels[li]
			if li > 0:
				k.rod(_leg(l, y, top), _leg(n, y, top), 0.026, 4, br)
			if li < levels.size() - 1:
				var y2 := levels[li + 1]
				k.rod(_leg(l, y, top), _leg(n, y2, top), 0.018, 4, br)
				k.rod(_leg(n, y, top), _leg(l, y2, top), 0.018, 4, br)
		k.chamfer(l.x, -0.04, l.y, 0.24, 0.16, 0.24, 0.05, P.STONE[2], P.STONE[3])
	for arm: Array in [[3.4, 1.15], [2.7, 0.85]]:
		var y: float = arm[0]
		var hw: float = arm[1]
		k.rod(Vector3(0, y, -hw), Vector3(0, y, hw), 0.05, 4, m)
		k.rod(Vector3(0, y - 0.3, -0.2), Vector3(0, y, -hw * 0.8), 0.02, 4, br)
		k.rod(Vector3(0, y - 0.3, 0.2), Vector3(0, y, hw * 0.8), 0.02, 4, br)
		for side: float in [-1.0, 1.0]:
			var p := Vector3(0, y, side * (hw - 0.05))
			k.rod(p, p + Vector3(0, -0.12, 0), 0.01, 4, br)
			for d in 3:
				var yy := p.y - 0.14 - d * 0.06
				k.found.prism(p.x, yy, p.z, 0.045, yy + 0.035, 0.045, 8, P.COLD[2], P.COLD[3])
			# WorldView strings the cables from here to the next mast.
	k.found.prism(0, top, 0, 0.14, top + 0.22, 0.0, 4, P.PLATE[4], Color(0, 0, 0, 0), PI * 0.25)
	# Ink & Neon: the grid keeps its lights. A beacon blinks on the top on a slow
	# machine beat; the crossarms carry a line of cold strip light.
	k.found.prism(0, top + 0.22, 0, 0.07, top + 0.34, 0.05, 6, Works.BEACON)
	for arm2: Array in [[3.4, 1.15], [2.7, 0.85]]:
		k.found.block(0, float(arm2[0]) + 0.05, 0, 0.03, 0.025, float(arm2[1]) * 1.7, Works.lit(Works.STRIP, 0.9))
	if c == Country.SNOWFIELD:
		# Ice on the grid in the snow (MADE: the weather's, not the machine's):
		# rime along each crossarm and icicles of uneven length under it.
		for arm3: Array in [[3.4, 1.15], [2.7, 0.85]]:
			var y: float = arm3[0]
			var hw: float = arm3[1]
			k.made.strut(Vector3(0.0, y + 0.045, -hw), Vector3(0.0, y + 0.045, hw), 0.03, 3, P.RIME[5])
			var n := 9 if hw > 1.0 else 7
			for i in n:
				var z := -hw + 0.08 + (hw * 2.0 - 0.16) * (i + Kit.j(1650, i, 0.3) + 0.5) / n
				var length := 0.12 + Rng.hash01(1651, i, int(hw * 10.0)) * 0.3
				k.made.prism(0.0, y - 0.03 - length, z, 0.0, y - 0.02, 0.04, 4, P.RIME[3] if i % 2 else P.RIME[2])
		k.made.strut(Vector3(0.0, 4.02, 0.0), Vector3(0.0, 4.12, 0.0), 0.09, 4, P.RIME[5])


static func _leg(l: Vector2, y: float, top: float) -> Vector3:
	var f := 1.0 - y / top * 0.74
	return Vector3(l.x * f, y, l.y * f)


## FOUND: a pole with a crossarm and two insulators, exact, a plate on it.
static func pole(k: Kit, c: int = Country.COAST) -> void:
	k.found.prism(0, -0.02, 0, 0.11, 0.18, 0.1, 8, P.PLATE[1], P.PLATE[2])
	k.found.prism(0, 0.18, 0, 0.06, 2.8, 0.048, 8, P.PLATE[3], P.PLATE[4])
	k.found.prism(0, 2.8, 0, 0.05, 2.9, 0.035, 6, Color(1.0, 0.3, 0.35, 0.3))
	k.rod(Vector3(0, 2.52, -0.5), Vector3(0, 2.52, 0.5), 0.04, 4, P.PLATE[3])
	k.rod(Vector3(0, 2.2, 0), Vector3(0, 2.52, -0.34), 0.015, 4, P.PLATE[2])
	k.rod(Vector3(0, 2.2, 0), Vector3(0, 2.52, 0.34), 0.015, 4, P.PLATE[2])
	for side: float in [-0.42, 0.42]:
		k.found.prism(0, 2.55, side, 0.035, 2.7, 0.03, 8, P.COLD[2], P.COLD[3])
		k.found.prism(0, 2.6, side, 0.05, 2.62, 0.05, 8, P.COLD[1], P.COLD[2])
		k.rod(Vector3(0, 2.68, side), Vector3(0, 2.72, side), 0.012, 4, P.INK[1])
	k.found.quad(Vector3(0.062, 1.1, 0.07), Vector3(0.062, 1.1, -0.07), Vector3(0.062, 1.3, -0.07), Vector3(0.062, 1.3, 0.07), P.RIME[5])
	k.found.quad(Vector3(0.064, 1.18, 0.05), Vector3(0.064, 1.18, -0.05), Vector3(0.064, 1.2, -0.05), Vector3(0.064, 1.2, 0.05), P.INK[1])
	if c == Country.SNOWFIELD:
		# Ice on the crossarm and a cap of rime (MADE: the weather's).
		k.made.strut(Vector3(0.0, 2.56, -0.5), Vector3(0.0, 2.56, 0.5), 0.045, 3, P.RIME[4])
		for i in 6:
			var z := -0.45 + i * 0.18 + Kit.j(1660, i, 0.04)
			var length := 0.14 + Rng.hash01(1661, i) * 0.3
			k.made.prism(0.0, 2.5 - length, z, 0.0, 2.51, 0.04, 4, P.RIME[3] if i % 2 else P.RIME[2])
		k.made.prism(0.0, 2.9, 0.0, 0.08, 2.98, 0.04, 5, P.RIME[5])
