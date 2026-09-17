class_name LandmarkModels
## The eight places worth the walk, drawn (docs/VISION.md §3, §8; docs/ART.md).
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
const ENAMEL := Color(0.2290, 0.1981, 0.3137)
const ENAMEL_TOP := Color(0.3176, 0.2695, 0.4413)
## What people built and what is left of them.
const STONE := Color(0.2902, 0.3333, 0.4000)
const STONE_TOP := Color(0.4275, 0.4784, 0.5490)
const LIME := Color(0.5882, 0.5412, 0.4627)
const TIMBER := Color(0.3098, 0.2118, 0.1529)
const TIMBER_PALE := Color(0.4353, 0.3020, 0.1922)
const SACKING := Color(0.4353, 0.3961, 0.3490)
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
	# The cabin: a deck, a rail, four posts, a hipped cap, and no glass.
	var deck := top
	made.box(Vector3(-0.95, deck, -0.95), Vector3(0.95, deck + 0.12, 0.95), TIMBER, TIMBER_PALE)
	for i in 4:
		var f := feet[i] * 0.78
		made.block(f.x, deck + 0.12, f.y, 0.09, 1.25, 0.09, TIMBER)
	made.box(Vector3(-0.9, deck + 0.12, -0.9), Vector3(0.9, deck + 0.5, -0.82), TIMBER_PALE, TIMBER_PALE)
	made.box(Vector3(-0.9, deck + 0.12, 0.82), Vector3(0.9, deck + 0.5, 0.9), TIMBER_PALE, TIMBER_PALE)
	made.prism(0.0, deck + 1.37, 0.0, 1.15, deck + 1.9, 0.16, 4, P.SLATE[2], P.SLATE[3])
	# The dark inside, which is what says the glass has gone.
	made.box(Vector3(-0.72, deck + 0.5, -0.72), Vector3(0.72, deck + 1.3, 0.72), P.INK[2], P.INK[2])
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
		k.quad(Vector3(x1 + w1, h * t1, -d1), Vector3(x1 - w1, h * t1, -d1), Vector3(x0 - w0, h * t0, -d0), Vector3(x0 + w0, h * t0, -d0), col)
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
	# The body: a long tank on four short legs, square, ruled.
	k.box(Vector3(-2.6, 0.55, -1.0), Vector3(1.4, 2.3, 1.0), ENAMEL, ENAMEL_TOP)
	for i in 4:
		var x := -2.2 + (i % 2) * 3.2
		var z := -0.7 + (i / 2) * 1.4
		k.box(Vector3(x - 0.18, 0.0, z - 0.18), Vector3(x + 0.18, 0.6, z + 0.18), PLATE_DARK, PLATE)
	# The hopper head and the boom: the shape, carried out over the pan.
	k.prism(1.4, 1.3, 0.0, 0.9, 2.9, 0.62, 6, PLATE, PLATE_TOP)
	k.strut(Vector3(1.5, 2.6, 0.0), Vector3(4.3, 0.42, 0.0), 0.16, 4, PLATE)
	k.strut(Vector3(1.5, 2.6, 0.0), Vector3(3.1, 1.5, 0.0), 0.08, 4, PLATE_DARK)
	# The rake itself, down in the crust where it stopped.
	k.box(Vector3(3.9, 0.12, -1.3), Vector3(4.5, 0.34, 1.3), PLATE_DARK, PLATE)
	for i in 7:
		k.block(4.2, 0.0, -1.15 + i * 0.38, 0.06, 0.2, 0.06, PLATE_DARK)
	# The crust: MADE, uneven, hatched, up the legs and over the boom's shadow.
	for i in 9:
		var t := i / 8.0
		var x := lerpf(-2.6, 4.4, t)
		var z := (Rng.hash01(seed_value, i, 0x71) - 0.5) * 2.0
		made.rock(x, 0.0, z, 0.5 + Rng.hash01(seed_value, i, 0x72) * 0.5, 0.2 + Rng.hash01(seed_value, i, 0x73) * 0.3, seed_value + i, SALT, 6)
	made.box(Vector3(-2.7, 0.5, -1.06), Vector3(1.5, 0.78, 1.06), SALT, P.LINEN[5])
	made.rock(1.5, 2.9, 0.0, 0.7, 0.5, seed_value + 44, SALT, 7)
	# One lens still on the head, lit: the plan has not written this one off.
	lamps.box(Vector3(1.9, 2.1, -0.18), Vector3(1.96, 2.4, 0.18), W.WORKING)


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
	k.prism(-0.5, 2.72, 0.0, 0.14, 4.0, 0.09, 4, PLATE, PLATE_TOP)
	k.prism(-0.5, 4.0, 0.0, 0.22, 4.2, 0.2, 6, PLATE_DARK, PLATE)
	lamps.box(Vector3(1.02, 1.0, -0.1), Vector3(1.06, 1.3, 0.1), W.STRIP)
	k.pop()
	# The paper. Drifts of it, banked the way the wind left it, pale against
	# whatever ground this is: the thing that reads from twenty tiles out.
	for i in 22:
		var a := Rng.hash01(seed_value, i, 0x91) * TAU
		var r := 1.6 + Rng.hash01(seed_value, i, 0x92) * 3.6
		var at := Vector3(cos(a) * r, 0.0, sin(a) * r * 0.8)
		made.rock(at.x, at.y, at.z, 0.34 + Rng.hash01(seed_value, i, 0x93) * 0.4, 0.07 + Rng.hash01(seed_value, i, 0x94) * 0.1, seed_value + i, PAPER if i % 3 else PAPER_DARK, 5)
	# And a few sheets caught upright on things, which is what says WIND.
	for i in 5:
		var a := Rng.hash01(seed_value, i, 0x95) * TAU
		var r := 2.2 + Rng.hash01(seed_value, i, 0x96) * 2.0
		made.push(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, 0.4), Vector3(cos(a) * r, 0.0, sin(a) * r)))
		made.box(Vector3(-0.01, 0.0, -0.16), Vector3(0.01, 0.42, 0.16), PAPER, PAPER)
		made.pop()


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
