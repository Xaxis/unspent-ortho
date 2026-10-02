extends RefCounted
## What stands in the Drowned City (docs/LANDSCAPES.md). The water is the
## street here, so everything is either how people meet the water — a stair cut
## down off a quay into it, a crowd of piles a boat was tied to before the jetty
## went — or what the water took and left standing in it: a tram half sunk in
## the silt with a net somebody hung over its windows. And the plan's own: a
## gate leaf in a lock, ruled steel in a stone recess. And the city itself: its
## blocks standing in the canals to their sills, and out in the shallows the
## roofs of the ones the sea took further.
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
const Houses := preload("res://src/models/props/houses.gd")
## The towers' own shaft, which the city's drowned blocks are cast in.
const Towers := preload("res://src/models/props/towers.gd")
## The stolen tube a lit form carries: one door, the city's, so the light and
## the thing casting it come from one place (`PropModels.neon_point`).
const Metropolis := preload("res://src/models/props/metropolis.gd")
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
		PropKind.DROWNED_SHELL: drowned_shell(k, v, c)
		PropKind.DROWNED_ROOF: drowned_roof(k, v, c)


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
			if top < 0.0:
				Remains._facing_quad(k.made, Vector3(x0, top - 0.5, sz * 0.831), Vector3(x0 + 0.72, top - 0.5, sz * 0.831),
					Vector3(0, 0.48, 0), Vector3(0, 0, sz), WEED)
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
			Remains._facing_quad(k.made, Vector3(xs, -0.5, z), Vector3(xs, -0.5, z - 0.46), Vector3(0, 0.7, 0), Vector3(sx, 0, 0), WEED)
	k.made.pop()
	for j in 3:
		Remains.streak(k, Vector3(0.126, 1.1 - j * 0.5, -0.6 - j * 0.7), 0.05, 0.3, Vector3.RIGHT, P.RUST[2])


# --- what the sea left standing ---------------------------------------------------

## How far a canal stands up a drowned block: its ground floor is under the water,
## and the first floor's sills sit a hand over the canal's sheet (which stands
## `TerrainMesher.WADE`, 0.3, over its bank).
const SILL_DEEP := 1.15
## A drowned block's plan at its widest: deep from its canal face (+X), and
## along the canal. What GenWorks plots one to (drowned_city.gd BLOCK_DEEP and
## BLOCK_ALONG in the landscape's file).
const BLOCK_DEEP := 2.4
const BLOCK_ALONG := 3.0

## THE BLOCKS ALONG A CANAL ARE NEVER ONE BOX TWICE. A row of one profile read
## from above as a shelf of identical boxes, which a city is not (docs/LOOK.md:
## never a box read as a building block). Each variant is its own profile:
## storeys, plan (`w` deep from the canal, `d` along it), how its top ended, and
## how far it has leant on the silt, toward the canal (+) or back off it (-).
##   snapped  two walls of the floor above to their broken heights, the rest sky
##   roofed   its parapet and what stood on the roof
##   stepped  the top floor set back off the canal, a terrace before it
##   cut      the canal corner gone from the second floor up, open to the sky
##   front    only its face to the canal: the block behind it came down
const SHELLS: Array[Dictionary] = [
	{"n": 3, "w": 2.4, "d": 3.0, "top": &"snapped", "lean": 0.0},
	{"n": 2, "w": 2.2, "d": 2.7, "top": &"roofed", "lean": 0.0},
	{"n": 4, "w": 2.4, "d": 2.8, "top": &"snapped", "lean": 0.05},
	{"n": 3, "w": 0.34, "d": 3.0, "top": &"front", "lean": 0.0},
	{"n": 5, "w": 2.4, "d": 3.0, "top": &"stepped", "lean": 0.0},
	{"n": 3, "w": 2.3, "d": 2.9, "top": &"cut", "lean": -0.035},
	{"n": 2, "w": 2.0, "d": 2.6, "top": &"snapped", "lean": 0.075},
	{"n": 4, "w": 2.3, "d": 3.0, "top": &"roofed", "lean": -0.02},
]

## How deep a sea roof's block stands below the ground it is laid on, by how
## much of it breaks the sea's sheet (`TerrainMesher.WATER_Y`, 0.3): its last
## floor's deck just under the water with its broken walls standing out of it,
## its deck just out of the water, and a floor and a half out, its windows' heads
## clear of the sea.
const ROOFS: Array[Dictionary] = [
	{"n": 3, "w": 2.4, "d": 3.0, "top": &"snapped", "out": 0.1},
	{"n": 2, "w": 2.2, "d": 2.8, "top": &"awash", "out": 0.42},
	{"n": 4, "w": 2.3, "d": 2.9, "top": &"snapped", "out": 1.55},
]


## A DROWNED BLOCK, lining a street that is a canal now: the metropolis's own
## towers with the sea in them. Its ground floor is under the water, so what
## stands out of the canal begins at the first floor's sills, the weed and a
## white salt line up its canal face to where the tide comes, and every floor
## above dark and empty. A row of them along a canal is a city's frontage, and
## the water between two rows is the street. Faces +X, its canal (SHELLS).
static func drowned_shell(k: Kit, v: int, c: int) -> void:
	var shape: Dictionary = SHELLS[v % SHELLS.size()]
	var w: float = shape.w
	# A front stands on the canal face; the rest stand back from it by their depth.
	var off := Vector3(BLOCK_DEEP * 0.5 - w * 0.5, -SILL_DEEP, 0.0)
	_drowned_block(k, 52100 + v * 37 + c * 5, c, shape, off, true)


## A DROWNED ROOF, out in the shallows off the city where the sea took the blocks
## further: all that breaks the surface is the top of its last floor, snapped or
## awash. Seen from a raft coming in, the city starts here, in the sea (ROOFS).
static func drowned_roof(k: Kit, v: int, c: int) -> void:
	var shape: Dictionary = ROOFS[v % ROOFS.size()]
	var up := float(shape.n) * Towers.STOREY - float(shape.out)
	_drowned_block(k, 52300 + v * 37 + c * 5, c, shape, Vector3(0.0, -up, 0.0), false)


## A block of `shape`'s storeys of the towers' own shaft, moved by `off` (its
## foot sunk below the ground it is laid on) and leant on the silt about its own
## foot, with the top its shape names; with the `tide` up its canal face.
static func _drowned_block(k: Kit, s: int, c: int, shape: Dictionary, off: Vector3, tide: bool) -> void:
	var dress := BiomeDressing.of(c)
	var n: int = shape.n
	var w: float = shape.w
	var d: float = shape.d
	var top_kind: StringName = shape.top
	var lean: float = shape.get("lean", 0.0)
	# Leant about the foot's canal edge, so the face stays on its plot.
	var foot := Vector3(w * 0.5, 0.0, 0.0)
	var xf := Transform3D(Basis.IDENTITY, off) * Transform3D(Basis.IDENTITY, foot) * Transform3D(Basis(Vector3(0, 0, 1), -lean), -foot)
	k.made.push(xf)
	k.found.push(xf)
	k.leaf.push(xf)
	var body := GroundColors.down(dress.concrete, 0.34)
	var hw := w * 0.5
	var hd := d * 0.5
	match top_kind:
		&"cut":
			# One floor whole, then the floors over it on the back half only: the
			# canal corner came away and the rooms behind it stand open.
			var y := Towers.shaft(k, w, d, 1, 0.0, s, c, false)
			var back := w * 0.55
			k.made.push(Transform3D(Basis.IDENTITY, Vector3(-(w - back) * 0.5, y, 0.0)))
			k.found.push(Transform3D(Basis.IDENTITY, Vector3(-(w - back) * 0.5, y, 0.0)))
			var top := Towers.shaft(k, back, d, n - 1, 0.0, s + 5, c, false)
			_snapped(k, back, d, top, s, body)
			k.found.pop()
			k.made.pop()
			# What came away, lying on the floor it fell to.
			for i in 4:
				k.slab(hw - 0.5 + Kit.j(s, i + 40, 0.3), y + 0.06, -hd + 0.5 + i * (d - 1.0) / 3.0, 0.5 + Kit.j(s, i + 44, 0.15), 0.18, 0.4, s + 90 + i,
					GroundColors.down(body, 0.15), GroundColors.up(body, 0.1), 0.05, 0.1, Kit.j(s, i + 48, 0.4))
		&"stepped":
			var y := Towers.shaft(k, w, d, n - 1, 0.0, s, c, false)
			Towers.parapet(k, w, d, y, s + 60, c)
			var back := w * 0.6
			var lift := Transform3D(Basis.IDENTITY, Vector3(-(w - back) * 0.5, y, 0.0))
			k.made.push(lift)
			k.found.push(lift)
			var top := Towers.shaft(k, back, d * 0.8, 1, 0.0, s + 7, c, false)
			var r := Towers.parapet(k, back, d * 0.8, top, s + 61, c)
			Towers.plant(k, back, d * 0.8, r[0], s + 70, c)
			k.found.pop()
			k.made.pop()
		_:
			var top := Towers.shaft(k, w, d, n, 0.0, s, c, false)
			match top_kind:
				&"roofed":
					var r := Towers.parapet(k, w, d, top, s + 60, c)
					Towers.plant(k, w, d, r[0], s + 70, c)
				&"awash":
					_awash(k, w, d, top, s, dress)
				_:
					_snapped(k, w, d, top, s, body)
	if tide:
		_tide(k, c, Vector3(hw + 0.012, -off.y, 0.0), d)
	k.leaf.pop()
	k.found.pop()
	k.made.pop()


## The floor above a snapped block: two walls of it to their own broken heights,
## the others sky, and the bars standing out of the tops of the walls that held.
static func _snapped(k: Kit, w: float, d: float, top: float, s: int, body: Color) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	for i in 5:
		var z := -hd + (i + 0.5) * d / 5.0
		var h := maxf(0.15, 0.95 - i * 0.16 + Kit.j(s, i + 60, 0.18))
		k.slab(hw - 0.09, top, z, 0.18, h, d / 5.0 + 0.02, s + i * 5, body, GroundColors.up(body, 0.2), 0.02)
		if i % 2 == 0:
			var at := Vector3(hw - 0.09, top + h, z)
			k.rod(at, at + Vector3(0.12 + Kit.j(s, i + 20, 0.1), 0.25 + Rng.hash01(s, i, 73) * 0.25, Kit.j(s, i + 26, 0.15)), 0.014, 3, P.RUST[2])
	if w > 1.0:
		for i in 3:
			var x := -hw + (i + 0.5) * w / 3.0
			var h := maxf(0.15, 0.25 + i * 0.22 + Kit.j(s, i + 70, 0.12))
			k.slab(x, top, -hd + 0.09, w / 3.0 + 0.02, h, 0.18, s + i * 7 + 3, GroundColors.down(body, 0.12), GroundColors.up(body, 0.15), 0.02)
			var at := Vector3(x, top + h, -hd + 0.09)
			k.rod(at, at + Vector3(Kit.j(s, i + 30, 0.15), 0.3, -0.12), 0.014, 3, P.RUST[2])


## A roof the sea comes over at high water: its deck dark and wet, weed in its
## low corner, its parapet down to stubs on the seaward side, and its tank gone
## over, lying on the deck.
static func _awash(k: Kit, w: float, d: float, top: float, s: int, dress: BiomeDressing) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var wet := GroundColors.made(GroundColors.down(dress.concrete, 0.6), GroundColors.CONCRETE)
	k.slab(0.0, top, 0.0, w + 0.06, 0.06, d + 0.06, s + 1, wet, GroundColors.down(wet, 0.1), 0.01)
	for i in 3:
		k.slab(-hw + 0.4 + i * 0.5, top + 0.06, hd - 0.45 - i * 0.3, 0.6, 0.012, 0.5, s + 10 + i, WEED, WEED_LIT, 0.01)
	for i in 4:
		var h := 0.08 + Rng.hash01(s, i, 12) * (0.3 if i < 2 else 0.08)
		var z := -hd + (i + 0.5) * d / 4.0
		k.slab(-hw + 0.06, top + 0.06, z, 0.14, h, d / 4.0 + 0.02, s + 20 + i, GroundColors.down(wet, 0.05), GroundColors.up(wet, 0.15), 0.015)
	k.limb(Vector3(hw * 0.2, top + 0.3, -hd * 0.3), Vector3(hw * 0.75, top + 0.18, hd * 0.2), 0.3, 0.28, 8, P.RUST[2])


## The tide up a drowned block's canal face: weed up from under the canal's
## sheet to where the water comes, its top ragged, and a pale salt line over it.
## The face only: the block's other sides stand on its own dry floor.
static func _tide(k: Kit, c: int, face: Vector3, d: float) -> void:
	var dress := BiomeDressing.of(c)
	var side := Vector3(1, 0, 0)
	var along := Vector3(0, 0, 1)
	var n := 6
	for i in n:
		var z0 := -d * 0.5 + d * float(i) / float(n)
		var h := 0.42 + Kit.j(52900, i, 0.08)
		Remains._facing_quad(k.made, face + along * z0 + Vector3(0, -0.2, 0), face + along * (z0 + d / float(n)) + Vector3(0, -0.2, 0), Vector3(0, h + 0.2, 0), side, WEED_LIT)
	Remains._facing_quad(k.made, face + side * 0.002 - along * d * 0.5 + Vector3(0, 0.52, 0), face + side * 0.002 + along * d * 0.5 + Vector3(0, 0.52, 0), Vector3(0, 0.04, 0), side, dress.pale[0])


# --- what people live in where the street is water (BiomeForms.FORMS) -------------

## The one door for the city's three built forms, reached from `Towers.build`
## by form id, never by landscape. A form this file does not know draws
## nothing, and `tests/biome/test_forms.gd` fails on it.
static func form(k: Kit, which: StringName, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match which:
		&"upper_floor": upper_floor(k, c)
		&"stilt_house": stilt_house(k, c)
		&"hulk_home": hulk_home(k, c)


## The landscape's cast concrete, lit as concrete.
static func _concrete(c: int) -> Color:
	return GroundColors.made(BiomeDressing.of(c).concrete, GroundColors.CONCRETE)


## Salt-grey boards, lit as timber.
static func _boards(c: int, i: int = 0) -> Color:
	var t := BiomeDressing.of(c).timber
	return GroundColors.made(t[i % t.size()], GroundColors.TIMBER)


## A punt: a flat timber boat, square at both ends, what a family here gets
## about in. `at` is its middle, `yaw` its heading.
static func _punt(k: Kit, at: Vector3, yaw: float, c: int, s: int) -> void:
	k.made.push(Transform3D(Basis(Vector3.UP, yaw), at))
	k.slab(0.0, -0.05, 0.0, 1.5, 0.2, 0.5, s, GroundColors.down(_boards(c, 1), 0.3), _boards(c), 0.02, 0.12)
	# Its thwart and a pole laid along it.
	k.slab(0.0, 0.1, 0.0, 0.08, 0.05, 0.46, s + 1, _boards(c))
	k.limb(Vector3(-0.7, 0.2, 0.1), Vector3(0.9, 0.24, -0.08), 0.016, 0.014, 4, _boards(c, 1))
	k.made.pop()


## "upper_floor": people living on the first floor of a flooded block, the
## ground floor given to the water. Two storeys of cast concrete, a green stain
## up the lower one to the tide line and its windows bricked or boarded, and
## over it the lived floor: the windows glazed with whatever was found, washing
## on a line out of one, a plank walk down to the boat tied at another, and a
## stolen tube along the sill. Lit: it faces the square.
static func upper_floor(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 51100 + c * 7
	# Salt-stained a step under the landscape's own pour: a century in the spray.
	var con := GroundColors.down(_concrete(c), 0.35)
	var w := 3.4
	var ground := 2.2
	var top := 4.5
	# The block: the drowned floor, the floor slab's lip, the lived floor, a parapet.
	k.slab(0.0, 0.0, 0.0, w, ground, w, s, GroundColors.down(con, 0.25), con, 0.03)
	k.slab(0.0, ground, 0.0, w + 0.14, 0.16, w + 0.14, s + 1, GroundColors.down(con, 0.1), GroundColors.up(con, 0.1), 0.02)
	k.slab(0.0, ground + 0.16, 0.0, w, top - ground - 0.16, w, s + 2, con, GroundColors.up(con, 0.05), 0.03)
	k.slab(0.0, top, 0.0, w + 0.06, 0.22, w + 0.06, s + 3, GroundColors.down(con, 0.08), GroundColors.up(con, 0.15), 0.02)
	var half := w * 0.5 + 0.004
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var along := Vector3(-side.z, 0, side.x)
		var face := side * half
		# The tide line: green-black up to it, and the pale salt line on top.
		Remains._facing_quad(k.made, face - along * (half - 0.02), face + along * (half - 0.02), Vector3(0, 0.95, 0), side, WEED)
		Remains._facing_quad(k.made, face - along * (half - 0.02) + Vector3(0, 0.95, 0), face + along * (half - 0.02) + Vector3(0, 0.95, 0), Vector3(0, 0.06, 0), side, dress.pale[0])
		for i in 3:
			var off := (float(i) - 1.0) * 1.05
			# Downstairs: the windows boarded over, the water at the sills.
			var lo := face + side * 0.002 + along * off + Vector3(0, 1.1, 0)
			Remains._facing_quad(k.made, lo - along * 0.3, lo + along * 0.3, Vector3(0, 0.62, 0), side, _boards(c, i))
			# Upstairs: lived in. Dark glass, and one with a warm lamp behind it.
			var up := face + side * 0.004 + along * off + Vector3(0, ground + 0.55, 0)
			var glass := P.INK[1] if (i + int(side.z)) % 2 == 0 else GroundColors.glow(P.EMBER[3], 0.3)
			Remains._facing_quad(k.made, up - along * 0.3, up + along * 0.3, Vector3(0, 0.85, 0), side, glass)
			Remains._facing_quad(k.made, up - along * 0.36 - side * 0.001 + Vector3(0, -0.06, 0), up + along * 0.36 - side * 0.001 + Vector3(0, -0.06, 0), Vector3(0, 0.08, 0), side, GroundColors.up(con, 0.2))
	# The way in: a plank walk from the front window's sill down to the water,
	# and the family's punt tied at its foot.
	var sill := Vector3(half + 0.02, ground + 0.5, 0.0)
	k.slab(half + 0.75, ground - 0.45, 0.0, 1.5, 0.05, 0.32, s + 10, _boards(c), _boards(c), 0.02, 0.0, -0.55)
	k.limb(sill, Vector3(half + 1.5, 0.3, 0.2), 0.018, 0.018, 4, _boards(c, 1))
	_punt(k, Vector3(half + 1.4, 0.05, 0.9), 0.35, c, s + 20)
	var rope := GroundColors.made(P.SAND[2].lerp(P.EARTH[2], 0.3), GroundColors.ROPE)
	k.sag(sill + Vector3(0, 0.1, 0.35), Vector3(half + 0.9, 0.2, 0.8), 0.2, 5, 0.012, rope)
	# Washing on a line between two windows on the side, what a lived floor shows.
	var cloth: Array[Color] = [GroundColors.made(dress.pale[0], GroundColors.CLOTH), GroundColors.made(P.SLATE[3], GroundColors.CLOTH), GroundColors.made(P.RUST[3], GroundColors.CLOTH)]
	var la := Vector3(-0.9, ground + 1.45, half + 0.3)
	var lb := Vector3(0.9, ground + 1.45, half + 0.3)
	k.sag(la, lb, 0.08, 5, 0.008, rope)
	for i in 4:
		var t := 0.15 + i * 0.22
		var p := la.lerp(lb, t) + Vector3(0, -0.32 * t * (1.0 - t) - 0.02, 0)
		Remains._facing_quad(k.made, p - Vector3(0.12, 0.34, 0), p + Vector3(0.12, -0.34, 0), Vector3(0, 0.34, 0), Vector3(0, 0, 1), cloth[i % cloth.size()])
	# A water butt on the roof, and the tube along the front sill.
	k.limb(Vector3(-0.8, top + 0.22, -0.8), Vector3(-0.8, top + 0.8, -0.8), 0.28, 0.26, 8, P.RUST[2])
	Metropolis._tube(k, Vector3(half + 0.01, ground + 0.36, 1.1), Vector3(half + 0.01, ground + 0.36, -1.1), Vector3(1, 0, 0), Remains.NEON[0])


## "stilt_house": a timber house on piles over the mud, the city's poorest and
## its commonest: six piles driven into the silt, a deck, board walls gone
## salt-grey, a roof of tarred boards, a ladder down to the water, and a
## porch where the nets are mended. No tube: nobody wired a machine in here.
static func stilt_house(k: Kit, c: int) -> void:
	var s := 51300 + c * 7
	var deck := 1.2
	var s0 := k.made.vertex_count()
	for ix in 3:
		for iz in 2:
			var x := -1.2 + ix * 1.2
			var z := -0.8 + iz * 1.6
			k.limb(Vector3(x + Kit.j(s, ix * 2 + iz, 0.08), -0.3, z + Kit.j(s, ix * 2 + iz + 9, 0.08)), Vector3(x, deck, z), 0.07, 0.06, 7, _boards(c, ix + iz))
	k.made.smooth_range(s0, k.made.vertex_count())
	# Cross braces between the front piles, and weed up them to the tide line.
	k.limb(Vector3(-1.2, 0.2, 0.8), Vector3(1.2, 0.9, 0.8), 0.025, 0.025, 4, _boards(c, 1))
	k.limb(Vector3(-1.2, 0.2, -0.8), Vector3(1.2, 0.9, -0.8), 0.025, 0.025, 4, _boards(c, 1))
	for i in 6:
		var x := -1.2 + (i % 3) * 1.2
		var z := -0.8 + float(i >= 3) * 1.6
		k.stone(x, -0.05, z, 0.1, 0.35, s + 30 + i, WEED if i % 2 == 0 else WEED_LIT, 6)
	# The deck, running out past the walls into a porch at the front.
	k.slab(0.25, deck, 0.0, 3.3, 0.08, 2.1, s + 1, GroundColors.down(_boards(c), 0.2), _boards(c), 0.02)
	k.made.push(Transform3D(Basis.IDENTITY, Vector3(-0.35, deck + 0.08, 0.0)))
	var corners := Houses.walls(k, 2.1, 1.8, 1.2, s + 2, _boards(c), _boards(c, 1), Vector3(0.02, 0.0, -0.02))
	k.made.pop()
	# The roof: two planes of tarred boards over a ridge along X.
	var ry := deck + 0.08 + 1.2
	var tar := GroundColors.made(P.INK[2].lerp(P.SLATE[1], 0.4), GroundColors.TAR)
	var ridge := ry + 0.6
	for sz: float in [-1.0, 1.0]:
		var a := Vector3(-1.55, ry - 0.05, sz * 1.15)
		var b := Vector3(0.9, ry - 0.05, sz * 1.15)
		Remains._facing_quad(k.made, a, b, Vector3(0, ridge - ry + 0.05, -sz * 1.15), Vector3(0, 1, sz), tar if sz > 0.0 else GroundColors.down(tar, 0.2))
	# The gables, boards to the ridge.
	for sx: float in [-1.0, 1.0]:
		var x := -0.35 + sx * 1.05
		if sx > 0.0:
			k.made.tri(Vector3(x, ry - 0.05, -1.0), Vector3(x, ry - 0.05, 1.0), Vector3(x, ridge, 0.0), _boards(c, 1))
		else:
			k.made.tri(Vector3(x, ry - 0.05, 1.0), Vector3(x, ry - 0.05, -1.0), Vector3(x, ridge, 0.0), _boards(c, 1))
	# The door on the porch, a window with a shutter, the stovepipe.
	var front := (corners[1] + corners[2]) * 0.5 + Vector3(-0.35, deck + 0.08, 0.0)
	Remains._facing_quad(k.made, front + Vector3(0.012, 0.0, 0.22), front + Vector3(0.012, 0.0, -0.22), Vector3(0, 0.95, 0), Vector3(1, 0, 0), P.INK[1])
	Remains._facing_quad(k.made, front + Vector3(0.012, 0.5, 0.6), front + Vector3(0.012, 0.5, 0.35), Vector3(0, 0.35, 0), Vector3(1, 0, 0), GroundColors.glow(P.EMBER[3], 0.3))
	k.limb(Vector3(-1.0, ry, 0.5), Vector3(-1.0, ridge + 0.5, 0.5), 0.05, 0.045, 6, P.RUST[1])
	# The ladder down to the water off the porch's edge, and a net over its rail.
	for i in 5:
		var y := deck - 0.2 - i * 0.28
		k.limb(Vector3(1.9, y, -0.2), Vector3(1.9, y, 0.2), 0.016, 0.016, 4, _boards(c))
	k.limb(Vector3(1.9, deck, -0.22), Vector3(1.95, -0.2, -0.22), 0.02, 0.02, 4, _boards(c, 1))
	k.limb(Vector3(1.9, deck, 0.22), Vector3(1.95, -0.2, 0.22), 0.02, 0.02, 4, _boards(c, 1))
	var cord := GroundColors.made(P.SAND[2].lerp(P.ASH[2], 0.35), GroundColors.ROPE)
	for j in 6:
		var z := -0.9 + j * 0.3
		k.made.strut(Vector3(1.85, deck + 0.5, z), Vector3(1.85 + Kit.j(s, j + 40, 0.04), deck + 0.05, z + 0.05), 0.008, 3, cord)
	k.limb(Vector3(1.85, deck + 0.52, -1.0), Vector3(1.85, deck + 0.52, 0.8), 0.02, 0.02, 4, _boards(c))


## "hulk_home": a steel barge nobody moves any more, moored for good and lived
## on: its rusted hull, a timber shed built on its deck with a tin roof, a
## stovepipe, pots of greens along the gunwale and a stolen tube over the shed
## door. The hull is FOUND, plate the machines' age rolled; what was built on
## it is MADE. Lit: somebody wired the tube in.
static func hulk_home(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 51500 + c * 7
	var rust := P.RUST[1].lerp(P.PLATE[1], 0.35)
	# The hull: a long chamfered box sat low in the water, a sheer strake, and
	# the bow raked up at +X.
	k.chamfer(0.0, -0.45, 0.0, 3.8, 1.05, 1.9, 0.22, rust, P.PLATE[2])
	k.chamfer(2.05, -0.2, 0.0, 0.5, 0.85, 1.3, 0.18, GroundColors.down(rust, 0.2), P.PLATE[2])
	for sz: float in [-1.0, 1.0]:
		k.rod(Vector3(-1.85, 0.55, sz * 0.96), Vector3(1.85, 0.55, sz * 0.96), 0.04, 4, P.PLATE[1])
		# Bollards at the quarters, with the lines out to the quay.
		k.rod(Vector3(1.5, 0.6, sz * 0.7), Vector3(1.5, 0.78, sz * 0.7), 0.06, 6, P.PLATE[2])
	var rope := GroundColors.made(P.SAND[2].lerp(P.EARTH[2], 0.3), GroundColors.ROPE)
	k.sag(Vector3(1.5, 0.75, 0.7), Vector3(2.8, 0.3, 1.9), 0.25, 5, 0.014, rope)
	k.sag(Vector3(-1.5, 0.7, -0.7), Vector3(-2.7, 0.3, -1.9), 0.25, 5, 0.014, rope)
	# The shed on its deck: board walls, a door, a window, and a tin roof.
	k.made.push(Transform3D(Basis.IDENTITY, Vector3(-0.35, 0.6, 0.0)))
	var corners := Houses.walls(k, 2.0, 1.45, 1.0, s + 2, _boards(c), _boards(c, 1), Vector3(0.02, 0.0, 0.02))
	k.made.pop()
	var ry := 1.6
	Remains.patch(k, Vector3(0.75, ry + 0.05, 0.9), Vector3(0.75, ry + 0.05, -0.9), Vector3(-1.5, ry - 0.2, -0.9), Vector3(-1.5, ry - 0.2, 0.9), 2)
	var front := (corners[1] + corners[2]) * 0.5 + Vector3(-0.35, 0.6, 0.0)
	Remains._facing_quad(k.made, front + Vector3(0.012, 0.0, 0.3), front + Vector3(0.012, 0.0, -0.1), Vector3(0, 0.82, 0), Vector3(1, 0, 0), P.INK[1])
	Remains._facing_quad(k.made, front + Vector3(0.012, 0.35, -0.3), front + Vector3(0.012, 0.35, -0.6), Vector3(0, 0.3, 0), Vector3(1, 0, 0), GroundColors.glow(P.EMBER[3], 0.3))
	k.limb(Vector3(-1.1, ry - 0.1, 0.4), Vector3(-1.1, ry + 0.7, 0.4), 0.05, 0.045, 6, P.RUST[2])
	# Greens in tins along the gunwale: what grows on a boat that never goes anywhere.
	for i in 5:
		var x := 0.9 + (i % 2) * 0.3
		var z := -0.8 + i * 0.4
		k.limb(Vector3(x, 0.58, z), Vector3(x, 0.72, z), 0.07, 0.07, 6, P.RUST[2])
		k.clump(x, 0.72, z, 0.1, 0.12, s + 40 + i, dress.growth if dress.growth.a > 0.0 else P.MOSS[3], 6)
	# Weed and rust at the waterline.
	for i in 10:
		var x := -1.8 + i * 0.4
		var sz := 1.0 if i % 2 == 0 else -1.0
		k.stone(x, -0.1, sz * 0.9, 0.1, 0.1, s + 60 + i, WEED if i % 3 != 0 else WEED_LIT, 5)
	Metropolis._tube(k, front + Vector3(0.014, 0.95, 0.35), front + Vector3(0.014, 0.95, -0.15), Vector3(1, 0, 0), Remains.NEON[1])


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
	for kind: int in [PropKind.STAIR_TO_WATER, PropKind.DROWNED_TRAM, PropKind.MOORING_POST, PropKind.LOCK_GATE, PropKind.DROWNED_SHELL, PropKind.DROWNED_ROOF]:
		for v in PropModels.variants(kind, c):
			out.append({"name": "drowned %s %d" % [PropKind.NAMES[kind], v], "node": PropModels.node(kind, v, c)})
	# What its people live in: a house here is dealt one of the stock's forms.
	var stock := BiomeForms.of(c).stock
	for v in stock.size():
		out.append({"name": "drowned home %s" % stock[v], "node": PropModels.node(PropKind.HOUSE, v, c)})
	for kid: StringName in [&"ferry", &"sentinel_lockkeeper"]:
		for p: StringName in [&"stand", &"alert", &"windup", &"dead"]:
			var item: FigureModel = MG.make(kid, p, 0.3)
			var holder := Node3D.new()
			holder.add_child(item)
			out.append({"name": "drowned %s %s" % [String(kid).trim_prefix("sentinel_"), p], "node": holder})
	return out
