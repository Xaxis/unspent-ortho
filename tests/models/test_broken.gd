extends TestCase
## A thing the taking has worked down (Broken): it is CUT, not scaled, the cut is
## capped with a face nothing has settled on, and every step of the work is a
## template of its own.

## Kinds a player actually takes from, one of each family the cut has to survive:
## a rounded rock, an ore body, a built wreck, a bank of peat.
const WORKED: Array[int] = [PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.WRECK, PropKind.PEAT_BANK]


func _made(kind: int, worked: int) -> MeshKit:
	return PropModels.build_kit(kind, 0, Country.COAST, worked).made


func _high(k: MeshKit) -> float:
	var hi := -INF
	for v: Vector3 in k.verts:
		hi = maxf(hi, v.y)
	return hi


func _wide(k: MeshKit) -> float:
	var w := 0.0
	for v: Vector3 in k.verts:
		w = maxf(w, Vector2(v.x, v.z).length())
	return w


func test_the_steps_a_worked_thing_is_drawn_in() -> void:
	eq(Broken.bucket(1.0), Broken.BUCKETS - 1, "whole")
	eq(Broken.bucket(0.0), 0, "all but gone")
	near(Broken.share_of(Broken.BUCKETS - 1), 1.0, 1e-6)
	var last := -1
	for i in 21:
		var share := float(i) / 20.0
		var b := Broken.bucket(share)
		check(b >= 0 and b < Broken.BUCKETS, "%f is a step" % share)
		check(b >= last, "less left is never a fuller step")
		last = b
	gt(Broken.height_for(1.0), Broken.height_for(0.5), "less left stands lower")
	gt(Broken.height_for(0.5), Broken.height_for(0.2))
	near(Broken.height_for(1.0), 1.0, 1e-6, "whole is its whole height")
	near(Broken.height_for(0.0), Broken.LEAST, 1e-6, "and a stump is still a thing")


func test_a_worked_thing_is_cut_down_not_scaled_in() -> void:
	for kind: int in WORKED:
		var name := PropKind.NAMES[kind]
		var whole := _made(kind, PropModels.WHOLE)
		var worked := _made(kind, 1)
		gt(float(whole.verts.size()), 8.0, "%s: something to cut" % name)
		lt(_high(worked), _high(whole), "%s: worked down" % name)
		gt(_wide(worked), _wide(whole) * 0.8, "%s: and still as wide as it was" % name)
		gt(float(worked.verts.size()), 8.0, "%s: something is left of it" % name)
		eq(worked.verts.size() % 3, 0, "%s: whole triangles" % name)
		eq(worked.normals.size(), worked.verts.size(), "%s: a normal each" % name)
		eq(worked.colors.size(), worked.verts.size(), "%s: a colour each" % name)
		eq(worked.uvs.size(), worked.verts.size(), "%s: a uv each" % name)
		eq(worked.uv2s.size(), worked.verts.size(), "%s: a second uv each" % name)
		eq(worked.custom0.size(), worked.verts.size() * 4, "%s: four custom floats each" % name)
		for v: Vector3 in worked.verts:
			check(is_finite(v.x) and is_finite(v.y) and is_finite(v.z), "%s: no vertex is nowhere" % name)


func test_the_cut_is_capped_with_a_face_nothing_has_settled_on() -> void:
	var worked := _made(PropKind.BOULDER, 1)
	var fresh := 0
	var top := -INF
	for i in worked.verts.size():
		if roundi(worked.colors[i].a * 255.0) == GroundColors.FRESH:
			fresh += 1
			top = maxf(top, worked.verts[i].y)
	gt(float(fresh), 5.0, "the cut has a face on it (%d vertices)" % fresh)
	gt(top, _high(worked) - 0.2, "and it is at the top, where the hammer was")
	# The face as a whole looks up, and no facet of it stands so steep that it
	# reads as a wall or an overhang: it is broken, not planed, but it is a face.
	var up := 0.0
	var faces := 0
	for i in range(0, worked.verts.size(), 3):
		if roundi(worked.colors[i].a * 255.0) != GroundColors.FRESH:
			continue
		gt(worked.normals[i].y, 0.2, "no part of a cut face is a wall")
		up += worked.normals[i].y
		faces += 1
	gt(float(faces), 2.0, "the face is made of facets")
	gt(up / float(faces), 0.8, "and the face of them looks up")


func _top(t: PropModels.Template) -> float:
	var hi := -INF
	for v: Vector3 in t.made_v:
		hi = maxf(hi, v.y)
	return hi


func test_every_step_is_its_own_model() -> void:
	# Height, not vertex count: opening a face ADDS triangles, so a thing nearly
	# worked out can carry more of them than a whole one and still be less of it.
	var last := INF
	for b in range(Broken.BUCKETS - 1, -1, -1):
		var t := PropModels.template(PropKind.BOULDER, 0, Country.COAST, b)
		gt(float(t.made_v.size()), 8.0, "step %d is a model" % b)
		lt(_top(t), last, "step %d stands lower than the step above it" % b)
		last = _top(t)
	var whole := PropModels.template(PropKind.BOULDER, 0, Country.COAST)
	near(_top(whole), _top(PropModels.template(PropKind.BOULDER, 0, Country.COAST, PropModels.WHOLE)), 1e-6,
		"whole is what a caller that says nothing gets")
	# The key packs kind, variant, country AND step into one int: a step of one
	# kind must never be handed back as another kind.
	var a := PropModels.template(PropKind.BOULDER, 0, Country.COAST, 0)
	var b2 := PropModels.template(PropKind.STONE_ORE, 0, Country.COAST, PropModels.WHOLE)
	check(a.made_v.size() != b2.made_v.size() or a.made_v[0] != b2.made_v[0], "a step of one kind is not another kind whole")


func test_nothing_is_cut_that_has_not_been_worked() -> void:
	var k := _made(PropKind.BOULDER, PropModels.WHOLE)
	var before := k.verts.size()
	Broken.work_down(k, 1.0, 3)
	eq(k.verts.size(), before, "a whole thing is left alone")
	Broken.work_down(k, 0.5, 3)
	lt(float(k.verts.size()), float(before) * 1.6, "a cut does not run away with the triangle count")
	for i in k.verts.size():
		if roundi(k.colors[i].a * 255.0) == GroundColors.FRESH:
			return
	fail("a cut leaves a fresh face")
