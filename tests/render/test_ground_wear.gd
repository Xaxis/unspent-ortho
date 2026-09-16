extends TestCase
## Wear is what a landscape holds at the zoom it is PLAYED at (world.gdshader
## ground_wear). Four flat bands laid on a low-frequency field: they must each
## cover about a quarter of the land, and the ladder must never pull the whole
## land darker — the land is already too dark at noon, and a band that is
## silently mostly-darkening is a per-landscape luma regression nobody chose.
##
## The bands are cut on `worn`, which is three octaves of world.gdshader's own
## value noise. That noise is reproduced here exactly so the thresholds can be
## held to the distribution they claim, without a GPU.

const CUTS := Vector3(0.40, 0.50, 0.60)
const MID := 2.0
const SRC := "res://src/render/world.gdshader"


func _fract(v: float) -> float:
	return v - floorf(v)


## world.gdshader / ink.gdshaderinc ink_hash(vec2).
func _hash(x: float, y: float) -> float:
	var px := _fract(x * 0.1031)
	var py := _fract(y * 0.1030)
	var d := px * (py + 33.33) + py * (px + 33.33)
	px += d
	py += d
	return _fract((px + py) * px)


## ink_vnoise(vec2).
func _vnoise(x: float, y: float) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var ux := (x - ix) * (x - ix) * (3.0 - 2.0 * (x - ix))
	var uy := (y - iy) * (y - iy) * (3.0 - 2.0 * (y - iy))
	var a := _hash(ix, iy)
	var b := _hash(ix + 1.0, iy)
	var c := _hash(ix, iy + 1.0)
	var d := _hash(ix + 1.0, iy + 1.0)
	var top := a + (b - a) * ux
	return top + ((c + (d - c) * ux) - top) * uy


## ground_wear's `worn`, at world point (x, y).
func _worn(x: float, y: float) -> float:
	var rag := (_vnoise(x * 7.1 + 3.0, y * 7.1 + 3.0) - 0.5) * 0.06
	return _vnoise(x * 0.11 + 61.0, y * 0.11 + 61.0) * 0.55 \
		+ _vnoise(x * 0.31 + 13.0, y * 0.31 + 13.0) * 0.3 \
		+ _vnoise(x * 0.9 + 5.0, y * 0.9 + 5.0) * 0.15 + rag


func _bands() -> PackedInt32Array:
	var hist := PackedInt32Array()
	hist.resize(4)
	var rng := Rng.make(4242, 0)
	for i in 30000:
		var x := rng.randf_range(-700.0, 700.0)
		var y := rng.randf_range(-700.0, 700.0)
		var w := _worn(x, y)
		var lay := 0
		if w > CUTS.x:
			lay += 1
		if w > CUTS.y:
			lay += 1
		if w > CUTS.z:
			lay += 1
		hist[lay] += 1
	return hist


func test_each_band_of_wear_covers_about_a_quarter_of_the_land() -> void:
	# Cut on an even ramp instead and a third of the land sits in the lowest
	# band while the top one clamps, so the ladder's mean lands wherever the
	# clamp puts it and wear biases every landscape without anyone choosing it.
	var hist := _bands()
	var n := 0
	for i in 4:
		n += hist[i]
	for i in 4:
		var share := float(hist[i]) / float(n)
		gt(share, 0.20, "band %d covers a fair share of the land" % i)
		lt(share, 0.30, "band %d covers a fair share of the land" % i)


func test_wear_never_pulls_the_whole_land_darker() -> void:
	# The ladder is pinned at MID: everything below it lifts, everything above
	# lays down. With four even bands the middle is 1.5, so MID at or above it
	# means wear is value-neutral or a lift, never a net darkening.
	var hist := _bands()
	var n := 0
	var sum := 0.0
	for i in 4:
		n += hist[i]
		sum += float(hist[i]) * float(i)
	var mean := sum / float(n)
	lt(mean, MID + 0.001, "the mean band sits at or below where the ladder is pinned")
	lt(MID - mean, 0.75, "and not so far below it that wear only ever bleaches")


func test_the_shader_cuts_the_bands_where_this_test_measured_them() -> void:
	var src := FileAccess.get_file_as_string(SRC)
	check(src.contains("const vec3 WEAR_CUT = vec3(%.2f, %.2f, %.2f);" % [CUTS.x, CUTS.y, CUTS.z]),
		"the shader cuts the wear bands at the quartiles this test measured")
	check(src.contains("const float WEAR_MID = %.1f;" % MID), "and pins the ladder where this test checked it")
	check(src.contains("step(WEAR_CUT.x, worn) + step(WEAR_CUT.y, worn) + step(WEAR_CUT.z, worn)"),
		"the bands are cut on the consts, not on a ramp")
