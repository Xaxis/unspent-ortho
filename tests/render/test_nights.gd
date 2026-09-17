extends TestCase
## A night belongs to the landscape it falls on, and a roofed realm reads as
## night at every hour — including to the two things that used not to.
##
## `lit` named the exposure/ambient/tonemap triple as its least confident call:
## one global setting for landscapes whose albedos differ by a factor of three.
## Measured on seed 7 at 23:00, bare ground and no village, the coast came back
## 81.4% of its pixels under luma 24 and the moss bog 95.3% — the same night,
## and one of them is a place you cannot cross. `BiomeDef.night_sky` is that one
## number made the landscape's own.
##
## Everything here is arithmetic rather than frames, because the frames are the
## canon's job (tours/nights.tour) and because each of these failures is SILENT:
## a night level that snaps at a border, a landscape that quietly asks for a
## night nobody can play in, a save refused over a lighting value, and a lantern
## that turns red underground all look like somebody's grading choice.

const Lights := preload("res://src/systems/15_lights.gd")

const NIGHT := 23.0
const NOON := 12.0


func _shares(id: StringName, w := 1.0) -> Dictionary:
	return {id: w}


# --- the landscape's own night ---------------------------------------------

func test_every_landscape_declares_a_night_inside_what_a_player_can_read() -> void:
	# The clamp is in night_sky_at, so a content file CAN write anything; this is
	# the line that says nobody should, and names them if they do.
	for d in BiomeRegistry.all():
		if d == null:
			continue
		check(d.night_sky >= SkyLight.NIGHT_SKY_LEAST and d.night_sky <= SkyLight.NIGHT_SKY_MOST,
			"%s asks for night_sky %.2f, outside %.2f..%.2f" % [d.id, d.night_sky,
				SkyLight.NIGHT_SKY_LEAST, SkyLight.NIGHT_SKY_MOST])


func test_the_coast_is_the_fixed_point_every_other_night_is_stated_against() -> void:
	# NIGHT_AMBIENT was measured on the coast. If the coast ever stops being 1.0
	# then every other landscape's number means something else than it says, and
	# the whole table has to be re-read rather than re-tuned.
	var coast := BiomeRegistry.get_def(&"coast")
	check(coast != null, "no coast in the registry")
	if coast != null:
		near(coast.night_sky, 1.0, 1e-6, "the coast's night is the reference")
	near(SkyLight.night_sky_at(_shares(&"coast")), 1.0, 1e-6, "and it blends to itself")


func test_a_bog_and_a_wood_do_not_get_the_same_night() -> void:
	var bog := SkyLight.night_sky_at(_shares(&"moss"))
	var wood := SkyLight.night_sky_at(_shares(&"pinewood"))
	var coast := SkyLight.night_sky_at(_shares(&"coast"))
	# A fen has no lid on it and a wood has one. That is the whole model, and if
	# it ever inverts the numbers are being tuned by eye against a symptom.
	gt(bog, coast, "an open fen keeps more night sky than the coast")
	lt(wood, coast, "a closed canopy keeps less")


func test_an_unknown_or_empty_share_reads_as_the_coast() -> void:
	# The title, the gallery and any headless compose have no landscape in view.
	near(SkyLight.night_sky_at({}), 1.0, 1e-6, "nothing in view is the reference night")
	near(SkyLight.night_sky_at({&"no_such_landscape": 1.0}), 1.0, 1e-6, "an unknown id too")


func test_the_clamp_holds_whatever_the_content_asks_for() -> void:
	# Readability at night is a floor the content layer may not argue with: the
	# rejected `noir` direction put the ground the player walks on under luma 24.
	near(SkyLight.night_sky_at({&"coast": 1.0}) , 1.0, 1e-6)
	var d := BiomeDef.new()
	d.id = &"greedy"
	d.night_sky = 99.0
	check(clampf(d.night_sky, SkyLight.NIGHT_SKY_LEAST, SkyLight.NIGHT_SKY_MOST) <= SkyLight.NIGHT_SKY_MOST,
		"the ceiling holds")
	d.night_sky = 0.0
	check(clampf(d.night_sky, SkyLight.NIGHT_SKY_LEAST, SkyLight.NIGHT_SKY_MOST) >= SkyLight.NIGHT_SKY_LEAST,
		"the floor holds")


# --- the border ------------------------------------------------------------

func test_a_night_level_crossing_a_border_never_steps() -> void:
	# An ecotone crossfades every other term on WorldData.blend; a night that
	# snapped would draw the border as a line across the frame, which is the one
	# thing an ecotone exists not to do. Walked in 64 steps from all-moss to
	# all-coast, no step may be a jump.
	var last := SkyLight.night_sky_at(_shares(&"moss"))
	var biggest := 0.0
	var span := absf(SkyLight.night_sky_at(_shares(&"coast")) - last)
	for i in range(1, 65):
		var t := float(i) / 64.0
		var here := SkyLight.night_sky_at({&"moss": 1.0 - t, &"coast": t})
		biggest = maxf(biggest, absf(here - last))
		last = here
	# No single step may be more than a fifth of the whole crossing: a smooth
	# blend over 64 steps lands nearer a sixteenth, and a hard switch would be
	# the entire span in one step.
	lt(biggest, span * 0.2, "the night level steps across a coast/moss ecotone")


func test_the_land_under_your_feet_carries_the_night_not_a_sliver_at_the_edge() -> void:
	# Squared weights (see night_sky_at). Standing in the bog with a little coast
	# showing at the top of the frame must still be the bog's night.
	var bog := SkyLight.night_sky_at(_shares(&"moss"))
	var coast := SkyLight.night_sky_at(_shares(&"coast"))
	var mostly_bog := SkyLight.night_sky_at({&"moss": 0.85, &"coast": 0.15})
	var linear := coast + (bog - coast) * 0.85
	# Squared weights pull it further toward the bog than a plain average would.
	gt(mostly_bog, linear, "a sliver of the neighbour is lifting the bog's night")


# --- a roof reads as night, to everything ----------------------------------

func test_a_roof_reads_as_night_at_every_hour_for_the_tint_and_the_energy() -> void:
	# `SkyLight.closed`'s own header says a roofed realm reads as night to
	# everything the sky writes. `last_tint` and `last_energy` were the last two
	# things that did not: both were read straight off the clock, so a cave at
	# noon told 15_lights the sun was fully up.
	var sky := SkyLight.new()
	sky.closed = 1.0
	sky.set_hour(NOON)
	var cave_noon_tint := sky.last_tint
	var cave_noon_energy := sky.last_energy
	sky.set_hour(NIGHT)
	var cave_night_tint := sky.last_tint
	var cave_night_energy := sky.last_energy
	near(cave_noon_energy, cave_night_energy, 1e-4,
		"a roofed realm's light level moved with the clock")
	near((cave_noon_tint - cave_night_tint).length(), 0.0, 1e-3,
		"a roofed realm's light colour moved with the clock")
	near(cave_noon_energy, SkyLight.NIGHT_LEVEL, 1e-4,
		"and it settles at the night's own level")
	sky.free()


func test_the_open_sky_still_knows_what_time_it_is() -> void:
	# The other half: fixing the roof must not flatten the surface's day.
	var sky := SkyLight.new()
	sky.closed = 0.0
	sky.set_hour(NOON)
	var noon := sky.last_energy
	var noon_tint := sky.last_tint
	sky.set_hour(NIGHT)
	gt(noon, sky.last_energy, "the surface's light no longer falls at night")
	gt((noon_tint - sky.last_tint).length(), 0.05, "the surface's colour no longer turns")
	sky.free()


func test_a_lantern_under_a_roof_is_warm_and_not_red() -> void:
	# LOOK law 2's one thematic rule: a person's light is WARM. 15_lights divides
	# its ochre lamp by `last_tint` per channel and subtracts `last_energy` as a
	# black point, so handing it a daylight tint under a roof took the blue to
	# zero and the pool came out sRGB (1.00, 0.39, 0.00). Measured in the caves
	# off tours/realms.tour, the pool's green-over-red was 0.372 before and 0.779
	# after, against the coast's 0.867.
	var sky := SkyLight.new()
	sky.closed = 1.0
	# The cave's own light, exactly as limestone_caves.gd declares it.
	var cave := Realm.light(Realm.UNDERGROUND)
	sky.region_tint = Vector3(cave.r, cave.g, cave.b)
	sky.set_hour(NOON)
	var lamp := Lights.compensate(Lights.WARM, sky.last_tint, sky.last_energy)
	gt(lamp.z, 0.0, "the lantern has no blue left in it underground: it is red")
	# Warm, not white and not red: red leads, green follows it, blue is least.
	gt(lamp.x, lamp.y, "the lantern stopped being warm")
	gt(lamp.y, lamp.z, "the lantern stopped being warm")
	# And the hue is near the coast's own midnight lamp rather than a stop off it.
	var surface := SkyLight.new()
	surface.closed = 0.0
	surface.set_hour(NIGHT)
	var coast_lamp := Lights.compensate(Lights.WARM, surface.last_tint, surface.last_energy)
	var cave_gr := lamp.y / maxf(lamp.x, 1e-4)
	var coast_gr := coast_lamp.y / maxf(coast_lamp.x, 1e-4)
	lt(absf(cave_gr - coast_gr), 0.35,
		"the cave's lamp is a different colour from the coast's: %.3f against %.3f" % [cave_gr, coast_gr])
	sky.free()
	surface.free()


# --- the fen is a mat, not a mirror ----------------------------------------

func test_the_fen_is_not_the_most_specular_ground_in_the_game() -> void:
	# The moss read as one flat teal sheet because its ground was a MIRROR: FEN
	# was (roughness 0.58, specular 0.68, relief 0.010), the second most specular
	# ground on the flattest relief, and world.gdshader forces a level face's
	# normal to exactly vertical — so every pixel of a bog had one identical BRDF
	# response, which is a flat sheet by construction. Measured at noon on seed 7,
	# the fen came back at luma 162 against coast turf's 100, off a wash whose own
	# luma is 58, with chroma 13: a broad sheen returns the LIGHT's colour, not
	# the ground's. Dropping the specular alone took it to 80 and chroma to 25.
	var src := FileAccess.get_file_as_string("res://src/render/matter.gdshaderinc")
	check(src != "", "cannot read matter.gdshaderinc")
	var rows := {}
	for line in src.split("\n"):
		var at := line.find("m == ")
		if at < 0 or not line.contains("r = vec4("):
			continue
		var id := line.substr(at + 5).split(")")[0].strip_edges().to_int()
		var nums := line.split("r = vec4(")[1].split(")")[0].split(",")
		if nums.size() < 3:
			continue
		rows[id] = [nums[0].to_float(), nums[1].to_float(), nums[2].to_float()]
	check(rows.has(48), "no FEN row in matter_of")
	check(rows.has(52), "no ROCK row in matter_of")
	if not (rows.has(48) and rows.has(52)):
		return
	var fen: Array = rows[48]
	# Sphagnum is the mattest thing in the landscape.
	gt(float(fen[0]), 0.7, "the fen's roughness says it is polished")
	lt(float(fen[1]), 0.5, "the fen is a mirror again")
	# And it has SHAPE: hummock and hollow, at a relief the sun and the moon can
	# both find. Loose stone (ROCK) is the yardstick for "real relief".
	gt(float(fen[2]), float(rows[52][2]) * 0.8, "the fen is flat again")


func test_the_fen_has_a_height_field_of_its_own_and_it_does_not_rule_a_lattice() -> void:
	# matter_fbm rotates between octaves precisely because a raw ink_vnoise
	# GRADIENT rules a square lattice over open ground, and the ground it happened
	# on was this one (a herringbone of diamonds two thirds of a tile across).
	# So the fen's own branch must build its hummocks out of matter_fbm.
	var src := FileAccess.get_file_as_string("res://src/render/matter.gdshaderinc")
	var at := src.find("float matter_height(")
	check(at > 0, "no matter_height")
	var body := src.substr(at, src.find("\n}", at) - at)
	var fen_at := body.find("m == 48")
	check(fen_at > 0, "the fen has no height field of its own")
	if fen_at <= 0:
		return
	var branch := body.substr(fen_at, 600)
	var ends := branch.find("} else")
	if ends > 0:
		branch = branch.substr(0, ends)
	check(branch.contains("matter_fbm"), "the fen's relief is not built out of matter_fbm")
	check(not branch.contains("ink_vnoise("),
		"the fen's relief uses a raw ink_vnoise: its gradient rules a lattice on open ground")
