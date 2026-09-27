extends TestCase
## STEAM IN THE COLD IS WHITE (MobFx.plume): a machine's stack puffs the fire's
## soft billboard, UNSHADED, so it reads white against snow and sky whatever the
## sun does. The shared puff lit by the scene read grey. A breath under the
## close eye keeps the lit puff: it is air round a body, not a plume.

func _puff_under(parent: Node3D) -> StandardMaterial3D:
	for c in parent.get_children():
		if c is MeshInstance3D:
			return (c as MeshInstance3D).material_override as StandardMaterial3D
	return null


func test_a_plume_is_unshaded_white() -> void:
	var at := Node3D.new()
	tree.root.add_child(at)
	MobFx.plume(at, Vector3.ZERO, Palette.RIME[5], 1.0, 2.0, Vector2.ZERO, 7)
	var m := _puff_under(at)
	check(m != null, "a plume puts out a puff")
	if m != null:
		eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "unshaded, so the sun cannot grey it")
		gt(m.albedo_color.r, 0.85, "and white (%s)" % m.albedo_color)
	at.free()
	var shared := FireModel.smoke_material()
	eq(shared.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL, "the shared puff itself is untouched")
