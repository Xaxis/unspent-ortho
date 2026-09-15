class_name RemnantModels
## What taking leaves in the world while a thing is gone: a stump where a tree
## was felled, rubble where rock was broken, cut stubble where reeds or gorse
## were cut, a cut face where peat was taken, bent plate where a machine's
## leavings were broken up. Low and quiet: they are marks, not props, and never
## block. Each is sized to read at 640x360, and carries both a dark and a pale
## part so it shows on sand and on ash alike.
##
## MADE leavings (stump, rubble, stubble, cut, tapped, picked) are drawn on the
## world material; FOUND leavings (plate) on the ruler's (docs/ART.md law 3).
##
##   RemnantModels.mesh(&"stump")                  # shared, built once
##   RemnantModels.for_kind(PropKind.PINE) -> &"stump" (or &"" for nothing)
##   RemnantModels.worked_for(kind, verb)          the mark on a picked-over thing still standing
##   RemnantModels.is_found(&"plate") -> true      draw it with found.gdshader

const NAMES: Array[StringName] = [&"stump", &"rubble", &"stubble", &"cut", &"tapped", &"picked", &"plate"]
const FOUND_KINDS: Array[int] = [PropKind.TIP, PropKind.WRECK, PropKind.POLE, PropKind.PYLON]


## The mark on a prop that is still standing but picked over for now: a tapped
## trunk weeps resin into a cup; a picked tip or wreck has bent plate turned out
## round it; anything else has the leavings of the picking at its foot.
static func worked_for(kind: int, verb: StringName = &"") -> StringName:
	if verb == &"tap":
		return &"tapped"
	if FOUND_KINDS.has(kind):
		return &"plate"
	return &"picked"


static func is_found(name: StringName) -> bool:
	return name == &"plate"

static var _cache: Dictionary = {}


static func for_kind(kind: int) -> StringName:
	match kind:
		PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE:
			return &"stump"
		PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, \
				PropKind.TIN_ORE, PropKind.CLINTS, PropKind.RUIN:
			return &"rubble"
		PropKind.WRECK, PropKind.POLE, PropKind.PYLON:
			return &"plate"
		PropKind.REEDS, PropKind.GORSE:
			return &"stubble"
		PropKind.PEAT_BANK:
			return &"cut"
	return &""


static func mesh(name: StringName) -> ArrayMesh:
	if not _cache.has(name):
		var k := MeshKit.new()
		# Broken rock is drawn in the rock's own strata strokes; plate is never hatched.
		if name == &"rubble":
			k.style = Ink.CONTOUR
			k.style2 = Ink.CONTOUR
		elif name == &"plate":
			k.style = Ink.NONE
			k.style2 = Ink.NONE
		match name:
			&"stump":
				_stump(k)
			&"rubble":
				_rubble(k)
			&"stubble":
				_stubble(k)
			&"cut":
				_cut(k)
			&"tapped":
				_tapped(k)
			&"picked":
				_picked(k)
			&"plate":
				_plate(k)
		_cache[name] = k.build()
	return _cache[name]


## Bark sides leaning off true, a pale axe-cut face stepped where the last fibres
## tore, two root knuckles, and chips of the cut lying round it.
static func _stump(k: MeshKit) -> void:
	# Wider than the trunk it was: from above, the cut face is what reads, so it sits
	# in a dark lip of bark (the outline pass never reaches anything this low) with
	# its rings drawn in, and the last torn fibres stand up off one side.
	k.prism(0, -0.05, 0, 0.3, 0.24, 0.26, 8, Palette.EARTH[0], Palette.EARTH[0], 0.3)
	k.prism(0.0, 0.24, 0.0, 0.23, 0.255, 0.22, 8, Palette.SAND[5], Palette.SAND[5], 0.3)
	k.prism(0.02, 0.255, 0.01, 0.11, 0.262, 0.1, 7, Palette.SAND[3], Palette.EARTH[3], 0.6)
	k.prism(0.12, 0.24, 0.07, 0.08, 0.36, 0.04, 5, Palette.EARTH[2], Palette.SAND[5], 0.5)
	k.strut(Vector3(0.1, 0.0, 0.06), Vector3(0.33, -0.03, 0.15), 0.05, 4, Palette.EARTH[1])
	k.strut(Vector3(-0.08, 0.0, -0.07), Vector3(-0.28, -0.03, -0.2), 0.045, 4, Palette.EARTH[1])
	for i in 8:
		var a := Rng.hash01(71, i) * TAU
		var r := 0.32 + Rng.hash01(72, i) * 0.3
		_chip(k, Vector3(cos(a) * r, 0.0, sin(a) * r), 0.065 + Rng.hash01(73, i) * 0.03, a * 2.0, Palette.SAND[5] if i % 2 else Palette.EARTH[1])


## A dark scar where the rock sat, and broken stone round it showing its pale
## inside: big enough pieces to catch the light at the size the game is played.
static func _rubble(k: MeshKit) -> void:
	var ring: Array[Vector3] = []
	for i in 10:
		var a := float(i) / 10.0 * TAU
		var r := 0.42 * (0.75 + Rng.hash01(80, i) * 0.4)
		ring.append(Vector3(cos(a) * r, 0.015, sin(a) * r * 0.85))
	for i in 10:
		k.tri(Vector3(0, 0.02, 0), ring[(i + 1) % 10], ring[i], Palette.STONE[1])
	for i in 9:
		var a := Rng.hash01(82, i) * TAU
		var r := 0.12 + Rng.hash01(83, i) * 0.34
		var sz := 0.1 + Rng.hash01(84, i) * 0.08
		var col := Palette.LINEN[5] if i % 3 == 0 else (Palette.STONE[5] if i % 3 == 1 else Palette.STONE[3])
		k.rock(cos(a) * r, -0.01, sin(a) * r, sz, sz * 1.6, 85 + i, col, 5)


## Stubs where stems stood, cut on a slant and pale at the cut, over the dark wet
## ground they grew from, and a few cut stems dropped across it.
static func _stubble(k: MeshKit) -> void:
	# A ragged patch of the bed's wet ground, never a disc: the reeds stood in clumps.
	var ring: Array[Vector3] = []
	for i in 13:
		var a := float(i) / 13.0 * TAU
		var r := 0.4 * (0.55 + Rng.hash01(90, i) * 0.6)
		ring.append(Vector3(cos(a) * r, 0.012, sin(a) * r * 0.8))
	for i in 13:
		k.tri(Vector3(0, 0.014, 0), ring[(i + 1) % 13], ring[i], Palette.EARTH[2])
	for i in 16:
		var a := Rng.hash01(91, i) * TAU
		var r := sqrt(Rng.hash01(92, i)) * 0.3
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var lean := Vector3(Rng.hash01(94, i) - 0.5, 0.0, Rng.hash01(95, i) - 0.5) * 0.06
		var top := base + lean + Vector3(0.0, 0.07 + Rng.hash01(93, i) * 0.08, 0.0)
		k.strut(base, top, 0.03, 3, Palette.MOSS[2] if i % 3 == 0 else Palette.SAND[3])
		k.prism(top.x, top.y - 0.01, top.z, 0.034, top.y + 0.012, 0.022, 3, Palette.SAND[5], Palette.SAND[5])
	for i in 4:
		var from := Vector3(-0.22 + Rng.hash01(96, i) * 0.1, 0.03, -0.18 + i * 0.12)
		var to := from + Vector3(0.34 + Rng.hash01(97, i) * 0.1, 0.0, (Rng.hash01(98, i) - 0.5) * 0.14)
		k.strut(from, to, 0.024, 3, Palette.SAND[4] if i % 2 else Palette.SAND[5])


## Where peat was taken: a dark, ragged-edged hollow cut into the bank, and three
## turves stood on end against each other to dry, the way they are left.
static func _cut(k: MeshKit) -> void:
	var ring: Array[Vector3] = []
	for i in 9:
		var a := float(i) / 9.0 * TAU
		var rx := 0.4 * (0.8 + Rng.hash01(111, i) * 0.35)
		var rz := 0.28 * (0.8 + Rng.hash01(112, i) * 0.35)
		ring.append(Vector3(cos(a) * rx, 0.02, sin(a) * rz))
	var floor_c := Vector3(0.02, -0.02, 0.0)
	for i in 9:
		k.tri(floor_c, ring[(i + 1) % 9], ring[i], Palette.EARTH[0])
	for i in 3:
		var at := Vector3(-0.16 + i * 0.15, 0.0, 0.4 + (Rng.hash01(113, i) - 0.5) * 0.06)
		k.push(Transform3D(Basis(Vector3.UP, 0.5 + i * 0.35).rotated(Vector3.RIGHT, (i - 1) * 0.35), at))
		k.prism(0, 0, 0, 0.075, 0.16, 0.06, 4, Palette.EARTH[1], Palette.EARTH[2], 0.35)
		k.pop()


## A blaze cut low in the bark, a runnel of amber, and the cup set out past the
## crown's edge where it can be seen from above (a crown hides the trunk).
## Faces +X; the instance is turned toward the camera's side.
static func _tapped(k: MeshKit) -> void:
	k.quad(Vector3(0.115, 0.06, -0.05), Vector3(0.115, 0.06, 0.05), Vector3(0.1, 0.3, 0.035), Vector3(0.1, 0.28, -0.045), Palette.SAND[5])
	k.strut(Vector3(0.12, 0.1, 0.0), Vector3(0.62, 0.07, 0.03), 0.018, 3, Palette.COPPER[3])
	k.prism(0.72, 0.0, 0.04, 0.075, 0.11, 0.085, 6, Palette.EARTH[2], Palette.COPPER[4])


## What a picking leaves: broken shells, a torn stem, a turned stone, at the foot.
static func _picked(k: MeshKit) -> void:
	for i in 8:
		var a := Rng.hash01(101, i) * TAU
		var r := 0.34 + Rng.hash01(102, i) * 0.24
		_chip(k, Vector3(cos(a) * r, 0.0, sin(a) * r), 0.07 + Rng.hash01(103, i) * 0.03, a * 2.0,
			Palette.LINEN[5] if i % 3 else Palette.EARTH[1])


## FOUND: pieces of plate turned out and left lying, each bent once on a straight
## crease, both faces drawn, and a length of rod. Machine-made: never hatched.
static func _plate(k: MeshKit) -> void:
	for i in 4:
		var a := float(i) / 4.0 * TAU + 0.5 + Rng.hash01(121, i) * 0.6
		var r := 0.3 + Rng.hash01(122, i) * 0.16
		var sz := 0.15 + Rng.hash01(123, i) * 0.06
		k.push(Transform3D(Basis(Vector3.UP, a * 1.7), Vector3(cos(a) * r, 0.0, sin(a) * r)))
		var lift := 0.06 + Rng.hash01(124, i) * 0.07
		# A flat panel and a bent-up flap on a straight crease at x = 0; corners cut off true.
		var p0 := Vector3(-sz, 0.012, -sz * 0.55)
		var p1 := Vector3(0.0, 0.012, -sz * 0.75)
		var p2 := Vector3(0.0, 0.012, sz * 0.75)
		var p3 := Vector3(-sz * 0.8, 0.012, sz * 0.6)
		var q1 := Vector3(sz * 0.7, lift, -sz * 0.6)
		var q2 := Vector3(sz * 0.85, lift, sz * 0.5)
		var face := Palette.PLATE[4] if i % 2 else Palette.PLATE[3]
		_two_sided(k, p0, p3, p2, p1, face, Palette.PLATE[1])
		_two_sided(k, p1, p2, q2, q1, face.lerp(Palette.PLATE[5], 0.4), Palette.PLATE[1])
		# The rubbed edge along the crease.
		k.strut(p1 + Vector3(0, 0.014, 0), p2 + Vector3(0, 0.014, 0), 0.016, 3, Palette.PLATE[5])
		k.pop()
	k.strut(Vector3(-0.46, 0.025, 0.1), Vector3(0.12, 0.035, 0.5), 0.026, 4, Palette.RUST[4])


## A thin sheet with its top face (a, b, c, d counter-clockwise seen from above) and its underside.
static func _two_sided(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, top: Color, under: Color) -> void:
	k.quad(a, b, c, d, top)
	k.quad(d, c, b, a, under)


## A flake lying on the ground: a low, lopsided wedge, never a block.
static func _chip(k: MeshKit, at: Vector3, sz: float, turn: float, col: Color) -> void:
	k.push(Transform3D(Basis(Vector3.UP, turn), at))
	var a := Vector3(-sz, 0.0, -sz * 0.45)
	var b := Vector3(sz * 1.1, 0.0, -sz * 0.2)
	var c := Vector3(-sz * 0.2, 0.0, sz * 0.55)
	var top := Vector3(sz * 0.15, sz * 0.45, 0.0)
	k.tri(a, b, top, col)
	k.tri(b, c, top, col.darkened(0.12))
	k.tri(c, a, top, col.darkened(0.06))
	k.pop()
