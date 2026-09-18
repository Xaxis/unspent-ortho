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


func test_no_sign_is_lit_in_the_machines_colours() -> void:
	for i in Towers.SIGN_COLOURS.size():
		var col: Color = Towers.SIGN_COLOURS[i]
		# A near-grey has no meaningful hue to judge, and nothing here is grey.
		gt(col.s, 0.25, "sign colour %d is a colour at all" % i)
		var inside := col.h >= MACHINE_FROM and col.h <= MACHINE_TO
		check(not inside, "sign colour %d is at hue %.0f, inside the machines' 240-336" % [i, col.h * 360.0])


func test_the_sodium_is_the_same_sodium_the_lights_throw() -> void:
	# Written out twice on purpose: a model may not depend on a system, so
	# towers.gd cannot import 15_lights. It is the same deliberate duplication
	# `GenScatter.HOUSE_MODELS` keeps against `Houses.VARIANTS`, and like that one
	# it is only safe while something fails the moment the two drift.
	var sodium: Vector3 = Lights.NEON_SODIUM
	var found := false
	for col: Color in Towers.SIGN_COLOURS:
		if absf(col.r - sodium.x) < 0.002 and absf(col.g - sodium.y) < 0.002 and absf(col.b - sodium.z) < 0.002:
			found = true
	check(found, "the street's sodium (%.2f, %.2f, %.2f) is one of the sign colours" % [sodium.x, sodium.y, sodium.z])


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
