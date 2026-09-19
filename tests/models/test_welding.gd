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
