class_name BiomeSurface
extends RefCounted
## One tile, as a landscape type's ground recipe sees it. GenSurface keeps one
## of these per band and moves it from tile to tile.
##
## The three fields EVERY recipe reads come as arguments, because the tile loop
## has them in hand already and an argument costs a fraction of a property:
## `e` the smoothed elevation, `rs` how far the tile stands above the land about
## it, `gb` the broad mass field. Everything rarer is on the sample, indexed by
## `i`:
##
##     static func _surface(t: BiomeSurface, e: float, rs: float, gb: float) -> int:
##         if t.shore:
##             return Ground.SHINGLE
##         return Ground.HEATH if rs > 0.4 else Ground.GRASS
##
## Everything here is smooth at the scale of a walk (docs/ART.md: grounds are
## washes, not salad). There is deliberately no per-tile noise and no integer
## level on this sample: a recipe that wants variety asks `big`, `rise`,
## `forest` or a distance, so its grounds mass into shapes the mesher can draw
## as long curves.

## The tile, as an index into every field below.
var i := 0

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

# --- this tile ------------------------------------------------------------

## Integer level of the tile.
var level := 0
## Within two tiles of a beach, at the foot of a tall face, beside a river.
var shore := false
var apron := false
var bank := false
## How far this tile has turned toward the type across the nearest border
## (0.5 on the border), and the two types themselves.
var blend := 0.0
var own_def: BiomeDef
var other_def: BiomeDef

## Set only while a type with a caldera is laying its ground: tiles from its
## heart, the warped distance the rim is measured by, the rim's radius, and the
## lava-flow field here (-1..1).
var heart_dist := 0.0
var rim_dist := 0.0
var crater := 0.0
var flow := 0.0
