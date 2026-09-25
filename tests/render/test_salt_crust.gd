extends TestCase
## The salt crust is one pattern read in two places: the ground draws its plates
## and lifted rims (world.gdshader through salt_crust.gdshaderinc), and the salt
## flats' straw roots along those rims (Decor, SaltCrust). If the two drift
## apart the straw stands in the middle of plates and the cracks go bare.

const INC := "res://src/render/salt_crust.gdshaderinc"


func test_the_mirror_holds_the_shaders_numbers() -> void:
	var src := FileAccess.get_file_as_string(INC)
	for pair: Array in [["SALT_FREQ", SaltCrust.FREQ], ["SALT_LIFT", SaltCrust.LIFT],
			["SALT_RIM_MIN", SaltCrust.RIM_MIN], ["SALT_RIM_SPAN", SaltCrust.RIM_SPAN]]:
		check(src.contains("const float %s = %s;" % [pair[0], str(pair[1])]), "%s is SaltCrust's" % pair[0])
	check(src.contains("ink_hash(g + 1.7), ink_hash(g + 5.3)) * 0.8 + 0.1"), "the plate centres are placed as the mirror places them")
	check(src.contains("ink_hash(min(own, next) * 3.1 + max(own, next) * 7.3)"), "a join lifts as the mirror says")
	check(FileAccess.get_file_as_string("res://src/render/world.gdshader").contains("salt_cells("), "the ground draws its plates through the shared function")


func test_the_hash_is_ink_hash() -> void:
	# Values ink_hash gives on the GPU for these inputs, worked by hand from its
	# three lines: fract(p * (0.1031, 0.1030)); p += dot(p, p.yx + 33.33);
	# fract((p.x + p.y) * p.x).
	var p := Vector2(3.0, 7.0)
	var f := Vector2(fposmod(3.0 * 0.1031, 1.0), fposmod(7.0 * 0.1030, 1.0))
	var d := f.x * (f.y + 33.33) + f.y * (f.x + 33.33)
	var want := fposmod((f.x + d + f.y + d) * (f.x + d), 1.0)
	# Vector2 is single precision, as the GPU is; the sum above is double.
	lt(absf(SaltCrust.ink_hash(p) - want), 1e-3, "ink_hash(3, 7)")


func test_a_snapped_point_lies_on_a_lifted_rim() -> void:
	var on := 0
	var tried := 0
	for i in 400:
		var p := Vector2(float(i % 20) * 1.37 + 500.0, float(i / 20) * 1.91 + 300.0)
		var s := SaltCrust.snap(p)
		if s == Vector2.INF:
			continue
		tried += 1
		if SaltCrust.on_rim(s):
			on += 1
	gt(float(tried), 100.0, "most points have a lifted join to snap to (%d of 400)" % tried)
	eq(on, tried, "every snapped point is on the rim the ground draws")


func test_the_salt_flats_straw_grows_along_the_cracks_and_in_the_lee() -> void:
	var d := BiomeRegistry.get_def(&"salt_flats")
	var straw: GrassSpecies = d.grasses[0]
	check(straw.rims, "the salt flats' straw seeks the crust's cracks")
	gt(straw.lee, 0.0, "and drifts against whatever stands on the flat")
