extends TestCase
## `perf lit` counts what the web's renderer pays for local lights: a light on a
## geometry when its range touches the geometry's box and its cull mask takes the
## geometry's layer, and no more of them on one geometry than the cap.

const LitPerf := preload("res://src/systems/tour/lit_perf.gd")


func _box(at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	m.position = at
	return m


func _lamp(at: Vector3, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.omni_range = reach
	l.position = at
	return l


func test_a_light_counts_on_what_its_range_and_mask_reach() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	root.add_child(_box(Vector3.ZERO))
	root.add_child(_box(Vector3(20, 0, 0)))
	# 1.5 from the first box's face: in its range of 2.
	root.add_child(_lamp(Vector3(2.5, 0, 0), 2.0))
	# Beside the first box, but its mask leaves out the box's layer.
	var masked := _lamp(Vector3(1.5, 0, 0), 2.0)
	masked.light_cull_mask = 2
	root.add_child(masked)
	# 3.5 from the first box and 16.5 from the second: neither.
	root.add_child(_lamp(Vector3(4.5, 0, 0), 2.0))
	var hidden := _lamp(Vector3.ZERO, 5.0)
	hidden.visible = false
	root.add_child(hidden)
	root.add_child(DirectionalLight3D.new())
	var c := LitPerf.count(root)
	eq(c.lights, 3, "the hidden lamp and the sun are not local lights shown")
	eq(c.pairs, 1, "only the lamp in range with the box's layer lights it")
	eq(c.lit, 1, "the far box is lit by nothing")
	eq(c.shaded, 12, "a box is 12 triangles, shaded by its one light")
	root.free()


func test_past_the_cap_a_geometry_is_counted_over() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	root.add_child(_box(Vector3.ZERO))
	for i in 9:
		root.add_child(_lamp(Vector3(1.5, 0, 0).rotated(Vector3.UP, i * 0.6), 2.0))
	var c := LitPerf.count(root)
	eq(c.most, 9, "nine lamps reach the box")
	eq(c.over, 1, "past the cap of %d" % int(c.cap))
	eq(c.shaded, 12 * int(c.cap), "only the cap's lights are shaded")
	root.free()
