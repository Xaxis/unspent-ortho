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
## still stand inside the trunk, a sheet of its plate caught up in the crown, and
## the bark has closed over the rest. The crown is the hand's; the ribs never
## bend.
##
## The camera looks DOWN on this wood, so the frame has to clear the crown or
## the player never learns what these trees are: two ribs carry on past the
## leaves with a level bar between them, and a sheet of plate lies IN the leaves,
## bent over a bough with the crown grown up round it (`_caught_sheet`).
##
## That sheet was, for the whole life of this model, a slab laid on top of the
## crown facing the ground, and found.gdshader culls a face turned away from the
## camera, so from every bearing the play camera can take it drew nothing: a
## playtest asked for it bigger, a review asked again, and nobody could see that
## there was nothing there. Turned over it would have been a table top on every
## tree, wider than the crown under it. tests/render/test_found_drawn.gd holds
## every FOUND part of every prop to being drawn now.
## Six trees, and no two of them the same shape from above. Thirty near-identical
## mushroom crowns at one scale with the same ruled bar across every one of them
## is a texture and not a wood (art finding 5), and the fault was that the crown
## was a fixed size whatever the tree's height, and the mast and its bar were the
## same on every tree. So height, spread, how many arms, whether one side of the
## crown ever grew back, and what the machine left standing out of the top all
## move together. The bar stays on most of them, because it is the one straight
## line the player reads this wood BY.
const SPREAD: Array[float] = [0.82, 1.18, 0.95, 1.34, 0.74, 1.06]
const BOUGHS: Array[int] = [3, 4, 3, 5, 2, 4]
## How far the bar reaches each way: two of the six are stubs where the far half
## went, and no two trees carry the same length either side.
const BAR_BACK: Array[float] = [0.78, 0.64, 0.22, 0.86, 0.5, 0.3]
const BAR_OUT: Array[float] = [0.62, 0.9, 0.7, 0.45, 0.83, 0.55]


static func tree(k: Kit, v: int, c: int = 0) -> void:
	var s := 610 + v * 31
	var lean := Vector2(Kit.j(s, 1, 0.12), Kit.j(s, 2, 0.1))
	var h := 1.85 + float(v) * 0.34
	# A crown against its own height, not a fixed blob: a young tree is a tight
	# ball and an old one is wide and flat.
	var spread := SPREAD[v % SPREAD.size()]
	var crown := (0.30 + h * 0.085) * spread
	# Two in six lost a side of the crown to whatever came through here.
	var gap := v % 3 == 1
	var bark := P.EARTH[2].lerp(RUSTED, 0.25)
	# The ruled frame first, standing OUTSIDE the trunk so both drawings show:
	# the tree grew up through the cage and closed on it, it did not swallow it.
	var ribs := 3 + v % 2
	for i in ribs:
		var a := float(i) / ribs * TAU + 0.3
		var foot := Vector3(cos(a) * 0.42, 0.0, sin(a) * 0.42)
		var head := Vector3(cos(a) * 0.26, h * (0.5 + (i % 2) * 0.14), sin(a) * 0.26)
		k.rod(foot, head, 0.03, 5, P.PLATE[2] if i % 2 == 0 else P.PLATE[3])
		# A cross member, exactly level, going nowhere: a stub off the rib along
		# the line the frame once ran. It was a ring from rib to rib, and a chord
		# between two ribs a third of a turn apart runs straight through the trunk
		# and its collar, so the whole ring was inside the bark.
		var at := Vector3(cos(a) * 0.35, h * 0.3, sin(a) * 0.35)
		var run := Vector3(-sin(a), 0.0, cos(a)) * (0.2 + float(i % 2) * 0.08)
		k.rod(at, at + run, 0.02, 4, P.PLATE[3])
	# There was a plate bolted across two ribs down here too, turned in to the
	# trunk under the crown's shade, and no bearing of the camera ever showed it.
	# Turned out and moved to the foot it read as a plinth under every tree, so
	# the plate this tree is known by is the one in its crown.
	# Two of the ribs never stopped: they carry on out of the leaves with a bar
	# across them, so from above this wood is green blobs with a ruler through
	# every one of them and reads as nothing else.
	var ma := 0.8 + Kit.j(s, 3, 0.6)
	var mast := h * (1.26 + float(v % 3) * 0.13)
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
	# ...and it is not the same bar on every tree. Two in six have lost the far
	# half of it, so a frame of this wood carries long bars, short bars and stubs
	# rather than one length repeated thirty times. Six lengths, not three: the
	# slab that used to hang over the crown was the widest FOUND thing on half
	# these trees, and with it gone three of them reached exactly as far as each
	# other (tests/render/test_props.gd measures what the machine left standing).
	# Scaled by the tree's own spread as everything else here is, so no two of the
	# six reach the same distance out of the leaves.
	var bar_k := 0.7 + spread * 0.35
	k.rod(bc - bd * BAR_BACK[v % BAR_BACK.size()] * bar_k, bc + bd * BAR_OUT[v % BAR_OUT.size()] * bar_k, 0.036, 4, P.PLATE[4])
	# A stay from the mast head out to the cage foot, clear of the crown.
	k.rod(top0, Vector3(cos(ma + 2.4) * 0.5, h * 0.12, sin(ma + 2.4) * 0.5), 0.022, 4, P.PLATE[2])
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
	var boughs := BOUGHS[v % BOUGHS.size()]
	# The side that never grew back, on the trees that lost one.
	var bare := Kit.j(s, 4, 3.0) + 3.0
	var start := k.made.vertex_count()
	var leaf_start := k.leaf.vertex_count()
	# Leaf cards, as every crown is (props/kit.gd `canopy`): the one wash this
	# land dealt the tree, a step either side of it so the masses turn.
	var mass: Array[Color] = [leaf, Kit.tone(leaf, 0.88), Kit.tone(leaf, 1.1)]
	for i in boughs:
		var a := float(i) / boughs * TAU + Kit.j(s, 10 + i, 0.5)
		if gap and absf(angle_difference(a, bare)) < 0.9:
			continue
		var from := Vector3(lean.x * h * 0.7, h * (0.62 + (i % 2) * 0.09), lean.y * h * 0.7)
		var arm := crown * (1.05 + Kit.j(s, 20 + i, 0.3))
		var to := from + Vector3(cos(a) * arm, 0.3, sin(a) * arm)
		k.limb(from, to, 0.055, 0.03, 5, bark)
		var cr := crown * (0.92 + Kit.j(s, 40 + i, 0.22))
		k.canopy(to.x, to.y - 0.1, to.z, cr, crown * 1.1, s + i * 7, mass, Kit.LEAF_BROAD, Trees.BROAD_CARD, Trees.leaf_cards(cr, crown * 1.1, Trees.BROAD_CARD))
	# The top of the crown, pushed off the trunk away from the bare side.
	var off := Vector3(cos(bare), 0.0, sin(bare)) * (crown * -0.35 if gap else 0.0)
	k.canopy(lean.x * h + off.x, h * 0.88, lean.y * h + off.z, crown * 1.2, crown * 1.32, s + 99, mass, Kit.LEAF_BROAD, Trees.BROAD_CARD, Trees.leaf_cards(crown * 1.2, crown * 1.32, Trees.BROAD_CARD))
	# The sheet the crown grew up round: on the side away from the bar, and never
	# on the side that did not grow back, where there would be nothing to hold it.
	var sa := ma + PI + Kit.j(s, 5, 0.5)
	if gap and absf(angle_difference(sa, bare)) < 1.2:
		sa = bare + PI
	var top := Vector3(lean.x * h + off.x, h * 0.88 + crown * 1.32 * 0.46, lean.y * h + off.z)
	_caught_sheet(k, top, Vector3(crown * 1.2, crown * 1.32 * 0.54, crown * 1.2), sa, v, s)
	# The underside, one step darker, so the crown reads as a mass and not a blob.
	k.made.push(Transform3D(Basis.IDENTITY, Vector3(lean.x * h + off.x, h * 0.82, lean.y * h + off.z)))
	k.made.prism(0, 0, 0, crown * 0.96, 0.09, crown * 1.1, 7, under)
	k.made.pop()
	k.sway_by_height(start, h * 0.5, h, 0.6)
	k.sway_by_height(leaf_start, h * 0.5, h, 0.6, k.leaf)


## A sheet of the machine's plate caught up in the crown of the tree that grew
## through it: lying in the leaves on the crown's shoulder, bent down over the
## bough that holds it, the crown grown up round its edges. From above at play it
## is a hard straight-edged plane, lit like metal, with leaves over its rim --
## the one shape in the wood that says "grew through salvage" and not "has a
## snag in it" -- and it is a HAND's width of the crown, not a lid over it.
##
## `centre` and `radii` are the crown's top mass as `canopy` took it; `bearing`
## the side of the crown it lies on. Only the outer faces are drawn: the backs
## face into the crown, and no bearing of the play camera ever reaches them.
static func _caught_sheet(k: Kit, centre: Vector3, radii: Vector3, bearing: float, v: int, s: int) -> void:
	var out := Vector3(cos(bearing), 0.0, sin(bearing))
	# The hinge: where the bough holding it leaves the crown's skin, high on its
	# shoulder, a little proud so the leaves close over its edges and not over
	# its face. High, because a sheet down the flank faces half the bearings a
	# prop can be turned to and is a sliver over the crown's far rim at the rest.
	var el := 0.98 + Kit.j(s, 60, 0.1)
	var skin := 1.04
	var hinge := centre + out * radii.x * cos(el) * skin + Vector3.UP * radii.y * sin(el) * skin
	# Up the crown along its skin...
	var up_run := (-out * radii.x * sin(el) + Vector3.UP * radii.y * cos(el)).normalized()
	# ...and never square to it. A sheet laid level across a crown's shoulder
	# with a flap turned down over the edge is a little roof, and a crown with a
	# roof on it is a bird box: the fold runs across the slope at a slant, so
	# one end of the sheet is lodged deeper than the other.
	var slant := 0.5 + Kit.j(s, 63, 0.15)
	var flat := Vector3(-sin(bearing), 0.0, cos(bearing))
	var along := (flat * cos(slant) + up_run * sin(slant)).normalized()
	var across := (up_run - along * up_run.dot(along)).normalized()
	var size := radii.x
	var wide := size * (0.9 + float(v % 3) * 0.08)
	var reach := size * (0.72 + Kit.j(s, 61, 0.08))
	# Its low end sunk a little into the crown and its high end standing clear:
	# the sheet is bent to it, as a sheet that has hung in a tree for years is.
	# Not deeper than a leaf: sunk a fifth of the crown it was a shard glimpsed
	# on one tree in four at play, and the wood read as ordinary broadleaf again.
	var skin_n := (out * cos(el) / radii.x + Vector3.UP * sin(el) / radii.y).normalized()
	var a0 := hinge - along * wide * 0.5 - skin_n * size * 0.07
	var a1 := hinge + along * wide * 0.5 + skin_n * size * 0.06
	# Torn, not cut: one far corner is missing a bite, so the outline is never a
	# rectangle.
	var t0 := a0 + across * reach * 0.62 + along * wide * 0.2 + skin_n * size * 0.1
	var t1 := a1 + across * reach + along * wide * (0.04 + Kit.j(s, 62, 0.05)) + skin_n * size * 0.04
	var face_n := across.cross(along)
	if face_n.dot(out + Vector3.UP) < 0.0:
		face_n = -face_n
	_sheet(k, a0, a1, t1, t0, face_n, P.PLATE[4], Kit.tone(P.PLATE[4], 0.82), P.PLATE[5])
	if v % 2 == 1:
		# Half the sheets are bent where the bough caught them: a short lip under
		# the low end only, turned down into the leaves.
		var hang := (out * 0.55 + Vector3.DOWN * 0.84).normalized()
		var lip := size * 0.3
		var d0 := a0 + hang * lip
		var d1 := a0.lerp(a1, 0.55) + hang * lip * 0.7
		var lip_n := along.cross(hang)
		if lip_n.dot(out) < 0.0:
			lip_n = -lip_n
		_sheet(k, d0, d1, a0.lerp(a1, 0.55), a0, lip_n, P.PLATE[3], Kit.tone(P.PLATE[3], 0.82), P.PLATE[4])


## One sheet of plate, `k.plate` wound so it faces the way `facing` points --
## the winding is decided HERE, from the direction the sheet is meant to show,
## and never left to the order its corners happened to be written in, which is
## how the old crown plate came to face the ground.
static func _sheet(k: Kit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, facing: Vector3, col: Color, rim: Color, rivet: Color) -> void:
	# kit.gd `plate` faces (c - b) x (a - b).
	if (c - b).cross(a - b).dot(facing) < 0.0:
		var t := b
		b = d
		d = t
	k.plate(a, b, c, d, col, rim, rivet)


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
