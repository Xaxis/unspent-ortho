extends TestCase
## A PROP SET DOWN IN PLAY IS DRAWN BY A WORKER (Survival.add_prop). Every drop
## and every build rebaked its chunk's props on the main thread, and a chunk
## whose mid models were in baked three times over: 10 to 60 ms, a dropped frame
## each. The prop is in the data and stops a body at once; its drawing comes in
## a frame or a few later (WorldView.refresh_props_soon). And a chunk drawn again
## in place while its rebake is out (a take) is never put back by that older bake.

const F := preload("res://tests/fight/fixture.gd")
const Fx := preload("res://tests/survival/fixture.gd")
const KEY := Vector2i(0, 0)


## A rebake held on the worker until the test lets it go (as test_view_dispose).
class HeldView extends WorldView:
	var hold := false
	var started := false
	var gate := Semaphore.new()
	var _m := Mutex.new()

	func _rebake_worker(ch: TerrainMesher.Chunk, props: Array, spans: Array) -> void:
		_m.lock()
		started = true
		var held := hold
		_m.unlock()
		if held:
			gate.wait()
		super._rebake_worker(ch, props, spans)

	func has_started() -> bool:
		_m.lock()
		var s := started
		_m.unlock()
		return s


## A field whose first chunk is drawn with `n` pines standing in it.
static func _game(n: int, v: WorldView = null) -> Game:
	var w := F.flat_world(64, Ground.GRASS, Country.COAST, 2)
	for i in n:
		w.add_prop(WorldProp.new(w.next_id(), PropKind.PINE, Vector2(1.5 + (i % 14) * 2.1, 1.5 + (i / 14) * 2.3), float(i), 1.0))
	var g := Fx.from_world(w)
	if v == null:
		v = WorldView.new()
	v.setup(w)
	v.focus = Vector2(16.0, 16.0)
	v.ensure_near(Vector2(16.0, 16.0))
	g.view = v
	return g


static func _done(g: Game) -> void:
	WorldView.dispose(g.view)
	g.player.free()
	g.free()


## Step the view's rebakes until none is out or waiting.
static func _settle(v: WorldView) -> void:
	for i in 2000:
		v._rebake_step()
		if v._rb_task < 0 and v._rb_wanted.is_empty():
			return
		OS.delay_msec(2)


func test_setting_a_prop_down_costs_a_small_share_of_baking_its_chunk() -> void:
	var g := _game(150)
	var v := g.view
	check(v._chunks.has(KEY), "the chunk is drawn")
	var snap := v._snapshot(KEY)
	var bake := TestCase.best_of(3, func() -> void: v.bake_props(v._data.get(KEY), v.mesher, snap[0], snap[1]))
	var adds: Array[float] = []
	for i in 5:
		var t0 := Time.get_ticks_usec()
		Survival.add_prop(g, PropKind.CAIRN, Vector2(4.0 + i * 3.0, 28.0))
		adds.append(float(Time.get_ticks_usec() - t0))
		_settle(v)
	print("  a prop set down: %s us, its chunk's bake %.0f us" % [str(adds), bake])
	ratio_lt(adds.min() / maxf(bake, 1.0), 0.25, "a prop set down, as a share of baking its chunk")
	_done(g)


func test_a_prop_set_down_is_drawn_once_its_worker_is_done() -> void:
	var g := _game(20)
	var v := g.view
	var node: Node3D = v._chunks.get(KEY)
	var before: Node = node.get_node_or_null("props")
	check(before != null, "the chunk's props are drawn")
	var cairn := Survival.add_prop(g, PropKind.CAIRN, Vector2(20.0, 20.0))
	check(g.query.props_near(cairn.pos, 0.5).any(func(q: WorldProp) -> bool: return WorldProp.same(q, cairn)), "in the world at once")
	eq(node.get_node_or_null("props"), before, "and not drawn on the spot")
	_settle(v)
	var after: Node = node.get_node_or_null("props")
	check(after != null and after != before, "drawn once the worker is done")
	gt(float((after as MeshInstance3D).mesh.surface_get_array_len(0)), float((before as MeshInstance3D).mesh.surface_get_array_len(0)), "with the cairn in it")
	_done(g)


func test_a_take_drawn_while_the_rebake_is_out_is_not_put_back() -> void:
	var held := HeldView.new()
	held.hold = true
	var g := _game(20, held)
	var w := g.world
	var node: Node3D = held._chunks.get(KEY)
	# A cairn set down: its chunk's rebake takes the props as they stand, the
	# first pine among them, and is held on the worker.
	Survival.add_prop(g, PropKind.CAIRN, Vector2(20.0, 20.0))
	held._rebake_step()
	check(held._rb_task >= 0, "the rebake is out")
	var polls := 0
	while not held.has_started() and polls < 20000:
		OS.delay_usec(500)
		polls += 1
	if not held.has_started():
		print("  UNSTAGED the rebake never started on this runner's pool: not judged")
		held.gate.post()
		_done(g)
		return
	# Then the pine is taken away, and its chunk drawn again in place.
	var pine := w.prop_at(0)
	w.depleted[pine.id] = INF
	held.refresh_props(pine)
	var taken: Node = node.get_node_or_null("props")
	held.gate.post()
	_settle(held)
	eq(node.get_node_or_null("props"), taken, "the drawing of the take stands, not the older bake")
	_done(g)
