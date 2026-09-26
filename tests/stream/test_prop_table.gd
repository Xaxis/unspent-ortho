extends TestCase
## Props as packed columns (`PropTable`, the streaming design's S7). While the
## objects still stand beside it, the table must be them, row for row, and what
## play changes on a prop must change on its row.

const SIZE := 512
const SEED := 7

static var _w: WorldData


static func _world() -> WorldData:
	if _w == null:
		_w = WorldGen.generate(SEED, SIZE)
	return _w


func test_every_row_is_its_prop() -> void:
	var w := _world()
	var t := w.table
	eq(t.size(), w.prop_count(), "a row for every prop")
	var bad := 0
	for i in w.prop_count():
		var p := w.prop_at(i)
		if t.kind[i] != p.kind or t.pos[i] != p.pos or t.rot[i] != p.rot or t.scale[i] != p.scale \
				or t.solid[i] != p.solid or t.variant[i] != p.variant or float(t.shown.get(i, 1.0)) != p.shown:
			bad += 1
			if bad < 4:
				fail("row %d differs from prop %d (%s at %s)" % [i, p.id, PropKind.NAMES[p.kind], p.pos])
	eq(bad, 0, "no row differs")
	lt(float(t.bytes()) / maxf(1.0, t.size()), 44.0, "a row is under 44 bytes (%d B)" % (t.bytes() / maxi(1, t.size())))


func test_what_play_changes_changes_the_row() -> void:
	var w := _world()
	var i := w.prop_count() / 2
	var p := w.prop_at(i)
	var was := [p.scale, p.solid, p.shown]
	w.set_shown(p, 0.4)
	w.set_scale(p, 0.7)
	w.set_solid(p, 0.2)
	eq([p.shown, p.scale, p.solid], [0.4, 0.7, 0.2], "the prop holds it")
	eq([w.table.shown.get(i, 1.0), w.table.scale[i], w.table.solid[i]], [0.4, 0.7, 0.2], "and so does its row")
	w.set_shown(p, 1.0)
	check(not w.table.shown.has(i), "a whole prop leaves the sparse column")
	w.set_scale(p, was[0])
	w.set_solid(p, was[1])
	# A prop the world does not hold (a settlement's ghost) changes, and no row does.
	var ghost := WorldProp.new(-7, PropKind.HOUSE, Vector2(10, 10), 0.0, 1.0)
	var rows := w.table.size()
	w.set_solid(ghost, 0.0)
	eq(ghost.solid, 0.0, "the ghost takes it")
	eq(w.table.size(), rows, "and the table is untouched")


func test_a_prop_set_down_later_gets_a_row() -> void:
	var w := WorldData.new(1, 16)
	w.add_prop(WorldProp.new(w.next_id(), PropKind.FIRE, Vector2(3.5, 3.5), 0.25, 1.0))
	eq(w.table.size(), 1, "one row")
	eq(w.table.pos[0], Vector2(3.5, 3.5), "where it stands")
	eq(w.table.rot[0], 0.25, "turned as it was")


## THE NUMBER S7 BOUGHT DOWN. A grown world keeps its props as table rows, and a
## WorldProp lives only while something holds it. Before S7 every prop was one
## (12,548 alive for 12,548 props at 512); a walk of every prop still makes them
## all, and lets them all go. A new holder of every prop makes this fail.
func test_a_grown_world_holds_no_props_as_objects() -> void:
	var w := _world()
	check(w.packed, "the world is packed")
	lt(float(WorldProp.live), 100.0, "a handful of props alive, not the world's %d (%d)" % [w.prop_count(), WorldProp.live])
	var every := w.each_prop()
	gt(float(WorldProp.live), float(w.prop_count()) - 1.0, "a walk makes every prop")
	every.clear()
	lt(float(WorldProp.live), 100.0, "and lets them all go (%d)" % WorldProp.live)


## THE COUNT IS EXACT ACROSS THREADS. Views are handed to the chunk and far
## workers and let go there, so props are made and freed on several threads at
## once; a count that drifts under that cannot hold the bound above.
func test_the_live_count_holds_while_threads_make_and_drop_props() -> void:
	var before := WorldProp.live
	var churn := func() -> void:
		for i in 20000:
			var p := WorldProp.new(i, PropKind.FIRE, Vector2(i, i), 0.0, 1.0)
			p.shown = 1.0
	var tasks: Array[int] = []
	for k in 4:
		tasks.append(WorkerThreadPool.add_task(churn))
	churn.call()
	for t in tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	eq(WorldProp.live, before, "every prop made on any thread is counted out again")
