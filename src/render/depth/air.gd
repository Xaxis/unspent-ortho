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
	# The snowfield: far goes PALE against a DARK land, which is the inversion the
	# whole idea is for -- and the hardest row here, twice measured.
	#
	# Snow is already at luma 221. Carried toward a paler air it has nothing to
	# move to: at `depth` 1.30 the top fifth of the frame lost 8% of its contrast
	# and at 1.60 it lost 7.7%, because `Air.MOST` had capped both at the same
	# number. Raising the row past 1.13 in clear weather does nothing at all.
	#
	# So the air is not paler than the snow, it is COLDER and a little darker --
	# the horizon dissolving into grey, which is what distance on a snowfield
	# really looks like -- and the pull does the work the depth could not.
	&"snowfield": {"tow": Color(0.76, 0.83, 0.95), "pull": 0.78, "depth": 1.15, "near": 0.84, "bank": 1.2},
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
	# Under the dome the air IS the landscape. Distance goes PALE and dirty, not
	# dark: smog over a lit city is lit from underneath and whites the far end of
	# a street out, which is the opposite of a cave and the opposite of what was
	# first written here. A near-black tow at pull 0.58 took a noon frame to
	# almost nothing — past the luma-24 floor `noir` was rejected for.
	# The crags are what fog is FOR (BiomeDef.mist, its weather): the far land goes
	# to a wet pale grey, the air begins close, and the bank is thick, so even a
	# clear day there has distance in it that no other upland has.
	# The sulphur jungle's air is WET and HOT: a yellow-green haze that begins
	# close, so the canopy fades into its own steam.
	&"sulphur_jungle": {"tow": Color(0.52, 0.55, 0.36), "pull": 0.52, "depth": 1.22, "near": 0.85, "bank": 1.4},
	# The mesas' distance goes to warm red dust, and begins far: the air is dry
	# and the canyon country is seen a long way off.
	&"mesas": {"tow": Color(0.80, 0.62, 0.50), "pull": 0.46, "depth": 1.05, "near": 1.05, "bank": 0.8},
	&"the_crags": {"tow": Color(0.62, 0.66, 0.70), "pull": 0.66, "depth": 1.30, "near": 0.80, "bank": 1.7},
	&"slums": {"tow": Color(0.300, 0.228, 0.170), "pull": 0.34, "depth": 1.20, "near": 0.90, "bank": 1.45},
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
static func reach(distance: float, view_size: float, pitch_deg: float, near_k: float = 1.0,
		fov_deg: float = 0.0) -> Vector2:
	var half := frame_depth(view_size, pitch_deg) if fov_deg <= 0.0 \
			else frame_depth_lens(distance, pitch_deg, fov_deg)
	return Vector2(distance - half * BEGIN_K * near_k, distance + half * END_K)


## Half the depth the frame spans, in world units. Public because it is the one
## number every other constant here is stated in multiples of, and because a test
## that could not measure it would be pinning arithmetic instead of a picture.
static func frame_depth(view_size: float, pitch_deg: float) -> float:
	var t := tan(deg_to_rad(clampf(pitch_deg, 5.0, 89.0)))
	return maxf(0.5, view_size * 0.5 / maxf(0.05, t))


## HOW FAR THE TOP EDGE MAY RUN BEFORE THE AIR STOPS MEANING ANYTHING, as the
## angle between it and the horizon. This is the horizon fork again, in a third
## place: the streamer caps its reach for it, `CameraRig` asserts `fov/2 < pitch`
## for it, and here it stops the far intersection running away. Measured, at the
## shipped lens: margin 12.5 deg gives a half-span of 14.5, margin 0.5 gives 340
## and margin 0.01 gives 16907 -- at which point the fog's begin and end are past
## everything in the world and the air silently ceases to exist, which is exactly
## the failure `lit` was built to fix, arrived at from the other side.
##
## 2 degrees is loose enough that the shipped pitch is nowhere near it and tight
## enough that a configuration walking toward the horizon DEGRADES rather than
## deletes. It is not a taste.
const LENS_TOP_LEAST := 2.0


## The same half-span for a LENS, which has no `view_size` to halve.
##
## Same quantity, same definition, derived rather than assumed: half the
## view-axis depth between where the BOTTOM edge and the TOP edge meet the plane
## the focus stands on. The eye is `distance * sin(pitch)` above that plane, and
## a ray at `t` below the horizontal meets it at view-axis depth
## `E * cos(t - pitch) / sin(t)`, so the span is the difference of the two edges.
##
## It agrees with the orthographic form where both apply: the orthographic
## expression is this one for parallel rays, and the two were checked equal to
## 1.78e-15 at two view heights before this was written.
static func frame_depth_lens(distance: float, pitch_deg: float, fov_deg: float) -> float:
	var half_fov := clampf(fov_deg, 1.0, 170.0) * 0.5
	var top := deg_to_rad(maxf(pitch_deg - half_fov, LENS_TOP_LEAST))
	var bot := deg_to_rad(minf(pitch_deg + half_fov, 89.0))
	var eye := maxf(distance, 0.1) * sin(deg_to_rad(clampf(pitch_deg, 1.0, 89.0)))
	var span := eye * cos(deg_to_rad(half_fov)) * 0.5 \
			* (1.0 / maxf(sin(top), 0.001) - 1.0 / maxf(sin(bot), 0.001))
	return maxf(0.5, span)


## The colour the distance is carried toward: the hour's own horizon, bent by
## `pull` toward the place's `tow`. The hour still authors it.
static func colour(horizon: Color, air: Dictionary) -> Color:
	return horizon.lerp(air.tow, clampf(float(air.pull), 0.0, 1.0))


## How much of the far edge the air takes, after the weather and the landscape
## have had their say, held under MOST so nothing can ever be lost in it.
static func density(air: Dictionary, thickness: float) -> float:
	return minf(DEPTH * float(air.depth) * maxf(thickness, 0.0), MOST)
