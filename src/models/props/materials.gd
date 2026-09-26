extends RefCounted
## What only one land gives a smith (GEAR.md §11, the land materials): the thing
## a player walks out to a landscape for, drawn so it is known from a way off and
## read close as what it is made of.
##
##   GRAFT_TREE    the grey orchards: a planted tree, rootstock and scion, the
##                 union clamped in the plan's steel band. MADE bark, FOUND band.
##   MOSS_CORE     the green towers: a drum of packed moss and root cable that
##                 fell out of a tower's wall, a collar of its concrete still on.
##   SERVER_BLADE  the server fields: a blade pulled out of a rack, finned, its
##                 light still on. All FOUND, it was never touched by hand.
##   MIDDEN_BALE   the middens: stuff sorted by hand and bound in rope, a tarp
##                 over it and a tag on it. The metropolis's bale is the plan's,
##                 pressed square; this one is people's, and lumpy.
##   DRIPSTONE     the limestone caves: a stalagmite and its skirt, ringed where
##                 the drip ran thick and thin, in the caves' own stone.
##
## Nothing here branches on a landscape by name: colours come from the land's
## dressing and tints, so a kind dealt elsewhere stands in that land's colours.
## A model faces +X.
##
##   tools/shot.sh shots/materials.png --scene=gallery --filter=materials

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Trees := preload("res://src/models/props/trees.gd")

const KINDS: Array[int] = [PropKind.GRAFT_TREE, PropKind.MOSS_CORE, PropKind.SERVER_BLADE,
	PropKind.MIDDEN_BALE, PropKind.DRIPSTONE]


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.GRAFT_TREE: graft_tree(k, v, c)
		PropKind.MOSS_CORE: moss_core(k, v, c)
		PropKind.SERVER_BLADE: server_blade(k, v, c)
		PropKind.MIDDEN_BALE: midden_bale(k, v, c)
		PropKind.DRIPSTONE: dripstone(k, v, c)


## A PLANTED TREE, AND IT SAYS SO. A short rootstock, the union swollen where the
## scion took, the plan's steel band still clamped round it, and above it a pale
## scion pruned to an open bowl of four limbs the way an orchard is kept. Grey
## leaves in the orchard's own tint. Variant 0 carries fruit nobody picks; 1 has a
## limb sawn back to a sealed stub, the tree going over.
static func graft_tree(k: Kit, v: int, c: int) -> void:
	var s := 51000 + v * 31 + c * 5
	var stock := BiomeDressing.tint1(c, &"trunk", P.EARTH[1])
	var scion := stock.lerp(P.ASH[3], 0.35)
	var leaves := BiomeDressing.tint(c, &"leaf",
		[P.MOSS[2].lerp(P.ASH[3], 0.4), P.MOSS[3].lerp(P.ASH[3], 0.45), P.SPRUCE[3].lerp(P.ASH[4], 0.4), P.ASH[4]])
	var union := Vector3(0.0, 0.34, 0.0)
	k.limb(Vector3.ZERO, union, 0.11, 0.1, 6, stock, Vector3(Kit.j(s, 1, 0.03), 0, Kit.j(s, 2, 0.03)))
	# The union: a knuckle of new wood over the old, the band clamped across it.
	k.clump(0.0, union.y - 0.08, 0.0, 0.15, 0.16, s + 3, stock.lerp(scion, 0.5), 7)
	k.hoop(union + Vector3(0, 0.02, 0), 0.155, 12, 0.03, P.PLATE[2])
	k.hoop(union + Vector3(0, 0.07, 0), 0.15, 12, 0.018, P.PLATE[3])
	var head := Vector3(Kit.j(s, 4, 0.03), 0.78, Kit.j(s, 5, 0.03))
	k.limb(union, head, 0.09, 0.075, 6, scion)
	# Four scaffold limbs, an open bowl, pruned square to the row they stand in.
	var tips: Array[Vector3] = []
	for i in 4:
		var a := float(i) * TAU / 4.0 + PI * 0.25 + Kit.j(s, 10 + i, 0.2)
		var cut := v == 1 and i == 2
		var reach := 0.22 if cut else 0.5
		var tip := head + Vector3(cos(a) * reach, 0.3 if cut else 0.52 + Kit.j(s, 20 + i, 0.08), sin(a) * reach)
		k.limb(head, tip, 0.05, 0.04 if cut else 0.025, 5, scion)
		if cut:
			# Sawn back and sealed: the paint over the cut is the plan's grey.
			k.clump(tip.x, tip.y - 0.03, tip.z, 0.055, 0.05, s + 30, P.SLATE[3], 5)
			continue
		tips.append(tip)
	var start := k.leaf.vertex_count()
	for i in tips.size():
		var tip := tips[i]
		var mass: Array[Color] = [leaves[i % 3], leaves[(i + 1) % 3], leaves[3]]
		k.canopy(tip.x, tip.y - 0.2, tip.z, 0.34, 0.5, s + i * 7, mass, Kit.LEAF_BROAD, Trees.BROAD_CARD,
			Trees.leaf_cards(0.34, 0.5, Trees.BROAD_CARD))
	k.sway_by_height(start, head.y, head.y + 0.9, 0.45, k.leaf)
	if v == 0:
		# Fruit nobody picks, gone the grey of everything here.
		for i in 9:
			var tip := tips[i % tips.size()]
			var p := tip + Vector3(Kit.j(s, 40 + i, 0.3), -0.18 + Kit.j(s, 50 + i, 0.12), Kit.j(s, 60 + i, 0.3))
			k.fleck(p, p + Vector3(0.05, 0.02, 0.0), p + Vector3(0.01, 0.06, 0.04), P.RUST[3].lerp(P.ASH[4], 0.45))


## A DRUM OF MOSS OUT OF A TOWER'S WALL. What held the green towers' face up
## came away in plugs: moss packed hard round a knot of root cable, a collar of
## the wall's concrete still round one end. It lies on its side (0) or stands on
## end where it landed (1), roots out of it like wire.
static func moss_core(k: Kit, v: int, c: int) -> void:
	var s := 52000 + v * 31 + c * 5
	var moss := BiomeDressing.tint(c, &"leaf", [P.MOSS[2], P.MOSS[3], P.SPRUCE[2], P.MOSS[4]])
	var concrete := BiomeDressing.of(c).stone[0] if not BiomeDressing.of(c).stone.is_empty() else P.SLATE[3]
	var a := Vector3(-0.7, 0.42, 0.0) if v == 0 else Vector3(0.0, 0.0, 0.0)
	var b := Vector3(0.7, 0.4, 0.05) if v == 0 else Vector3(0.05, 1.3, 0.02)
	# The drum under it, thinner than what grew on it, so the moss is the shape.
	k.limb(a, b, 0.3, 0.28, 7, moss[2], Vector3(0, Kit.j(s, 1, 0.05), Kit.j(s, 2, 0.08)))
	# Packed moss round it in cushions, each its own green: a plug of a living
	# wall, not a can. Rings of four round the drum, every ring turned a little.
	var axis0 := (b - a).normalized()
	var side0 := axis0.cross(Vector3.UP if absf(axis0.y) < 0.9 else Vector3.RIGHT).normalized()
	var up0 := side0.cross(axis0).normalized()
	for ring in 6:
		var t := (float(ring) + 0.5) / 6.0
		var at := a.lerp(b, t)
		for q in 4:
			var ang := float(q) * TAU / 4.0 + float(ring) * 0.7 + Kit.j(s, 10 + ring * 4 + q, 0.3)
			var p := at + (side0 * cos(ang) + up0 * sin(ang)) * 0.26
			if p.y < 0.06:
				continue
			k.clump(p.x, p.y - 0.09, p.z, 0.16 + Kit.j(s, 40 + ring * 4 + q, 0.03), 0.16, s + 60 + ring * 4 + q, moss[(ring + q) % 4], 6, 0.3)
	# The collar: the wall's concrete, broken off square at one end.
	var ring := a.lerp(b, 0.08)
	var axis := (b - a).normalized()
	k.hoop(ring, 0.47, 10, 0.07, P.SLATE[2], axis)
	k.hoop(ring + axis * 0.1, 0.45, 10, 0.05, P.SLATE[3], axis)
	k.stone(ring.x - axis.x * 0.1, maxf(0.0, ring.y - 0.45), ring.z, 0.2, 0.22, s + 40, concrete, 5)
	# The root cable it was grown round, out at the broken end: dark, thin and
	# curling, root and wire twisted together.
	var end := b + axis * 0.05
	for i in 7:
		var out := end + axis * (0.35 + Rng.hash01(s, i, 50) * 0.45) + Vector3(Kit.j(s, 60 + i, 0.4), Kit.j(s, 70 + i, 0.25) - 0.12, Kit.j(s, 80 + i, 0.4))
		var from := end + Vector3(Kit.j(s, 90 + i, 0.16), Kit.j(s, 95 + i, 0.16), Kit.j(s, 99 + i, 0.16))
		k.limb(from, out, 0.03, 0.008, 4, P.INK[2] if i % 3 else P.EARTH[0], Vector3(Kit.j(s, 110 + i, 0.15), 0.1, Kit.j(s, 120 + i, 0.15)))


## A BLADE PULLED OUT OF A RACK. Every slot of a server field held one, and they
## come out whole: a long thin case, a face of fins, the handle it was drawn by
## and one light that has not been told to stop. Jammed upright in the earth
## where it was dropped (0), or three fanned where somebody stacked them (1).
static func server_blade(k: Kit, v: int, c: int) -> void:
	var s := 53000 + v * 31 + c * 5
	if v == 0:
		_blade(k, Vector3(0.0, -0.08, 0.0), 0.0, Kit.j(s, 1, 0.12), s, true)
		return
	# Stacked fins up, and only the top one's fins drawn: under the next blade a
	# face of fins is triangles no bearing sees (tests/render/test_found_drawn.gd).
	for i in 3:
		var at := Vector3(float(i) * 0.08 - 0.08, 0.02 + float(i) * 0.12, Kit.j(s, 10 + i, 0.05))
		_blade(k, at, -PI * 0.5, 0.35 - float(i) * 0.3 + Kit.j(s, 20 + i, 0.1), s + i, i == 2)


## One blade: 0.9 long, 0.12 thick, 0.6 deep, standing on its long edge; `lie`
## tips it over onto its side, `turn` turns it on the ground; `fins` draws its
## face, label and handle, which a blade lying under another never shows.
static func _blade(k: Kit, at: Vector3, lie: float, turn: float, s: int, fins: bool) -> void:
	var basis := Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, lie)
	k.found.push(Transform3D(basis, at))
	k.chamfer(0.0, 0.0, 0.0, 0.9, 0.62, 0.12, 0.02, P.PLATE[2], P.PLATE[3])
	# The fins on its face, ruled, each catching the light a step apart.
	for i in (11 if fins else 0):
		var x := -0.38 + float(i) * 0.076
		k.plate(Vector3(x, 0.08, 0.065), Vector3(x + 0.03, 0.08, 0.065), Vector3(x + 0.03, 0.54, 0.065), Vector3(x, 0.54, 0.065),
			P.PLATE[4] if i % 2 else P.PLATE[3], P.PLATE[2], P.PLATE[4])
	if fins:
		# The plan's label across its end: which rack and which slot, ruled.
		# Wound to face OUT along +X: the other order faced it into the case, where no
		# bearing of the play camera sees it (tests/render/test_found_drawn.gd).
		k.plate(Vector3(0.451, 0.06, 0.05), Vector3(0.451, 0.06, -0.05), Vector3(0.451, 0.56, -0.05), Vector3(0.451, 0.56, 0.05),
			P.SAND[4], P.SAND[3], P.SAND[2])
		# The handle it was drawn by, at the end that faced the aisle.
		k.rod(Vector3(0.46, 0.2, 0.0), Vector3(0.54, 0.2, 0.0), 0.02, 4, P.PLATE[4])
		k.rod(Vector3(0.54, 0.2, 0.0), Vector3(0.54, 0.42, 0.0), 0.02, 4, P.PLATE[4])
		k.rod(Vector3(0.46, 0.42, 0.0), Vector3(0.54, 0.42, 0.0), 0.02, 4, P.PLATE[4])
	k.found.pop()
	# Its one light, still on: a fleck in a glow colour (GroundColors.glow), lit
	# rather than a material.
	var lamp := at + basis * Vector3(0.44, 0.52, 0.07)
	k.fleck(lamp, lamp + basis * Vector3(0.03, 0.0, 0.0), lamp + basis * Vector3(0.0, 0.03, 0.0), GroundColors.glow(P.MOSS[4], 0.9))


## A BALE PEOPLE SORTED. What the middens' people pick out of the heaps they
## bind by hand: a lumpy heap of one thing, rope netted over it and knotted to
## stakes, a tarp across the top against the wet and a tag saying whose it is.
## Three sorts, as the metropolis's has three, but nothing here is square: wire
## (0), cloth and plastic (1), bottle glass (2).
static func midden_bale(k: Kit, v: int, c: int) -> void:
	var s := 54000 + v * 37 + c * 5
	var body: Color = [P.RUST[2], P.EARTH[3], P.SLATE[4]][v % 3]
	var top: Color = [P.RUST[3], P.EARTH[4], P.RIME[3]][v % 3]
	k.clump(0.0, 0.0, 0.0, 0.62, 0.78, s, body, 8, 0.25)
	k.clump(0.18, 0.32, -0.1, 0.36, 0.42, s + 1, top, 7, 0.2)
	# The rope, netted over it: four runs over the top and one round the waist.
	for i in 4:
		var a := float(i) * PI * 0.5 + 0.35
		var foot := Vector3(cos(a) * 0.66, 0.02, sin(a) * 0.66)
		var over := Vector3(cos(a + PI) * 0.66, 0.02, sin(a + PI) * 0.66)
		if i < 2:
			k.cable(foot, over, -0.86, 6, 0.018, P.SAND[3])
	k.hoop(Vector3(0.0, 0.34, 0.0), 0.64, 10, 0.018, P.SAND[3])
	# The tarp over the top, weighted at its corners, wound to face the sky (the
	# other order laid it face down, seen from no bearing).
	k.plate(Vector3(-0.36, 0.66, 0.42), Vector3(0.46, 0.7, 0.36), Vector3(0.38, 0.8, -0.4), Vector3(-0.42, 0.74, -0.34),
		P.SPRUCE[2], P.SPRUCE[1], P.SPRUCE[3])
	# The tag, on a string at the front: whose it is.
	k.cable(Vector3(0.6, 0.5, 0.05), Vector3(0.7, 0.34, 0.08), 0.02, 3, 0.008, P.SAND[3])
	k.plate(Vector3(0.7, 0.28, 0.02), Vector3(0.7, 0.28, 0.14), Vector3(0.7, 0.4, 0.14), Vector3(0.7, 0.4, 0.02), P.SAND[4], P.SAND[2], P.SAND[3])
	match v % 3:
		0:
			for i in 6:
				var p := Vector3(Kit.j(s, 10 + i, 0.4), 0.55 + Rng.hash01(s, i, 11) * 0.2, Kit.j(s, 20 + i, 0.4))
				k.spike(p, p + Vector3(Kit.j(s, 30 + i, 0.25), 0.15, Kit.j(s, 40 + i, 0.25)), 0.012, 3, P.RUST[3])
		1:
			for i in 4:
				var a := float(i) * 1.6
				var p := Vector3(cos(a) * 0.55, 0.3 + float(i) * 0.08, sin(a) * 0.55)
				k.clump(p.x, p.y, p.z, 0.1, 0.08, s + 50 + i, [P.MOSS[3], P.RUST[4], P.SLATE[4], P.EARTH[4]][i], 5)
		_:
			for i in 10:
				var a := float(i) * 0.63
				var p := Vector3(cos(a) * 0.6, 0.18 + Rng.hash01(s, i, 12) * 0.5, sin(a) * 0.6)
				k.fleck(p, p + Vector3(0.05, 0.03, 0.0), p + Vector3(0.0, 0.06, 0.03), GroundColors.glint(P.RIME[4] if i % 2 else P.MOSS[4]))


## THE DRIP'S OWN WORK. A stalagmite in the caves' stone, ringed where the drip
## ran thick and thin over the years, standing on the skirt it built round its
## foot. One tall (0), a pair (1), or a cluster of three (2).
static func dripstone(k: Kit, v: int, c: int) -> void:
	var s := 55000 + v * 31 + c * 5
	var d := BiomeDressing.of(c)
	var rock: Array[Color] = d.stone if d.stone.size() >= 3 else [P.SAND[3], P.SAND[4], P.SAND[2]]
	var spikes: Array[Vector3] = [Vector3(0.0, 1.9, 0.0)]
	if v == 1:
		spikes = [Vector3(-0.12, 1.5, 0.0), Vector3(0.26, 0.95, 0.14)]
	elif v == 2:
		spikes = [Vector3(0.0, 1.35, 0.0), Vector3(0.3, 0.8, -0.18), Vector3(-0.24, 0.6, 0.22)]
	# The skirt: the flowstone the drip laid round its foot.
	k.stone(0.0, 0.0, 0.0, 0.5, 0.12, s, rock[1], 9, 0.0, rock[2])
	for i in spikes.size():
		var foot := Vector3(spikes[i].x, 0.06, spikes[i].z)
		var h := spikes[i].y
		var r := 0.12 + h * 0.08
		# Rings, thick and thin, each a band of the stone a shade off the last.
		var n := 4 + i
		for b in n:
			var y0 := foot.y + h * float(b) / n
			var y1 := foot.y + h * float(b + 1) / n
			var r0 := r * (1.0 - float(b) / n) + 0.015
			var r1 := r * (1.0 - float(b + 1) / n) + 0.008
			var off := Vector3(Kit.j(s, 10 * i + b, 0.02), 0, Kit.j(s, 10 * i + b + 5, 0.02))
			k.limb(foot + off * float(b) + Vector3(0, y0 - foot.y, 0), foot + off * float(b + 1) + Vector3(0, y1 - foot.y, 0),
				r0, r1, 7, rock[(b + i) % 2] if b % 2 == 0 else Kit.tone(rock[0], 1.12))
