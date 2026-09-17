class_name Air
extends RefCounted
## What DISTANCE does in a place (docs/LOOK.md law 3, "the world has thickness").
##
## `lit` established that exponential fog under an orthographic camera is a flat
## grey wash over the entire frame, and replaced it with DEPTH fog that has a
## begin and an end. This file takes that the rest of the way, and it exists
## because of one measurement.
##
## THE MEASUREMENT. An orthographic camera 30 units back, showing 15 units of
## world height at 57 degrees of pitch, sees ground between depth 25.1 and 34.9.
## The whole frame is 9.8 units deep. The air `lit` left began at 31 and ended at
## 74, so at the very top of the picture -- the furthest thing a player can see --
## it had carried the land about **one per cent** of the way toward the horizon.
## Distance was doing nothing at all. The begin and the end were chosen against
## the comment's own guess at the depth range ("between about 26 and 60"), which
## is the range of the loaded CHUNKS and not of the frame.
##
## So the reach is no longer two constants. `reach()` derives it from the camera
## that is actually drawing -- its distance, the height it is showing and its
## pitch -- so a zoom, a target lean or a different rig cannot silently put the
## air back outside the picture. The near quarter of the frame is always clear
## (BEGIN_K < 1), the far edge is always well inside the ramp (END_K > 1), and
## the curve keeps the middle honest.
##
## Because it is DEPTH, and depth is measured along the view axis, HEIGHT buys
## clarity for free: a ridge standing up at the top of the frame is 0.84 units
## nearer the eye per unit it rises, so it comes out of the haze the flat ground
## beside it is sunk in. That is aerial perspective doing the one thing a filter
## cannot, and it is the whole reason this is worth having.
##
## THE SECOND IDEA, and the cheaper one: **distance does not do the same thing
## everywhere.** Far goes DARK in the moss bog and under the pinewood, and PALE
## on the snowfield and the salt. One landscape's air is peat and rot; another's
## is glare off a white pan. The hour still authors the colour -- `tow` only
## BENDS the sky's own horizon colour, by `pull`, so dusk is still dusk in the
## bog -- but which way it bends is the place's own, and it costs one lerp.
##
## Nothing here is a filter over the frame. It is a term that grows with distance
## and is zero where the player is standing.

## A ROW, per landscape type id.
##
##   tow    Color   the colour this place's air carries the distance TOWARD
##   pull   0..1    how far the hour's own horizon colour is bent toward `tow`
##   depth  float   multiplier on DEPTH: how much of the far edge the air takes
##   near   float   multiplier on BEGIN_K: under 1 the haze starts nearer the eye
##   bank   float   multiplier on the volumetric density, where a tier has it
const ROWS := {
	# The sea's air is bright and wet: distance goes pale and slightly blue, and
	# it starts far out, because there is nothing between you and the horizon.
	&"sea": {"tow": Color(0.74, 0.80, 0.86), "pull": 0.30, "depth": 0.85, "near": 1.10, "bank": 0.9},
	# The coast is the neutral one on purpose. It is the first place a player
	# stands and it is where every other landscape's air is judged against.
	# Measured: at depth 1.00 the coast lost 29% of the contrast in the top fifth
	# of the frame, which is more than the bog does, on the landscape that is
	# supposed to be the quiet one. Mid-value grass carried toward a pale horizon
	# moves further per unit of density than either a dark bog or bright snow, so
	# the neutral row has to ASK for less to READ as less.
	&"coast": {"tow": Color(0.66, 0.71, 0.75), "pull": 0.18, "depth": 0.82, "near": 1.00, "bank": 1.0},
	# The bog: far goes DARK. Peat, standing water and rot, and the haze begins
	# close, so the next rise is already a silhouette.
	&"moss": {"tow": Color(0.085, 0.115, 0.105), "pull": 0.72, "depth": 1.25, "near": 0.82, "bank": 1.5},
	# Under the pines: far goes dark and cold. The same trick as the bog with a
	# different hue, which is what makes them two places and not one mood.
	&"pinewood": {"tow": Color(0.075, 0.105, 0.135), "pull": 0.66, "depth": 1.20, "near": 0.86, "bank": 1.35},
	# The snowfield: far goes PALE, and this is the inversion the whole idea is
	# for. Distance eats the land instead of darkening it -- but snow is already
	# at luma 221 and there is nothing left to carry it TOWARD, so at the depth
	# the bog uses it moved 8% and read as nothing. What distance takes from snow
	# is not its value, it is its TEXTURE: the row asks for half again as much
	# air, in a colour a little cooler than the snow itself, so the far field
	# flattens into its own glare while the near field keeps its shade.
	&"snowfield": {"tow": Color(0.88, 0.92, 1.00), "pull": 0.72, "depth": 1.60, "near": 0.84, "bank": 1.2},
	# The salt: pale, but bone rather than snow, and drier -- it starts further
	# out, because a salt pan is flat and the glare is what closes it, not water.
	&"salt_flats": {"tow": Color(0.91, 0.89, 0.82), "pull": 0.62, "depth": 1.15, "near": 0.96, "bank": 0.8},
	# Bonelands: dust. Pale and warm, thinner than the salt's glare.
	&"bonelands": {"tow": Color(0.84, 0.79, 0.68), "pull": 0.48, "depth": 1.05, "near": 0.98, "bank": 0.85},
	# The Burning: soot over a furnace. Far goes dark AND warm, which no other
	# place does, and it begins very close.
	&"burning": {"tow": Color(0.20, 0.115, 0.085), "pull": 0.70, "depth": 1.35, "near": 0.78, "bank": 1.6},
	# Scrapwood: oil haze off wet metal. Dark, a little green.
	&"scrapwood": {"tow": Color(0.12, 0.135, 0.125), "pull": 0.55, "depth": 1.10, "near": 0.90, "bank": 1.2},
	# Under the limestone there is no horizon: the dark IS the distance, and it
	# is nearer than anywhere on the surface. A roofed realm reads as night at
	# any hour (SkyLight.closed), and this is the air that goes with it.
	&"limestone_caves": {"tow": Color(0.035, 0.040, 0.055), "pull": 0.86, "depth": 1.45, "near": 0.70, "bank": 1.8},
}

## A landscape with no row of its own: the coast's air, which is nearly neutral.
## A new landscape reads as ordinary rather than as broken, and adds a row when
## somebody has looked at it.
const DEFAULT := {"tow": Color(0.66, 0.71, 0.75), "pull": 0.18, "depth": 1.00, "near": 1.00, "bank": 1.0}

## Where the air begins and ends, as multiples of the frame's own depth half-span
## either side of the focus. BEGIN_K under 1 keeps the near part of the picture
## -- where the player is standing and where anything that matters to them is --
## completely clear; END_K over 1 puts the end of the ramp past the far edge, so
## the furthest land is deep in the air but never at the end of it.
const BEGIN_K := 0.86
const END_K := 1.62
## How hard the ramp is held off the near ground. Over 1, so the middle of the
## frame stays nearly clear and the term only really arrives at the far edge.
const CURVE := 1.9
## What the far edge of a clear frame is carried toward its air colour, before a
## landscape's own `depth` multiplies it.
const DEPTH := 0.55

## The most the air may ever take, whatever the weather, the hour and the
## landscape multiply up to. **This is a readability cap, not a taste one.** At
## 1.0 a machine standing at the top of the frame is the colour of the air and
## the player cannot see it coming; the brief this package was built to says an
## occluder may never hide a threat, and neither may a bank of fog. Measured
## against a hunter at nine tiles on the moss at noon, which is the worst case
## the game has (dark machine, dark air).
const MOST := 0.62


## The row for one landscape type id.
static func row(id: StringName) -> Dictionary:
	return ROWS.get(id, DEFAULT)


## The air over a frame that holds several landscapes, weighted by how much of
## each is in view (`10_sky.sample_types`, the same shares the light and the
## grade are composed from). A border is a place where one air becomes another,
## and the crossfade is what says so.
static func at(shares: Dictionary) -> Dictionary:
	if shares.is_empty():
		return DEFAULT.duplicate()
	var tow := Color(0, 0, 0, 0)
	var pull := 0.0
	var depth := 0.0
	var near := 0.0
	var bank := 0.0
	var total := 0.0
	for id: StringName in shares:
		var w := float(shares[id])
		if w <= 0.0:
			continue
		var r := row(id)
		var c: Color = r.tow
		tow += Color(c.r * w, c.g * w, c.b * w, 0.0)
		pull += float(r.pull) * w
		depth += float(r.depth) * w
		near += float(r.near) * w
		bank += float(r.bank) * w
		total += w
	if total <= 0.0:
		return DEFAULT.duplicate()
	return {
		"tow": Color(tow.r / total, tow.g / total, tow.b / total),
		"pull": pull / total, "depth": depth / total,
		"near": near / total, "bank": bank / total,
	}


## Where the air begins and ends, in world units of depth, for the camera that is
## really drawing. `view_size` is the camera's own `size` (so a zoom or a target
## lean is already in it), `pitch_deg` its pitch below the horizontal, `distance`
## how far back it stands.
##
## The frame's depth half-span is the ground displacement that fills half the
## screen, resolved onto the view axis: (size/2) / tan(pitch). Everything else
## here is that number times a constant, which is why a change of rig cannot put
## the air outside the picture again.
static func reach(distance: float, view_size: float, pitch_deg: float, near_k: float = 1.0) -> Vector2:
	var half := frame_depth(view_size, pitch_deg)
	return Vector2(distance - half * BEGIN_K * near_k, distance + half * END_K)


## Half the depth the frame spans, in world units. Public because it is the one
## number every other constant here is stated in multiples of, and because a test
## that could not measure it would be pinning arithmetic instead of a picture.
static func frame_depth(view_size: float, pitch_deg: float) -> float:
	var t := tan(deg_to_rad(clampf(pitch_deg, 5.0, 89.0)))
	return maxf(0.5, view_size * 0.5 / maxf(0.05, t))


## The colour the distance is carried toward: the hour's own horizon, bent by
## `pull` toward the place's `tow`. The hour still authors it.
static func colour(horizon: Color, air: Dictionary) -> Color:
	return horizon.lerp(air.tow, clampf(float(air.pull), 0.0, 1.0))


## How much of the far edge the air takes, after the weather and the landscape
## have had their say, held under MOST so nothing can ever be lost in it.
static func density(air: Dictionary, thickness: float) -> float:
	return minf(DEPTH * float(air.depth) * maxf(thickness, 0.0), MOST)
