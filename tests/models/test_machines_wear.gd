extends TestCase
## Trophies of the trade have to reach the player: from the fixed game camera at
## gameplay zoom, each machine's trophy (matter on a `wear` holder) must win the
## depth test on enough raster cells to be seen, in the pose and turn the review
## lineup shows it (machine_gallery.gd make). Rasterised with a depth buffer one
## CELL to a cell, so a bone hidden under a comb counts for nothing.

const MG := preload("res://src/models/machines/machine_gallery.gd")
## Every kind but the flock, which is too small to carry anything.
const CARRIERS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"runner", &"clerk"]
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
const W := 180
const H := 160
## Fewer solid cells than this is a speck: it does not read as a thing.
const MIN_PX := 6


## Solid pixels of trophy that win the depth test against the whole machine.
static func trophy_pixels(m: MachineModel) -> int:
	var b := Basis.from_euler(Vector3(deg_to_rad(-57.0), deg_to_rad(45.0), 0.0))
	var right := b.x
	var up := b.y
	var back := b.z
	var depth := PackedFloat32Array()
	depth.resize(W * H)
	depth.fill(-INF)
	var owner := PackedByteArray()
	owner.resize(W * H)
	m._update_chain()
	for surface: StringName in m.surfaces:
		var mi: MeshInstance3D = m.surfaces[surface]
		var arrays := mi.mesh.surface_get_arrays(0)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
		var bpv := bones.size() / maxi(1, verts.size())
		for t in range(0, verts.size(), 3):
			var bone := bones[t * bpv]
			var c := m._bone_chain[bone]
			if c >= 0 and m._chain_shown[c] == 0:
				continue
			var trophy := surface == &"matter" and c >= 0 and m._chain[c].name == &"wear"
			var xf := m.transform * (Transform3D.IDENTITY if c < 0 else m._chain_xf[c]) * m._bone_bind[bone]
			var p: Array[Vector3] = []
			for i in 3:
				var w := xf * verts[t + i]
				p.append(Vector3(w.dot(right) / TEXEL + W * 0.5, H * 0.75 - w.dot(up) / TEXEL, w.dot(back)))
			_fill(p, depth, owner, 2 if trophy else 1)
	# Only solid trophy counts: a pixel whose 2 x 2 block is all trophy. A bone
	# drawn as a one-pixel line reads as a scratch, not as a bone.
	var count := 0
	for y in H - 1:
		for x in W - 1:
			var i := y * W + x
			if owner[i] == 2 and owner[i + 1] == 2 and owner[i + W] == 2 and owner[i + W + 1] == 2:
				count += 1
	return count


static func _fill(p: Array[Vector3], depth: PackedFloat32Array, owner: PackedByteArray, who: int) -> void:
	var a := Vector2(p[0].x, p[0].y)
	var b := Vector2(p[1].x, p[1].y)
	var c := Vector2(p[2].x, p[2].y)
	var area := (b - a).cross(c - a)
	if absf(area) < 1e-6:
		return
	for y in range(maxi(0, floori(minf(a.y, minf(b.y, c.y)))), mini(H - 1, ceili(maxf(a.y, maxf(b.y, c.y)))) + 1):
		for x in range(maxi(0, floori(minf(a.x, minf(b.x, c.x)))), mini(W - 1, ceili(maxf(a.x, maxf(b.x, c.x)))) + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			var w0 := (c - b).cross(q - b) / area
			var w1 := (a - c).cross(q - c) / area
			var w2 := (b - a).cross(q - a) / area
			if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
				continue
			var z := p[0].z * w0 + p[1].z * w1 + p[2].z * w2
			var i := y * W + x
			if z > depth[i]:
				depth[i] = z
				owner[i] = who


func test_every_trophy_reaches_the_camera_at_gameplay_zoom() -> void:
	for kid in CARRIERS:
		var m := MG.make(kid, &"stand") as MachineModel
		var px := trophy_pixels(m)
		gt(float(px), MIN_PX - 0.5, "%s: its trophy shows %d px from the game camera" % [kid, px])
		m.free()


func test_a_trophy_behind_the_body_does_not_count() -> void:
	# The depth test is what makes the gate honest: turned away, the watcher's
	# flag on its far leg shows less than it does turned toward the camera.
	var m := MG.make(&"watcher", &"stand") as MachineModel
	var toward := trophy_pixels(m)
	var least := toward
	for i in 8:
		m.rotation.y = i * TAU / 8.0
		least = mini(least, trophy_pixels(m))
	lt(float(least), float(toward), "some turn hides part of the flag (%d of %d px)" % [least, toward])
	m.free()
