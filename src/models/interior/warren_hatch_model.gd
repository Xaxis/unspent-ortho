extends RefCounted
## THE WAY INTO A CONTAINER WARREN, as a player finds it at a blind alley's end
## (docs/MIDDENS_ROOMS.md): a shipping container's end, set flush in the refuse
## of the slot face where the heap was poured over it. Its frame in the paint it
## was shipped in gone dark, one door leaf hung ajar on its bars and the other
## shut, the dark of the container behind. Built in the hatch's own frame: +X is
## the way out, the ground at y 0; 21_doors stands it at the threshold's host,
## which for a door in a face is just inside the face line.

const Kit := preload("res://src/models/props/kit.gd")
# Everything here goes in `made`, the one mesh built: Kit.rod draws into `found`,
# which a hatch never builds, so its bars were never drawn.
## What stops a body: the face itself already does; this is the doors' swing.
const REACH := 0.35
## Its drawn box in its own frame and its height (21_doors `sight_boxes`).
const LO := Vector2(-0.4, -1.3)
const HI := Vector2(0.9, 1.3)
const TOP := 2.6
## The container's end: 2.4 across, 2.5 high.
const HALF := 1.2
const HIGH := 2.5


static func node(mat: Material) -> Node3D:
	var k := Kit.new()
	var paint := GroundColors.made(Color(0.24, 0.1, 0.07), GroundColors.ENAMEL)
	var frame := GroundColors.made(Color(0.13, 0.07, 0.05), GroundColors.ENAMEL)
	var bar := GroundColors.made(Color(0.1, 0.1, 0.1), GroundColors.ENAMEL)
	var dark := GroundColors.made(Color(0.02, 0.02, 0.025), GroundColors.TAR)
	# The frame: corner posts, the header and the sill, standing a hand out of the
	# refuse round it.
	for z: float in [-HALF, HALF - 0.14]:
		k.made.box(Vector3(-0.1, 0.0, z), Vector3(0.12, HIGH, z + 0.14), frame, frame)
	k.made.box(Vector3(-0.1, HIGH - 0.16, -HALF), Vector3(0.12, HIGH, HALF), frame, frame)
	k.made.box(Vector3(-0.1, 0.0, -HALF), Vector3(0.14, 0.08, HALF), frame, frame)
	# The dark inside, across the whole end.
	k.made.quad(Vector3(-0.05, 0.08, -HALF + 0.14), Vector3(-0.05, HIGH - 0.16, -HALF + 0.14),
		Vector3(-0.05, HIGH - 0.16, HALF - 0.14), Vector3(-0.05, 0.08, HALF - 0.14), dark)
	# One leaf shut in the frame, corrugated, its two locking bars down it.
	for r in 6:
		var z0 := -HALF + 0.14 + float(r) * 0.17
		var out := 0.0 if (r & 1) == 0 else -0.03
		k.made.box(Vector3(out, 0.08, z0), Vector3(out + 0.05, HIGH - 0.16, z0 + 0.17), paint, paint)
	for z: float in [-0.75, -0.35]:
		k.made.strut(Vector3(0.08, 0.12, z), Vector3(0.08, HIGH - 0.2, z), 0.025, 6, bar)
	# The other leaf hung ajar, swung a third open, the gap the way in.
	var hinge := Vector3(0.05, 0.08, HALF - 0.14)
	var swing := Vector3(0.55, 0.0, -0.95).normalized() * 1.06
	var tip := hinge + swing
	k.made.box(Vector3(minf(hinge.x, tip.x), 0.08, minf(hinge.z, tip.z)), Vector3(maxf(hinge.x, tip.x) + 0.05, HIGH - 0.16, maxf(hinge.z, tip.z) + 0.03), paint, paint)
	for u: float in [0.35, 0.75]:
		var q := hinge + swing * u + Vector3(0.06, 0.0, 0.0)
		k.made.strut(Vector3(q.x, 0.12, q.z), Vector3(q.x, HIGH - 0.2, q.z), 0.025, 6, bar)
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = k.made.build()
	mi.material_override = mat
	n.add_child(mi)
	return n
