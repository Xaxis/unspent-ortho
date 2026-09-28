class_name Tether
extends RefCounted
## THE TETHER (docs/STORY.md: "the Tether and Foundry rise"; the far shore is
## "the Emissary's works at the Tether's foot"): one made thing, a hair-thin line
## rising off the far shore's horizon to the FOUNDRY, a small steady light fixed
## in the sky. A real tether climbs to a point that does not move, so this one
## does not: it is there from the first morning, the same every night, and the
## ring (19_orbit), lower and dead, passes near it every thirty-odd hours.
##
## PURE AND DERIVED: a function of the world, never saved. Directions are the
## ring's own frame (OrbitPass): x east, y up, z south, a world tile's x and y
## being east and south. The foot is inside the island, a couple of kilometres
## off at most, and the line climbs thousands, so from anywhere on the coast it
## stands in one vertical plane: the far shore's BEARING is all that places it.
##
##   Tether.bearing(world, foot) -> float    radians, 0 east, PI/2 south
##   Tether.top(world) -> float              the Foundry's elevation, radians
##   Tether.flat(world, foot) -> Vector3     the horizontal way to the foot
##   Tether.foundry(world, foot) -> Vector3  the direction of the Foundry

## Where the Foundry stands in the sky: high enough that the line reads as
## climbing out of the world, low enough that a view over the shoulder turned
## toward the far shore holds the whole of it.
const TOP_LEAST := deg_to_rad(46.0)
const TOP_MOST := deg_to_rad(60.0)
## The climber's trip from the foot to the Foundry, in real seconds: slow
## enough that a player watching sees it move and does not see it arrive.
const CLIMB_SECONDS := 240.0


## `foot`: where the far shore's works stand (StoryPlan's `the_far_works`, which
## 49_cast keeps), or Vector2.INF where the story places none; then a bearing
## of the world's own.
static func bearing(w: WorldData, foot: Vector2) -> float:
	var to := foot - w.spawn
	if foot == Vector2.INF or to.length() < 1.0:
		return Rng.hash01(w.seed_value, 0, 0, 0x7E7) * TAU
	return atan2(to.y, to.x)


static func top(w: WorldData) -> float:
	return lerpf(TOP_LEAST, TOP_MOST, Rng.hash01(w.seed_value, 1, 0, 0x7E7))


static func flat(w: WorldData, foot: Vector2) -> Vector3:
	var b := bearing(w, foot)
	return Vector3(cos(b), 0.0, sin(b))


static func foundry(w: WorldData, foot: Vector2) -> Vector3:
	var e := top(w)
	return flat(w, foot) * cos(e) + Vector3.UP * sin(e)
