extends TestCase
## A closed hold's barricades are drawn in the world's own material. A made
## mesh carries no material of its own (PropModels.node) and a node does not
## inherit one from its parent, so a barricade left without one drew in Godot's
## grey default: a program nothing else on the web built, three of them the
## first time a road was held (tools/web.sh --programs).


func _game(args: PackedStringArray) -> Game:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(args))
	return g


func test_a_held_road_s_barricades_are_drawn_in_the_world_s_material() -> void:
	var base := PackedStringArray(["--seed=4", "--size=256", "--hour=11", "--weather=clear:0"])
	var g := _game(base)
	await frames(2)
	var holds := g.get_node("24_holds")
	var at := Vector2.INF
	for h: Object in holds.get("sites"):
		if holds.call(&"closed", h):
			at = h.get("pos")
			break
	g.queue_free()
	await frames(1)
	check(at != Vector2.INF, "this world holds a road")
	if at == Vector2.INF:
		return
	var args := base.duplicate()
	args.append("--at=%d,%d" % [roundi(at.x), roundi(at.y)])
	g = _game(args)
	await frames(60)
	var drawn := 0
	for n: Node in g.find_child("holds", true, false).find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			drawn += 1
			check(mi.get_active_material(i) != null, "%s surface %d has a material" % [mi.name, i])
	check(drawn > 0, "the hold stood beside the player")
	g.queue_free()
	await frames(1)
