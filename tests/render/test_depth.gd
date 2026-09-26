extends TestCase
## LANTERN law 3: the world has thickness (docs/LOOK.md, src/render/depth/).
##
## Two things are pinned here and they are not the same kind of thing.
##
## The first is a MEASUREMENT that was wrong and is the reason this package
## exists: the air's reach was written as two constants against the depth range
## of the loaded chunks, and the FRAME is about ten units deep, so distance was
## doing about one per cent at the top of the picture. Anything that puts the
## reach back outside the frame fails here.
##
## The second is the promise: an occluder may never hide a threat or a thing
## that can be taken. Under an orthographic camera that is arithmetic, not
## taste, and the arithmetic is the only part a test can hold -- the picture is
## held by shots/depth/read-pair.png and by tours/depth.tour.


## The camera the game really plays at. Read off CameraRig's own exports rather
## than copied, so a rig that is retuned takes these numbers with it.
func _rig() -> Dictionary:
	var c := CameraRig.new()
	var out := {"distance": c.distance, "size": c.view_height, "pitch": c.pitch_deg}
	c.free()
	return out


func test_the_frame_is_about_ten_units_deep_and_the_air_lands_inside_it() -> void:
	var r := _rig()
	var half: float = Air.frame_depth(float(r.size), float(r.pitch))
	# (15 / 2) / tan(57) = 4.87. If this ever stops being small, the whole
	# argument for depth fog over exponential fog changes with it.
	gt(half, 4.0, "half the frame's depth, in world units")
	lt(half, 6.0, "half the frame's depth, in world units")
	var near_edge: float = float(r.distance) - half
	var far_edge: float = float(r.distance) + half
	var reach: Vector2 = Air.reach(float(r.distance), float(r.size), float(r.pitch))
	lt(reach.x, far_edge, "the air BEGINS before the far edge of the frame, or it does nothing at all")
	gt(reach.x, near_edge - 1.0, "and not before the near edge, or the ground under the player is hazy")
	gt(reach.y, far_edge, "it ENDS past the far edge, so the furthest land is never at the end of the ramp")
	lt(reach.y, far_edge + half * 2.0, "but not so far past that the far edge is still in the flat part")


func test_the_air_is_a_ramp_across_the_frame_and_not_a_wash_over_it() -> void:
	var r := _rig()
	var reach: Vector2 = Air.reach(float(r.distance), float(r.size), float(r.pitch))
	var half: float = Air.frame_depth(float(r.size), float(r.pitch))
	var near_edge: float = float(r.distance) - half
	var far_edge: float = float(r.distance) + half
	# What the renderer's depth fog does: smoothstep(begin, end, depth) ^ curve.
	var at := func(d: float) -> float:
		return pow(smoothstep(reach.x, reach.y, d), Air.CURVE)
	var near := float(at.call(near_edge))
	var mid := float(at.call(float(r.distance)))
	var far := float(at.call(far_edge))
	lt(near, 0.02, "the near edge of the picture is clear: that is where the player is standing")
	lt(mid, 0.25, "and the middle is nearly clear")
	gt(far, 0.35, "while the far edge is deep in the air -- the two must not be the same number")
	gt(far - mid, 0.3, "a RAMP across the frame")


func test_a_zoom_takes_the_air_with_it() -> void:
	var r := _rig()
	var close: Vector2 = Air.reach(float(r.distance), float(r.size) * 0.6, float(r.pitch))
	var wide: Vector2 = Air.reach(float(r.distance), float(r.size) * 2.0, float(r.pitch))
	gt(close.x, wide.x, "a zoomed-IN frame is shallower, so its air begins later")
	lt(close.y, wide.y, "and ends sooner. A constant could do neither")


func test_each_landscape_says_which_way_distance_goes() -> void:
	var day := Color(0.62, 0.68, 0.74)
	var bog := Air.colour(day, Air.row(&"moss"))
	var snow := Air.colour(day, Air.row(&"snowfield"))
	var here := Air.colour(day, Air.row(&"coast"))
	lt(bog.v, here.v * 0.75, "far goes DARK in the bog")
	gt(snow.v, here.v, "and PALE on the snowfield: the inversion is the whole idea")
	gt(absf(bog.v - snow.v), 0.5, "and the two are not near neighbours")


func test_every_landscape_in_the_registry_has_air_or_falls_back_to_the_quiet_one() -> void:
	for def: BiomeDef in BiomeRegistry.land():
		var row := Air.row(def.id)
		check(row.has("tow") and row.has("pull"), "%s has an air row" % def.id)
		gt(float(row.pull), -0.001, "%s pulls by a share" % def.id)
		lt(float(row.pull), 1.001, "%s pulls by a share" % def.id)
		gt(float(row.depth), 0.0, "%s has air at all" % def.id)


func test_the_air_can_never_take_enough_to_hide_something() -> void:
	# The worst case the game has: the thickest landscape, in the worst weather.
	var worst := 0.0
	for def: BiomeDef in BiomeRegistry.land():
		worst = maxf(worst, Air.density(Air.row(def.id), 2.1))
	lt(worst, 0.7, "even the thickest air leaves most of a far surface showing")
	eq(worst, Air.MOST, "and it is held at the cap, which is a readability number")


## --- The occluder's promise ------------------------------------------------

## Under an orthographic camera a thing at height h draws over the ground point
## h/tan(pitch) FURTHER from the eye than its own. This is the number the whole
## hole depends on, and getting it wrong opens the hole in clear air.
func test_a_piece_draws_over_ground_further_away_than_it_stands() -> void:
	var r := _rig()
	var lean := 1.0 / tan(deg_to_rad(float(r.pitch)))
	gt(lean, 0.6, "tiles further per unit of height, at the play pitch")
	lt(lean, 0.7, "tiles further per unit of height, at the play pitch")
	# The tallest thing this package hangs, over the ground it hangs on.
	var tallest := 0.0
	for k: int in ForeKinds.ROWS:
		tallest = maxf(tallest, (ForeKinds.ROWS[k].lift as Vector2).y)
	var offset := tallest * lean
	gt(offset, ForeView.CLEAR_REACH * 0.5,
		"the offset is big enough that ignoring it would matter")
	# And the reason this package does not simply use 18_crowns' clear list.
	gt(offset, 1.6, "a crown's own reach (1.6) does not cover it")


func test_the_hole_is_wide_enough_for_what_it_is_for() -> void:
	# A body is about a tile across and a machine half as much again. The hole
	# has to be wider than the thing plus the stipple at its rim.
	gt(ForeView.CLEAR_REACH, 1.5, "a machine fits in the hole with room round it")
	gt(ForeView.PLAYER_REACH, ForeView.CLEAR_REACH,
		"and the player's is wider still: it also covers whatever is at their feet")
	gt(ForeView.PLAYER_REACH, 2.5, "which is the whole of a use reach")


func test_the_player_can_never_be_crowded_out_of_their_own_hole() -> void:
	var mobs: Array[Vector2] = []
	var hostile := PackedByteArray()
	var aware := PackedByteArray()
	for i in 20:
		mobs.append(Vector2(float(i), 0.0))
		hostile.append(1)
		aware.append(1)
	var chosen := ForeView.rank(mobs, hostile, aware, Vector2.ZERO, ForeView.CLEAR - 1)
	eq(chosen.size(), ForeView.CLEAR - 1, "a crowd fills every slot but one")
	# Slot 0 is the player's and `clear_for` writes it before anything else; the
	# ranking is only ever asked for CLEAR - 1.


func test_a_body_that_has_noticed_you_gets_the_hole_before_a_gull() -> void:
	var mobs: Array[Vector2] = [Vector2(1, 0), Vector2(9, 0), Vector2(12, 0)]
	var hostile := PackedByteArray([0, 1, 1])
	var aware := PackedByteArray([0, 0, 1])
	var chosen := ForeView.rank(mobs, hostile, aware, Vector2.ZERO, 2)
	eq(chosen[0], Vector2(12, 0), "the one that has noticed you, though it is furthest")
	eq(chosen[1], Vector2(9, 0), "then the hostile, before the pest two tiles away")


## --- The tier contract -----------------------------------------------------

func test_every_layer_this_package_adds_is_gated_on_a_tier_row() -> void:
	for r: Dictionary in Quality.ROWS:
		check(r.has("fore"), "%s says how many foreground pieces it may hang" % r.id)
		check(r.has("near_focus"), "%s says whether it pays for the near blur" % r.id)
	gt(int(Quality.row(&"ultra").fore), int(Quality.row(&"web").fore),
		"ultra hangs more than the web, or the rows are decoration")
	gt(int(Quality.row(&"web").fore), 0,
		"and the web still has SOME: the same place on a worse night, not a flat one")
	check(not bool(Quality.row(&"web").near_focus),
		"the web does not pay for a screen pass it cannot afford")
	var view := FileAccess.get_file_as_string("res://src/render/depth/fore_view.gd")
	check(view.contains('Quality.current().get("fore", 0)'),
		"the view reads the row rather than deciding for itself")
	var rig := FileAccess.get_file_as_string("res://src/render/camera_rig.gd")
	check(rig.contains('Quality.current().get("near_focus", false)'),
		"and so does the near blur")


## The near blur may not soften anything a player has to read. The plane is
## derived from the frame, so this is a property of the arithmetic and holds at
## every zoom rather than at the one the constants were chosen at.
func test_the_near_blur_leaves_everything_a_player_reads_sharp() -> void:
	var c := CameraRig.new()
	for zoom: float in [0.6, 1.0, 1.6, 2.4]:
		var shown: float = c.view_height * zoom
		var near_ground: float = c.distance - Air.frame_depth(shown, c.pitch_deg)
		var begin: float = near_ground - CameraRig.DOF_CLEAR_LIFT * sin(deg_to_rad(c.pitch_deg))
		lt(begin, near_ground,
			"the blur begins IN FRONT of the nearest ground, at zoom %.1f" % zoom)
		# A machine is about 1.8 units tall. Standing at the very nearest edge of
		# the frame it is this deep, and it must still be past the plane.
		var machine: float = near_ground - 1.8 * sin(deg_to_rad(c.pitch_deg))
		gt(machine, begin,
			"a machine at the bottom edge of the frame is sharp, at zoom %.1f" % zoom)
	c.free()


## --- What is hung, and on what ---------------------------------------------

func test_a_piece_is_always_hung_on_something_that_is_standing_there() -> void:
	# There is no placement path that does not start from a prop: the view asks
	# the query for props and ForeKinds says which kinds carry one. A tile hash
	# in open air would put a limb in the sky with no trunk under it.
	var view := FileAccess.get_file_as_string("res://src/render/depth/fore_view.gd")
	check(view.contains("query.props_near("), "the layer is placed from the world's own props")
	check(not view.contains("Rng.hash01(world.seed_value, int(focus"),
		"and never from a tile hash")
	gt(ForeKinds.ROWS.size(), 8, "and enough kinds carry one that most places have some")


func test_what_hangs_on_a_prop_is_the_same_in_every_run() -> void:
	var p := WorldProp.new(4123, PropKind.PINE, Vector2(30.0, 40.0), 0.7, 1.0)
	var a := ForeKinds.hang(p, 7)
	var b := ForeKinds.hang(p, 7)
	eq(a, b, "same prop, same world, same piece")
	var other := ForeKinds.hang(p, 8)
	check(a != other, "and a different world hangs a different one")


func test_every_shape_builds_and_stays_inside_its_own_span() -> void:
	ForeKinds.forget()
	for shape: int in [ForeKinds.BOUGH, ForeKinds.LINE, ForeKinds.EAVE,
			ForeKinds.GIRDER, ForeKinds.TANGLE, ForeKinds.WALKWAY, ForeKinds.SIGN_ARM]:
		for v in ForeKinds.VARIANTS:
			var m := ForeKinds.template(shape, v, Color(0.2, 0.35, 0.3))
			gt(float(m.get_surface_count()), 0.0, "shape %d variant %d has geometry" % [shape, v])
			var box := m.get_aabb()
			# The instance scales this by the piece's span, so a template that
			# ran past unit length would reach twice as far as `ROWS` says and
			# the gather band would be too small for it.
			lt(box.position.x + box.size.x, 1.35,
				"shape %d variant %d reaches about one unit span" % [shape, v])
			lt(box.size.y, 1.2, "shape %d variant %d does not hang a whole unit down" % [shape, v])
	ForeKinds.forget()


func test_a_piece_is_cheap_enough_that_a_frame_can_hold_the_tier_full_of_them() -> void:
	ForeKinds.forget()
	var most := 0
	for shape: int in [ForeKinds.BOUGH, ForeKinds.LINE, ForeKinds.EAVE,
			ForeKinds.GIRDER, ForeKinds.TANGLE, ForeKinds.WALKWAY, ForeKinds.SIGN_ARM]:
		for v in ForeKinds.VARIANTS:
			var m := ForeKinds.template(shape, v, Color(0.2, 0.35, 0.3))
			var tris := 0
			for s in m.get_surface_count():
				tris += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			most = maxi(most, tris)
	lt(float(most), 900.0, "the dearest piece, in triangles")
	# The whole layer at the dearest tier, against a machine's own budget.
	lt(float(most * int(Quality.row(&"ultra").fore)), 26000.0,
		"the whole layer at ultra, in triangles")
	ForeKinds.forget()


func test_the_foreground_draws_in_the_opaque_pass_and_has_no_priority_to_get_wrong() -> void:
	# A transparent world material at the default render_priority is drawn and
	# then painted over, silently and completely. This package is the most
	# exposed thing in the project to that, so it sidesteps it: every alpha is a
	# discard against a world-pinned stipple, exactly as world.gdshader cuts a
	# crown, and the pass is the opaque one.
	var src := FileAccess.get_file_as_string("res://src/render/depth/fore.gdshader")
	check(src.contains("discard;"), "the hole is cut, not faded")
	check(not src.contains("ALPHA"), "nothing here is alpha blended")
	check(not src.contains("blend_mix") and not src.contains("blend_add"),
		"and the render mode does not ask for a blend")
	check(src.contains("matter_albedo("), "colour goes through the one door")
	check(not src.contains("void light("), "and the renderer does the lighting")


## Weather falls at several depths, and the near band is in front of the player.
func test_weather_falls_at_more_than_one_depth() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/weather/weather_view.gd")
	check(src.contains("near_rain") and src.contains("far_rain"),
		"rain has a near band and a far one, not one sheet")
	# The near band sits high enough to be genuinely between the eye and the
	# ground: at 57 degrees, TOP * 0.95 = 10.45 units up is 8.8 units nearer.
	var near_high := WeatherView.TOP * 0.95
	gt(near_high * sin(deg_to_rad(57.0)), 6.0,
		"the near band is several units nearer the eye than the ground is")


## A CITY DOES NOT HANG A COTTAGE EAVE. Every building in the game is
## `PropKind.HOUSE`, so the layer's per-kind table answered for a six-storey
## tower with the row written for a one-storey cot: a 2.1-unit eave over a street
## it should have been roofing. This fails if a landscape that builds upward ever
## goes back to the kind's own row, and if a piece stops hanging off the height of
## the thing it is hung on.
func test_a_landscape_that_builds_upward_hangs_its_own_pieces() -> void:
	var city := -1
	var plain := -1
	for i in BiomeRegistry.count():
		var forms := BiomeForms.of(i)
		if forms == null or forms.stock.is_empty():
			continue
		if ForeKinds.FORM_ROWS.has(forms.form(0)):
			city = i
		else:
			plain = i
	check(city >= 0, "some landscape in the registry builds upward")
	check(plain >= 0, "and some landscape still builds one storey")
	# The same prop, asked in two landscapes: the kind cannot tell them apart and
	# the FORM has to.
	var p := WorldProp.new(211, PropKind.HOUSE, Vector2(40.0, 40.0), 0.0, 1.0)
	# DEALT, not hashed: the claim is about a building of the city's own height,
	# and this used to lean on id 211 happening to hash to a tall form. A model
	# is dealt by position now (`WorldProp.deal_hash`), and (40, 40) deals a low
	# one -- 1.84, a real reading of a real building, and no evidence either way
	# about how a TOWER hangs its piece. So the prop is given the tallest form.
	var tall := BiomeForms.of(city)
	for v in tall.stock.size():
		if p.variant < 0 or tall.fact(v, BiomeForms.HIGH, 2.6) > tall.fact(p.variant, BiomeForms.HIGH, 2.6):
			p.variant = v
	var in_city := ForeKinds.row_of(p, 7, city)
	var in_village := ForeKinds.row_of(p, 7, plain)
	check(in_city != in_village, "a building's piece is its landscape's, not its kind's")
	eq(in_village, ForeKinds.ROWS[PropKind.HOUSE], "a one-storey landscape is untouched")
	# The city's piece hangs off the building's own height, well clear of a head.
	var lift: Vector2 = in_city.lift
	gt(lift.x, 2.7, "a city piece hangs higher than a cottage eave (%.2f)" % lift.x)
	var forms := BiomeForms.of(city)
	var high := forms.fact(PropModels.variant_of(p, 7, city), BiomeForms.HIGH, 2.6)
	lt(lift.y, high, "and never above the building it is hung on (%.2f of %.2f)" % [lift.y, high])
	# A caller that does not know the landscape gets the kind's row, because a
	# guess would hang a walkway over a fishing village.
	eq(ForeKinds.row_of(p, 7, -1), ForeKinds.ROWS[PropKind.HOUSE], "no country, no guess")


## THE LAND NEVER OPENS AND NO VILLAGE CHANGES. `world.gdshader`'s tall cut is
## what stops a city building standing between the camera and the player, and it
## is the one thing in this package that can reach into a landscape nobody is
## working on. Both of its guards are held here against the DATA rather than
## against the number written in the shader, so raising a village form above the
## floor fails this instead of quietly putting a hole in a cottage roof.
func test_the_tall_cut_can_never_reach_a_village_or_the_land() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/world.gdshader")
	check(src.contains("float tall_cut("), "the tall cut exists")
	check(src.contains("if (m >= 40 && m <= 72) {"), "and the ground band (40..72: grounds 40..60, strata 61..72) is refused: the land never opens")
	# Read out of the shader so the two cannot drift apart. It is a UNIFORM now
	# rather than a const (18_crowns can put it out of reach to ask what the cut
	# COSTS), so what is pinned here is the DEFAULT the shipped game draws with.
	var decl := "uniform float tall_floor = "
	var at := src.find(decl)
	gt(float(at), 0.0, "the floor is named")
	var floor_v := src.substr(at + decl.length(), 8).to_float()
	gt(floor_v, 0.0, "and is a number (%f)" % floor_v)
	# THE FLOOR IS A FENCE, NOT A MEASUREMENT, and that is why this test asserts
	# a BAND and never the number. 3.0 is not a threshold anybody derived: it
	# sits between the tallest thing a village raises (steading 2.8) and the
	# shortest thing a city raises (block 4.6). The `float` and the
	# geometric-sounding name are what disguise that -- the genuinely geometric
	# answer is the subject's own height, about 1.8, in BOTH projections, because
	# the eye-to-head ray is lowest at the subject where it is exactly the
	# subject's head; it carries no pitch term at all. Deriving the floor from
	# geometry would therefore put it UNDER every village form and open the
	# cottages, with a derivation that made it look correct. So the fence is
	# policy, it does not scale with the eye, and a new cottage or a shorter city
	# block has to fail HERE rather than silently cross it.
	#
	# BUT THE GAP IS EMPTY OF BUILDINGS ONLY, AND THIS COMMENT SAID OTHERWISE
	# FOR ONE COMMIT. `tall_cut` reaches every MADE thing, so measuring the
	# BUILDING table and concluding "nothing in the game stands between them" was
	# evidence about houses answering a question about everything. Measured
	# instead, every kind and all 23 countries, by mesh extent:
	#
	#   in the gap, OVER the fence, so these open today: pine and snow pine
	#   2.83..4.40, scrap tree 2.96..3.27, pylon 4.12
	#   in the gap, UNDER it, so these never do: house 2.97..2.98, pole 2.98
	#   over 4.6 and not a building at all: fire tower 5.01..5.51, mural 7.54
	#
	# So the fence has always had a second job nobody wrote down, and the village
	# claim below is the half of its meaning that happens to be testable from a
	# table. A COAST-only sweep misses the pylon, and scale is not applied here,
	# so read these as model extents rather than as what stands in a world.
	var tallest := 0.0
	var worst := &""
	for id: StringName in BiomeForms.PLAIN:
		var high := float((BiomeForms.FORMS[id] as Dictionary).get(BiomeForms.HIGH, 0.0))
		if high > tallest:
			tallest = high
			worst = id
	lt(tallest, floor_v, "the tallest village form (%s at %.1f) stands under the cut's floor %.1f" % [worst, tallest, floor_v])
	# And EVERY city form has to reach it, not merely the tallest -- the old
	# version took the maximum, which a sixteen-metre spire satisfies on its own
	# while a four-metre block quietly falls through.
	var lowest := INF
	var least := &""
	for id: StringName in BiomeForms.RAISED:
		var high := float((BiomeForms.FORMS[id] as Dictionary).get(BiomeForms.HIGH, 0.0))
		if high < lowest:
			lowest = high
			least = id
	gt(lowest, floor_v, "the shortest city form (%s at %.1f) still reaches the floor %.1f" % [least, lowest, floor_v])


## The pieces hung over the top-down frame stand down for ANY camera that sees
## the horizon, not only the rig's shoulder view: a staged eye (96_eye) is its
## own Camera3D, and under it the rig's share was 0 and a piece was drawn full
## across the top-right of every eye frame (seed 7 coast at 21:30: that corner's
## mean luma 30 with it, 50 with `--fore=0`, 50 after this).
func test_the_foreground_stands_down_for_whatever_camera_sees_the_horizon() -> void:
	var src := FileAccess.get_file_as_string("res://src/systems/13_fore.gd")
	check(src.contains("view.thin(maxf(sh, SkyLight.horizon_share(get_viewport().get_camera_3d())))"),
		"13_fore thins by the drawing camera's horizon share as well as the rig's shoulder share")
