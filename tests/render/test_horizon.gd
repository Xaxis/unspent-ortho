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


## What stands on the far land is carried there as a silhouette of its own
## height, or a forest beyond the near chunks is a bare plain from eye level.
func test_a_far_tree_stands_up_off_the_land() -> void:
	var w := _ridge()
	var p := WorldProp.new(0, PropKind.PINE, Vector2(20.5, 20.5), 0.0, 1.0)
	w.props.append(p)
	eq(Far.stand_arrays(w, []).size(), 0, "nothing standing, nothing drawn")
	var stood: Array = Far.stand_arrays(w, [p])
	var n0 := 0
	var n1 := (stood[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	gt(float(n1), 0.0, "the pine adds a solid to the far land")
	var top := 0.0
	for v: Vector3 in stood[Mesh.ARRAY_VERTEX] as PackedVector3Array:
		if Vector2(v.x, v.z).distance_to(p.pos) < 3.0:
			top = maxf(top, v.y)
	var tall: float = Far.summary(PropKind.PINE, PropModels.variant_of(p, w.seed_value, Country.COAST), Country.COAST)[0]
	near(top, TerrainMesher.level_height(2) + tall, 0.05, "as tall as the model it stands for")
	# Every added face must be one that draws: front faces turned outward.
	var v3: PackedVector3Array = stood[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = stood[Mesh.ARRAY_NORMAL]
	var wrong := 0
	for i in range(n0, n1, 3):
		var f := (v3[i + 1] - v3[i]).cross(v3[i + 2] - v3[i])
		# Wound as the land is: the cross product is opposite the normal.
		if f.dot(nn[i]) > 0.0:
			wrong += 1
	eq(wrong, 0, "every silhouette face is wound to be drawn")


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


## A VIEW NOBODY CAN LOOK OUT FROM NEVER PAYS FOR THE SILHOUETTES. They cost most
## of the world's models built once, and nothing but a camera that sees the
## horizon shows them; a view that has never had one, and was not told the
## player can look out (`stands_early`), builds its far land and stops.
func test_silhouettes_wait_for_the_horizon() -> void:
	var w := _ridge()
	w.props.append(WorldProp.new(0, PropKind.PINE, Vector2(20.5, 20.5), 0.0, 1.0))
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
	check(not view.far.stands_done(w.size), "and no silhouettes are, with no horizon in sight")
	view.ensure_far()
	check(view.far.stands_done(w.size), "a view that looks out builds them")
	check(view.far.get_child(0).get_node_or_null("stands") != null, "and the pine stands on the far land")
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
	lt(float(level.sun_el), float(down.sun_el) - 15.0, "and at dusk the eye's sun is much lower")
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
	w.props.append(WorldProp.new(0, PropKind.PINE, Vector2(20.5, 20.5), 0.0, 1.0))
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
	while not view.far.stands_done(w.size) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	check(view.far.stands_done(w.size), "the silhouettes are in with the horizon never seen")
	view.queue_free()
	cam.queue_free()
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--size=64", "--seed=4"])))
	check(g.view.stands_early, "and a running game asks for them")
	g.free()
