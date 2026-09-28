extends TestCase
## EVERYTHING A ROOM DRAWS HAS A MATERIAL. A room's view shares the outside's
## materials (WorldView.setup_sharing), and one it did not share drew in the
## renderer's grey default: the grass and weeds in a tower lobby, found on
## the web as programs nothing else built (tools/web.sh --programs,
## tours/every-room.tour).

const Sx := preload("res://tests/save/save_fixture.gd")


func test_every_surface_in_a_grassed_room_has_a_material() -> void:
	var g := Sx.game(tree, ["--seed=4", "--hour=11"])
	var doors: Node = Sx.system(g, "21_doors")
	for kind: StringName in [&"tower_lobby"]:
		var t: Threshold = null
		for th: Threshold in Interiors.thresholds(g.world):
			if th.kind == kind:
				t = th
				break
		check(t != null, "seed 4 has a %s" % kind)
		if t == null:
			continue
		await doors.call(&"go_in", t)
		var grass := 0
		for n: Node in g.view.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			if String(mi.name).begins_with("grass"):
				grass += mi.mesh.get_surface_count()
			for i in mi.mesh.get_surface_count():
				check(mi.get_active_material(i) != null, "%s: %s surface %d has a material" % [kind, mi.get_path(), i])
		gt(float(grass), 0.0, "the %s grows grass to draw" % kind)
		await doors.call(&"go_out")
	Sx.end(g)
