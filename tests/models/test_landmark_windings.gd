extends TestCase
## Every side face of a standing stone has to face OUTWARD.
##
## `world.gdshader` is `render_mode cull_back`, so a face wound the wrong way
## round is not dark and is not z-fighting: it is ABSENT, and you see straight
## through the slab to whatever is behind it. Nothing anywhere raises an error.
##
## WHY NO EXISTING TEST COVERS THIS. `tests/render/test_found_drawn.gd` is the
## instrument for "a piece that no bearing draws", and both its halves iterate
## `PropKind` x `PropModels.variants()` x landscapes. `LandmarkModels` is not a
## `PropKind` and is never rasterised by it -- so the most widely placed landmark
## in the game (`cast_stones` names twelve landscapes) has never been checked
## from any bearing at all.
##
## THE TEST IS GEOMETRIC, NOT A PICTURE, on purpose: a slab is a closed shell
## round a leaning vertical axis, so "outward" is exactly "away from the axis at
## my own height" and needs no camera, no lighting and no eye.

const Models := preload("res://src/models/landmarks/landmark_models.gd")

## `_slab` emits four side quads per segment for four segments (32 triangles),
## then two crown quads. The crown is a deliberately irregular broken top and is
## not a shell round the axis, so the rule below does not apply to it.
const SIDE_TRIS := 32


func _slab_faces(seed_value: int) -> Array:
	var k := MeshKit.new()
	Models._slab(k, 5.2, 0.62, 0.34, Color.WHITE, Color.GRAY, seed_value)
	var out: Array = []
	for t in mini(SIDE_TRIS, int(k.verts.size() / 3)):
		var a := k.verts[t * 3]
		var b := k.verts[t * 3 + 1]
		var c := k.verts[t * 3 + 2]
		out.append([(a + b + c) / 3.0, k.normals[t * 3]])
	return out


func test_no_flank_of_a_standing_stone_faces_into_itself() -> void:
	# The lean is dealt off the seed, so ask several rather than one shape.
	for seed_value: int in [1, 7, 42, 900]:
		var inward := 0
		var worst := 0.0
		for f: Array in _slab_faces(seed_value):
			var mid: Vector3 = f[0]
			var n: Vector3 = f[1]
			# The axis at THIS face's height: the slab leans, so the centre of the
			# shell moves with y. Comparing against x=0 would call a leaning slab
			# broken on whichever side it leans away from.
			var axis := Vector3(mid.x, mid.y, 0.0)
			var out_dir := mid - axis
			if out_dir.length() < 1e-4:
				continue
			var dot := n.normalized().dot(out_dir.normalized())
			if dot < 0.0:
				inward += 1
				worst = minf(worst, dot)
		eq(inward, 0, "seed %d: %d of %d side faces of a standing stone point INTO it (worst %.2f), so that flank is culled away and the stone is see-through from those bearings"
			% [seed_value, inward, SIDE_TRIS, worst])
