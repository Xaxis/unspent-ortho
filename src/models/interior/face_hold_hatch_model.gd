extends RefCounted
## THE MOUTH OF A FACE SETTLEMENT, as a player finds it in a junction room's
## wall (docs/MIDDENS_ROOMS.md §2): a timbered mouth cut into the refuse, shored
## either side with salvaged panels (a door, a sign, sheet), a cloth hung across
## the dark half drawn back, and cable looped over the lintel. People live
## behind it: it is the one door in the middens that looks kept. Built in the
## hatch's own frame: +X is the way out, the ground at y 0; 21_doors stands it at
## the threshold's host, just inside the face line.

const Kit := preload("res://src/models/props/kit.gd")
# Everything here goes in `made`, the one mesh built (Kit.rod draws into `found`).
## What stops a body: the face itself already does; this is the shoring's reach.
const REACH := 0.3
## Its drawn box in its own frame and its height (21_doors `sight_boxes`).
const LO := Vector2(0.0, -1.6)
const HI := Vector2(0.95, 1.6)
const TOP := 2.4
## The mouth: a door's width and a person's height, and the shoring beside it.
const HALF := 0.55
const HIGH := 2.05
const SHORE := 1.5
## The host is inside the face (Threshold.of_face: 0.4 behind the face line), and
## the face is warped round that line: the mouth is built this far out so it
## stands proud of the refuse and is not buried in it.
const PROUD := 0.45


static func node(mat: Material) -> Node3D:
	var k := Kit.new()
	var timber := GroundColors.made(Color(0.22, 0.15, 0.1), GroundColors.TIMBER)
	var dark := GroundColors.made(Color(0.02, 0.02, 0.025), GroundColors.TAR)
	var cloth := GroundColors.made(Color(0.34, 0.28, 0.2), GroundColors.CLOTH)
	var cable := GroundColors.made(Color(0.08, 0.08, 0.09), GroundColors.TAR)
	var panels: Array[Color] = [Color(0.3, 0.13, 0.09), Color(0.14, 0.18, 0.24), Color(0.36, 0.33, 0.28), Color(0.2, 0.22, 0.18)]
	k.made.push(Transform3D(Basis(), Vector3(PROUD, 0.0, 0.0)))
	# The posts and the lintel, stood a hand out of the refuse.
	for z: float in [-HALF - 0.12, HALF]:
		k.made.box(Vector3(-0.08, 0.0, z), Vector3(0.1, HIGH + 0.14, z + 0.12), timber, timber)
	k.made.box(Vector3(-0.08, HIGH, -HALF - 0.14), Vector3(0.12, HIGH + 0.16, HALF + 0.14), timber, timber)
	# The dark inside.
	k.made.quad(Vector3(-0.05, 0.0, -HALF), Vector3(-0.05, HIGH, -HALF),
		Vector3(-0.05, HIGH, HALF), Vector3(-0.05, 0.0, HALF), dark)
	# The cloth, hung from the lintel and drawn back to one side.
	k.made.box(Vector3(0.0, 0.25, -HALF), Vector3(0.04, HIGH, -HALF + 0.38), cloth, cloth)
	k.made.box(Vector3(0.0, HIGH - 0.3, -HALF + 0.38), Vector3(0.04, HIGH, HALF), cloth, cloth)
	# Salvaged panels shoring the face either side, each its own paint, leaning.
	for side: float in [-1.0, 1.0]:
		for i in 2:
			var z0 := side * (HALF + 0.14 + float(i) * (SHORE - HALF) * 0.5)
			var z1 := z0 + side * (SHORE - HALF) * 0.5 - side * 0.04
			var col := GroundColors.made(panels[(i * 2 + (1 if side > 0.0 else 0)) % panels.size()], GroundColors.ENAMEL)
			var h := HIGH - 0.2 - 0.25 * float(i)
			k.made.box(Vector3(-0.04, 0.0, minf(z0, z1)), Vector3(0.06, h, maxf(z0, z1)), col, col)
	# Cable looped over the lintel.
	for n in 3:
		var z := -HALF + float(n) * HALF
		k.made.strut(Vector3(0.16, HIGH + 0.18, z), Vector3(0.2, HIGH - 0.12, z + HALF * 0.5), 0.025, 5, cable)
	k.made.pop()
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = k.made.build()
	mi.material_override = mat
	node.add_child(mi)
	return node
