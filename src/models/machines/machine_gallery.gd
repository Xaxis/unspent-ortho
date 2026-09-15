extends RefCounted
## The machines' contribution to the gallery. Lives outside the MachineModel
## hierarchy because the gallery lists inherited static methods: a gallery() on
## the base class would run once per kind.
##
##   tools/shot.sh shots/machines/all.png --scene=gallery --filter=watcher
##   ... --filter=lineup --zoom=14          every kind beside a person, stand and alert rows
##   ... --filter=walk                      four gait phases per kind
##   ... --silhouette                       flat black bodies: the readability check
##   ... --filter=sheet_watcher --zoom=6     one kind: a person, stand, alert, windup, strike, dead
##   ... --filter=sheet_watcher_snow         the same on snow (lineup_snow for the lineup)

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk"]
const SHOWN: Array[StringName] = [&"stand", &"alert", &"windup", &"dead"]
## Room each kind needs across a review row, in tiles.
const WIDTHS := {&"watcher": 1.3, &"longlegs": 2.3, &"harvester": 3.0, &"cutter": 1.9, &"hauler": 2.6, &"warden": 1.3, &"sweeper": 1.6, &"dredger": 2.1, &"lineman": 1.4, &"flock": 1.9, &"runner": 1.0, &"clerk": 1.5}


static func gallery() -> Array:
	var args := OS.get_cmdline_user_args()
	var filter := ""
	for a in args:
		if a.begins_with("--filter="):
			filter = a.trim_prefix("--filter=")
	var silhouette := BootOptions.parse(args).silhouette
	var out: Array = []
	if filter.contains("lineup"):
		out.append({"name": filter, "node": lineup(silhouette, filter.contains("snow"))})
		return out
	if filter.begins_with("sheet_"):
		var kid := StringName(filter.trim_prefix("sheet_").trim_suffix("_snow"))
		if KINDS.has(kid):
			out.append({"name": filter, "node": sheet(kid, silhouette, filter.ends_with("_snow"))})
		return out
	for kid in KINDS:
		if filter.contains("walk"):
			for i in 4:
				var w := make(kid, &"walk", 0.25 * i)
				out.append({"name": "%s walk %d" % [kid, i], "node": _finish(w, silhouette)})
			continue
		for p in SHOWN:
			var item := _finish(make(kid, p), silhouette)
			var holder := Node3D.new()
			holder.add_child(item)
			_label_later(holder, "%s %s" % [kid, p], Vector3(0.7, 0.0, 0.7))
			out.append({"name": "%s %s" % [kid, p], "node": holder})
	return out.filter(func(it: Dictionary) -> bool: return String(it.name).contains(filter)) if filter != "" else out


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
static func lineup(silhouette: bool, snow: bool = false) -> Node3D:
	var holder := Node3D.new()
	var root := Node3D.new()
	var across := Vector3(1, 0, -1).normalized()
	var back := Vector3(-1, 0, -1).normalized()
	# The gallery aims at x=1.6 for a single item; centre both rows on that.
	root.position = Vector3(1.6, 0, 0) - back * 2.0
	holder.add_child(root)
	var ground := review_ground(Vector2(34, 10), silhouette, snow)
	ground.position = back * 2.0
	root.add_child(ground)
	var widths := WIDTHS
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
		person.position = across * (x + 0.5) + back * (row * 4.0)
		root.add_child(person)
		x += 1.0
		for kid in KINDS:
			var wdt: float = widths[kid]
			var m := make(kid, &"stand" if row == 0 else &"alert")
			m.position = across * (x + wdt * 0.5) + back * (row * 4.0)
			root.add_child(m)
			x += wdt
	if silhouette:
		for c in root.get_children():
			if c != ground:
				_blacken(c)
	return holder


## A strip of MADE ground under a review row: turf with the coast's wind hatch,
## snow with the snowfield's sparse hatch, or linen for black silhouettes.
static func review_ground(size: Vector2, silhouette: bool, snow: bool) -> MeshInstance3D:
	var g := MeshKit.new()
	var gc: Color = Palette.MOSS[3]
	g.style = Ink.WIND
	if snow:
		gc = Palette.LINEN[5]
		g.style = Ink.SPARSE
	if silhouette:
		gc = Palette.LINEN[4]
	g.style2 = g.style
	g.push(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.ZERO))
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	g.quad(Vector3(-hx, 0.004, -hz), Vector3(-hx, 0.004, hz), Vector3(hx, 0.004, hz), Vector3(hx, 0.004, -hz), gc)
	g.pop()
	var ground := MeshInstance3D.new()
	ground.name = "ground"
	ground.mesh = g.build()
	var gmat := ShaderMaterial.new()
	gmat.shader = preload("res://src/render/world.gdshader")
	ground.material_override = gmat
	return ground


## One kind across the screen: a person for scale, then every pose that
## changes the shape, each labelled. Centred where the gallery aims.
static func sheet(kid: StringName, silhouette: bool, snow: bool) -> Node3D:
	var holder := Node3D.new()
	var root := Node3D.new()
	var across := Vector3(1, 0, -1).normalized()
	root.position = Vector3(1.6, 0, 0)
	holder.add_child(root)
	var ground := review_ground(Vector2(30, 14), silhouette, snow)
	root.add_child(ground)
	var poses: Array[StringName] = [&"stand", &"walk", &"alert", &"windup", &"strike", &"dead"]
	var gap := maxf(float(WIDTHS[kid]) * 1.1, 1.5)
	var x := -gap * (poses.size() * 0.5)
	var person := PersonModel.new()
	var pmat := ShaderMaterial.new()
	pmat.shader = preload("res://src/render/world.gdshader")
	person.build(pmat)
	person.rotation.y = -PI * 0.25
	person.position = across * (x + gap * 0.3)
	root.add_child(person)
	for p in poses:
		x += gap
		var m := make(kid, p, 0.3)
		m.position = across * x
		root.add_child(m)
		_label_later(root, String(p), across * x + Vector3(0.6, 0.0, 0.6))
	if silhouette:
		for c in root.get_children():
			if c != ground and not c is Label3D:
				_blacken(c)
	return holder


## The gallery puts its world material on every geometry node it is handed,
## which blanks a Label3D; add labels once the row is in the tree instead.
static func _label_later(parent: Node3D, text: String, pos: Vector3) -> void:
	parent.ready.connect(func() -> void:
		var label := Label3D.new()
		label.text = text
		label.font_size = 18
		label.pixel_size = 0.009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Palette.INK[1]
		label.outline_size = 0
		label.no_depth_test = true
		# Drawn after the outline pass, which repaints the frame from a copy.
		label.render_priority = 20
		label.position = pos
		parent.add_child.call_deferred(label)
	, CONNECT_ONE_SHOT)


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
