extends RefCounted
## THE PLATFORM IN ORBIT, AS DATA (the orbit design, 2026-09-24).
##
## The owner asked for "an orbiting platform/massive mega structure, which is
## partially fractured and some of its debris is falling from orbit to the
## planet's surface". What it IS -- whose, what it was for, its name -- is still
## his to rule on, so nothing here names one: `ring()` is a spoked wheel with a
## wound in it, and the engine draws whatever it is handed. Another body is
## another `static func` beside it.
##
## EVERYTHING HERE IS IN KILOMETRES AND WORLD MINUTES, unlike the colossi, which
## are in metres: nothing about this body is ever measured against a tile, and a
## thing 120 km across drawn from 420 km away is best stated in the units its
## own layer is drawn in (src/render/orbit/orbit_layer.gd).
##
## No class_name: reached by path, so a pull cannot leave the global class cache
## without it (CLAUDE.md, the class_name trap).

var id: StringName = &"ring"

## THE PLANET. The colossi's hull-down is stated on the same radius
## (far.gdshaderinc `R_EFF`, 4.5e6 m): small, so a thing on it goes over the
## horizon at a distance a player can feel, and so the Earth's shadow reaches a
## thing 420 km up an hour or two after the land has lost the sun rather than
## minutes. DUPLICATE of that constant, to be promoted to one shared number.
var planet_km := 4500.0
## 300 km up and 90 km in radius, not the design's 420 and 60 (owner,
## 2026-09-24): a low pass was 98 px across at 12 degrees up and read as a
## ring drawn on the sky. This one is 189 px there and 600 overhead, and the
## Earth's shadow still takes it only after dusk (at the zenith from 22:57 to
## 02:33 on the game's night).
var altitude_km := 300.0

## THE WHEEL (180 km across). Rim radius to the middle of the trough; the trough itself (the
## habitat ring, open to the axis side); six spokes to a hub spindle carrying
## two radiator sails.
var rim_km := 90.0
## Seven kilometres wide and three deep, not the design's first 3.2 by 1.1: at
## 420 km that section was seven pixels, and at 7 to 16 degrees across the wheel
## read as wire (the owner wants it massive). A drum this size is still a
## thirtieth of the wheel across -- a ring, not a doughnut.
var trough_wide := 7.0
var trough_deep := 3.0
## THE DECK: a collar of plate laid in the wheel's own plane inside the trough,
## `deck_km` wide, hung on radial girders -- where the torn ends' "peeled deck
## plate" comes from, and what gives the wheel a face: at 420 km a 3.2 km
## trough is seven pixels, and a wheel of nothing but trough read as a drawn
## circle (measured, the first frames). Panels are missing by hash, more of
## them toward the wound, so the girders show through.
var deck_km := 16.0
var spokes := 6
var spoke_thick := 2.2
var hub_long := 16.0
var hub_r := 3.4
var sail := Vector2(26.0, 8.0)

## THE WOUND. A sector of the rim gone, centred at `gap_at` degrees round the
## wheel's own frame (where a spoke met the rim, so that spoke is the one
## snapped), and the pieces still drifting near it.
var gap_deg := 70.0
var gap_at := 90.0
var chunks := 14

## HOW IT GOES OVER. Not an honest orbit -- a real one at 420 km crosses the
## sky in minutes -- but ORBIT BY PASSES: every `period_h` world hours one pass
## rises, crosses the sky at an even pace for `window_h` world hours and sets,
## and while it is down it is hurrying round the far side. A period that is not
## a whole number of days moves each pass `period_h mod 24` hours later
## (33.2: 9.2 hours, the golden step, so over a week passes fall at noon, dusk,
## midnight and dawn and no hour is favoured). Each pass climbs to its own peak
## elevation, a smooth seeded walk between `peak_least` and `peak_most`.
var period_h := 33.2
var window_h := 11.0
var peak_least := 20.0
var peak_most := 88.0
## World minutes for one turn of the wheel (about 25 real minutes at 1.4 world
## minutes a real second), and for one slow tumble of its axis, which is what
## turns it from an edge-on line to an open wheel from one pass to the next.
var spin_min := 2100.0
var tumble_min := 9000.0


static func ring() -> RefCounted:
	return load("res://src/core/orbit/orbit_def.gd").new()


## The orbit's radius from the planet's centre.
func orbit_km() -> float:
	return planet_km + altitude_km
