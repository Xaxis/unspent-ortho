class_name BiomeSurface
extends RefCounted
## One tile, as a landscape type's ground recipe sees it. GenSurface keeps one
## of these per band and moves it from tile to tile.
##
## NOTHING on the sample changes from tile to tile. Everything a recipe needs
## per tile comes as an ARGUMENT: the tile `i`, `e` the smoothed elevation, `rs`
## how far the tile stands above the land about it, `gb` the broad mass field,
## and `f`, the places a tile can be, as bits. Everything rarer is a BAND field
## here, indexed by `i`:
##
##     static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
##         if f & BiomeSurface.SHORE != 0:
##             return Ground.SHINGLE
##         return Ground.HEATH if rs > 0.4 else Ground.GRASS
##
## That rule is not tidiness, it is the world's start time. Writing one property
## on this object costs about what the whole rest of the tile loop costs, and
## worse: every worker thread laying a band takes the same engine-wide lock to
## do it, so three writes a tile cost the surface pass a third of a second on a
## 512-tile world (measured, main vs this branch). Add a band field, pass an
## argument, never a per-tile write.
## Everything here is smooth at the scale of a walk (docs/ART.md: grounds are
## washes, not salad). There is deliberately no per-tile noise and no integer
## level on this sample: a recipe that wants variety asks `big`, `rise`,
## `forest` or a distance, so its grounds mass into shapes the mesher can draw
## as long curves.

## Bits of the `f` argument: within two tiles of a beach, at the foot of a tall
## face, beside a river.
const SHORE := 1
const APRON := 2
const BANK := 4

# --- the band's fields (set once, not per tile) ---------------------------

## Smoothed float elevation in levels.
var elev: PackedFloat32Array
## How far a tile stands above the land about 30 tiles around it.
var rise: PackedFloat32Array
## The broad mass field (1/48): where a ground gathers.
var big: PackedFloat32Array
## Share of land within ~24 tiles: < 0.5 on a headland, > 0.5 in a bay.
var convex: PackedFloat32Array
## Woodland.
var forest: PackedFloat32Array
## 4-neighbour steps from the sea, and from a salt-marsh estuary.
var sea_steps: PackedByteArray
var marsh: PackedByteArray
## Integer level per tile, and how far each tile has turned toward the type
## across the nearest border (0.5 on the border).
var levels: PackedInt32Array
var blends: PackedFloat32Array

# --- handed over only where the land changes ------------------------------

## The type that holds the tile, and the type across the nearest border. Both
## change only at a border, so the tile loop hands them over there and nowhere
## else; a recipe reads them, never writes them.
var own_def: BiomeDef
var other_def: BiomeDef

## Set only while a type with a caldera is laying its ground: tiles from its
## heart, the warped distance the rim is measured by, the rim's radius, and the
## lava-flow field here (-1..1).
var heart_dist := 0.0
var rim_dist := 0.0
var crater := 0.0
var flow := 0.0
