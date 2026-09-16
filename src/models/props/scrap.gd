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
## Iron dust, near black with a blue sheen. It was a step lighter and sat within
## three luminance steps of the wood's own floor once that floor was given the
## colour it should always have had, so a cone of filings read as a smudge. A
## heap is the darkest mass in this wood; the shards and the combing on it are
## the only bright things, which is what makes it read as HELD UP.
const FILING := Color(0.1176, 0.1333, 0.1804)


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.SCRAP_TREE: tree(k, v, c)
		PropKind.MAGNET_HEAP: heap(k, v)


## A broadleaf that took a dead hauler for a trellis: the ribs of its frame
## still stand inside the trunk, a plate or two caught in the fork, and the bark
## has closed over the rest. The crown is the hand's; the ribs never bend.
##
## The camera looks DOWN on this wood, so the frame has to clear the crown or
## the player never learns what these trees are: two ribs carry on past the
## leaves with a level bar between them, and the plate hangs in the fork on top,
## where a crown cannot hide it.
static func tree(k: Kit, v: int, c: int = 0) -> void:
	var s := 610 + v * 31
	var lean := Vector2(Kit.j(s, 1, 0.12), Kit.j(s, 2, 0.1))
	var h := 2.1 + v * 0.45
	var bark := P.EARTH[2].lerp(RUSTED, 0.25)
	# The ruled frame first, standing OUTSIDE the trunk so both drawings show:
	# the tree grew up through the cage and closed on it, it did not swallow it.
	var ribs := 3 + v % 2
	for i in ribs:
		var a := float(i) / ribs * TAU + 0.3
		var foot := Vector3(cos(a) * 0.42, 0.0, sin(a) * 0.42)
		var head := Vector3(cos(a) * 0.26, h * (0.5 + (i % 2) * 0.14), sin(a) * 0.26)
		k.rod(foot, head, 0.03, 5, P.PLATE[2] if i % 2 == 0 else P.PLATE[3])
		# A cross member, exactly level, going nowhere.
		var next := float((i + 1) % ribs) / ribs * TAU + 0.3
		k.rod(Vector3(cos(a) * 0.34, h * 0.26, sin(a) * 0.34),
			Vector3(cos(next) * 0.34, h * 0.26, sin(next) * 0.34), 0.02, 4, P.PLATE[3])
	# One plate still bolted across two ribs, rubbed bright on its lower edge,
	# clear of the crown so it reads against the ground.
	var pa := 0.3
	k.plate(Vector3(cos(pa) * 0.4, h * 0.2, sin(pa) * 0.4), Vector3(cos(pa + 2.1) * 0.4, h * 0.2, sin(pa + 2.1) * 0.4),
		Vector3(cos(pa + 2.1) * 0.34, h * 0.46, sin(pa + 2.1) * 0.34), Vector3(cos(pa) * 0.34, h * 0.46, sin(pa) * 0.34),
		P.PLATE[2], P.PLATE[1], P.PLATE[4])
	# Two of the ribs never stopped: they carry on out of the leaves with a bar
	# across them, so from above this wood is green blobs with a ruler through
	# every one of them and reads as nothing else.
	var ma := 0.8 + Kit.j(s, 3, 0.6)
	var mast := h * (1.42 + v % 2 * 0.12)
	var m0 := Vector3(cos(ma) * 0.24, 0.0, sin(ma) * 0.24)
	var m1 := Vector3(cos(ma + PI) * 0.26, 0.0, sin(ma + PI) * 0.26)
	var top0 := Vector3(m0.x * 0.5 + lean.x * mast * 0.7, mast, m0.z * 0.5 + lean.y * mast * 0.7)
	var top1 := Vector3(m1.x * 0.5 + lean.x * mast * 0.6, mast * 0.86, m1.z * 0.5 + lean.y * mast * 0.6)
	k.rod(m0 + Vector3(0, h * 0.28, 0), top0, 0.05, 5, P.PLATE[2])
	k.rod(m1 + Vector3(0, h * 0.28, 0), top1, 0.04, 5, P.PLATE[3])
	# A bar across them, level, reaching out past the leaves on both sides: from
	# above it is a straight line laid over a hand-drawn blob, and nothing else
	# in the wood makes that shape.
	var bar_y := mast * 0.8
	var bd := Vector3(cos(ma + 1.57), 0.0, sin(ma + 1.57))
	var bc := Vector3(lean.x * bar_y * 0.7, bar_y, lean.y * bar_y * 0.7)
	# A step brighter than the frame under it, because this is the one straight
	# line the player sees from above: at PLATE[3] it was dark slate over a dark
	# crown and read as a dead branch, so the wood read as a wood with snags in it
	# rather than a wood grown through machines (playtest 6). It stops at PLATE[4]:
	# the rubbed step over it clipped white under this landscape's lift, and a
	# white stick laid across every crown is louder than the tree.
	k.rod(bc - bd * 0.78, bc + bd * 0.62, 0.036, 4, P.PLATE[4])
	# A stay from the mast head out to the cage foot, clear of the crown.
	k.rod(top0, Vector3(cos(ma + 2.4) * 0.5, h * 0.12, sin(ma + 2.4) * 0.5), 0.022, 4, P.PLATE[2])
	# The plate caught in the fork, lying ON the crown where the light finds it.
	# This is the ONE thing that says "a tree closed over a frame" at the zoom a
	# player actually walks at: at zoom 12 a crown is about twenty pixels across,
	# so a plate at 0.58 of a tile covered four of them in the crown's own dark
	# and the wood read as ordinary broadleaf (playtest 6, and the review after
	# it). Half again as wide, lifted clear of the leaves, and a step up the
	# ramp, so it is a hard bright quadrilateral over a soft dark blob — which is
	# Law 3 twice over and the only shape in the game that makes it.
	var fa := ma + 1.3
	var fx := lean.x * h * 0.85
	var fz := lean.y * h * 0.85
	var fy := h * 1.12
	k.plate(Vector3(fx + cos(fa) * 0.88, fy, fz + sin(fa) * 0.88),
		Vector3(fx + cos(fa + 1.5) * 0.94, fy + 0.13, fz + sin(fa + 1.5) * 0.94),
		Vector3(fx + cos(fa + 2.7) * 0.82, fy + 0.24, fz + sin(fa + 2.7) * 0.82),
		Vector3(fx + cos(fa + 4.3) * 0.72, fy + 0.1, fz + sin(fa + 4.3) * 0.72),
		P.PLATE[4], P.PLATE[3], P.PLATE[5])
	# The trunk, swelling where it grew round the frame.
	var mid := Vector3(lean.x * h * 0.5, h * 0.5, lean.y * h * 0.5)
	k.limb(Vector3.ZERO, mid, 0.19, 0.13, 7, bark)
	k.limb(mid, Vector3(lean.x * h, h * 0.92, lean.y * h), 0.13, 0.075, 6, bark)
	# A collar of swollen bark where it took the frame in, wide enough to close
	# over the ribs it reaches.
	k.made.push(Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, h * 0.26, 0)))
	k.made.prism(0, 0, 0, 0.3, 0.17, 0.26, 7, Kit.tone(bark, 0.88), bark)
	k.made.pop()
	# Boughs and a lumpy crown, the hand's shapes, hatched underneath. A
	# landscape that colours its own trees says so (BiomeDef.tree_tints): the
	# leaves that grew in a metal taste are not the coast's greens.
	var tints: Dictionary = BiomeRegistry.by_index(c).tree_tints
	var own_leaf: Array = tints.get(&"leaf", [])
	var leaf: Color = own_leaf[v % own_leaf.size()] if not own_leaf.is_empty() else P.MOSS[3].lerp(P.SPRUCE[3], 0.3)
	var under := Kit.tone(leaf, 0.72)
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
## with shards on end in it like grass that cuts. The shards are the point: they
## stand clear of the cone and break its line, so the heap reads as something
## held up rather than something tipped.
static func heap(k: Kit, v: int) -> void:
	var s := 660 + v * 19
	var r := 0.52 + v * 0.16
	# Taller than it is wide, because a cone of dust that stands up on its own is
	# the whole point and a low one reads as something tipped out of a barrow.
	var h := 0.76 + v * 0.22
	# A lit top on a near-black body, so the cone reads AS a cone from above and
	# not as a hole cut in the floor.
	k.stone(0, 0, 0, r, h, s, FILING, 7, 0.18, Kit.tone(FILING, 1.9))
	# The cone is combed too: the filings lie along the field, not at random.
	for i in 9:
		var a := float(i) / 9.0 * TAU
		var foot := Vector3(cos(a) * r * 1.02, 0.015, sin(a) * r * 1.02)
		k.fleck(foot, foot * 0.2 + Vector3(0, h * 1.0, 0), foot * 0.3 + Vector3(0.03, h * 0.86, 0.02),
			P.RUST[2] if i % 3 == 0 else Kit.tone(FILING, 1.5))
	# Shards standing on end, drawn up by the same pull: exact, because a
	# machine cut them and the field only stood them up. They lean OUT along the
	# lines of the field, so the camera — which is over this, not beside it —
	# reads a splayed burst and not the grey lump a cone of dark filings makes
	# from above (playtest 6: no heap was legible in any frame).
	for i in 7 + v * 2:
		var a := float(i) * 2.2 + Kit.j(s, i, 0.5)
		var d := r * (0.55 + Kit.j(s, 10 + i, 0.3))
		var base := Vector3(cos(a) * d, h * 0.45, sin(a) * d)
		var up := 0.34 + absf(Kit.j(s, 30 + i, 0.22))
		var out := 0.26 + absf(Kit.j(s, 50 + i, 0.16))
		var tilt := Vector3(cos(a) * out + Kit.j(s, 20 + i, 0.1), up, sin(a) * out + Kit.j(s, 40 + i, 0.1))
		k.rod(base, base + tilt, 0.018, 4, P.PLATE[3] if i % 2 == 0 else P.PLATE[4])
	# And the ground it stands on is combed too: swarf dragged in toward the heap
	# in fine lines, which from above is the one mark nothing else in the wood
	# makes. It reaches past the cone, so the shape on the page is wider than the
	# heap and reads as a pull rather than a pile.
	#
	# They lie along the FIELD, not out from the heap: a ring of them at even
	# spacing is a starburst, which is a firework and not a magnet. So the lines
	# fan about one axis, two lobes of them, the way filings lie on a page over a
	# bar. Twice as many as before and a step off the floor rather than a step
	# off the heap, because at 1.15 of the filing colour they were a few flecks
	# lost in the ground and the comb is the whole tell.
	var fd := Kit.j(s, 90, 3.14)
	for i in 22:
		var lobe := 1.0 if i % 2 == 0 else -1.0
		var spread := (float(i / 2) / 10.0 - 0.5) * 1.7 + Kit.j(s, 60 + i, 0.16)
		var a := fd + spread * lobe + (0.0 if lobe > 0.0 else PI)
		var near := Vector3(cos(a) * r * 1.05, 0.012, sin(a) * r * 1.05)
		var far := near * (1.9 + absf(Kit.j(s, 70 + i, 0.8)))
		far.y = 0.012
		k.fleck(near, far, far + Vector3(0.045, 0.0, 0.045),
			P.RUST[2] if i % 5 == 0 else Kit.tone(FILING, 1.85))
	# Where the pull came from: the corner of the frame itself, standing out of
	# the filings beside the heap with a stub of its own reaching up.
	var corner := Vector3(r * 1.25, 0.0, -r * 0.9)
	k.chamfer(corner.x, -0.03, corner.z, 0.2, 0.3, 0.13, 0.035, P.PLATE[2], P.PLATE[3])
	k.rod(corner + Vector3(0.0, 0.26, 0.0), corner + Vector3(-0.2, 0.72, -0.12), 0.024, 4, P.PLATE[3])
