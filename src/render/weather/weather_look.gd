class_name WeatherLook
## How each kind of weather looks, and how the weathers of the countries around
## the camera mix into one sky. Pure data and arithmetic, so it is tested
## headless; WeatherView and SkyLight only draw what compose() returns.

## Colour multiplies at full strength, eased toward 1 by strength. Rain, storm,
## fog, snow, hail, heat and dust (the source's sand) are the source's numbers.
## Glare never brightens: it bleaches (sky_air.y), and its multiply only takes
## a little warmth out of the blue.
const MULTIPLY := {
	&"clear": Vector3(1.0, 1.0, 1.0),
	&"grey": Vector3(0.86, 0.88, 0.92),
	&"rain": Vector3(0.84, 0.87, 0.94),
	&"storm": Vector3(0.70, 0.75, 0.88),
	&"fog": Vector3(0.88, 0.91, 0.94),
	&"hail": Vector3(0.84, 0.88, 0.95),
	&"snow": Vector3(0.95, 0.97, 1.0),
	&"blizzard": Vector3(0.82, 0.86, 0.95),
	&"ash": Vector3(0.84, 0.79, 0.74),
	&"heat": Vector3(1.0, 0.96, 0.88),
	&"dust": Vector3(0.94, 0.84, 0.68),
	&"drizzle": Vector3(0.84, 0.89, 0.88),
	&"whiteout": Vector3(0.90, 0.94, 1.0),
	&"glare": Vector3(1.0, 1.0, 0.97),
	&"dry_storm": Vector3(0.84, 0.78, 0.74),
	&"haze": Vector3(0.90, 0.78, 0.66),
}

## Cloud cover (the share of the land in cloud shade) at strength 0 and at
## strength 1. Fair days keep a few clouds, about a fifth of the land, so their
## shadows always walk over it without dimming the day.
const COVER := {
	&"clear": [0.18, 0.18], &"grey": [0.2, 0.9], &"rain": [0.2, 0.95], &"storm": [0.24, 1.0],
	&"fog": [0.15, 0.1], &"hail": [0.22, 0.9], &"snow": [0.2, 0.85], &"blizzard": [0.24, 1.0],
	&"ash": [0.18, 0.7], &"heat": [0.1, 0.03], &"dust": [0.18, 0.45],
	&"drizzle": [0.2, 0.95], &"whiteout": [0.24, 1.0], &"glare": [0.08, 0.0], &"dry_storm": [0.22, 0.75],
	&"haze": [0.15, 0.5],
}

## How far a kind at full strength hides the sun: at 0.6 and over, nothing casts.
const OVERCAST := {
	&"grey": 0.75, &"rain": 0.9, &"storm": 1.0, &"fog": 0.72, &"hail": 0.9, &"snow": 0.8,
	&"blizzard": 1.0, &"ash": 0.66, &"dust": 0.5,
	&"drizzle": 0.85, &"whiteout": 1.0, &"dry_storm": 0.55, &"haze": 0.62,
}

## What falls or hangs, per kind: rain, drizzle, hail, snow, ash, dust, fog, heat
## haze, and the M2.0 airs: whiteout (the page goes white), glare (the light
## bleaches), haze (fog drawn warm and dirty, lying low), bolt (lightning).
const FALL := {
	&"rain": {"rain": 0.75, "fog": 0.0},
	&"storm": {"rain": 1.0, "bolt": 1.0},
	&"hail": {"hail": 1.0, "rain": 0.25},
	&"snow": {"snow": 0.8},
	&"blizzard": {"snow": 1.0, "fog": 0.3},
	&"fog": {"fog": 1.0},
	&"ash": {"ash": 1.0},
	&"heat": {"heat": 1.0},
	&"dust": {"dust": 1.0, "fog": 0.25},
	&"drizzle": {"drizzle": 1.0, "fog": 0.35},
	&"whiteout": {"snow": 1.0, "fog": 0.45, "whiteout": 1.0},
	&"glare": {"glare": 1.0, "heat": 0.45},
	# A dry storm is dust on a hard wind before it is lightning: it must read
	# as the bonelands' own storm between the strikes.
	&"dry_storm": {"dust": 0.7, "bolt": 1.0},
	&"haze": {"haze": 1.0, "fog": 0.8, "ash": 0.2, "heat": 0.25},
}

const FALLS: Array[String] = ["rain", "drizzle", "hail", "snow", "ash", "dust", "fog", "heat", "whiteout", "glare", "haze", "bolt"]


## entries: Array of {kind, strength, weight} (weights sum to about 1; the
## countries sampled around the camera). Returns everything the sky draws:
## {tint: Vector3, cover, cloud, overcast, rain, drizzle, hail, snow, ash, dust,
##  fog, heat, whiteout, glare, haze, bolt, storm: float}. Every value is
## continuous in each strength, so a border walked mid-storm thins the rain
## rather than cutting it.
static func compose(entries: Array) -> Dictionary:
	var out := {"tint": Vector3.ONE, "cover": 0.0, "cloud": 0.0, "overcast": 0.0, "storm": 0.0}
	for f: String in FALLS:
		out[f] = 0.0
	var total := 0.0
	for e: Dictionary in entries:
		total += float(e.weight)
	if total <= 0.0:
		return out
	var amount := {}
	for e: Dictionary in entries:
		var k: StringName = e.kind
		var w := float(e.weight) / total
		var s := float(e.strength)
		amount[k] = float(amount.get(k, 0.0)) + w * s
		var cov: Array = COVER.get(k, [0.3, 0.3])
		out.cover += w * lerpf(cov[0], cov[1], s)
		out.overcast += w * s * float(OVERCAST.get(k, 0.0))
		var fall: Dictionary = FALL.get(k, {})
		for f: String in fall:
			out[f] = float(out[f]) + w * s * float(fall[f])
	var tint := Vector3.ONE
	for k: StringName in amount:
		var m: Vector3 = MULTIPLY.get(k, Vector3.ONE)
		tint *= Vector3.ONE.lerp(m, clampf(amount[k], 0.0, 1.0))
	out.tint = tint
	out.storm = float(amount.get(&"storm", 0.0))
	# Under a full overcast the separate cloud shadows fade into the general
	# dimming; the gaps of light are what is left to see.
	out.cloud = lerpf(0.9, 0.45, clampf(out.overcast, 0.0, 1.0))
	for f: String in FALLS:
		out[f] = clampf(out[f], 0.0, 1.0)
	return out


## How warm the fog in view is drawn, 0..1: the share of it that is furnace haze.
static func haze_share(look: Dictionary) -> float:
	return clampf(float(look.get("haze", 0.0)) * 0.8 / maxf(0.05, float(look.get("fog", 0.0))), 0.0, 1.0)
