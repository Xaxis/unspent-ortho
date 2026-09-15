extends RefCounted
## The machines' contribution to the gallery. Lives outside the MachineModel
## hierarchy because the gallery lists inherited static methods: a gallery() on
## the base class would run once per kind.
##
##   tools/shot.sh shots/machines/all.png --scene=gallery --filter=watcher
##   ... --filter=lineup --zoom=14          every kind beside a person, stand and alert rows
##   ... --filter=walk                      four gait phases per kind
##   ... --silhouette                       flat black bodies: the readability check

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk"]
const SHOWN: Array[StringName] = [&"stand", &"alert", &"windup", &"dead"]


static func gallery() -> Array:
	var args := OS.get_cmdline_user_args()
	var filter := ""
	for a in args:
		if a.begins_with("--filter="):
			filter = a.trim_prefix("--filter=")
	var silhouette := BootOptions.parse(args).silhouette
	var out: Array = []
	if filter.contains("lineup"):
		out.append({"name": "lineup", "node": lineup(silhouette)})
		return out
	for kid in KINDS:
		if filter.contains("walk"):
			for i in 4:
				var w := make(kid, &"walk", 0.25 * i)
				out.append({"name": "%s walk %d" % [kid, i], "node": _finish(w, silhouette)})
			continue
		for p in SHOWN:
			out.append({"name": "%s %s" % [kid, p], "node": _finish(make(kid, p), silhouette)})
	var matching := out.filter(func(it: Dictionary) -> bool: return String(it.name).contains(filter))
	if matching.size() == 1:
		var only: Dictionary = matching[0]
		only.node = _centred(only.node, 2.0)
	return matching if filter != "" else out


## The gallery aims at the middle of a two-column grid, not at a lone item:
## shift a single close-up so the camera's aim falls on the machine's middle.
static func _centred(n: Node3D, grid_cols: int) -> Node3D:
	var holder := Node3D.new()
	var mid_h := 0.5
	if n is FigureModel:
		mid_h = (n as FigureModel).height * 0.5
	var toward_camera := Vector3(1, 0, 1).normalized()
	n.position = Vector3(1.6 * (grid_cols - 1), 0, 0) + toward_camera * mid_h / tan(deg_to_rad(57.0))
	holder.add_child(n)
	return holder


## A machine in a settled pose, turned so its working part shows three-quarters
## to the camera. `phase` is the gait phase for walk.
static func make(kid: StringName, p: StringName, phase: float = 0.0) -> FigureModel:
	var m := FigureModel.create(kid)
	var turn := (m as MachineModel).gallery_turn if m is MachineModel else 30.0
	m.rotation.y = gallery_yaw(m.part_side, turn)
	if m is MachineModel:
		var mm := m as MachineModel
		mm.set_pose(p)
		if p == &"walk":
			mm.gait = phase
			mm.walk_w = 1.0
		mm.settle()
	else:
		m.set_pose(p)
	return m


## Yaw that turns the part's side `turn` degrees off straight-at-the-camera.
static func gallery_yaw(side: StringName, turn: float = 30.0) -> float:
	var n := MachineModel.side_normal(side)
	if n == Vector3.ZERO:
		n = Vector3.RIGHT
	var target := -PI * 0.25 + deg_to_rad(turn)
	return target - atan2(-n.z, n.x)


## Every kind in a row across the screen beside a person, stand in front and
## alert behind: scale and silhouette at gameplay zoom (--zoom=14).
static func lineup(silhouette: bool) -> Node3D:
	var holder := Node3D.new()
	var root := Node3D.new()
	var across := Vector3(1, 0, -1).normalized()
	var back := Vector3(-1, 0, -1).normalized()
	# The gallery aims at x=1.6 for a single item; centre both rows on that.
	root.position = Vector3(1.6, 0, 0) - back * 1.6
	holder.add_child(root)
	# Its own ground, pale for the silhouette check so black shapes stand out.
	var g := MeshKit.new()
	var gc: Color = Palette.LINEN[4] if silhouette else Palette.MOSS[2]
	g.push(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.ZERO))
	g.box(Vector3(-15, -0.02, -4.5), Vector3(15, 0.006, 4.5), gc, gc)
	g.pop()
	var ground := MeshInstance3D.new()
	ground.mesh = g.build()
	var gmat := ShaderMaterial.new()
	gmat.shader = preload("res://src/render/world.gdshader")
	ground.material_override = gmat
	ground.position = back * 1.6
	root.add_child(ground)
	var widths := {&"watcher": 1.2, &"longlegs": 1.9, &"harvester": 2.9, &"cutter": 1.6, &"hauler": 2.2, &"warden": 1.3, &"sweeper": 1.4, &"dredger": 2.0, &"lineman": 1.3, &"flock": 1.9, &"runner": 1.0, &"clerk": 1.3}
	var total := 1.0
	for kid in KINDS:
		total += float(widths[kid])
	for row in 2:
		var x := -total * 0.5
		var person := PersonModel.new()
		var pmat := ShaderMaterial.new()
		pmat.shader = preload("res://src/render/world.gdshader")
		person.build(pmat)
		person.rotation.y = -PI * 0.25
		person.position = across * (x + 0.5) + back * (row * 3.2)
		root.add_child(person)
		x += 1.0
		for kid in KINDS:
			var wdt: float = widths[kid]
			var m := make(kid, &"stand" if row == 0 else &"alert")
			m.position = across * (x + wdt * 0.5) + back * (row * 3.2)
			root.add_child(m)
			x += wdt
	if silhouette:
		for c in root.get_children():
			if c != ground:
				_blacken(c)
	return holder


static func _finish(n: Node3D, silhouette: bool) -> Node3D:
	if silhouette:
		_blacken(n)
	return n


## Flat black, no glow, no shadow: what the shape alone says.
static func _blacken(n: Node) -> void:
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	_blacken_with(n, black)


static func _blacken_with(n: Node, black: Material) -> void:
	if n.name == &"glow":
		(n as Node3D).visible = false
	elif n is GeometryInstance3D:
		(n as GeometryInstance3D).material_override = black
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_blacken_with(c, black)
