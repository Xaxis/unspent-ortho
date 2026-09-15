extends TestCase
## Readability gates from art-audio-extract §8, measured the way the player sees
## them: each machine is rasterised flat black through the game camera at
## gameplay texel size, and silhouettes are compared cell by cell.
##
##   alert changes the silhouette more than any walk pose does
##   every machine is visibly bigger than nothing and fits its footprint

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk"]
## One screen pixel at the game's default view height (14 units over 360 px).
const TEXEL := 14.0 / 360.0
const W := 160
const H := 130
const YAW := 0.6


static func camera_axes() -> Array[Vector3]:
	var b := Basis.from_euler(Vector3(deg_to_rad(-57.0), deg_to_rad(45.0), 0.0))
	return [b.x, b.y]


## A W x H mask of the figure as drawn from the game camera.
static func silhouette(m: FigureModel, yaw: float = YAW) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(W * H)
	var axes := camera_axes()
	_raster_node(m, m, Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO), axes[0], axes[1], mask)
	return mask


static func _raster_node(root: FigureModel, n: Node, xf: Transform3D, right: Vector3, up: Vector3, mask: PackedByteArray) -> void:
	if n is Node3D and n != root:
		if not (n as Node3D).visible or n.name == &"glow":
			return
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		_raster_mesh((n as MeshInstance3D).mesh, xf, right, up, mask)
	elif n is MultiMeshInstance3D:
		# Headless runs keep no MultiMesh transforms; the flock keeps its own.
		var mm := (n as MultiMeshInstance3D).multimesh
		var xforms: Variant = root.get("shard_xforms")
		for i in mm.instance_count:
			var ixf: Transform3D = (xforms as Array)[i] if xforms is Array and i < (xforms as Array).size() else mm.get_instance_transform(i)
			_raster_mesh(mm.mesh, xf * ixf, right, up, mask)
	for c in n.get_children():
		_raster_node(root, c, xf, right, up, mask)


static func _raster_mesh(mesh: Mesh, xf: Transform3D, right: Vector3, up: Vector3, mask: PackedByteArray) -> void:
	var verts := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var pts := PackedVector2Array()
	pts.resize(verts.size())
	for i in verts.size():
		var p := xf * verts[i]
		pts[i] = Vector2(p.dot(right) / TEXEL + W * 0.5, H * 0.75 - p.dot(up) / TEXEL)
	for t in range(0, pts.size(), 3):
		var a := pts[t]
		var b := pts[t + 1]
		var c := pts[t + 2]
		var x0 := maxi(0, floori(minf(a.x, minf(b.x, c.x))))
		var x1 := mini(W - 1, ceili(maxf(a.x, maxf(b.x, c.x))))
		var y0 := maxi(0, floori(minf(a.y, minf(b.y, c.y))))
		var y1 := mini(H - 1, ceili(maxf(a.y, maxf(b.y, c.y))))
		var area := (b - a).cross(c - a)
		if absf(area) < 1e-6:
			continue
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var q := Vector2(x + 0.5, y + 0.5)
				var w0 := (b - a).cross(q - a) / area
				var w1 := (c - b).cross(q - b) / area
				var w2 := (a - c).cross(q - c) / area
				if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
					mask[y * W + x] = 1


static func count(mask: PackedByteArray) -> int:
	var total := 0
	for v in mask:
		total += v
	return total


static func diff(a: PackedByteArray, b: PackedByteArray) -> int:
	var total := 0
	for i in a.size():
		if a[i] != b[i]:
			total += 1
	return total


static func posed(kid: StringName, p: StringName, phase: float = 0.0) -> FigureModel:
	var m := FigureModel.create(kid) as MachineModel
	m.set_pose(p)
	if p == &"walk":
		m.walk_w = 1.0
		m.gait = phase
	m.settle()
	return m


func test_alert_changes_the_silhouette_more_than_any_walk_pose() -> void:
	# Seen from the side-ish and from the front-ish: the gate must hold both ways.
	for yaw: float in [0.6, 2.3]:
		for kid in KINDS:
			var stand := posed(kid, &"stand")
			var base := silhouette(stand, yaw)
			stand.free()
			var alert := posed(kid, &"alert")
			var alert_change := diff(base, silhouette(alert, yaw))
			alert.free()
			var walk_change := 0
			for i in 8:
				var w := posed(kid, &"walk", i / 8.0)
				walk_change = maxi(walk_change, diff(base, silhouette(w, yaw)))
				w.free()
			gt(float(alert_change), float(walk_change), "%s yaw %.1f: alert (%d px) vs walk (%d px)" % [kid, yaw, alert_change, walk_change])


func test_every_machine_reads_at_gameplay_zoom() -> void:
	for kid in KINDS:
		var m := posed(kid, &"stand")
		var px := count(silhouette(m))
		m.free()
		# A person is roughly 20 x 8 screen pixels; nothing here should vanish.
		gt(float(px), 80.0, "%s covers %d px" % [kid, px])
		lt(float(px), W * H * 0.5, "%s covers %d px" % [kid, px])
