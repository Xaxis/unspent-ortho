extends TestCase
## What a colour MEANS between the palette and the frame, and it is not the same
## thing on the two renderers this game ships on.
##
## Measured, a flat unshaded quad, ALBEDO = (0.500, 0.250, 0.125):
##   Forward+        the PNG holds (0.737, 0.537, 0.388) = linear_to_srgb(in)
##   Compatibility   the PNG holds (0.502, 0.247, 0.114) = in
##
## So Forward+ reads ALBEDO as LINEAR light and encodes the frame for the
## display; Compatibility hands it straight over. The palette is sRGB display
## values. Writing them raw on Forward+ lifts the entire game about a stop and a
## half and flattens every ramp into its top -- which it had been doing since
## the floor moved to Forward+, and which nobody chose.
##
## CLAUDE.md used to say "colours are sRGB palette values straight into ALBEDO;
## the Compatibility renderer does no conversion and converting made everything
## black". Both halves were true of Compatibility and neither is true of
## Forward+. The rule now is: every colour goes through matter_albedo(), which
## decides per renderer from `sky_linear`.
##
## This test exists because the failure is SILENT and looks like a grading
## choice. There is nothing pink, no error, and no shader warning -- just a game
## that is washed out on one of the two platforms it promises to be the same on.

## Every shader that lights something and therefore writes a palette colour out.
const LIT: Array[String] = [
	"res://src/render/world.gdshader",
	"res://src/render/found.gdshader",
	"res://src/render/water.gdshader",
	"res://src/models/people/person.gdshader",
	"res://src/models/people/person_rim.gdshader",
	"res://src/render/foliage/leaf.gdshader",
]


func test_every_lit_shader_writes_albedo_through_the_one_door() -> void:
	for path in LIT:
		var src := FileAccess.get_file_as_string(path)
		check(src.contains("matter.gdshaderinc"), "%s includes the matter rules" % path)
		var at := src.find("ALBEDO = ")
		var found := false
		while at >= 0:
			var line := src.substr(at, 80).get_slice("\n", 0)
			# `ALBEDO = vec3(0.0)` is the hit flash blanking the body before it
			# writes EMISSION, and is not a colour going to the display.
			if not line.contains("vec3(0.0)"):
				found = true
				check(line.contains("matter_albedo("),
					"%s writes a colour out through matter_albedo: %s" % [path, line.strip_edges()])
			at = src.find("ALBEDO = ", at + 1)
		check(found, "%s writes ALBEDO at all" % path)


func test_the_door_is_the_identity_on_compatibility_and_decodes_on_forward_plus() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/matter.gdshaderinc")
	check(src.contains("return mix(srgb, matter_linear(srgb), sky_linear);"),
		"matter_albedo picks between the two by sky_linear")
	# The piecewise curve, not pow(c, 2.2): the approximation is two values out
	# at the bottom of every ramp, which is exactly where this game lives.
	check(src.contains("0.04045") and src.contains("12.92") and src.contains("1.055"),
		"and it is the real sRGB curve")


func test_the_renderer_is_asked_which_one_it_is_and_the_answer_is_registered() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/sky_light.gd")
	check(src.contains('global_shader_parameter_set("sky_linear"'), "SkyLight sets it")
	check(src.contains("Quality.forward_plus()"),
		"from whether this run really has a RenderingDevice, not from a project setting")
	var proj := FileAccess.get_file_as_string("res://project.godot")
	check(proj.contains("sky_linear={"), "and project.godot registers it")
	# An unregistered global reads zero in every shader, silently, which here
	# would mean the desktop quietly drew in the web's colour space.
	check(proj.contains("sky_wear={"), "and the wear map with it")


## The palette is authored in sRGB and every reader has to agree about that,
## including the ones outside the shaders.
func test_the_palette_is_still_read_as_srgb_by_the_lights() -> void:
	var src := FileAccess.get_file_as_string("res://src/systems/15_lights.gd")
	check(src.contains("linear_to_srgb()"),
		"a light's colour is pre-encoded, because Godot decodes light_color")
