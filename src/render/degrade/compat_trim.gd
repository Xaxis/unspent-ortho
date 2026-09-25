class_name CompatTrim
extends RefCounted
## What the Compatibility renderer's light has to be told so that a web frame is
## the desktop's place (docs/LOOK.md: "the same place, on a worse night").
##
## THE FLOOR UNDER THE WEB FRAME. The first side-by-side of the canon had every
## web frame lifted and flattened -- the spawn at noon 195 luma against the
## desktop's 146, the night 87 against 46 -- and it was not the colour door: a
## flat unshaded quad comes back from Compatibility exactly as it was written
## (`perf colour`), so `sky_linear` is right on both renderers. It was the LIGHT,
## found by switching it (`perf features`, `perf shadowpass`, `perf sunpath` in
## render_probe.gd), with desktop gl_compatibility and the exported web build
## agreeing to the third decimal:
##
##   1. A sun that CASTS is drawn by Compatibility in a pass of its own, and that
##      pass does not add what the base pass would have. On a lit quad, turning the
##      shadow on added the surface's ambient again (+0.169 on a 0.5 red) and its
##      emission again (+0.071 of 0.1). On the land it adds far more than that: with
##      the ambient and the emission taken to zero the shadowed frame was STILL
##      brighter than the unshadowed one, and the sun energy that matches the
##      desktop is about a seventh of the desktop's. The desktop goes 154 -> 151
##      luma for the switch; Compatibility 169 -> 199.
##   2. Compatibility lights the palette's display values (it has to: it hands
##      ALBEDO to the screen unchanged), so the lamps, the bloom, the depth fog and
##      the filmic curve all land on different numbers than on the desktop, where
##      they work on linear light. Glow lifted the web noon by 10.6 luma against
##      the desktop's 2.5; the fog by 10.8 against 5.6.
##
## Neither is a feature the web lacks, so neither has a stand-in: it is the same
## light counted differently, and the answer is to count it back. The rows are
## multipliers on what SkyLight and the lights compose -- the sun, the ambient, the
## lamps, the exposure, the bloom, the fog, the emission, and the grade's contrast
## and saturation -- and they were FITTED, not chosen: `perf match` holds a frame of
## the running game against the desktop's own frame of the same moment, pixel for
## pixel, and walks each number to where the two differ least (`tours/degrade_fit.tour`,
## on the desktop's Compatibility, which measured identical to the web build).
##
## Each row is the median, key by key, of what the fit walked to at every place of
## its kind, and day and night are fitted apart and blended by how far night has
## fallen, because the error is not one number: lighting display values instead of
## linear light is wrong by a different amount at every level of light.
##
## Measured in the exported web build against the desktop, mean absolute channel
## difference 0..255 (tools/canon.sh --web): the eighteen canon places 44.4 before,
## 10.6 after; five overcast places (tours/degrade_grey.tour) 17.9 before, 7.9 after.
## After the desktop's day was relit (2026-09-24) and these rows refitted, the
## eighteen measure 10.9 in the web build (the spawn morning furthest, 22.1: the
## sea's glitter is a different pattern on each renderer).
## Before that, the furthest was the Burning by day (17.3; 12.8 now): the web was 14 luma darker and
## the machines' cold vent light carries no halo, which on the desktop is the
## volumetric air round it.
##
## On Forward+ every number is 1 and this file does nothing.

## What a row may say, and the identity.
const IDENTITY := {"sun": 1.0, "ambient": 1.0, "lamps": 1.0, "emission": 1.0, "glow": 1.0, "fog": 1.0, "exposure": 1.0, "contrast": 1.0, "saturation": 1.0}
## The keys in the order a fit walks them: the ones that move the most light
## first, so the finer ones are fitted against a frame already near the target.
const KEYS: Array[String] = ["sun", "ambient", "lamps", "exposure", "glow", "fog", "emission", "contrast", "saturation"]

## While the sun casts (Compatibility's second pass runs), by day and by night --
## the moon casts too. Each is the median, key by key, of the rows `perf match`
## walked to at every canon place of its kind: twelve by day, four by night (the
## two dusks sat between the two, which is what the blend by `night` gives them).
## A key no place could tell apart from its neighbours (the lamps by day) takes
## the value the places that could see it chose.
##
## REFITTED 2026-09-24 after the desktop's day was relit (SUN_NOON 1.17,
## DAY_AMBIENT 0.26, no depth fog over a clear top-down day). The day FOG is the
## big mover (0.6 -> 0.1): the desktop dropped its day fog while the web keeps its
## own as the volumetric stand-in, so the web now counts nearly all of it back.
## The day CONTRAST stays at 0.95 although its median walked to 0.85, because the
## rows were measured WHOLE against the shipped ones in one run and 0.85 lost at
## every pale place (the snowfield 16.83 against 11.53, the bonelands 16.19
## against 12.86). With it, every one of the 23 places is nearer the desktop than
## the old rows were: mean distance 15.40 -> 11.05, the four rows as written here
## against the four they replaced, in one run over tours/degrade_fit.tour's places
## on desktop Compatibility.
const SHADOWED_DAY := {"sun": 0.22, "ambient": 0.95, "lamps": 0.7, "emission": 1.0, "glow": 0.6, "fog": 0.1, "exposure": 0.95, "contrast": 0.95, "saturation": 0.9}
const SHADOWED_NIGHT := {"sun": 0.05, "ambient": 0.8, "lamps": 0.7, "emission": 1.0, "glow": 1.0, "fog": 1.0, "exposure": 1.0, "contrast": 0.95, "saturation": 0.9}
## While it does not (an overcast that takes the shadows away, a roof overhead):
## no second pass, only the difference in where the lighting is done. Fitted the
## same way over tours/degrade_grey.tour: three places by day, two by night. The
## open day's fog median was 0.0, and it is 0.1 because a zero turns a thing off
## rather than counting it back (tests/render/test_degrade.gd).
const OPEN_DAY := {"sun": 0.8, "ambient": 1.0, "lamps": 0.7, "emission": 0.75, "glow": 1.0, "fog": 0.1, "exposure": 1.0, "contrast": 1.0, "saturation": 1.1}
const OPEN_NIGHT := {"sun": 0.05, "ambient": 0.8, "lamps": 0.7, "emission": 1.0, "glow": 1.0, "fog": 1.1, "exposure": 1.0, "contrast": 0.95, "saturation": 0.95}

## A fit in progress sets this; nothing else may.
static var override: Dictionary = {}
## The row SkyLight composed last (`remember`), which the lamps follow.
static var _last: Dictionary = IDENTITY


## The row in force for a frame whose sun does or does not cast, `night` 0 (day)
## to 1 (night fallen, or a roof overhead).
## `contrast` is the landscapes' own web contrast (`SkyLight.web_contrast_at`),
## spent by day only.
static func row(sun_casts: bool, night: float = 0.0, contrast: float = 1.0) -> Dictionary:
	return _row(Quality.forward_plus(), sun_casts, night, contrast)


## The row, with the renderer passed in rather than asked, so a test can hold
## the Forward+ half on a runner that has no rendering device.
static func _row(forward: bool, sun_casts: bool, night: float, contrast: float) -> Dictionary:
	if forward:
		return IDENTITY
	if not override.is_empty():
		return override
	var day: Dictionary = SHADOWED_DAY if sun_casts else OPEN_DAY
	var dark: Dictionary = SHADOWED_NIGHT if sun_casts else OPEN_NIGHT
	var t := clampf(night, 0.0, 1.0)
	var out := {}
	for k: String in KEYS:
		out[k] = lerpf(float(day[k]), float(dark[k]), t)
	out.contrast = float(out.contrast) * lerpf(contrast, 1.0, t)
	return out


## SkyLight hands over the row it composed this frame with.
static func remember(r: Dictionary) -> void:
	_last = r


## What a local light's energy is multiplied by (15_lights `_set_light`): the row
## SkyLight composed with, so a lamp and the sun are always counted back together.
## 1 on Forward+.
static func lamp_gain() -> float:
	if Quality.forward_plus():
		return 1.0
	if not override.is_empty():
		return float(override.get("lamps", 1.0))
	return float(_last.get("lamps", 1.0))
