extends RefCounted
## What stands in the Drowned City (docs/LANDSCAPES.md §5). The water is the
## street here, so everything is either how people meet the water — a stair cut
## down off a quay into it, a crowd of piles a boat was tied to before the jetty
## went — or what the water took and left standing in it: a tram half sunk in
## the silt with a net somebody hung over its windows. And the plan's own: a
## gate leaf in a lock, ruled steel in a stone recess.
##
## Two pens, by what a thing IS. Stone somebody cut is MADE and tagged CUTSTONE
## (matter row 91): a quay's steps and a lock's recess were dressed by hand. The
## piles are TIMBER and their lashing ROPE. The tram and the gate are FOUND,
## ruled, and carry no mark in their alpha, because on that pen an alpha is a
## lamp. The net over the tram's windows is people's, so it is drawn on the
## MADE pen over the found body, tagged ROPE.
##
## Weed is drawn but not tagged: it is growth, and a GROUND mark on made
## geometry would pull the landscape's own ground treatment over it (CLAUDE.md,
## the tagging trap), so the green below the tide line is a plain made colour.
##
## Every model faces +X, like every prop. A stair's +X is the WATER: it goes
## down that way off the quay it stands on.
##
## The gallery (`tools/shot.sh shots/x.png --scene=gallery --filter=drowned`)
## shows every kind here in the drowned city's own dressing, and beside them the
## two machines the landscape keeps to itself, so one frame answers whether the
## city's things read as one place.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Remains := preload("res://src/models/props/remains.gd")
## The machines' gallery helper, reached by path (it carries no class_name).
const MG := preload("res://src/models/machines/machine_gallery.gd")

## Weed below the tide line: green-black and slick, never tagged (see above).
static var WEED: Color = P.SPRUCE[1].lerp(P.MOSS[2], 0.35)
static var WEED_LIT: Color = P.MOSS[2].lerp(P.SPRUCE[2], 0.3)
## A tram's paint, what the sea left of it: FOUND stock, unmarked.
static var TRAM: Color = P.PLATE[2].lerp(P.SPRUCE[2], 0.25)
static var TRAM_TOP: Color = P.PLATE[3].lerp(P.LINEN[2], 0.2)
static var LIVERY: Color = P.LINEN[2].lerp(P.PLATE[2], 0.45)


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.STAIR_TO_WATER: stair_to_water(k, v, c)
		PropKind.DROWNED_TRAM: drowned_tram(k, v, c)
		PropKind.MOORING_POST: mooring_post(k, v, c)
		PropKind.LOCK_GATE: lock_gate(k, v, c)


## The landscape's stone, dressed: what a quay and a lock's recess are cut from.
static func cut_stone(c: int, i: int = 0) -> Color:
	var st := BiomeDressing.of(c).stone
	return GroundColors.made(st[i % st.size()], GroundColors.CUTSTONE)


# --- how people met the water ------------------------------------------------------

## A stone stair going down off a quay into the water, its lower treads green
## with weed and slick, a cheek wall either side stepping down with it, and an
## iron ring let into the top of one cheek for a boat's line. Two units along
## the water, 1.2 across. 0: whole; 1: one cheek broken off and a tread gone.
static func stair_to_water(k: Kit, v: int, c: int) -> void:
	var s := 50100 + v * 29 + c
	var steps := 6
	var run := 0.34
	var rise := 0.19
	for i in steps:
		if v == 1 and i == 3:
			continue
		var top := 0.04 - i * rise
		var x := i * run + run * 0.5
		var wet := top < -0.15
		var tread := GroundColors.down(cut_stone(c, i), 0.35 if not wet else 0.9)
		k.slab(x, -1.3, 0.0, run + 0.02, top + 1.3, 1.16, s + i, tread, WEED if wet else GroundColors.up(tread, 0.1), 0.02)
		if wet:
			# Weed hanging off the nose of each drowned tread.
			for j in 3:
				var z := -0.4 + j * 0.4 + Kit.j(s, i * 3 + j, 0.1)
				k.blade(Vector3(x + run * 0.5, top, z), Vector3(x + run * 0.62, top - 0.16, z + Kit.j(s, i * 5 + j, 0.05)), 0.07, 0.0, WEED_LIT)
	# The cheek walls, stepping down with the flight: three courses a side, the
	# stone dressed square, the top course a coping a hair proud of the face.
	for sz: float in [-1.0, 1.0]:
		if v == 1 and sz > 0.0:
			# Broken: only its root stands, and what came off it lies on the treads.
			k.slab(0.35, -1.3, sz * 0.7, 0.7, 1.55, 0.26, s + 40, cut_stone(c, 2), GroundColors.up(cut_stone(c, 2), 0.1), 0.03)
			for j in 3:
				k.stone(1.1 + j * 0.3, -0.5 - j * 0.12, 0.35 + Kit.j(s, j + 50, 0.12), 0.1 + j * 0.02, 0.08, s + 50 + j, cut_stone(c, j), 5)
			continue
		for j in 3:
			var x0 := j * 0.72
			var top := 0.3 - j * 0.55
			var col := GroundColors.down(cut_stone(c, j + (1 if sz > 0.0 else 0)), 0.3)
			k.slab(x0 + 0.36, -1.3, sz * 0.7, 0.72, top + 1.3, 0.26, s + 30 + j + int(sz) * 5, col, GroundColors.up(col, 0.12), 0.03)
			# Wet below the tide line: the lower courses go green.
			# Wound to face outward on either side, or it draws from no bearing.
			if top < 0.0:
				var a := Vector3(x0, top - 0.02, sz * 0.831)
				var b := Vector3(x0 + 0.72, top - 0.02, sz * 0.831)
				var lo := Vector3(0, -0.48, 0)
				if sz > 0.0:
					k.made.quad(a, b, b + lo, a + lo, WEED)
				else:
					k.made.quad(b, a, a + lo, b + lo, WEED)
	# The iron ring on the top of the near cheek, and its staple: what a boat
	# was tied to at the foot of the stair, still bright where a rope wore it.
	k.rod(Vector3(0.2, 0.3, -0.7), Vector3(0.2, 0.36, -0.7), 0.05, 6, P.PLATE[1])
	k.hoop(Vector3(0.2, 0.44, -0.7), 0.09, 8, 0.016, P.RUST[2], Vector3.BACK)
	# Rust run down the cheek from the staple.
	Remains.streak(k, Vector3(0.2, 0.28, -0.831), 0.06, 0.4, Vector3.FORWARD, P.RUST[2])


## A crowd of timber piles leaned together where a jetty used to be, lashed at
## the head with rope and an iron band, weed and barnacles up them to the tide
## line, and a length of rope trailing off into the water. What a boat is
## moored to now the planking has gone. Three variants: three, four and five
## piles, each leaning its own way.
static func mooring_post(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 50300 + v * 31 + c
	var piles := 3 + v
	var rope := GroundColors.made(P.SAND[2].lerp(P.EARTH[2], 0.3), GroundColors.ROPE)
	var heads: Array[Vector3] = []
	var s0 := k.made.vertex_count()
	for i in piles:
		var a := float(i) / piles * TAU + Kit.j(s, i, 0.3)
		var foot := Vector3(cos(a), 0.0, sin(a)) * (0.16 + Rng.hash01(s, i, 2) * 0.06)
		var head := Vector3(cos(a) * 0.05, 1.3 + Rng.hash01(s, i, 3) * 0.35, sin(a) * 0.05)
		var timber := GroundColors.made(dress.timber[i % dress.timber.size()], GroundColors.TIMBER)
		k.limb(foot + Vector3(0, -0.2, 0), head, 0.085, 0.07, 7, timber)
		heads.append(head)
	# The piles, welded round: a pile is a trunk, and eight flat facets under a real
	# sun read as a pencil.
	k.made.smooth_range(s0, k.made.vertex_count())
	# The tops, cut square and grey where the weather gets at the end grain.
	for h: Vector3 in heads:
		k.stone(h.x, h.y - 0.02, h.z, 0.075, 0.03, s + int(h.y * 100.0), GroundColors.made(dress.timber[0].lerp(P.ASH[3], 0.3), GroundColors.TIMBER), 7)
	# The lashing: two turns of rope round the crowd near the head, and the
	# iron band a hand under it.
	for y: float in [1.05, 1.15]:
		var r := 0.2
		for j in 8:
			var a0 := j * TAU / 8.0
			var a1 := (j + 1) * TAU / 8.0
			k.made.strut(Vector3(cos(a0) * r, y + j * 0.004, sin(a0) * r), Vector3(cos(a1) * r, y + (j + 1) * 0.004, sin(a1) * r), 0.02, 4, rope)
	k.hoop(Vector3(0, 0.82, 0), 0.215, 10, 0.018, P.RUST[1])
	# A line off it into the water, the knot at the post and the end gone slack.
	var out := Vector3(1.0, 0.0, Kit.j(s, 9, 0.6)).normalized()
	k.sag(Vector3(0.18, 0.9, 0.0), out * 1.7 + Vector3(0, -0.05, 0), 0.25, 6, 0.018, rope)
	# Weed and barnacles to the tide line.
	for i in 7:
		var a := i * TAU / 7.0 + Kit.j(s, i + 20, 0.3)
		var r := 0.22 + Rng.hash01(s, i, 21) * 0.08
		k.stone(cos(a) * r, -0.06, sin(a) * r, 0.07 + Rng.hash01(s, i, 22) * 0.05, 0.1 + Rng.hash01(s, i, 23) * 0.2, s + 60 + i, WEED if i % 3 != 0 else P.STONE[3], 5)


# --- what the water took ----------------------------------------------------------

## A tram half sunk in the silt, listing, its roof and clerestory still above
## the water, its trolley pole up and its copper gear green on the roof, and a
## fishing net hung over the windows on one side by whoever uses it as a weir.
## Five long, 1.6 wide. 0: pole up, net hung; 1: sunk deeper by the stern, the
## pole snapped and hanging, the net torn. What comes off the roof is copper
## (Takes: sea copper, off the trolley gear, from the water).
static func drowned_tram(k: Kit, v: int, c: int) -> void:
	var s := 50500 + v * 37 + c
	var sink := 0.0 if v == 0 else 0.2
	var list := 0.07 if v == 0 else -0.09
	var pitch := 0.0 if v == 0 else 0.05
	var frame := Transform3D(Basis(Vector3.RIGHT, list) * Basis(Vector3.BACK, pitch), Vector3(0.0, -sink, 0.0))
	k.found.push(frame)
	k.made.push(frame)
	# The body: a long chamfered box, its lower half in the silt.
	k.chamfer(0.0, -0.9, 0.0, 5.0, 1.95, 1.5, 0.14, TRAM, TRAM_TOP)
	# The clerestory: the raised middle of the roof with its small lights.
	k.chamfer(0.0, 1.05, 0.0, 4.2, 0.26, 1.0, 0.08, GroundColors.down(TRAM, 0.3), TRAM_TOP)
	# The ends raked round, where the driver stood: one at each end.
	for sx: float in [-1.0, 1.0]:
		k.chamfer(sx * 2.62, -0.9, 0.0, 0.34, 1.8, 1.2, 0.12, GroundColors.down(TRAM, 0.2), TRAM_TOP)
	# The windows along both sides, dark, and the livery band under them.
	for sz: float in [-1.0, 1.0]:
		for i in 7:
			var x := -2.1 + i * 0.7
			k.chamfer(x, 0.42, sz * 0.755, 0.52, 0.5, 0.02, 0.02, P.INK[1])
		k.chamfer(0.0, 0.26, sz * 0.757, 4.8, 0.1, 0.02, 0.01, LIVERY)
	# The destination box over each end, dark, a pale block in it nobody can read.
	for sx: float in [-1.0, 1.0]:
		k.chamfer(sx * 2.78, 0.82, 0.0, 0.03, 0.22, 0.7, 0.01, P.INK[1])
		k.chamfer(sx * 2.8, 0.87, 0.0, 0.02, 0.1, 0.4, 0.01, P.LINEN[2])
	# The trolley gear on the roof: the base, its spring box, and the green of
	# the copper after years under the salt (the sea copper a take strips off).
	var verdigris := P.COPPER[2].lerp(P.MOSS[3], 0.45)
	k.chamfer(-0.9, 1.31, 0.0, 0.6, 0.12, 0.5, 0.04, P.PLATE[1], verdigris)
	k.rod(Vector3(-1.1, 1.43, -0.15), Vector3(-0.7, 1.43, -0.15), 0.035, 6, verdigris)
	k.rod(Vector3(-1.1, 1.43, 0.15), Vector3(-0.7, 1.43, 0.15), 0.035, 6, verdigris)
	if v == 0:
		# The pole up and back, its shoe still hunting for a wire that fell in.
		k.rod(Vector3(-0.9, 1.45, 0.0), Vector3(1.4, 2.75, 0.0), 0.03, 6, P.PLATE[2])
		k.rod(Vector3(1.4, 2.75, -0.06), Vector3(1.4, 2.75, 0.06), 0.05, 6, verdigris)
		k.cable(Vector3(1.4, 2.72, 0.0), Vector3(-0.8, 1.44, 0.2), 0.3, 5, 0.01, P.INK[2])
	else:
		# Snapped a third of the way up, the rest hanging down the side into the water.
		k.rod(Vector3(-0.9, 1.45, 0.0), Vector3(-0.1, 1.9, 0.0), 0.03, 6, P.PLATE[2])
		k.rod(Vector3(-0.1, 1.9, 0.0), Vector3(0.6, 0.4, 0.82), 0.03, 6, P.PLATE[1])
	# The net over the windows on one side, MADE: people's, hung from the roof
	# edge to the water, a mesh of cord with cork floats along its foot.
	var cord := GroundColors.made(P.SAND[2].lerp(P.ASH[2], 0.35), GroundColors.ROPE)
	var floats := GroundColors.made(P.EARTH[3], GroundColors.TIMBER)
	var nz := 0.79
	var x0 := -1.9
	var x1 := 1.3 if v == 0 else 0.4
	var rows := 5
	for j in rows + 1:
		var y := 1.0 - j * 0.24
		k.made.strut(Vector3(x0, y, nz), Vector3(x1, y + Kit.j(s, j, 0.04), nz), 0.008, 3, cord)
	var cols := int((x1 - x0) / 0.26)
	for j in cols + 1:
		var x := x0 + j * 0.26
		k.made.strut(Vector3(x, 1.02, nz), Vector3(x + Kit.j(s, j + 20, 0.05), -0.2, nz + 0.02), 0.008, 3, cord)
	for j in 5:
		var x := x0 + 0.2 + j * (x1 - x0 - 0.4) / 4.0
		k.stone(x, -0.24, nz + 0.03, 0.06, 0.06, s + 70 + j, floats, 6)
	k.made.pop()
	k.found.pop()
	# Weed at the waterline all round: the tide has been at it for years. Drawn
	# unrotated, since the water is level whatever the tram does.
	for i in 12:
		var x := -2.4 + i * 0.44
		var sz := 1.0 if i % 2 == 0 else -1.0
		k.stone(x, -0.12, sz * (0.72 + Rng.hash01(s, i, 81) * 0.08), 0.12 + Rng.hash01(s, i, 82) * 0.08, 0.14, s + 80 + i, WEED if i % 3 != 0 else WEED_LIT, 5)


# --- the plan's -----------------------------------------------------------------

## A lock's gate leaf: ruled steel in a stone recess, its stiffeners on exact
## pitch, the balance beam run back over the side it swings from, a walkway
## rail along its head and the paddle gear that lets the water through it. The
## recess is MADE, cut stone; the leaf is the plan's, FOUND. Three across,
## two and a half high. 0: shut across the canal; 1: swung half open.
static func lock_gate(k: Kit, v: int, c: int) -> void:
	var s := 50700 + v * 41 + c
	# The recess: a pier each side of the canal, stone in courses, the lower
	# courses green where the water stands.
	for sz: float in [-1.0, 1.0]:
		for j in 3:
			var col := GroundColors.down(cut_stone(c, j + (1 if sz > 0.0 else 0)), 0.3)
			k.slab(0.0, -0.9 + j * 0.8, sz * 1.72, 0.9 - j * 0.04, 0.82, 0.62, s + j + int(sz) * 7, col if j > 0 else GroundColors.down(col, 0.5), GroundColors.up(col, 0.12), 0.025)
		# The coping on top, proud of the courses.
		k.slab(0.0, 1.5, sz * 1.72, 1.0, 0.14, 0.72, s + 20 + int(sz), GroundColors.down(cut_stone(c, 3), 0.25), GroundColors.down(cut_stone(c, 3), 0.1), 0.02)
	# The leaf, turned on its heel post at +Z: shut, it closes the canal.
	var open := 0.0 if v == 0 else 0.55
	var hinge := Vector3(0.0, 0.0, 1.38)
	var frame := Transform3D(Basis(Vector3.UP, open), hinge)
	k.found.push(frame)
	var steel := P.PLATE[2]
	var dark := P.PLATE[1]
	k.chamfer(0.0, -0.8, -1.38, 0.24, 2.5, 2.72, 0.04, steel, P.PLATE[3])
	# The stiffeners across its face, both faces, on exact pitch, and the two
	# posts it is framed on.
	for sx: float in [-1.0, 1.0]:
		for j in 4:
			var y := -0.4 + j * 0.52
			k.rod(Vector3(sx * 0.13, y, -2.66), Vector3(sx * 0.13, y, -0.1), 0.028, 4, dark)
		k.rod(Vector3(sx * 0.13, -0.8, -1.38), Vector3(sx * 0.13, 1.7, -1.38), 0.03, 4, dark)
	k.chamfer(0.0, -0.8, 0.0, 0.3, 2.6, 0.22, 0.04, dark, steel)
	k.chamfer(0.0, -0.8, -2.72, 0.28, 2.55, 0.18, 0.04, dark, steel)
	# The paddle gear on its head: a ruled box and the rack that lifts the
	# paddle, and a walkway rail along the top.
	k.chamfer(0.0, 1.7, -1.8, 0.3, 0.28, 0.36, 0.04, P.PLATE[1], P.PLATE[3])
	k.rod(Vector3(0.0, 1.98, -1.8), Vector3(0.0, 2.35, -1.8), 0.025, 4, P.PLATE[3])
	for j in 5:
		var z := -0.2 - j * 0.6
		k.rod(Vector3(-0.1, 1.7, z), Vector3(-0.1, 2.15, z), 0.014, 4, dark)
	k.rod(Vector3(-0.1, 2.15, -0.1), Vector3(-0.1, 2.15, -2.66), 0.016, 4, dark)
	# The balance beam, run back over the bank on the -X side: what a gate is
	# swung by, and the one long line a lock is read by from along the canal.
	k.chamfer(-1.3, 1.62, 0.12, 2.5, 0.22, 0.24, 0.04, dark, steel)
	k.chamfer(-2.4, 1.52, 0.12, 0.3, 0.32, 0.3, 0.04, P.PLATE[1])
	k.found.pop()
	# Weed on the leaf's lower half where the water stands against it, and
	# rust run from its stiffeners: MADE, drawn over the steel on the made pen.
	k.made.push(frame)
	for sx: float in [-1.0, 1.0]:
		var xs := sx * 0.125
		for j in 5:
			var z := -0.3 - j * 0.52
			if sx > 0.0:
				k.made.quad(Vector3(xs, 0.2, z), Vector3(xs, 0.2, z - 0.46), Vector3(xs, -0.5, z - 0.46), Vector3(xs, -0.5, z), WEED)
			else:
				k.made.quad(Vector3(xs, 0.2, z - 0.46), Vector3(xs, 0.2, z), Vector3(xs, -0.5, z), Vector3(xs, -0.5, z - 0.46), WEED)
	k.made.pop()
	for j in 3:
		Remains.streak(k, Vector3(0.126, 1.1 - j * 0.5, -0.6 - j * 0.7), 0.05, 0.3, Vector3.RIGHT, P.RUST[2])


## Every kind here in the drowned city's own dressing, and the two machines it
## keeps to itself beside them. The city is found by what its people BUILD and
## never by name: nothing under src/models/props/ may name a landscape
## (tests/biome/test_dressing.gd), and the one that declares a drowned tram
## among its things is the one these dress for.
static func gallery() -> Array:
	var out: Array = []
	var c := 0
	for d: BiomeDef in BiomeRegistry.land():
		if d.props.has(PropKind.DROWNED_TRAM):
			c = d.index
	for kind: int in [PropKind.STAIR_TO_WATER, PropKind.DROWNED_TRAM, PropKind.MOORING_POST, PropKind.LOCK_GATE]:
		for v in PropModels.variants(kind, c):
			out.append({"name": "drowned %s %d" % [PropKind.NAMES[kind], v], "node": PropModels.node(kind, v, c)})
	for kid: StringName in [&"ferry", &"sentinel_lockkeeper"]:
		for p: StringName in [&"stand", &"alert", &"windup", &"dead"]:
			var item: FigureModel = MG.make(kid, p, 0.3)
			var holder := Node3D.new()
			holder.add_child(item)
			out.append({"name": "drowned %s %s" % [String(kid).trim_prefix("sentinel_"), p], "node": holder})
	return out
