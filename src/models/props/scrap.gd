extends RefCounted
## What stands in the Scrapwood: a wood that grew back through the machines that
## died in it. Every tree here is two drawings at once (docs/ART.md law 3) — a
## crown and a trunk by hand, and inside them the ruled ribs of something that
## stopped. The hand won, slowly, and the ruler is still there under the bark.
##
## The other thing this land has is what the iron does to itself: the fields
## left in a dead frame draw the filings up into cones that stand where nothing
## should stand, with shards on end in them like grass that cuts.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Trees := preload("res://src/models/props/trees.gd")

const RUSTED := Color(0.4314, 0.2000, 0.1255)
const FILING := Color(0.1843, 0.2118, 0.2745)


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.SCRAP_TREE: tree(k, v)
		PropKind.MAGNET_HEAP: heap(k, v)


## A broadleaf that took a dead hauler for a trellis: the ribs of its frame
## still stand inside the trunk, a plate or two caught in the fork, and the bark
## has closed over the rest. The crown is the hand's; the ribs never bend.
static func tree(k: Kit, v: int) -> void:
	var s := 610 + v * 31
	var lean := Vector2(Kit.j(s, 1, 0.12), Kit.j(s, 2, 0.1))
	var h := 2.1 + v * 0.45
	var bark := P.EARTH[2].lerp(RUSTED, 0.25)
	# The ruled frame first, so the tree closes over it.
	var ribs := 3 + v % 2
	for i in ribs:
		var a := float(i) / ribs * TAU + 0.3
		var foot := Vector3(cos(a) * 0.24, 0.0, sin(a) * 0.24)
		var head := Vector3(cos(a) * 0.1, h * (0.42 + (i % 2) * 0.12), sin(a) * 0.1)
		k.rod(foot, head, 0.026, 5, P.PLATE[2] if i % 2 == 0 else P.PLATE[3])
		# A cross member, exactly level, going nowhere.
		if i % 2 == 0:
			var across := Vector3(-sin(a) * 0.22, h * 0.3, cos(a) * 0.22)
			k.rod(head * Vector3(1, 0.7, 1), across, 0.018, 4, P.PLATE[3])
	# One plate still hanging in the fork, rubbed bright on its lower edge.
	k.plate(Vector3(0.18, h * 0.46, -0.2), Vector3(0.34, h * 0.5, 0.06),
		Vector3(0.3, h * 0.72, 0.1), Vector3(0.14, h * 0.68, -0.16),
		P.PLATE[2], P.PLATE[1], P.PLATE[4])
	# The trunk, swelling where it grew round the frame.
	var mid := Vector3(lean.x * h * 0.5, h * 0.5, lean.y * h * 0.5)
	k.limb(Vector3.ZERO, mid, 0.19, 0.13, 7, bark)
	k.limb(mid, Vector3(lean.x * h, h * 0.92, lean.y * h), 0.13, 0.075, 6, bark)
	# A collar of swollen bark where it took the frame in.
	k.made.push(Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, h * 0.3, 0)))
	k.made.prism(0, 0, 0, 0.215, 0.16, 0.175, 7, Kit.tone(bark, 0.88), bark)
	k.made.pop()
	# Boughs and a lumpy crown, the hand's shapes, hatched underneath.
	var leaf := P.MOSS[3].lerp(P.SPRUCE[3], 0.3)
	var under := P.SPRUCE[2]
	var boughs := 3 + v % 2
	var start := k.made.vertex_count()
	for i in boughs:
		var a := float(i) / boughs * TAU + Kit.j(s, 10 + i, 0.5)
		var from := Vector3(lean.x * h * 0.7, h * (0.62 + (i % 2) * 0.09), lean.y * h * 0.7)
		var to := from + Vector3(cos(a) * (0.48 + Kit.j(s, 20 + i, 0.14)), 0.3, sin(a) * (0.48 + Kit.j(s, 30 + i, 0.14)))
		k.limb(from, to, 0.055, 0.03, 5, bark)
		k.clump(to.x, to.y - 0.1, to.z, 0.42 + Kit.j(s, 40 + i, 0.09), 0.5, s + i * 7, leaf)
	k.clump(lean.x * h, h * 0.88, lean.y * h, 0.55, 0.62, s + 99, leaf)
	# The underside, one step darker, so the crown reads as a mass and not a blob.
	k.made.push(Transform3D(Basis.IDENTITY, Vector3(lean.x * h, h * 0.82, lean.y * h)))
	k.made.prism(0, 0, 0, 0.44, 0.09, 0.5, 7, under)
	k.made.pop()
	k.sway_by_height(start, h * 0.5, h, 0.6)


## A cone of iron filings standing where the field in a dead frame still pulls,
## with shards on end in it. Nothing grows within a pace of one.
static func heap(k: Kit, v: int) -> void:
	var s := 660 + v * 19
	var r := 0.4 + v * 0.14
	var h := 0.34 + v * 0.1
	k.clump(0, 0, 0, r, h, s, FILING)
	# The cone is combed: the filings lie along the field, not at random.
	for i in 9:
		var a := float(i) / 9.0 * TAU
		var foot := Vector3(cos(a) * r * 0.98, 0.015, sin(a) * r * 0.98)
		k.fleck(foot, foot * 0.2 + Vector3(0, h * 0.95, 0), foot * 0.3 + Vector3(0.025, h * 0.85, 0.02),
			P.RUST[2] if i % 3 == 0 else Kit.tone(FILING, 1.3))
	# Shards standing on end, drawn up by the same pull. Exact, because they
	# were cut by a machine and the field only stood them up.
	for i in 3 + v:
		var a := float(i) * 2.2 + Kit.j(s, i, 0.5)
		var d := r * (0.3 + Kit.j(s, 10 + i, 0.25))
		var base := Vector3(cos(a) * d, h * 0.25, sin(a) * d)
		var tilt := Vector3(Kit.j(s, 20 + i, 0.09), 0.3 + absf(Kit.j(s, 30 + i, 0.16)), Kit.j(s, 40 + i, 0.09))
		k.rod(base, base + tilt, 0.013, 4, P.PLATE[3] if i % 2 == 0 else P.PLATE[4])
	# Where the pull came from: a corner of the frame itself, half buried.
	k.chamfer(r * 0.45, -0.04, -r * 0.35, 0.16, 0.2, 0.1, 0.03, P.PLATE[2], P.PLATE[3])
	k.rod(Vector3(r * 0.45, 0.14, -r * 0.35), Vector3(r * 0.2, 0.42, -r * 0.55), 0.02, 4, P.PLATE[3])
