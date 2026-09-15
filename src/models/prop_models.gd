class_name PropModels
## Models for every PropKind, in 1-4 variants, dressed per country (snow on the
## pines of the Snowfield, basalt boulders in the Burning). Built once per
## (kind, variant, country) and shared by every instance; WorldView bakes the
## instances of a chunk into one mesh from these templates.
##
## Contract (others may rely on these):
##   PropModels.mesh(kind) -> ArrayMesh          variant 0, coast dressing
##   PropModels.variant_mesh(kind, v, country)   any variant
##   PropModels.variants(kind) -> int
##   PropModels.template(kind, v, country)       raw arrays for baking
##   PropModels.gallery()                         every kind (and variant) for review
##
## Authoring: builders in src/models/props/ use MeshKit with palette colours.
## A colour's ALPHA is a code, turned into the world shader's vertex kind here:
##   1.0          plain
##   sway(c, w)   moves in the wind, w 0 base .. 1 tip
##   glow(c, s)   emissive ember or flame, strength s
##   lamp(c, s)   emissive only at night
##   flame(c)     emissive and flickering in place
##   glint(c)     sparkles now and then
##
## MADE things (anything a person built or grew) are uneven and asymmetric, in
## the coast ramps. FOUND things (pylons, poles, wreck plate) are exact and
## symmetric, in the machine plate ramp.

const PropTrees := preload("res://src/models/props/trees.gd")
const PropRocks := preload("res://src/models/props/rocks.gd")
const PropShore := preload("res://src/models/props/shore.gd")
const PropBuilt := preload("res://src/models/props/built.gd")

## Instance brightness tones (dark, base, light), chosen per prop by hash.
const TONES: PackedFloat32Array = [0.95, 1.0, 1.05]


## Raw, baked-ready arrays of one model.
class Template:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	## One colour array per TONES entry.
	var tones: Array[PackedColorArray] = []


static var _templates: Dictionary = {}
static var _meshes: Dictionary = {}


static func variants(kind: int) -> int:
	match kind:
		PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.DRIFTWOOD, PropKind.BONES, PropKind.RUIN, PropKind.STANDING_STONE:
			return 3
		PropKind.BOULDER, PropKind.HOUSE:
			return 4
		PropKind.SNOW_PINE, PropKind.REEDS, PropKind.GORSE, PropKind.CLINTS, PropKind.CAIRN, PropKind.MUSSEL_ROCK, PropKind.PEAT_BANK, \
		PropKind.WRACK, PropKind.VENT, PropKind.TIP, PropKind.WRECK, PropKind.KILN, PropKind.STONE_ORE, PropKind.IRON_ORE, \
		PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE:
			return 2
	return 1


## A variant for an instance from its hash (any non-negative int).
static func pick_variant(kind: int, h: int) -> int:
	return absi(h) % variants(kind)


static func sway(col: Color, w: float) -> Color:
	return Color(col.r, col.g, col.b, 0.8 * (1.0 - clampf(w, 0.0, 1.0)))


static func glow(col: Color, strength: float) -> Color:
	return Color(col.r, col.g, col.b, 0.85 + clampf(strength, 0.0, 1.95) * 0.05)


static func lamp(col: Color, strength: float) -> Color:
	return Color(col.r, col.g, col.b, 0.95 + clampf(strength, 0.0, 1.95) * 0.02)


static func flame(col: Color) -> Color:
	return Color(col.r, col.g, col.b, 0.835)


static func glint(col: Color) -> Color:
	return Color(col.r, col.g, col.b, 0.81)


## Vertex kind (UV) for an authored alpha code.
static func code_uv(a: float) -> Vector2:
	if a >= 0.995:
		return Vector2.ZERO
	if a >= 0.95:
		return Vector2(10.0 + (a - 0.95) * 50.0, TerrainMesher.KIND_GLOW)
	if a >= 0.85:
		return Vector2((a - 0.85) * 20.0, TerrainMesher.KIND_GLOW)
	if a > 0.82:
		return Vector2(6.5, TerrainMesher.KIND_GLOW)
	if a > 0.8:
		return Vector2(0.0, TerrainMesher.KIND_GLINT)
	return Vector2(1.0 - a / 0.8, TerrainMesher.KIND_SWAY)


## MeshKit arrays -> Template, decoding alpha codes.
static func extract(k: MeshKit) -> Template:
	var t := Template.new()
	t.v = k.verts.duplicate()
	t.n = k.normals.duplicate()
	t.uv.resize(k.colors.size())
	var base := PackedColorArray()
	base.resize(k.colors.size())
	for i in k.colors.size():
		var col := k.colors[i]
		t.uv[i] = code_uv(col.a)
		base[i] = Color(col.r, col.g, col.b, 1.0)
	for tone in TONES:
		if tone == 1.0:
			t.tones.append(base)
			continue
		var arr := PackedColorArray()
		arr.resize(base.size())
		for i in base.size():
			var c := base[i]
			arr[i] = Color(minf(1.0, c.r * tone), minf(1.0, c.g * tone), minf(1.0, c.b * tone), 1.0)
		t.tones.append(arr)
	return t


static func template(kind: int, variant: int = 0, country: int = Country.COAST) -> Template:
	var key := (kind * 8 + variant) * 8 + country
	if not _templates.has(key):
		_templates[key] = extract(build_kit(kind, variant, country))
	return _templates[key]


static func build_kit(kind: int, variant: int, country: int) -> MeshKit:
	var k := MeshKit.new()
	variant = clampi(variant, 0, variants(kind) - 1)
	match kind:
		PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.GORSE, PropKind.REEDS:
			PropTrees.build(k, kind, variant, country)
		PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE, \
		PropKind.STANDING_STONE, PropKind.CLINTS, PropKind.CAIRN, PropKind.MUSSEL_ROCK, PropKind.PEAT_BANK:
			PropRocks.build(k, kind, variant, country)
		PropKind.DRIFTWOOD, PropKind.WRACK, PropKind.BONES, PropKind.WRECK, PropKind.TIP, PropKind.VENT:
			PropShore.build(k, kind, variant, country)
		PropKind.HOUSE, PropKind.RUIN, PropKind.LAMP, PropKind.FIRE, PropKind.BENCH, PropKind.KILN, PropKind.PYLON, PropKind.POLE:
			PropBuilt.build(k, kind, variant, country)
	if k.vertex_count() == 0:
		# Loud on purpose: an unmodelled kind must be seen and fixed.
		k.rock(0, 0, 0, 0.35, 0.5, kind * 31 + 7, Palette.BLOOM[3], 5)
	return k


static func to_mesh(t: Template, tone: int = 1) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = t.v
	arrays[Mesh.ARRAY_NORMAL] = t.n
	arrays[Mesh.ARRAY_COLOR] = t.tones[tone]
	arrays[Mesh.ARRAY_TEX_UV] = t.uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func mesh(kind: int) -> ArrayMesh:
	return variant_mesh(kind, 0, Country.COAST)


static func variant_mesh(kind: int, variant: int, country: int) -> ArrayMesh:
	var key := (kind * 8 + variant) * 8 + country
	if not _meshes.has(key):
		_meshes[key] = to_mesh(template(kind, variant, country))
	return _meshes[key]


## Every kind in every variant; `--filter=` in the gallery narrows it.
## Country-dressed variants appear as "<kind> <country>" for the kinds that change.
static func gallery() -> Array:
	var out: Array = []
	for kind in PropKind.COUNT:
		for v in variants(kind):
			var mi := MeshInstance3D.new()
			mi.mesh = variant_mesh(kind, v, Country.COAST)
			var label := PropKind.NAMES[kind] + ("" if variants(kind) == 1 else " %d" % v)
			out.append({"name": label, "node": mi})
	for kind: int in [PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.BOULDER, PropKind.REEDS, PropKind.HOUSE, PropKind.STANDING_STONE]:
		for c: int in [Country.MOSS, Country.PINEWOOD, Country.SNOWFIELD, Country.BONELANDS, Country.BURNING]:
			var mi := MeshInstance3D.new()
			mi.mesh = variant_mesh(kind, 0, c)
			out.append({"name": "%s %s" % [PropKind.NAMES[kind], Country.NAMES[c]], "node": mi})
	return out
