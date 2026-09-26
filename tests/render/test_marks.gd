extends TestCase
## The rules a mark lives by (docs/LOOK.md, and mob_fx.gd's own header): a
## mark proves something, and it must never be the biggest thing in the frame
## nor the thing standing in front of what it proves. Wave A2's two reviews
## found four marks breaking it at once, so each one is held here.


## The mark shaders are built from these consts at run time: this is the source
## that is compiled, read the same way the shader itself reads it.
func _marks_source() -> String:
	return MobFx._MARKS


# --- A blow whitens the part it struck, not the machine -------------------------

func _one_part(mat: Material) -> MeshInstance3D:
	var k := MeshKit.new()
	k.block(0, 0, 0, 0.4, 0.4, 0.4, Palette.FOUND[2], Palette.FOUND[3])
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = mat
	return mi


func test_the_flash_is_written_into_a_copy_and_never_into_a_shared_material() -> void:
	# People share one material and every animal draws on the world's own: a flash
	# written straight into it would whiten the village, or the ground.
	var shared := MachineModel.found_material(0.0)
	var root := Node3D.new()
	var part := _one_part(shared)
	root.add_child(part)
	MobFx.set_flash(root, true, Vector3(3, 1, 4), 0.3)
	check(part.material_override != shared, "the part draws with a copy while it flashes")
	near(float(part.material_override.get_shader_parameter(&"flash_r")), 0.3, 1e-5, "the copy carries the sphere")
	eq(shared.get_shader_parameter(&"flash_r"), null, "and the shared material is untouched")
	MobFx.set_flash(root, false, Vector3(3, 1, 4), 0.3)
	check(part.material_override == shared, "and it is handed back afterwards")
	root.free()


func test_without_a_radius_the_whole_body_still_flashes() -> void:
	# A dog is a few pixels across and has no parts to tell apart.
	var shared := MachineModel.found_material(0.0)
	var root := Node3D.new()
	var part := _one_part(shared)
	root.add_child(part)
	MobFx.set_flash(root, true)
	check(part.material_override != shared, "something else is drawing it")
	check(part.material_override.shader != shared.shader, "the flat paper-white material")
	MobFx.set_flash(root, false)
	check(part.material_override == shared, "put back")
	root.free()


func test_the_flash_sphere_is_a_part_of_a_body_and_not_the_body() -> void:
	for h: float in [0.8, 1.2, 1.8, 2.6]:
		var r := MobFx.flash_radius(h)
		lt(r * 2.0, h * 0.62, "a %0.1f-tall body flashes well under two thirds of itself" % h)
		gt(r, 0.0, "and something flashes")


func test_both_lit_shaders_carry_the_same_flash_and_lay_it_over_the_light() -> void:
	for path: String in ["res://src/render/found.gdshader", "res://src/render/world.gdshader"]:
		var src := FileAccess.get_file_as_string(path)
		check(src.contains("uniform vec3 flash_at"), "%s takes the blow's place" % path)
		check(src.contains("uniform float flash_r"), "%s takes its size" % path)
		# Written as emission over a black albedo, so the struck part lands on the
		# page's own white whatever the sun and the lamps are doing to it.
		# It goes through matter_light() like every other authored colour, or the
		# one white in the game would be the one thing drawn in the wrong colour
		# space (tests/render/test_colour_space.gd).
		check(src.contains("ALBEDO = vec3(0.0);") and src.contains("EMISSION = matter_light(flash_col);"),
			"%s lays the flash over the light, not under it" % path)


# --- A dash leaves the body showing --------------------------------------------

func test_the_speed_lines_are_ink_over_the_world_and_never_a_field_of_paper() -> void:
	var src := _marks_source()
	var at := src.find("vec4 streak(")
	gt(at, 0, "the streak is in the mark shader")
	var body := src.substr(at, src.find("\n}", at) - at)
	check(not body.contains("inked("),
		"a speed line is not edged all round: three narrow strokes so edged read as white lozenges")
	# It is the DODGE's mark as well as the dash (40_fight), so it has to survive a
	# cave: one flank of page, never both, so it can read on dark ground without
	# the three strokes' edges meeting into a slab again.
	check(body.contains("lit < 0.0") and body.contains("paper_out()"),
		"but it keeps one pixel of page on its lit flank, or it vanishes on dark rock")
	check(body.contains("R * (1.0 - OPEN)"),
		"and its heads start clear of the open heart, where the body is")
	# And that flank is a step DOWN the page's own ramp. Every other mark takes
	# the full linen, which the midday sky grades all the way to 255 -- pure
	# white, which docs/LOOK.md keeps for fire and lamps.
	var src2 := FileAccess.get_file_as_string("res://src/actors/mob_fx.gd")
	var at2 := src2.find("static func streak(")
	gt(at2, 0, "the streak lays its own mark")
	var lay := src2.substr(at2, src2.find("\n\n\n", at2) - at2)
	check(lay.contains("&\"paper_col\", _v3(Palette.LINEN[4])"),
		"a speed line's page is a step under the page every other mark is edged in")
	lt(Palette.LINEN[4].get_luminance(), Palette.LINEN[5].get_luminance(), "and that step is down")


func test_a_speed_line_is_no_wider_than_a_hit_mark() -> void:
	# It came in at 40 px, wider than the body that made it.
	lt(MobFx.STREAK_PX, MobFx.BURST_PX * 1.6, "a dash is a flick of the pen, not a banner")


# --- The working part's light is smaller than the machine wearing it ------------

func test_the_parts_halo_is_stippled_and_stops_short_of_its_own_quad() -> void:
	var src := FileAccess.get_file_as_string("res://src/models/machines/part_glow.gdshader")
	check(not src.contains("bayer"),
		"an ordered dither draws a square lattice, which docs/LOOK.md forbids")
	check(src.contains("ink_hash(px)"), "the halo is stippled on the world's own pixels")
	var reach := src.get_slice("const float REACH = ", 1).get_slice(";", 0).to_float()
	var open := src.get_slice("const float OPEN = ", 1).get_slice(";", 0).to_float()
	lt(reach, 0.75, "the halo stops well inside its quad, so it is smaller than the body")
	gt(open, 0.1, "and its heart stays open: the lens is the brightest pixel, not the light round it")


# --- Breath is neither ink nor paper -------------------------------------------

func test_breath_is_drawn_in_its_own_two_values_and_in_no_ink_at_all() -> void:
	var src := _marks_source()
	var at := src.find("vec4 vapour(")
	gt(at, 0, "breath has a mark of its own")
	var body := src.substr(at, src.find("\n}", at) - at)
	check(not body.contains("ink_col") and not body.contains("paper_col"),
		"drawn in ink on white ground, breath reads as soot (wave A2, art finding 9)")
	check(body.contains("col_a") and body.contains("col_b"),
		"a pale core held by a rim, so it steps away from snow AND from wet rock")


func test_a_breath_carries_a_pale_core_and_a_darker_rim() -> void:
	# MobFx.breath derives both from the cue's own colour: the core is a long step
	# up from it, the rim a shorter one, so the contour lands BETWEEN the core and
	# the snow instead of being a near-black ring round a pale heart.
	var cue := HazardCues.colour(&"cold")
	var core := cue.lightened(0.86)
	var rim := cue.lightened(0.34)
	gt(core.get_luminance() - rim.get_luminance(), 0.25, "the two values are a long way apart")
	gt(rim.get_luminance() - cue.get_luminance(), 0.1, "and the rim is lifted off the cue's own dark step")


func test_breath_takes_the_sun_the_ground_takes_or_it_is_soot_on_snow() -> void:
	# The palette values above prove nothing about the DRAWN mark: a mark is
	# `unshaded`, so through sky_apply alone it takes the sky's ambient and none
	# of the key light the snow beside it takes, and a core of 0.91 luminance
	# landed at 103/255 over snow at 187/255. What has to hold is the shader.
	var src := _marks_source()
	var at := src.find("vec4 vapour(")
	gt(at, 0, "breath has a mark of its own")
	var body := src.substr(at, src.find("\n}", at) - at)
	check(not body.contains("sky_apply("),
		"breath must not go out through the ambient wash alone: that is what made it soot")
	check(body.contains("vapour_lit(col_a)") and body.contains("vapour_lit(col_b)"),
		"both its values are lifted, or the rim is a dark ring round a pale heart")
	var lift_at := src.find("vec3 vapour_lit(")
	gt(lift_at, 0, "and the lift is one function, not two copies")
	var lift := src.substr(lift_at, src.find("\n}", lift_at) - lift_at)
	check(lift.contains("sky_view.y"), "it gives the mark the day's own light back")
	check(lift.contains("min(c,"), "capped at its own paint, so it can never burn past its colour")
	# Full daylight has to saturate that cap: at the hour the review shot, the
	# ambient wash alone was 0.45 of the paint, so the multiply must clear 1/0.45.
	gt(1.0 + MobFx.VAPOUR_SUN, 2.2, "and in daylight the core lands on its own colour, above any snow")
	# And the lift never goes out. Breath's paint is as pale as snow, so with no
	# lift at all the two render as one value and the cloud is gone (measured: a
	# core of 101 on a snowfield rendering 98 at eleven at night).
	gt(MobFx.VAPOUR_DARK, 0.3, "at midnight the core still steps off the page it hangs over")
	lt(MobFx.VAPOUR_DARK, MobFx.VAPOUR_SUN * 0.5, "but a breath in the dark is a cloud, not a lamp")


# --- A line of borrowed light is a line ----------------------------------------

func test_a_magnet_line_is_drawn_whole_and_not_as_spaced_sparkles() -> void:
	var src := FileAccess.get_file_as_string("res://src/systems/54_gear.gd")
	check(src.contains("MobFx.line("), "the grapple draws a line")
	check(src.contains("MobFx.aim_line("), "and re-points it as the body comes in")
	check(not src.contains("LINE_STEP"), "no marks of light spaced along a rope")
	var line: String = MobFx._LINE
	check(line.contains("core") and line.contains("edge"),
		"it carries its own dark edge, so it reads over pale gravel and over night both")
	gt(MobFx.LINE_PX, 2.0, "and it is wide enough to be seen")


func test_a_scan_only_stands_down_for_a_throw_and_never_drops_the_aware_tell() -> void:
	# Standing the whole read down for ANY motion took the brackets AND the tell
	# over a machine that has noticed you away for the six seconds of a glide --
	# exactly the moment a player in the air needs to know who is looking.
	var src := FileAccess.get_file_as_string("res://src/systems/54_gear.gd")
	var throws := src.get_slice("const THROWN: Array[StringName] = [", 1).get_slice("]", 0)
	check(throws.contains("dash") and throws.contains("grapple"), "a throw is a dash or a pull")
	check(not throws.contains("glide"), "a glide is ordinary flight, not a throw")
	# And a throw really is over in the blink the gate assumes.
	lt(AbilityDash.SECONDS, 1.0, "a dash is over in a fifth of a second")
	lt(AbilityGrapple.RANGE / AbilityGrapple.SPEED, 1.0, "and the longest pull in well under one")
	gt(AbilityGlide.SECONDS, 3.0, "while a glide is long enough that going blind through it is a bug")
	var at := src.find("func _scan_marks(")
	gt(at, 0, "the scan lays its own marks")
	var body := src.substr(at, src.find("\n\n\n", at) - at)
	check(not body.contains("if _motion != null:\n\t\treturn"),
		"the whole read must not stand down for any motion at all")
	var gate := body.find("if not thrown:")
	gt(gate, 0, "the brackets stand down for a throw")
	gt(body.find("mob.aware and tell_due"), gate, "and the aware tell is drawn outside that gate")


## A BODY THE LAND HIDES IS STILL DRAWN (render/behind.gdshader): people and
## machines carry the pass that stipples them through a wall, and it tests the
## depth the world left, never opening the land.
func test_bodies_are_drawn_through_the_land_that_hides_them() -> void:
	var behind := load("res://src/render/behind.gdshader") as Shader
	var person := PersonModel.material()
	var found := false
	var m: Material = person
	while m != null:
		if m is ShaderMaterial and (m as ShaderMaterial).shader == behind:
			found = true
		m = m.next_pass
	check(found, "a person's material chain ends in the pass through the land")
	var machine := MachineModel.found_material(0.0)
	check(machine.next_pass is ShaderMaterial and (machine.next_pass as ShaderMaterial).shader == behind, "and a machine's")
	check(behind.code.contains("hint_depth_texture") and behind.code.contains("depth_test_disabled"), "drawn over the land where the depth says it is hidden")

