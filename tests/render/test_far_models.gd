extends TestCase
## A model seen from far off is the model itself with what is too small to see
## left out (src/models/far_models.gd), and at eye level the near square hands its
## far half over to those models and parks what is behind the camera
## (src/render/world_view.gd `_lod_apply`, `_in_view`) -- while the top-down game
## sees none of it.

const FarModels := preload("res://src/models/far_models.gd")


## Two triangles of a quad from `o` along `u` and `v`, wound as MeshKit winds.
static func _quad(t: PropModels.Template, o: Vector3, u: Vector3, v: Vector3, mark: int) -> void:
	var c := Color(0.5, 0.5, 0.5, mark / 255.0)
	var n := u.cross(v).normalized()
	for p: Vector3 in [o, o + u, o + u + v, o, o + u + v, o + v]:
		t.made_v.append(p)
		t.made_n.append(n)
		t.made_c.append(c)
		t.made_uv.append(Vector2.ZERO)
		t.made_uv2.append(Vector2.ZERO)


## A lattice strut is long and thin, a bolt is small both ways: from far off the
## strut still draws a line and the bolt is under a pixel. Ranking by AREA kept
## neither and left a pylon's insulators floating in the air.
func test_a_strut_is_kept_and_a_bolt_is_not() -> void:
	var t := PropModels.Template.new()
	_quad(t, Vector3(0, 0.5, 0), Vector3(0, 3.0, 0), Vector3(0.03, 0, 0), 0)
	_quad(t, Vector3(1, 0.5, 0), Vector3(0, 0.03, 0), Vector3(0.03, 0, 0), 0)
	var r := FarModels.reduce(t, FarModels.NEAR_FAR)
	eq(r.made_v.size(), 6, "the strut's two faces stay and the bolt's go")
	for p: Vector3 in r.made_v:
		lt(p.x, 0.5, "and what stays is the strut")


## A window is smaller than anything else a far model keeps, and a far city at
## night is its windows: a lit face is kept well under the level's tolerance.
func test_a_lit_face_outlives_a_plain_one_of_its_size() -> void:
	var s := FarModels.TOL[FarModels.NEAR_FAR] * 0.6
	var lit := PropModels.Template.new()
	_quad(lit, Vector3(0, 1, 0), Vector3(0, s, 0), Vector3(s * 0.5, 0, 0), 19)
	_quad(lit, Vector3(0, 0, 0), Vector3(0, 3.0, 0), Vector3(3.0, 0, 0), 0)
	var plain := PropModels.Template.new()
	_quad(plain, Vector3(0, 1, 0), Vector3(0, s, 0), Vector3(s * 0.5, 0, 0), 0)
	_quad(plain, Vector3(0, 0, 0), Vector3(0, 3.0, 0), Vector3(3.0, 0, 0), 0)
	eq(FarModels.reduce(lit, FarModels.NEAR_FAR).made_v.size(), 12, "the window stays on its wall")
	eq(FarModels.reduce(plain, FarModels.NEAR_FAR).made_v.size(), 6, "a speck the same size does not")


## A crown is thinned and grown, never emptied: the far tree keeps its mass.
func test_a_crown_thins_but_never_vanishes() -> void:
	var t := PropModels.template(PropKind.BROADLEAF, 0, Country.COAST)
	var cards := t.leaf_v.size() / 6
	gt(float(cards), 8.0, "a broadleaf has a crown to thin")
	for level: int in [FarModels.NEAR_FAR, FarModels.FAR]:
		var r := FarModels.template(PropKind.BROADLEAF, 0, Country.COAST, level)
		var kept := r.leaf_v.size() / 6
		check(kept >= 1 and kept < cards, "level %d keeps some cards and not all (%d of %d)" % [level, kept, cards])
		# Grown about their middles, so the crown covers about what it covered.
		gt(_card_area(r.leaf_v), _card_area(t.leaf_v) * 0.4, "and the thinned crown keeps its mass at level %d" % level)


static func _card_area(v: PackedVector3Array) -> float:
	var a := 0.0
	for i in range(0, v.size(), 3):
		a += (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).length() * 0.5
	return a


## A flat plain at level 2, four chunks across.
static func _plain() -> WorldData:
	var w := WorldData.new(3, 128)
	for i in 128 * 128:
		w.level[i] = 2
		w.ground[i] = Ground.GRASS
		w.country[i] = Country.COAST
	for x: float in [16.5, 110.5]:
		w.add_prop(WorldProp.new(w.next_id(), PropKind.PINE, Vector2(x, 64.5), 0.0, 1.0))
	return w


func _eye(at: Vector3, toward: Vector3) -> Camera3D:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_PERSPECTIVE
	c.keep_aspect = Camera3D.KEEP_HEIGHT
	c.fov = 50.0
	tree.root.add_child(c)
	c.look_at_from_position(at, toward, Vector3.UP)
	c.make_current()
	return c


## AT EYE LEVEL HALF THE SQUARE IS BEHIND YOU, and it is parked rather than
## drawn into the shadow splits -- but still built, so turning round brings it
## back on the next frame instead of building it while the player watches.
func test_eye_level_parks_what_is_behind_and_turning_brings_it_back() -> void:
	var w := _plain()
	var cam := _eye(Vector3(76, 4.0, 64), Vector3(200, 3.8, 64))
	var view := WorldView.new()
	view.setup(w)
	tree.root.add_child(view)
	view.ensure_near(Vector2(76, 64))
	await process_frames(3)
	var behind := Vector2i(0, 2)
	check(view._parked.has(behind), "the chunk behind the eye is out of the scene")
	check(view._chunks.has(Vector2i(3, 2)), "the one ahead is in it")
	cam.look_at_from_position(Vector3(76, 4.0, 64), Vector3(-100, 3.8, 64), Vector3.UP)
	await process_frames(1)
	check(view._chunks.has(behind), "turned round, it is back on the next frame")
	eq(view.build_count, 16, "and nothing had to be built to bring it back")
	view.queue_free()
	cam.queue_free()


## At eye level a crown's full cards cast only to LEAF_SHADOW and its shade model
## casts past that, while trunks and boughs keep casting in full to SHADOW_FULL:
## far leaf cards were a third of a wooded frame's shadow primitives.
func test_leaf_cards_cast_close_in_and_the_shade_crowns_past_it() -> void:
	var w := _plain()
	var cam := _eye(Vector3(76, 4.0, 64), Vector3(200, 3.8, 64))
	var view := WorldView.new()
	view.setup(w)
	tree.root.add_child(view)
	view.ensure_near(Vector2(76, 64))
	await process_frames(2)
	var node: Node3D = view._chunks[Vector2i(3, 2)]
	var leaf := node.get_node_or_null("props_leaf_casts") as GeometryInstance3D
	var made := node.get_node_or_null("props_casts") as GeometryInstance3D
	var shade := node.get_node_or_null("shade_leaf_casts") as GeometryInstance3D
	check(leaf != null and made != null and shade != null, "the leaves, the trunks and the shade crowns each cast by a twin")
	if leaf != null and made != null and shade != null:
		near(leaf.visibility_range_end, minf(WorldView.LEAF_SHADOW, WorldView.SHADOW_FULL), 1e-3, "leaf cards cast to LEAF_SHADOW")
		gt(made.visibility_range_end, leaf.visibility_range_end, "trunks and boughs cast further than the cards")
		near(shade.visibility_range_begin, leaf.visibility_range_end, 1e-3, "and the shade crowns take over where the cards stop")
	view.queue_free()
	cam.queue_free()


## Past MID_FROM a chunk's props are drawn as their mid models, at eye level only:
## the top-down game keeps every chunk whole at any range and casting for itself.
func test_the_hand_over_is_the_eyes_and_never_the_top_down_games() -> void:
	var w := _plain()
	var cam := _eye(Vector3(76, 4.0, 64), Vector3(200, 3.8, 64))
	var view := WorldView.new()
	view.setup(w)
	tree.root.add_child(view)
	view.ensure_near(Vector2(76, 64))
	await process_frames(2)
	var node: Node3D = view._chunks[Vector2i(3, 2)]
	check(node.get_node_or_null("mid_done") != null, "an eye bakes the chunk's mid models")
	var props := node.get_node("props_leaf") as GeometryInstance3D
	eq(props.visibility_range_end, WorldView.MID_FROM, "and its full props hand over to them at MID_FROM")
	check((node.get_node("mid_leaf") as GeometryInstance3D).visible, "which are drawn past it")
	# With the fade off a range margin is hysteresis on each half of the pair, so
	# the mid models must be shown by the time the full ones may still be hidden:
	# otherwise a chunk in the band is drawn by neither (the roofs sixty tiles out
	# lost every tank and mast that way).
	var mid := node.get_node("mid_leaf") as GeometryInstance3D
	check(mid.visibility_range_begin + mid.visibility_range_begin_margin
		<= props.visibility_range_end - props.visibility_range_end_margin, "no band where neither half draws")
	var top := Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.rotation = Vector3(deg_to_rad(-CameraRig.PITCH_DEG), 0.0, 0.0)
	tree.root.add_child(top)
	top.make_current()
	await process_frames(2)
	for key: Vector2i in view._chunks:
		var n: Node3D = view._chunks[key]
		for part: Node in n.get_children():
			check(not part.name.ends_with("_casts"), "no shadow twin under the top-down camera (%s)" % part.name)
			if part is GeometryInstance3D and not str(part.name).begins_with("mid") and not str(part.name).begins_with("shade"):
				var gi := part as GeometryInstance3D
				eq(gi.visibility_range_end, 0.0, "%s draws at any range from above" % part.name)
			elif part is GeometryInstance3D and str(part.name).begins_with("mid"):
				check(not (part as GeometryInstance3D).visible, "and the mid models are not drawn")
	view.queue_free()
	cam.queue_free()
	top.queue_free()
