extends TestCase
## Foliage is leaf cards, not a lobed solid (props/kit.gd `canopy`,
## src/render/foliage/leaf.gdshader). What a test can hold of that: which plants
## carry cards, that a card is a whole quad cut by the shader and never blended,
## that it carries the crown's normal and not its own, that the crown still opens
## over a fight, and that a chunk draws them all in one more call.

const Kit := preload("res://src/models/props/kit.gd")
const Trees := preload("res://src/models/props/trees.gd")
const Crowns := preload("res://src/systems/18_crowns.gd")
const Terrain := preload("res://tests/render/test_terrain.gd")
const SHADER := "res://src/render/foliage/leaf.gdshader"


func test_every_plant_with_leaves_draws_them_as_cards() -> void:
	var coast := BiomeRegistry.index_of(&"coast")
	for kind: int in [PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.BUSH, PropKind.GORSE]:
		for v in PropModels.variants(kind):
			var t := PropModels.template(kind, v, coast)
			gt(t.leaf_v.size(), 60, "%s %d has leaves" % [PropKind.NAMES[kind], v])
	for v in PropModels.variants(PropKind.SCRAP_TREE):
		gt(PropModels.template(PropKind.SCRAP_TREE, v, BiomeRegistry.index_of(&"scrapwood")).leaf_v.size(), 60, "scrap tree %d has leaves" % v)
	# What has no leaves draws none: a dead tree, a burnt pine, reeds.
	eq(PropModels.template(PropKind.DEAD_TREE, 0, coast).leaf_v.size(), 0, "a dead tree has no leaves")
	eq(PropModels.template(PropKind.PINE, 0, Country.BURNING).leaf_v.size(), 0, "a burnt pine has lost its needles")
	eq(PropModels.template(PropKind.BROADLEAF, 0, Country.SNOWFIELD).leaf_v.size(), 0, "a broadleaf in winter is bare")
	eq(PropModels.template(PropKind.BOULDER, 0, coast).leaf_v.size(), 0, "a boulder has no leaves")


func test_a_card_is_a_whole_quad_cut_to_a_sprig_the_shader_knows() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	for pair: Array in [["LEAF_BROAD", Kit.LEAF_BROAD], ["LEAF_SMALL", Kit.LEAF_SMALL], ["LEAF_NEEDLE", Kit.LEAF_NEEDLE], ["LEAF_SPINE", Kit.LEAF_SPINE]]:
		check(src.contains("const int %s = %d;" % pair), "the shader cuts %s as the kit names it" % pair[0])
	var known := [Kit.LEAF_BROAD, Kit.LEAF_SMALL, Kit.LEAF_NEEDLE, Kit.LEAF_SPINE]
	for kind: int in [PropKind.PINE, PropKind.BROADLEAF, PropKind.BUSH, PropKind.GORSE]:
		var t := PropModels.template(kind, 1, Country.COAST)
		eq(t.leaf_v.size() % 6, 0, "%s: cards are whole quads" % PropKind.NAMES[kind])
		eq(t.leaf_uv.size(), t.leaf_v.size(), "%s: every corner has card coordinates" % PropKind.NAMES[kind])
		for i in t.leaf_v.size():
			var uv := t.leaf_uv[i]
			if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
				fail("%s: a card corner off its own card (%s)" % [PropKind.NAMES[kind], uv])
				break
			if not known.has(roundi(t.leaf_c[i].a * 255.0)):
				fail("%s: a card names a sprig the shader does not cut (%d)" % [PropKind.NAMES[kind], roundi(t.leaf_c[i].a * 255.0)])
				break


func test_the_cards_are_opaque_and_double_sided_and_lit_through() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	check(src.contains("render_mode cull_disabled;"), "a leaf has no back to cull")
	check(src.contains("discard;"), "a sprig is cut, not blended")
	# Blended world geometry at the default priority silently does not draw.
	check(not src.contains("ALPHA =") and not src.contains("ALPHA_SCISSOR"), "nothing writes ALPHA: the card stays in the opaque pass")
	check(PropModels.leaf_material().render_priority == 0, "and so needs no priority to be drawn at all")
	check(src.contains("BACKLIGHT ="), "sun comes through a leaf from behind")
	check(src.contains("FRONT_FACING ? NORMAL : -NORMAL"), "the crown normal is recovered whichever face shows")


func test_a_card_carries_the_crowns_normal_not_its_own() -> void:
	# The one trick that makes cards a mass: the vertex normal points out of the
	# crown, whichever way the card itself happens to face.
	var k := Kit.new()
	var cols: Array[Color] = [Palette.MOSS[3]]
	var centre := Vector3(0.0, 1.0 + 0.8 * 0.46, 0.0)
	k.canopy(0.0, 1.0, 0.0, 0.5, 0.8, 77, cols, Kit.LEAF_BROAD, 0.26, 40)
	eq(k.leaf.vertex_count(), 40 * 6, "forty cards, six corners each")
	var outward := 0
	var faces_agree := 0
	for i in range(0, k.leaf.vertex_count(), 6):
		var v := k.leaf.verts[i]
		var n := k.leaf.normals[i]
		if n.dot(v - centre) > 0.0:
			outward += 1
		var face := (k.leaf.verts[i + 1] - v).cross(k.leaf.verts[i + 2] - v).normalized()
		if absf(face.dot(n)) > 0.95:
			faces_agree += 1
	gt(float(outward), 40 * 0.95, "the crown's normal points out of the crown")
	lt(float(faces_agree), 40 * 0.5, "and is not simply each card's own face")


func test_a_canopy_is_the_same_every_time_it_is_built() -> void:
	var a := Kit.new()
	var b := Kit.new()
	var cols: Array[Color] = [Palette.MOSS[2], Palette.MOSS[3]]
	a.canopy(0.1, 0.0, -0.2, 0.4, 0.6, 1234, cols, Kit.LEAF_SMALL, 0.2, 30)
	b.canopy(0.1, 0.0, -0.2, 0.4, 0.6, 1234, cols, Kit.LEAF_SMALL, 0.2, 30)
	eq(a.leaf.verts, b.leaf.verts, "same seed, same cards")
	eq(a.leaf.colors, b.leaf.colors, "same seed, same washes")
	eq(a.leaf.uv2s, b.leaf.uv2s, "same seed, same phases")


func test_a_crown_still_opens_over_a_fight() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	check(src.contains("uniform vec4 crown_clear[CROWN_CLEAR];"), "the leaves take the clearings")
	check(src.contains("const int CROWN_CLEAR = %d;" % Crowns.SLOTS), "the same slots as 18_crowns")
	check(src.contains("const float CROWN_SWAY = %.2f;" % Crowns.SWAY_MIN), "the same sway gate")
	check(src.contains("const float CROWN_LIFT = %.2f;" % Crowns.LIFT), "the same lift gate")
	check(src.contains("ink_hash(px + vec2(53.0, 11.0)) < cut"), "cut as world-pinned stipple, never a fade")
	# ...and the cards of a crown stand high enough and sway enough to be cut.
	for kind: int in [PropKind.BROADLEAF, PropKind.PINE]:
		var t := PropModels.template(kind, 0, Country.COAST)
		var open := 0
		for i in t.leaf_v.size():
			if t.leaf_v[i].y > Crowns.LIFT + 0.2 and t.leaf_uv2[i].x >= Crowns.SWAY_MIN:
				open += 1
		gt(float(open), t.leaf_v.size() * 0.3, "%s: most of a crown is leaves that can open" % PropKind.NAMES[kind])


func test_a_chunk_draws_its_leaves_in_one_more_call_with_the_views_own_material() -> void:
	var w := Terrain.fixture()
	w.props.append(WorldProp.new(0, PropKind.BROADLEAF, Vector2(36.5, 38.5), 0.3, 1.0))
	w.props.append(WorldProp.new(1, PropKind.BUSH, Vector2(40.5, 40.5), 0.2, 1.0))
	w.props.append(WorldProp.new(2, PropKind.BOULDER, Vector2(42.5, 41.5), 0.3, 1.0))
	var view := WorldView.new()
	view.setup(w)
	tree.root.add_child(view)
	view.ensure_near(Vector2(40, 40))
	var node := view.get_node_or_null("chunk_1_1")
	check(node != null, "the chunk with the plants is built")
	if node != null:
		var leaves := node.get_node_or_null("props_leaf") as MeshInstance3D
		check(leaves != null, "the chunk has a leaf surface")
		if leaves != null:
			check(leaves.material_override == view.leaf_material(), "drawn with the view's own leaf material, which 18_crowns writes")
			eq(leaves.mesh.get_surface_count(), 1, "every plant's cards in one draw")
			var direct := view.bake_props(view.chunk_at(Vector2(40, 40)), TerrainMesher.new(w), [w.props[0], w.props[1], w.props[2]], [])
			eq(leaves.mesh.surface_get_array_len(0), (direct[2][Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "the leaves are the direct bake")
		# Taking a plant takes its leaves.
		w.depleted[1] = INF
		view.refresh_props(w.props[1])
		var after := view.get_node_or_null("chunk_1_1/props_leaf") as MeshInstance3D
		var bush := PropModels.template(PropKind.BUSH, PropModels.variant_of(w.props[1], w.seed_value), view.prop_country(w.props[1], view.chunk_at(Vector2(40, 40))))
		if after != null and leaves != null:
			eq(after.mesh.surface_get_array_len(0), leaves.mesh.surface_get_array_len(0) - bush.leaf_v.size(), "the taken bush's leaves are gone from the bake")
	view.queue_free()
	await tree.process_frame


## `Broken.work_down` cuts a thing's MADE and FOUND geometry down to what the
## taking has left, and leaves its cards alone: a plant worked down that way would
## stand a whole crown over half a trunk. Nothing that grows leaves is taken like
## that today (gathering keeps the plant, felling takes it whole), and this is the
## line that says so before a take is added that would change it.
func test_nothing_with_leaves_is_worked_down_under_its_crown() -> void:
	for kind in PropKind.COUNT:
		var leafy := false
		for v in PropModels.variants(kind):
			for c: int in BiomeRegistry.land_indices():
				leafy = leafy or not PropModels.template(kind, v, c).leaf_v.is_empty()
		if not leafy:
			continue
		for o: Dictionary in Takes.options(kind):
			check(bool(o.keep) or int(o.uses) <= 1,
				"%s grows leaves and a take (%s) works it down: Broken would cut the trunk under a whole crown"
				% [PropKind.NAMES[kind], o.verb])


func test_a_falling_tree_takes_its_crown_down_in_its_own_material() -> void:
	var leaves := PropModels.leaf_node(PropKind.BROADLEAF)
	check(leaves != null, "a broadleaf's leaves as a node")
	if leaves != null:
		check(leaves.material_override == PropModels.leaf_material(), "carrying the leaf shader, never the world's")
		leaves.free()
	check(PropModels.leaf_node(PropKind.BOULDER) == null, "a boulder has none")
