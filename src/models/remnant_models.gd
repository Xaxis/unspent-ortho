class_name RemnantModels
## What taking leaves in the world while a thing is gone: a stump where a tree
## was felled, rubble where rock was broken, cut stubble where reeds or gorse
## were cut, a cut face where peat was taken. MADE-world ramps, low and quiet:
## they are marks, not props, and never block.
##
##   RemnantModels.mesh(&"stump")      # shared, built once
##   RemnantModels.for_kind(PropKind.PINE) -> &"stump" (or &"" for nothing)

const NAMES: Array[StringName] = [&"stump", &"rubble", &"stubble", &"cut"]

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
		match name:
			&"stump":
				_stump(k)
			&"rubble":
				_rubble(k)
			&"stubble":
				_stubble(k)
			&"cut":
				_cut(k)
		_cache[name] = k.build()
	return _cache[name]


## Bark sides, a pale axe-cut face stepped where the last fibres tore, a root knuckle, chips.
static func _stump(k: MeshKit) -> void:
	k.prism(0, -0.05, 0, 0.14, 0.15, 0.12, 6, Palette.EARTH[2], Palette.SAND[4], 0.3)
	k.prism(0.03, 0.151, 0.01, 0.07, 0.2, 0.05, 5, Palette.EARTH[3], Palette.SAND[5], 0.5)
	k.strut(Vector3(0.08, 0.0, 0.05), Vector3(0.24, -0.03, 0.11), 0.04, 4, Palette.EARTH[1])
	k.strut(Vector3(-0.07, 0.0, -0.06), Vector3(-0.2, -0.03, -0.15), 0.035, 4, Palette.EARTH[1])
	for i in 6:
		var a := Rng.hash01(71, i) * TAU
		var r := 0.22 + Rng.hash01(72, i) * 0.3
		k.push(Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r, 0.0, sin(a) * r)))
		k.block(0, 0.0, 0, 0.08, 0.025, 0.04, Palette.SAND[5] if i % 2 else Palette.EARTH[4])
		k.pop()


## A low scar and a scatter of broken stone.
static func _rubble(k: MeshKit) -> void:
	k.rock(0, -0.03, 0, 0.3, 0.07, 81, Palette.STONE[2], 7)
	for i in 7:
		var a := Rng.hash01(82, i) * TAU
		var r := 0.12 + Rng.hash01(83, i) * 0.3
		var s := 0.05 + Rng.hash01(84, i) * 0.07
		k.rock(cos(a) * r, -0.01, sin(a) * r, s, s * 1.4, 85 + i, Palette.STONE[3] if i % 3 else Palette.STONE[4], 5)


## Short pale stubs where stems stood.
static func _stubble(k: MeshKit) -> void:
	for i in 9:
		var a := Rng.hash01(91, i) * TAU
		var r := Rng.hash01(92, i) * 0.3
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		k.strut(base, base + Vector3(0.0, 0.07 + Rng.hash01(93, i) * 0.07, 0.0), 0.024, 3, Palette.SAND[4] if i % 2 else Palette.MOSS[2])


## A dark cut face and three turves stacked to dry.
static func _cut(k: MeshKit) -> void:
	k.block(0, -0.03, 0, 0.7, 0.06, 0.5, Palette.EARTH[0])
	for i in 3:
		k.block(-0.2 + i * 0.2, 0.03, 0.36, 0.14, 0.09, 0.1, Palette.EARTH[1], Palette.EARTH[2])


static func gallery() -> Array:
	var out: Array = []
	for name in NAMES:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh(name)
		out.append({"name": String(name), "node": mi})
	return out
