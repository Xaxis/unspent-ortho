extends TestCase
## One wind for everything that sways (src/render/wind.gdshaderinc). The sway was
## one formula copied into three shaders, and all three copies had the same three
## faults: the phase was `TIME * (1.1 + wind_strength)`, so easing the wind jumped
## every blade by TIME x delta; the push leaned east-north-east in every wind; and
## the only gust was a sine 108 tiles long that never crossed a frame.

const SWAYERS: Array[String] = [
	"res://src/render/world.gdshader",
	"res://src/render/foliage/leaf.gdshader",
	"res://src/render/depth/fore.gdshader",
	"res://src/render/foliage/grass.gdshader",
]
const INCLUDE := "res://src/render/wind.gdshaderinc"


## The body of `vertex()` in a shader's source, or "" when it has none.
static func vertex_body(src: String) -> String:
	var at := src.find("void vertex()")
	if at < 0:
		return ""
	var open := src.find("{", at)
	var depth := 0
	for i in range(open, src.length()):
		var ch := src[i]
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				return src.substr(open, i - open + 1)
	return ""


func test_every_swaying_shader_takes_the_one_wind_and_no_clock() -> void:
	for path in SWAYERS:
		var src := FileAccess.get_file_as_string(path)
		check(src.contains("#include \"%s\"" % INCLUDE), "%s includes the wind" % path)
		var body := vertex_body(src)
		check(body != "", "%s has a vertex()" % path)
		check(body.contains("wind_push("), "%s sways by wind_push" % path)
		check(not body.contains("TIME"), "%s: no sway runs on TIME, whose rate jumps when the wind eases" % path)


func test_the_wind_reads_its_phase_and_bearing_from_the_sky() -> void:
	var src := FileAccess.get_file_as_string(INCLUDE)
	check(src.contains("sky_wind.w"), "the phase is the sky's continuous one")
	check(src.contains("sky_wind.xy"), "the push leans the way the sky says the wind blows")
	check(src.contains("sky_gust.xy"), "the gust field travels by the sky's integrated offset")
	check(src.contains("sky_shock("), "a colossus's landing is a term in the one push")
	check(not src.contains("TIME"), "nothing in the wind runs on TIME")
	for pair: Array in [["GUST_CELL", WindField.CELL], ["GUST_PERIOD", WindField.PERIOD]]:
		check(src.contains("const float %s = %.1f;" % pair), "the shader's %s is WindField's" % pair[0])


## The gust field seen at a point one step later is the field that stood
## `speed x dt` upwind of it: it moves WITH sky_wind.xy, at the declared speed.
func test_a_gust_front_travels_downwind_at_the_declared_speed() -> void:
	for along: Vector2 in [Vector2(0.8, 0.0), Vector2(-0.3, 0.5), Vector2(0.0, -1.0)]:
		var g := WindField.advance(Vector4(3.0, 5.0, 1.0, 0.0), along, 0.0)
		var dt := 0.5
		var later := WindField.advance(g, along, dt)
		var step := along.normalized() * WindField.speed(along.length()) * dt
		var worst := 0.0
		var moved := 0.0
		for i in 40:
			var p := Vector2(float(i) * 3.7, float(i) * -2.3 + 11.0)
			worst = maxf(worst, absf(WindField.gust_at(p + step, later) - WindField.gust_at(p, g)))
			moved = maxf(moved, absf(WindField.gust_at(p, later) - WindField.gust_at(p, g)))
		lt(worst, 1e-4, "%s: the field carried downwind is the field" % along)
		gt(moved, 0.05, "%s: and a fixed point sees it change" % along)


func test_a_front_moves_fast_enough_to_cross_a_frame() -> void:
	gt(WindField.speed(0.5), 2.9, "a moderate wind carries fronts at 3 tiles/s or more")
	lt(WindField.speed(1.0), 6.1, "and a gale no faster than 6")
	# Fronts are gust-sized, not landscape-sized: a cell well inside a frame.
	check(WindField.CELL >= 8.0 and WindField.CELL <= 15.0, "a gust cell is 8-15 tiles")


## The offset wraps where the noise lattice repeats, so a field that has run for
## an hour is the same field, with no seam where the float wrapped.
func test_the_travel_wraps_on_the_lattice_and_never_jumps() -> void:
	var g := Vector4(WindField.PERIOD - 0.01, 2.0, 1.0, 0.0)
	var wrapped := WindField.advance(g, Vector2(1.0, 0.0), 0.2)
	lt(wrapped.x, 1.0, "the offset came round")
	for i in 20:
		var p := Vector2(float(i) * 5.1, float(i) * 1.9)
		var unwrapped := Vector4(g.x + (wrapped.x + WindField.PERIOD - g.x), wrapped.y, 1.0, 0.0)
		lt(absf(WindField.gust_at(p, wrapped) - WindField.gust_at(p, unwrapped)), 1e-4, "no seam at the wrap")


func test_a_calm_keeps_the_last_bearing() -> void:
	var g := WindField.advance(Vector4(0.0, 0.0, 0.0, 1.0), Vector2(0.0, 0.0), 1.0)
	eq(Vector2(g.z, g.w), Vector2(0.0, 1.0), "a calm has no bearing of its own")


## Slice 2: a leaf card's own flutter answers the gust field and the trample
## field, so a front reaching a crown sets it shivering and a body pushing
## through a bush rustles it. Before this the flutter ran on wind_strength alone,
## the same everywhere at once.
func test_leaves_shiver_in_a_gust_and_rustle_where_a_body_pushes() -> void:
	var body := vertex_body(FileAccess.get_file_as_string("res://src/render/foliage/leaf.gdshader"))
	check(body.contains("gust_at("), "a card's flutter reads the gust at its own place")
	check(body.contains("trample_at("), "and the trample field under it")
	check(body.contains("crown_clear[0]"), "and only a card near the ground a body stands on rustles")
