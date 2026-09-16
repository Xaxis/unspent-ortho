extends TestCase
## The rules a mark lives by (docs/ART.md §7, and mob_fx.gd's own header): a
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
		check(src.contains("ALBEDO = vec3(0.0);") and src.contains("EMISSION = flash_col;"),
			"%s lays the flash over the light, not under it" % path)


# --- A dash leaves the body showing --------------------------------------------

func test_the_speed_lines_are_ink_over_the_world_and_never_a_field_of_paper() -> void:
	var src := _marks_source()
	var at := src.find("vec4 streak(")
	gt(at, 0, "the streak is in the mark shader")
	var body := src.substr(at, src.find("\n}", at) - at)
	check(body.contains("inked(e, 0.0)"),
		"a speed line takes no paper: edged in page, three narrow strokes read as white lozenges")
	check(body.contains("R * (1.0 - OPEN)"),
		"and its heads start clear of the open heart, where the body is")


func test_a_speed_line_is_no_wider_than_a_hit_mark() -> void:
	# It came in at 40 px, wider than the body that made it.
	lt(MobFx.STREAK_PX, MobFx.BURST_PX * 1.6, "a dash is a flick of the pen, not a banner")


# --- The working part's light is smaller than the machine wearing it ------------

func test_the_parts_halo_is_stippled_and_stops_short_of_its_own_quad() -> void:
	var src := FileAccess.get_file_as_string("res://src/models/machines/part_glow.gdshader")
	check(not src.contains("bayer"),
		"an ordered dither draws a square lattice, which docs/ART.md §1 forbids")
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
	# up from it, and the rim is the cue's colour itself.
	var cue := HazardCues.colour(&"cold")
	var core := cue.lightened(0.86)
	gt(core.get_luminance() - cue.get_luminance(), 0.35, "the two values are a long way apart")
	gt(core.get_luminance(), 0.80, "the core is paler than any ground it will sit on")


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
