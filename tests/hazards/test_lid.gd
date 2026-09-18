extends TestCase
## A landscape's LID presses a body, and it is not the same thing as night.
##
## `SkyLight.closed` has read a roofed realm as night at every hour since realms
## landed — blue floor, no cast shadows, a lamp pool — while `Hazards` read the
## raw clock and pressed the body as if it stood in the midday sun. So the cave
## the renderer drew black reported the LEAST dark it is able to report, and the
## gauge was at its lowest in the darkest place in the game.
##
## `Hazards.Place.roofed` closes that, and the interesting half is what it must
## NOT do. A lid is not a second name for night:
##
##   the SUN's    cold, dark, heat, glare, thirst   -> gone under a lid
##   the CLOCK's  magnetism                         -> unchanged under a lid
##
## because the field in the dead iron runs off the machines' grid, and the grid
## works its own day under the rock as well as over it. A roofed realm at noon
## is a place where the hum is loudest and the light is wholly gone, and reading
## one number for both would have said the opposite while looking tidier.
##
## The other thing it must not do is INVENT a pressure. `BiomeDef.hazards` stays
## the authority: the lid scales what a landscape declares, under the same
## `NIGHT_MOST` cap the clock is held to, so a cave that says it is not dark
## shows no gauge.

const H := preload("res://src/core/hazards/hazards.gd")


static func _at(hazards: Dictionary, hour: float, roofed: bool) -> Dictionary:
	var p := H.Place.new()
	p.hazards = hazards
	p.hour = hour
	p.roofed = roofed
	return H.felt(p)


func test_a_lid_presses_the_dark_at_noon_the_way_midnight_does() -> void:
	var declares := {&"dark": 0.5}
	var open_noon: float = _at(declares, 12.0, false).get(&"dark", 0.0)
	var under_noon: float = _at(declares, 12.0, true).get(&"dark", 0.0)
	var open_night: float = _at(declares, 2.0, false).get(&"dark", 0.0)
	gt(under_noon, open_noon,
		"a roofed realm at noon is darker than an open one at noon (%.3f vs %.3f)" % [under_noon, open_noon])
	near(under_noon, open_night, 1e-4,
		"and it is exactly as dark as the open world at 2am, because both spend the same `sun_gone`")


func test_a_lid_takes_the_cold_the_same_way_and_the_heat_and_glare_off() -> void:
	var cold := {&"cold": 0.5}
	gt(float(_at(cold, 12.0, true).get(&"cold", 0.0)), float(_at(cold, 12.0, false).get(&"cold", 0.0)),
		"there is no sun over a roofed realm to take the cold off it")
	var hot := {&"heat": 0.8, &"glare": 0.8}
	var under: Dictionary = _at(hot, 12.0, true)
	var open: Dictionary = _at(hot, 12.0, false)
	lt(float(under.get(&"heat", 0.0)), float(open.get(&"heat", 0.0)), "a lid takes the sun's heat")
	lt(float(under.get(&"glare", 0.0)), float(open.get(&"glare", 0.0)), "and its glare, more completely")


## The one that would break if somebody made `roofed` a synonym for night.
func test_a_lid_does_not_touch_the_machines_own_day() -> void:
	var iron := {&"magnetism": 0.6}
	near(float(_at(iron, 12.0, true).get(&"magnetism", 0.0)),
		float(_at(iron, 12.0, false).get(&"magnetism", 0.0)), 1e-4,
		"the grid runs under the rock too, so a lid must not quiet the hum")
	gt(float(_at(iron, 12.0, true).get(&"magnetism", 0.0)),
		float(_at(iron, 2.0, true).get(&"magnetism", 0.0)),
		"and underground the hum still sags in the small hours, because that is the CLOCK")


func test_a_lid_cannot_press_a_body_with_something_the_landscape_never_declared() -> void:
	# The whole of `BiomeDef.hazards` is the authority, roof or no roof.
	var quiet: Dictionary = _at({}, 12.0, true)
	eq(quiet, {}, "a roofed realm that declares nothing presses with nothing: %s" % [quiet])
	var only_dark: Dictionary = _at({&"dark": 0.4}, 12.0, true)
	eq(only_dark.keys(), [&"dark"] as Array, "and it adds no pressure of its own beside what is declared")


func test_the_lid_is_still_capped_where_the_clock_is() -> void:
	# NIGHT_MOST holds the added term, so a lid cannot take a mild place past a
	# bite on its own any more than midnight can.
	var mild := {&"dark": 0.1}
	var under: float = _at(mild, 12.0, true).get(&"dark", 0.0)
	lt(under, H.BITE,
		"a place that calls itself barely dark is not made dangerous by a roof alone (%.3f)" % under)
