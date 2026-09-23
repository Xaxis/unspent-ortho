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

## The machines' own band (docs/LOOK.md section 4 and the Palette contract), as
## Color.h turns it: hue in degrees over 360.
const MACHINE_FROM := 240.0 / 360.0
const MACHINE_TO := 336.0 / 360.0


func test_the_grounding_sign_colour_is_never_a_machines_colour() -> void:
	# ONLY INDEX 0, and the reason is a measurement rather than a concession.
	#
	# This test used to hold every entry to the hue band, and that rule is wrong
	# twice over. It already had to skip near-greys, because an earlier version
	# would have failed the correct list's dirty warm white the moment it landed.
	# And it would have failed the ACCENT too: that magenta is hue 316, inside the
	# band -- and it is `Houses.NEON_TUBES[1]`, the coast's own stolen neon,
	# shipped since M1 and claimed by name in a canon frame. A gate that reddens
	# on shipped canon-protected content is one the next person deletes.
	#
	# What the reservation actually protects is measured: every machine body fill
	# spans 240.0-336.0 exactly, with no headroom, and every one is dark and
	# low-chroma -- value at most 0.43, saturation at most 0.37. A machine reads
	# as a cold heavy MASS. Nothing small and burning at value 1.00 competes with
	# that whatever its hue, which is why one shop's sign may sit in the band and
	# a four-storey field of the same colour may not.
	#
	# Index 0 is the entry that covers a building, so it is the one that carries
	# area, so it is the only one a colour test can hold to anything true.
	var col: Color = Towers.SIGN_COLOURS[0]
	var inside := col.h >= MACHINE_FROM and col.h <= MACHINE_TO
	check(not inside,
		"the grounding sign colour is at hue %.0f, inside the machines' 240-336" % [col.h * 360.0])


func test_an_accent_that_sits_in_the_band_still_cannot_read_as_a_machine() -> void:
	# The other half of the rule above, so admitting the accent is not a hole:
	# whatever its hue, a sign colour has to be far outside what a machine's fill
	# can ever be, and those two numbers are the ones `palette.gd` solved for.
	const MACHINE_MOST_VALUE := 0.43
	const MACHINE_MOST_SAT := 0.37
	for i in Towers.SIGN_COLOURS.size():
		var col: Color = Towers.SIGN_COLOURS[i]
		if col.h < MACHINE_FROM or col.h > MACHINE_TO:
			continue
		check(col.v > MACHINE_MOST_VALUE + 0.3,
			"sign colour %d sits in the machines' band at value %.2f, which is not far enough above a machine's 0.43" % [i, col.v])
		check(col.s > MACHINE_MOST_SAT + 0.2,
			"sign colour %d sits in the machines' band at saturation %.2f, too near a machine's 0.37" % [i, col.s])


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
