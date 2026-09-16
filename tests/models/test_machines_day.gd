extends TestCase
## What a machine says when none of it is lit (playtest wave N, finding 3): by day
## the machines were flat lilac boxes — no rust, no dents, no patched plate, no
## grime, nothing but one wash a face. Night was never the problem; the lamps do
## that work, and they do it well.
##
## Measured the way a player sees it: the body is rasterised through the game
## camera with a depth buffer at gameplay texel size, and the COLOUR that wins
## each pixel is counted. Two gates:
##
##   no machine's face is one value (a box)
##   taking the years off it changes what the face says (the wear is not
##   sub-pixel detail that never reaches the screen)
##
## The second is the one with teeth, because it needs no threshold argument: a
## 0.018-wide scribed line is exact, and it is also half a screen pixel, so a
## machine drawn entirely in them is a machine drawn in nothing. Marks are
## budgeted in screen pixels (FoundKit.PX) for exactly that reason.

## Every kind marks the one face the camera at 57 degrees cannot miss: a deck, a
## hull flank, a cap's shoulder, a chest, a lid, a drum's top. The big kinds use
## FoundKit.day_wear, which is composed for half a tile of plate; the thin ones
## (watcher, warden, runner, cutter, hauler, lineman) use FoundKit.day_marks,
## which is the same three things scaled to a face a fifth that size — they had
## nothing at all before, because the only idiom was sized for a harvester.
##
## The flock is the one exception, and it is in the model's own header: thirty-six
## shards in a MultiMesh, "too small to plate". It has no body surface to mark and
## no weak side; it reads by the shape of its cloud and its amber points.
const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"runner", &"clerk"]
const MG := preload("res://src/models/machines/machine_gallery.gd")
## One screen pixel at the game's default view height (14 units over 360 px).
const TEXEL := 14.0 / 360.0
const W := 190
const H := 170
## A colour covering fewer pixels than this is a speck, not something read.
const MIN_PATCH := 4
const MIN_COLOURS := 8
const MAX_SHARE := 0.48
## How much of the visible body the years have to change to count as wear. Seven
## per cent was the floor when five of the twelve carried day marks and the rest
## carried nothing that reached the screen; with every kind marked the worst is
## the clerk at 12.5 per cent, so the floor is where a kind cannot quietly fall
## back to a body with chamfer lines on it and still pass.
const MIN_WEAR_SHARE := 0.11


## Per-pixel colour index and the palette behind it, from the fixed game camera.
static func face_pixels(m: MachineModel, palette: Array[Color]) -> PackedInt32Array:
	var b := Basis.from_euler(Vector3(deg_to_rad(-57.0), deg_to_rad(45.0), 0.0))
	var right := b.x
	var up := b.y
	var back := b.z
	var depth := PackedFloat32Array()
	depth.resize(W * H)
	depth.fill(-INF)
	var owner := PackedInt32Array()
	owner.resize(W * H)
	owner.fill(-1)
	m._update_chain()
	for surface: StringName in m.surfaces:
		# Lamps are light, not what the body says: this is the unlit hour.
		if surface == &"lights":
			continue
		var mi: MeshInstance3D = m.surfaces[surface]
		var arrays := mi.mesh.surface_get_arrays(0)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var cols := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
		var bpv := bones.size() / maxi(1, verts.size())
		for t in range(0, verts.size(), 3):
			var bone := bones[t * bpv]
			var c := m._bone_chain[bone]
			if c >= 0 and m._chain_shown[c] == 0:
				continue
			var xf := (Transform3D.IDENTITY if c < 0 else m._chain_xf[c]) * m._bone_bind[bone]
			var p: Array[Vector3] = []
			for i in 3:
				var w := xf * verts[t + i]
				p.append(Vector3(w.dot(right) / TEXEL + W * 0.5, H * 0.72 - w.dot(up) / TEXEL, w.dot(back)))
			var col := cols[t]
			var idx := palette.find(col)
			if idx < 0:
				idx = palette.size()
				palette.append(col)
			_fill(p, depth, owner, idx)
	return owner


static func _fill(p: Array[Vector3], depth: PackedFloat32Array, owner: PackedInt32Array, who: int) -> void:
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


## [colours holding MIN_PATCH pixels, the biggest one's share, visible pixels].
static func spread(owner: PackedInt32Array) -> Array:
	var counts := {}
	var total := 0
	for v in owner:
		if v < 0:
			continue
		total += 1
		counts[v] = int(counts.get(v, 0)) + 1
	var kept := 0
	var biggest := 0
	for key: int in counts:
		var n: int = counts[key]
		biggest = maxi(biggest, n)
		if n >= MIN_PATCH:
			kept += 1
	return [kept, float(biggest) / maxf(1.0, float(total)), total]


func test_no_machine_is_one_flat_value_by_day() -> void:
	for kid in KINDS:
		var m := MG.make(kid, &"stand") as MachineModel
		var got := spread(face_pixels(m, [] as Array[Color]))
		m.free()
		gt(float(got[2]), 80.0, "%s covers something" % kid)
		gt(float(got[0]), MIN_COLOURS - 0.5, "%s breaks into %d read colours" % [kid, int(got[0])])
		lt(float(got[1]), MAX_SHARE, "%s: one value covers %.0f%% of it" % [kid, float(got[1]) * 100.0])


## The mirror test takes the wear off to find the machine as built; this takes it
## off to find out whether it was ever there to be seen. A patch, a run of grime
## or a shadowed recess that changes nothing at gameplay zoom is not wear.
func test_the_years_change_what_a_machine_says_at_gameplay_zoom() -> void:
	for kid in KINDS:
		var m := MG.make(kid, &"stand") as MachineModel
		var palette: Array[Color] = []
		var worn := face_pixels(m, palette)
		for wear: Node in m.find_children("wear", "Node3D", true, false):
			(wear as Node3D).visible = false
		var bare := face_pixels(m, palette)
		m.free()
		var changed := 0
		var total := 0
		for i in worn.size():
			if worn[i] < 0 and bare[i] < 0:
				continue
			total += 1
			if worn[i] != bare[i]:
				changed += 1
		var share := float(changed) / maxf(1.0, float(total))
		gt(share, MIN_WEAR_SHARE, "%s: the years cover %.1f%% of it (%d of %d px)" % [kid, share * 100.0, changed, total])
