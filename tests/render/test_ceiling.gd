extends TestCase
## THE CEILING: nothing the game draws may clip.
##
## There used to be a shoulder in sky.gdshaderinc (SKY_TOP_KNEE, SKY_TOP). The
## grade was a per-frame GAIN with no ceiling, so a pale landscape seen from a
## dark one was multiplied onto the page and came back flat white -- and flat
## white holds no second wash, no shade band, no hatch and no ink, so the laws
## failed exactly at an ecotone, which is where they mattered most. The salt
## crust drew 18.7% of one frame at pure white.
##
## Clipping is still a failure. It has stopped being about paper.
##
## What replaced the shoulder is the TONEMAPPER, and it is a better answer for
## three reasons: it is one curve over the whole finished image rather than a
## multiply applied before anything knows how bright the frame turned out; it
## cannot be defeated by a second landscape being in view; and it takes a neon
## tube four times over white and gives back a bright tube instead of a hole. A
## machine's own light is meant to burn, and now it can.
##
## tests/render/test_page_ceiling.gd pinned the old shoulder's arithmetic, and
## that shoulder no longer exists. This pins the curve that took its job, and
## the tier contract that says which expensive things are allowed to be on.


func test_the_frame_is_rolled_off_and_not_clipped() -> void:
	var e := SkyLight.build_environment()
	check(e.tonemap_mode != Environment.TONE_MAPPER_LINEAR,
		"a linear tonemapper IS clipping: everything over 1.0 is lost")
	eq(e.tonemap_mode, SkyLight.TONEMAP, "and it is the one SkyLight names")
	gt(e.tonemap_white, 1.5,
		"with headroom over white, or a lamp is a white rectangle again")
	gt(e.tonemap_exposure, 0.0, "and an exposure that buys the curve's mids back")


func test_the_shoulder_is_gone_from_the_shader_and_nothing_grades_per_fragment() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/sky.gdshaderinc")
	# The names survive in the comment that says what took their job; what must
	# not survive is either of them being DECLARED and spent on a fragment.
	check(not src.contains("const float SKY_TOP_KNEE") and not src.contains("const float SKY_TOP ="),
		"the page shoulder is gone")
	var at := src.find("vec3 neon_graded(vec3 c, float found) {")
	gt(float(at), 0.0, "neon_graded is kept while its callers are converted")
	check(src.substr(at, 90).contains("return c;"), "and it really is the identity now")


## The grade is now one knob on the finished image, driven from the same hour
## and the same landscapes in view that the per-fragment multiply used.
func test_the_grade_is_on_the_image_and_still_answers_to_the_landscape() -> void:
	var e := SkyLight.build_environment()
	check(e.adjustment_enabled, "the image is graded")
	var src := FileAccess.get_file_as_string("res://src/render/sky_light.gd")
	check(src.contains("neon_grade_at(hour, neon_shares)") and src.contains("adjustment_saturation"),
		"from the hour and the landscapes in view")


## The contract with `degrade`: every expensive thing is gated on the TIER's own
## row and nothing is hardcoded on. A tier that says no volumetrics and gets
## them anyway is a broken web promise, and it breaks silently on this machine.
func test_every_expensive_thing_reads_the_tier_row_rather_than_deciding() -> void:
	var q := Quality.current()
	var e := SkyLight.build_environment()
	eq(e.volumetric_fog_enabled, bool(q.volumetric), "volumetric air follows the row")
	eq(e.ssao_enabled, bool(q.ssao), "SSAO follows the row")
	eq(e.ssil_enabled, bool(q.ssil), "SSIL follows the row")
	# The screen-space shafts are the OTHER half of the same row: they are the
	# web's stand-in for volumetric air (docs/LOOK.md's degradation table), so
	# they run only where there is none of it.
	var rig := FileAccess.get_file_as_string("res://src/render/camera_rig.gd")
	check(rig.contains('Quality.current().get("volumetric", false)'),
		"the shaft pass asks the row whether it is wanted")
	var lights := FileAccess.get_file_as_string("res://src/systems/15_lights.gd")
	check(lights.contains('Quality.current().get("shadow_lights", 0)'),
		"and the lights system is the only enforcer of how many may cast")


## A tier that asks for more must really get more, or the rows are decoration.
func test_the_rows_are_ordered_and_the_web_asks_for_least() -> void:
	var ultra := Quality.row(&"ultra")
	var web := Quality.row(&"web")
	gt(float(ultra.shadow_lights), float(web.shadow_lights), "ultra casts more local shadows")
	check(bool(ultra.volumetric) and not bool(web.volumetric), "and has air the web has not")
