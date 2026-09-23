class_name LandmarkModels
## The eight places worth the walk, drawn (docs/VISION.md, §8; docs/LOOK.md).
##
##   LandmarkModels.node(kind, seed_value, made_material) -> Node3D
##   LandmarkModels.set_opened(node, done)   the cache, emptied
##
## Every one is built to the same three rules, and the tests hold them to the
## first two:
##
##   IT IS A SILHOUETTE FIRST. It stands well above everything round it — the
##   tallest prop in the game is a fire tower at 4.2 — and its outline is the
##   thing that carries: a leaning line, a ring, a crust, a broken back. At the
##   distance it is meant to be read from there are no details, only a shape
##   against the sky, so the shape does the work.
##
##   IT SAYS WHAT WAS LOST. Not a ruin in general: a lamp room with the lens
##   still cradled and no light in it; a stair that has gone and somebody's kit
##   still on the deck above where it was; a clerk's whole file out in the
##   weather and still in order. The dystopia is in the specific thing.
##
##   BOTH IDIOMS, WHERE BOTH WERE THERE. The machines' work is FOUND — ruled,
##   square, unhatched. What people made and what the land did is MADE — hatched,
##   uneven, leaning. Half of these places are a machine thing people lived in
##   afterwards, and that is drawn rather than described.
##
## The model faces +X, like everything else; the caller turns it with
## `rotation.y = -facing`. Its cache stands in front of it at +X *
## `Landmarks.CACHE_OUT`, so the face a player reads and the place their hands go
## are the same side.

const P := preload("res://src/render/palette.gd")
const W := preload("res://src/models/props/works.gd")

## The plate and the enamel every machine-built landmark is cut from: the same
## values the depots use, because they came out of the same yards.
const PLATE := Color(0.2536, 0.2892, 0.3655)
const PLATE_TOP := Color(0.3511, 0.3906, 0.4811)
const PLATE_DARK := Color(0.1687, 0.1962, 0.2518)
const SHADOW := Color(0.0892, 0.1064, 0.1412)
## ENAMEL is the row this file looks like it should use and must not: there IS
## an ENAMEL row (88, a painted sign) and these are the only constants whose
## name matches an unused one exactly — and all 8 uses are on the FOUND pen,
## where the mark would be a blinking lamp rather than paint. The name matched;
## the pen decided.
const ENAMEL := Color(0.2290, 0.1981, 0.3137)
const ENAMEL_TOP := Color(0.3176, 0.2695, 0.4413)
## What people built and what is left of them.
const STONE := Color(0.2902, 0.3333, 0.4000)
const STONE_TOP := Color(0.4275, 0.4784, 0.5490)
## **LIME MUST NEVER BE TAGGED, and it is the clearest case in the codebase of
## the rule `GroundColors.made` states.** It is used on the MADE pen twice and
## the FOUND pen twice — one colour, both pens. The two lit shaders read vertex
## alpha for different things, so no mark can be right for it: whatever says
## "poured lime" on the made pen says "a lamp, blinking on the machines' beat"
## on the found one. This is a third category beside tagged and untagged —
## UNTAGGABLE — and the fix, if it is ever worth one, is two constants and not
## a mark.
const LIME := Color(0.5882, 0.5412, 0.4627)
## TIMBER (row 80) on both: 7 uses and 11 uses, every one of them on the MADE
## pen and none on FOUND, counted rather than assumed. The fire watch is a
## timber frame and the tallest thing a player walks to.
static var TIMBER: Color = GroundColors.made(Color(0.3098, 0.2118, 0.1529), GroundColors.TIMBER)
static var TIMBER_PALE: Color = GroundColors.made(Color(0.4353, 0.3020, 0.1922), GroundColors.TIMBER)
## CLOTH (row 82): sacking over a doorway is canvas, and it is one made use.
static var SACKING: Color = GroundColors.made(Color(0.4353, 0.3961, 0.3490), GroundColors.CLOTH)
const PAPER := Color(0.7529, 0.7020, 0.5804)
const PAPER_DARK := Color(0.5882, 0.5412, 0.4627)
const RUST := Color(0.4314, 0.2000, 0.1255)
const SALT := Color(0.7843, 0.8118, 0.8471)
const LEAF := Color(0.1725, 0.2667, 0.1882)
const LEAF_PALE := Color(0.2745, 0.4118, 0.2275)


static func node(kind: StringName, seed_value: int, made_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "landmark_%s" % kind
	var found := MeshKit.new()
	found.style = Ink.NONE
	found.style2 = Ink.NONE
	var lamps := MeshKit.new()
	lamps.style = Ink.NONE
	lamps.style2 = Ink.NONE
	var made := MeshKit.new()
	made.style = Ink.HAND
	made.style2 = Ink.HAND
	match kind:
		&"lighthouse": _lighthouse(found, made, lamps, seed_value)
		&"leaning_mast": _leaning_mast(found, made, lamps, seed_value)
		&"firewatch": _firewatch(found, made, lamps, seed_value)
		&"blinking_stack": _blinking_stack(found, made, lamps, seed_value)
		&"cast_stones": _cast_stones(found, made, lamps, seed_value)
		&"evaporator": _evaporator(found, made, lamps, seed_value)
		&"grown_hulk": _grown_hulk(found, made, lamps, seed_value)
		&"poured_pillar": _poured_pillar(found, made, lamps, seed_value)
		&"sump_pump": _sump_pump(found, made, lamps, seed_value)
		_: _clerks_office(found, made, lamps, seed_value)
	root.add_child(_mesh("found", found, PropModels.found_material()))
	root.add_child(_mesh("lamps", lamps, PropModels.found_material()))
	root.add_child(_mesh("made", made, made_material))
	root.add_child(_cache(kind, seed_value, made_material))
	return root


## The cache, emptied: its lid back, its inside showing, and nothing in it. What
## a player sees on coming back to a place they have already been.
static func set_opened(root: Node3D, done: bool) -> void:
	if root == null:
		return
	var cache := root.get_node_or_null(^"cache")
	if cache == null:
		return
	var shut := cache.get_node_or_null(^"shut")
	var open := cache.get_node_or_null(^"open")
	if shut != null:
		(shut as Node3D).visible = not done
	if open != null:
		(open as Node3D).visible = done


## THE MASS OF ONE, as circles in the model's own frame: `(x, z, radius)` in
## tiles, turned with the model and handed to `WorldQuery.set_blocks` by
## 22_landmarks. Nothing in this package stopped a body at all until this was
## written — a player walked into the middle of the lighthouse's stonework and
## stood there, occluded and invisible, and every silhouette in the game was
## scenery you could stand inside.
##
## Only the mass a BODY meets: a hulk raised on its legs blocks at the feet and
## nowhere else, because at this camera the player walks under it. And nothing
## may cover the cache, which stands at (`Landmarks.CACHE_OUT`, 0) — held by
## `tests/landmarks/test_models.gd`, which walks in to it from every quarter.
const BLOCKS := {
	&"lighthouse": [Vector3(0.0, 0.0, 1.02)],
	&"leaning_mast": [Vector3(-0.85, 0.0, 0.8)],
	&"firewatch": [Vector3(-1.1, -1.1, 0.24), Vector3(1.1, -1.1, 0.24), Vector3(1.1, 1.1, 0.24), Vector3(-1.1, 1.1, 0.24)],
	&"blinking_stack": [Vector3(0.0, 0.0, 1.12), Vector3(1.3, -1.1, 0.36), Vector3(1.3, 1.1, 0.36)],
	&"cast_stones": [Vector3(0.0, 0.0, 0.78)],
	&"evaporator": [Vector3(-2.2, 0.0, 0.92), Vector3(-1.2, 0.0, 0.92), Vector3(-0.2, 0.0, 0.92),
		Vector3(0.8, 0.0, 0.92), Vector3(4.75, 0.0, 0.55)],
	&"grown_hulk": [Vector3(-2.3, 2.4, 0.4), Vector3(0.1, 2.4, 0.4), Vector3(2.5, 2.4, 0.4),
		Vector3(-3.2, -2.5, 0.4), Vector3(-0.8, -2.5, 0.4), Vector3(1.6, -2.5, 0.4), Vector3(3.9, 2.0, 0.42)],
	&"clerks_office": [Vector3(0.0, 0.0, 1.12), Vector3(-2.4, 0.5, 0.3)],
	&"poured_pillar": [Vector3(0.0, 0.0, 0.85)],
	&"sump_pump": [Vector3(-1.25, -1.05, 0.28), Vector3(1.25, -1.05, 0.28),
		Vector3(1.25, 1.05, 0.28), Vector3(-1.25, 1.05, 0.28), Vector3(-0.6, 0.0, 0.85)],
}


## The stones of a ring stand where the ring puts them, so they are worked out
## rather than written down: `_cast_stones` lays nine on a 3.6 ring at the same
## angles, and the one that is lying down does not stop anybody.
static func blocks(kind: StringName) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for c: Vector3 in BLOCKS.get(kind, []):
		out.append(c)
	if kind == &"cast_stones":
		for i in 9:
			if i == 2:
				continue
			var a := TAU * i / 9.0 + 0.2
			out.append(Vector3(cos(a) * 3.6, sin(a) * 3.6, 0.5))
	return out


## What one is, measured off the mesh it really builds: `{high, wide, draws}`.
## The header above claims a silhouette that stands above everything round it and
## a shape that carries at the distance it is read from; this is what lets a test
## hold it to both instead of the claim standing on its own.
static func measure(kind: StringName, seed_value: int = 11) -> Dictionary:
	var root := node(kind, seed_value, null)
	var box := AABB()
	var first := true
	var draws := 0
	for c in root.get_children():
		var m := c as MeshInstance3D
		if m == null or not m.visible or m.mesh == null or m.mesh.get_surface_count() == 0:
			continue
		draws += m.mesh.get_surface_count()
		var a := m.mesh.get_aabb()
		box = a if first else box.merge(a)
		first = false
	# The cache is a child of its own, and it is furniture, not silhouette.
	var cache := root.get_node_or_null(^"cache")
	if cache != null:
		for c in cache.get_children():
			var m := c as MeshInstance3D
			if m != null and m.visible and m.mesh != null and m.mesh.get_surface_count() > 0:
				draws += m.mesh.get_surface_count()
	root.free()
	return {"high": box.end.y, "wide": maxf(box.size.x, box.size.z), "draws": draws}


## How tall one stands, worked out once per kind off the mesh it really builds.
## Whoever asks whether a landmark is in the frame needs it every look, and
## building the model again to find out would be a dozen meshes a second.
static var _high: Dictionary = {}


static func high_of(kind: StringName) -> float:
	if not _high.has(kind):
		_high[kind] = float(measure(kind).high)
	return _high[kind]


static func _mesh(node_name: String, k: MeshKit, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = k.build()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


# --- what a player's hands go into ----------------------------------------------

## Every landmark keeps what it holds the same way: a locker the machines left,
## dragged out into the open and wedged shut. It reads at a glance, it is the
## same shape at all eight places, and it is the only thing at a landmark a
## player can be in doubt about doing something with.
static func _cache(kind: StringName, seed_value: int, made_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "cache"
	root.position = Vector3(Landmarks.CACHE_OUT, 0.0, 0.0)
	var shut := MeshKit.new()
	shut.style = Ink.NONE
	shut.style2 = Ink.NONE
	var open := MeshKit.new()
	open.style = Ink.NONE
	open.style2 = Ink.NONE
	var made := MeshKit.new()
	made.style = Ink.HAND
	made.style2 = Ink.HAND
	for m: MeshKit in [shut, open]:
		m.box(Vector3(-0.42, 0.0, -0.34), Vector3(0.42, 0.62, 0.34), ENAMEL, ENAMEL_TOP)
		m.box(Vector3(-0.46, 0.0, -0.38), Vector3(0.46, 0.1, 0.38), PLATE_DARK, PLATE)
	# Shut: a lid, a hasp, and a stone somebody wedged under the lip.
	shut.box(Vector3(-0.45, 0.62, -0.37), Vector3(0.45, 0.72, 0.37), PLATE, PLATE_TOP)
	shut.block(0.42, 0.34, 0.0, 0.05, 0.16, 0.14, SHADOW)
	# Opened: the lid hinged back against the body and the well showing, empty.
	open.push(Transform3D(Basis(Vector3.FORWARD, -1.25), Vector3(-0.44, 0.62, 0.0)))
	open.box(Vector3(0.0, -0.05, -0.37), Vector3(0.9, 0.05, 0.37), PLATE_DARK, PLATE)
	open.pop()
	open.box(Vector3(-0.34, 0.5, -0.26), Vector3(0.34, 0.62, 0.26), SHADOW, SHADOW)
	made.rock(-0.5, 0.0, 0.34, 0.16, 0.12, seed_value + 3, P.STONE[2], 5)
	made.rock(0.52, 0.0, -0.3, 0.13, 0.1, seed_value + 5, P.STONE[1], 5)
	var a := _mesh("shut", shut, PropModels.found_material())
	var b := _mesh("open", open, PropModels.found_material())
	b.visible = false
	root.add_child(a)
	root.add_child(b)
	root.add_child(_mesh("made", made, made_material))
	# The kind is stamped on the face as that many bars, which is a machine's
	# mark: a shape and never a glyph at 640x360.
	return root


# --- the eight ------------------------------------------------------------------

## THE DROWNED LIGHT. A stone tower on a rock in the shallows, leaning off the
## upright, its gallery rail gone on the seaward side and the lens still sitting
## in its cradle with nothing behind it. The lantern is DARK: the one tower in
## the game with a lamp room and no lamp.
static func _lighthouse(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	var lean := Basis(Vector3.BACK, 0.075)
	made.push(Transform3D(lean, Vector3.ZERO))
	k.push(Transform3D(lean, Vector3.ZERO))
	lamps.push(Transform3D(lean, Vector3.ZERO))
	var top := 7.4
	# The shaft: coursed stone, tapering, banded once where the render went.
	made.prism(0.0, 0.0, 0.0, 1.05, 1.1, 0.95, 12, STONE, STONE_TOP)
	made.prism(0.0, 1.1, 0.0, 0.95, top - 1.5, 0.62, 12, STONE, STONE_TOP)
	made.prism(0.0, 3.2, 0.0, 0.79, 3.95, 0.76, 12, LIME, LIME)
	for i in 9:
		var y := 1.3 + i * 0.62
		var r := lerpf(0.95, 0.62, (y - 1.1) / (top - 2.6))
		made.prism(0.0, y, 0.0, r + 0.015, y + 0.04, r + 0.015, 12, P.STONE[1], P.STONE[2])
	# Windows up the stair: dark slots, so the shaft is a building and not a cone.
	for i in 4:
		var y := 1.7 + i * 1.2
		var a := 0.5 + i * 1.9
		var r := lerpf(0.93, 0.62, (y - 1.1) / (top - 2.6))
		made.block(cos(a) * r, y, sin(a) * r, 0.1, 0.4, 0.22, P.INK[2])
	# The gallery: a corbel ring and a rail with its seaward quarter torn away.
	made.prism(0.0, top - 1.5, 0.0, 0.86, top - 1.3, 1.02, 12, STONE_TOP, STONE_TOP)
	k.prism(0.0, top - 1.3, 0.0, 1.02, top - 1.24, 1.02, 12, PLATE_DARK, PLATE)
	for i in 12:
		var a := TAU * i / 12.0
		if a > 0.4 and a < 2.2:
			continue
		k.block(cos(a) * 0.96, top - 1.24, sin(a) * 0.96, 0.05, 0.42, 0.05, PLATE_DARK)
	k.prism(0.0, top - 0.86, 0.0, 1.0, top - 0.8, 1.0, 12, PLATE, PLATE_TOP)
	# The lamp room: eight uprights, a cap, and the lens in its cradle, unlit.
	for i in 8:
		var a := TAU * i / 8.0
		k.block(cos(a) * 0.62, top - 1.24, sin(a) * 0.62, 0.07, 1.0, 0.07, PLATE)
	k.prism(0.0, top - 0.24, 0.0, 0.78, top + 0.12, 0.5, 8, PLATE_DARK, PLATE)
	k.prism(0.0, top + 0.12, 0.0, 0.5, top + 0.5, 0.06, 8, PLATE, PLATE_TOP)
	made.prism(0.0, top - 1.1, 0.0, 0.42, top - 0.9, 0.42, 8, P.SLATE[1], P.SLATE[2])
	k.prism(0.0, top - 0.9, 0.0, 0.34, top - 0.34, 0.3, 10, P.RIME[2], P.RIME[3])
	k.pop()
	made.pop()
	lamps.pop()
	# The rock it stands on, and the wrack the tide left up the base.
	for i in 5:
		var a := Rng.hash01(seed_value, i, 0x31) * TAU
		made.rock(cos(a) * 1.5, -0.05, sin(a) * 1.5, 0.42 + Rng.hash01(seed_value, i, 0x32) * 0.3, 0.3, seed_value + i, P.SLATE[1], 6)
	for i in 4:
		var a := Rng.hash01(seed_value, i, 0x33) * TAU
		made.rock(cos(a) * 1.15, 0.24, sin(a) * 1.15, 0.2, 0.06, seed_value + 20 + i, P.MOSS[1], 5)


## THE LEANING MAST. A relay mast that went over into standing water and stayed,
## held up by one guy that did not part, its head cabinet still shut and still
## drawing power. Everything else on it is dead.
static func _leaning_mast(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	var top := 8.2
	k.push(Transform3D(Basis(Vector3.BACK, 0.34), Vector3(-0.6, 0.0, 0.0)))
	lamps.push(Transform3D(Basis(Vector3.BACK, 0.34), Vector3(-0.6, 0.0, 0.0)))
	k.prism(0.0, 0.0, 0.0, 0.44, top * 0.5, 0.3, 4, PLATE, PLATE_TOP)
	k.prism(0.0, top * 0.5, 0.0, 0.3, top, 0.17, 4, PLATE_DARK, PLATE)
	for i in 9:
		var y0 := top * (i / 9.0)
		var y1 := top * ((i + 1) / 9.0)
		var r0 := lerpf(0.44, 0.17, i / 9.0)
		var r1 := lerpf(0.44, 0.17, (i + 1) / 9.0)
		var side := 1.0 if i % 2 == 0 else -1.0
		k.strut(Vector3(-r0 * side, y0, -r0), Vector3(r1 * side, y1, r1), 0.04, 4, SHADOW)
		k.strut(Vector3(-r0 * side, y0, r0), Vector3(r1 * side, y1, -r1), 0.04, 4, SHADOW)
		k.strut(Vector3(-r1, y1, -r1), Vector3(r1, y1, -r1), 0.03, 4, PLATE_DARK)
	# The dishes: three, all turned the same way, all facing nothing now.
	for i in 3:
		var y := top * (0.48 + i * 0.17)
		k.push(Transform3D(Basis(Vector3.UP, -0.5 + i * 0.1), Vector3(0.0, y, 0.0)))
		k.prism(0.4, 0.0, 0.0, 0.05, 0.5, 0.5, 8, PLATE, PLATE_TOP)
		k.pop()
	# The head cabinet, shut, with one strip still alive in it.
	k.box(Vector3(-0.3, top, -0.3), Vector3(0.3, top + 0.72, 0.3), ENAMEL, ENAMEL_TOP)
	k.box(Vector3(0.3, top + 0.1, -0.22), Vector3(0.36, top + 0.62, 0.22), PLATE_DARK, PLATE)
	lamps.box(Vector3(0.36, top + 0.2, -0.16), Vector3(0.4, top + 0.5, 0.16), W.STRIP)
	lamps.prism(0.0, top + 0.72, 0.0, 0.1, top + 0.92, 0.06, 6, W.BEACON, W.BEACON)
	k.pop()
	lamps.pop()
	# The one guy that held, and three that did not: MADE cable, sagging.
	var head := Vector3(-0.6, 0.0, 0.0) + Basis(Vector3.BACK, 0.34) * Vector3(0.0, top * 0.82, 0.0)
	_cable(made, head, Vector3(3.4, 0.05, -1.1), 0.045, P.STONE[2], seed_value)
	for i in 3:
		var a := 2.1 + i * 1.5
		var slack := Vector3(cos(a) * 2.2, 0.06, sin(a) * 2.2)
		_cable(made, slack + Vector3(0, 0.9, 0), slack, 0.04, P.STONE[1], seed_value + i * 5)
	# The footing it tore out of the ground on its way over.
	for i in 4:
		var a := Rng.hash01(seed_value, i, 0x41) * TAU
		made.rock(-1.4 + cos(a) * 0.8, 0.0, sin(a) * 0.9, 0.3, 0.2, seed_value + i, P.EARTH[1], 5)
	made.box(Vector3(-1.5, 0.0, -0.8), Vector3(-0.7, 0.22, 0.8), P.STONE[1], P.STONE[2])


## THE FIRE TOWER. Timber legs, a cabin with its glass gone, and the bottom two
## flights of the stair missing — taken for firewood, or cut away on purpose.
## Somebody lived up there after that, and their line and sacking are still on it.
static func _firewatch(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	var top := 6.6
	var feet: Array[Vector2] = [Vector2(-1.1, -1.1), Vector2(1.1, -1.1), Vector2(1.1, 1.1), Vector2(-1.1, 1.1)]
	for i in 4:
		var f := feet[i]
		var g := feet[(i + 1) % 4]
		_limb(made, Vector3(f.x, -0.08, f.y), Vector3(f.x * 0.42, top, f.y * 0.42), 0.1, TIMBER, seed_value + i)
		for li in 5:
			var t0 := li / 5.0
			var t1 := (li + 1) / 5.0
			var k0 := 1.0 - t0 * 0.58
			var k1 := 1.0 - t1 * 0.58
			_limb(made, Vector3(f.x * k0, top * t0 + 0.1, f.y * k0), Vector3(g.x * k1, top * t1, g.y * k1), 0.035, TIMBER_PALE, seed_value + li * 7 + i)
	# The stair: the top three flights only. Where the bottom two were, two stubs.
	for i in 6:
		var y := top * 0.42 + i * 0.4
		var sgn := 1.0 if i % 2 == 0 else -1.0
		_limb(made, Vector3(-0.42 * sgn, y, 0.16), Vector3(0.42 * sgn, y + 0.38, 0.16), 0.045, TIMBER_PALE, seed_value + 40 + i)
	_limb(made, Vector3(-0.8, 0.0, 1.0), Vector3(-0.5, 0.9, 0.8), 0.05, TIMBER, seed_value + 61)
	# THE CABIN IS THE TOP OF THE SILHOUETTE, and the first version drew it as one
	# grey box with a pyramid on it — the one part of the model that has to carry
	# and the one part that was a brick. So: a deck that overhangs on a joist, a
	# sill board round all four sides, corner posts, a boarded half-wall of
	# separate boards with one sprung, the dark set BACK behind the posts, a
	# shutter propped open, and a cap whose eave overhangs and whose corner has
	# gone. None of it is square to the step below it.
	var deck := top
	made.box(Vector3(-1.02, deck, -1.02), Vector3(1.02, deck + 0.09, 1.02), TIMBER, TIMBER_PALE)
	made.box(Vector3(-0.86, deck - 0.14, -0.86), Vector3(0.86, deck, 0.86), P.INK[1], TIMBER)
	# A plank sprung off the near edge of the deck, hanging.
	made.push(Transform3D(Basis(Vector3.BACK, 0.42), Vector3(0.0, deck + 0.04, 0.99)))
	made.box(Vector3(-0.34, -0.04, 0.0), Vector3(0.38, 0.04, 0.2), TIMBER_PALE, TIMBER_PALE)
	made.pop()
	for i in 4:
		var f := feet[i] * 0.78
		made.block(f.x, deck + 0.09, f.y, 0.11, 1.32, 0.11, TIMBER)
	# The sill, all four sides, set out past the posts.
	for side: float in [-1.0, 1.0]:
		made.box(Vector3(-0.94, deck + 0.09, side * 0.94 - 0.07), Vector3(0.94, deck + 0.21, side * 0.94 + 0.07), TIMBER_PALE, TIMBER_PALE)
		made.box(Vector3(side * 0.94 - 0.07, deck + 0.09, -0.88), Vector3(side * 0.94 + 0.07, deck + 0.21, 0.88), TIMBER_PALE, TIMBER_PALE)
	# The boarded half-wall: five boards a side, laid one over the next, and on
	# the near side one of them sprung out at the bottom.
	for i in 5:
		var y := deck + 0.21 + i * 0.13
		var pale := i % 2 == 0
		for side: float in [-1.0, 1.0]:
			made.box(Vector3(-0.84, y, side * 0.9 - 0.05), Vector3(0.84, y + 0.14, side * 0.9 + 0.02), TIMBER_PALE if pale else TIMBER, TIMBER)
		made.box(Vector3(-0.9 - 0.02, y, -0.8), Vector3(-0.9 + 0.05, y + 0.14, 0.8), TIMBER if pale else TIMBER_PALE, TIMBER)
		if i != 2:
			made.box(Vector3(0.9 - 0.05, y, -0.8), Vector3(0.9 + 0.02, y + 0.14, 0.8), TIMBER if pale else TIMBER_PALE, TIMBER)
	made.push(Transform3D(Basis(Vector3.BACK, 0.0) * Basis(Vector3.UP, 0.3), Vector3(0.9, deck + 0.47, 0.0)))
	made.box(Vector3(-0.04, 0.0, -0.8), Vector3(0.03, 0.14, 0.42), TIMBER_PALE, TIMBER)
	made.pop()
	# The dark inside, set back behind the posts so the corner posts read against
	# it: this is what says the glass has gone, and it must not be the whole box.
	made.box(Vector3(-0.78, deck + 0.21, -0.78), Vector3(0.78, deck + 1.32, 0.78), P.INK[2], P.INK[2])
	# The shutter, hinged up off the seaward face and propped on a stick.
	made.push(Transform3D(Basis(Vector3.RIGHT, 1.05), Vector3(0.0, deck + 1.32, -0.84)))
	made.box(Vector3(-0.8, 0.0, -0.62), Vector3(0.8, 0.04, 0.06), TIMBER, TIMBER_PALE)
	made.pop()
	_limb(made, Vector3(-0.5, deck + 0.9, -0.8), Vector3(-0.56, deck + 1.82, -1.12), 0.03, TIMBER, seed_value + 91)
	# The eave, overhanging, with one corner torn off; then the cap on it.
	made.box(Vector3(-1.04, deck + 1.32, -1.04), Vector3(0.68, deck + 1.44, 1.04), P.SLATE[1], P.SLATE[2])
	made.box(Vector3(0.68, deck + 1.32, -1.04), Vector3(1.04, deck + 1.44, 0.44), P.SLATE[1], P.SLATE[2])
	made.prism(0.0, deck + 1.44, 0.0, 0.92, deck + 1.94, 0.12, 4, P.SLATE[2], P.SLATE[3])
	# A sheet of plate somebody nailed over the hole in the cap: FOUND on a MADE
	# roof, which is the whole of what has happened to this place.
	k.push(Transform3D(Basis(Vector3.UP, 0.8) * Basis(Vector3.BACK, 0.55), Vector3(-0.34, deck + 1.66, 0.3)))
	k.box(Vector3(-0.3, -0.02, -0.26), Vector3(0.3, 0.02, 0.26), PLATE, PLATE_TOP)
	k.pop()
	# What the last person up there left: sacking over the weather side, a line
	# tied off across the deck, and a plate stove with its flue out through the cap.
	made.box(Vector3(-0.86, deck + 0.46, -0.9), Vector3(0.1, deck + 1.28, -0.8), SACKING, SACKING)
	_cable(made, Vector3(-0.86, deck + 1.2, 0.86), Vector3(0.86, deck + 1.05, 0.86), 0.025, P.LINEN[3], seed_value + 80)
	k.block(0.5, deck + 0.12, -0.4, 0.34, 0.5, 0.34, PLATE_DARK, PLATE)
	k.prism(0.5, deck + 0.62, -0.4, 0.07, deck + 2.05, 0.06, 6, PLATE, PLATE_TOP)
	# Its bell, still on its bracket: the thing that used to be rung.
	k.prism(0.92, deck + 1.1, 0.0, 0.05, deck + 1.28, 0.05, 5, PLATE_DARK)
	k.prism(0.92, deck + 0.82, 0.0, 0.1, deck + 1.1, 0.2, 7, P.COPPER[1], P.COPPER[2])


## THE TALL STACK. The plan's flue, three times anything round it, banded and
## still blinking, with nothing burning under it. Its base is a bank of ducts
## going into the ground and one of them has been unbolted.
static func _blinking_stack(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	var top := 11.5
	k.prism(0.0, 0.0, 0.0, 1.15, 1.6, 1.0, 10, PLATE_DARK, PLATE)
	k.prism(0.0, 1.6, 0.0, 0.9, top - 0.9, 0.42, 10, PLATE, PLATE_TOP)
	k.prism(0.0, top - 0.9, 0.0, 0.5, top, 0.46, 10, PLATE_DARK, PLATE)
	k.prism(0.0, top, 0.0, 0.46, top + 0.18, 0.34, 10, SHADOW, SHADOW)
	# The bands: what makes a cone a stack at any distance.
	for i in 7:
		var y := 1.9 + i * (top - 3.0) / 7.0
		var r := lerpf(0.9, 0.44, (y - 1.6) / (top - 2.5))
		k.prism(0.0, y, 0.0, r + 0.05, y + 0.14, r + 0.05, 10, RUST, PLATE_DARK)
	# The ladder up the back of it, in one ruled run, and its cage.
	for i in 26:
		var y := 1.0 + i * 0.4
		var r := lerpf(0.98, 0.5, clampf((y - 1.6) / (top - 2.5), 0.0, 1.0))
		k.block(-r, y, 0.0, 0.05, 0.05, 0.4, PLATE_DARK)
	# The duct bank at the foot, and the one somebody has had the bolts out of.
	for i in 3:
		var z := -1.1 + i * 1.1
		k.push(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(1.3, 0.55, z)))
		k.prism(0.0, -1.3, 0.0, 0.34, 0.0, 0.34, 8, ENAMEL, ENAMEL_TOP)
		k.pop()
	k.box(Vector3(1.32, 0.3, -1.4), Vector3(1.44, 0.82, -0.8), SHADOW, SHADOW)
	made.rock(1.85, 0.0, -1.2, 0.26, 0.16, seed_value, P.STONE[1], 5)
	# The beacons: two on the head, one halfway, all on the machines' beat. This
	# is the whole reason the thing is a landmark in the snow at night.
	lamps.prism(0.0, top + 0.18, 0.0, 0.2, top + 0.52, 0.12, 6, W.BEACON, W.BEACON)
	for side: float in [-1.0, 1.0]:
		lamps.block(side * 0.55, top - 0.7, 0.0, 0.16, 0.2, 0.16, W.BEACON)
	lamps.block(0.0, top * 0.52, 0.72, 0.16, 0.2, 0.16, W.BEACON)
	# Scorch and clinker round the foot, MADE, low.
	for i in 6:
		var a := Rng.hash01(seed_value, i, 0x51) * TAU
		var r := 1.8 + Rng.hash01(seed_value, i, 0x52) * 1.4
		made.rock(cos(a) * r, 0.0, sin(a) * r, 0.24, 0.12, seed_value + i, P.ASH[1], 5)


## THE CAST STONES. A ring that stood here before any of it, with the fallen ones
## recast in concrete round rebar and set back up — the machines' own tidiness
## applied to somebody else's monument, which is the most dystopian thing in it.
static func _cast_stones(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	var n := 9
	var ring := 3.6
	for i in n:
		var a := TAU * i / float(n) + 0.2
		var at := Vector3(cos(a) * ring, 0.0, sin(a) * ring)
		var h := 3.2 + Rng.hash01(seed_value, i, 0x61) * 1.4
		if i == 2:
			# One still down, half-buried, with the grass over it. A slab lying
			# flat is what says the ring is OLD and has been falling for a while.
			made.push(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, 1.5), at))
			_slab(made, h * 0.85, 0.66, 0.34, P.STONE[1], P.STONE[2], seed_value + i)
			made.pop()
			made.rock(at.x, 0.0, at.z, 0.7, 0.16, seed_value + 50 + i, P.MOSS[2], 6)
			continue
		if i == 4 or i == 7:
			# Recast: a square concrete column, ruled, poured round rebar that came
			# up short at the head. It is the WRONG SHAPE beside the others, and
			# that is the whole of what this place is about.
			k.push(Transform3D(Basis(Vector3.UP, a), at))
			k.box(Vector3(-0.42, 0.0, -0.3), Vector3(0.42, h, 0.3), LIME, P.LINEN[4])
			k.box(Vector3(-0.45, h * 0.28, -0.33), Vector3(0.45, h * 0.32, 0.33), P.LINEN[2], P.LINEN[3])
			k.box(Vector3(-0.45, h * 0.66, -0.33), Vector3(0.45, h * 0.7, 0.33), P.LINEN[2], P.LINEN[3])
			for j in 4:
				var o := Vector3(-0.22 + (j % 2) * 0.44, 0.0, -0.14 + (j / 2) * 0.28)
				k.prism(o.x, h, o.z, 0.045, h + 0.5 + Rng.hash01(seed_value, i * 4 + j, 0x62) * 0.4, 0.035, 4, RUST)
			k.pop()
			continue
		made.push(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, (Rng.hash01(seed_value, i, 0x63) - 0.5) * 0.3), at))
		_slab(made, h, 0.62 + Rng.hash01(seed_value, i, 0x64) * 0.2, 0.34, STONE, STONE_TOP, seed_value + i * 3)
		made.pop()
	# The one in the middle, tallest and thickest, with the machines' own survey
	# plate bolted to it at head height: they measured it and moved on.
	made.push(Transform3D(Basis(Vector3.UP, 0.4), Vector3.ZERO))
	_slab(made, 5.2, 0.86, 0.46, STONE_TOP, P.STONE[4], seed_value + 77)
	made.pop()
	k.box(Vector3(0.42, 1.5, -0.34), Vector3(0.52, 2.05, 0.34), PLATE, PLATE_TOP)
	for j in 3:
		k.block(0.53, 1.64 + j * 0.13, 0.0, 0.025, 0.06, 0.2, PLATE_DARK)
	# What the ring is standing in: cropped turf, a few boulders, and the ditch
	# somebody dug round it long before any of this.
	for i in 6:
		var a := Rng.hash01(seed_value, i, 0x65) * TAU
		made.rock(cos(a) * (ring + 1.6), 0.0, sin(a) * (ring + 1.6), 0.34, 0.24, seed_value + 30 + i, P.STONE[1], 5)


## A standing stone: a tapered slab, wide one way and thin the other, with a
## broken crown. A bipyramid (`MeshKit.rock`) reads as a shard on the ground at
## this camera; a slab reads as something set upright by hands.
static func _slab(k: MeshKit, h: float, wide: float, thick: float, col: Color, top: Color, seed_value: int) -> void:
	var lean := (Rng.hash01(seed_value, 1, 0xB1) - 0.5) * 0.16
	for i in 4:
		var t0 := i / 4.0
		var t1 := (i + 1) / 4.0
		var w0 := lerpf(wide, wide * 0.66, t0) * (1.0 + (Rng.hash01(seed_value, i, 0xB2) - 0.5) * 0.14)
		var w1 := lerpf(wide, wide * 0.66, t1)
		var d0 := lerpf(thick, thick * 0.74, t0)
		var d1 := lerpf(thick, thick * 0.74, t1)
		var x0 := lean * h * t0
		var x1 := lean * h * t1
		k.quad(Vector3(x0 - w0, h * t0, d0), Vector3(x0 + w0, h * t0, d0), Vector3(x1 + w1, h * t1, d1), Vector3(x1 - w1, h * t1, d1), col)
		# WOUND THE OTHER WAY ROUND FROM THE +Z FACE ABOVE, which is the whole point
		# and was inverted for this model's entire life: `MeshKit.tri` takes its
		# normal as `(c - b) x (a - b)`, so running this face in the same rotational
		# order as its opposite twin gives both of them a +Z normal. The land is
		# `cull_back`, so the -Z flank was not dark and was not z-fighting -- it was
		# ABSENT, and every standing stone was an open shell you could see through
		# from half the bearings on the ring. Held by tests/models/test_landmark_windings.gd.
		k.quad(Vector3(x0 + w0, h * t0, -d0), Vector3(x0 - w0, h * t0, -d0), Vector3(x1 - w1, h * t1, -d1), Vector3(x1 + w1, h * t1, -d1), col)
		k.quad(Vector3(x0 + w0, h * t0, -d0), Vector3(x1 + w1, h * t1, -d1), Vector3(x1 + w1, h * t1, d1), Vector3(x0 + w0, h * t0, d0), top)
		k.quad(Vector3(x0 - w0, h * t0, d0), Vector3(x1 - w1, h * t1, d1), Vector3(x1 - w1, h * t1, -d1), Vector3(x0 - w0, h * t0, -d0), top)
	var cw := wide * 0.66
	var cd := thick * 0.74
	var cx := lean * h
	k.quad(Vector3(cx - cw, h, cd), Vector3(cx + cw, h, cd), Vector3(cx + cw * 0.4, h + 0.2, -cd * 0.3), Vector3(cx - cw * 0.5, h + 0.12, -cd * 0.3), top)
	k.quad(Vector3(cx + cw, h, -cd), Vector3(cx - cw, h, -cd), Vector3(cx - cw * 0.5, h + 0.12, -cd * 0.3), Vector3(cx + cw * 0.4, h + 0.2, -cd * 0.3), col)


## THE EVAPORATOR. A pan machine that stopped with its rake arm down, and
## everything the brine touched has grown a crust over it since — the one hulk in
## the game that is WHITE, which is why it reads at a distance on a white flat.
static func _evaporator(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	# THE TANK IS NOT ONE BOX. Four bays with a rib between each pair, a lid
	# tapered off the sides, and a walkway down the near flank: a plain prism four
	# tiles long is the slab docs/LOOK.md forbids, and at this camera the tank
	# is most of what a player sees of the whole machine.
	for i in 4:
		var x0 := -2.7 + i * 1.02
		k.box(Vector3(x0, 0.6, -1.0), Vector3(x0 + 0.9, 2.1, 1.0), ENAMEL, ENAMEL_TOP)
		k.box(Vector3(x0 + 0.9, 0.55, -1.08), Vector3(x0 + 1.02, 2.2, 1.08), PLATE_DARK, PLATE)
		# The gauge slot down each bay's face: a recess, so the flank has depth.
		k.box(Vector3(x0 + 0.24, 0.9, 0.96), Vector3(x0 + 0.66, 1.8, 1.02), SHADOW, SHADOW)
	k.prism(-1.2, 2.1, 0.0, 1.5, 2.5, 1.1, 4, PLATE, PLATE_TOP, PI * 0.25)
	# The legs, standing clear of the tank so it reads as carried and not sunk.
	for i in 4:
		var x := -2.3 + (i % 2) * 3.4
		var z := -0.75 + (i / 2) * 1.5
		k.box(Vector3(x - 0.2, 0.0, z - 0.2), Vector3(x + 0.2, 0.62, z + 0.2), PLATE_DARK, PLATE)
		k.strut(Vector3(x, 0.55, z), Vector3(x + 0.7, 0.05, z * 1.4), 0.07, 4, SHADOW)
	# The walkway and its rail along the near flank, and the ladder up to it.
	k.box(Vector3(-2.8, 1.35, 1.0), Vector3(1.5, 1.45, 1.55), PLATE_DARK, PLATE)
	k.box(Vector3(-2.8, 1.45, 1.5), Vector3(1.5, 1.52, 1.56), PLATE, PLATE_TOP)
	k.box(Vector3(-2.8, 1.9, 1.5), Vector3(1.5, 1.97, 1.56), PLATE, PLATE_TOP)
	for i in 6:
		k.block(-2.6 + i * 0.8, 1.45, 1.53, 0.06, 0.46, 0.06, PLATE_DARK)
	for i in 5:
		k.block(1.2, 0.2 + i * 0.26, 1.3, 0.05, 0.05, 0.5, PLATE_DARK)
	# Pipe stubs down the far flank, capped and going nowhere.
	for i in 4:
		k.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-2.3 + i * 1.02, 1.1, -1.12)))
		k.prism(0.0, 0.0, 0.0, 0.16, 0.34, 0.16, 6, PLATE_DARK, PLATE)
		k.pop()
	# The hopper head and the boom: the shape, carried out over the pan.
	k.prism(1.6, 1.2, 0.0, 0.95, 3.2, 0.6, 6, PLATE, PLATE_TOP)
	k.prism(1.6, 3.2, 0.0, 0.6, 3.45, 0.55, 6, PLATE_DARK, PLATE)
	# THE STAY TOWER, which is what the boom hangs off and what makes this thing
	# read at all. Without it the whole hulk stood under four units on a flat that
	# has nothing else standing on it — lower than a fire tower, which is the one
	# height a landmark may not be. Four legs and rings, so it is a lattice and
	# not a stick, and the stays run from its head down the boom.
	var tow: Array[Vector2] = [Vector2(-0.42, -0.42), Vector2(0.42, -0.42), Vector2(0.42, 0.42), Vector2(-0.42, 0.42)]
	var tip := 5.65
	for i in 4:
		var c: Vector2 = tow[i]
		k.strut(Vector3(1.6 + c.x, 3.4, c.y), Vector3(1.6 + c.x * 0.4, tip, c.y * 0.4), 0.06, 4, PLATE)
	for i in 5:
		var t0 := i / 5.0
		var t1 := (i + 1) / 5.0
		var y1 := lerpf(3.4, tip, t1)
		var r1 := lerpf(0.42, 0.17, t1)
		for j in 4:
			var a: Vector2 = tow[j]
			var b: Vector2 = tow[(j + 1) % 4]
			k.strut(Vector3(1.6 + a.x * r1 / 0.42, y1, a.y * r1 / 0.42), Vector3(1.6 + b.x * r1 / 0.42, y1, b.y * r1 / 0.42), 0.032, 4, PLATE_DARK)
			if (i + j) % 2 == 0:
				var y0 := lerpf(3.4, tip, t0)
				var r0 := lerpf(0.42, 0.17, t0)
				k.strut(Vector3(1.6 + a.x * r0 / 0.42, y0, a.y * r0 / 0.42), Vector3(1.6 + b.x * r1 / 0.42, y1, b.y * r1 / 0.42), 0.026, 4, SHADOW)
	k.box(Vector3(1.4, tip, -0.2), Vector3(1.8, tip + 0.1, 0.2), PLATE_DARK, PLATE)
	k.strut(Vector3(1.6, tip + 0.05, 0.0), Vector3(4.6, 0.6, 0.0), 0.05, 4, PLATE_DARK)
	k.strut(Vector3(1.6, tip + 0.05, 0.0), Vector3(-2.4, 1.5, 0.0), 0.05, 4, PLATE_DARK)
	k.strut(Vector3(1.7, 2.9, 0.0), Vector3(4.8, 0.45, 0.0), 0.18, 4, PLATE)
	k.strut(Vector3(1.7, 2.9, 0.0), Vector3(3.4, 1.6, 0.0), 0.09, 4, PLATE_DARK)
	k.strut(Vector3(2.5, 2.2, -0.5), Vector3(2.5, 2.2, 0.5), 0.06, 4, PLATE_DARK)
	# The rake itself, down in the crust where it stopped.
	k.box(Vector3(4.4, 0.14, -1.5), Vector3(5.1, 0.4, 1.5), PLATE_DARK, PLATE)
	for i in 8:
		k.block(4.75, 0.0, -1.3 + i * 0.37, 0.07, 0.24, 0.07, PLATE_DARK)
	# The crust: MADE, uneven, hatched, up the legs, over the walkway and along
	# the whole length of the boom's shadow. The one hulk in the game that is
	# WHITE, which is why it reads at a distance on a white flat.
	for i in 11:
		var t := i / 10.0
		var x := lerpf(-3.0, 5.0, t)
		var z := (Rng.hash01(seed_value, i, 0x71) - 0.5) * 2.4
		made.rock(x, 0.0, z, 0.55 + Rng.hash01(seed_value, i, 0x72) * 0.55, 0.22 + Rng.hash01(seed_value, i, 0x73) * 0.34, seed_value + i, SALT, 6)
	for i in 4:
		made.rock(-2.3 + i * 1.02, 0.5, 1.02, 0.4, 0.42, seed_value + 20 + i, SALT, 6)
	made.rock(1.6, 3.35, 0.0, 0.75, 0.55, seed_value + 44, SALT, 7)
	made.rock(4.7, 0.3, 0.4, 0.6, 0.4, seed_value + 45, SALT, 6)
	# One lens still on the head, lit: the plan has not written this one off.
	lamps.box(Vector3(2.2, 2.3, -0.2), Vector3(2.28, 2.65, 0.2), W.WORKING)
	lamps.box(Vector3(-2.82, 1.62, 1.5), Vector3(-2.76, 1.86, 1.56), W.STRIP)
	lamps.prism(1.6, 5.75, 0.0, 0.16, 6.02, 0.1, 6, W.BEACON, W.BEACON)


## THE GROWN HULK. A hauler-sized machine that died standing and has been in one
## place long enough for the land to come up through it: its back is broken, its
## deck is a floor of soil, and what grows here grows out of it.
static func _grown_hulk(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	# The legs it stood on, three left and one lying: they lift the body clear of
	# the ground, which is what makes it a thing that WALKED and died standing
	# rather than a heap somebody tipped.
	for i in 3:
		var x := -2.8 + i * 2.4
		k.strut(Vector3(x, 1.5, 1.1), Vector3(x + 0.5, 0.0, 2.4), 0.2, 5, PLATE_DARK)
		k.strut(Vector3(x, 1.5, -1.1), Vector3(x - 0.4, 0.0, -2.5), 0.2, 5, PLATE_DARK)
		k.prism(x + 0.5, 0.0, 2.4, 0.34, 0.2, 0.34, 6, PLATE, PLATE_TOP)
	k.strut(Vector3(2.8, 0.22, 2.6), Vector3(5.0, 0.14, 1.4), 0.2, 5, PLATE_DARK)
	# The spine, broken in the middle, both halves tipped away from the break.
	k.push(Transform3D(Basis(Vector3.BACK, -0.18), Vector3(-1.8, 1.4, 0.0)))
	k.box(Vector3(-1.7, 0.0, -1.2), Vector3(1.7, 1.9, 1.2), ENAMEL, ENAMEL_TOP)
	k.box(Vector3(-1.8, 1.9, -1.35), Vector3(1.3, 2.18, 1.35), PLATE_DARK, PLATE)
	k.box(Vector3(-1.72, 0.3, 1.18), Vector3(1.6, 1.0, 1.26), SHADOW, SHADOW)
	k.pop()
	k.push(Transform3D(Basis(Vector3.BACK, 0.44), Vector3(1.7, 1.15, 0.0)))
	k.box(Vector3(-0.9, 0.0, -1.1), Vector3(2.1, 1.6, 1.1), ENAMEL, ENAMEL_TOP)
	k.box(Vector3(-0.9, 1.6, -1.2), Vector3(1.9, 1.84, 1.2), PLATE_DARK, PLATE)
	# Its head, still up, still pointed the way it was going.
	k.prism(2.1, 0.6, 0.0, 0.9, 3.4, 0.4, 6, PLATE, PLATE_TOP)
	k.prism(2.1, 3.4, 0.0, 0.4, 3.7, 0.2, 6, PLATE_DARK, PLATE)
	k.pop()
	# The break: ribs standing out of the gap with nothing between them. The one
	# place the thing is open, and the silhouette's own notch.
	for i in 7:
		var z := -1.0 + i * 0.34
		k.strut(Vector3(-0.5, 1.5, z), Vector3(0.4, 3.4 + Rng.hash01(seed_value, i, 0x81) * 0.8, z * 0.6), 0.07, 4, PLATE_DARK)
	# And the land, which is the whole point: soil banked over the deck, a tree up
	# through the break, scrub in every hollow, moss down the north faces.
	made.rock(-1.7, 3.1, 0.0, 1.7, 0.6, seed_value + 1, P.EARTH[2], 7)
	made.rock(1.7, 2.5, 0.0, 1.2, 0.5, seed_value + 2, P.EARTH[1], 6)
	_limb(made, Vector3(0.1, 2.2, 0.2), Vector3(-0.5, 7.4, -0.4), 0.28, TIMBER, seed_value + 11)
	for i in 4:
		var a := 1.1 + i * 1.3
		_limb(made, Vector3(-0.35, 5.6 + i * 0.3, -0.2), Vector3(-0.35 + cos(a) * 1.5, 6.6 + i * 0.3, -0.2 + sin(a) * 1.5), 0.09, TIMBER, seed_value + 30 + i)
	for i in 6:
		var a := Rng.hash01(seed_value, i, 0x82) * TAU
		var r := 0.8 + Rng.hash01(seed_value, i, 0x83) * 1.2
		made.rock(-0.5 + cos(a) * r, 6.4 + sin(a) * 0.6, -0.4 + sin(a) * r, 1.0, 0.8, seed_value + 20 + i, LEAF if i % 2 == 0 else LEAF_PALE, 6)
	for i in 8:
		var a := Rng.hash01(seed_value, i, 0x84) * TAU
		var r := 2.4 + Rng.hash01(seed_value, i, 0x85) * 2.6
		made.rock(cos(a) * r, 0.0, sin(a) * r, 0.4, 0.36, seed_value + 40 + i, LEAF_PALE, 5)
	made.rock(-2.9, 2.9, -0.7, 0.6, 0.18, seed_value + 60, P.MOSS[2], 6)
	made.rock(2.6, 2.2, 0.8, 0.5, 0.16, seed_value + 61, P.MOSS[1], 6)


## THE CLERK'S POST. A filing post that went over, and every reading it ever took
## out on the ground round it in drifts — still sorted, because the wind took
## them off the top of each stack in order. The one landmark made mostly of paper.
static func _clerks_office(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	# The post: a squat cabin on a plinth, leaning, its door off.
	k.push(Transform3D(Basis(Vector3.BACK, 0.13), Vector3(0.0, 0.0, 0.0)))
	k.box(Vector3(-1.2, 0.0, -1.0), Vector3(1.2, 0.3, 1.0), PLATE_DARK, PLATE)
	k.box(Vector3(-1.0, 0.3, -0.85), Vector3(1.0, 2.5, 0.85), ENAMEL, ENAMEL_TOP)
	k.box(Vector3(-1.1, 2.5, -0.95), Vector3(1.1, 2.72, 0.95), PLATE_DARK, PLATE)
	# The doorway, open and dark, with the door itself lying in front of it.
	k.box(Vector3(0.94, 0.3, -0.42), Vector3(1.02, 1.85, 0.42), SHADOW, SHADOW)
	k.box(Vector3(1.5, 0.02, -0.5), Vector3(3.0, 0.1, 0.34), PLATE, PLATE_TOP)
	# The racks inside, standing, still full: seen through the door.
	for i in 4:
		k.box(Vector3(-0.85, 0.42 + i * 0.5, -0.7), Vector3(0.8, 0.5 + i * 0.5, 0.7), PLATE_DARK, PLATE_DARK)
		made.box(Vector3(-0.8, 0.5 + i * 0.5, -0.64), Vector3(0.7, 0.86 + i * 0.5, 0.64), PAPER_DARK, PAPER)
	# The mast on its cap, snapped off short, and the one lens still reading.
	k.prism(-0.5, 2.72, 0.0, 0.16, 5.1, 0.09, 4, PLATE, PLATE_TOP)
	k.prism(-0.5, 5.1, 0.0, 0.26, 5.34, 0.24, 6, PLATE_DARK, PLATE)
	# Snapped: the top third of it lying where it came down, still wired on.
	k.push(Transform3D(Basis(Vector3.BACK, 1.35), Vector3(-2.4, 0.1, 0.5)))
	k.prism(0.0, 0.0, 0.0, 0.13, 1.7, 0.08, 4, PLATE_DARK, PLATE)
	k.pop()
	lamps.box(Vector3(1.02, 1.0, -0.1), Vector3(1.06, 1.3, 0.1), W.STRIP)
	k.pop()
	# The paper. Drifts of it, banked the way the wind left it, pale against
	# whatever ground this is: the thing that reads from twenty tiles out.
	# FLAT, and wider than they are tall. Drifts drawn at a stone's proportions
	# read as stones, which on a bonelands pavement is exactly what they are not:
	# paper lies down, and what says so is that none of it stands up except the
	# few sheets the wind has caught.
	for i in 26:
		var a := Rng.hash01(seed_value, i, 0x91) * TAU
		var r := 1.5 + Rng.hash01(seed_value, i, 0x92) * 3.8
		var at := Vector3(cos(a) * r, 0.0, sin(a) * r * 0.8)
		made.rock(at.x, at.y, at.z, 0.55 + Rng.hash01(seed_value, i, 0x93) * 0.55, 0.035 + Rng.hash01(seed_value, i, 0x94) * 0.05, seed_value + i, PAPER if i % 3 else PAPER_DARK, 5)
	# And the sheets caught upright on things, which is the whole of what says WIND.
	for i in 9:
		var a := Rng.hash01(seed_value, i, 0x95) * TAU
		var r := 1.9 + Rng.hash01(seed_value, i, 0x96) * 2.4
		made.push(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, 0.35 + Rng.hash01(seed_value, i, 0x97) * 0.4), Vector3(cos(a) * r, 0.0, sin(a) * r)))
		made.box(Vector3(-0.012, 0.0, -0.2), Vector3(0.012, 0.58, 0.2), PAPER, PAPER)
		made.pop()


## THE POURED PILLAR. Under the ground there is no weather and nothing grows, so
## the evidence a cave holds is the working's own. A limestone column stood floor
## to roof here and held the roof up; they cut it out for the stone and poured a
## square concrete one in its place round rebar, while the roof was still on it.
## The pour came up short at the head and was packed out with plate. The stumps
## of the real one are still standing beside it, cut off clean at knee height.
static func _poured_pillar(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	var top := 6.1
	# The flare the natural column left in the floor: MADE, uneven, hatched, and
	# the pour is standing IN it, which is what says one replaced the other.
	made.prism(0.0, 0.0, 0.0, 1.5, 0.42, 1.15, 9, LIME, P.LINEN[4])
	for i in 5:
		var a := Rng.hash01(seed_value, i, 0xC1) * TAU
		made.rock(cos(a) * 1.35, 0.0, sin(a) * 1.35, 0.4 + Rng.hash01(seed_value, i, 0xC2) * 0.24, 0.2, seed_value + i, P.STONE[2], 6)
	# The column: ruled, square, drawn in at each lift so the silhouette is a
	# stepped shaft and not a post — a bare box this tall is the slab ART §2 bans.
	for i in 4:
		var y0 := 0.32 + i * (top - 0.32) / 4.0
		var y1 := 0.32 + (i + 1) * (top - 0.32) / 4.0
		var r := lerpf(0.62, 0.44, i / 3.0)
		k.box(Vector3(-r, y0, -r * 0.82), Vector3(r, y1 - 0.09, r * 0.82), LIME, P.LINEN[4])
		# The shuttering band at every lift: where one pour met the next.
		k.box(Vector3(-r - 0.06, y1 - 0.09, -r * 0.82 - 0.06), Vector3(r + 0.06, y1, r * 0.82 + 0.06), P.LINEN[2], P.LINEN[3])
	# The rebar, coming up out of the head short of the roof, and the plate they
	# packed the gap with: the one thing here that was never meant to be seen.
	for j in 6:
		var o := Vector3(-0.3 + (j % 3) * 0.3, 0.0, -0.18 + (j / 3) * 0.36)
		k.prism(o.x, top - 0.1, o.z, 0.05, top + 0.42 + Rng.hash01(seed_value, j, 0xC3) * 0.5, 0.04, 4, RUST)
	k.box(Vector3(-0.56, top, -0.5), Vector3(0.56, top + 0.16, 0.5), PLATE_DARK, PLATE)
	k.box(Vector3(-0.66, top + 0.16, -0.58), Vector3(0.66, top + 0.34, 0.58), PLATE, PLATE_TOP)
	# The roof it is holding up, jammed down on the pour: ROCK and not a plate, so
	# it reads as the cavern closing on the thing rather than a cap on a post.
	made.rock(0.0, top + 0.3, 0.0, 1.45, 0.62, seed_value + 3, P.STONE[1], 7)
	for i in 3:
		var a := 0.7 + i * 2.1
		made.rock(cos(a) * 1.5, top + 0.12, sin(a) * 1.4, 0.7, 0.4, seed_value + 30 + i, P.STONE[2], 6)
	# The stumps of the columns they took: cut off clean, which is the tell.
	for i in 4:
		var a := 1.1 + i * 1.5
		var r := 2.6 + Rng.hash01(seed_value, i, 0xC4) * 1.1
		var h := 0.7 + Rng.hash01(seed_value, i, 0xC5) * 0.6
		made.prism(cos(a) * r, 0.0, sin(a) * r, 0.5, h, 0.42, 8, P.STONE[2], P.RIME[2])
		made.prism(cos(a) * r, h, sin(a) * r, 0.42, h + 0.05, 0.42, 8, P.RIME[3], P.RIME[3])
	# The gauge they left wired to the pour, still reading the load on it.
	k.box(Vector3(0.6, 1.5, -0.24), Vector3(0.72, 2.05, 0.24), PLATE_DARK, PLATE)
	lamps.box(Vector3(0.72, 1.66, -0.14), Vector3(0.76, 1.9, 0.14), W.WORKING)


## THE SUMP. A gantry on four legs over black water, with the pump hung under it
## and the float down: it kept this level dry for somebody, and stopped. The rim
## of flowstone round the pool is where the water stood before it won.
static func _sump_pump(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	var deck := 2.35
	# The pool, and the lip the water laid round it while it was being held down.
	# Set back off +X, because that is the face the place is approached from and
	# what a player's hands go to stands there: nobody wades to a locker.
	var pool := -0.9
	made.prism(pool, -0.06, 0.0, 3.0, 0.16, 2.8, 11, P.RIME[2], P.RIME[3])
	made.prism(pool, 0.1, 0.0, 2.4, 0.2, 2.3, 11, P.INK[1], P.INK[1])
	for i in 7:
		var a := Rng.hash01(seed_value, i, 0xD1) * TAU
		var r := 2.7 + Rng.hash01(seed_value, i, 0xD2) * 0.8
		made.rock(pool + cos(a) * r, 0.0, sin(a) * r * 0.9, 0.5, 0.22 + Rng.hash01(seed_value, i, 0xD3) * 0.3, seed_value + i, P.RIME[3], 6)
	# Four legs standing in it, braced, each with its own foot plate.
	var feet: Array[Vector2] = [Vector2(-1.25, -1.05), Vector2(1.25, -1.05), Vector2(1.25, 1.05), Vector2(-1.25, 1.05)]
	for i in 4:
		var f: Vector2 = feet[i]
		k.box(Vector3(f.x - 0.26, -0.05, f.y - 0.26), Vector3(f.x + 0.26, 0.2, f.y + 0.26), PLATE_DARK, PLATE)
		k.prism(f.x, 0.2, f.y, 0.19, deck, 0.13, 4, PLATE, PLATE_TOP)
		var g: Vector2 = feet[(i + 1) % 4]
		k.strut(Vector3(f.x, 0.5, f.y), Vector3(g.x, deck - 0.25, g.y), 0.045, 4, SHADOW)
	# The gantry: a grating floor of separate bearers, not one plate.
	k.box(Vector3(-1.45, deck, -1.25), Vector3(1.45, deck + 0.1, 1.25), PLATE_DARK, PLATE)
	for i in 6:
		var x := -1.3 + i * 0.52
		k.box(Vector3(x - 0.06, deck + 0.1, -1.18), Vector3(x + 0.06, deck + 0.16, 1.18), PLATE, PLATE_TOP)
	for side: float in [-1.0, 1.0]:
		k.box(Vector3(-1.45, deck + 0.16, side * 1.2 - 0.04), Vector3(1.45, deck + 0.22, side * 1.2 + 0.04), PLATE, PLATE_TOP)
		k.box(Vector3(-1.45, deck + 0.7, side * 1.2 - 0.04), Vector3(1.45, deck + 0.76, side * 1.2 + 0.04), PLATE, PLATE_TOP)
		for i in 4:
			k.block(-1.2 + i * 0.8, deck + 0.16, side * 1.2, 0.07, 0.6, 0.07, PLATE_DARK)
	# The pump house on the deck: drawn in at the shoulder, capped, with a door.
	k.box(Vector3(-1.1, deck + 0.16, -0.72), Vector3(0.1, deck + 1.5, 0.72), ENAMEL, ENAMEL_TOP)
	k.box(Vector3(-1.0, deck + 1.5, -0.62), Vector3(0.0, deck + 1.78, 0.62), ENAMEL_TOP, PLATE)
	k.box(Vector3(-1.14, deck + 1.78, -0.74), Vector3(0.14, deck + 1.9, 0.74), PLATE_DARK, PLATE)
	k.box(Vector3(0.1, deck + 0.3, -0.34), Vector3(0.16, deck + 1.3, 0.34), SHADOW, SHADOW)
	for j in 3:
		k.box(Vector3(-1.12, deck + 0.4 + j * 0.34, -0.5), Vector3(-1.06, deck + 0.62 + j * 0.34, 0.5), PLATE_DARK, PLATE_DARK)
	# The rising main down into the water, and the delivery going off into the dark.
	k.prism(-0.55, 0.14, 0.4, 0.2, deck + 0.4, 0.2, 8, PLATE, PLATE_TOP)
	k.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.6, deck + 0.9, -0.2)))
	k.prism(0.0, 0.0, 0.0, 0.17, 2.6, 0.17, 8, PLATE_DARK, PLATE)
	k.pop()
	# The float on its chain, DOWN, which is the whole of what the place says.
	k.prism(1.05, 0.16, 0.55, 0.26, 0.5, 0.2, 7, RUST, PLATE)
	_cable(made, Vector3(1.05, deck + 0.1, 0.55), Vector3(1.05, 0.5, 0.55), 0.028, P.STONE[2], seed_value + 7)
	# The vent riser off the house, up into the dark, with its cowl: the one thing
	# in a sump that stands, and what makes the shape read across a cave floor.
	k.prism(-0.55, deck + 1.9, -0.3, 0.2, deck + 2.9, 0.17, 6, PLATE, PLATE_TOP)
	k.prism(-0.55, deck + 2.9, -0.3, 0.34, deck + 3.06, 0.3, 6, PLATE_DARK, PLATE)
	k.push(Transform3D(Basis(Vector3.BACK, 0.5), Vector3(-0.55, deck + 3.06, -0.3)))
	k.prism(0.0, 0.0, 0.0, 0.3, 0.42, 0.26, 6, PLATE, PLATE_TOP)
	k.pop()
	for i in 3:
		k.strut(Vector3(-0.55, deck + 2.5, -0.3), Vector3(-0.55 + cos(2.1 * i) * 0.62, deck + 0.2, -0.3 + sin(2.1 * i) * 0.62), 0.035, 4, PLATE_DARK)
	# One strip alive on the house, and the gauge lens still reading the level.
	lamps.box(Vector3(0.16, deck + 1.02, -0.12), Vector3(0.2, deck + 1.34, 0.12), W.STRIP)
	lamps.box(Vector3(-1.16, deck + 0.9, -0.16), Vector3(-1.12, deck + 1.16, 0.16), W.WORKING)
	lamps.prism(-0.55, deck + 3.2, -0.3, 0.13, deck + 3.42, 0.08, 6, W.BEACON, W.BEACON)


# --- shared hands ---------------------------------------------------------------

## A slightly bent MADE limb from a to b: the kit's own shape, without a PropKit.
static func _limb(k: MeshKit, a: Vector3, b: Vector3, r: float, col: Color, seed_value: int) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 1e-5:
		return
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	k.push(Transform3D(Basis(side, up, side.cross(up)), a))
	k.prism(0, 0, 0, r * (1.0 + Rng.hash01(seed_value, 1, 0xA1) * 0.14), length, r * 0.8, 5, col)
	k.pop()


## A cable between two points with a sag in it: four short limbs, so it reads as
## something with weight rather than a ruled line (a guy that parted is MADE).
static func _cable(k: MeshKit, a: Vector3, b: Vector3, r: float, col: Color, seed_value: int) -> void:
	var sag := a.distance_to(b) * 0.12
	for i in 4:
		var p := a.lerp(b, i / 4.0)
		var q := a.lerp(b, (i + 1) / 4.0)
		p.y -= sag * sin(PI * i / 4.0)
		q.y -= sag * sin(PI * (i + 1) / 4.0)
		_limb(k, p, q, r, col, seed_value + i)


## The gallery: every kind, and the cache both ways, so a review can judge the
## silhouettes side by side without walking a world.
##   tools/shot.sh shots/x.png --scene=gallery --filter=landmark
static func gallery() -> Array:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/render/world.gdshader")
	var out: Array = []
	for d: LandmarkDef in Landmarks.all():
		out.append({"name": "landmark_%s" % d.id, "node": node(d.id, 11, mat)})
	var opened := node(&"cast_stones", 11, mat)
	set_opened(opened, true)
	out.append({"name": "landmark_cache_opened", "node": opened})
	return out
