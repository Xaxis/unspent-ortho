extends TestCase
## The city's signs may not be lit in the machines' colours.
##
## `palette.gd` reserves hue 240-336 for the machine ramps, and that reservation
## is load-bearing rather than decorative: it is the whole reason a patched roof
## never reads as a live machine. The Slums is about to be the most crowded frame
## in the game, which is exactly where that cue does the most work -- so a violet
## sign spends the one thing that makes the frame legible.
##
## `Towers.SIGN_COLOURS` shipped with a violet at hue 261 and a cyan beside it,
## and nothing anywhere would have said so: no landscape declared RAISED stock
## yet, so not one pixel of either had ever been drawn. A convention nobody can
## fail is not a rule, and this file is what turns it into one.

const Towers := preload("res://src/models/props/towers.gd")
const Lights := preload("res://src/systems/15_lights.gd")

## The machines' own band (docs/ART.md section 4 and the Palette contract), as
## Color.h turns it: hue in degrees over 360.
const MACHINE_FROM := 240.0 / 360.0
const MACHINE_TO := 336.0 / 360.0


func test_the_ground_note_is_not_a_machines_colour() -> void:
	# THE RULE IS ABOUT THE FIELD, NOT ABOUT HUE, and the measurement is why.
	#
	# The obvious guard -- no sign colour inside the machines' 240-336 -- is wrong,
	# and wrong against SHIPPED CANON. The coast's stolen neon
	# (`Houses.NEON_TUBES[1]`, `15_lights.NEON_MAGENTA`, the ff40cc that
	# `18-stolen-neon-close.png` claims by name) is hue 316.0: inside the band, on
	# the lit house of every lit village, right since M1. A hue ban fails it.
	#
	# Nor does brightness separate them. Measured:
	#   coast neon      hue 316.0  sat 0.75  val 1.00   <- correct, shipped
	#   removed violet  hue 258.5  sat 0.65  val 1.00   <- wrong, removed
	#   machine fill    hue 257.5  sat 0.35  val 0.41   <- what the band protects
	# The first two are the same brightness and nearly the same chroma. No
	# property of the COLOUR tells them apart.
	#
	# What told them apart was AREA. The violet was proposed as the ground note --
	# the four-storey FIELD `Towers.billboard` throws on a wall, which is mass --
	# and a magenta is one shop's accent. So this guards the ground note and
	# leaves accents free: the decision that was actually taken, and the only part
	# of it that is derivable rather than curated.
	#
	# The blanket rule this replaces passed the shipped list by 0.9 of a degree,
	# which is not a rule, it is a coincidence with a green light on it.
	var ground: Color = Towers.SIGN_COLOURS[0]
	var inside := ground.h >= MACHINE_FROM and ground.h <= MACHINE_TO
	check(not inside, "the ground note is at hue %.0f, inside the machines' 240-336" % [ground.h * 360.0])
	# And it is the street's own sodium, not a second orange that looks like it.
	# Written out twice because a model may not import a system.
	var sodium: Vector3 = Lights.NEON_SODIUM
	check(absf(ground.r - sodium.x) < 0.002 and absf(ground.g - sodium.y) < 0.002
			and absf(ground.b - sodium.z) < 0.002,
		"the ground note is the street's own sodium (%.2f, %.2f, %.2f)" % [sodium.x, sodium.y, sodium.z])


func test_a_mural_lights_only_where_something_was_bolted_over_it() -> void:
	# The landscape's argument, as a test: paint emits nothing and a projection
	# lights the street. Neither fact is written down anywhere -- the glow point
	# is READ off the hoarding's own NEON geometry, so a mural that started
	# lighting on every variant would mean a sign had appeared on a wall nobody
	# meant to put one on, and nothing else in the game would complain.
	for v in PropModels.variants(PropKind.MURAL):
		var pts := PropModels.glow_points(PropKind.MURAL, v, Country.COAST)
		if v % 4 < 2:
			check(pts.is_empty(), "mural %d is bare paint and gives no light" % v)
		else:
			check(not pts.is_empty(), "mural %d carries a hoarding and lights the street" % v)
