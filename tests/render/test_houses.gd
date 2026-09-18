extends TestCase
## Houses are drawn in SCREEN pixels, not world units. The art review found the
## whole vocabulary already there — leaning walls, sagging ridges, plate patches
## — at amplitudes of one to three pixels at the play camera, under an inked
## ridge line that hides anything smaller than itself. And a village of them
## read pre-apocalyptic: tidy, intact, unpatched.
##
## The wave A2 review went further and measured the thing those amplitudes were
## meant to prevent: every house silhouette was a rectangular prism whose outline
## was long straight runs of near-black, and the whole roof was ONE ruled
## corrugation, which put a hand-built house in the machines' idiom. So the gates
## here are the reviewer's own measurements, taken the way the player sees them:
## the house rasterised through the play camera, and its outline profiles read
## for straight runs.

const Houses := preload("res://src/models/props/houses.gd")
const Kit := preload("res://src/models/props/kit.gd")
const Lights := preload("res://src/systems/15_lights.gd")
## Frame pixels to a world unit at the camera players get: the base's own rows
## over the rig's own view height, asked of both rather than written down again
## (docs/LOOK.md). This read 24 — 360 rows — for two waves after LANTERN's floor
## took the base to 1080, so every readability gate below quietly demanded three
## times the pixels its own message named.
static var PX := float(UiBase.SIZE.y) / CameraRig.VIEW_HEIGHT
## A cell of the silhouette raster, in those pixels. Coarser than one on purpose:
## it is what keeps eight houses at two bearings affordable, and it is
## conservative, since an outline that is straight on a coarse raster is straight
## on the frame too. `_edge_straight`'s window and tolerance are in THESE cells,
## so the raster's fineness and their calibration can only move together — and W
## and H below are its size in them.
## The house that is a machine's housing lived in (Houses.build variant 3).
const BUT := 3
const CELL := 3.0
static var RASTER := PX / CELL
const W := 190
const H := 180


## Which of the COAST'S forms wired a machine's light in. Every measurement in
## this file is taken on the coast's own stock: a landscape that builds towers
## hangs its sign on a flank and would fail the roof test below on purpose.
func _lit() -> Array[int]:
	return BiomeForms.of(Country.COAST).lit()


func test_every_corner_leans_its_own_way() -> void:
	# One shared lean vector is a shear: the prism stays a rigid box, just tilted.
	var k := Kit.new()
	var t := Houses.walls(k, 2.3, 2.9, 1.35, 1400, Palette.LINEN[4], Palette.LINEN[3])
	var offs: Array[Vector2] = []
	var highs: Array[float] = []
	for i in 4:
		offs.append(Vector2(t[i + 4].x - t[i].x, t[i + 4].z - t[i].z))
		highs.append(t[i + 4].y)
	var spread := 0.0
	for i in 4:
		for j in 4:
			spread = maxf(spread, (offs[i] - offs[j]).length())
	gt(spread * PX, 9.0, "corners lean apart by at least 9 screen px")
	var tall := 0.0
	for i in 4:
		for j in 4:
			tall = maxf(tall, absf(highs[i] - highs[j]))
	gt(tall * PX, 7.5, "no two corners stand the same height, in screen px")


func test_a_ridge_sags_more_than_the_ink_that_draws_it() -> void:
	# A straight inked ridge line hides any sag smaller than the pen.
	var k := Kit.new()
	var t := Houses.walls(k, 2.3, 2.9, 1.35, 1400, Palette.LINEN[4], Palette.LINEN[3])
	var r := Houses.hipped(k, t, 0.24, 1.05, 0.58, 0.22, 1460, Houses.SLATE_ROOF, 0.2, Palette.SLATE[2])
	var sag := (r[4].y + r[6].y) * 0.5 - r[5].y
	gt(sag * PX, 12.0, "the ridge sags at least 12 screen px")


func test_a_roof_has_a_break_in_its_line() -> void:
	var k := Kit.new()
	var t := Houses.walls(k, 2.3, 2.9, 1.35, 1400, Palette.LINEN[4], Palette.LINEN[3])
	var r := Houses.hipped(k, t, 0.24, 1.05, 0.58, 0.22, 1460, Houses.SLATE_ROOF, 0.2, Palette.SLATE[2], 1, 0.16)
	var lo := 9.0
	var hi := -9.0
	for i in 4:
		lo = minf(lo, r[i].y)
		hi = maxf(hi, r[i].y)
	gt((hi - lo) * PX, 9.0, "one eave corner has given way, by at least 9 screen px")


## Where a world point lands in the RASTER, in its cells, at the play camera:
## orthographic, yaw 45, pitch 57 (camera_rig.gd). Only the up axis is needed to
## read a roofline, and the right axis to walk along it.
static func _screen(p: Vector3) -> Vector2:
	var pitch := deg_to_rad(57.0)
	var yaw := deg_to_rad(45.0)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var up := Vector3(-sin(pitch) * sin(yaw), cos(pitch), -sin(pitch) * cos(yaw))
	return Vector2(p.dot(right), p.dot(up)) * RASTER


## The break in a house's own skyline, in RASTER CELLS: how far the highest thing
## along it gets from the straightest line that skyline could be.
static func _roofline_break(verts: PackedVector3Array) -> float:
	# Above head height is roof and whatever stands on it. Measuring from a share
	# of the tallest vertex instead would let one aerial or pylon leg decide what
	# counts as the roof.
	const ROOF_Y := 0.85
	const BINS := 14
	var tops := PackedFloat32Array()
	var lo := 1e9
	var hi := -1e9
	var pts: Array[Vector2] = []
	for p: Vector3 in verts:
		if p.y < ROOF_Y:
			continue    # walls and what is stacked against them, not the roof
		var s := _screen(p)
		pts.append(s)
		lo = minf(lo, s.x)
		hi = maxf(hi, s.x)
	if pts.size() < 8 or hi - lo < 1.0:
		return 0.0
	tops.resize(BINS)
	tops.fill(-1e9)
	for s: Vector2 in pts:
		var b := clampi(int((s.x - lo) / (hi - lo) * float(BINS - 1) + 0.5), 0, BINS - 1)
		tops[b] = maxf(tops[b], s.y)
	# The straightest line the skyline could be (least squares), and how far the
	# skyline gets from it. A line through the two ends would call a house with
	# its chimney at one end straight.
	var n := 0.0
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	for i in BINS:
		if tops[i] < -1e8:
			continue
		n += 1.0
		sx += float(i)
		sy += tops[i]
		sxx += float(i) * float(i)
		sxy += float(i) * tops[i]
	if n < 4.0 or sxx * n - sx * sx < 1e-6:
		return 0.0
	var slope := (n * sxy - sx * sy) / (n * sxx - sx * sx)
	var base := (sy - slope * sx) / n
	var worst := 0.0
	for i in BINS:
		if tops[i] > -1e8:
			worst = maxf(worst, absf(tops[i] - (base + slope * float(i))))
	return worst


func test_every_house_breaks_its_roofline_at_the_zoom_it_is_seen_from() -> void:
	# Proving `hipped` CAN drop an eave proves a capability, not that all seven
	# variants use it — and a roof is seen from above at 72 px to the unit, where
	# a break of a few pixels is lost in the run of the ridge itself.
	for v in BiomeForms.PLAIN.size():
		var k := PropModels.build_kit(PropKind.HOUSE, v, Country.COAST)
		var all := PackedVector3Array(k.made.verts)
		all.append_array(k.found.verts)
		gt(_roofline_break(all) * CELL, 30.0, "house %d has a break in its roofline, in screen px" % v)


func test_every_house_keeps_salvage_against_a_wall() -> void:
	# A village reads as people living in a ruin, not as a village before the
	# end: plate leaned up, a drum, firewood, under a lean-to of machine plate.
	# Salvage stands ON THE GROUND; roof plate and the enamel plate are higher.
	for v in BiomeForms.PLAIN.size():
		var k := PropModels.build_kit(PropKind.HOUSE, v, Country.COAST)
		var low := 0
		for p: Vector3 in k.found.verts:
			if p.y < 0.35:
				low += 1
		gt(low, 30, "house %d keeps salvage against a wall" % v)


func test_every_house_is_weathered_on_every_face() -> void:
	# Only the door wall being worn is what made a village read tidy.
	var k := Kit.new()
	var before := k.made.vertex_count()
	var t := Houses.walls(k, 2.3, 2.9, 1.35, 1400, Palette.LINEN[4], Palette.LINEN[3])
	for f: Array in Houses.faces(t):
		Houses.weathered(k, f[0], f[1], f[2], f[3], 7, Palette.STONE[2], Palette.MOSS[2])
	# Four walls plus, on each face, two patches, five runs and a green foot.
	gt(k.made.vertex_count() - before, 200, "every face is worn")
	eq(Houses.faces(t).size(), 4, "a house has four faces")


# --- The silhouette, rasterised the way the player sees it ---------------------

## A flat mask of a house turned by `yaw`, through the play camera at play zoom.
static func _mask(verts: PackedVector3Array, yaw: float) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(W * H)
	var b := Basis(Vector3.UP, yaw)
	var pts := PackedVector2Array()
	pts.resize(verts.size())
	for i in verts.size():
		var s := _screen(b * verts[i])
		pts[i] = Vector2(s.x + W * 0.5, H * 0.72 - s.y)
	for t in range(0, pts.size() - 2, 3):
		var a := pts[t]
		var q := pts[t + 1]
		var c := pts[t + 2]
		var x0 := maxi(0, floori(minf(a.x, minf(q.x, c.x))))
		var x1 := mini(W - 1, ceili(maxf(a.x, maxf(q.x, c.x))))
		var y0 := maxi(0, floori(minf(a.y, minf(q.y, c.y))))
		var y1 := mini(H - 1, ceili(maxf(a.y, maxf(q.y, c.y))))
		var area := (q - a).cross(c - a)
		if absf(area) < 1e-6:
			continue
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var p := Vector2(x + 0.5, y + 0.5)
				var w0 := (q - a).cross(p - a) / area
				var w1 := (c - q).cross(p - q) / area
				var w2 := (a - c).cross(p - c) / area
				if (w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0) or (w0 <= 0.0 and w1 <= 0.0 and w2 <= 0.0):
					mask[y * W + x] = 1
	return mask


## Share of the silhouette's four edge profiles (leftmost and rightmost filled
## pixel per row, topmost and bottommost per column) that sits on a locally
## straight run of nine. A rectangular prism scores high: its outline IS four
## long ruled segments, which is what the outline pass inks near-black.
static func _edge_straight(mask: PackedByteArray) -> float:
	var profiles: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	for y in H:
		var lo := -1
		var hi := -1
		for x in W:
			if mask[y * W + x] != 0:
				if lo < 0:
					lo = x
				hi = x
		if lo >= 0:
			profiles[0].append(Vector2(lo, y))
			profiles[1].append(Vector2(hi, y))
	for x in W:
		var lo := -1
		var hi := -1
		for y in H:
			if mask[y * W + x] != 0:
				if lo < 0:
					lo = y
				hi = y
		if lo >= 0:
			profiles[2].append(Vector2(x, lo))
			profiles[3].append(Vector2(x, hi))
	const HALF := 4
	const TOL := 0.6
	var straight := 0
	var total := 0
	for pr: PackedVector2Array in profiles:
		if pr.size() < HALF * 2 + 3:
			continue
		for i in range(HALF, pr.size() - HALF):
			total += 1
			var a := pr[i - HALF]
			var b := pr[i + HALF]
			var v := b - a
			var len_v := v.length()
			if len_v < 1e-6:
				continue
			var nrm := Vector2(-v.y, v.x) / len_v
			var worst := 0.0
			for j in range(-HALF, HALF + 1):
				worst = maxf(worst, absf((pr[i + j] - a).dot(nrm)))
			if worst <= TOL:
				straight += 1
	return float(straight) / maxf(1.0, float(total))


func test_no_house_outline_is_made_of_long_straight_runs() -> void:
	# The measurement the art review took, taken again: at HEAD before this wave
	# the eight variants averaged 0.33 of their outline on straight runs and the
	# worst was 0.57 — a box. Irregular footprints, wavering eaves, a wandering
	# ridge and an added-on room bring that to 0.14 / 0.31.
	var sum := 0.0
	var n := 0
	for v in BiomeForms.PLAIN.size():
		var k := PropModels.build_kit(PropKind.HOUSE, v, Country.COAST)
		var all := PackedVector3Array(k.made.verts)
		all.append_array(k.found.verts)
		for yaw: float in [0.0, 0.6]:
			var f := _edge_straight(_mask(all, yaw))
			lt(f, 0.35, "house %d at yaw %.1f: %.3f of its outline is a straight run" % [v, yaw, f])
			sum += f
			n += 1
	lt(sum / n, 0.22, "the eight houses average %.3f of outline on straight runs" % (sum / n))


func test_no_roof_is_one_ruled_corrugation() -> void:
	# The whole roof laid in one repeating direction is the FOUND idiom: it read
	# as a machine shed. A roof is what could be got — slate in several tones,
	# tar, a board, damp at the foot, plate off a machine — and no one material
	# owns it.
	for v in BiomeForms.PLAIN.size():
		var k := PropModels.build_kit(PropKind.HOUSE, v, Country.COAST)
		var seen: Dictionary = {}
		var roof := 0
		var verts := k.made.verts
		var cols := k.made.colors
		var norms := k.made.normals
		for i in range(0, verts.size() - 2, 3):
			# A roof is what faces the sky above head height: the long house is low
			# and the small washed house is lower still, so a fixed height would
			# read one house's roof and miss another's.
			var mid := (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
			if mid.y < 0.95 or norms[i].y < 0.25:
				continue
			roof += 1
			var c: Color = cols[i]
			var key := "%d_%d_%d" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]
			seen[key] = int(seen.get(key, 0)) + 1
		# Enough of a roof to read a mix on. The but's is mostly the machine lid it
		# was made of, which is FOUND and ruled on purpose; what is MADE on it is
		# the sods the people laid, and those still have to be a mix.
		gt(roof, 14, "house %d has a roof to read" % v)
		gt(seen.size(), 5, "house %d roof is laid in more than five materials" % v)
		var most := 0
		for key: String in seen:
			most = maxi(most, int(seen[key]))
		lt(float(most) / float(roof), 0.5, "house %d: no one material owns its roof" % v)


## Every cell `patch_slope` laid, as [bottom edge length, up-slope side edge].
## MeshKit emits a quad as two reversed triangles: quad(A, B, C, D) lands as
## [A, C, B, A, D, C], so the eave edge is 0 -> 2 and the side edge 2 -> 1.
static func _cells(k: Kit) -> Array:
	var out: Array = []
	var v := k.made.verts
	var c := k.made.colors
	for i in range(0, v.size() - 5, 6):
		if c[i].is_equal_approx(Palette.INK[2]):
			continue    # the dark batten under a course that slipped, not a course
		var side := v[i + 1] - v[i + 2]
		# ...nor is the exposed EDGE of a course a course. A course lies over the
		# one below it and leaves its own thickness standing to the sky, which is
		# what rules the line across a slope; that face is `Houses.LAP` deep and
		# square to the slope by construction, so measuring it as a patch of slate
		# says only that a lip is not a slate. Every course FACE is still held to
		# the width and the lean below.
		if side.length() < Houses.LAP * 1.5:
			continue
		out.append([v[i].distance_to(v[i + 2]), side])
	return out


func test_a_roof_is_laid_in_courses_not_rays() -> void:
	# On a hipped slope — a long eave under a short ridge — pairing eave station
	# i with ridge station i converges every cell boundary on the ridge ends, so
	# the patches near the apex came out as slivers radiating from a point and a
	# plate one was a ruled FOUND ray (a2 review). Laid by length along the
	# course instead: a patch is the same size wherever it lies, and only the
	# outermost of each course leans, because that is where the hip cuts it.
	var eave := PackedVector3Array()
	var ridge := PackedVector3Array()
	for i in 9:
		var f := float(i) / 8.0
		eave.append(Vector3(1.4, 1.0, lerpf(-1.7, 1.7, f)))
		ridge.append(Vector3(0.0, 2.0, lerpf(-0.45, 0.45, f)))
	var k := Kit.new()
	Houses.patch_slope(k, eave, ridge, 3, 77, Houses.SLATE_ROOF, 0.0)
	var cells := _cells(k)
	gt(cells.size(), 12, "the slope is cut into patches")
	var fall := Vector3(-1.4, 1.0, 0.0).normalized()
	var lean := 0.0
	var steep := 0
	for cell: Array in cells:
		var w: float = cell[0]
		gt(w, Houses.CELL * 0.8, "a patch is a piece of slate, not a sliver: %.3f wide" % w)
		lt(w, Houses.CELL * 1.2, "a patch is a piece of slate, not a sheet: %.3f wide" % w)
		var a := rad_to_deg((cell[1] as Vector3).normalized().angle_to(fall))
		lean += a
		if a > 25.0:
			steep += 1
	lt(lean / cells.size(), 15.0, "the courses run up the slope: mean lean %.1f deg" % (lean / cells.size()))
	lt(float(steep) / cells.size(), 0.25, "only the ends of a course lean into the hip: %d of %d" % [steep, cells.size()])


func test_a_roof_is_hand_made_with_found_plate_only_as_patches() -> void:
	# The brief: the MADE idiom dominant, FOUND plate as PATCHES on it. Counting
	# MADE materials alone cannot see plate taking a roof over, and it had: 0.60
	# of the half house's roof area and 0.38 of the slated one's was machine plate.
	for v in BiomeForms.PLAIN.size():
		var k := PropModels.build_kit(PropKind.HOUSE, v, Country.COAST)
		var made := 0.0
		var found := 0.0
		for pen_i in 2:
			var pen: MeshKit = k.made if pen_i == 0 else k.found
			for i in range(0, pen.verts.size() - 2, 3):
				var mid := (pen.verts[i] + pen.verts[i + 1] + pen.verts[i + 2]) / 3.0
				if mid.y < 0.95 or pen.normals[i].y < 0.25:
					continue
				var area := 0.5 * ((pen.verts[i + 1] - pen.verts[i]).cross(pen.verts[i + 2] - pen.verts[i])).length()
				if pen_i == 0:
					made += area
				else:
					found += area
		var share := found / maxf(0.001, made + found)
		if v == BUT:
			# The but is a machine's housing lived in: its lid IS found plate, and
			# what the people added to it is the MADE sods and chimney above.
			gt(share, 0.5, "the but is still a machine housing: %.3f of its roof is found" % share)
			continue
		lt(share, 0.35, "house %d: found plate is a patch on its roof, not the roof (%.3f)" % [v, share])


func test_turf_is_banked_past_the_drip_line() -> void:
	# ART section 4 asks for turf banked at the foot. It used to sit 0.04 INSIDE
	# the wall line, where the eaves hide it at a 57-degree pitch, so it never
	# reached the screen. It has to stand outside the wall to be seen at all.
	var k := Kit.new()
	var t := Houses.walls(k, 2.2, 2.8, 1.3, 1400, Palette.LINEN[4], Palette.LINEN[3])
	var before := k.made.vertex_count()
	Houses.turf_bank(k, t, 99, Country.COAST)
	var outside := 0
	for i in range(before, k.made.verts.size()):
		var p: Vector3 = k.made.verts[i]
		if p.y < 0.35 and (absf(p.x) > 1.2 or absf(p.z) > 1.5):
			outside += 1
	gt(outside, 60, "the bank reaches past the wall line, where the eave does not hide it")


func test_the_stolen_neon_is_where_the_play_camera_can_see_it() -> void:
	# Art review 11 found zero tube pixels in three canon frames. The tube was on
	# the door wall — which faces the village square, not the camera — and at
	# v=0.85, under an eave overhang that at this pitch hides the top of a wall.
	# So the run of it goes on the ROOF, the one surface this camera always sees.
	for v: int in _lit():
		var k := PropModels.build_kit(PropKind.HOUSE, v, Country.COAST)
		var on_roof := 0
		var on_wall := 0
		var cols := k.made.colors
		var norms := k.made.normals
		for i in k.made.verts.size():
			if roundi(cols[i].a * 255.0) != GroundColors.NEON:
				continue
			if norms[i].y > 0.3:
				on_roof += 1
			else:
				on_wall += 1
		gt(on_roof, 20, "house %d runs its stolen tube along the roof, where the camera sees it" % v)
		gt(on_roof, float(on_wall), "house %d keeps more tube on the roof than on a wall" % v)


func test_the_light_a_tube_throws_comes_from_the_tube() -> void:
	# The tube moved to the roof edge and the pool it laid stayed pinned to the
	# door wall, in the other lit house's colour (a2 review): a light written down
	# in one file and its geometry in another. `PropModels.neon_point` reads the
	# model, so they cannot part company again.
	for v in BiomeForms.PLAIN.size():
		var point := PropModels.neon_point(PropKind.HOUSE, v, Country.COAST)
		if not _lit().has(v):
			check(point.is_empty(), "house %d wired nothing in, so it declares no tube" % v)
			continue
		check(not point.is_empty(), "house %d declares where its stolen tube is" % v)
		var at: Vector3 = point.at
		var k := PropModels.build_kit(PropKind.HOUSE, v, Country.COAST)
		# Where the tube actually is: the middle of what was drawn as neon.
		var mid := Vector3.ZERO
		var n := 0
		var eave := 0.0
		for i in k.made.verts.size():
			if roundi(k.made.colors[i].a * 255.0) != GroundColors.NEON:
				continue
			mid += k.made.verts[i]
			n += 1
		for p: Vector3 in k.made.verts:
			eave = maxf(eave, p.y)
		gt(n, 20, "house %d drew a tube to read" % v)
		lt((at - mid / n).length(), 0.02, "house %d: the light stands where the tube is" % v)
		gt(at.y, 0.9, "house %d: the tube is up on the roof, not at the door" % v)
		var col: Color = point.color
		var want: Color = Houses.NEON_TUBES[0]
		var best := 9.0
		for t: Color in Houses.NEON_TUBES:
			var d := Vector3(col.r - t.r, col.g - t.g, col.b - t.b).length()
			if d < best:
				best = d
				want = t
		lt(best, 0.35, "house %d: the light is the tube's own colour, not a constant" % v)
	# The two lit houses do not share a colour, so a glint in the wrong one shows.
	var a: Color = PropModels.neon_point(PropKind.HOUSE, _lit()[0], Country.COAST).color
	var b: Color = PropModels.neon_point(PropKind.HOUSE, _lit()[1], Country.COAST).color
	gt(Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length(), 0.3, "the two lit houses burn different colours")


func test_a_lit_house_puts_its_glint_on_its_own_tube() -> void:
	# In a running game: the wet-ground reflection of a stolen tube has to sit
	# where the tube is and burn its colour. It sat on the door wall in the other
	# house's magenta while the tube ran along a roof edge (a2 review).
	var o := BootOptions.new()
	o.size = 64
	o.hour = 23.0
	o.weather = "rain:1"
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	var lights: Node = null
	for s in g.systems:
		if s.get_script() == Lights:
			lights = s
	check(lights != null, "lights system")
	var houses: Array[WorldProp] = []
	for i in _lit().size():
		var p := WorldProp.new(g.world.props.size(), PropKind.HOUSE, g.player.pos + Vector2(3.0 + i * 4.0, 1.0), 0.0, 1.0)
		p.variant = _lit()[i]
		g.world.props.append(p)
		houses.append(p)
	var dark := WorldProp.new(g.world.props.size(), PropKind.HOUSE, g.player.pos + Vector2(-3.0, 1.0), 0.0, 1.0)
	dark.variant = 2
	g.world.props.append(dark)
	await frames(20)
	var by_prop := {}
	for src: Dictionary in lights.get("sources"):
		by_prop[(src.prop as WorldProp).id] = src
	check(not (by_prop.get(dark.id, {}) as Dictionary).has("neon_at"), "a house with nothing wired in throws no tube light")
	for p: WorldProp in houses:
		var src: Dictionary = by_prop.get(p.id, {})
		check(src.has("neon_at"), "the lit house throws its tube's light")
		var tube := PropModels.neon_point(PropKind.HOUSE, p.variant, Country.COAST)
		var at: Vector3 = src.neon_at
		var want := g.world.to_3d(p.pos) + (tube.at as Vector3)
		lt((at - want).length(), 0.05, "the tube's light stands on the tube, not on the door wall")
		var rgb: Vector3 = src.neon_rgb
		var col: Color = tube.color
		lt((rgb - Vector3(col.r, col.g, col.b)).length(), 0.02, "it burns the tube's own colour")
	g.queue_free()
	await frames(2)


func test_no_kind_has_more_models_than_the_cache_can_tell_apart() -> void:
	# `PropModels.template` packs (kind, variant) into one key. At a multiplier of
	# 8 a ninth house would have collided with the next kind's variant 0 and drawn
	# something else entirely, silently. Nothing is close to the cap today; this
	# is here so that adding a model is a test failure and not a screenshot.
	for kind in PropKind.COUNT:
		check(PropModels.variants(kind) <= PropModels.MAX_VARIANTS, "%s has more models than the cache key packs" % PropKind.NAMES[kind])


func test_a_village_deals_every_house_a_different_model() -> void:
	# On seed 7 the spawn village had seven houses drawn from four models, three
	# of them the same (art review 5). A village deals a pack now, and the house
	# nearest the square is always the one with a machine's light on it.
	# The pack and the models could drift once, so a test held `HOUSE_MODELS` and
	# `HOUSE_NEON` equal to their two copies in the renderer. There is nothing to
	# hold equal now: both world gen and the geometry read one table in core
	# (`BiomeForms`), and `tests/biome/test_forms.gd` holds the table against what
	# is actually built.
	var villages := 0
	var lit_on_square := 0
	var dark := 0
	for seed_value: int in [7, 1, 3]:
		var w := WorldGen.generate(seed_value)
		for v: Dictionary in w.villages:
			var vp: Vector2 = v.pos
			# EACH VILLAGE'S OWN LANDSCAPE. Which forms are lit and how many there
			# are to deal are the landscape's (`BiomeForms`), so asking the coast's
			# question of a village somewhere else counts the wrong house and holds
			# it to the wrong pack size.
			var here := int(v.get("country", Country.COAST))
			var forms := BiomeForms.of(here)
			var neon := forms.lit()
			var seen: Array[int] = []
			var lit := 0
			var nearest := -1
			var best := INF
			for p: WorldProp in w.props:
				if p.kind != PropKind.HOUSE or p.pos.distance_to(vp) > 18.0:
					continue
				var variant := PropModels.variant_of(p, w.seed_value, here)
				check(not seen.has(variant), "%s: two houses drawn the same (model %d)" % [v.get("name", "?"), variant])
				seen.append(variant)
				var d := p.pos.distance_to(vp)
				if d < best:
					best = d
					nearest = variant
				if neon.has(variant):
					lit += 1
			if seen.is_empty():
				continue
			villages += 1
			if neon.has(nearest):
				lit_on_square += 1
				# A DEAL MAY NOT PREFER THE LIT FORMS. The stock is dealt without
				# repeats, so lit houses can be no commoner in the street than lit
				# forms are in the pack: the coast has one in eight and a village of
				# seven still gets one. This said "one, not a street of them" as a
				# flat number, which was the coast's answer written down as every
				# landscape's — the city has four lit forms in six, and a street of
				# five mostly lit is the landscape being what it is.
				check(lit <= mini(seen.size(), neon.size()),
					"%s: %d lit houses from %d forms, %d of them lit" % [v.get("name", "?"), lit, seen.size(), neon.size()])
			if lit == 0:
				dark += 1
	gt(villages, 20, "three seeds have villages to read")
	# A share of villages wired a machine's light in, and in those it is on the
	# house by the square. Not all of them: dealing a lit house to every village
	# made stolen neon a filter over the coast instead of something one village
	# did (a2 review, and the owner's own correction).
	var share := float(lit_on_square) / villages
	gt(share, 0.2, "villages with the lit house on the square: %.2f" % share)
	lt(share, 0.6, "villages with the lit house on the square: %.2f" % share)
	gt(float(dark) / villages, 0.1, "some villages have no stolen light at all: %.2f" % (float(dark) / villages))


func test_the_canon_stands_where_a_tube_burns() -> void:
	# Art review 11: the two canon frames meant to protect the stolen neon held
	# zero pixels of any tube colour. The canon shoots seed 7 from the spawn, so
	# the village the player wakes in has to be one of the lit ones, and the lit
	# house has to be the one it looks at.
	var w := WorldGen.generate(7)
	var vp := Vector2.ZERO
	var best := INF
	for v: Dictionary in w.villages:
		var d: float = (v.pos as Vector2).distance_to(w.spawn)
		if d < best:
			best = d
			vp = v.pos
	var nearest := -1
	var near := INF
	for p: WorldProp in w.props:
		if p.kind != PropKind.HOUSE or p.pos.distance_to(vp) > 18.0:
			continue
		var d := p.pos.distance_to(vp)
		if d < near:
			near = d
			nearest = PropModels.variant_of(p, w.seed_value)
	check(_lit().has(nearest), "the village the canon stands in has its stolen light on the square")
