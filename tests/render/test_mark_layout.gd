extends TestCase
## THE MARK LAYOUT (GroundColors, THE LAYOUT). A mark is one byte, and it used to
## be squeezed: grounds 40..60 and walls 61..77 in one run with two numbers left,
## and every shader spelling that run by hand in six places, so each new material
## was a hunt through them. The land is now two runs of grounds and one of walls
## with room in each, and the shaders ask `mark_ground` / `mark_strata` /
## `mark_land` (matter.gdshaderinc). This holds the constants to their runs, the
## runs apart from each other and from the light and MADE codes, and the
## shader's own numbers to GroundColors', so neither can move alone.

const MATTER := "res://src/render/matter.gdshaderinc"


func _in(v: int, run: Vector2i) -> bool:
	return v >= run.x and v <= run.y


func test_every_ground_mark_lies_in_a_ground_run() -> void:
	for g: int in Ground.COUNT:
		if Ground.is_water(g):
			continue
		var m := GroundColors._base_mark(g)
		check(_in(m, GroundColors.GROUND_A) or _in(m, GroundColors.GROUND_B),
			"%s's mark %d is in a ground run" % [Ground.NAMES[g], m])
	for i: int in BiomeRegistry.land_indices():
		var d := BiomeRegistry.by_index(i)
		for g: int in d.ground_marks:
			var m: int = d.ground_marks[g]
			check(_in(m, GroundColors.GROUND_A) or _in(m, GroundColors.GROUND_B),
				"%s names mark %d for %s, in a ground run" % [d.id, m, Ground.NAMES[g]])
	for m: int in [GroundColors.FRESH, GroundColors.VITRIFIED, GroundColors.TIDEFLAT, GroundColors.CITY_FLOOR, GroundColors.OVERGROWN, GroundColors.CAST_FLOOR]:
		check(_in(m, GroundColors.GROUND_A) or _in(m, GroundColors.GROUND_B), "mark %d is a ground" % m)


func test_every_wall_is_in_the_strata_run() -> void:
	for d: BiomeDef in BiomeRegistry.all():
		for g: int in Ground.COUNT:
			var code := GroundColors.STRATA + GroundColors.strata(g, maxi(d.index, 0))
			check(_in(code, GroundColors.STRATA_RUN), "%s's wall %d is in the strata run" % [d.id, code])
	eq(GroundColors.STRATA + 1, GroundColors.STRATA_RUN.x, "strata ids start at 1")


func test_the_runs_do_not_touch_each_other_or_the_other_codes() -> void:
	var runs: Array[Vector2i] = [Vector2i(1, 34), GroundColors.GROUND_A,
		Vector2i(GroundColors.MADE_FIRST, 95), GroundColors.GROUND_B, GroundColors.STRATA_RUN]
	for i in runs.size():
		lt(float(runs[i].y), 256.0, "a mark is one byte")
		for j in range(i + 1, runs.size()):
			check(runs[i].y < runs[j].x, "run %s ends before %s begins" % [runs[i], runs[j]])
	check(_in(GroundColors.MADE_LAST, Vector2i(GroundColors.MADE_FIRST, 95)), "MADE fits its run")


func test_the_shader_states_the_same_layout() -> void:
	var src := FileAccess.get_file_as_string(MATTER)
	for pair: Array in [["MARK_GROUND_A0", GroundColors.GROUND_A.x], ["MARK_GROUND_A1", GroundColors.GROUND_A.y],
			["MARK_GROUND_B0", GroundColors.GROUND_B.x], ["MARK_GROUND_B1", GroundColors.GROUND_B.y],
			["MARK_STRATA", GroundColors.STRATA], ["MARK_STRATA_END", GroundColors.STRATA_RUN.y],
			["M_VITRIFIED", GroundColors.VITRIFIED], ["M_TIDEFLAT", GroundColors.TIDEFLAT],
			["M_CITY_FLOOR", GroundColors.CITY_FLOOR], ["M_OVERGROWN", GroundColors.OVERGROWN],
			["M_CAST_FLOOR", GroundColors.CAST_FLOOR], ["M_STRATA_CAST", GroundColors.STRATA + GroundColors.STRATA_CAST],
			["M_STRATA_ROOTED", GroundColors.STRATA + GroundColors.STRATA_ROOTED],
			["M_STRATA_BONE", GroundColors.STRATA + GroundColors.STRATA_BONE],
			["M_STRATA_GLASS", GroundColors.STRATA + GroundColors.STRATA_GLASS],
			["M_STRATA_TIDE", GroundColors.STRATA + GroundColors.STRATA_TIDE],
			["M_STRATA_CAVE", GroundColors.STRATA + GroundColors.STRATA_CAVE],
			["M_STRATA_REFUSE", GroundColors.STRATA + GroundColors.STRATA_REFUSE],
			["M_STRATA_CRAG", GroundColors.STRATA + GroundColors.STRATA_CRAG],
			["M_STRATA_DECK", GroundColors.STRATA + GroundColors.STRATA_DECK]]:
		check(src.contains("const int %s = %d;" % [pair[0], int(pair[1])]),
			"matter.gdshaderinc says %s = %d, as GroundColors does" % [pair[0], int(pair[1])])


func test_no_shader_spells_a_land_range_by_hand() -> void:
	# The squeeze came back every time somebody wrote `m <= 77`: every land test
	# goes through the helpers.
	for path: String in ["res://src/render/world.gdshader", "res://src/render/depth/fore.gdshader", MATTER]:
		var src := FileAccess.get_file_as_string(path)
		var re := RegEx.create_from_string("\\bm[i1]?\\s*(<=|<|>|>=)\\s*(59|6\\d|7\\d)\\b")
		eq(re.search_all(src).size(), 0, "%s spells no range over the old land codes" % path)
