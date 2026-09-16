extends TestCase
## Houses are drawn in SCREEN pixels, not world units. The art review found the
## whole vocabulary already there — leaning walls, sagging ridges, plate patches
## — at amplitudes of one to three pixels at the play camera, under an inked
## ridge line that hides anything smaller than itself. And a village of them
## read pre-apocalyptic: tidy, intact, unpatched.

const Houses := preload("res://src/models/props/houses.gd")
const Kit := preload("res://src/models/props/kit.gd")
## camera_rig.gd view_height 15 over 360 rows: screen pixels to a world unit.
const PX := 24.0


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
	gt(spread * PX, 3.0, "corners lean apart by at least 3 screen px")
	var tall := 0.0
	for i in 4:
		for j in 4:
			tall = maxf(tall, absf(highs[i] - highs[j]))
	gt(tall * PX, 2.5, "no two corners stand the same height, in screen px")


func test_a_ridge_sags_more_than_the_ink_that_draws_it() -> void:
	# A straight inked ridge line hides any sag smaller than the pen.
	var k := Kit.new()
	var t := Houses.walls(k, 2.3, 2.9, 1.35, 1400, Palette.LINEN[4], Palette.LINEN[3])
	var r := Houses.hipped(k, k.made, t, 0.24, 1.05, 0.58, 0.22, Palette.SLATE[2], Palette.SLATE[1], Palette.SLATE[2])
	var sag := (r[4].y + r[6].y) * 0.5 - r[5].y
	gt(sag * PX, 4.0, "the ridge sags at least 4 screen px")


func test_a_roof_has_a_break_in_its_line() -> void:
	var k := Kit.new()
	var t := Houses.walls(k, 2.3, 2.9, 1.35, 1400, Palette.LINEN[4], Palette.LINEN[3])
	var r := Houses.hipped(k, k.made, t, 0.24, 1.05, 0.58, 0.22, Palette.SLATE[2], Palette.SLATE[1], Palette.SLATE[2], 1, 0.16)
	var lo := 9.0
	var hi := -9.0
	for i in 4:
		lo = minf(lo, r[i].y)
		hi = maxf(hi, r[i].y)
	gt((hi - lo) * PX, 3.0, "one eave corner has given way, by at least 3 screen px")


## Where a world point lands on screen, in pixels, at the play camera:
## orthographic, yaw 45, pitch 57, view_height 15 over 360 rows (camera_rig.gd).
## Only the up axis is needed to read a roofline, and the right axis to walk
## along it.
static func _screen(p: Vector3) -> Vector2:
	var pitch := deg_to_rad(57.0)
	var yaw := deg_to_rad(45.0)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var up := Vector3(-sin(pitch) * sin(yaw), cos(pitch), -sin(pitch) * cos(yaw))
	return Vector2(p.dot(right), p.dot(up)) * PX


## The break in a house's own skyline, in screen pixels: how far the highest
## thing along it gets from the straightest line that skyline could be.
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
	# variants use it — and a roof is seen from above at 24 px to the unit, where
	# a break of a pixel or two is under the pen that inks the ridge.
	for v in Houses.VARIANTS:
		var k := PropModels.build_kit(PropKind.HOUSE, v, Country.COAST)
		var all := PackedVector3Array(k.made.verts)
		all.append_array(k.found.verts)
		gt(_roofline_break(all), 10.0, "house %d has a break in its roofline, in screen px" % v)


func test_every_house_keeps_salvage_against_a_wall() -> void:
	# A village reads as people living in a ruin, not as a village before the
	# end: plate leaned up, a drum, firewood, under a lean-to of machine plate.
	# Salvage stands ON THE GROUND; roof plate and the enamel plate are higher.
	for v in Houses.VARIANTS:
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
