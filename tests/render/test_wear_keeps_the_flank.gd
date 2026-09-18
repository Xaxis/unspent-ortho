extends TestCase
## What keeps a machine readable once the land has worn it (docs/ART.md §4).
##
## THE LAW HAD NO TEST THAT COULD SEE IT BREAK. "A machine is a DARK mass by
## day" is held by `tests/models/test_machines_ramps.gd`, which compares the
## PALETTE's body fill against the coast turf — and `matter_worn` then lays
## wear over that fill, which the palette knows nothing about. So the one test
## of the law is structurally blind to the one thing that can undo it, and it
## passed happily throughout.
##
## It was undone, and nobody saw, because no model review in this project's
## history had wear in it at all: `matter_wear()` exits while `sky_view.z <= 0`
## and the gallery never set it (`--wear=`, #81). Measured once it rendered:
##
##   coast turf MOSS[3]   luma 0.350   the bar the ramps test holds fills under
##   MATTER_RUST               0.261   darker than turf
##   MATTER_SOOT               0.073   darker than turf
##   MATTER_SALT               0.865   LIGHTER, capped at 0.80 of the surface
##   MATTER_FROST              0.921   LIGHTER, capped at 0.78 of the surface
##
## (#80 recorded rust as 0.244; that was Rec.709 weights. Every number here is
## Rec.601, 0.299/0.587/0.114, because that is what `test_machines_ramps.gd`
## compares fills to the turf with, and a bar and the thing measured against it
## have to be weighed on one scale.)
##
## and the salt flats and the snowfield declare those two channels at FULL, so
## an up-facing face of a machine standing there reaches 0.75 to 0.79 — twice
## the turf. The letter of §4 is false in two landscapes.
##
## ITS PURPOSE SURVIVES, and this file pins the reason rather than the letter.
## Both LIGHT channels are gated on what faces the SKY and the two DARK ones are
## not, so the flanks, wheels and underside of a machine keep their mass while
## its roof goes white. At the play camera's 57 degrees the flank is most of what
## is seen, which is why `shots/wear/frost.png` — one hauler on the coast beside
## the same hauler on the snowfield — still reads as a machine on both.
##
## So the thing that must not change is the GATING, and that is what is asserted
## here. Cap the light channels to restore the luma number and LANTERN law 1
## loses its most visible effect to fix something a frame says is not wrong;
## ungate them and a machine on snow really does disappear.
##
## It reads the shipped shader, the way `tests/raid/test_causes_are_live.gd`
## reads shipped source, because the property lives in the shader and a copy of
## it here would be a second thing to drift.

const MATTER := "res://src/render/matter.gdshaderinc"


static func luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


static func source() -> String:
	var f := FileAccess.open(MATTER, FileAccess.READ)
	return f.get_as_text() if f != null else ""


## The body of `matter_worn`'s term for one wear channel: from its comment to the
## `if (<name> > 0.001)` that spends it.
static func term(src: String, name: String) -> String:
	var at := src.find("float %s = wear." % name)
	if at < 0:
		return ""
	var end := src.find("if (%s > 0.001)" % name, at)
	return src.substr(at, maxi(0, end - at))


func test_the_light_channels_are_gated_on_what_faces_the_sky() -> void:
	var src := source()
	check(src.length() > 0, "the include is readable")
	# `top` is `clamp(up, 0, 1)`: the face's own upness. A light channel that does
	# not multiply by it lands on the flanks too, and THAT is what would take a
	# machine's mass away rather than its roof's.
	for name: String in ["salt", "frost"]:
		var body := term(src, name)
		check(body != "", "%s is still a term in matter_worn" % name)
		check(body.contains("top"), ("%s must stay gated on `top`, or it lands on the flanks and a machine "
			+ "on snow or salt stops being a mass at all (docs/ART.md §4)") % name)
	# And the dark ones must NOT be, or a machine in the bog loses the rust down
	# its sides that is the whole of what the bog does to it.
	for name: String in ["rust", "soot"]:
		var body := term(src, name)
		check(body != "", "%s is still a term in matter_worn" % name)
		check(body.contains("flank") or body.contains("in_lee"),
			"%s must keep reaching surfaces that do not face the sky" % name)


func test_the_light_wear_is_lighter_than_the_turf_and_the_dark_is_darker() -> void:
	# The arithmetic the paragraph above is built on, pinned so the numbers in
	# docs/ART.md cannot quietly stop being true. These four are the colours
	# `matter_worn` mixes toward; the turf is what the ramps test holds fills under.
	var turf := luma(Palette.MOSS[3])
	near(turf, 0.350, 0.01, "coast turf")
	near(luma(Color(0.431, 0.200, 0.126)), 0.261, 0.01, "MATTER_RUST")
	near(luma(Color(0.071, 0.067, 0.114)), 0.073, 0.01, "MATTER_SOOT")
	near(luma(Color(0.910, 0.863, 0.753)), 0.865, 0.01, "MATTER_SALT")
	near(luma(Color(0.867, 0.941, 0.969)), 0.921, 0.01, "MATTER_FROST")
	lt(luma(Color(0.431, 0.200, 0.126)), turf, "rust is darker than the turf, so the law holds in the bog")
	lt(luma(Color(0.071, 0.067, 0.114)), turf, "soot is darker than the turf, so the law holds in the Burning")
	gt(luma(Color(0.910, 0.863, 0.753)), turf, "salt is LIGHTER: §4's letter is false on the flat")
	gt(luma(Color(0.867, 0.941, 0.969)), turf, "frost is LIGHTER: §4's letter is false on the snowfield")


func test_the_two_landscapes_that_break_the_letter_are_the_two_that_declare_it() -> void:
	# Which lands press with a LIGHT channel at all, so the next landscape added
	# with a full salt or frost row meets this file rather than a surprise.
	var light: Array[String] = []
	for id: StringName in SkyWear.OF:
		var w: Color = SkyWear.OF[id]
		if w.g >= 0.9 or w.a >= 0.9:
			light.append(String(id))
	light.sort()
	eq(light, ["salt_flats", "snowfield"],
		"a landscape pressing salt or frost at full strength puts a machine's ROOF above the turf; "
		+ "its flanks still carry it (docs/ART.md §4), but the frame is worth looking at: %s" % [light])
