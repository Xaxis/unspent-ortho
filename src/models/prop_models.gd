class_name PropModels
## Models for every PropKind, in 1-4 variants, dressed per country (snow on the
## pines of the Snowfield, basalt boulders in the Burning). Each model is two
## parts: MADE geometry for world.gdshader (land, plants, anything a person
## built) and FOUND geometry for found.gdshader (pylons, poles, plate taken off
## machines, cast stone). Built once per (kind, variant, country); WorldView
## bakes the instances of a chunk into one MADE and one FOUND mesh.
##
## Contract (others may rely on these):
##   PropModels.mesh(kind) -> ArrayMesh     variant 0, coast dressing: the MADE
##                                          surface first when the kind has one,
##                                          then the FOUND surface (if any) with
##                                          found.gdshader set on it
##   PropModels.found_surface(kind) -> int  that FOUND surface's index, or -1
##                                          (0 for FOUND-only kinds: pylon, pole)
##   PropModels.node(kind, v, country)      a Node3D with both parts and materials
##   PropModels.template(kind, v, country)  raw arrays for baking
##   PropModels.variants(kind) -> int, pick_variant(kind, hash) -> int
##   PropModels.gallery()                   every kind and variant for review
##
## Builders live in src/models/props/ and draw with a PropKit (props/kit.gd).

const Kit := preload("res://src/models/props/kit.gd")
const Trees := preload("res://src/models/props/trees.gd")
const Rocks := preload("res://src/models/props/rocks.gd")
const Shore := preload("res://src/models/props/shore.gd")
const Built := preload("res://src/models/props/built.gd")
const Houses := preload("res://src/models/props/houses.gd")
const Remains := preload("res://src/models/props/remains.gd")
const Works := preload("res://src/models/props/works.gd")


## Raw, bake-ready arrays of one model.
class Template:
	var made_v := PackedVector3Array()
	var made_n := PackedVector3Array()
	var made_c := PackedColorArray()
	var made_uv := PackedVector2Array()
	var made_uv2 := PackedVector2Array()
	var found_v := PackedVector3Array()
	var found_n := PackedVector3Array()
	var found_c := PackedColorArray()


static var _templates: Dictionary = {}
static var _meshes: Dictionary = {}
static var _found_mat: ShaderMaterial


static func variants(kind: int) -> int:
	match kind:
		PropKind.HOUSE:
			return Houses.VARIANTS
		PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.BOULDER:
			return 4
		PropKind.SNOW_PINE, PropKind.DRIFTWOOD, PropKind.BONES, PropKind.RUIN, PropKind.STANDING_STONE, PropKind.REEDS, \
		PropKind.GORSE, PropKind.CLINTS, PropKind.CAIRN, PropKind.MUSSEL_ROCK, PropKind.PEAT_BANK, PropKind.WRACK:
			return 3
		PropKind.VENT, PropKind.TIP, PropKind.WRECK, PropKind.KILN, PropKind.STONE_ORE, PropKind.IRON_ORE, \
		PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE:
			return 2
		PropKind.FENCE, PropKind.SIGN, PropKind.GRAVE, PropKind.DEBRIS, PropKind.STUMP:
			return 3
		PropKind.BARRICADE, PropKind.SHACK, PropKind.VEHICLE, PropKind.HULL, PropKind.SEA_WALL, PropKind.TIDE_GAUGE, \
		PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.PIPE, PropKind.FIRE_TOWER, PropKind.CHECKPOINT, PropKind.DRILL_RIG, \
		PropKind.CONVEYOR, PropKind.SURVEY, PropKind.WATER_TANK, PropKind.SLAG_HEAP, PropKind.VENT_CAP, PropKind.ARCHIVE:
			return 2
	return 1


## A variant for an instance from its hash (any int).
static func pick_variant(kind: int, h: int) -> int:
	return absi(h) % variants(kind)


## Chunk workers bake props while the main thread may too.
static var _lock := Mutex.new()


static func template(kind: int, variant: int = 0, country: int = Country.COAST) -> Template:
	var key := (kind * 8 + variant) * 8 + country
	_lock.lock()
	var t: Template = _templates.get(key)
	if t == null:
		t = _extract(build_kit(kind, variant, country))
		_templates[key] = t
	_lock.unlock()
	return t


static func build_kit(kind: int, variant: int, country: int) -> Kit:
	var k := Kit.new()
	variant = clampi(variant, 0, variants(kind) - 1)
	match kind:
		PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.GORSE, PropKind.REEDS:
			Trees.build(k, kind, variant, country)
		PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE, \
		PropKind.STANDING_STONE, PropKind.CLINTS, PropKind.CAIRN, PropKind.MUSSEL_ROCK, PropKind.PEAT_BANK:
			Rocks.build(k, kind, variant, country)
		PropKind.DRIFTWOOD, PropKind.WRACK, PropKind.BONES, PropKind.WRECK, PropKind.TIP, PropKind.VENT:
			Shore.build(k, kind, variant, country)
		PropKind.HOUSE, PropKind.RUIN:
			Houses.build(k, kind, variant, country)
		PropKind.LAMP, PropKind.FIRE, PropKind.BENCH, PropKind.KILN, PropKind.PYLON, PropKind.POLE:
			Built.build(k, kind, variant, country)
		PropKind.FENCE, PropKind.BARRICADE, PropKind.GRAVE, PropKind.DEBRIS, PropKind.SHACK, PropKind.VEHICLE, \
		PropKind.HULL, PropKind.SEA_WALL, PropKind.STUMP, PropKind.FIRE_TOWER, PropKind.WATER_TANK, PropKind.SLAG_HEAP:
			Remains.build(k, kind, variant, country)
		PropKind.SIGN, PropKind.TIDE_GAUGE, PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.PIPE, PropKind.RELAY, \
		PropKind.CHECKPOINT, PropKind.STACK, PropKind.DRILL_RIG, PropKind.CONVEYOR, PropKind.SURVEY, PropKind.VENT_CAP, PropKind.ARCHIVE:
			Works.build(k, kind, variant, country)
	if k.made.vertex_count() == 0 and k.found.vertex_count() == 0:
		# Loud on purpose: an unmodelled kind must be seen and fixed.
		k.made.rock(0, 0, 0, 0.35, 0.5, kind * 31 + 7, Palette.BLOOM[3], 5)
	return k


static func _extract(k: Kit) -> Template:
	var t := Template.new()
	t.made_v = k.made.verts
	t.made_n = k.made.normals
	t.made_c = k.made.colors
	t.made_uv = k.made.uvs
	t.made_uv2 = k.made.uv2s
	t.found_v = k.found.verts
	t.found_n = k.found.normals
	t.found_c = k.found.colors
	return t


static func found_material() -> ShaderMaterial:
	if _found_mat == null:
		_found_mat = ShaderMaterial.new()
		_found_mat.shader = preload("res://src/render/found.gdshader")
	return _found_mat


static func made_mesh(t: Template) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not t.made_v.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = t.made_v
		arrays[Mesh.ARRAY_NORMAL] = t.made_n
		arrays[Mesh.ARRAY_COLOR] = t.made_c
		arrays[Mesh.ARRAY_TEX_UV] = t.made_uv
		arrays[Mesh.ARRAY_TEX_UV2] = t.made_uv2
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func found_mesh(t: Template) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not t.found_v.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = t.found_v
		arrays[Mesh.ARRAY_NORMAL] = t.found_n
		arrays[Mesh.ARRAY_COLOR] = t.found_c
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func mesh(kind: int) -> ArrayMesh:
	var key := kind
	if not _meshes.has(key):
		var t := template(kind, 0, Country.COAST)
		var m := made_mesh(t)
		if not t.found_v.is_empty():
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = t.found_v
			arrays[Mesh.ARRAY_NORMAL] = t.found_n
			arrays[Mesh.ARRAY_COLOR] = t.found_c
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			m.surface_set_material(m.get_surface_count() - 1, found_material())
		_meshes[key] = m
	return _meshes[key]


## Where a model gives light, in its own frame (a model faces +X): Array of
## {at: Vector3, size: Vector2 (0 = no pane), color: Color, box: bool, door: bool,
## rays: [inner px, outer px, flicker 0..1, spokes]} (read by 15_lights).
## Windows and lamp glass are drawn lit by the models themselves (lamp-coded
## washes), so these carry no panes: only where the light stands and the
## flame strokes.
static func glow_points(kind: int) -> Array:
	match kind:
		PropKind.HOUSE:
			# The door side is +X on every house variant (props/houses.gd).
			return [{"at": Vector3(1.15, 0.7, 0.0), "size": Vector2.ZERO, "color": Palette.COPPER[4]}]
		PropKind.LAMP:
			# The lantern hangs off its arm at x 0.4 (props/built.gd lamp_post).
			return [{"at": Vector3(0.4, 1.41, 0.02), "size": Vector2.ZERO, "color": Palette.COPPER[4], "rays": [3.0, 6.0, 0.0, 8.0]}]
		PropKind.PYLON:
			return [{"at": Vector3(0, 4.05, 0), "size": Vector2(0.12, 0.12), "color": Palette.RUST[4], "box": true, "rays": [2.0, 4.0, 0.0, 4.0]}]
		PropKind.FIRE:
			return [{"at": Vector3(0, 0.35, 0), "size": Vector2.ZERO, "color": Palette.EMBER[4], "rays": [3.0, 7.0, 1.0, 8.0]}]
	return []


## Index of the FOUND surface in mesh(kind), or -1 when the kind has none.
static func found_surface(kind: int) -> int:
	var t := template(kind, 0, Country.COAST)
	if t.found_v.is_empty():
		return -1
	return 0 if t.made_v.is_empty() else 1


## Both parts of a model as nodes: the MADE part takes whatever material its
## parent gives (the gallery and WorldView give world.gdshader), the FOUND part
## carries found.gdshader.
static func node(kind: int, variant: int = 0, country: int = Country.COAST) -> Node3D:
	var t := template(kind, variant, country)
	var root := MeshInstance3D.new()
	root.mesh = made_mesh(t)
	if not t.found_v.is_empty():
		var f := MeshInstance3D.new()
		f.name = "found"
		f.mesh = found_mesh(t)
		f.material_override = found_material()
		root.add_child(f)
	return root


## Every kind in every variant, then the country dressings of the kinds that
## change; `--filter=` in the gallery narrows it.
static func gallery() -> Array:
	var out: Array = []
	for kind in PropKind.COUNT:
		for v in variants(kind):
			var label := PropKind.NAMES[kind] + ("" if variants(kind) == 1 else " %d" % v)
			out.append({"name": label, "node": node(kind, v, Country.COAST)})
	for kind: int in [PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.BOULDER, PropKind.REEDS, PropKind.HOUSE, PropKind.GORSE, PropKind.RUIN, PropKind.WRECK, PropKind.CAIRN]:
		for c: int in [Country.MOSS, Country.PINEWOOD, Country.SNOWFIELD, Country.BONELANDS, Country.BURNING]:
			out.append({"name": "%s %s" % [PropKind.NAMES[kind], Country.NAMES[c]], "node": node(kind, 0, c)})
	# The but in snow: its sods carry the snow, not a lid of it.
	out.append({"name": "%s 3 snowfield" % PropKind.NAMES[PropKind.HOUSE], "node": node(PropKind.HOUSE, 3, Country.SNOWFIELD)})
	# The evidence each landscape dresses its own way.
	for kind: int in DRESSED:
		for c: int in [Country.MOSS, Country.PINEWOOD, Country.SNOWFIELD, Country.BONELANDS, Country.BURNING]:
			for v in variants(kind):
				out.append({"name": "%s %d %s" % [PropKind.NAMES[kind], v, Country.NAMES[c]], "node": node(kind, v, c)})
	return out


## Kinds of evidence whose model changes with the landscape it stands in.
const DRESSED: Array[int] = [PropKind.FENCE, PropKind.GRAVE, PropKind.SHACK, PropKind.VEHICLE, PropKind.SIGN, PropKind.CHECKPOINT, PropKind.PIPE]
