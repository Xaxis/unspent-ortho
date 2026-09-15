extends Node3D
## Every model in the game on one lit plinth, under the game's own camera,
## lights and outline. The review surface for anything drawn:
##   tools/shot.sh shots/gallery.png --scene=gallery [--filter=pine] [--hour=21]
##
## Discovery is by convention so parallel work never edits a shared list: any
## script under res://src/models/ or res://src/systems/ (recursively) that defines
##   static func gallery() -> Array   # of {"name": String, "node": Node3D}
## contributes its items. Nodes that need the world material get it via
## `material` meta; see _material_for().

var options: BootOptions
var _mat: ShaderMaterial


func setup(o: BootOptions) -> void:
	options = o
	name = "gallery"
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/render/world.gdshader")
	var sky := SkyLight.new()
	add_child(sky)
	sky.set_hour(o.hour)

	var items: Array = []
	var paths := _find("res://src/models")
	paths.append_array(_find("res://src/systems"))
	for path in paths:
		var s: GDScript = load(path)
		if s == null:
			continue
		for m in s.get_script_method_list():
			if m.name == "gallery":
				items.append_array(s.call("gallery"))
				break
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.trim_prefix("--filter=")
	if filter != "":
		items = items.filter(func(it: Dictionary) -> bool: return String(it.name).contains(filter))

	var cols := maxi(1, ceili(sqrt(items.size() * 1.8)))
	var spacing := 3.2
	var rows := ceili(float(items.size()) / cols)
	var plinth := MeshKit.new()
	plinth.box(Vector3(-1.5, -0.5, -1.5), Vector3(cols * spacing + 0.3, 0.0, rows * spacing + 0.3), Palette.STONE[2], Palette.MOSS[3])
	var ground := MeshInstance3D.new()
	ground.mesh = plinth.build()
	ground.material_override = _mat
	add_child(ground)
	for i in items.size():
		var it: Dictionary = items[i]
		var node: Node3D = it.node
		node.position = Vector3((i % cols) * spacing, 0.0, (i / cols) * spacing)
		_apply_material(node)
		add_child(node)
		var label := Label3D.new()
		label.text = it.name
		label.font_size = 24
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Palette.LINEN[5]
		label.outline_modulate = Palette.INK[0]
		label.position = node.position + Vector3(0, -0.2, 1.1)
		add_child(label)
	var cam := CameraRig.new()
	cam.view_height = maxf(8.0, rows * spacing * 1.1 + 2.0) if o.zoom <= 0.0 else o.zoom
	add_child(cam)
	cam.snap_to(Vector3((cols - 1) * spacing * 0.5, 0.0, (rows - 1) * spacing * 0.5))
	print("gallery %d items" % items.size())


func _apply_material(n: Node) -> void:
	if n is GeometryInstance3D and (n as GeometryInstance3D).material_override == null:
		(n as GeometryInstance3D).material_override = _mat
	for c in n.get_children():
		_apply_material(c)


func _find(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root.path_join(f))
	for d in dir.get_directories():
		out.append_array(_find(root.path_join(d)))
	return out
