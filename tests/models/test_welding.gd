extends TestCase
## A weathered mass is welded, and what is cut into it is not.
##
## A flat normal per facet is what a GEM is made of. Under the wash-and-ink
## pipeline that was right -- the ink drew the form and a normal only chose a
## shade band -- and under a real sun it is the whole difference between stone
## and crystal (docs/LOOK.md law 1). `MeshKit.smooth_range` is the pass that
## fixes it and it adds no triangles.
##
## This pins the ONE thing a picture cannot tell you at play distance: whether
## the weld is still happening. A small prop is about seventy pixels on screen,
## and at that size welded and unwelded ore are indistinguishable -- the
## difference only reads close up or under a raking sun. So a silent revert here
## would never be caught by looking, which is exactly when a test earns its keep.

const Kit := preload("res://src/models/props/kit.gd")
const Rocks := preload("res://src/models/props/rocks.gd")

const CREASE_SAFE := 0.02


## A plain n-sided band, built the way `Rocks.banded` builds one: a ring of
## quads, each carrying its own normal. No jitter, so the angle between
## neighbouring facets is exactly 360/n and the arithmetic below is checkable by
## hand rather than by running it.
static func _band(sides: int) -> MeshKit:
	var k := MeshKit.new()
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for e in sides:
		var a := float(e) / float(sides) * TAU
		lo.append(Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5))
		hi.append(Vector3(cos(a) * 0.5, 0.4, sin(a) * 0.5))
	for e in sides:
		var m := (e + 1) % sides
		k.quad(lo[m], lo[e], hi[e], hi[m], Color.WHITE)
	return k


static func _same(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not a[i].is_equal_approx(b[i]):
			return false
	return true


func test_the_default_crease_sits_on_the_ring_counts_a_rock_is_built_from() -> void:
	# **THE FINDING THIS PINS.** The facets of an n-sided ring meet at 360/n
	# degrees. Six sides is 60 and seven is 51.43, while `MeshKit.CREASE` is 52 --
	# so a seven-sided mass welds by six tenths of a degree and a six-sided one
	# does not weld at all, and `Rocks.banded` jitters every ring, which makes
	# whether any given seam welds a matter of noise. Nothing in a picture says
	# which half of a mass rounded.
	#
	# So the ore builders state their crease instead of taking the default, and
	# these are the two facts that forced it.
	var six := _band(6)
	var raw := six.normals.duplicate()
	six.smooth_range(0, six.vertex_count(), MeshKit.CREASE)
	check(_same(six.normals, raw), "a six-sided ring welds NOTHING at the default crease of 52")
	var rocky := _band(6)
	rocky.smooth_range(0, rocky.vertex_count(), Rocks.ROCK_CREASE)
	check(not _same(rocky.normals, raw), "and rounds at the crease the rocks ask for")


func test_the_rock_crease_clears_every_ring_count_the_ores_use() -> void:
	# Five sides is 72 degrees, and the ores build masses of five, six and seven.
	# A crease at or under 72 puts the five-sided ones back on the knife edge, so
	# the number has to sit clear of it -- `Sculpt.WALL_CREASE` picked 76 for a
	# six-sided limb for the same reason and is the precedent.
	gt(Rocks.ROCK_CREASE, 72.0, "a five-sided mass rounds too")
	for sides: int in [5, 6, 7]:
		var k := _band(sides)
		var raw := k.normals.duplicate()
		k.smooth_range(0, k.vertex_count(), Rocks.ROCK_CREASE)
		check(not _same(k.normals, raw), "%d sides rounds at the rock crease" % sides)


func test_the_weld_stops_where_the_mass_does() -> void:
	# The reason the bracket is INSIDE `banded` rather than round its callers:
	# the stone's quarried face is FLAT by design, its beds and wedge holes are
	# cut into it, and the split blocks at its foot are their own stones. A
	# bracket round the whole caller would soften the one thing that says the
	# rock was worked -- and nothing in a picture at play distance would tell you
	# it had happened, because a small prop is about seventy pixels on screen.
	#
	# So build the mass, then rule a flat face across it the way `stone_ore`
	# does, and hold both halves: the mass keeps the normals it was welded with,
	# and the face is one plane.
	var k := Kit.new()
	Rocks.banded(k, [0.5, 0.6, 0.55, 0.4], [0.0, 0.2, 0.4, 0.6],
		[Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE], Vector3(0.0, 0.8, 0.0), 7, 4242)
	var mass := k.made.normals.duplicate()
	gt(float(mass.size()), 8.0, "the mass is built")
	k.made.quad(Vector3(0.5, -0.04, -0.4), Vector3(0.5, -0.04, 0.4),
		Vector3(0.44, 0.6, 0.3), Vector3(0.44, 0.6, -0.3), Color.WHITE)
	for i in mass.size():
		if not k.made.normals[i].is_equal_approx(mass[i]):
			fail("ruling a face across the mass changed the mass's own normal at %d" % i)
			break
	var face := k.made.normals[mass.size()]
	var same := true
	for i in range(mass.size(), k.made.normals.size()):
		same = same and k.made.normals[i].is_equal_approx(face)
	check(same, "the face ruled across it is one flat plane, not welded into the mass")

## Share of a model's shared corners where two faces meet under `crease` and were
## left unaveraged -- how much of it is still cut glass.
static func _hard_share(v: PackedVector3Array, n: PackedVector3Array, crease: float) -> float:
	var by_pos := {}
	for i in v.size():
		var p: Vector3 = v[i]
		var key := "%.3f,%.3f,%.3f" % [p.x, p.y, p.z]
		if not by_pos.has(key):
			by_pos[key] = ([] as Array)
		(by_pos[key] as Array).append(n[i])
	var limit := cos(deg_to_rad(crease))
	var shared := 0
	var hard := 0
	for key: String in by_pos:
		var ns: Array = by_pos[key]
		if ns.size() < 2:
			continue
		shared += 1
		for a in ns.size():
			var done := false
			for b in range(a + 1, ns.size()):
				if (ns[a] as Vector3).dot(ns[b]) > limit and (ns[a] as Vector3).distance_to(ns[b]) > 1e-4:
					hard += 1
					done = true
					break
			if done:
				break
	return 0.0 if shared == 0 else float(hard) / float(shared)


## **NOT EVERYTHING FACETED IS WRONG, AND THIS IS THE LIST THAT SAYS SO.**
##
## A share of hard corners reads like a defect report, so the next person to
## sweep for welding will find these near the top and round them off to make a
## number go green. They are faceted because the facets ARE the thing:
##
##   clints          limestone pavement is clints and grikes -- blocks broken at
##                   a stride, and the fissures between them are the landscape
##   cairn           a cairn has edges because somebody stacked it
##   standing stone  a quarried leaning slab and a snapped CAST machine leg;
##                   both were cut, neither was weathered round
##   salt ridge      plates of crust that met, buckled and tipped, standing on
##                   edge -- "a white tick with a cut under it, never a row of
##                   dashes", which is the builder's own note
##   pan gate        a machine. FOUND geometry is panelled and ruled by contract
##                   (CLAUDE.md): a seam that catches the light is the material
##
## If one of these ever needs welding, the argument has to be about what the
## thing IS, not about the number below.
const FACETED_ON_PURPOSE: Array[int] = [PropKind.CLINTS, PropKind.CAIRN,
	PropKind.STANDING_STONE, PropKind.SALT_RIDGE, PropKind.PAN_GATE]


func test_what_is_faceted_on_purpose_keeps_its_edges() -> void:
	for kind: int in FACETED_ON_PURPOSE:
		var t := PropModels.template(kind, 0, Country.COAST)
		gt(float(t.made_v.size()), 8.0, "%s is built" % PropKind.NAMES[kind])
		gt(_hard_share(t.made_v, t.made_n, Rocks.ROCK_CREASE), 0.15,
			"%s keeps the edges that ARE it -- see FACETED_ON_PURPOSE before welding this" % PropKind.NAMES[kind])
