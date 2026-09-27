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
