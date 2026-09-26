extends TestCase
## Every settled pose keeps a machine in the world it stands in: nothing below
## the ground it walks on, nothing flung out past its footprint. A broken dead
## pose (legs through the ground, arms thrown out into a bar) fails here first.
##
## Measured on the real meshes in model space, hidden nodes and halos skipped.

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk", &"sorter"]
const MG := preload("res://src/models/machines/machine_gallery.gd")
const GROUND := -0.05
## Radius a kind may reach from its origin, as a multiple of the room it gets
## in a review row (machine_gallery.gd WIDTHS, a width, so 0.5 would be touching
## its neighbour). A windup or strike is a lunge and may reach a quarter further.
const REACH := 1.0
const LUNGE := 1.25


## Vector3(min y, max y, max horizontal radius) over every visible vertex.
static func extent(m: FigureModel) -> Vector3:
	var out := Vector3(INF, -INF, 0.0)
	return _extent_node(m, m, Transform3D.IDENTITY, out)


static func _extent_node(root: FigureModel, n: Node, xf: Transform3D, out: Vector3) -> Vector3:
	if n != root and n is Node3D:
		if not (n as Node3D).visible or n.name == &"glow" or n.name == &"beam":
			return out
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).skin != null and root is MachineModel:
		out = _extent_points((root as MachineModel).posed_triangles(n as MeshInstance3D), xf, out)
	elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = _extent_mesh((n as MeshInstance3D).mesh, xf, out)
	elif n is MultiMeshInstance3D:
		var mm := (n as MultiMeshInstance3D).multimesh
		var xforms: Variant = root.get("shard_xforms")
		for i in mm.instance_count:
			var ixf: Transform3D = (xforms as Array)[i] if xforms is Array and i < (xforms as Array).size() else mm.get_instance_transform(i)
			out = _extent_mesh(mm.mesh, xf * ixf, out)
	for c in n.get_children():
		out = _extent_node(root, c, xf, out)
	return out


static func _extent_mesh(mesh: Mesh, xf: Transform3D, out: Vector3) -> Vector3:
	return _extent_points(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array, xf, out)


static func _extent_points(verts: PackedVector3Array, xf: Transform3D, out: Vector3) -> Vector3:
	for v in verts:
		var p := xf * v
		out.x = minf(out.x, p.y)
		out.y = maxf(out.y, p.y)
		out.z = maxf(out.z, Vector2(p.x, p.z).length())
	return out


static func settled(kid: StringName) -> Array:
	var shown: Array = []
	for p: StringName in MachineModel.POSES:
		if p == &"walk":
			for i in 4:
				shown.append([p, i / 4.0])
		else:
			shown.append([p, 0.0])
	return shown


func test_no_pose_goes_through_the_ground_or_past_its_footprint() -> void:
	for kid in KINDS:
		for pp: Array in settled(kid):
			var lunge: bool = pp[0] == &"windup" or pp[0] == &"strike"
			var reach := float(MG.WIDTHS[kid]) * (LUNGE if lunge else REACH)
			var m := FigureModel.create(kid) as MachineModel
			m.set_pose(pp[0])
			if pp[0] == &"walk":
				m.walk_w = 1.0
				m.gait = pp[1]
			m.settle()
			var e := extent(m)
			m.free()
			var label := "%s %s" % [kid, pp[0]]
			gt(e.x, GROUND, "%s lowest point" % label)
			lt(e.z, reach, "%s reach" % label)


func test_dead_lies_lower_than_it_stands() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		m.settle()
		var standing := extent(m)
		m.set_pose(&"dead")
		m.settle()
		var dead := extent(m)
		m.free()
		# Tall things come down by a fifth at least; a slab that was already low
		# still settles by a visible two pixels (0.08 u at gameplay zoom).
		lt(dead.y, maxf(standing.y * 0.8, standing.y - 0.08), "%s dead top vs standing top %.2f" % [kid, standing.y])


func test_a_dead_lineman_lies_with_its_arms_along_it() -> void:
	var m := FigureModel.create(&"lineman") as MachineModel
	m.set_pose(&"dead")
	m.settle()
	var e := extent(m)
	m.free()
	lt(e.y, 0.55, "dead lineman top")
	lt(e.z, 1.0, "dead lineman reach")


## A mark over a machine (the windup tell) stands on the top of the body as it
## is posed now, not on the rest rig: a mast run up, a blade lifted count, and
## a spill that only exists once it is dead does not.
func test_the_top_of_the_body_follows_the_pose() -> void:
	var up := Basis.from_euler(Vector3(deg_to_rad(-57.0), deg_to_rad(45.0), 0.0)).y
	var worst_slack := 0.0
	for kid in KINDS:
		if kid == &"flock":
			continue
		var m := FigureModel.create(kid) as MachineModel
		for turn in 4:
			m.rotation.y = turn * TAU / 4.0 + 0.3
			for p: StringName in [&"stand", &"alert", &"windup", &"strike"]:
				m.set_pose(p)
				m.settle()
				var drawn := -INF
				for s: StringName in m.surfaces:
					for v in m.posed_triangles(m.surfaces[s]):
						drawn = maxf(drawn, (m.transform * v).dot(up))
				var top := m.top_toward(up).dot(up)
				gt(top, drawn - 1e-3, "%s %s: the top is never under the drawn body" % [kid, p])
				worst_slack = maxf(worst_slack, top - drawn)
		m.free()
	# A box round each part overshoots at its corners (a chamfered hull, an oval
	# carapace) by no more than half a unit: a dozen pixels at gameplay zoom.
	lt(worst_slack, 0.5, "and never far over it (%.2f)" % worst_slack)
	# The rest rig's mesh bounds carry no spill while the machine lives.
	var h := FigureModel.create(&"harvester") as MachineModel
	var matter: MeshInstance3D = h.surfaces[&"matter"]
	# The bar is where the COMB is, and the comb moved: the header is carried out
	# in front of the hull on a feeder throat now, so that daylight stands either
	# side of it and the machine is not one plate from the front. The rule is
	# unchanged — the rest rig's matter stops at the comb and the spilled row is
	# the dead node's alone.
	lt(matter.mesh.get_aabb().end.x, 2.2, "a living harvester's matter ends at its comb")
	h.set_pose(&"dead")
	gt(matter.mesh.get_aabb().end.x, 2.2, "dead, the row it cut spills out past it")
	h.set_pose(&"stand")
	lt(matter.mesh.get_aabb().end.x, 2.2, "and a machine stood back up carries none")
	h.free()
