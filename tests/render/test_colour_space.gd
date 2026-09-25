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

## **THIS TEST NAMED SIX SHADERS AND ALL SIX ALREADY OBEYED.** It could not fail,
## and it did not, while eight other draw paths wrote raw palette sRGB into
## ALBEDO for the whole life of the lit renderer — the player's lantern and every
## lit window pane, the scan beams, the working-part halos, the survival marks
## and the light shafts. A test over a hand-written list checks the files somebody
## was already thinking about. `test_every_shader_in_the_repo...` below sweeps the
## tree instead, so the next one is caught by existing.
##
## Its own wording was the excuse: "every shader that LIGHTS something" reads as
## though an overlay is exempt. Nothing is exempt. `render_probe.gd:203` measured
## the stop and a half on `render_mode unshaded; ALBEDO = c;`, which IS the
## overlay case — so `unshaded` is not an exemption from the door, it is the
## case the door was measured on.
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


## **THERE ARE TWO DOORS AND THAT IS FINE; WHAT IS NOT FINE IS THAT NOBODY WROTE
## THE SECOND ONE DOWN.** `matter_albedo()` converts in the fragment, from the
## `sky_linear` global. A `uniform vec3 x : source_color` converts when the
## uniform is SET, which Godot does per renderer — the same decision, made once
## instead of per pixel, and therefore the better door for a colour that is
## constant over a draw. Six shaders used the first, two used the second, and
## eight used neither, because nothing said which was which.
##
## An entry in EXCUSED claims a particular write is not a raw palette colour on
## its way to the display. A claim is checked, not taken: `source_color` entries
## must actually declare one.
const EXCUSED := {
	# A screen-space composite: what it writes back is the frame it read, already
	# in whatever space this renderer keeps. The palette colour it mixes IN goes
	# through the door at the mix, which is where the two spaces meet.
	"res://src/render/shafts.gdshader": "screen",
	# The whole of ALBEDO is one `: source_color` uniform.
	"res://src/render/weather/rays.gdshader": "source_color",
	# A sum of light at several hues and energies: every term goes through the
	# door on its own (`lit()`), and what is written is their sum.
	"res://src/render/falls/streak.gdshader": "sum",
}


func test_a_shader_excused_for_source_color_really_declares_one() -> void:
	for path: String in EXCUSED:
		if EXCUSED[path] != "source_color":
			continue
		var src := FileAccess.get_file_as_string(path)
		check(src.contains(": source_color"),
			"%s is excused as a source_color uniform and must declare one" % path)


func _shaders(at: String, out: Array[String]) -> Array[String]:
	var d := DirAccess.open(at)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var path := at.path_join(name)
		if d.current_is_dir():
			_shaders(path, out)
		elif name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):
			out.append(path)
		name = d.get_next()
	d.list_dir_end()
	return out


func test_every_shader_in_the_repo_writes_albedo_through_the_one_door() -> void:
	var all: Array[String] = []
	_shaders("res://src", all)
	gt(float(all.size()), 20.0, "the sweep found the shaders at all")
	for path in all:
		var src := FileAccess.get_file_as_string(path)
		var at := src.find("ALBEDO = ")
		while at >= 0:
			var line := src.substr(at, 160).get_slice("\n", 0)
			var bare := line.strip_edges()
			# Black is black in both spaces: the hit flash blanking a body before
			# it writes EMISSION.
			var ok := bare.contains("vec3(0.0)") \
				or bare.contains("matter_albedo(") or bare.contains("matter_light(") \
				or EXCUSED.has(path)
			check(ok, "%s: %s\n      (wrap it in matter_albedo() for a surface or matter_light() for a light, or excuse it in EXCUSED with a reason)" % [path, bare])
			at = src.find("ALBEDO = ", at + 1)


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
