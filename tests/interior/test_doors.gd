extends TestCase
## Walking into a coast cottage and out again, in a running game (docs/interiors,
## S1). The door only swaps: the pocket's view is grown while the player stands
## at the door, the outside view is set aside whole and put back, and nothing is
## rebuilt on the way out.

const Sx := preload("res://tests/save/save_fixture.gd")


func _doors(g: Game) -> Node:
	return Sx.system(g, "21_doors")


func _frames(n: int) -> void:
	var until := Time.get_ticks_msec() + 15000
	for i in n:
		await tree.process_frame
		if Time.get_ticks_msec() > until:
			return


## Nodes under a view, the vertices its meshes hold, and the bytes of its world's
## per-tile arrays.
static func _kept_set(view: Node, w: WorldData) -> Vector3i:
	var nodes := 0
	var verts := 0
	var todo: Array[Node] = [view]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		nodes += 1
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			for si in mi.mesh.get_surface_count():
				verts += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		todo.append_array(n.get_children())
	var tiles := w.size * w.size
	return Vector3i(nodes, verts, w.level.size() + w.ground.size() + w.country.size() + tiles * 8)


func _at_door(g: Game, d: Node) -> Threshold:
	var p: Vector2 = d.call(&"tour_place", "door:house")
	g.player.hero.pos = p
	g.player.sync_view(0.0)
	var best: Threshold = null
	for t: Threshold in d.get("doors"):
		if best == null or t.door.distance_to(p) < best.door.distance_to(p):
			best = t
	return best


func test_in_through_a_cottage_door_and_out_onto_the_same_coast() -> void:
	Sx.use_root("doors-in-out")
	var g := Sx.game(tree, ["--seed=4", "--village=0", "--hour=11", "--weather=clear:0"])
	var d := _doors(g)
	check(d != null, "21_doors is loaded from src/systems")
	gt(float((d.get("doors") as Array).size()), 0.0, "the coast's houses have doors")
	var outside := g.world
	var outside_view := g.view
	var depleted := outside.depleted.duplicate()
	var t := _at_door(g, d)
	await _frames(90)
	check(d.get("_grown") != null, "the pocket was grown while the player stood at the door")
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:cottage")), "inside a cottage")
	eq(g.world.realm, Realm.INTERIOR, "in a pocket world under a roof")
	eq(g.view.world, g.world, "drawn by the pocket's own view")
	check(outside_view.get_parent() == null, "the outside view set aside, not freed")
	await _frames(10)
	var kept := _kept_set(g.view, g.world)
	# What a room costs to keep beside the coast set aside, counted off the room
	# itself: a process-wide counter reads the coast's own streaming, not this.
	# Printed, not held to a bar: the owner sets that budget.
	print("S1 kept set: %d nodes, %d mesh vertices (~%.2f MB of vertex data), world arrays %.2f MB" % [
		kept.x, kept.y, kept.y * 48.0 / 1048576.0, kept.z / 1048576.0])
	# What keeps the outside sleeps through the door rather than re-reading it.
	var sleepers: Array[Node] = []
	for sys: Node in g.systems:
		if sys.has_method(&"indoors"):
			sleepers.append(sys)
	gt(float(sleepers.size()), 0.0, "some systems keep the outside")
	for sys: Node in sleepers:
		check(not sys.is_processing() and not sys.is_physics_processing(), "%s sleeps indoors" % sys.name)
	var start := g.player.pos
	await _frames(20)
	# Walk at a wall: the room stops the body.
	g.scripted_move = Vector2(0.0, -1.0)
	g.scripted_seconds = 3.0
	await _frames(200)
	var pocket: InteriorGen.Pocket = d.get("pocket")
	check(pocket.layout.is_floor(floori(g.player.pos.x), floori(g.player.pos.y)), "walked into a wall and still on the floor (%s)" % str(g.player.pos))
	check(g.player.pos.distance_to(start) > 0.5, "and it did walk")
	# Back to the door, and out.
	g.player.hero.pos = pocket.layout.door - pocket.layout.door_out * 0.4
	g.player.sync_view(0.0)
	await _frames(5)
	await d.call(&"go_out")
	await _frames(30)
	check(g.world == outside, "out onto the SAME coast, not a new one")
	check(g.view == outside_view, "drawn by the view that drew it before")
	eq(g.world.depleted, depleted, "with what was taken from it intact")
	check(bool(d.call(&"tour_seen", &"outside")), "outside")
	for sys: Node in sleepers:
		check(sys.is_processing() or sys.is_physics_processing(), "%s wakes outside" % sys.name)
	eq(int(d.get("built_after_out")), 0, "and the way out rebuilt nothing")
	# The door's own cost, the swap under the cover, stated as the best of three
	# trips (load only ever adds time), and the worst beside it so an outlier is
	# seen rather than averaged away.
	var ins: Array[float] = [float(d.get("swap_in_ms"))]
	var outs: Array[float] = [float(d.get("swap_out_ms"))]
	for trip in 2:
		await _frames(30)
		await d.call(&"go_in", t)
		check(bool(d.call(&"tour_seen", &"inside:cottage")), "in again, trip %d" % (trip + 2))
		await _frames(10)
		await d.call(&"go_out")
		check(g.world == outside and g.view == outside_view, "and out onto the same coast, trip %d" % (trip + 2))
		ins.append(float(d.get("swap_in_ms")))
		outs.append(float(d.get("swap_out_ms")))
	print("S1 swap in best %.1f worst %.1f ms, swap out best %.1f worst %.1f ms" % [
		ins.min(), ins.max(), outs.min(), outs.max()])
	lt(float(ins.min()), 50.0, "the way in swaps under 50 ms")
	lt(float(outs.min()), 50.0, "the way out swaps under 50 ms")
	# And no trip STALLS: the bar above is a cost, this is the door a player felt
	# stand for 4.6 s when the view waited on its far rings to leave the tree.
	lt(float(ins.max()), 250.0, "no way in stalls")
	lt(float(outs.max()), 250.0, "no way out stalls")
	Sx.end(g)
	Sx.finish()


## A save made in a room opens in that room: the coast is grown, the same house's
## pocket is grown behind the same door, and the player stands where they saved.
func test_a_save_made_inside_opens_inside() -> void:
	Sx.use_root("doors-save")
	var a := Sx.game(tree, ["--seed=4", "--village=0", "--hour=11", "--weather=clear:0"])
	var d := _doors(a)
	var t := _at_door(a, d)
	# Something built outside before going in: a save made in the room must keep
	# it, because the room is grown again and the coast is what the save carries.
	var fire_at := t.door + t.out * 2.5
	var built := Survival.add_prop(a, PropKind.FIRE, fire_at)
	await _frames(30)
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:cottage")), "inside before the save")
	var pocket: InteriorGen.Pocket = d.get("pocket")
	var stood := pocket.layout.inside() + Vector2(0.0, -1.5).rotated(pocket.layout.door_out.angle() - PI * 0.5)
	a.player.hero.pos = stood
	a.player.pos = stood
	await _frames(5)
	stood = a.player.pos
	var key := String(pocket.threshold.key)
	eq(Sx.system(a, "05_save").call("save_to", 2), "", "saved to slot 2 inside")
	Sx.end(a)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(2, o), "", "slot 2 boots")
	var b := Sx.game(tree, [], o)
	await _frames(10)
	var db := _doors(b)
	check(bool(db.call(&"tour_seen", &"inside:cottage")), "the save opens inside the cottage")
	eq(b.world.realm, Realm.INTERIOR, "in a pocket world")
	var back: InteriorGen.Pocket = db.get("pocket")
	check(back != null and String(back.threshold.key) == key, "behind the same door (%s)" % key)
	near(b.player.pos.distance_to(stood), 0.0, 0.3, "where the player stood when they saved")
	# And the way out leads onto the coast, at that door.
	await db.call(&"go_out")
	await _frames(10)
	check(bool(db.call(&"tour_seen", &"outside")), "and the door leads out")
	eq(b.world.realm, Realm.SURFACE, "onto the surface")
	near(b.player.pos.distance_to(back.threshold.door), 0.0, 1.0, "at the house's door")
	var kept := false
	for q: WorldProp in b.world.props:
		if q.kind == PropKind.FIRE and q.pos.distance_to(built.pos) < 0.01:
			kept = true
	check(kept, "and the fire built outside before going in is still there")
	Sx.end(b)
	Sx.finish()
