extends RefCounted
## The machines' contribution to the gallery. Lives outside the MachineModel
## hierarchy because the gallery lists inherited static methods: a gallery() on
## the base class would run once per kind.
##
##   tools/shot.sh shots/machines/all.png --scene=gallery --filter=watcher
##   ... --filter=lineup --zoom=14          every kind beside a person, stand and alert rows
##   ... --filter=lineup_dead --zoom=14     the back row in another pose (windup, strike, dead, walk, hurt)
##   ... --filter=walk                      four gait phases per kind
##   ... --silhouette                       flat black bodies: the readability check
##   ... --filter=sheet_watcher --zoom=6     one kind: a person, stand, alert, windup, strike, dead
##   ... --filter=sheet_watcher_snow         the same on snow (lineup_snow for the lineup)
##   ... --filter=gait_watcher               six phases of one stride
##   ... --filter=terrace --zoom=10 --hour=23  watchers and harvesters throwing their
##                                          light into a raised step and over a ledge
##   ... --filter=disposed_harvester --zoom=15 --hour=12  ONE kind standing at each of
##                                          the four dispositions, same light, same
##                                          ground: what a player has to tell apart
##                                          across a field. Shoot it at noon and at
##                                          23 and hold the two side by side.
##   ... --filter=disposed_harvester_hostile              one of them alone, which
##                                          is the frame to count lit pixels in --
##                                          but NOT unlabelled, whatever this said:
##                                          the gallery draws the item's name tag
##                                          across the model unless the frame is
##                                          aimed (`--piece`, gallery.gd `named`),
##                                          so count inside the model's own box or
##                                          crop round the tag.

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
		var back_pose := &"alert"
		for bp: StringName in [&"windup", &"strike", &"dead", &"walk", &"hurt"]:
			if filter.contains(String(bp)):
				back_pose = bp
		out.append({"name": filter, "node": lineup(silhouette, filter.contains("snow"), back_pose)})
		return out
	if filter == "terrace":
		out.append({"name": filter, "node": terrace()})
		return out
	if filter.begins_with("disposed"):
		var rest := filter.trim_prefix("disposed_").split("_", false)
		var did: StringName = StringName(rest[0]) if rest.size() > 0 else &"harvester"
		var only: StringName = StringName(rest[1]) if rest.size() > 1 else &""
		out.append({"name": filter, "node": disposed(did if KINDS.has(did) else &"harvester", silhouette, only)})
		return out
	if filter.begins_with("sheet_") or filter.begins_with("gait_"):
		var kid := StringName(filter.trim_prefix("sheet_").trim_prefix("gait_").trim_suffix("_snow"))
		if KINDS.has(kid):
			out.append({"name": filter, "node": sheet(kid, silhouette, filter.ends_with("_snow"), filter.begins_with("gait_"))})
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
static func lineup(silhouette: bool, snow: bool = false, back_pose: StringName = &"alert") -> Node3D:
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
			var m := make(kid, &"stand" if row == 0 else back_pose, 0.3)
			m.position = across * (x + wdt * 0.5) + back * (row * 4.0)
			root.add_child(m)
			x += wdt
	if silhouette:
		for c in root.get_children():
			if c != ground:
				_blacken(c)
	return holder


## One kind, standing, at each of the four dispositions in the order of the
## ladder, on one strip of ground under one sky: the review surface for the read
## a player has to make of a machine across a field. Every cell is the same
## body, so anything that differs between them IS the disposition.
##
## Name one disposition (`disposed_runner_hostile`) and it stands alone, centred,
## with no label beside it. That is the frame to COUNT: four bodies in a row
## cannot be told apart by a script without guessing where one cell ends, and a
## measurement that has to guess is how a ladder that only reads on three kinds
## came to be reported as a ladder.
static func disposed(kid: StringName, silhouette: bool, only: StringName = &"") -> Node3D:
	var holder := Node3D.new()
	var root := Node3D.new()
	var across := Vector3(1, 0, -1).normalized()
	root.position = Vector3(1.6, 0, 0)
	holder.add_child(root)
	root.add_child(review_ground(Vector2(26, 10), silhouette, false))
	var shown: Array[StringName] = []
	if Disposition.ORDER.has(only):
		shown.append(only)
	else:
		shown.append_array(Disposition.ORDER)
	var gap := maxf(float(WIDTHS[kid]) * 1.25, 1.8)
	var x := -gap * (shown.size() - 1) * 0.5
	for d: StringName in shown:
		var m := FigureModel.create(kid) as MachineModel
		m.rotation.y = gallery_yaw(m.part_side, m.gallery_turn)
		m.disposition = d
		m.set_pose(&"stand")
		m.settle()
		m.position = across * x
		root.add_child(m)
		if shown.size() > 1:
			_label_later(root, String(d), across * x + Vector3(0.6, 0.0, 0.6))
		x += gap
	if silhouette:
		for c in root.get_children():
			if c.name != &"ground" and not c is Label3D:
				_blacken(c)
	return holder


## Three terrace levels a step apart across X (raised to the west, lowered to
## the east, the walls facing the camera), with a watcher and a harvester on
## the middle level turned toward each edge: a beam must land on the step's
## wall and stop at the ledge, never hang in the air or show inside the step.
static func terrace() -> Node3D:
	var holder := Node3D.new()
	var root := Node3D.new()
	root.position = Vector3(1.6, 0, 0)
	holder.add_child(root)
	var step := WorldData.STEP
	# The raised step is nearer: a harvester's wash starts well out past its comb.
	var west := -2.0
	var edge := 2.4
	var g := MeshKit.new()
	g.style = Ink.WIND
	g.style2 = g.style
	var tops := [[-7.0, west, step * 2.0], [west, edge, step], [edge, 7.0, 0.004]]
	for t: Array in tops:
		var x0: float = t[0]
		var x1: float = t[1]
		var y: float = t[2]
		g.quad(Vector3(x0, y, -6.5), Vector3(x0, y, 6.5), Vector3(x1, y, 6.5), Vector3(x1, y, -6.5), Palette.MOSS[3])
	g.style = Ink.NONE
	g.style2 = g.style
	for w: Array in [[west, step, step * 2.0], [edge, 0.004, step]]:
		var x: float = w[0]
		var y0: float = w[1]
		var y1: float = w[2]
		g.quad(Vector3(x, y1, 6.5), Vector3(x, y0, 6.5), Vector3(x, y0, -6.5), Vector3(x, y1, -6.5), Palette.STONE[2])
	var ground := MeshInstance3D.new()
	ground.name = "ground"
	ground.mesh = g.build()
	var gmat := ShaderMaterial.new()
	gmat.shader = preload("res://src/render/world.gdshader")
	ground.material_override = gmat
	root.add_child(ground)
	# [kind, x, z, facing]: each looks at the nearer edge.
	for spot: Array in [[&"watcher", -0.6, -3.6, PI], [&"watcher", 1.2, -1.2, 0.0], [&"harvester", 0.0, 1.6, PI], [&"harvester", 0.2, 4.8, 0.0]]:
		var m := FigureModel.create(spot[0])
		m.position = Vector3(float(spot[1]), step, float(spot[2]))
		m.rotation.y = -float(spot[3])
		m.set_pose(&"stand")
		root.add_child(m)
		(m as MachineModel).settle()
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
static func sheet(kid: StringName, silhouette: bool, snow: bool, gait: bool = false) -> Node3D:
	var holder := Node3D.new()
	var root := Node3D.new()
	var across := Vector3(1, 0, -1).normalized()
	root.position = Vector3(1.6, 0, 0)
	holder.add_child(root)
	var ground := review_ground(Vector2(30, 14), silhouette, snow)
	root.add_child(ground)
	var poses: Array[StringName] = [&"stand", &"walk", &"alert", &"windup", &"strike", &"dead"]
	var gap := maxf(float(WIDTHS[kid]) * 1.1, 1.5)
	# The person stands 0.3 of a gap before the first pose: centre the whole row.
	var x := -gap * (poses.size() + 0.3) * 0.5
	var person := PersonModel.new()
	var pmat := ShaderMaterial.new()
	pmat.shader = preload("res://src/render/world.gdshader")
	person.build(pmat)
	person.rotation.y = -PI * 0.25
	person.position = across * (x + gap * 0.3)
	root.add_child(person)
	for i in poses.size():
		x += gap
		var p := poses[i]
		var phase := 0.3
		var label := String(p)
		if gait:
			p = &"walk"
			phase = i / float(poses.size())
			label = "walk %d/%d" % [i, poses.size()]
		var m := make(kid, p, phase)
		m.position = across * x
		root.add_child(m)
		_label_later(root, label, across * x + Vector3(0.6, 0.0, 0.6))
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
	if n.name == &"glow" or n.name == &"beam":
		(n as Node3D).visible = false
	elif n is GeometryInstance3D:
		(n as GeometryInstance3D).material_override = black
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_blacken_with(c, black)
