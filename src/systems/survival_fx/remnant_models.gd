class_name RemnantModels
## What taking leaves in the world while a thing is gone: a stump where a tree
## was felled, rubble where rock was broken, cut stubble where reeds or gorse
## were cut, a cut face where peat was taken. MADE-world ramps, low and quiet:
## they are marks, not props, and never block.
##
##   RemnantModels.mesh(&"stump")      # shared, built once
##   RemnantModels.for_kind(PropKind.PINE) -> &"stump" (or &"" for nothing)

const NAMES: Array[StringName] = [&"stump", &"rubble", &"stubble", &"cut", &"tapped", &"picked"]


## The mark on a prop that is still standing but picked over for now: a tapped
## trunk weeps resin into a cup; anything else has the leavings of the picking
## at its foot.
static func worked_for(kind: int) -> StringName:
	match kind:
		PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE:
			return &"tapped"
	return &"picked"

static var _cache: Dictionary = {}


static func for_kind(kind: int) -> StringName:
	match kind:
		PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE:
			return &"stump"
		PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, \
				PropKind.TIN_ORE, PropKind.CLINTS, PropKind.RUIN, PropKind.WRECK, PropKind.POLE, PropKind.PYLON:
			return &"rubble"
		PropKind.REEDS, PropKind.GORSE:
			return &"stubble"
		PropKind.PEAT_BANK:
			return &"cut"
	return &""


static func mesh(name: StringName) -> ArrayMesh:
	if not _cache.has(name):
		var k := MeshKit.new()
		# Broken rock is drawn in the rock's own strata strokes; the rest in the hand.
		if name == &"rubble":
			k.style = Ink.CONTOUR
			k.style2 = Ink.CONTOUR
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
		_cache[name] = k.build()
	return _cache[name]


## Bark sides leaning off true, a pale axe-cut face stepped where the last fibres
## tore, two root knuckles, and chips of the cut lying round it.
static func _stump(k: MeshKit) -> void:
	# Wider than the trunk it was: from above, the cut face is what reads, so it sits
	# in a dark lip of bark (the outline pass never reaches anything this low) with
	# its rings drawn in, and the last torn fibres stand up off one side.
	k.prism(0, -0.05, 0, 0.25, 0.19, 0.22, 8, Palette.EARTH[1], Palette.EARTH[1], 0.3)
	k.prism(0.0, 0.19, 0.0, 0.19, 0.205, 0.18, 8, Palette.SAND[4], Palette.SAND[4], 0.3)
	k.prism(0.02, 0.205, 0.01, 0.09, 0.212, 0.085, 7, Palette.SAND[3], Palette.EARTH[3], 0.6)
	k.prism(0.1, 0.19, 0.06, 0.07, 0.3, 0.035, 5, Palette.EARTH[2], Palette.SAND[5], 0.5)
	k.strut(Vector3(0.08, 0.0, 0.05), Vector3(0.25, -0.03, 0.12), 0.042, 4, Palette.EARTH[1])
	k.strut(Vector3(-0.07, 0.0, -0.06), Vector3(-0.21, -0.03, -0.16), 0.036, 4, Palette.EARTH[1])
	for i in 6:
		var a := Rng.hash01(71, i) * TAU
		var r := 0.22 + Rng.hash01(72, i) * 0.3
		_chip(k, Vector3(cos(a) * r, 0.0, sin(a) * r), 0.05 + Rng.hash01(73, i) * 0.025, a * 2.0, Palette.SAND[5] if i % 2 else Palette.EARTH[4])


## A low scar and a scatter of broken, faceted stone.
static func _rubble(k: MeshKit) -> void:
	k.rock(0, -0.03, 0, 0.3, 0.07, 81, Palette.STONE[2], 7)
	for i in 7:
		var a := Rng.hash01(82, i) * TAU
		var r := 0.12 + Rng.hash01(83, i) * 0.3
		var sz := 0.05 + Rng.hash01(84, i) * 0.07
		k.rock(cos(a) * r, -0.01, sin(a) * r, sz, sz * 1.4, 85 + i, Palette.STONE[3] if i % 3 else Palette.STONE[4], 5)


## Short pale stubs where stems stood, cut on a slant.
static func _stubble(k: MeshKit) -> void:
	for i in 9:
		var a := Rng.hash01(91, i) * TAU
		var r := Rng.hash01(92, i) * 0.3
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var lean := Vector3(Rng.hash01(94, i) - 0.5, 0.0, Rng.hash01(95, i) - 0.5) * 0.05
		k.strut(base, base + lean + Vector3(0.0, 0.07 + Rng.hash01(93, i) * 0.07, 0.0), 0.024, 3, Palette.SAND[4] if i % 2 else Palette.MOSS[2])


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


## What a picking leaves: pale broken shells, a torn stem, a turned stone, at the foot.
static func _picked(k: MeshKit) -> void:
	for i in 6:
		var a := Rng.hash01(101, i) * TAU
		var r := 0.32 + Rng.hash01(102, i) * 0.2
		_chip(k, Vector3(cos(a) * r, 0.0, sin(a) * r), 0.055 + Rng.hash01(103, i) * 0.02, a * 2.0, Palette.LINEN[5] if i % 3 else Palette.EARTH[3])


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


static func gallery() -> Array:
	var out: Array = []
	for name in NAMES:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh(name)
		out.append({"name": String(name), "node": mi})
	return out
