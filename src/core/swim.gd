class_name Swim
## Who may cross deep water, and what it does to them (owner, 2026-09-17).
##
## Deep water was a wall: `WorldQuery.standable` refused it to everything without
## a craft underneath. It is a slow crossing now for anything that can take it,
## and the owner's ruling is that it costs time and a soaking and never a
## player's things — no load limit, nothing dropped, nothing drowned. What a raft
## is still for is speed, a dry creel, and carrying what a swimmer cannot.
##
##   Swim.crosses(row)              what deep water is to this kind
##   Swim.deep(world, p)            the tile under p is out of a body's depth
##   Swim.drop_for(world, p, h)     how far to sink a figure so the water cuts it
##
## A craft under the body wins: a raft is not a swimmer, and `Hero.ride` is still
## 44_crafts' to write (docs/DESIGN.md §Crafts).
##
## What a kind makes of deep water is ONE key on its roster row, `crosses`:
## absent, it stops at the waterline as everything always has. The dredger keeps
## to wet ground and swims; the flock and the gulls go over. Nothing else in the
## roster crosses, which is what makes water worth running to and never safe.

## What a body makes of deep water.
const NONE := &""
const SWIM := &"swim"
const FLY := &"fly"

## How far into the water a body floats, as a share of its own height: a person
## is in to the chest, so the head, the shoulders and the stroke are what the
## player sees and the waterline cuts the figure where a person is cut.
const SINK_SHARE := 0.62
## No body is drawn deeper than this, whatever its height: a gull on the water is
## not a gull under it.
const SINK_MOST := 1.1


## What deep water is to the kind this row describes.
static func crosses(row: Dictionary) -> StringName:
	var c := StringName(str(row.get("crosses", NONE)))
	return c if c == SWIM or c == FLY else NONE


## Can a body of this kind be over deep water at all, swimming or flying?
static func may_cross(row: Dictionary) -> bool:
	return crosses(row) != NONE


## Is it IN the water rather than over it? A flier is never wet.
static func swims(row: Dictionary) -> bool:
	return crosses(row) == SWIM


## The tile under `p` is out of a body's depth. The shallows — water, river,
## black water — are waded as they always have been; only deep water is swum.
static func deep(world: WorldData, p: Vector2) -> bool:
	if world == null:
		return false
	return Ground.is_deep(world.ground_at(floori(p.x), floori(p.y)))


## Where the water is drawn, in world units. It duplicates `TerrainMesher.WATER_Y`
## on purpose — core holds no rendering — and `tests/swim/test_swim.gd` fails if
## the two ever drift, because a waterline the rules and the picture disagree
## about is a body swimming through the air.
const WATER_Y := 0.3


## How far under the surface a body of this kind floats: a dog is in to the neck,
## a dredger to its deck. Read off the roster row height, so a kind that is added
## needs no line here.
static func sink_of(row: Dictionary) -> float:
	return minf(maxf(float(row.get("height", 1.0)), 0.2) * SINK_SHARE, SINK_MOST)


## How far to drop a figure of height `h` standing at `p` so the water cuts it
## where it should, or 0 where it is not swimming. The bed is not modelled under
## deep water (`WorldData.height_at` clamps at 0) and the sheet is drawn at
## WATER_Y, so what is measured here is the surface down to the chest, not the
## ground up to the feet.
static func drop_for(world: WorldData, p: Vector2, h: float) -> float:
	if not deep(world, p):
		return 0.0
	var under := minf(maxf(h, 0.2) * SINK_SHARE, SINK_MOST)
	return maxf(0.0, under - WATER_Y)
