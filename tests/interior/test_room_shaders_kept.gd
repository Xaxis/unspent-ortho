extends TestCase
## A ROOM'S SHADERS OUTLIVE THE VISIT (21_doors `_keep_shaders`). Godot frees a
## built-in material's shader with the last material using it, and a room's
## materials go when it is left, so on the web each entry built them again (the
## same cottage: 61 programs, then 11). Asked here of the keep itself: every
## built-in material a room drew with has a kept twin with the same shader key.

const Sx := preload("res://tests/save/save_fixture.gd")

var _doors := load("res://src/systems/21_doors.gd") as GDScript


func test_what_a_room_drew_with_is_kept_after_it_is_left() -> void:
	var g := Sx.game(tree, ["--seed=4", "--hour=11"])
	var doors: Node = Sx.system(g, "21_doors")
	var t: Threshold = null
	for th: Threshold in Interiors.thresholds(g.world):
		if th.kind == &"cottage":
			t = th
			break
	check(t != null, "seed 4 has a cottage")
	await doors.call(&"go_in", t)
	var keys := {}
	for n: Node in g.view.find_children("*", "GeometryInstance3D", true, false):
		var m := (n as GeometryInstance3D).material_override
		if m is BaseMaterial3D:
			keys[_doors.call(&"shader_key", m)] = true
	gt(float(keys.size()), 0.0, "the room draws with built-in materials")
	await doors.call(&"go_out")
	var kept: Dictionary = _doors.get(&"_shader_keep")
	for k: String in keys:
		check(kept.has(k), "a built-in material the room drew with is kept after it is left")
	Sx.end(g)


func test_a_material_is_keyed_by_its_settings_never_its_values() -> void:
	var a := StandardMaterial3D.new()
	a.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	a.albedo_color = Color.RED
	var b := a.duplicate() as StandardMaterial3D
	b.albedo_color = Color.BLUE
	b.roughness = 0.2
	eq(_doors.call(&"shader_key", a), _doors.call(&"shader_key", b), "a colour or a roughness is not a new shader")
	b.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	check(_doors.call(&"shader_key", a) != _doors.call(&"shader_key", b), "transparency is")
	b.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	b.albedo_texture = GradientTexture2D.new()
	check(_doors.call(&"shader_key", a) != _doors.call(&"shader_key", b), "a texture set is")
