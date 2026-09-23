class_name PropModels
## Models for every PropKind, in 1-4 variants, dressed for the landscape they
## stand in (snow on a pine where snow lies, basalt boulders where the rock is
## basalt). What a landscape's things are made of is `BiomeDressing`, read off
## the registry: nothing here knows a landscape by name. Each model is two
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
const Site := preload("res://src/models/props/black_site.gd")
const Salt := preload("res://src/models/props/salt.gd")
const Scrap := preload("res://src/models/props/scrap.gd")
const Signage := preload("res://src/models/props/signage.gd")
const Metropolis := preload("res://src/models/props/metropolis.gd")


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
	## LEAVES (props/kit.gd `canopy`): cards drawn by leaf.gdshader, double-sided
	## and cut to a sprig. UV is the card's own coordinates, not a hand.
	var leaf_v := PackedVector3Array()
	var leaf_n := PackedVector3Array()
	var leaf_c := PackedColorArray()
	var leaf_uv := PackedVector2Array()
	var leaf_uv2 := PackedVector2Array()


static var _templates: Dictionary = {}
static var _meshes: Dictionary = {}
static var _found_mat: ShaderMaterial
static var _leaf_mat: ShaderMaterial


## How many models of `kind` there are IN THIS LANDSCAPE. Only a building's
## answer moves: its forms are the landscape's own stock (`BiomeForms`), so a
## city deals six towers where a coast deals eight crofts, and neither costs the
## other a slot — the cache key already carries the country
## (`(kind * MAX_VARIANTS + variant) * SLOTS + country`), so variants have always
## been per-landscape in the CACHE and only the COUNT was global.
##
## The default is the coast because every caller outside a running world means
## "the plain answer": the gallery's first pass, a test, a mesh asked for on its
## own. A caller that has a world passes the country, or it deals a model this
## landscape does not build.
static func variants(kind: int, country: int = Country.COAST) -> int:
	match kind:
		PropKind.HOUSE:
			return BiomeForms.of(country).stock.size()
		PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.BOULDER:
			return 4
		PropKind.SNOW_PINE, PropKind.DRIFTWOOD, PropKind.BONES, PropKind.RUIN, PropKind.STANDING_STONE, PropKind.REEDS, \
		PropKind.GORSE, PropKind.CLINTS, PropKind.CAIRN, PropKind.MUSSEL_ROCK, PropKind.PEAT_BANK, PropKind.WRACK:
			return 3
		# Four: the Burning puts nine vents in one frame, and two shapes there is a
		# stamp (art finding 16). Even variants are a hole burnt in the ground,
		# odd ones a bolted pipe, and each pair differs in size and stance.
		PropKind.VENT:
			return 4
		PropKind.TIP, PropKind.WRECK, PropKind.KILN, PropKind.STONE_ORE, PropKind.IRON_ORE, \
		PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE:
			return 2
		PropKind.SIGN:
			return 4
		PropKind.SALT_RIDGE:
			return 3
		# Six, because four was still a stamp at play zoom: thirty crowns in one
		# frame want six heights, six spreads, six arm counts and six of the
		# machine's bars, and `Scrap.SPREAD`/`BOUGHS` are sized for six.
		PropKind.SCRAP_TREE:
			return 6
		PropKind.SALT_HEAP, PropKind.PAN_GATE, PropKind.MAGNET_HEAP:
			return 2
		# Four: a street holds several at once and two shapes would be a stamp.
		# They differ in what is PAINTED and in whether a hoarding was bolted over
		# it -- 0 and 1 are bare paint, 2 and 3 carry a sign.
		PropKind.MURAL:
			return 4
		PropKind.FENCE, PropKind.GRAVE, PropKind.DEBRIS, PropKind.STUMP, PropKind.WRECKAGE:
			return 3
		# The metropolis: a span with its lamp standing or snapped, a lift core
		# with its cable in or out, a shop with its shutter a third, two thirds or
		# all the way down, and a bale of each of the three things the plan sorts
		# the city into (rebar, copper, cullet).
		PropKind.DECK_SPAN, PropKind.LIFT_SHAFT:
			return 2
		PropKind.SHOPFRONT, PropKind.SORTED_BALE:
			return 3
		PropKind.BARRICADE, PropKind.SHACK, PropKind.VEHICLE, PropKind.HULL, PropKind.SEA_WALL, PropKind.TIDE_GAUGE, \
		PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.PIPE, PropKind.FIRE_TOWER, PropKind.CHECKPOINT, PropKind.DRILL_RIG, \
		PropKind.CONVEYOR, PropKind.SURVEY, PropKind.WATER_TANK, PropKind.SLAG_HEAP, PropKind.VENT_CAP, PropKind.ARCHIVE, \
		PropKind.MEMORIAL:
			return 2
	return 1


## A variant for an instance from its hash (any int).
static func pick_variant(kind: int, h: int, country: int = Country.COAST) -> int:
	return absi(h) % variants(kind, country)


## The model one placed prop is drawn as: what world gen dealt it (`WorldProp.variant`,
## which a village uses so no two of its houses repeat a silhouette), or, where
## nothing was dealt, the one its kind and position hash to (`WorldProp.deal_hash`,
## never its id: see there). Every reader — the chunk bake, the lights — asks
## here, so a dealt variant reaches all of them.
static func variant_of(p: WorldProp, seed_value: int, country: int = Country.COAST) -> int:
	if p.variant >= 0:
		return clampi(p.variant, 0, variants(p.kind, country) - 1)
	return pick_variant(p.kind, WorldProp.deal_hash(seed_value, p.kind, p.pos), country)


## Chunk workers bake props while the main thread may too.
static var _lock := Mutex.new()


## Variants one kind may have. It is the cache key's packing, nothing else: at 8
## a ninth model of a kind collided with the next kind's variant 0 and silently
## drew the wrong prop. `tests/models` fails if a kind ever declares more.
const MAX_VARIANTS := 16


## `worked` is how far the taking has got through it (Broken.BUCKETS steps, the
## last whole): a thing being quarried is a template of its own at each step, so a
## rock worked twice is built twice and cached, not cut every frame it is drawn.
static func template(kind: int, variant: int = 0, country: int = Country.COAST, worked: int = WHOLE) -> Template:
	var key := _key(kind, variant, country, worked)
	_lock.lock()
	var t: Template = _templates.get(key)
	if t == null:
		t = _extract(build_kit(kind, variant, country, worked))
		_templates[key] = t
	_lock.unlock()
	return t


## A thing nothing has been taken from.
const WHOLE := Broken.BUCKETS - 1


static func _key(kind: int, variant: int, country: int, worked: int) -> int:
	return ((kind * MAX_VARIANTS + variant) * BiomeRegistry.SLOTS + country) * Broken.BUCKETS + clampi(worked, 0, WHOLE)


static func build_kit(kind: int, variant: int, country: int, worked: int = WHOLE) -> Kit:
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
		PropKind.HULL, PropKind.SEA_WALL, PropKind.STUMP, PropKind.FIRE_TOWER, PropKind.WATER_TANK, PropKind.SLAG_HEAP, \
		PropKind.WRECKAGE, PropKind.MEMORIAL:
			Remains.build(k, kind, variant, country)
		PropKind.SIGN, PropKind.TIDE_GAUGE, PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.PIPE, PropKind.RELAY, \
		PropKind.CHECKPOINT, PropKind.STACK, PropKind.DRILL_RIG, PropKind.CONVEYOR, PropKind.SURVEY, PropKind.VENT_CAP, PropKind.ARCHIVE:
			Works.build(k, kind, variant, country)
		PropKind.SALT_RIDGE, PropKind.SALT_HEAP, PropKind.PAN_GATE:
			Salt.build(k, kind, variant, country)
		PropKind.SCRAP_TREE, PropKind.MAGNET_HEAP:
			Scrap.build(k, kind, variant, country)
		PropKind.MURAL:
			Signage.build(k, kind, variant, country)
		PropKind.PLATFORM, PropKind.GROWTH_TANK, PropKind.CONSOLE:
			Site.build(k, kind, variant, country)
		PropKind.DECK_SPAN, PropKind.LIFT_SHAFT, PropKind.SHOPFRONT, PropKind.SORTED_BALE, PropKind.DEMOLITION_GANTRY:
			Metropolis.build(k, kind, variant, country)
	if k.made.vertex_count() == 0 and k.found.vertex_count() == 0 and k.leaf.vertex_count() == 0:
		# Loud on purpose: an unmodelled kind must be seen and fixed.
		k.made.rock(0, 0, 0, 0.35, 0.5, kind * 31 + 7, Palette.BLOOM[3], 5)
	if worked < WHOLE:
		# Worked down, not shrunk: the same thing with a piece off it.
		var share := Broken.share_of(worked)
		Broken.work_down(k.made, share, kind * 131 + variant)
		Broken.work_down(k.found, share, kind * 131 + variant + 7)
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
	t.leaf_v = k.leaf.verts
	t.leaf_n = k.leaf.normals
	t.leaf_c = k.leaf.colors
	t.leaf_uv = k.leaf.uvs
	t.leaf_uv2 = k.leaf.uv2s
	return t


static func found_material() -> ShaderMaterial:
	if _found_mat == null:
		_found_mat = ShaderMaterial.new()
		_found_mat.shader = preload("res://src/render/found.gdshader")
	return _found_mat


## The material every leaf card is drawn with, outside a running world: the
## gallery, a node on its own, a tree falling. A running world hands its chunks
## WorldView's own copy, because 18_crowns writes the clearings into that one.
static func leaf_material() -> ShaderMaterial:
	if _leaf_mat == null:
		_leaf_mat = ShaderMaterial.new()
		_leaf_mat.shader = preload("res://src/render/foliage/leaf.gdshader")
	return _leaf_mat


## A model's leaf cards as one surface's arrays, or [] when it has none.
static func leaf_arrays(t: Template) -> Array:
	if t.leaf_v.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = t.leaf_v
	arrays[Mesh.ARRAY_NORMAL] = t.leaf_n
	arrays[Mesh.ARRAY_COLOR] = t.leaf_c
	arrays[Mesh.ARRAY_TEX_UV] = t.leaf_uv
	arrays[Mesh.ARRAY_TEX_UV2] = t.leaf_uv2
	return arrays


## A model's leaves as a node carrying leaf.gdshader, or null when it has none.
## For whatever shows one prop outside the chunk bake and gives the rest of it a
## material_override, which a card must never take: world.gdshader would draw a
## sprig as the square it is cut from.
static func leaf_node(kind: int, variant: int = 0, country: int = Country.COAST) -> MeshInstance3D:
	var arrays := leaf_arrays(template(kind, variant, country))
	if arrays.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "leaf"
	mi.mesh = mesh
	mi.material_override = leaf_material()
	return mi


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
static func glow_points(kind: int, variant: int = 0, country: int = Country.COAST) -> Array:
	# One source for the machines' own light: the geometry and the pool it casts
	# must not disagree about what colour a strip or a beacon is.
	var cold := Color(Works.STRIP, 1.0)
	var beacon := Color(Works.BEACON, 1.0)
	match kind:
		PropKind.PAN_GATE:
			# The one strip on a sluice gate that still reads (props/salt.gd).
			if variant != 0:
				return []
			return [{"at": Vector3(-0.375, 0.62, 0.056), "size": Vector2.ZERO, "color": cold}]
		PropKind.SHACK:
			# Only the shacks that wired stolen tech in (props/remains.gd _wired):
			# the middle of the neon tube, in that shelter's colour. Keyed on the
			# FORM and not on a landscape: a stilt hut's wall is where it is over
			# whichever fen the hut stands.
			if variant % 2 == 0:
				return []
			var n := Remains.NEON
			match BiomeDressing.of(country).shelter:
				&"stilt": return [{"at": Vector3(0.62, 1.27, -0.285), "size": Vector2.ZERO, "color": n[2], "neon": true}]
				&"blind": return [{"at": Vector3(0.64, 1.75, 0.4), "size": Vector2.ZERO, "color": n[0], "neon": true}]
				&"pod": return [{"at": Vector3(1.14, 0.45, 0.585), "size": Vector2.ZERO, "color": n[1], "neon": true}]
				&"lean_to": return [{"at": Vector3(0.92, 0.7, 0.375), "size": Vector2.ZERO, "color": n[2], "neon": true}]
				&"dugout": return [{"at": Vector3(0.82, 0.5, 0.475), "size": Vector2.ZERO, "color": n[1], "neon": true}]
			return [{"at": Vector3(0.81, 0.85, -0.5), "size": Vector2.ZERO, "color": n[0], "neon": true}]
		PropKind.INTAKE:
			# The cold strip along both eaves (props/works.gd intake).
			return [{"at": Vector3(-0.6, 1.03, 0.97), "size": Vector2.ZERO, "color": cold}, {"at": Vector3(-0.6, 1.03, -0.97), "size": Vector2.ZERO, "color": cold}]
		PropKind.PUMP_HOUSE:
			if variant % 2 == 1:
				return []
			return [{"at": Vector3(0.0, 0.96, 0.77), "size": Vector2.ZERO, "color": cold}, {"at": Vector3(0.0, 0.96, -0.77), "size": Vector2.ZERO, "color": cold}]
		PropKind.CHECKPOINT:
			# The flood over the gate burns even when the gate is broken.
			return [{"at": Vector3(-0.2, 2.9, 0.74), "size": Vector2.ZERO, "color": cold}]
		PropKind.FIRE_TOWER:
			# A lookout's lamp left on the sill, on the towers still standing.
			if variant % 2 == 1:
				return []
			return [{"at": Vector3(0.35, 4.69, 0.2), "size": Vector2.ZERO, "color": Palette.COPPER[4]}]
		PropKind.RELAY:
			# The beacon on the mast's top, on the machines' beat.
			return [{"at": Vector3(0.0, 3.76, 0.0), "size": Vector2.ZERO, "color": beacon, "blink": true}]
		PropKind.HOUSE:
			# The door side is +X on every house variant (props/houses.gd).
			var house: Array = [{"at": Vector3(1.15, 0.7, 0.0), "size": Vector2.ZERO, "color": Palette.COPPER[4]}]
			var tube := neon_point(kind, variant, country)
			if not tube.is_empty():
				house.append(tube)
			return house
		PropKind.LAMP:
			# The lantern hangs off its arm at x 0.4 (props/built.gd lamp_post).
			return [{"at": Vector3(0.4, 1.41, 0.02), "size": Vector2.ZERO, "color": Palette.COPPER[4], "rays": [3.0, 6.0, 0.0, 8.0]}]
		PropKind.PYLON:
			# The cap on the mast is the same beacon a relay carries: it was rust
			# here, dull violet in the geometry and crimson in the light it cast.
			return [{"at": Vector3(0, 4.05, 0), "size": Vector2(0.12, 0.12), "color": beacon, "box": true, "rays": [2.0, 4.0, 0.0, 4.0]}]
		PropKind.FIRE:
			return [{"at": Vector3(0, 0.35, 0), "size": Vector2.ZERO, "color": Palette.EMBER[4], "rays": [3.0, 7.0, 1.0, 8.0]}]
		PropKind.MURAL:
			# READ OFF THE GEOMETRY, never typed. The hoarding's face is a NEON
			# mark, so `neon_point` gives its middle and its own colour, and the
			# light cannot end up standing where the sign is not. A bare mural
			# has no NEON in it at all, so this returns nothing and
			# `15_lights.PLACED_SOURCES` drops it: paint emits nothing and a
			# projection lights the street, said once, by the models themselves.
			var sign := neon_point(kind, variant, country)
			return [] if sign.is_empty() else [sign]
	return []


## Where a model runs stolen neon, in its own frame, READ OFF THE GEOMETRY it
## drew: the middle of its NEON-marked vertices, in their own colour, or {} when
## this model wired nothing in.
##
## Written down twice, it goes wrong: the tube moved from a house's door wall to
## its roof edge and the light it threw stayed on the wall, in the colour the
## other lit house used (art review 11). A light and the thing casting it come
## from one place or they disagree.
static var _neon: Dictionary = {}


static func neon_point(kind: int, variant: int, country: int) -> Dictionary:
	# Cached: the lights ask this for every house in the world, and reading a
	# model's marks means walking a few thousand vertices.
	var key := _key(kind, variant, country, WHOLE)
	_lock.lock()
	var hit: Variant = _neon.get(key)
	_lock.unlock()
	if hit != null:
		return hit
	var t := template(kind, variant, country)
	var at := Vector3.ZERO
	var rgb := Vector3.ZERO
	var n := 0
	for i in t.made_v.size():
		if roundi(t.made_c[i].a * 255.0) != GroundColors.NEON:
			continue
		at += t.made_v[i]
		rgb += Vector3(t.made_c[i].r, t.made_c[i].g, t.made_c[i].b)
		n += 1
	var out: Dictionary = {}
	if n > 0:
		out = {"at": at / float(n), "size": Vector2.ZERO, "color": Color(rgb.x / n, rgb.y / n, rgb.z / n), "neon": true}
	_lock.lock()
	_neon[key] = out
	_lock.unlock()
	return out


## Index of the FOUND surface in mesh(kind), or -1 when the kind has none.
static func found_surface(kind: int) -> int:
	var t := template(kind, 0, Country.COAST)
	if t.found_v.is_empty():
		return -1
	return 0 if t.made_v.is_empty() else 1


## Every part of a model as nodes: the MADE part takes whatever material its
## parent gives (the gallery and WorldView give world.gdshader), the FOUND part
## carries found.gdshader, and the leaves (when it has any) leaf.gdshader.
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
	var leaves := leaf_node(kind, variant, country)
	if leaves != null:
		root.add_child(leaves)
	return root


## Every kind in every variant in the coast's dressing, then the dressings of
## every OTHER landscape in the registry for the kinds that change;
## `--filter=` in the gallery narrows it.
static func gallery() -> Array:
	var out: Array = []
	for kind in PropKind.COUNT:
		for v in variants(kind):
			var label := PropKind.NAMES[kind] + ("" if variants(kind) == 1 else " %d" % v)
			out.append({"name": label, "node": node(kind, v, Country.COAST)})
	var lands := dressings()
	for kind: int in [PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.BOULDER, PropKind.REEDS, PropKind.HOUSE, PropKind.GORSE, PropKind.RUIN, PropKind.WRECK, PropKind.CAIRN]:
		for c: int in lands:
			out.append({"name": "%s %s" % [PropKind.NAMES[kind], BiomeRegistry.names()[c]], "node": node(kind, 0, c)})
	# The but in snow: its sods carry the snow, not a lid of it.
	out.append({"name": "%s 3 snowfield" % PropKind.NAMES[PropKind.HOUSE], "node": node(PropKind.HOUSE, 3, Country.SNOWFIELD)})
	# Every form of a landscape that builds something other than the plain stock
	# (`BiomeForms`). The rows above show the plain eight once; a landscape whose
	# people build upward shows its own, or the gallery is evidence about a stock
	# nobody in that world raises.
	for d: BiomeDef in BiomeRegistry.land():
		var stock := BiomeForms.of(d.index).stock
		if stock == BiomeForms.PLAIN:
			continue
		for v in stock.size():
			out.append({"name": "%s %s %s" % [PropKind.NAMES[PropKind.HOUSE], stock[v], d.id], "node": node(PropKind.HOUSE, v, d.index)})
	# The evidence each landscape dresses its own way.
	for kind: int in DRESSED:
		for c: int in lands:
			for v in variants(kind):
				out.append({"name": "%s %d %s" % [PropKind.NAMES[kind], v, BiomeRegistry.names()[c]], "node": node(kind, v, c)})
	return out


## Every land type but the coast, whose dressing the plain rows above already
## show. A landscape added tomorrow shows up here without a line being added.
static func dressings() -> Array[int]:
	var out: Array[int] = []
	for d: BiomeDef in BiomeRegistry.land():
		if d.index != Country.COAST:
			out.append(d.index)
	return out


## Kinds of evidence whose model changes with the landscape it stands in.
const DRESSED: Array[int] = [PropKind.FENCE, PropKind.GRAVE, PropKind.SHACK, PropKind.VEHICLE, PropKind.SIGN, PropKind.CHECKPOINT, PropKind.PIPE, PropKind.WRECKAGE, PropKind.MEMORIAL]
