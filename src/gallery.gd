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

## Screen pixels a grid cell must be wide before the names are worth drawing.
const TAG_PITCH := 58.0
## Frames the gallery sweeps for captions a model hung deferred. Three is two
## more than any of them takes, and after that the walk stops: two hundred
## models' subtrees, every frame, is the whole reason this was a per-frame job.
const CAPTION_SWEEPS := 3

var options: BootOptions
var _mat: ShaderMaterial
var _cam: CameraRig
## [{name, at: Vector3}] — where each item's label is hung in the world.
var _labels: Array[Dictionary] = []
var _tags: Control
var _sweeps := CAPTION_SWEEPS


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
		_labels.append({"name": String(it.name), "at": node.position + Vector3(0, -0.2, 1.1)})
	var cam := CameraRig.new()
	cam.view_height = maxf(8.0, rows * spacing * 1.1 + 2.0) if o.zoom <= 0.0 else o.zoom
	add_child(cam)
	cam.snap_to(Vector3((cols - 1) * spacing * 0.5, 0.0, (rows - 1) * spacing * 0.5))
	_cam = cam
	# A name is only worth drawing where it does not cover the model beside it.
	# The whole gallery is a contact sheet of two hundred silhouettes at forty
	# pixels a cell; a review that needs the names uses --filter and gets them.
	var pitch := cam.unproject_position(Vector3.ZERO).distance_to(cam.unproject_position(Vector3(spacing, 0.0, 0.0)))
	if pitch >= TAG_PITCH:
		_add_tags()
	print("gallery %d items, %s (cell %d px)" % [items.size(), "named" if pitch >= TAG_PITCH else "a contact sheet: --filter for names", roundi(pitch)])


## The names, drawn in the game's own pixel font on a scrap of the slate's
## glass, at whole pixels of the 640x360 base.
##
## They were Label3D with a 12 px outline around a 24 px face: the outline
## swallowed the fill and every name read as a near-black smear over the models
## it was naming — 1.11:1 against the plinth. This is the surface every model
## review happens on, so the labels have to be readable at native size.
func _add_tags() -> void:
	var layer := CanvasLayer.new()
	layer.name = "tags"
	layer.layer = 10
	add_child(layer)
	_tags = Control.new()
	_tags.name = "canvas"
	_tags.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tags.theme = UiTheme.theme()
	_tags.draw.connect(_draw_tags)
	layer.add_child(_tags)


func _process(_delta: float) -> void:
	# The sweep for captions is not a per-frame job: a model's own script hangs
	# them deferred, so they are all there within a few frames of the first, and
	# walking two hundred models' whole subtree every frame is the gallery's own
	# budget spent on nothing.
	if _sweeps > 0:
		_sweeps -= 1
		_take_over_labels(self)
	if _tags != null:
		_tags.queue_redraw()


## A model's own script may hang Label3D captions on a row (machine_gallery's
## poses do, deferred, so they land after the first frame). They are the same
## dark smear over the plinth, so the gallery takes them over: the node is
## hidden and its text is drawn as a tag at the place it hung.
##
## On the contact sheet (`pitch < TAG_PITCH`, no `_tags` canvas) there is nothing
## to draw them on, so this hides them and they are gone: two hundred names at
## forty pixels a cell is a smear, and `--filter` is how a review gets them.
func _take_over_labels(n: Node) -> void:
	if n is Label3D and n.visible:
		var l := n as Label3D
		l.visible = false
		_labels.append({"name": l.text, "node": l})
		return
	for c in n.get_children():
		_take_over_labels(c)


func _draw_tags() -> void:
	if _cam == null:
		return
	# Near first, so the tag nearest the eye keeps its place and the ones behind
	# it step down out of its way — and a row's own caption is dropped when the
	# name above it already says the same word.
	var rows := _labels.duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _tag_at(a).z > _tag_at(b).z)
	var placed: Array[Dictionary] = []
	for l: Dictionary in rows:
		# A caption whose node has been freed has no place left: it is dropped,
		# never hung at the world's origin.
		if l.has("node") and not is_instance_valid(l.get("node")):
			continue
		var at := _tag_at(l)
		if _cam.is_position_behind(at):
			continue
		var p := _cam.unproject_position(at)
		var text: String = l.name
		var w := UiFont.width(text)
		var box := Rect2i(roundi(p.x) - w / 2 - 3, roundi(p.y) - 5, w + 6, 11)
		var said := false
		for k in 5:
			var clash := {}
			for o: Dictionary in placed:
				if (o.box as Rect2i).intersects(box):
					clash = o
					break
			if clash.is_empty():
				break
			if String(clash.text).ends_with(text):
				said = true
				break
			box.position.y += 12
			said = k == 4
		if said:
			continue
		placed.append({"box": box, "text": text})
		UiDraw.rect(_tags, box, Color(UiTheme.GLASS, 0.82))
		UiDraw.frame(_tags, box, UiTheme.GHOST)
		UiDraw.text(_tags, Vector2i(box.position.x + 3, box.position.y), text, UiTheme.TEXT)


func _tag_at(l: Dictionary) -> Vector3:
	var n: Node3D = l.get("node")
	# A taken-over caption carries a node and no `at`: once it is freed there is
	# no place left to hang it, and asking for `at` was an error, not a fallback.
	return n.global_position if n != null and is_instance_valid(n) else (l.get("at", Vector3.ZERO) as Vector3)


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
