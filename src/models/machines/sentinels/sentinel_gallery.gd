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
##
## A strike is drawn where its first phase's bite lands (MachineModel.
## strike_front), the landing part live, with a pale bar on the ground across
## the bite box's front and a post a person's height at each end of it: the
## frame shows the drawn blow against the hit.

## machine_gallery.gd has no class_name (the gallery lists inherited statics, so a
## base class must not carry one): it is reached by path.
const MG := preload("res://src/models/machines/machine_gallery.gd")

const KINDS: Array[StringName] = [&"sentinel_reaper", &"sentinel_rake", &"sentinel_plumb", &"sentinel_listener", &"sentinel_anvil", &"sentinel_unbuilder", &"sentinel_lockkeeper", &"sentinel_anchor", &"sentinel_plough", &"sentinel_drip_warden"]
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
			if p == &"strike":
				_strike_at_its_box(item, kid)
			if silhouette:
				_blacken(item)
			var holder := Node3D.new()
			holder.add_child(item)
			_label(holder, "%s %s" % [String(kid).trim_prefix("sentinel_"), p], Vector3(1.1, 0.0, 1.1))
			out.append({"name": "%s %s" % [kid, p], "node": holder})
	return out


## Pose `m`'s strike onto its keeper's first-phase bite box, and lay the box's
## front on the ground in front of it.
static func _strike_at_its_box(m: FigureModel, kid: StringName) -> void:
	var mm := m as MachineModel
	if mm == null:
		return
	for def: SentinelDef in Sentinels.all():
		var row := Roster.row(def.kind)
		if row.get("model", &"") != kid:
			continue
		mm.strike_front = float(row.get("radius", 0.5)) + float(def.phase(0).bite.get("reach", 0.6))
		mm.blow_live = true
		mm.settle()
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.02, 1.6) / mm.scale.x
		bar.mesh = box
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Palette.LINEN[5]
		bar.material_override = mat
		bar.position = Vector3(mm.strike_reach(), 0.01, 0.0)
		mm.add_child(bar)
		# A post at each end, a person's height (the hit band's top, 1.8): what
		# the strike reaches is read against them, at the height it reaches.
		for side: float in [-0.8, 0.8]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.04, 1.8, 0.04) / mm.scale.x
			post.mesh = pm
			post.material_override = mat
			post.position = Vector3(mm.strike_reach(), 0.9 / mm.scale.x, side / mm.scale.x)
			mm.add_child(post)
		return


## Both keepers, a harvester and a person on one strip of ground: the only frame
## that answers what a sentinel IS, which is a question about scale.
static func beside(silhouette: bool) -> Node3D:
	var holder := Node3D.new()
	var root := Node3D.new()
	var across := Vector3(1, 0, -1).normalized()
	root.position = Vector3(1.6, 0, 0)
	holder.add_child(root)
	var ground: MeshInstance3D = MG.review_ground(Vector2(46, 12), silhouette, false)
	root.add_child(ground)
	var person := PersonModel.new()
	var pmat := ShaderMaterial.new()
	pmat.shader = preload("res://src/render/world.gdshader")
	person.build(pmat)
	person.rotation.y = -PI * 0.25
	person.position = across * -5.6
	root.add_child(person)
	var x := -21.0
	for kid: StringName in [&"harvester", &"sentinel_reaper", &"sentinel_rake", &"sentinel_plumb", &"sentinel_listener", &"sentinel_anvil", &"sentinel_unbuilder", &"sentinel_lockkeeper", &"sentinel_anchor"]:
		var m: FigureModel = MG.make(kid, &"alert")
		m.position = across * x
		root.add_child(m)
		# The gantry straddles a street: it wants the width of one to stand in,
		# the barge after it splays its stilts nearly four units wide, and the
		# anchor's hooks splay four across.
		x += 6.2 if kid == &"sentinel_anvil" or kid == &"sentinel_unbuilder" else 4.4
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
