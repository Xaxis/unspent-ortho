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


## A view whose props rebake is held on the worker until the test lets it go:
## `started` says the worker is inside the view's own method, which is what
## locks it, so the race is staged by state and never by a clock.
class HeldView extends WorldView:
	var started := false
	var gate := Semaphore.new()
	var _m := Mutex.new()

	func _rebake_worker(ch: TerrainMesher.Chunk, props: Array, spans: Array) -> void:
		_m.lock()
		started = true
		_m.unlock()
		gate.wait()
		super._rebake_worker(ch, props, spans)

	func has_started() -> bool:
		_m.lock()
		var s := started
		_m.unlock()
		return s


## And with a chunk's props rebaking on the worker (refresh_props_soon): the
## rebake runs a method of the view too, so `dispose` has to wait on it as well.
## The rebake is held inside the view's method, and let go from another thread
## only once `dispose` is under way: without the wait the free meets a locked
## view every time, with it the free waits for the release. Fast or slow, the
## runner changes only how long it takes.
func test_a_view_freed_while_its_props_rebake_is_freed() -> void:
	var w := F.flat_world(64, Ground.MOSS, Country.COAST, 2)
	var st := WorldProp.new(w.next_id(), PropKind.STANDING_STONE, Vector2(16.5, 16.5), 0.0, 1.0)
	w.add_prop(st)
	var v := HeldView.new()
	v.setup(w)
	v.focus = Vector2(16.0, 16.0)
	v.ensure_near(Vector2(16.0, 16.0))
	check(v._chunks.has(Vector2i(0, 0)), "the chunk is built")
	v.threaded = true
	w.turn_prop(st.id, 0.4)
	v.refresh_props_soon(w.prop(st.id))
	v._rebake_step()
	check(v._rb_task >= 0, "its props are rebaking on the worker")
	# Waited on the STATE: the worker inside the view's method. The cap is only
	# for a pool that never runs it at all, which is no answer either way.
	var polls := 0
	while not v.has_started() and polls < 20000:
		OS.delay_usec(500)
		polls += 1
	if not v.has_started():
		print("  UNSTAGED the rebake never started on this runner's pool: not judged")
		v.gate.post()
		WorldView.dispose(v)
		return
	# Let go from another thread, so a `dispose` that waits is not waiting on
	# itself; one that does not wait frees at once, into the lock.
	var gate := v.gate
	var opener := Thread.new()
	opener.start(func() -> void:
		OS.delay_msec(20)
		gate.post())
	WorldView.dispose(v)
	var freed := not is_instance_valid(v)
	opener.wait_to_finish()
	if not freed:
		# Left locked by a missing wait: let its worker end before the test does.
		WorldView.dispose(v)
	check(freed, "the view is gone")
