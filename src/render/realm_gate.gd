class_name RealmGate
## The drawn gate of a portal (docs/VISION.md §4: "a portal is a place, drawn and
## sounded, never a menu"). Two draws, both idioms visible at once, which is what
## a MENDED thing is (docs/ART.md, VISION §6): the machines' ruled plate collar
## and headframe sunk into the rock, and the ladder somebody hung down it after
## they stopped coming.
##
##   RealmGate.node(portal, made_material) -> Node3D
##
## A shaft is a HOLE, and at this camera a hole is seen from above, so the
## drawing starts with the hole: floor, four cut walls, a plate collar round the
## lip, and the ladder hanging IN it. A frame standing on the ground with a black
## rectangle painted on it reads as a door, and a door is not a way down.
##
## The model faces +X, like every other model in the game, and the caller turns
## it with `rotation.y = -portal.facing`. It has no collision: a shaft is walked
## up to and used, never bumped into.

const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")
const Kit := preload("res://src/models/props/kit.gd")

## The shaft, in tiles: how wide the hole is across, how far the headframe stands
## over it, how far back it is cut and how deep the drawn shaft goes. Sized to
## read at 640x360 from across a hall: the frame is twice a person's height.
const WIDE := 1.9
const TALL := 2.6
const DEEP := 0.5
## The mouth is drawn lying ON the ground (a hair above it, so it is never in a
## fight with the terrain for the same pixel), and the cut rock across its far
## side stands this proud of it.
const LIE := 0.035
const LIP := 0.42

## The dark at the bottom of it. Never pure black (docs/ART.md: nothing in the
## world is, the outline pen included) — one step up off the ink, so the shaft is
## a depth and not a hole cut in the page.
const MOUTH := Color(0.0706, 0.0667, 0.1137)
## The cut rock of its walls, and the one wall the strip above reaches.
const SHAFT := Color(0.0892, 0.1064, 0.1412)
const SHAFT_LIT := Color(0.1373, 0.1843, 0.2392)
## The plate the frame is cut from, its lit top face and its shadowed parts.
const PLATE := Color(0.2536, 0.2892, 0.3655)
const PLATE_TOP := Color(0.3511, 0.3906, 0.4811)
const PLATE_DARK := Color(0.1687, 0.1962, 0.2518)
## The timber somebody lashed a ladder out of, and the cord they lashed it with.
const TIMBER := Color(0.3098, 0.2118, 0.1529)
const CORD := Color(0.5882, 0.5412, 0.4627)


static func node(portal: Portal, made_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "gate_%d" % portal.id
	var found := MeshKit.new()
	found.style = Ink.NONE
	found.style2 = Ink.NONE
	var made := MeshKit.new()
	made.style = Ink.HAND
	made.style2 = Ink.HAND
	_frame(found, portal)
	_ladder(made, portal)
	var f := MeshInstance3D.new()
	f.name = "found"
	f.mesh = found.build()
	f.material_override = PropModels.found_material()
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(f)
	var m := MeshInstance3D.new()
	m.name = "made"
	m.mesh = made.build()
	m.material_override = made_material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	return root


## Where the gate's own lights are, in its own frame and colour, in the shape
## `PropModels.glow_points` uses, so whoever mirrors lights in wet ground can
## read this one too. The beacon blinks on the machines' beat; the strip under
## the lintel is steady.
static func glow_points() -> Array:
	return [
		{"at": Vector3(-DEEP - 0.61, TALL + 0.2, 0.0), "color": Works.BEACON, "blink": true},
		{"at": Vector3(-DEEP - 0.46, TALL - 0.13, 0.0), "color": Works.STRIP},
	]


## The hole, and the ruled iron round it. Nothing here jitters.
##
## EVERYTHING IS DRAWN ABOVE THE GROUND. A shaft modelled the obvious way — a
## floor a tile down with four cut walls rising to the lip — is invisible: the
## terrain is a solid mesh and the whole hole sits behind it, which is how the
## first one came out as a headframe standing on unbroken rock. So the depth is
## drawn instead of modelled: a dark plan lying on the surface, a second darker
## one inside it, a rim of cut rock standing proud across the far side, and the
## head of the ladder coming up out of it.
static func _frame(k: MeshKit, portal: Portal) -> void:
	var half := WIDE * 0.5
	var x0 := -DEEP - 0.55
	var x1 := 0.35
	# The mouth in plan, and the dark inside it: two steps, so it reads as a shaft
	# going down and not as a patch of shade on the ground.
	# Wound the way `MeshKit.box` winds its +Y face — (x0,z0), (x0,z1), (x1,z1),
	# (x1,z0). The other way round the normal points at the floor and the quad is
	# culled, which is exactly as invisible as burying it under the terrain.
	k.quad(Vector3(x0, LIE, -half), Vector3(x0, LIE, half), Vector3(x1, LIE, half), Vector3(x1, LIE, -half), SHAFT)
	k.quad(Vector3(x0 + 0.2, LIE + 0.01, -half + 0.2), Vector3(x0 + 0.2, LIE + 0.01, half - 0.2),
		Vector3(x1 - 0.2, LIE + 0.01, half - 0.2), Vector3(x1 - 0.2, LIE + 0.01, -half + 0.2), MOUTH)
	# The rim of cut rock across the far side, standing proud of the ground: the
	# one face of the shaft a body looking down into it can actually see.
	k.box(Vector3(x0 - 0.06, LIE, -half), Vector3(x0 + 0.06, LIP, half), SHAFT_LIT, SHAFT_LIT)
	# The collar: four plates laid round the lip, the pale ruled ring that says a
	# hole is a hole. `box` takes its corners in order, low to high on every axis:
	# written the other way round on one side its faces wind backwards and that
	# plate is not drawn at all.
	k.box(Vector3(x0 - 0.22, 0.0, -half - 0.22), Vector3(x1 + 0.22, 0.13, -half), PLATE, PLATE_TOP)
	k.box(Vector3(x0 - 0.22, 0.0, half), Vector3(x1 + 0.22, 0.13, half + 0.22), PLATE, PLATE_TOP)
	k.box(Vector3(x0 - 0.22, 0.0, -half), Vector3(x0 - 0.06, 0.13, half), PLATE, PLATE_TOP)
	k.box(Vector3(x1, 0.0, -half), Vector3(x1 + 0.22, 0.13, half), PLATE, PLATE_TOP)
	# The headframe: two legs on the far lip, a lintel across them, a strut back
	# to the near collar on each side, rivets up each leg.
	for side: float in [-1.0, 1.0]:
		var z := side * (half + 0.08)
		k.box(Vector3(x0 - 0.16, 0.0, z - 0.11), Vector3(x0 + 0.04, TALL - 0.22, z + 0.11), PLATE, PLATE_TOP)
		_strut(k, Vector3(x0 - 0.06, TALL - 0.5, z), Vector3(x1 + 0.12, 0.1, z), 0.055, PLATE_DARK)
		for i in 3:
			k.block(x0 + 0.05, 0.45 + i * 0.7, z, 0.03, 0.07, 0.07, PLATE_DARK)
	k.box(Vector3(x0 - 0.2, TALL - 0.22, -half - 0.26), Vector3(x0 + 0.08, TALL + 0.02, half + 0.26), PLATE, PLATE_TOP)
	# The strip under the lintel: the one thing here still drawing power, and the
	# whole of what lights the lip of the hole.
	k.quad(Vector3(x0 + 0.09, TALL - 0.2, half + 0.2), Vector3(x0 + 0.09, TALL - 0.2, -half - 0.2),
		Vector3(x0 + 0.09, TALL - 0.06, -half - 0.2), Vector3(x0 + 0.09, TALL - 0.06, half + 0.2), Works.STRIP)
	# The shaft's number, stamped as that many short bars: a machine's mark is a
	# shape and never a glyph at 640x360.
	for i in portal.id + 1:
		k.block(x0 + 0.1, TALL - 0.44, -0.2 + i * 0.16, 0.03, 0.12, 0.07, Works.STRIP)
	# The beacon on the lintel, big enough to be a light and not a speck.
	k.prism(x0 - 0.06, TALL + 0.02, 0.0, 0.14, TALL + 0.16, 0.11, 6, PLATE_DARK)
	k.prism(x0 - 0.06, TALL + 0.16, 0.0, 0.12, TALL + 0.3, 0.06, 6, Works.BEACON, Works.BEACON)


## What people did to it afterwards: the head of a ladder coming up out of the
## mouth, and a cord tied off on the collar. MADE, so it is hatched and uneven —
## and it is the whole of what says a shaft can be walked down, so it stands well
## proud of the ground rather than hanging where nothing can see it.
static func _ladder(k: MeshKit, portal: Portal) -> void:
	var seed_value := portal.id * 37 + 11
	var half := WIDE * 0.5
	var top := Vector3(0.14, 0.72, 0.0)
	var foot := Vector3(-DEEP - 0.2, LIE + 0.02, 0.0)
	for side: float in [-1.0, 1.0]:
		var off := Vector3(0.0, 0.0, side * 0.32)
		_limb(k, foot + off, top + off, 0.055, TIMBER, seed_value + int(side * 3.0))
	for i in 5:
		var t := 0.12 + i * 0.19
		var at := foot.lerp(top, t)
		k.block(at.x, at.y, at.z, 0.07, 0.05, 0.70, Kit.tone(TIMBER, 1.15 + Kit.j(seed_value, i, 0.08)))
	# A cord tied off on the collar and slung across the mouth.
	var tie := Vector3(x_edge(), 0.16, -(half + 0.1))
	var far := Vector3(-DEEP - 0.45, 0.16, half + 0.1)
	for i in 4:
		var a := tie.lerp(far, i / 4.0)
		var b := tie.lerp(far, (i + 1) / 4.0)
		a.y -= 0.1 * sin(PI * i / 4.0)
		b.y -= 0.1 * sin(PI * (i + 1) / 4.0)
		_limb(k, a, b, 0.024, CORD, seed_value + 40 + i)
	# The stone somebody wedged under the near stile so it would not slip.
	k.rock(0.42, 0.0, 0.42, 0.18, 0.14, seed_value + 91, P.SLATE[2], 5)


## The near edge of the collar, in the model's own frame.
static func x_edge() -> float:
	return 0.35 + 0.22


## A ruled brace between two points (FOUND: no jitter, square ends).
static func _strut(k: MeshKit, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 1e-5:
		return
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	k.push(Transform3D(Basis(side, up, side.cross(up)), a))
	k.prism(0, 0, 0, r, length, r, 4, col)
	k.pop()


## A slightly bent MADE limb from a to b (the kit's own shape, without a Kit).
static func _limb(k: MeshKit, a: Vector3, b: Vector3, r: float, col: Color, seed_value: int) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 1e-5:
		return
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	k.push(Transform3D(Basis(side, up, side.cross(up)), a))
	k.prism(0, 0, 0, r * (1.0 + Kit.j(seed_value, 1, 0.12)), length, r * 0.82, 5, col)
	k.pop()
