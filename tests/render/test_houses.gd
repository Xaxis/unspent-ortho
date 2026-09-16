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
## camera_rig.gd view_height 15 over 360 rows: screen pixels to a world unit.
const PX := 24.0
const W := 190
const H := 180


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
	var r := Houses.hipped(k, t, 0.24, 1.05, 0.58, 0.22, 1460, Houses.SLATE_ROOF, 0.2, Palette.SLATE[2])
	var sag := (r[4].y + r[6].y) * 0.5 - r[5].y
	gt(sag * PX, 4.0, "the ridge sags at least 4 screen px")


func test_a_roof_has_a_break_in_its_line() -> void:
	var k := Kit.new()
	var t := Houses.walls(k, 2.3, 2.9, 1.35, 1400, Palette.LINEN[4], Palette.LINEN[3])
	var r := Houses.hipped(k, t, 0.24, 1.05, 0.58, 0.22, 1460, Houses.SLATE_ROOF, 0.2, Palette.SLATE[2], 1, 0.16)
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
	for v in Houses.VARIANTS:
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
	for v in Houses.VARIANTS:
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
	for v: int in Lights.NEON_HOUSE_VARIANTS:
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


func test_a_village_deals_every_house_a_different_model() -> void:
	# On seed 7 the spawn village had seven houses drawn from four models, three
	# of them the same (art review 5). A village deals a pack now, and the house
	# nearest the square is always the one with a machine's light on it.
	eq(GenScatter.HOUSE_MODELS, Houses.VARIANTS, "the pack has one card per house model")
	eq(GenScatter.HOUSE_NEON, Lights.NEON_HOUSE_VARIANTS, "the pack knows which houses are lit")
	var w := WorldGen.generate(7)
	var villages := 0
	for v: Dictionary in w.villages:
		var vp: Vector2 = v.pos
		var seen: Array[int] = []
		var lit := 0
		var nearest := -1
		var best := INF
		for p: WorldProp in w.props:
			if p.kind != PropKind.HOUSE or p.pos.distance_to(vp) > 18.0:
				continue
			var variant := PropModels.variant_of(p, w.seed_value)
			check(not seen.has(variant), "%s: two houses drawn the same (model %d)" % [v.get("name", "?"), variant])
			seen.append(variant)
			var d := p.pos.distance_to(vp)
			if d < best:
				best = d
				nearest = variant
			if GenScatter.HOUSE_NEON.has(variant):
				lit += 1
		if seen.is_empty():
			continue
		villages += 1
		gt(lit, 0, "%s has somebody's stolen light in it" % v.get("name", "?"))
		check(GenScatter.HOUSE_NEON.has(nearest), "%s: the house nearest the square is the lit one" % v.get("name", "?"))
	gt(villages, 4, "seed 7 has villages to read")
