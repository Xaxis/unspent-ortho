extends TestCase
## A VIEW OUT OF THE TREE IS FREED WITH ITS WORKERS DONE (WorldView.dispose). A
## chunk built on a worker runs a method of the view, and while it runs the view
## is locked: `free()` on it then refuses ("Attempted to free a locked object")
## before the predelete that would have waited, and the view leaks with its
## worker still writing into it. A door's parked coast (21_doors), a page's
## unshown view, a title's next view and an offer never taken are all freed out
## of the tree; each goes through `dispose`.

const F := preload("res://tests/fight/fixture.gd")


func test_a_view_freed_while_its_worker_builds_is_freed() -> void:
	var w := F.flat_world(256)
	var v := WorldView.new()
	v.setup(w)
	v.threaded = true
	v.focus = Vector2(128.0, 128.0)
	# One step of the view starts a chunk building on the worker...
	v._process(0.0)
	check(v._task >= 0, "a chunk is building on the worker")
	# ...and it is freed while that build is still going.
	OS.delay_msec(4)
	WorldView.dispose(v)
	check(not is_instance_valid(v), "the view is gone")


## And with a chunk's props rebaking on the worker (refresh_props_soon): the
## rebake runs a method of the view too, so `dispose` has to wait on it as well.
func test_a_view_freed_while_its_props_rebake_is_freed() -> void:
	var w := F.flat_world(64, Ground.MOSS, Country.COAST, 2)
	var st := WorldProp.new(w.next_id(), PropKind.STANDING_STONE, Vector2(16.5, 16.5), 0.0, 1.0)
	w.add_prop(st)
	# Enough in the chunk that its rebake is still going when the view is freed.
	for y in 24:
		for x in 24:
			w.add_prop(WorldProp.new(w.next_id(), PropKind.PINE, Vector2(4.5 + x, 4.5 + y), 0.0, 1.0))
	var v := WorldView.new()
	v.setup(w)
	v.focus = Vector2(16.0, 16.0)
	v.ensure_near(Vector2(16.0, 16.0))
	check(v._chunks.has(Vector2i(0, 0)), "the chunk is built")
	v.threaded = true
	w.turn_prop(st.id, 0.4)
	v.refresh_props_soon(w.prop(st.id))
	v._rebake_step()
	check(v._rb_task >= 0, "its props are rebaking on the worker")
	# Started, and still going: a chunk this full bakes for tens of milliseconds.
	OS.delay_msec(4)
	check(not WorkerThreadPool.is_task_completed(v._rb_task), "and it is still going")
	WorldView.dispose(v)
	check(not is_instance_valid(v), "the view is gone")
