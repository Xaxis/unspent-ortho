extends GameSystem
## DOORS (docs/interiors): walking into a house and out again. A house whose
## landscape declares an interior for it (`BiomeDef.interiors`) has a door
## (`Threshold`), and behind it a POCKET world (`InteriorGen`) that 20_realms
## points the game at, the way a shaft points it at a realm. Not a new game: the
## clock, the score, the body and the creel go in with the player.
##
## THE DOOR ONLY SWAPS. Everything that costs is paid before it:
##   - within WARM of a door the pocket is grown (pure, under a millisecond), and a
##     view of it is made sharing the outside view's materials and put in the
##     tree HIDDEN, so its chunks are built on its own worker while the player
##     walks up (S0 measured growing them at the door at 85-150 ms);
##   - at the door the outside view is taken out of the tree WHOLE -- its chunks,
##     its far land, its in-flight worker tasks, which finish into its own fields
##     -- and the pocket's view is shown, under a cover that closes on the door
##     from above (an iris) or blinks as the eye passes the jamb over the shoulder;
##   - coming out puts the outside view back as it was: nothing is rebuilt (S0:
##     rebinding the coast instead cost about a second).
##
## Inside, the walls are the layout's, handed to the query as blocks; the model
## shows the camera a section from above and the whole room over the shoulder
## (CottageModel.show_for); the windows let the sun in along its own bearing.

const CottageModel := preload("res://src/models/interior/cottage_model.gd")
## A pocket is grown and its view built within this of a door, and a body within
## REACH of one may go through it.
const WARM := 7.0
const REACH := 1.4
## Seconds the cover takes to close and to open, from above and over the shoulder.
const CLOSE := 0.18
const OPEN := 0.24
const BLINK := 0.06
## How much of the sky's light comes in off each window at full day; how hard a
## window's own sun is, and how far below level it shines (a fall of 0.62 for
## each unit across, about thirty-two degrees).
const SKY_IN := 0.35
const SUN_IN := 3.0
const SUN_LOW := 0.62

## The doors of the world outside, and the one within reach, if any.
var doors: Array[Threshold] = []
var door_near: Threshold = null
## Inside: the pocket and what draws it; null outside.
var pocket: InteriorGen.Pocket = null
var model: Node3D = null
var crossings := 0

var _grown: InteriorGen.Pocket = null
var _view: WorldView = null
var _model: Node3D = null
var _outside: WorldData = null
var _outside_view: WorldView = null
var _outside_query: WorldQuery = null
var _outside_key: StringName = &""
var _outside_height := 0.0
var _swapping := false
var _cover: ColorRect
var _cover_mat: ShaderMaterial
var _lights: Array[SpotLight3D] = []
var _windows: Array[Array] = []
## The swap frames, measured: how long the frame that swapped in and out took.
var swap_in_ms := 0.0
var swap_out_ms := 0.0
var built_after_out := -1


func setup(g: Game) -> void:
	super.setup(g)
	doors = Interiors.thresholds(g.world)
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.name = "door_cover"
	add_child(layer)
	_cover = ColorRect.new()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover_mat = ShaderMaterial.new()
	_cover_mat.shader = _iris()
	_cover.material = _cover_mat
	_cover.visible = false
	layer.add_child(_cover)


## A game that ends with the player indoors still holds the coast's view, out of
## the tree, where nothing else will free it: freed here, so its workers are
## waited for (WorldView, at predelete) before the engine quits under them.
func _exit_tree() -> void:
	if _outside_view != null and is_instance_valid(_outside_view) and not _outside_view.is_inside_tree():
		_outside_view.free()
	_outside_view = null


func _process(delta: float) -> void:
	var down := Input.is_action_pressed(&"use")
	_use_edge = down and not _use_was
	_use_was = down
	if game == null or game.world == null or game.player == null or _swapping:
		return
	if game.watch.is_finite():
		return
	if pocket == null:
		_outside_side()
	else:
		_inside_side(delta)


func _outside_side() -> void:
	var at := game.player.pos
	door_near = null
	var best: Threshold = null
	var bd := INF
	for t: Threshold in doors:
		var d := t.door.distance_squared_to(at)
		if d < bd:
			bd = d
			best = t
	if best == null or bd > WARM * WARM:
		return
	_begin(best)
	if bd <= REACH * REACH:
		door_near = best
		if _pressed() and _door_wins(best.door):
			go_in(best)


func _inside_side(_delta: float) -> void:
	var cam := game.camera
	var back := Vector2(cam.global_transform.basis.z.x, cam.global_transform.basis.z.z)
	if back.length() > 0.001:
		back = back.normalized()
	model.call(&"show_for", back, cam.shoulder_share())
	_light_windows()
	door_near = null
	if game.player.pos.distance_to(pocket.layout.door) <= REACH:
		door_near = pocket.threshold
		if _pressed():
			go_out()


## The press is this system's own edge (down now, up the frame before), not
## `is_action_just_pressed`: that answers only in the frame the key went down, so
## a press made later in a frame than this system runs -- a tour's, from a system
## numbered after it -- is never seen at all.
var _use_was := false
var _use_edge := false


func _pressed() -> bool:
	if game.input_blocked() or not _use_edge:
		return false
	for s in game.systems:
		if s != self and s.has_method(&"use_spent") and bool(s.call(&"use_spent")):
			return false
	return true


## `use` is one key: the door takes it only when it is nearer than whatever is
## under the hand, as a shaft does (20_realms `_shaft_wins`).
func _door_wins(at: Vector2) -> bool:
	var t := Survival.use_target(game)
	return t == null or at.distance_to(game.player.pos) <= t.pos.distance_to(game.player.pos)


## Grow the pocket behind `t` and a hidden view of it, once, while the player is
## on the way to its door.
func _begin(t: Threshold) -> void:
	if _grown != null and _grown.threshold.key == t.key:
		return
	_drop_grown()
	_grown = InteriorGen.grow(game.options.seed_value, t)
	if _grown == null:
		return
	_view = WorldView.new()
	_view.name = "pocket"
	_view.setup_sharing(_grown.world, game.view)
	_view.visible = false
	_view.focus = _grown.world.spawn
	_model = CottageModel.new()
	_model.name = "rooms"
	_model.call(&"build", _grown.layout, _grown.kind, t.land, game.view.world_material())
	_view.add_child(_model)
	game.add_child(_view)


func _drop_grown() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	_model = null
	_grown = null


## Through the door, under the cover.
func go_in(t: Threshold) -> void:
	if pocket != null or _swapping:
		return
	_begin(t)
	if _grown == null:
		return
	Events.sfx.emit(&"door", game.player.position)
	await _cover_close(t.door)
	var t0 := Time.get_ticks_usec()
	_swap_in()
	swap_in_ms = (Time.get_ticks_usec() - t0) / 1000.0
	await _cover_open()


func _swap_in() -> void:
	var realms := _realms()
	var p := _grown
	_outside = game.world
	_outside_view = game.view
	_outside_query = game.query
	_outside_key = realms.get("_realm")
	_outside_height = game.camera.view_height
	game.set_meta(SaveCore.META_OUTSIDE, _outside)
	game.remove_child(_outside_view)
	_view.visible = true
	game.view = _view
	pocket = p
	model = _model
	_grown = null
	realms.set("pocket_closed", p.kind.closed)
	realms.call(&"enter", p.world, p.threshold.realm_key(), p.layout.inside())
	game.query.set_blocks(&"rooms", _walls(p.layout))
	game.camera.view_height = p.kind.zoom
	_windows = model.call(&"windows")
	_make_lights()
	crossings += 1


## Out of the door, under the cover, onto the world that was left: the same one.
func go_out() -> void:
	if pocket == null or _swapping:
		return
	Events.sfx.emit(&"door", game.player.position)
	await _cover_close(pocket.layout.door)
	var t0 := Time.get_ticks_usec()
	var before := _outside_view.build_count
	_swap_out()
	swap_out_ms = (Time.get_ticks_usec() - t0) / 1000.0
	await _cover_open()
	built_after_out = game.view.build_count - before


func _swap_out() -> void:
	var realms := _realms()
	var t := pocket.threshold
	for l: SpotLight3D in _lights:
		l.queue_free()
	_lights.clear()
	game.query.set_blocks(&"rooms", [] as Array[Vector3])
	game.remove_meta(SaveCore.META_OUTSIDE)
	var inner := game.view
	game.remove_child(inner)
	inner.queue_free()
	game.add_child(_outside_view)
	_outside_view.reclaim()
	game.view = _outside_view
	realms.call(&"enter", _outside, _outside_key, t.door + t.out * 0.3, true, _outside_query)
	game.camera.view_height = _outside_height
	pocket = null
	model = null
	_view = null
	_model = null
	_outside = null
	_outside_view = null
	_outside_query = null


func _realms() -> Node:
	for s in game.systems:
		if s.has_method(&"enter") and s.has_method(&"use_spent"):
			return s
	return null


## The walls as the query's blocks: a circle every half tile along every edge
## but the doorways, so a wall stops a body and a doorway lets it through.
static func _walls(l: InteriorLayout) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for e: Dictionary in l.edges:
		if e.kind == &"door" or e.kind == &"inner":
			continue
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		for k in 3:
			var p := a.lerp(b, float(k) / 2.0)
			out.append(Vector3(p.x, p.y, 0.3))
	# The chimney breast stands out from its wall.
	var c := l.hearth + l.hearth_wall * 0.35
	out.append(Vector3(c.x, c.y, 0.55))
	return out


# --- light through the windows -------------------------------------------------

func _make_lights() -> void:
	for w: Array in _windows:
		var sky := SpotLight3D.new()
		sky.spot_range = 5.0
		sky.spot_angle = 55.0
		sky.shadow_enabled = false
		sky.light_energy = 0.0
		game.view.add_child(sky)
		_lights.append(sky)
		var sun := SpotLight3D.new()
		sun.spot_range = 6.0
		sun.spot_angle = 16.0
		sun.spot_attenuation = 0.4
		sun.shadow_enabled = true
		sun.light_energy = 0.0
		game.view.add_child(sun)
		_lights.append(sun)


## THE HOUR COMES IN THROUGH THE WINDOWS. A cottage's lid is under the line where
## the sun stops casting (InteriorKind.closed), so the ceiling and the walls shade
## the room. But the game's sun is steep on purpose (SkyLight: it never drops
## below about sixty degrees, for the length of a shadow on screen), and through
## a window in a wall 0.22 thick its patch lands under the sill, where nobody sees
## it. So each window keeps a sun of its own on the sun's BEARING, at `SUN_LOW`,
## lit only while the sun is on that side of the house: the patch walks across
## the boards with the hour and goes when the sun goes round. Beside it, the SKY's
## light, a soft fill off each window, and the sky itself seen in it.
func _light_windows() -> void:
	if game.sky == null or game.sky.sun == null:
		return
	var sun: DirectionalLight3D = game.sky.sun
	var day := clampf(sun.light_energy, 0.0, 1.0)
	var hor := Color(0.62, 0.7, 0.8)
	var env: WorldEnvironment = game.sky.env
	if env != null and env.environment != null and env.environment.sky != null:
		var sm := env.environment.sky.sky_material as ProceduralSkyMaterial
		if sm != null:
			hor = sm.sky_horizon_color
	if model != null:
		model.call(&"daylight", Color(hor.r, hor.g, hor.b) * lerpf(0.18, 1.15, day))
	for i in _windows.size():
		var at: Vector3 = _windows[i][0]
		var inward2: Vector2 = _windows[i][1]
		var inward := Vector3(inward2.x, 0.0, inward2.y)
		var travel := -sun.global_transform.basis.z
		var flat := Vector3(travel.x, 0.0, travel.z)
		var facing := 0.0
		if flat.length() > 0.01:
			flat = flat.normalized()
			facing = maxf(0.0, flat.dot(inward))
		var beam := (flat + Vector3.DOWN * SUN_LOW).normalized()
		var sp := _lights[i * 2 + 1] as SpotLight3D
		# Stood outside the wall and under the eaves, so the ceiling does not
		# shadow its own window's sun and the opening cuts the patch square.
		sp.global_position = at - beam * 1.5
		_aim(sp, beam)
		sp.light_color = sun.light_color
		sp.light_energy = SUN_IN * sun.light_energy * smoothstep(0.0, 0.35, facing)
		sp.visible = sp.light_energy > 0.01
		var fill := _lights[i * 2] as SpotLight3D
		var down := (inward + Vector3.DOWN * 0.45).normalized()
		fill.global_position = at - down * 1.2
		_aim(fill, down)
		fill.light_color = hor.lerp(Color(0.78, 0.84, 1.0), 0.5)
		fill.light_energy = SKY_IN * lerpf(0.15, 1.0, day)


static func _aim(l: Node3D, dir: Vector3) -> void:
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	l.look_at(l.global_position + dir, up)


# --- the cover -----------------------------------------------------------------

## From above, an iris closing on the doorway; over the shoulder, a blink as the
## eye passes the jamb. Either way the swap happens under full cover.
func _cover_close(at: Vector2) -> void:
	_swapping = true
	_cover.visible = true
	var cam := game.camera
	var over := cam.shoulder_share() > 0.5
	var p := cam.unproject_position(Vector3(at.x, game.player.position.y + 1.0, at.y))
	var size := get_viewport().get_visible_rect().size
	_cover_mat.set_shader_parameter(&"centre", Vector2(p.x / maxf(size.x, 1.0), p.y / maxf(size.y, 1.0)))
	_cover_mat.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))
	var tw := create_tween()
	_cover_mat.set_shader_parameter(&"radius", 1.6)
	tw.tween_method(func(r: float) -> void: _cover_mat.set_shader_parameter(&"radius", r), 1.6, 0.0, BLINK if over else CLOSE)
	await tw.finished


func _cover_open() -> void:
	var over := game.camera.shoulder_share() > 0.5
	var size := get_viewport().get_visible_rect().size
	var p := game.camera.unproject_position(game.player.position + Vector3(0, 1.0, 0))
	_cover_mat.set_shader_parameter(&"centre", Vector2(p.x / maxf(size.x, 1.0), p.y / maxf(size.y, 1.0)))
	var tw := create_tween()
	tw.tween_method(func(r: float) -> void: _cover_mat.set_shader_parameter(&"radius", r), 0.0, 1.6, BLINK * 2.0 if over else OPEN)
	await tw.finished
	_cover.visible = false
	_swapping = false


static func _iris() -> Shader:
	var s := Shader.new()
	s.code = """shader_type canvas_item;
uniform vec2 centre = vec2(0.5);
uniform float radius = 1.6;
uniform float aspect = 1.7778;
void fragment() {
	vec2 d = (UV - centre) * vec2(aspect, 1.0);
	float edge = smoothstep(radius, radius + 0.012, length(d));
	COLOR = vec4(0.018, 0.016, 0.02, edge);
}
"""
	return s


# --- what a tour may ask, and where it may stand -------------------------------

func tour_seen(what: StringName) -> bool:
	match what:
		&"door":
			return door_near != null
		&"inside":
			return pocket != null and not _swapping
		&"outside":
			return pocket == null and not _swapping and game.world.realm != Realm.INTERIOR
	if String(what).begins_with("inside:"):
		return pocket != null and not _swapping and String(pocket.kind.id) == String(what).substr(7)
	return false


## The names `tour_place` answers (tests/tours/test_tour_claims reads this).
const TOUR_PLACES: Array[String] = ["door:house", "door"]


## `at door:house`: just outside the nearest door of that host, facing it -- or,
## inside, just inside the room's own door, facing out.
func tour_place(what: String) -> Vector2:
	if what != "door:house" and what != "door":
		return Vector2.INF
	if pocket != null:
		return pocket.layout.door - pocket.layout.door_out * 0.5
	var best: Threshold = null
	var bd := INF
	for t: Threshold in doors:
		var d := t.door.distance_squared_to(game.player.pos)
		if d < bd:
			bd = d
			best = t
	if best == null:
		return Vector2.INF
	return best.door + best.out * 0.5


func tour_face(what: String) -> float:
	if what != "door:house" and what != "door":
		return NAN
	if pocket != null:
		return pocket.layout.door_out.angle()
	var p := tour_place(what)
	for t: Threshold in doors:
		if t.door.distance_to(p - t.out * 0.5) < 0.01:
			return (-t.out).angle()
	return NAN


## A crossing into another realm is another island with its own doors; a door's
## own crossing is this system's, and the doors outside stay as they were.
func realm_changed(from: StringName, to: StringName) -> void:
	if Realm.is_pocket(from) or Realm.is_pocket(to):
		return
	_drop_grown()
	doors = Interiors.thresholds(game.world)


## A SAVE MADE INSIDE (20_realms `started`): the game opened on the world outside,
## the player where they stood inside. The door is found again by its key, the
## pocket grown again from it, and gone into with no cover: this is the first
## frame, nothing to hide.
func reenter(key: StringName, at: Vector2) -> void:
	var door_key := String(key).trim_prefix(Realm.POCKET)
	var t := Interiors.by_key(game.world, door_key)
	if t == null:
		push_warning("doors: no door %s on this island; staying outside" % door_key)
		return
	_begin(t)
	if _grown == null:
		return
	_swap_in()
	var realms := _realms()
	# Where the save was made, not the doorway.
	game.player.pos = at
	if game.player.hero != null:
		game.player.hero.pos = at
	game.player.sync_view(0.0)
	if game.camera != null:
		game.camera.snap_to(game.player.position)
	realms.set("_settle", 0.0)
