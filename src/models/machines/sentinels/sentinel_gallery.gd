extends RefCounted
## The sentinels' contribution to the gallery (src/gallery.gd finds any script
## under src/models with a `gallery()`). They are not in `MachineGallery.KINDS`
## because a keeper is not one of the twelve: it is the grandest FOUND drawing in
## the game and wants its own review surface, at its own scale.
##
##   tools/shot.sh shots/x.png --scene=gallery --filter=sentinel
##   ... --filter=sentinel_reaper            one keeper, every pose that changes its shape
##   ... --filter=sentinel_reaper --silhouette   what the shape alone says
##   ... --filter=sentinel_beside            both keepers beside a person and a harvester,
##                                           which is the only frame that answers "how big"
##   ... --zoom=14                           the zoom players actually have

## machine_gallery.gd has no class_name (the gallery lists inherited statics, so a
## base class must not carry one): it is reached by path.
const MG := preload("res://src/models/machines/machine_gallery.gd")

const KINDS: Array[StringName] = [&"sentinel_reaper", &"sentinel_rake"]
const SHOWN: Array[StringName] = [&"stand", &"walk", &"alert", &"windup", &"strike", &"dead"]


static func gallery() -> Array:
	var args := OS.get_cmdline_user_args()
	var filter := ""
	for a in args:
		if a.begins_with("--filter="):
			filter = a.trim_prefix("--filter=")
	var silhouette := BootOptions.parse(args).silhouette
	var out: Array = []
	if filter.contains("beside"):
		out.append({"name": "sentinel_beside", "node": beside(silhouette)})
		return out
	# Every pose that changes the shape, for both keepers. The gallery's own
	# `--filter` cuts this list down by name, so nothing needs deciding here.
	for kid in KINDS:
		for p in SHOWN:
			var item: FigureModel = MG.make(kid, p, 0.3)
			if silhouette:
				_blacken(item)
			var holder := Node3D.new()
			holder.add_child(item)
			_label(holder, "%s %s" % [String(kid).trim_prefix("sentinel_"), p], Vector3(1.1, 0.0, 1.1))
			out.append({"name": "%s %s" % [kid, p], "node": holder})
	return out


## Both keepers, a harvester and a person on one strip of ground: the only frame
## that answers what a sentinel IS, which is a question about scale.
static func beside(silhouette: bool) -> Node3D:
	var holder := Node3D.new()
	var root := Node3D.new()
	var across := Vector3(1, 0, -1).normalized()
	root.position = Vector3(1.6, 0, 0)
	holder.add_child(root)
	var ground: MeshInstance3D = MG.review_ground(Vector2(30, 12), silhouette, false)
	root.add_child(ground)
	var person := PersonModel.new()
	var pmat := ShaderMaterial.new()
	pmat.shader = preload("res://src/render/world.gdshader")
	person.build(pmat)
	person.rotation.y = -PI * 0.25
	person.position = across * -5.6
	root.add_child(person)
	var x := -4.2
	for kid: StringName in [&"harvester", &"sentinel_reaper", &"sentinel_rake"]:
		var m: FigureModel = MG.make(kid, &"alert")
		m.position = across * x
		root.add_child(m)
		x += 4.4
	if silhouette:
		for c in root.get_children():
			if c != ground:
				_blacken(c)
	return holder


static func _label(parent: Node3D, text: String, pos: Vector3) -> void:
	parent.ready.connect(func() -> void:
		var label := Label3D.new()
		label.text = text
		label.font_size = 18
		label.pixel_size = 0.009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Palette.INK[1]
		label.outline_size = 0
		label.no_depth_test = true
		label.render_priority = 20
		label.position = pos
		parent.add_child.call_deferred(label)
	, CONNECT_ONE_SHOT)


static func _blacken(n: Node) -> void:
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	_blacken_with(n, black)


static func _blacken_with(n: Node, black: Material) -> void:
	if n.name == &"glow" or n.name == &"beam":
		(n as Node3D).visible = false
	elif n is GeometryInstance3D:
		(n as GeometryInstance3D).material_override = black
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_blacken_with(c, black)
