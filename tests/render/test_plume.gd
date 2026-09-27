extends TestCase
## STEAM IN THE COLD IS WHITE (MobFx.plume): a machine's stack puffs the soft
## vapour billboard (plume.gdshader) with `unshaded` set, so it reads white against
## snow and sky whatever the sun does; lit by the scene it read grey. A breath
## keeps the lit puff: it is air round a body, not a plume.

func _puff_under(parent: Node3D) -> ShaderMaterial:
	for c in parent.get_children():
		if c is MeshInstance3D:
			return (c as MeshInstance3D).material_override as ShaderMaterial
	return null


func test_a_plume_is_unshaded_white() -> void:
	var at := Node3D.new()
	tree.root.add_child(at)
	MobFx.plume(at, Vector3.ZERO, Palette.RIME[5], 1.0, 2.0, Vector2.ZERO, 7)
	var m := _puff_under(at)
	check(m != null, "a plume puts out a puff")
	if m != null:
		eq(m.shader, MobFx.PLUME_SHADER, "the soft vapour, as every puff is")
		check(bool(m.get_shader_parameter("unshaded")), "unshaded, so the sun cannot grey it")
		gt((m.get_shader_parameter("tint") as Color).r, 0.85, "and white (%s)" % m.get_shader_parameter("tint"))
	at.free()
	var breath := Node3D.new()
	tree.root.add_child(breath)
	MobFx._air(breath, Vector3.ZERO, Palette.ASH[4], 1.0, 2.0, Vector2.ZERO, 7)
	var b := _puff_under(breath)
	check(b != null and not bool(b.get_shader_parameter("unshaded")), "a breath stays lit")
	breath.free()
