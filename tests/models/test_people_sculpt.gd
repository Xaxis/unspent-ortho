extends TestCase
## Sculpt: the solids every figure is drawn with must face outward whichever
## way their rings are listed, or the rim pass and the light both invert.


func _outward_share(k: MeshKit, centre_axis_y: bool = true) -> float:
	var out := 0
	var tris := k.verts.size() / 3
	for t in tris:
		var a := k.verts[t * 3]
		var b := k.verts[t * 3 + 1]
		var c := k.verts[t * 3 + 2]
		var mid := (a + b + c) / 3.0
		var radial := Vector3(mid.x, 0.0, mid.z) if centre_axis_y else mid
		if k.normals[t * 3].dot(radial) > 0.0:
			out += 1
	return float(out) / tris


func test_loft_faces_outward_up_or_down() -> void:
	for down: bool in [false, true]:
		var k := MeshKit.new()
		var rings: Array = [[0.0, 0.1, 0.1, 0.0, 0.0], [0.3, 0.08, 0.08, 0.0, 0.0]]
		if down:
			rings = [[0.0, 0.1, 0.1, 0.0, 0.0], [-0.3, 0.08, 0.08, 0.0, 0.0]]
		Sculpt.loft(k, rings, 6, Color.WHITE, false, false)
		eq(k.verts.size(), 36, "one band of six quads")
		near(_outward_share(k), 1.0, 1e-6, "walls face out (down=%s)" % down)


func test_loft_band_colours_stay_with_their_band_when_listed_downward() -> void:
	var k := MeshKit.new()
	Sculpt.loft(k, [[0.0, 0.1, 0.1, 0.0, 0.0], [-0.2, 0.1, 0.1, 0.0, 0.0], [-0.3, 0.1, 0.1, 0.0, 0.0]], 4, [Color.RED, Color.BLUE], false, false)
	for i in k.verts.size():
		var y := k.verts[i].y
		if y > -0.001:
			eq(k.colors[i], Color.RED, "top band keeps the first colour")
		elif y < -0.299:
			eq(k.colors[i], Color.BLUE, "bottom band keeps the second colour")


func test_slab_and_card_face_the_way_asked() -> void:
	var k := MeshKit.new()
	Sculpt.slab(k, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)]), 0.1, Color.WHITE)
	gt(k.normals[0].z, 0.9, "front cap faces +Z")
	lt(k.normals[3].z, -0.9, "back cap faces -Z")
	for out: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:
		var c := MeshKit.new()
		Sculpt.card(c, Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, -1), Color.WHITE, out)
		gt(c.normals[0].dot(out), 0.9, "card faces %s" % out)


## The loft welds its walls from its own ring topology instead of searching for
## coincident corners. It must give the answer the search gives, for a closed
## body with a shoulder that creases, an open collar, folds, and a transform
## pushed, or a figure is lit wrong in exactly the places it was made rounder.
func test_the_loft_weld_is_the_corner_search_by_another_road() -> void:
	var cases: Array = [
		[[[0.0, 0.1, 0.12, 0.0, 0.0, 0.03], [0.2, 0.12, 0.14, 0.01, 0.0], [0.24, 0.05, 0.06, 0.0, 0.0], [0.3, 0.02, 0.02, 0.0, 0.0]], 12, 1.0],
		[[[0.3, 0.08, 0.08, 0.0, 0.0], [0.0, 0.1, 0.1, 0.0, 0.0], [-0.2, 0.07, 0.07, 0.0, 0.0, 0.05]], 7, 1.0],
		[[[0.0, 0.1, 0.1, 0.0, 0.0], [0.1, 0.11, 0.1, 0.0, 0.0]], 8, 0.52],
	]
	for c: Array in cases:
		var k := MeshKit.new()
		k.push(Transform3D(Basis(Vector3(0, 0, 1), 0.4).scaled(Vector3(1.0, 1.3, 0.9)), Vector3(0.2, 0.1, 0)))
		Sculpt.loft(k, c[0], c[1], Color.WHITE, false, false, 0.2, 0.05, 9, c[2], PI)
		k.pop()
		# The same triangles laid flat, then welded by the search.
		var ref := MeshKit.new()
		for t in range(0, k.verts.size(), 3):
			ref.tri(k.verts[t], k.verts[t + 2], k.verts[t + 1], Color.WHITE)
		ref.smooth_range(0, ref.verts.size(), Sculpt.WALL_CREASE)
		var worst := 0.0
		for i in k.verts.size():
			worst = maxf(worst, k.normals[i].distance_to(ref.normals[i]))
		lt(worst, 0.02, "n=%d arc=%.2f: the loft's weld against the search, worst %.4f" % [c[1], c[2], worst])
		# And it is a weld: a curved wall does not keep one normal per face.
		var flat := 0.0
		for i in k.verts.size():
			flat = maxf(flat, k.normals[i].distance_to(ref_flat(k, i)))
		gt(flat, 0.05, "n=%d: the walls are not left faceted" % c[1])


static func ref_flat(k: MeshKit, i: int) -> Vector3:
	var t := i - i % 3
	return (k.verts[t + 1] - k.verts[t + 2]).cross(k.verts[t] - k.verts[t + 2]).normalized()
