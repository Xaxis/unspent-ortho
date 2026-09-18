extends TestCase
## Readability gates from art-audio-extract §8, measured the way the player sees
## them: each machine is rasterised flat black through the game camera at
## gameplay texel size, and silhouettes are compared cell by cell.
##
##   alert and dead change the silhouette more than any walk pose does
##   every pose a player must read in a fight differs from every other in SHAPE
##   every machine is visibly bigger than nothing and fits its footprint

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk"]
## One CELL of this raster, in world units — a fixed number of pixels of the
## frame at the camera players get, asked of the rig and the base rather than
## written down again (docs/LOOK.md).
##
## It read `14.0 / 360.0` for two waves after LANTERN's floor took the base to
## 1080 rows, against a rig whose view height has never been 14: so every count
## below was in cells that nothing in the repository could name. 2.8 is what
## leaves the raster exactly where these gates were calibrated (3 for the rows,
## times 14/15 for the view height that was never right), and the cell is
## deliberately COARSER than a frame pixel — that is what keeps a whole roster
## affordable, and it is conservative, since detail that survives a coarse raster
## survives the frame. W and H are the raster's size in cells and every threshold
## below counts in them, so the cell and the thresholds can only move together.
const CELL := 2.8
static var TEXEL := CameraRig.VIEW_HEIGHT / float(UiBase.SIZE.y) * CELL
const W := 160
const H := 130
const YAW := 0.6
## The poses a fight asks a player to tell apart at a glance.
const READ_POSES: Array[StringName] = [&"stand", &"alert", &"windup", &"strike", &"dead"]
const MIN_FRACTION := 0.085
const MIN_EDGE_PX := 3.0


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
		if not (n as Node3D).visible or n.name == &"glow" or n.name == &"beam":
			return
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).skin != null and root is MachineModel:
		_raster_tris((root as MachineModel).posed_triangles(n as MeshInstance3D), xf, right, up, mask)
	elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
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
	_raster_tris(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array, xf, right, up, mask)


## Triangles (three points each) through `xf` into the mask.
static func _raster_tris(verts: PackedVector3Array, xf: Transform3D, right: Vector3, up: Vector3, mask: PackedByteArray) -> void:
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


func test_alert_and_dead_change_the_silhouette_more_than_any_walk_pose() -> void:
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
			# A dead machine must be told from a live one at a glance, too.
			var dead := posed(kid, &"dead")
			var dead_change := diff(base, silhouette(dead, yaw))
			dead.free()
			gt(float(dead_change), float(walk_change), "%s yaw %.1f: dead (%d px) vs walk (%d px)" % [kid, yaw, dead_change, walk_change])


## The poses a player has to tell apart in a fight, told apart by SHAPE. A machine
## that changes only what is lit says nothing at noon, which is how the harvester
## came to have four poses that differed by a glow and by nothing else.
##
## Two gates, because one is not enough for a set that runs from a flock of shards
## to a two-and-a-half-tile slab: the change must be at least a twelfth of the
## body's own area (a small machine has to move a lot of itself) AND at least
## three raster cells of outline travel, about eight frame pixels (a big one
## must not hide its poses inside
## its own bulk — the harvester used to manage only 0.063 of itself).
func test_the_poses_a_player_reads_differ_in_silhouette() -> void:
	for kid in KINDS:
		for yaw: float in [0.6, 2.3]:
			var masks := {}
			var area := 0.0
			for p in READ_POSES:
				var m := posed(kid, p)
				masks[p] = silhouette(m, yaw)
				area = maxf(area, float(count(masks[p])))
				m.free()
			gt(area, 80.0, "%s covers something at yaw %.1f" % [kid, yaw])
			for i in READ_POSES.size():
				for j in range(i + 1, READ_POSES.size()):
					var n := float(diff(masks[READ_POSES[i]], masks[READ_POSES[j]]))
					var label := "%s yaw %.1f %s/%s" % [kid, yaw, READ_POSES[i], READ_POSES[j]]
					gt(n / area, MIN_FRACTION, "%s: %.3f of the body (%d px)" % [label, n / area, int(n)])
					gt(n / sqrt(area), MIN_EDGE_PX, "%s: %.1f px of outline" % [label, n / sqrt(area)])


## What share of its own bounding box a silhouette actually fills. A box on a box
## fills nearly all of it; a shape a player can name leaves daylight inside its
## own box — a leg, a mast, an arm out, a notch under a cap.
static func fill(mask: PackedByteArray) -> float:
	var x0 := W
	var x1 := -1
	var y0 := H
	var y1 := -1
	var n := 0
	for y in H:
		for x in W:
			if mask[y * W + x] == 0:
				continue
			n += 1
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
	if x1 < 0:
		return 1.0
	return float(n) / float((x1 - x0 + 1) * (y1 - y0 + 1))


## No machine is a filled rectangle. This is the rule the art review caught the
## harvester breaking: a slab on tracks under a low housing, seen from a camera
## that never moves, filled 0.73/0.72 of its box at one yaw and 0.73/0.77 at the
## other, so four poses of it were four identical black lozenges and nothing in
## the outline named the kind. An unloading spout swung out over one flank and
## two stacks clear of the deck took it to 0.54/0.55 and 0.65/0.69. The hauler
## then went the same way: a signal mast between the hoppers, and an alert that
## breaks at the hinge and squares up instead of jacking straight up, 0.73 to 0.67.
##
## THE BAR IS A RATCHET, and it is written per kind because one number for the
## whole set is a rubber stamp: the first version of this test sat 0.02 above the
## worst machine that existed, so nothing that existed could fail it. Every kind
## is pinned two hundredths above where it stands today. A kind may only get
## better, and bringing one down means bringing its own number down with it. The
## two worst — the harvester and the hauler seen end-on — are slabs that genuinely
## fill their boxes from that bearing, and getting them under 0.6 is a bigger
## change to both than a fix wave should make; they are the next two to do.
##
## A RATCHET WITH ONE END IS A TRAP, and the watcher sprang it. At 0.25 it was
## the emptiest thing in the roster and it passed everything here, while the one
## a player sees from a hill away was "a thin mast and three splayed legs of
## scattered violet pixels" (art finding 3) — nothing on it wide enough to carry
## a chamfer, a rivet row or a slit. Giving it a body put it at 0.27, which this
## file called a regression. So `tests/models/test_machines_mass.gd` holds the
## other end now: how much of a machine is BODY rather than edge, floored per
## kind. The watcher's number here went up on purpose and the reason is written
## in both files.
const FILLED := {
	&"harvester": 0.67, &"hauler": 0.59, &"runner": 0.51, &"warden": 0.56,
	&"sweeper": 0.55, &"dredger": 0.48, &"clerk": 0.47, &"lineman": 0.44,
	&"cutter": 0.44, &"flock": 0.32, &"longlegs": 0.32, &"watcher": 0.30,
}
## ...and the same ratchet over EVERY bearing, not the two yaws above. The two
## sampled yaws are the bearings a player mostly sees, but a camera that never
## turns still shows a machine from all sixteen as it walks its round, and the
## worst of them is where a slab shows. This is the number the A2 review had to
## take by hand (harvester and hauler "end-on", 0.69 and 0.68 of their boxes);
## it is in the gate now, pinned where each kind stands, so the next wave that
## rebuilds a hull can see what it bought.
##
## A FOURTH cheap route was tried on the harvester and it went the same way as
## the first three: standing the unloading spout up like a derrick at alert
## (0.4 rad of lift to 1.05) moved the worst bearing off 3.93 and took the alert
## fill at yaw 2.3 from 0.71 to 0.76 — worse where it is measured, for nothing
## where it is not. Raising the two lamp masts with it bought the same nothing.
## The hull is a slab from four of the sixteen bearings and the only thing that
## changes that is a different hull.
##
## SO THE HULL CHANGED (LANTERN `form`), and 0.85 came down to 0.77. Every one
## of those four attempts was an attempt to open the machine for FREE — to move
## parts about on a hull that had no hole in it — and none of them could work.
## What worked was two holes that a harvester should have had all along: the
## hull lifted onto a frame of three bolsters a side, clear of its track wells,
## so a slot of daylight runs the length of each side; and the header carried out
## in front on a feeder throat a third of its width, so daylight stands either
## side of it too. Both are structure, not decoration, and both cost triangles,
## which is why they had to wait for the budget to rise with the resolution.
##
## THE NEXT THREE WENT THE SAME WAY, and each mask showed its cause at a glance.
## The hauler end-on was one 14-pixel column: two hoppers in a line, the wheels
## tucked under the rims and a hinge of two plates as wide as the hoppers. Its
## wheels went out on bogie outriggers and the two units onto drawbars to a low
## knuckle, so a slot runs the length of it either side and the gap between the
## units is open round the mast: 0.67 to 0.56. The sweeper seen along its
## crossbar was an I, not a T: one plank 0.42 deep with the hopper stood on it.
## It is an axle beam and a brush head slung out in front on two arms now, the
## beam deepest under the hopper and thin at the wheels: 0.67 to 0.53. The
## runner side-on was a column too: a satchel strapped flat to its back, arms
## hanging inside the torso's outline and its feet together. The satchel rides
## a rack off the spine, and a runner that stops holds the step it was on, so
## there is daylight between the legs: 0.65 to 0.55. The hauler's and the
## runner's numbers at the two sampled yaws above came down with them. The
## runner's mass came down with its hole (0.53 to 0.49 of body, floor 0.40),
## which is the counterweight doing its job and why the rack stands no further off.
const FILLED_ANY := {
	&"harvester": 0.77, &"hauler": 0.58, &"sweeper": 0.55, &"runner": 0.57,
	&"warden": 0.62, &"clerk": 0.55, &"dredger": 0.54, &"lineman": 0.52,
	&"cutter": 0.47, &"flock": 0.37, &"longlegs": 0.36, &"watcher": 0.42,
}
const BEARINGS := 16
## What a kind nobody has pinned yet may fill: the bar for the thirteenth machine.
const MOST_FILLED := 0.70


func test_no_machine_is_a_filled_box() -> void:
	for kid in KINDS:
		var bar: float = float(FILLED.get(kid, MOST_FILLED))
		for yaw: float in [0.6, 2.3]:
			for p: StringName in [&"stand", &"alert"]:
				var m := posed(kid, p)
				var f := fill(silhouette(m, yaw))
				m.free()
				lt(f, bar, "%s %s at yaw %.1f fills %.2f of its box (ratchet %.2f)" % [kid, p, yaw, f, bar])
				lt(f, MOST_FILLED + 0.02, "%s %s at yaw %.1f fills %.2f: no machine is a crate" % [kid, p, yaw, f])


## ...and from every bearing, which is the measurement the A2 review had to take
## outside the gate. Printed as well as checked, because the next wave that opens
## a hull needs the table more than it needs the pass.
func test_no_machine_is_a_filled_box_from_any_bearing() -> void:
	var lines: PackedStringArray = []
	for kid in KINDS:
		var bar: float = float(FILLED_ANY.get(kid, MOST_FILLED + 0.16))
		var worst := 0.0
		var at := 0.0
		for i in BEARINGS:
			var yaw := float(i) / float(BEARINGS) * TAU
			for p: StringName in [&"stand", &"alert"]:
				var m := posed(kid, p)
				var f := fill(silhouette(m, yaw))
				m.free()
				if f > worst:
					worst = f
					at = yaw
		lines.append("  %-10s worst %.2f at yaw %.2f (ratchet %.2f)" % [kid, worst, at, bar])
		lt(worst, bar, "%s fills %.2f of its box at yaw %.2f (ratchet %.2f)" % [kid, worst, at, bar])
	print("the worst bearing of each machine:\n", "\n".join(lines))


func test_every_machine_reads_at_gameplay_zoom() -> void:
	for kid in KINDS:
		var m := posed(kid, &"stand")
		var px := count(silhouette(m))
		m.free()
		# A person is roughly 20 x 8 raster cells; nothing here should vanish.
		gt(float(px), 80.0, "%s covers %d px" % [kid, px])
		lt(float(px), W * H * 0.5, "%s covers %d px" % [kid, px])
