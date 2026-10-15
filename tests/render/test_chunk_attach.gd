extends TestCase
## A STREAMED CHUNK'S PROPS GO IN OVER FRAMES. Its land is in at once; its prop
## meshes follow a few milliseconds a frame (WorldView ATTACH_BUDGET_USEC),
## because about eighty meshes and nodes a chunk were one 27 ms frame on the main
## thread, a hitch each time a walk crossed into new ground. Whatever needs a
## chunk whole (ensure_near) gets it whole, and it ends with the same meshes.

const Sx := preload("res://tests/save/save_fixture.gd")


## Land chunk `key` the way streaming does, its props deferred: [node, runs],
## or [] when it has fewer than `least` runs of props to put in.
static func _land(view: WorldView, key: Vector2i, least := 0) -> Array:
	var ch := view.mesher.build_arrays(key.x, key.y)
	var snap: Array = view._snapshot(key)
	var baked: Array = view.bake_props(ch, view.mesher, snap[0], snap[1])
	var runs := 0
	for i in 3:
		runs += WorldView._runs(baked, i).size()
	if runs < least:
		return []
	var dec: Array = view.decor.build_parts(ch, snap[0])
	view._add_chunk(key, ch, dec, 0, baked, true)
	return [view._chunks[key], runs]


static func _props(node: Node) -> int:
	var n := 0
	for part: String in ["props", "props_found", "props_leaf"]:
		n += WorldView.parts(node, part).size()
	return n


func test_a_streamed_chunk_lands_whole_land_first_and_its_props_after() -> void:
	Sx.use_root("chunk-attach")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	await tree.process_frame
	var view := g.view
	var key := Vector2i(-1, -1)
	var landed: Array = []
	var home: Vector2i = view._key_of(g.player.pos)
	for d in range(3, 10):
		for dir: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, -1)]:
			var k := home + dir * d
			if landed.is_empty() and not view._chunks.has(k) and not view._parked.has(k):
				landed = _land(view, k, 5)
				if not landed.is_empty():
					key = k
	check(not landed.is_empty(), "an unbuilt chunk with props to land")
	if landed.is_empty():
		Sx.end(g)
		return
	var node: Node3D = landed[0]
	var runs: int = landed[1]
	gt(float(runs), 4.0, "it has props to put in (%d runs)" % runs)
	check(node.get_node_or_null("terrain") != null, "the land is in at once")
	lt(float(_props(node)), float(runs), "the props are not all in on the frame it lands")
	view._attach_step(WorldView.ATTACH_BUDGET_USEC)
	view._attach_step(-1)
	eq(_props(node), runs, "and after, every one of them is")
	# A chunk wanted whole gets its queued props at once.
	for k2: Vector2i in [key + Vector2i(1, 0), key + Vector2i(0, 1), key + Vector2i(-1, 0)]:
		if not view._chunks.has(k2) and not view._parked.has(k2):
			var l2 := _land(view, k2, 1)
			if not l2.is_empty():
				view.ensure_near(g.player.pos)
				eq(_props(l2[0]), int(l2[1]), "ensure_near puts the rest in")
				break
	Sx.end(g)
