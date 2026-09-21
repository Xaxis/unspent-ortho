extends RefCounted
## The vocabulary every built piece is drawn out of (docs/ART.md §10, §12): posts
## that lean, cord that sits off true, thatch with a fringe the wind takes, and
## plate cut off a machine with the rivet row it was cut through still in it.
##
## Two rules hold all of it together and nothing here breaks them: the hand's
## half is `Ink.HAND`, crooked, in earth and sand and linen; the machine's half
## is `Ink.NONE`, ruled, symmetric, in the violet PLATE ramps. Where a cord
## crosses a panel it crosses the rivets, and that join is the drawing.

const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")

## Timber, cord and cloth. Kept as names because a builder reading a model wants
## to see what the thing is made of, not which step of which ramp.
##
## **AND NOW THE RENDERER IS TOLD THE SAME THING.** The names were already here
## and already right at all 158 call sites across the five settlement files —
## the only thing missing was that a colour reached the shader at alpha 1.0, so
## a lashing, a rag skin and a driftwood post all came back as one material and
## only the mesh normal told them apart. Tagging the PALETTE rather than the
## call sites is what makes that a five-line change instead of a sweep, and it
## cannot drift: a builder that picks from `TIMBER` gets timber by construction.
## `GroundColors.down`/`up`/`same_matter` and `Kit.tone` all preserve the alpha,
## and no `_found` builder in this package touches these ramps (checked: 158
## uses, none of them in one), which matters because a MADE mark on FOUND
## geometry is not a wrong material, it is a blinking beacon.
##
## `GroundColors.made`'s own rule is "never on a shared colour that might reach
## either", and these ARE shared colours — so the measurement above is what buys
## the exception, not the convenience. **It is also the thing that can go stale.**
## The day somebody writes a `_found` builder in this package that reaches for
## `Parts.TIMBER` because timber is what it wants, that piece starts blinking on
## the machines' beat, and nothing errors. The machine's half of this vocabulary
## is the PLATE ramps and `Works` — a `_found` builder has no business in these
## five names, and if one ever needs a colour from here it takes
## `GroundColors.marked(col, 0)` to strip the mark first.
##
## **TURF AND ASH ARE DELIBERATELY LEFT ALONE, and they are the dangerous two.**
## Sod banked at the foot of a wall really is turf and there really is a TURF
## row — but it is 40, a GROUND mark, and `world.gdshader` gives 40..70 the
## landscape's own ground treatment. That is not a hypothesis: `towers.gd`
## carries the frame where a deck drawn from a `wash()`-derived colour pulled a
## landscape's ground stipple over every roof in the settlement. A made surface
## takes a made mark or none.
static var TIMBER: Array[Color] = _matter(GroundColors.TIMBER, [P.EARTH[2], P.EARTH[3], P.EARTH[4]])
static var CORD: Color = GroundColors.made(P.SAND[3], GroundColors.ROPE)
static var CORD_DARK: Color = GroundColors.made(P.SAND[2], GroundColors.ROPE)
static var CLOTH: Array[Color] = _matter(GroundColors.CLOTH, [P.LINEN[2], P.LINEN[3], P.SAND[2]])
static var THATCH: Array[Color] = _matter(GroundColors.THATCH, [P.SAND[3], P.EARTH[4], P.LINEN[3]])
const TURF := P.MOSS[3]
const ASH := P.ASH[1]


static func _matter(kind: int, bag: Array[Color]) -> Array[Color]:
	var out: Array[Color] = []
	for c: Color in bag:
		out.append(GroundColors.made(c, kind))
	return out


## A number 0..1 from a piece's variant and a slot: every wobble, lean and
## mismatch in a drawing comes through here, so the same piece is the same
## drawing every time it is loaded and no two pieces of a kind are alike.
static func wob(variant: int, slot: int) -> float:
	return Rng.hash01(variant + 1, slot, 0x5E77)


## The same, centred on zero and scaled: `lean(v, 3, 0.2)` is a lean of up to a
## fifth of a tile either way.
static func lean(variant: int, slot: int, amount: float) -> float:
	return (wob(variant, slot) - 0.5) * 2.0 * amount


## One of a small ramp, chosen by the variant: which timber this spar was cut from.
static func pick(ramp: Array, variant: int, slot: int) -> Color:
	return ramp[int(wob(variant, slot) * float(ramp.size())) % ramp.size()]


static func hand(k: MeshKit) -> void:
	k.style = Ink.HAND
	k.style2 = Ink.HAND
	k.style_blend = 0.0
	k.sway = 0.0


static func ruled(k: MeshKit) -> void:
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	k.style_blend = 0.0
	k.sway = 0.0


## A post: a tapered spar, never plumb. `sink` puts its foot below the ground so
## a leaning post does not show daylight under it.
static func post(k: MeshKit, foot: Vector3, head: Vector3, r: float, col: Color) -> void:
	k.strut(foot - Vector3(0, 0.08, 0), head, r, 5, col)


## Cord, strap or lashing. It is drawn a little off true on purpose: a hand put
## it there, and where it crosses a ruled edge is what the eye is meant to catch.
static func lash(k: MeshKit, a: Vector3, b: Vector3, variant: int, slot: int, r: float = 0.028) -> void:
	var off := lean(variant, slot, 0.03)
	k.strut(a + Vector3(off, 0.0, -off), b + Vector3(-off, 0.0, off), r, 4,
		CORD if slot % 2 == 0 else CORD_DARK)


## An upright face between two ground points and the two points above them.
##
## **The winding rule, written down once**: walk the footprint anticlockwise in
## x-z (angle increasing) and give the face its two corners in the order
## `f0`, `f1`; it then looks OUTWARD. Every face in this package goes through
## here or follows the same order, because a wall wound the wrong way is
## invisible from the camera and the mistake costs a whole review pass to see.
static func wall(k: MeshKit, f0: Vector3, f1: Vector3, t0: Vector3, t1: Vector3, col: Color) -> void:
	k.quad(f1, f0, t0, t1, col)


## A flat thing with two sides — a rag, a blade, a vane. Drawn both ways round,
## because a single quad is invisible from behind and a thing that hangs, turns
## or flaps is seen from both sides in the same minute.
static func flag(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, front: Color, back: Color) -> void:
	k.quad(a, b, c, d, front)
	k.quad(d, c, b, a, back)


## A panel of thatch, cloth or boards over four corners, with a fringe of loose
## ends along the edge `c`-`d` that the wind moves. The fringe is the whole
## reason a hand-built roof reads as hand-built at 640x360, and it belongs on the
## eave: `a`-`b` is the high edge, `c`-`d` the one the rain runs off.
static func skin(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, variant: int, slot: int, fringe: bool = true) -> void:
	k.quad(a, b, c, d, col)
	if not fringe:
		return
	var n := 6
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var from := c.lerp(d, t)
		var wave := lean(variant, slot * 8 + i, 0.05)
		k.sway = 0.55
		k.sway_phase = wob(variant, slot * 8 + i) * TAU
		k.strut(from, from + Vector3(wave, -0.13 - wob(variant, slot * 8 + i) * 0.07, wave * 0.5), 0.017, 3, col)
		k.sway = 0.0


## A plate cut off something bigger: a flat panel with the rivet row it was cut
## through still running across it, and one chamfered corner where the cutter
## came off true. `w` and `h` are its width and height; it stands in the x-y
## plane of whatever transform is on the kit.
static func plate(k: MeshKit, w: float, h: float, variant: int, slot: int) -> void:
	var col := P.PLATE[2 + int(wob(variant, slot) * 2.0) % 3]
	var cut := 0.12 + wob(variant, slot + 1) * 0.1
	# The face, with the top corner cut away: a panel nobody squared up.
	k.quad(Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, h - cut, 0), Vector3(-w, h, 0), col)
	k.tri(Vector3(w, h - cut, 0), Vector3(w - cut, h, 0), Vector3(-w, h, 0), col)
	# Its back, a step darker, so the panel has a thickness at this scale.
	k.quad(Vector3(-w, h, -0.03), Vector3(w, h - cut, -0.03), Vector3(w, 0, -0.03), Vector3(-w, 0, -0.03), P.PLATE[1])
	# The rivet rows the cut went through: one ruled line each, raised off the
	# face. Rivet by rivet they would be under a pixel at play zoom and cost a
	# hundred triangles to say the same thing.
	var rows := 2 if h > 0.7 else 1
	for r in rows:
		var y := h * (0.28 + 0.42 * float(r))
		k.block(0.0, y, 0.016, w * 1.94, 0.022, 0.014, P.PLATE[4])


## Push the frame a cut panel is drawn in: it stands on `base` (the middle of its
## bottom edge), its width runs along the world Z axis, and `tilt` leans it back
## from upright — 0 faces +X, a quarter turn lies flat and faces the sky. `side`
## -1 turns it to face -X instead, for the other slope of a roof. The caller pops.
##
## The plate is drawn facing its own +Z and rising along its own +Y
## (`plate()`), so this is the one place the two have to agree, and it is written
## down once rather than worked out again in every model.
static func panel(k: MeshKit, base: Vector3, tilt: float, side: int = 1) -> void:
	k.push(Transform3D(Basis(Vector3.UP, float(side) * PI * 0.5).rotated(Vector3(0, 0, 1), float(side) * tilt), base))


## The same for a panel standing upright on a wall that faces any way: `out` is
## the direction the wall looks.
static func panel_facing(k: MeshKit, base: Vector3, out: Vector3) -> void:
	k.push(Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), base))


## A machine's own light, still burning on a part nobody could switch off. Amber
## and small: on a settlement it is the thing a machine will come for.
static func tell_tale(k: MeshKit, at: Vector3, r: float) -> void:
	k.prism(at.x, at.y, at.z, r, at.y + r * 1.6, r * 0.7, 6, Works.WORKING, Works.WORKING)


## A cold strip light off a machine's flank, wired into a person's wall.
static func strip(k: MeshKit, a: Vector3, b: Vector3, r: float) -> void:
	k.strut(a, b, r, 4, Works.STRIP)


## A stone at the foot of a post, or a ring of them. Faceted and leaning, never a
## ball (law 1).
static func stone(k: MeshKit, at: Vector3, r: float, variant: int, slot: int) -> void:
	k.rock(at.x, at.y, at.z, r, r * (0.6 + wob(variant, slot) * 0.5), variant * 31 + slot,
		P.STONE[1 + int(wob(variant, slot + 3) * 2.0) % 3], 6)


## Turf banked at the foot of a wall, the way people keep the wind out.
static func bank(k: MeshKit, at: Vector3, w: float, d: float, variant: int, slot: int) -> void:
	for i in 4:
		var t := (float(i) + 0.5) / 4.0
		var x := lerpf(-w, w, t)
		k.rock(at.x + x, at.y, at.z + lean(variant, slot * 4 + i, 0.05), d * (0.8 + wob(variant, slot * 4 + i) * 0.5),
			0.1 + wob(variant, slot * 4 + i) * 0.06, variant * 17 + i, TURF, 5)
