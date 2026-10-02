extends TestCase
## The world at eye level, out to the horizon: which cameras see it, that the
## far world keeps the land's real height, that it stands down under the near
## chunks, that the sea runs past what the eye can see, and that looking out to
## the horizon leaves nothing behind for the next top-down frame.

const Far := preload("res://src/render/world_far.gd")


func _camera(persp: bool, pitch_deg: float, fov_deg: float) -> Camera3D:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_PERSPECTIVE if persp else Camera3D.PROJECTION_ORTHOGONAL
	c.keep_aspect = Camera3D.KEEP_HEIGHT
	c.fov = fov_deg
	tree.root.add_child(c)
	c.rotation = Vector3(deg_to_rad(-pitch_deg), deg_to_rad(45.0), 0.0)
	return c


## The eye the owner asked for sees the horizon; the shipped orthographic camera
## and the pitched lens do not, so neither of them changes by a pixel.
func test_only_an_eye_level_camera_sees_the_horizon() -> void:
	var eye := _camera(true, 10.0, 60.0)
	var ortho := _camera(false, CameraRig.PITCH_DEG, CameraRig.LENS_FOV)
	var lens := _camera(true, CameraRig.LENS_PITCH, CameraRig.LENS_FOV)
	check(SkyLight.sees_horizon(eye), "a lens 10 degrees down with a 60 degree fov holds the horizon")
	check(not SkyLight.sees_horizon(ortho), "the orthographic play camera has no horizon")
	check(not SkyLight.sees_horizon(lens), "the pitched lens keeps the horizon out")
	check(not SkyLight.sees_horizon(null), "no camera, no horizon")
	for c: Camera3D in [eye, ortho, lens]:
		c.queue_free()


## AN EYE OUT IN THE AIR (SkyLight.LOOKS_OUT, the climb's) keeps the eye-level
## rules looking straight down a walker's leg, where a lens on the ground would
## have gone over to the play camera's; and only the eye that says so.
func test_an_eye_out_in_the_air_sees_by_the_horizon_at_any_pitch() -> void:
	var down := _camera(true, 80.0, 60.0)
	eq(SkyLight.horizon_share(down), 0.0, "a lens on the ground looking 80 degrees down has no horizon")
	down.set_meta(SkyLight.LOOKS_OUT, true)
	eq(SkyLight.horizon_share(down), 1.0, "the same lens out in the air is wholly under the eye-level rules")
	var ortho := _camera(false, CameraRig.PITCH_DEG, CameraRig.LENS_FOV)
	ortho.set_meta(SkyLight.LOOKS_OUT, true)
	eq(SkyLight.horizon_share(ortho), 0.0, "and the orthographic camera never is")
	for c: Camera3D in [down, ortho]:
		c.queue_free()


## A flat plain at level 2 with a ridge three tiles wide at level 12 running
## north-south through it.
static func _ridge() -> WorldData:
	var w := WorldData.new(3, 128)
	for y in 128:
		for x in 128:
			var i := y * 128 + x
			w.level[i] = 12 if x >= 60 and x < 63 else 2
			w.ground[i] = Ground.GRASS
			w.country[i] = Country.COAST
	return w


## FROM EYE LEVEL A RIDGE IS A SILHOUETTE, and the far world used to be a floor
## (every corner the lowest land within a cell of it), which put every ridge on
## the horizon down at the bottom of its valley.
func test_a_far_ridge_keeps_its_height() -> void:
	var w := _ridge()
	var arrays: Array = Far.build_arrays(w, 0, 0, Far.tables())
	var land: Array = arrays[0]
	var top := -INF
	for v: Vector3 in land[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		top = maxf(top, v.y)
	var ridge := TerrainMesher.level_height(12)
	print("ridge %.2f, far land reaches %.2f" % [ridge, top])
	gt(top, ridge * 0.6, "the far land stands up where the ridge does")
	lt(top, ridge + 0.01, "and never above the land it stands for")


## What stands on the far land is carried there as its own model seen from far
## off, or a forest beyond the near chunks is a bare plain from eye level.
func test_a_far_tree_stands_up_off_the_land() -> void:
	var w := _ridge()
	var p := WorldProp.new(0, PropKind.PINE, Vector2(20.5, 20.5), 0.0, 1.0)
	w.add_prop(p)
	eq(Far.stand_arrays(w, []).size(), 0, "nothing standing, nothing drawn")
	var levels: Array = Far.stand_arrays(w, [p])
	eq(levels.size(), Far.LEVELS.size(), "one set of far models per far level")
	var tall: float = Far.summary(PropKind.PINE, PropModels.variant_of(p, w.seed_value, Country.COAST), Country.COAST)[0]
	for li in levels.size():
		var top := 0.0
		var n := 0
		var wrong := 0
		for arrays: Array in levels[li]:
			if arrays.is_empty():
				continue
			var v3: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			n += v3.size()
			for v: Vector3 in v3:
				if Vector2(v.x, v.z).distance_to(p.pos) < 3.0:
					top = maxf(top, v.y)
		gt(float(n), 0.0, "the pine is on the far land at level %d" % li)
		# Its own model, cast as the near chunk casts it (height within the
		# near bake's own +/-15% cast), standing on the far land.
		near(top, TerrainMesher.level_height(2) + tall, tall * 0.2, "as tall as the model it stands for at level %d" % li)
		# Every kept face keeps the near model's winding and normal: made faces
		# are wound as the land is, the cross product opposite the normal.
		var made: Array = levels[li][0]
		if not made.is_empty():
			var v3: PackedVector3Array = made[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = made[Mesh.ARRAY_NORMAL]
			for i in range(0, v3.size(), 3):
				var f := (v3[i + 1] - v3[i]).cross(v3[i + 2] - v3[i])
				if f.length() > 1e-6 and f.dot(nn[i]) > 0.0:
					wrong += 1
		eq(wrong, 0, "every far face is wound to be drawn at level %d" % li)


## Where a near chunk is in the scene the far world discards itself; only the far
## world's own materials read the mask, so the near land draws as it always did.
func test_the_far_world_stands_down_only_under_near_chunks() -> void:
	var w := _ridge()
	var view := WorldView.new()
	view.setup(w)
	tree.root.add_child(view)
	view.ensure_near(Vector2(20, 20))
	view.ensure_far()
	var block := view.far.get_child(0)
	var mi := block.get_node("land") as MeshInstance3D
	var fm := mi.material_override as ShaderMaterial
	var far_cut := float(fm.get_shader_parameter("near_cut"))
	var tex := fm.get_shader_parameter("near_mask") as Texture2D
	eq(far_cut, 1.0, "the far land stands down under the near chunks")
	check(fm != view.world_material(), "with a material of its own")
	var near_cut: Variant = view.world_material().get_shader_parameter("near_cut")
	check(near_cut == null or float(near_cut) == 0.0, "the near land never reads the mask")
	check(tex != null, "the mask is bound")
	var img: Image = view._near_mask
	if img != null:
		var drawn := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).r > 0.5:
					drawn += 1
					check(view.get_node_or_null("chunk_%d_%d" % [x, y]) != null, "a masked cell is a chunk in the scene")
		eq(drawn, view.chunk_count(), "every chunk in the scene is masked, and nothing else")
	view.queue_free()


## NOTHING STANDING IS DRAWN PAST WHERE IT IS A PIXEL (Far.STANDS_SEEN): at eye
## level a far silhouette's coarse level ends there, as a near chunk's mid models
## do, and both still reach far past where any eye on the ground sees (SEE), so
## only an eye up a walker's leg loses them; from above nothing has an end.
func test_nothing_standing_is_drawn_past_a_pixel() -> void:
	gt(Far.STANDS_SEEN, SkyLight.SEE * 4.0, "the end is far past where an eye on the ground sees")
	var far: Node3D = Far.new()
	var block := Node3D.new()
	far.add_child(block)
	var coarse := MeshInstance3D.new()
	coarse.set_meta(&"far_level", 1)
	block.add_child(coarse)
	far.call(&"set_eye", true)
	eq(coarse.visibility_range_end, Far.STANDS_SEEN, "at eye level a coarse silhouette ends where it is a pixel")
	far.call(&"set_eye", false)
	eq(coarse.visibility_range_end, 0.0, "from above it has no end")
	far.free()


## A VIEW NOBODY CAN LOOK OUT FROM NEVER PAYS FOR THE SILHOUETTES. They cost most
## of the world's models built once, and nothing but a camera that sees the
## horizon shows them; a view that has never had one, and was not told the
## player can look out (`stands_early`), builds its far land and stops.
func test_silhouettes_wait_for_the_horizon() -> void:
	var w := _ridge()
	w.add_prop(WorldProp.new(0, PropKind.PINE, Vector2(20.5, 20.5), 0.0, 1.0))
	# The view asks the viewport's CURRENT camera whether the horizon shows, so
	# this stands its own top-down one: a perspective camera another test left
	# current would answer yes and build the silhouettes before the claim.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation = Vector3(deg_to_rad(-CameraRig.PITCH_DEG), 0.0, 0.0)
	tree.root.add_child(cam)
	cam.make_current()
	var view := WorldView.new()
	view.setup(w)
	tree.root.add_child(view)
	view.focus = Vector2(20, 20)
	var deadline := Time.get_ticks_msec() + 10000
	while not view.far.done(w.size) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	await process_frames(8)
	check(view.far.done(w.size), "the far land is built")
	check(view.far.stood_keys().is_empty(), "and no silhouettes are, with no horizon in sight")
	view.ensure_far()
	check(view.far_settled(), "a view that looks out builds them")
	check(view.far.get_child(0).get_node_or_null("stands_leaf_far") != null, "and the pine stands on the far land, at the coarse level the view from above draws")
	check(view.far.get_child(0).get_node_or_null("stands_leaf") == null, "and not the close level, which only an eye draws and so is not built for one")
	view.queue_free()
	cam.queue_free()


## At eye level the sea runs to the horizon: the open sea reaches past the
## furthest the eye sees from the world's own edge.
func test_the_open_sea_reaches_past_what_the_eye_sees() -> void:
	var w := _ridge()
	var view := WorldView.new()
	view.setup(w)
	var sea := view.get_node("open_sea") as MeshInstance3D
	var box := sea.mesh.get_aabb()
	lt(box.position.x, -SkyLight.SEE, "west past the eye's reach")
	gt(box.end.z, float(w.size) + SkyLight.SEE, "south past the eye's reach")
	view.free()


## FROM HIGH UP THE SEA RUNS UNDER THE ISLAND TOO: a far block not built yet is
## sea, not a hole onto the sky's ground half. The sheet under the map's square
## lies below the far water, as that lies below the near water, and is drawn
## only for an eye high over it.
func test_from_high_up_the_sea_runs_under_the_island() -> void:
	var w := _ridge()
	var view := WorldView.new()
	tree.root.add_child(view)
	view.setup(w)
	var under := view.get_node_or_null("open_sea/sea_under") as MeshInstance3D
	check(under != null, "a sheet under the map's square")
	if under == null:
		view.queue_free()
		return
	var box := under.mesh.get_aabb()
	near(box.position.x, 0.0, 0.01, "from the west edge")
	near(box.end.z, float(w.size), 0.01, "to the south edge")
	lt(box.position.y, TerrainMesher.WATER_Y - Far.DROP, "under the far water")
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	cam.position = Vector3(64.0, 1.7, 64.0)
	await process_frames(2)
	check(not under.visible, "not drawn for an eye at a man's height")
	cam.position = Vector3(64.0, 46000.0, 64.0)
	await process_frames(2)
	check(under.visible, "drawn for one up a walker's thigh")
	view.queue_free()
	cam.queue_free()
	await process_frames(1)


## A FAR CELL IS ITS TILES' MEAN: from up a leg a pixel holds a cell or two, and
## a cell coloured by its middle tile set grass beside rock across the island.
func test_a_far_cell_is_the_mean_of_its_land() -> void:
	var w := WorldData.new(3, 128)
	for y in 128:
		for x in 128:
			var i := y * 128 + x
			w.level[i] = 2
			# Every other column rock, the rest grass: no cell is one ground.
			w.ground[i] = Ground.ROCK if x % 2 == 0 else Ground.GRASS
			w.country[i] = Country.COAST
	var tabs: Array = Far.tables()
	var col: PackedColorArray = tabs[0]
	var rock := col[Ground.ROCK * BiomeRegistry.SLOTS + Country.COAST]
	var grass := col[Ground.GRASS * BiomeRegistry.SLOTS + Country.COAST]
	var mean := Vector3(rock.r + grass.r, rock.g + grass.g, rock.b + grass.b) * 0.5
	var cs: PackedColorArray = (Far.build_arrays(w, 0, 0, tabs)[0] as Array)[Mesh.ARRAY_COLOR]
	var off := 0
	for c: Color in cs:
		if Vector3(c.r, c.g, c.b).distance_to(mean) > 0.001:
			off += 1
	eq(off, 0, "every cell is the mean of its rock and grass (%d of %d vertices off it)" % [off, cs.size()])


## FROM HIGH UP THE AIR VEILS THE LAND AND CLOSES AT THE HORIZON: from the thigh
## the island fifty kilometres off keeps most of its light, the sea three times
## as far off far less, and the sea's own edge is in air that has closed; an eye
## on the drum or lower is under the eye level's air exactly.
func test_from_high_up_the_air_veils_the_land_and_closes_at_the_horizon() -> void:
	var island := SkyLight.aloft_air(50000.0)
	lt(island, 0.2, "the island from the thigh keeps most of its light (the air takes %.2f)" % island)
	gt(SkyLight.aloft_air(150000.0), 0.6, "the sea at three times that is mostly the air")
	eq(SkyLight.aloft_air(SkyLight.HIGHEST_SEE), 1.0, "and the sea's own edge is all air")
	var r := SkyLight.aloft_reach(Vector2(SkyLight.HORIZON_BEGIN, SkyLight.SEE), 46000.0)
	eq(r, Vector2(0.0, SkyLight.HIGHEST_SEE * SkyLight.ALOFT_EDGE), "which is the air _aloft gives the thigh's eye")
	eq(SkyLight.aloft_share(150.0), 0.0, "over the tallest thing on the land, the eye level's air")
	eq(SkyLight.aloft_share(46000.0), 1.0, "up a leg, the high air's")


## HIGH OVER THE LAND THE AIR IS SEEN THROUGH (SkyLight.aloft_reach): an eye a
## man's height up, or over the tallest thing on the land, keeps the eye-level
## air exactly; from a walker's thigh, forty kilometres up, the ground under it
## is well inside the air instead of behind it, and from the hub the air still
## closes inside the far plane the climb's eye is given.
func test_high_over_the_land_the_air_is_seen_through() -> void:
	var eye := Vector2(SkyLight.HORIZON_BEGIN, SkyLight.SEE)
	eq(SkyLight.aloft_reach(eye, 1.7), eye, "at a man's height the air is the eye level's")
	eq(SkyLight.aloft_reach(eye, 150.0), eye, "and over the tallest thing on the land")
	var h := 46000.0
	var r := SkyLight.aloft_reach(eye, h)
	gt(r.y, h * 2.0, "from the thigh the ground under him is well inside the air (closed at %.0f m)" % r.y)
	lt(r.x, h, "and the air has begun before the ground")
	lt(SkyLight.aloft_reach(eye, 55000.0).y, SkyLight.HIGHEST_SEE, "from the hub it closes inside the farthest eye's far plane")


## LOOKING OUT TO THE HORIZON LEAVES NOTHING BEHIND. The air, the sky, the
## shadow and the figure light are all changed while the horizon is in frame;
## the next top-down frame must find every one of them as the play camera has it.
func test_a_horizon_frame_leaves_the_top_down_one_untouched() -> void:
	var sky := SkyLight.new()
	var e := SkyLight.build_environment()
	var sm := e.sky.sky_material as ProceduralSkyMaterial
	var before := [e.background_mode, e.fog_depth_curve, e.fog_aerial_perspective, e.sky.sky_material]
	var a := Air.at({})
	sky._look_out(e, sm, a, 1.0, 0.4)
	check(e.background_mode == Environment.BG_SKY, "at the horizon the sky is drawn")
	check(e.sky.sky_material != sm, "and it is the seen sky, not the reflected one")
	eq(e.fog_density, 1.0, "the air closes the far edge completely")
	eq(e.fog_depth_end, SkyLight.SEE, "at the eye's reach")
	sky._look_out(e, sm, a, 0.0, 0.4)
	var after := [e.background_mode, e.fog_depth_curve, e.fog_aerial_perspective, e.sky.sky_material]
	for i in before.size():
		check(before[i] == after[i], "field %d is back as the play camera has it: %s -> %s" % [i, before[i], after[i]])
	sky.free()


## Tip a lens from 45 degrees down to level, half a degree a frame, and record
## what the air, the shadow and the light are at each step.
func _tilt(hour: float) -> Array[Dictionary]:
	var sky := SkyLight.new()
	tree.root.add_child(sky)
	sky.clock_hour = hour
	var cam := _camera(true, 45.0, 60.0)
	cam.make_current()
	var out: Array[Dictionary] = []
	var e := sky.env.environment
	var p := 45.0
	while p >= 0.0:
		cam.rotation = Vector3(deg_to_rad(-p), deg_to_rad(45.0), 0.0)
		sky.compose()
		out.append({"pitch": p, "fog_end": e.fog_depth_end, "fog_begin": e.fog_depth_begin,
			"fog_density": e.fog_density, "fog_curve": e.fog_depth_curve, "aerial": e.fog_aerial_perspective,
			"shadow": sky.sun.directional_shadow_max_distance, "sun_el": -sky.sun.rotation_degrees.x})
		p -= 0.5
	cam.queue_free()
	sky.queue_free()
	return out


## TIPPING THE VIEW NEVER SNAPS. A boolean put every eye-level rule in force in
## one frame at about 33 degrees down; each one is now carried over a band, so
## no half-degree of tilt moves any of them by more than a small share of the
## whole way it goes.
func test_tipping_up_to_the_horizon_never_snaps() -> void:
	var rows := _tilt(18.6)
	for key: String in ["fog_end", "fog_begin", "fog_density", "fog_curve", "aerial", "shadow", "sun_el"]:
		var lo := INF
		var hi := -INF
		var worst := 0.0
		for i in rows.size():
			var v := float(rows[i][key])
			lo = minf(lo, v)
			hi = maxf(hi, v)
			if i > 0:
				worst = maxf(worst, absf(v - float(rows[i - 1][key])))
		var span := hi - lo
		print("  %s: %.3f .. %.3f, worst half-degree step %.3f (%.0f%%)" % [key, lo, hi, worst, 100.0 * worst / maxf(span, 1e-6)])
		if span > 1e-4:
			lt(worst / span, 0.2, "%s moves over the band, not in one step" % key)


## AT EYE LEVEL THE LIGHT COMES FROM THE SUN THAT IS DRAWN, so dusk shadows fall
## away from it; looking down, the light is where the play camera always had it.
func test_the_light_at_eye_level_is_the_drawn_sun() -> void:
	var rows := _tilt(18.6)
	var level: Dictionary = rows[rows.size() - 1]
	var down: Dictionary = rows[0]
	near(float(level.sun_el), SkyLight.eye_light(18.6).y, 0.05, "level, the light stands at the drawn sun's height")
	near(float(down.sun_el), float(SkyLight.sun_at(18.6).elevation), 0.05, "45 degrees down, the play camera's light")
	# The evening sun comes down onto the eye's own arc (SkyLight.LOWER_FROM), so
	# by dusk the play camera and the eye are lit by one low sun, not by two.
	lt(float(level.sun_el), 30.0, "at dusk the eye's sun is low")
	lt(absf(float(level.sun_el) - float(down.sun_el)), 1.0, "and the play camera's has come down to meet it")
	for at: float in [SkyLight.SUNSET, SkyLight.SUNRISE]:
		lt(SkyLight.eye_light(at - 0.001).distance_to(SkyLight.eye_light(at + 0.001)), 0.1, "the sun and the moon hand over at one place")
	var ortho := _camera(false, CameraRig.PITCH_DEG, CameraRig.LENS_FOV)
	ortho.make_current()
	var sky := SkyLight.new()
	tree.root.add_child(sky)
	sky.clock_hour = 18.6
	sky.compose()
	near(-sky.sun.rotation_degrees.x, float(SkyLight.sun_at(18.6).elevation), 1e-4, "the orthographic game's light has not moved")
	sky.queue_free()
	ortho.queue_free()


## A GAME THE PLAYER CAN LOOK OUT FROM BUILDS THEM FROM THE START. The first
## look over the shoulder showed bare far land for seconds while the silhouettes
## were started only then; the view over the shoulder now asks for them at
## setup, and they come in on the far workers behind the near land with no
## horizon ever in sight.
func test_silhouettes_come_in_before_the_first_look() -> void:
	var w := _ridge()
	w.add_prop(WorldProp.new(0, PropKind.PINE, Vector2(20.5, 20.5), 0.0, 1.0))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation = Vector3(deg_to_rad(-CameraRig.PITCH_DEG), 0.0, 0.0)
	tree.root.add_child(cam)
	cam.make_current()
	var view := WorldView.new()
	view.setup(w)
	view.stands_early = true
	tree.root.add_child(view)
	view.focus = Vector2(20, 20)
	var deadline := Time.get_ticks_msec() + 10000
	while not view.far_settled() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	check(view.far_settled(), "the silhouettes are in with the horizon never seen")
	view.queue_free()
	cam.queue_free()
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--size=64", "--seed=4"])))
	check(g.view.stands_early, "and a running game asks for them")
	g.free()


## A DUST STORM IS THE LAND'S OWN AIR (BiomeDef.weather_style `dust`): the mesas'
## red and the salt's white are not the shared sand, a land that says nothing
## blows the shared sand, and a misspelt row is named.
func test_each_land_blows_its_own_dust() -> void:
	var mesas: Color = Air.dust_of(&"mesas").air
	var salt: Color = Air.dust_of(&"salt_flats").air
	gt(mesas.r - mesas.b, 0.3, "the mesas' dust is red iron")
	gt(salt.get_luminance(), mesas.get_luminance() + 0.2, "the salt's dust is pale")
	eq(Air.dust_of(&"coast").air, Air.DUST_AIR, "a land with no row blows the shared sand")
	eq(Air.at({&"mesas": 1.0}).dust, mesas, "and the air over a frame carries it")
	var bad := BiomeDef.new()
	bad.weather_style = {&"dust": {"colour": Color.RED}, &"sleet": {}}
	var said := "\n".join(PackedStringArray(bad.style_problems()))
	check(said.contains("no field colour"), "a misspelt field is named: %s" % said)
	check(said.contains("no row for sleet"), "and a kind with no style")


## WHERE A MACHINE CANNOT SEE YOU, YOU CANNOT SEE FAR EITHER: a dust storm's air
## closes at the distance the rules still let a typical machine see.
func test_a_dust_storm_closes_the_air_where_sight_ends() -> void:
	for s: float in [0.5, 1.0]:
		var r := SkyLight.dust_reach(30.0, s)
		near(r.y - 30.0, SkyLight.SIGHT_TYPICAL * Weather.sight_factor(&"dust", s), 1e-4, "closed at sight, strength %.1f" % s)
		lt(r.x, 30.0, "and clear up to the player")
	gt(SkyLight.dust_reach(30.0, 0.5).y, SkyLight.dust_reach(30.0, 1.0).y, "a thinner storm is seen further through")


## The sulphur jungle's fog is its own acid yellow, lying low; a land that says
## nothing keeps the shared pale mist.
func test_the_sulphur_jungle_fog_is_its_own() -> void:
	var row: Dictionary = BiomeRegistry.get_def(&"sulphur_jungle").weather_style.get(&"fog", {})
	check(not row.is_empty(), "the sulphur jungle styles its fog")
	var c: Color = row.get("air", Color.BLACK)
	gt(c.r + c.g - 2.0 * c.b, 0.4, "sulphur-yellow, not pale grey")
	gt(float(row.get("low", 0.0)), 0.5, "and it lies low")
	check(BiomeRegistry.get_def(&"coast").weather_style.get(&"fog", {}).is_empty(), "the coast keeps the shared fog")
	eq(BiomeRegistry.get_def(&"sulphur_jungle").style_problems().size(), 0, "a well-formed row")


## A BLOCK LET GO AND BUILT AGAIN IS THE BLOCK IT WAS. The far view keeps only the
## levels its camera can draw and drops the rest (`WorldView._far_evict`), so a
## level is built alone, and built again on the way back. Either is only safe if
## a level built alone, or twice, is to the byte the level built with the other.
func test_a_block_built_again_is_the_block_it_was() -> void:
	var w := WorldGen.generate(7, 256)
	var by := {}
	var houses := {}
	for r in w.table.size():
		var key := Vector2i(w.table.pos[r] / float(Far.BLOCK))
		if not by.has(key):
			by[key] = []
		(by[key] as Array).append(r)
		if w.table.kind[r] == PropKind.HOUSE:
			houses[key] = int(houses.get(key, 0)) + 1
	var most := Vector2i.ZERO
	for key: Vector2i in houses:
		if int(houses[key]) > int(houses.get(most, 0)):
			most = key
	var props: Array = []
	for r: int in by[most]:
		props.append(w.prop_at(r))
	var both := Far.stand_arrays(w, props, Far.BOTH)
	check(not both.is_empty(), "the block with most houses stands something (%d props)" % props.size())
	if both.is_empty():
		return
	var close := Far.stand_arrays(w, props, Far.CLOSE)
	var coarse := Far.stand_arrays(w, props, Far.COARSE)
	gt(float(var_to_bytes(both[0]).size()), 1000.0, "the close level has geometry")
	eq(hash(var_to_bytes(Far.stand_arrays(w, props, Far.BOTH))), hash(var_to_bytes(both)), "built twice, the same bytes")
	eq(hash(var_to_bytes(close[0])), hash(var_to_bytes(both[0])), "the close level alone is the close level of both")
	eq(hash(var_to_bytes(coarse[1])), hash(var_to_bytes(both[1])), "the coarse level alone is the coarse level of both")
	check(var_to_bytes(close[1]).size() < 64, "and a level not asked for is not built")


## A ROOFED CAVE IS ITS LID FROM FAR OFF. The near chunks draw a roof's top, and
## past them the far world stood the floor of the halls under an open sky.
func test_a_far_roof_keeps_its_lid() -> void:
	var w := WorldData.new(3, 128)
	for y in 128:
		for x in 128:
			var i := y * 128 + x
			w.level[i] = 2
			w.ground[i] = Ground.SAND
			w.country[i] = Country.COAST
	for y in range(40, 90):
		for x in range(40, 90):
			w.set_overhead(x, y, 6, 10)
	var land: Array = Far.build_arrays(w, 0, 0, Far.tables())[0]
	var inside := -INF
	var outside := -INF
	var vs: PackedVector3Array = land[Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = land[Mesh.ARRAY_COLOR]
	var tabs: Array = Far.tables()
	var roof_wash: Color = (tabs[0] as PackedColorArray)[(tabs[2] as PackedInt32Array)[Country.COAST] * BiomeRegistry.SLOTS + Country.COAST]
	var painted := 0
	for k in vs.size():
		var v := vs[k]
		if v.x > 48.0 and v.x < 80.0 and v.z > 48.0 and v.z < 80.0:
			inside = maxf(inside, v.y)
			if cs[k].is_equal_approx(roof_wash) or cs[k].is_equal_approx(roof_wash.darkened(0.03)):
				painted += 1
		elif v.x < 30.0:
			outside = maxf(outside, v.y)
	print("roof %.2f, far land over it %.2f, beside it %.2f" % [TerrainMesher.level_height(10), inside, outside])
	gt(inside, TerrainMesher.level_height(10) - 0.1, "the far land over the cave stands at the roof's top")
	lt(outside, TerrainMesher.level_height(3), "and the open plain beside it stays down")
	gt(painted, 0, "the lid is painted with the landscape's plain ground, as the near roof is")


## A CHUNK LET GO FOR THE PARK'S BUDGET IS NOT BUILT AGAIN UNTIL IT IS SEEN. At eye
## level the wanted square is bigger than the scene and the park together, and
## every chunk left over was built, parked, let go for the budget and built again,
## one every few frames, standing still: 258 builds in 1200 frames over the
## shoulder on seed 1's coast, and the far land starved behind them (2026-09-30).
func test_a_still_eye_stops_building() -> void:
	var w := WorldData.new(3, 256)
	for y in 256:
		for x in 256:
			var i := y * 256 + x
			w.level[i] = 2
			w.ground[i] = Ground.GRASS
			w.country[i] = Country.COAST
	var view := WorldView.new()
	view.threaded = false
	view.setup(w)
	tree.root.add_child(view)
	var cam := _camera(true, 5.0, 60.0)
	cam.global_position = Vector3(128.0, 3.0, 128.0)
	cam.make_current()
	view.near_limit = 96.0
	view.ensure_near(Vector2(128, 128))
	# The park holds about one chunk: everything built out of view is let go.
	view.park_budget = 1
	for i in 40:
		view._process(0.016)
	var settled := view.build_count
	for i in 60:
		view._process(0.016)
	eq(view.build_count, settled, "a still eye builds nothing more once what it sees is built (%d then %d)" % [settled, view.build_count])
	check(view.parked_count() <= 1, "and the park stays inside its budget")
	view.queue_free()
	cam.queue_free()
