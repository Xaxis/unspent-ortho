extends TestCase
## Nothing the game draws may reach the page.
##
## `neon_grade.x` is negative in most landscapes, so the grade's last step is a
## GAIN, and it is one number for the WHOLE frame: SkyLight averages every
## landscape in view. A pale land seen from a dark one is therefore multiplied by
## the dark one's lift. That is why 18.7% of shots/tour/biomes/15-coast-salt-flats.png
## was pure white, and why the snowfield — the landscape ART section 3 calls "the
## page itself" — still clipped against the pinewood (3.9%), the moss (4.4%) and
## the scrapwood (4.9%). A clipped pixel holds no second wash, no shade band, no
## hatch and no ink, so Law 2 and Law 6 fail exactly at an ecotone.
##
## sky.gdshaderinc answers it with a shoulder: under SKY_TOP_KNEE nothing moves,
## and what was heading past it rolls into the gap below SKY_TOP. These tests
## read the two numbers OUT of the shader, so the rule cannot be quietly undone
## in one file, and then check the brightest things the renderer can hand it.

const SHADER := "res://src/render/sky.gdshaderinc"
## The reviewers' measure: all three channels at or over this is "pure white".
const PURE := 250.0 / 255.0
## The page itself (LINEN[5]), lying snow and a whiteout, straight out of
## sky.gdshaderinc — the brightest colours sky_apply can hand the grade.
const BRIGHTEST: Array[Color] = [
	Color(0.910, 0.863, 0.753), Color(0.90, 0.93, 0.95), Color(0.96, 0.97, 1.0),
]


static func _const_in_shader(name: String) -> float:
	var f := FileAccess.open(SHADER, FileAccess.READ)
	if f == null:
		return -1.0
	for line: String in f.get_as_text().split("\n"):
		var t := line.strip_edges()
		if not t.begins_with("const float %s " % name):
			continue
		var eq := t.find("=")
		return t.substr(eq + 1).replace(";", "").strip_edges().to_float()
	return -1.0


## The shoulder from neon_graded(), per channel, as GDScript.
static func held(v: Vector3) -> Vector3:
	var knee := _const_in_shader("SKY_TOP_KNEE")
	var top := _const_in_shader("SKY_TOP")
	var out := Vector3.ZERO
	for i in 3:
		var x: float = v[i]
		var over := maxf(x - knee, 0.0)
		out[i] = minf(x, knee + (top - knee) * over / (over + (top - knee)))
	return out


func test_the_shoulder_is_in_the_shader_and_stops_below_the_page() -> void:
	var knee := _const_in_shader("SKY_TOP_KNEE")
	var top := _const_in_shader("SKY_TOP")
	gt(knee, 0.0, "sky.gdshaderinc declares SKY_TOP_KNEE")
	gt(top, knee, "and SKY_TOP above it")
	lt(top, PURE, "the ceiling itself is under pure white, so no pixel can ever reach it")
	var src := FileAccess.open(SHADER, FileAccess.READ).get_as_text()
	check(src.contains("SKY_TOP_KNEE) * over / (over + (SKY_TOP - SKY_TOP_KNEE))"),
		"and neon_graded rolls into it instead of stacking on the page")
	check(src.contains("min(lit, SKY_TOP_KNEE +"),
		"per channel, so a wash only loses what was over the line")


func test_the_page_itself_cannot_clip_under_any_landscape_lift() -> void:
	# The worst case a border can make: the two hardest-lifting landscapes in the
	# registry, both in frame. The page has to survive it with ink still on it.
	var lifts: Array[float] = []
	for d in BiomeRegistry.all():
		lifts.append(1.0 - d.grade.x)
	lifts.sort()
	var worst: float = lifts[lifts.size() - 1]
	gt(worst, 1.0, "at least one landscape lifts rather than darkens")
	for c: Color in BRIGHTEST:
		var lit := held(Vector3(c.r, c.g, c.b) * worst)
		lt(maxf(lit.x, maxf(lit.y, lit.z)), PURE,
			"%s stays off the page under the hardest lift in the game" % c)
	# And it is still a wash where a wash is still possible: a landscape's own
	# lift on its own washes leaves the page its warmth, and only a colour driven
	# far past the paper crowds the ceiling.
	var page := BRIGHTEST[0]
	var own := held(Vector3(page.r, page.g, page.b) * 1.2)
	gt(own.x - own.z, 0.03, "the page keeps its warm side under an ordinary lift")


func test_nothing_under_the_knee_is_touched() -> void:
	# The shoulder must not be a tone curve: every landscape's ordinary washes are
	# authored where they are and must come back exactly where they were.
	var knee := _const_in_shader("SKY_TOP_KNEE")
	for x: float in [0.0, 0.1, 0.35, 0.6, knee - 0.001]:
		var v := held(Vector3(x, x, x))
		near(v.x, x, 1e-6, "%.3f is left where it was" % x)


func test_a_lifted_wash_still_rises_with_the_wash_under_it() -> void:
	# Order is kept: a brighter wash must still draw brighter than a dimmer one
	# after the shoulder, or the contour and the shade band flatten into each other.
	var last := -1.0
	for x: float in [0.80, 0.86, 0.92, 1.0, 1.2, 1.6]:
		var v: float = held(Vector3(x, x, x)).x
		gt(v, last + 1e-5, "%.2f still draws over what is under it" % x)
		last = v
