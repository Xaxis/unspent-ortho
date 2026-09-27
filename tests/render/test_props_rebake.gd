extends TestCase
## A CHUNK'S PROPS REBAKED OFF THE MAIN THREAD (WorldView.refresh_props_soon):
## a prop changed where nobody is watching (a hush stone turned) is redrawn by a
## worker, and the chunk's new props are swapped in when it is done, never
## baked on the main thread.

const F := preload("res://tests/fight/fixture.gd")


func test_a_turned_stone_is_redrawn_by_a_worker() -> void:
	var w := F.flat_world(64, Ground.MOSS, Country.COAST, 2)
	var st := WorldProp.new(w.next_id(), PropKind.STANDING_STONE, Vector2(16.5, 16.5), 0.0, 1.0)
	w.add_prop(st)
	var v := WorldView.new()
	v.setup(w)
	v.focus = Vector2(16.0, 16.0)
	v.ensure_near(Vector2(16.0, 16.0))
	var node: Node3D = v._chunks.get(Vector2i(0, 0))
	check(node != null, "the chunk is built")
	var before: Node = node.get_node_or_null("props")
	check(before != null, "with its props drawn")
	w.turn_prop(st.id, 0.4)
	v.refresh_props_soon(w.prop(st.id))
	eq(node.get_node_or_null("props"), before, "nothing redrawn on the spot")
	for i in 400:
		v._rebake_step()
		if v._rb_task < 0 and v._rb_wanted.is_empty() and node.get_node_or_null("props") != before:
			break
		OS.delay_msec(5)
	var after: Node = node.get_node_or_null("props")
	check(after != null and after != before, "the props were swapped for new ones")
	gt(float(v.rebake_swap_usec_max), 0.0, "by the rebake, not in place")
	v.free()
