class_name BiomeScatter
extends RefCounted
## One tile, as a landscape type's prop scatter sees it, plus the scatter rules
## every type shares. GenScatter fills one of these per band and hands it to
## `BiomeDef.scatter`, which answers with a PropKind, NONE, or PASS.
##
## NOTHING on the sample changes from tile to tile. What a recipe reads per tile
## comes as an ARGUMENT: the tile `i`, `g`, what the tile is made of, and `r`,
## the tile's own hash in [0, 1). A recipe compares `r` against cumulative
## chances, so the same tile always grows the same thing and no sequence RNG is
## drawn in a threaded loop; low rolls are the common things. Everything rarer
## is a BAND field here, indexed by `i`.
##
## That rule is the world's start time, not tidiness: writing one property on
## this object costs about what the whole rest of the scatter loop costs, and
## every worker thread laying a band takes the same engine-wide lock to do it.
## Add a band field, pass an argument, never a per-tile write.
##
## A type's recipe calls `shared()` first, for the grounds every landscape meets
## the same way (the strandline, shingle, an exposed rock face, water's edge),
## and only writes the grounds that are its own. That is what keeps a new
## landscape file short.
##
## Two types are in play on an ecotone tile: `def` is the one whose recipe the
## ground followed, and `own_def` is the one that holds the tile. What grows
## follows the recipe; what is buried follows the land, so the seams under a
## tongue of pinewood in the bonelands are still the bonelands'.

## Nothing grows on this tile.
const NONE := -1
## `shared` did not claim this tile: the type's own recipe decides.
const PASS := -2

## The world's width, so a recipe can step to a neighbouring tile.
var size := 0

# --- the band's fields (set once, not per tile) ---------------------------

## Clumping (1/11) and the fissure field (1/26), the woodland field, and how
## far a tile stands above the land around it.
var clump: PackedFloat32Array
var fissure: PackedFloat32Array
var forest: PackedFloat32Array
var rise: PackedFloat32Array
## What every tile is made of, 4-neighbour steps from the sea, the integer
## level, and how far each tile has turned toward the type across the border.
var grounds: PackedByteArray
var sea_steps: PackedByteArray
var levels: PackedInt32Array
var blends: PackedFloat32Array

# --- handed over only where the land changes ------------------------------

## The type whose recipe this tile follows, the type that holds the tile, and
## the type across the nearest border. All three change only at a border, so
## the tile loop hands them over there and nowhere else.
var def: BiomeDef
var own_def: BiomeDef
var other_def: BiomeDef


## True on the edge of a run of `g`.
func edge_of(i: int, g: int) -> bool:
	return grounds[i - 1] != g or grounds[i + 1] != g or grounds[i - size] != g or grounds[i + size] != g


## What the land decides before any landscape gets a say: ore at the foot of an
## exposed face, and what stands at water's edge. PASS when neither applies.
## `up`: levels the tallest neighbour stands above this tile. `wet`: the tile is
## beside running or still water.
static func first(t: BiomeScatter, g: int, r: float, up: int, wet: bool) -> int:
	if up >= 2 and (g == Ground.SCREE or g == Ground.ROCK or g == Ground.LIMESTONE or g == Ground.GRAVEL or g == Ground.SNOW or g == Ground.ASH):
		# What is buried follows the land, not the recipe on top of it.
		return ore(t.own_def, r * 2.2)
	if wet:
		return PropKind.REEDS if r < t.def.reed_chance else NONE
	return PASS


## The grounds every landscape reads the same way: the strandline and its wrack,
## shingle, fen, mud, peat, snow, loose rock and gravel. Run after the type's own
## recipe, so a type that wants its own answer on one of these takes it first.
static func shared(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.SAND:
		if t.sea_steps[i] <= 2:
			# The strandline: wrack in drifts, driftwood along it.
			var k := maxf(0.0, t.clump[i])
			if r < 0.02 + k * 0.08:
				return PropKind.WRACK
			return PropKind.DRIFTWOOD if r < 0.035 + k * 0.08 else NONE
		return t.def.shore_bush if r < 0.012 else NONE
	if g == Ground.SHINGLE:
		if t.sea_steps[i] <= 1 and r < 0.07:
			return PropKind.MUSSEL_ROCK
		if r < 0.1:
			return PropKind.WRACK
		if r < 0.12:
			return PropKind.DRIFTWOOD
		return PropKind.BOULDER if r < 0.14 else NONE
	if g == Ground.MOSS:
		var k := maxf(0.0, t.clump[i])
		if r < 0.03 + k * 0.08:
			return PropKind.REEDS
		if r < 0.045 + k * 0.08:
			return PropKind.DEAD_TREE
		return PropKind.BUSH if r < 0.055 + k * 0.08 else NONE
	if g == Ground.MUD:
		return PropKind.REEDS if r < 0.1 + maxf(0.0, t.clump[i]) * 0.35 else NONE
	if g == Ground.PEAT:
		# Banks are cut along the edge of a hag.
		if t.edge_of(i, Ground.PEAT) and r < 0.16:
			return PropKind.PEAT_BANK
		return PropKind.REEDS if r < 0.02 else NONE
	if g == Ground.SNOW:
		var k := maxf(0.0, t.forest[i] + 0.05)
		if t.levels[i] <= 9 and r < k * 0.5:
			return PropKind.SNOW_PINE
		if r < 0.008 + k * 0.5:
			return PropKind.DEAD_TREE
		return PropKind.BOULDER if r < 0.016 + k * 0.5 else NONE
	if g == Ground.NEEDLES:
		var k := maxf(0.0, t.forest[i] + 0.12)
		if t.own_def.id == &"snowfield":
			# A wood thinning into the snow: snow pines last.
			return PropKind.SNOW_PINE if r < 0.1 + k * 0.3 else NONE
		if r < (0.16 + k * 0.34) * green_reach(t, i):
			return PropKind.PINE
		if r < 0.17 + k * 0.34:
			return PropKind.DEAD_TREE
		return PropKind.BUSH if r < 0.2 + k * 0.34 else NONE
	if g == Ground.LIMESTONE:
		var k := maxf(0.0, t.clump[i])
		if r < 0.04 + k * 0.22:
			return PropKind.CLINTS
		if r > 0.3 and r < 0.302:
			return PropKind.STANDING_STONE
		# Seams show in the pavement's joints.
		return ore(t.own_def, (r - 0.44) * 1.6) if r > 0.44 else NONE
	if g == Ground.BONE:
		if r < 0.02:
			return PropKind.BONES
		return PropKind.BOULDER if r < 0.03 else NONE
	if g == Ground.ASH:
		# Burnt stumps in ash that is not a furnace's own.
		return PropKind.DEAD_TREE if r < 0.015 else NONE
	if g == Ground.CLINKER:
		if absf(t.fissure[i]) < 0.05 and r < 0.2:
			return PropKind.VENT
		if t.edge_of(i, Ground.CLINKER) and r < 0.16:
			# The flow's margin: a levee of blocks and the odd vent.
			return PropKind.BOULDER if r < 0.12 else PropKind.VENT
		if r < 0.006:
			return PropKind.VENT
		return PropKind.BOULDER if r < 0.02 else NONE
	if g == Ground.ROCK or g == Ground.SCREE:
		if r < 0.06:
			return PropKind.BOULDER
		return ore(t.own_def, r - 0.06)
	if g == Ground.GRAVEL:
		if r < 0.018:
			return PropKind.BOULDER
		return ore(t.own_def, (r - 0.018) * 3.0) if t.own_def.gravel_ore else NONE
	if g == Ground.GRASS:
		return PropKind.BUSH if r < 0.02 else NONE
	if g == Ground.HEATH:
		return PropKind.BUSH if r < 0.04 else NONE
	return PASS


## How far the green things get toward a landscape that burns them off: 1 away
## from it, 0 on its border, nothing inside it.
static func green_reach(t: BiomeScatter, i: int) -> float:
	if t.own_def.scorched:
		return 0.0
	if not t.other_def.scorched:
		return 1.0
	return clampf(1.0 - t.blends[i] * 2.6, 0.0, 1.0)


## A type's ore for a roll in [0, 1): low values are the common kinds,
## NONE is bare rock.
static func ore(def: BiomeDef, r: float) -> int:
	for row: Array in def.ore:
		if r < float(row[1]):
			return int(row[0])
	return NONE
