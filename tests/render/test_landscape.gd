extends TestCase
## The landscape as it streams and what it holds: props baked off the main
## thread, the evidence each landscape carries, and the machines' works laid
## across it.

const Terrain := preload("res://tests/render/test_terrain.gd")


## The terrain fixture with a few props and a strung pair of poles on it.
static func _dressed() -> WorldData:
	var w := Terrain.fixture()
	var kinds: Array[int] = [PropKind.PINE, PropKind.BOULDER, PropKind.HOUSE, PropKind.POLE, PropKind.POLE]
	var at: Array[Vector2] = [Vector2(36.5, 38.5), Vector2(42.5, 41.5), Vector2(34.5, 44.5), Vector2(38.5, 33.5), Vector2(44.5, 33.5)]
	for i in kinds.size():
		w.props.append(WorldProp.new(i, kinds[i], at[i], 0.3, 1.0))
	w.lines.append({"kind": PropKind.POLE, "props": PackedInt32Array([3, 4])})
	return w


func test_streamed_props_are_baked_on_the_worker_and_match_a_direct_bake() -> void:
	var w := _dressed()
	var view := WorldView.new()
	view.setup(w)
	tree.root.add_child(view)
	view.focus = Vector2(40, 40)
	var deadline := Time.get_ticks_msec() + 10000
	while view.pending() > 0 and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	eq(view.pending(), 0, "every wanted chunk streamed in")
	var node := view.get_node_or_null("chunk_1_1")
	check(node != null, "the chunk with the props streamed in")
	if node != null:
		var made := node.get_node_or_null("props") as MeshInstance3D
		var found := node.get_node_or_null("props_found") as MeshInstance3D
		check(made != null and found != null, "both prop meshes are there")
		var direct := view.bake_props(view.chunk_at(Vector2(40, 40)), TerrainMesher.new(w), w.props, [[w.props[3], w.props[4]]])
		if made != null:
			eq(made.mesh.surface_get_array_len(0), (direct[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "MADE props are the direct bake")
		if found != null:
			eq(found.mesh.surface_get_array_len(0), (direct[1][Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "FOUND props and cables are the direct bake")
	# A take is seen at once: the chunk's props are baked again without it.
	w.depleted[0] = INF
	view.refresh_props(w.props[0])
	var after := view.get_node_or_null("chunk_1_1/props") as MeshInstance3D
	var pine := PropModels.template(PropKind.PINE, PropModels.pick_variant(PropKind.PINE, Rng.hash_ints(w.seed_value, 0, 90)), Country.COAST)
	if node != null and after != null:
		var before_len := (view.bake_props(view.chunk_at(Vector2(40, 40)), TerrainMesher.new(w), [w.props[0], w.props[1], w.props[2]], [])[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		eq(after.mesh.surface_get_array_len(0), before_len - pine.made_v.size(), "the taken pine is gone from the bake")
	view.queue_free()
	await tree.process_frame


func test_prop_templates_are_safe_to_build_from_two_threads() -> void:
	var kinds: Array[int] = [PropKind.KILN, PropKind.WRECK, PropKind.CAIRN]
	var task := WorkerThreadPool.add_task(func() -> void:
		for kd: int in kinds:
			for c: int in BiomeRegistry.land_indices():
				PropModels.template(kd, 1, c)
	)
	for kd: int in kinds:
		for c: int in BiomeRegistry.land_indices():
			PropModels.template(kd, 1, c)
	WorkerThreadPool.wait_for_task_completion(task)
	for kd: int in kinds:
		gt(PropModels.template(kd, 1, Country.MOSS).made_v.size() + PropModels.template(kd, 1, Country.MOSS).found_v.size(), 11, "%s built once, whole" % PropKind.NAMES[kd])


func test_litter_gathers_where_the_machines_worked() -> void:
	var w := Terrain.fixture()
	var ch := TerrainMesher.new(w).build(0, 0)
	var plain := Decor.new(w)
	var worked := Decor.new(w)
	w.landmarks.append({"kind": &"turf_rows", "pos": Vector2(20, 16), "dir": Vector2.RIGHT, "half": Vector2(8, 12), "mark": &"cut"})
	worked.works = WorksMap.bake(w)
	var a := _rust(plain.build_arrays(ch))
	var b := _rust(worked.build_arrays(ch))
	gt(b, a * 3.0 + 20.0, "scrap in the cut (%d rust vertices, %d outside any work)" % [b, a])
	eq(_rust(worked.build_arrays(ch)), b, "litter is deterministic")


static func _rust(arrays: Array) -> int:
	if arrays.is_empty():
		return 0
	var n := 0
	for c: Color in (arrays[Mesh.ARRAY_COLOR] as PackedColorArray):
		if c.is_equal_approx(Palette.RUST[2]) or c.is_equal_approx(GroundColors.down(Palette.RUST[2], 0.4)):
			n += 1
	return n


func test_cold_lines_hang_with_ice_drawn_by_hand() -> void:
	var w := _dressed()
	var view := WorldView.new()
	view.setup(w)
	var ch := view.mesher.build_arrays(0, 1)
	var spans := [[w.props[3], w.props[4]]]
	var mild := view.bake_props(ch, view.mesher, [], spans)
	eq((mild[0] as Array).size(), 0, "a span in a mild landscape carries no ice")
	for i in w.country.size():
		if w.level[i] > 0:
			w.country[i] = Country.SNOWFIELD
	var cold := view.bake_props(ch, view.mesher, [], spans)
	check((cold[0] as Array).size() > 0 and (cold[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 60, "a span in the snow hangs with MADE ice")
	eq((cold[1][Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (mild[1][Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "and its FOUND cable is the same line")
	# The pylons in the snow carry ice on their crossarms; elsewhere they stay FOUND only.
	gt(PropModels.template(PropKind.PYLON, 0, Country.SNOWFIELD).made_v.size(), 60, "a snowfield pylon has ice on its arms")
	eq(PropModels.template(PropKind.PYLON, 0, Country.COAST).made_v.size(), 0, "a coast pylon has none")
	view.free()


func test_drifts_are_soft_mounds_not_shards() -> void:
	var k := PropModels.Remains.Kit.new()
	PropModels.Remains.drift(k, Vector3.ZERO, 1.2, 0.6, 0.4, 0.3, Palette.RIME[5], 7)
	var top := 0.0
	var steep := 0
	for i in k.made.verts.size():
		top = maxf(top, k.made.verts[i].y)
		if k.made.normals[i].y < 0.5:
			steep += 1
	near(top, 0.4, 0.02, "a drift rises to its height")
	lt(float(steep) / k.made.verts.size(), 0.2, "its faces lie low, not up-ended like shards")
	# Long and low: its footprint is far wider than it is tall.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in k.made.verts:
		lo = lo.min(Vector2(v.x, v.z))
		hi = hi.max(Vector2(v.x, v.z))
	gt((hi - lo).length(), top * 5.0, "long and low")
