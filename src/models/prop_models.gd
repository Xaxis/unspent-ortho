class_name PropModels
## One mesh per PropKind, built once and shared by every instance. Instances get
## rotation, scale and a small colour wobble from the MultiMesh, so a wood of one
## pine mesh still reads as many trees.
##
## MADE things (houses, lamps) are uneven; FOUND things (pylons) are exact.

static var _cache: Dictionary = {}


static func mesh(kind: int) -> ArrayMesh:
	if not _cache.has(kind):
		_cache[kind] = _build(kind)
	return _cache[kind]


static func _build(kind: int) -> ArrayMesh:
	var k := MeshKit.new()
	match kind:
		PropKind.PINE:
			k.prism(0, 0, 0, 0.09, 0.5, 0.07, 5, Palette.EARTH[1])
			k.prism(0, 0.35, 0, 0.62, 1.25, 0.0, 7, Palette.SPRUCE[2], Color(0, 0, 0, 0), 0.2)
			k.prism(0, 0.9, 0, 0.5, 1.85, 0.0, 7, Palette.SPRUCE[3], Color(0, 0, 0, 0), 0.6)
			k.prism(0, 1.45, 0, 0.34, 2.35, 0.0, 6, Palette.SPRUCE[3].lerp(Palette.SPRUCE[4], 0.4), Color(0, 0, 0, 0), 1.1)
		PropKind.BROADLEAF:
			k.prism(0, 0, 0, 0.12, 0.9, 0.08, 5, Palette.EARTH[2])
			k.rock(0.05, 0.7, 0.0, 0.72, 1.1, 101, Palette.MOSS[2], 7)
			k.rock(-0.25, 1.0, 0.15, 0.45, 0.8, 102, Palette.MOSS[3], 6)
			k.rock(0.28, 1.05, -0.12, 0.4, 0.7, 103, Palette.MOSS[3].lerp(Palette.SPRUCE[3], 0.5), 6)
		PropKind.DEAD_TREE:
			k.prism(0, 0, 0, 0.1, 1.5, 0.05, 5, Palette.ASH[2])
			k.strut(Vector3(0, 0.9, 0), Vector3(0.45, 1.35, 0.1), 0.04, 4, Palette.ASH[2])
			k.strut(Vector3(0, 1.15, 0), Vector3(-0.35, 1.6, -0.1), 0.035, 4, Palette.ASH[1])
		PropKind.BUSH:
			k.rock(0, 0, 0, 0.38, 0.42, 201, Palette.MOSS[2], 6)
			k.rock(0.18, 0, 0.1, 0.24, 0.3, 202, Palette.MOSS[3], 5)
		PropKind.REEDS:
			for i in 7:
				var a := Rng.hash01(301, i) * TAU
				var r := Rng.hash01(302, i) * 0.3
				var base := Vector3(cos(a) * r, 0, sin(a) * r)
				var tip := base + Vector3((Rng.hash01(303, i) - 0.5) * 0.2, 0.55 + Rng.hash01(304, i) * 0.35, (Rng.hash01(305, i) - 0.5) * 0.2)
				k.strut(base, tip, 0.025, 3, Palette.SAND[3] if i % 3 else Palette.MOSS[3])
		PropKind.BOULDER:
			k.rock(0, -0.05, 0, 0.5, 0.7, 401, Palette.SLATE[3], 7)
		PropKind.STONE_ORE:
			k.rock(0, -0.05, 0, 0.45, 0.65, 501, Palette.STONE[3], 6)
			k.rock(0.18, 0.2, 0.12, 0.14, 0.2, 502, Palette.LINEN[4], 5)
		PropKind.IRON_ORE:
			k.rock(0, -0.05, 0, 0.45, 0.6, 601, Palette.SLATE[2], 6)
			k.rock(0.15, 0.25, 0.12, 0.13, 0.18, 602, Palette.RUST[3], 5)
			k.rock(-0.18, 0.15, -0.05, 0.1, 0.16, 603, Palette.RUST[4], 5)
		PropKind.COPPER_ORE:
			k.rock(0, -0.05, 0, 0.45, 0.6, 701, Palette.SLATE[2], 6)
			k.rock(0.15, 0.25, 0.12, 0.13, 0.18, 702, Palette.SPRUCE[4], 5)
		PropKind.PYLON:
			var v := Palette.PLATE[3]
			for c: Vector2 in [Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(0.35, 0.35), Vector2(-0.35, 0.35)]:
				k.strut(Vector3(c.x, 0, c.y), Vector3(c.x * 0.3, 3.6, c.y * 0.3), 0.035, 4, v)
			k.block(0, 3.3, 0, 1.6, 0.08, 0.08, v)
			k.block(0, 2.6, 0, 1.2, 0.08, 0.08, v)
		PropKind.RUIN:
			k.block(0, 0, 0, 1.0, 0.6, 0.3, Palette.STONE[2], Palette.STONE[3])
			k.block(0.35, 0.6, 0, 0.3, 0.35, 0.3, Palette.STONE[2], Palette.STONE[3])
		PropKind.HOUSE:
			_house(k)
		PropKind.LAMP:
			k.prism(0, 0, 0, 0.05, 1.6, 0.04, 4, Palette.EARTH[1])
			k.block(0, 1.6, 0, 0.18, 0.2, 0.18, Palette.COPPER[3], Palette.COPPER[4])
		PropKind.BONES:
			k.strut(Vector3(-0.2, 0.03, 0), Vector3(0.25, 0.05, 0.1), 0.04, 4, Palette.LINEN[4])
			k.rock(0.28, 0, 0.12, 0.09, 0.12, 901, Palette.LINEN[5], 5)
	return k.build()


## A lime-washed rubble house under a roof re-laid in weathered machine plate,
## with the struck-through enamel plate on its front wall. Footprint ~3x2.4,
## door on +Z (the house is rotated to face its square).
static func _house(k: MeshKit) -> void:
	var wall := Palette.LINEN[4]
	var wall_dark := Palette.LINEN[3]
	var w := 2.8
	var d := 2.2
	var h := 1.5
	# Turf banked at the foot, walls, a slightly uneven lean given by two blocks.
	k.block(0, 0, 0, w + 0.14, 0.12, d + 0.14, Palette.MOSS[2])
	k.block(0, 0.1, 0, w, h - 0.1, d, wall, wall_dark)
	# Hipped roof: two sloped quads and two end triangles, in plate.
	var ridge := h + 1.05
	var e := 0.18 # eave overhang
	var x0 := -w * 0.5 - e
	var x1 := w * 0.5 + e
	var z0 := -d * 0.5 - e
	var z1 := d * 0.5 + e
	var rx := w * 0.22
	var plate := Palette.PLATE[2]
	var plate_light := Palette.PLATE[3]
	k.quad(Vector3(x0, h, z1), Vector3(x1, h, z1), Vector3(rx, ridge, 0), Vector3(-rx, ridge, 0), plate_light)
	k.quad(Vector3(x1, h, z0), Vector3(x0, h, z0), Vector3(-rx, ridge, 0), Vector3(rx, ridge, 0), plate)
	k.tri(Vector3(x1, h, z1), Vector3(x1, h, z0), Vector3(rx, ridge, 0), plate.lerp(plate_light, 0.5))
	k.tri(Vector3(x0, h, z0), Vector3(x0, h, z1), Vector3(-rx, ridge, 0), plate.lerp(plate_light, 0.3))
	# Eave underside so the overhang reads dark from below.
	k.quad(Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), Palette.INK[2])
	# One patch of old slate left where it held.
	k.quad(Vector3(-0.9, h + 0.28, z1 - 0.28), Vector3(-0.2, h + 0.28, z1 - 0.28), Vector3(-0.2, h + 0.62, z1 - 0.58), Vector3(-0.9, h + 0.62, z1 - 0.58), Palette.SLATE[2])
	# Door and window on the front (+Z).
	var fz := d * 0.5 + 0.01
	k.quad(Vector3(0.35, 0.1, fz), Vector3(0.85, 0.1, fz), Vector3(0.85, 1.05, fz), Vector3(0.35, 1.05, fz), Palette.EARTH[1])
	k.quad(Vector3(-1.0, 0.65, fz), Vector3(-0.55, 0.65, fz), Vector3(-0.55, 1.05, fz), Vector3(-0.99, 1.05, fz), Palette.COPPER[1])
	k.quad(Vector3(-0.95, 0.69, fz + 0.005), Vector3(-0.6, 0.69, fz + 0.005), Vector3(-0.6, 1.01, fz + 0.005), Vector3(-0.95, 1.01, fz + 0.005), Palette.BRINE[2])
	# The struck-through plate: a third along, a little under half height, clear of the door.
	var pz := fz + 0.01
	k.quad(Vector3(-0.3, 0.55, pz), Vector3(0.05, 0.55, pz), Vector3(0.05, 0.78, pz), Vector3(-0.3, 0.78, pz), Palette.RIME[5])
	k.quad(Vector3(-0.34, 0.6, pz + 0.004), Vector3(0.09, 0.7, pz + 0.004), Vector3(0.09, 0.73, pz + 0.004), Vector3(-0.34, 0.63, pz + 0.004), Palette.INK[0])
	# Stone chimney at one end, off-centre.
	k.block(-1.0, h, -0.4, 0.34, 1.25, 0.34, Palette.STONE[2], Palette.STONE[1])


static func gallery() -> Array:
	var out: Array = []
	for kind in PropKind.COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh(kind)
		out.append({"name": PropKind.NAMES[kind], "node": mi})
	return out
