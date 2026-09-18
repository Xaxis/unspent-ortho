class_name ForeView
extends Node3D
## The layer between the camera and the place (docs/LOOK.md law 3).
##
## An orthographic camera gives depth away for NOTHING. There is no perspective
## parallax: a thing at depth 10 and a thing at depth 50 move across the screen
## by exactly the same number of pixels when the camera pans, and they are drawn
## at exactly the same scale. Every cue a perspective game gets free has to be
## bought here, and there are only three worth buying:
##
##   1. OCCLUSION. Something in front of something. This is the whole of it, and
##      the game had none: everything stood on one plane and the camera saw all
##      of it at once, which is why a beautifully lit frame still read as a lit
##      diagram rather than a place. So: pieces hung over the play plane, that
##      the player walks BEHIND.
##   2. The SHADOW a near thing throws on a far one. A bough four units up lays a
##      shadow across the ground the player is standing on, and that shadow is
##      what says the bough is real and how high it is. It costs a shadow pass
##      this package did not add -- the sun was already casting.
##   3. MOVEMENT that is not the camera's. The pieces sway on the world's own
##      wind (fore.gdshader's vertex, world.gdshader's numbers). A still frame
##      loses this and a moving one does not.
##
## WHAT IS NOT HERE, on purpose: nothing camera-locked. A "foreground layer" that
## slides with the camera reads as dirt on the lens, and after ten seconds of
## walking the player knows it is not in the world. Every piece here stands at a
## world position, hung on a prop that is standing there (`ForeKinds`), and
## enters and leaves the frame as the player walks past it.
##
## THE RISK THIS FILE OWNS. An occluder may never hide a threat or a thing that
## can be taken. `clear()` is that promise, and it is kept the way 18_crowns
## keeps it for tree crowns -- a ranked list of bodies, a hole cut in stipple --
## with one difference that is the reason this is not simply 18_crowns:
## `crown_clear` cuts by HORIZONTAL distance, and under this camera a piece at
## height h draws over ground h/tan(pitch) further away than it stands. At four
## units that is 2.6 tiles, against a crown's reach of 1.6, so the existing cut
## would have opened its hole in clear air. fore.gdshader is handed the lean and
## the bearing and cuts where the piece DRAWS.

## Slots in fore.gdshader's `fore_clear`. The player always takes slot 0.
const CLEAR := 8
## Tiles of clear round a body: gone inside about 0.58 of it, stippling out by
## the whole. Wider than a crown's 1.6 because a piece is higher up and its
## shadow on the ground is wider than the piece.
const CLEAR_REACH := 2.1
## The player's own hole, which also has to cover whatever is at their feet: the
## driftwood they are standing on is a thing that can be taken and the promise
## covers it. Two and a half tiles is the whole of a `use` reach and more.
const PLAYER_REACH := 2.6
## A body further than this from the player is not part of this moment.
const NEAR := 14.0

## Tiles around the focus that props are asked for. A piece may reach 10 tiles
## from its own root, so the band is wider than the frame's own half extent or a
## line would appear out of nothing at the edge.
const REACH := 22.0
## Tiles the focus must move before the band is gathered again. Gathering walks
## the prop grid, so it is not free; a third of a tile is far below what a player
## can see change.
const RESTEP := 0.34

var world: WorldData
var query: WorldQuery
var camera: CameraRig
## How many pieces may be alive at once. Quality's `fore` row; 0 turns the layer
## off altogether, which is what the lowest tiers do.
var budget := 0

## The shared material. One for every piece, because a piece carries its colour
## and its material id in its own vertices.
var _mat: ShaderMaterial
var _pool: Array[MeshInstance3D] = []
var _live := 0
var _last_gather := Vector2(INF, INF)
var _slots := PackedVector4Array()
## What was hung, so a gather that finds the same props does no work.
var _keys: PackedInt64Array = PackedInt64Array()

## How many pieces are drawn this frame. `--stats` and the tests read it.
var drawn := 0


func setup(w: WorldData, q: WorldQuery, cam: CameraRig) -> void:
	world = w
	query = q
	camera = cam
	budget = int(Quality.current().get("fore", 0))
	_slots.resize(CLEAR)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/render/depth/fore.gdshader")
	_mat.set_shader_parameter("fore_clear", _slots)
	_aim()


## A realm crossing replaces the world under us; the pieces hung in the old one
## belong to it. 20_realms calls this through the system.
func rebind(w: WorldData, q: WorldQuery) -> void:
	world = w
	query = q
	_last_gather = Vector2(INF, INF)
	_keys = PackedInt64Array()
	for m in _pool:
		m.visible = false
	_live = 0
	drawn = 0


## Where the camera is, expressed the way fore.gdshader needs it: how far a piece
## draws beyond its own ground per unit of height, and in which direction.
##
## Read off the LIVE camera every frame rather than off CameraRig's exports,
## because a target lock leans the rig (42_target) and a lean that moved the
## picture without moving the hole would put the hole beside the machine exactly
## when the player was reading it.
func _aim() -> void:
	var lean := 0.6494
	var toward := Vector2(0.7071, 0.7071)
	if camera != null and camera.is_inside_tree():
		var b := camera.global_transform.basis.z
		var flat := Vector2(b.x, b.z)
		if flat.length() > 0.001:
			toward = flat.normalized()
			# b is unit length, so its horizontal part over its vertical part is
			# exactly 1/tan(pitch) with no trigonometry and no assumption about
			# which angle the rig was built with.
			lean = flat.length() / maxf(0.05, absf(b.y))
	_mat.set_shader_parameter("fore_lean", lean)
	_mat.set_shader_parameter("fore_toward", toward)


## The bodies nothing may hide, into `fore_clear`. Ranked exactly as 18_crowns
## ranks them and for the same reason: a flock of gulls twelve tiles off must
## never fill the slots and leave the machine two tiles away under a bough.
func clear_for(player: Vector2, mobs: Array[Vector2], hostile: PackedByteArray,
		aware: PackedByteArray, ground: Callable) -> void:
	var chosen := rank(mobs, hostile, aware, player, CLEAR - 1)
	_slots[0] = Vector4(player.x, float(ground.call(player)), player.y, PLAYER_REACH)
	var n := mini(chosen.size(), CLEAR - 1)
	for i in n:
		var p: Vector2 = chosen[i]
		_slots[i + 1] = Vector4(p.x, float(ground.call(p)), p.y, CLEAR_REACH)
	for i in range(n + 1, CLEAR):
		_slots[i] = Vector4.ZERO
	_mat.set_shader_parameter("fore_clear", _slots)


## Which bodies get a hole when more are near than there are slots: one that has
## noticed the player first, a hostile before a pest, then the nearest. Pure.
static func rank(pos: Array[Vector2], hostile: PackedByteArray, aware: PackedByteArray,
		player: Vector2, limit: int) -> Array[Vector2]:
	var order: Array[int] = []
	for i in pos.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra := int(aware[a]) * 2 + int(hostile[a])
		var rb := int(aware[b]) * 2 + int(hostile[b])
		if ra != rb:
			return ra > rb
		return pos[a].distance_squared_to(player) < pos[b].distance_squared_to(player))
	var out: Array[Vector2] = []
	for i in mini(limit, order.size()):
		out.append(pos[order[i]])
	return out


## Every frame: aim the hole, and gather again when the focus has moved enough.
func follow(focus: Vector2) -> void:
	if budget <= 0 or world == null or query == null:
		return
	_aim()
	if focus.distance_to(_last_gather) < RESTEP:
		return
	_last_gather = focus
	_gather(focus)


## Which props near the focus carry a piece, nearest first, up to the budget.
## Pure apart from asking the query where the props are, so a test can run it.
func _gather(focus: Vector2) -> void:
	var found: Array = []
	for p: WorldProp in query.props_near(focus, REACH):
		if not ForeKinds.carries(p.kind):
			continue
		# A prop the player has taken is not standing there any more, and neither
		# is what was hanging off it.
		if world.depleted.has(p.id):
			continue
		if not ForeKinds.hung_on(p, world.seed_value, _country(p)):
			continue
		found.append([p.pos.distance_squared_to(focus), p])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var want := mini(found.size(), budget)
	# Nothing changed: the same props in the same order, so every transform and
	# every mesh already on the pool is still right.
	var keys := PackedInt64Array()
	keys.resize(want)
	for i in want:
		keys[i] = (found[i][1] as WorldProp).id
	if keys == _keys:
		return
	_keys = keys
	for i in want:
		_place(i, found[i][1] as WorldProp, focus)
	for i in range(want, _live):
		_pool[i].visible = false
	_live = want
	drawn = want


## The landscape a prop stands in. A BUILDING's piece is decided by what its
## landscape BUILT (`ForeKinds.row_of`), so the country has to travel with the
## prop: every building in the game is one PropKind and the kind alone cannot
## tell a six-storey tower from a cot.
func _country(p: WorldProp) -> int:
	return maxi(Country.COAST, world.country_at(floori(p.pos.x), floori(p.pos.y)))


func _place(i: int, p: WorldProp, focus: Vector2) -> void:
	var hang := ForeKinds.hang(p, world.seed_value, _country(p))
	var node := _slot(i)
	var tint := _tint(p)
	node.mesh = ForeKinds.template(int(hang.shape), int(hang.variant), tint)
	var base: Vector3 = world.to_3d(p.pos)
	var span := float(hang.span)
	# WHICH WAY IT REACHES. Biased toward the far side of the frame, because a
	# piece only ever draws over ground FURTHER from the eye than it stands:
	# reaching the other way puts it behind the very thing it should be in front
	# of. The bias is against the rig's FIXED yaw and never `yaw_now()` -- a
	# camera lean must not move world geometry, or every `same A B TOL` in every
	# tour fails on a frame where the player happened to be holding the read key.
	var away := _away()
	var jitter := (float(hang.turn) - 0.5) * 2.2
	var dir := away.rotated(jitter)
	var t := Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)).scaled(Vector3(span, span, span)),
		base + Vector3(0.0, float(hang.lift), 0.0))
	node.global_transform = t
	# Nothing pops at the edge of the band and nothing is faded to hide it: REACH
	# is 22 tiles and the frame's own furthest corner is about 13, so a piece is
	# hung and unhung well outside the picture and the player never sees either.
	node.visible = true


## The fixed bearing away from the camera, on the ground. Read off the rig's
## exported yaw, which never changes -- see `_place` for why a lean may not.
func _away() -> Vector2:
	var yaw := deg_to_rad(camera.yaw_deg if camera != null else 45.0)
	# The camera stands at focus + basis.z * distance, so basis.z's horizontal
	# part is toward the eye and its opposite is away from it.
	return -Vector2(sin(yaw), cos(yaw)).normalized()


## What colour a piece is, from the landscape it stands in. A bough over the
## pinewood is not a bough over the salt, and BiomeDef already says so: the
## landscape's own tree tints where it has them, its decor tints where it has
## not. Nothing new is authored per landscape for this layer.
func _tint(p: WorldProp) -> Color:
	var def := BiomeRegistry.at(world, p.pos)
	var tints: Dictionary = def.tree_tints
	if not tints.is_empty():
		for k: Variant in tints:
			var c: Variant = tints[k]
			if c is Color:
				return c as Color
	if not def.grass_colors.is_empty():
		return def.grass_colors[0]
	return Palette.SPRUCE[2]


func _slot(i: int) -> MeshInstance3D:
	while _pool.size() <= i:
		var m := MeshInstance3D.new()
		m.name = "fore_%d" % _pool.size()
		m.material_override = _mat
		# It CASTS. A near thing's shadow on a far thing is the second of the
		# three cues an orthographic camera does not give away, and the sun is
		# already drawing a shadow map -- this is the cheapest depth in the
		# package. It does not RECEIVE its own kind's shadows worth speaking of.
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# A piece is scaled up to ten times and swayed in its own vertex shader,
		# so its built AABB is not where it ends up. Without this the renderer
		# culls it the moment its root leaves the frustum, which is exactly when
		# a limb reaching across the frame matters most.
		m.extra_cull_margin = 16.0
		add_child(m)
		_pool.append(m)
	return _pool[i]
