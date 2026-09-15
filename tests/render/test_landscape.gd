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
			for c: int in Country.LAND:
				PropModels.template(kd, 1, c)
	)
	for kd: int in kinds:
		for c: int in Country.LAND:
			PropModels.template(kd, 1, c)
	WorkerThreadPool.wait_for_task_completion(task)
	for kd: int in kinds:
		gt(PropModels.template(kd, 1, Country.MOSS).made_v.size() + PropModels.template(kd, 1, Country.MOSS).found_v.size(), 11, "%s built once, whole" % PropKind.NAMES[kd])
