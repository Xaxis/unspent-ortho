class_name Dome
extends RefCounted
## Where a lid over a landscape is TORN, and where the light that gets through it
## lands (`BiomeDef.sky_shut`, `src/systems/11_dome.gd`).
##
## A landscape can say the sky does not reach it. This says the one thing that
## makes that worth walking through rather than merely dark: the lid is not
## perfect. Where it is torn a hard column of dirty daylight comes down, and the
## patch it lays on the ground is the brightest thing in the landscape.
##
## THE PATCH MOVES WITH THE HOUR, and that is the whole point of it. A tear is a
## hole at a fixed place in the lid; the light through it lands wherever the sun
## is pushing it, so the pool walks across a street over the day and out of it by
## evening. A player who learns a city learns where the light falls and when,
## which is a thing to know about a place rather than a thing to look at.
##
## It is spent on the SAME BEARING the sky lights the world with (`SkyLight.sun_at`),
## and that is not a detail: were a shaft aimed by any other rule, the light in
## the street and the shadows in it would disagree, and the eye reads that
## instantly even when it cannot say what is wrong.
##
## Pure and derived, like a landmark site or a depot: nothing here is saved,
## because a hole in a lid is a property of the world and not of the game. Same
## seed, same tears, for ever.

## The coarse grid the tears are dealt on, in tiles. Big enough that two are
## never in one frame (the play camera shows about 27 x 18 tiles of ground), so
## a shaft is an event in a street and not a row of skylights.
const CELL := 26
## How many cells hold one. Under half, so a walk turns up dark streets between
## the lit ones and the light is worth walking to.
const CHANCE := 0.42
## How far under the lid the street lies, in world units. It is what decides how
## far the patch travels over a day: the offset is HEIGHT / tan(elevation), so a
## taller dome swings the light further and a lower one keeps it in one street.
const HEIGHT := 13.0
## How wide the patch is where it lands, in world units.
const SPREAD := 2.6
## A tear is dealt this far off its cell's centre, at most, in tiles, so the
## grid the cells make can never be read off the world.
const JITTER := 7.0

const SALT_HAS := 0x5D0E
const SALT_X := 0x5D1F
const SALT_Y := 0x5D2A


## Whether the cell (cx, cy) holds a tear, and where in tile space if it does.
## Vector2.INF for a cell with none, so a caller never has to ask twice.
static func tear_in(seed_value: int, cx: int, cy: int) -> Vector2:
	if Rng.hash01(seed_value, cx, cy, SALT_HAS) >= CHANCE:
		return Vector2.INF
	var jx := (Rng.hash01(seed_value, cx, cy, SALT_X) - 0.5) * 2.0 * JITTER
	var jy := (Rng.hash01(seed_value, cx, cy, SALT_Y) - 0.5) * 2.0 * JITTER
	return Vector2(float(cx) * CELL + CELL * 0.5 + jx, float(cy) * CELL + CELL * 0.5 + jy)


## Every tear within `reach` tiles of `at`, nearest first.
static func tears(seed_value: int, at: Vector2, reach: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	# The jitter can carry a tear a cell's own width out of its cell, so the sweep
	# reaches one cell wider than the radius or a shaft would pop in at the edge.
	var span := int(ceilf((reach + JITTER) / float(CELL)))
	var c0 := Vector2i(int(floorf(at.x / CELL)), int(floorf(at.y / CELL)))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var p := tear_in(seed_value, c0.x + dx, c0.y + dy)
			if p.x == INF:
				continue
			if p.distance_to(at) <= reach:
				out.append(p)
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(at) < b.distance_squared_to(at))
	return out


## Where the light through a tear at `tear` lands on the ground, for a sun at
## this bearing and elevation (`SkyLight.sun_at` gives both, in degrees).
##
## The offset is the same one SkyLight hands the shaders to line a cloud's shadow
## on a wall up with its shadow on the ground — it points TOWARD the light per
## unit of height — so the patch is where the tear's own shadow would be, which
## is to say where the light it lets through goes. Reading it off the same
## expression is what keeps the shaft and every cast shadow in the frame on one
## bearing.
static func patch(tear: Vector2, azimuth: float, elevation: float) -> Vector2:
	var toward := Vector2(sin(deg_to_rad(azimuth)), cos(deg_to_rad(azimuth))) / maxf(0.2, tan(deg_to_rad(elevation)))
	return tear - toward * HEIGHT


## The cone a spot light needs to lay SPREAD of ground from HEIGHT up, in degrees.
static func cone_degrees() -> float:
	return rad_to_deg(atan(SPREAD * 0.5 / HEIGHT))
