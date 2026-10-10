class_name Player
extends Node3D
## The player in the world. Position lives in tile space (`pos`); the node's 3D
## transform is derived from it every frame. Movement is `drive()`, which takes
## an intent in WORLD space so tests and bots can call it without input devices.
##
## In a running game a FightSim (`hero`) owns the body: drive() only records the
## intent and the fight system steps the simulation in fixed slices, then calls
## sync_view(). Without one (tests, tools) drive() moves the player itself.

var world: WorldData
var query: WorldQuery
## Tile-space position.
var pos := Vector2.ZERO
## Radians. 0 = east (+x), PI/2 = south (+y).
var facing := PI * 0.5
## Tiles per second actually moved last step.
var speed := 0.0
var model: PersonModel
## The fight body, when a simulation drives this player, and that simulation
## (every body near the player lives in it; the mobs and fight systems share it here).
var hero: Hero = null
var sim: FightSim = null
var intent_move := Vector2.ZERO
var intent_run := false
## Height above the ground held by an ability (a glide, a grapple's arc) or by
## the deck of a craft under the body. Two writers, and they cannot disagree:
## the gear package (54_gear) writes it every frame a motion runs and puts it
## back to 0 when the body lands, the crafts package (44_crafts) writes it every
## frame a craft carries the body, and 54 runs after 44.
var lift := 0.0
## The craft carrying this body (src/core/craft/), or null on foot. In a running
## game the hero's own `ride` is what the simulation moves by; this is the same
## craft, for the tests and tools where no simulation owns the body. The crafts
## package (src/systems/44_crafts.gd) is the only writer.
var ride: CraftRide = null
## OFF THE LAND ALTOGETHER, up a walker's leg (43_climb, the only writer): the
## figure is drawn where the climb hangs it, in world space, placed by the climb
## the same frame as the leg it hangs from, and the climb puts this node with it,
## so what is seen and heard of him (his lamp, his breath, his sounds) is up
## there too. `pos`, the fight body and `on_land` stay where it left the ground.
## Nothing below has him while he hangs: the machines' senses read him as gone
## (Moment.aloft), so one that had him loses him and goes back to its rounds, and
## none lands a blow on the body he left at the foot.
var hanging := false:
	set(v):
		hanging = v
		if model != null:
			model.top_level = v
var _z := 0.0
## Real-time msec until which a hit flash shows (real time, so a held shot still lets it go).
var _flash_until := 0
## Where in the world the blow landed, so the flash is made of light and not of
## paper (see `flash`). Mobs have carried this since machines flashed by part.
var _flash_at := Vector3.ZERO
## Half a body up: what "the whole of you" means to a flash with no point.
const FLASH_MID := 0.85
## How much of a body one flash covers when nothing says where it was struck.
const FLASH_WHOLE := 1.4
var _shudder_left := 0.0
var _arc: MeshInstance3D
var _arc_blow: Blow
var _arc_mat: ShaderMaterial
var _flashing := false


func setup(w: WorldData, q: WorldQuery, at: Vector2, material: Material) -> void:
	world = w
	query = q
	pos = q.stand_at(at, Tuning.PLAYER_RADIUS, ride, true, FightSim.HERO_TALL)
	_z = w.height_at(pos)
	model = PersonModel.new()
	model.name = "model"
	add_child(model)
	model.build(material)
	_sync(0.0)


## PUT THE BODY DOWN at `at` (or the nearest spot it stands whole on:
## WorldQuery.stand_at) and say where. Every path that places the player rather
## than walks it -- a load, a door, a warp, a respawn, the hours going by, a
## pad's edge, a tour or dev jump -- comes through here, so none can leave a
## corner on the step above, where the move refuses every step (tests/core/
## test_stand_at.gd reads the source for any that do not). The fight body owns
## the place in a running game, so it moves with the drawn one. `facing` NAN
## keeps the facing it had.
func place(at: Vector2, face: float = NAN) -> Vector2:
	var to := query.stand_at(at, Tuning.PLAYER_RADIUS, ride, true, FightSim.HERO_TALL)
	pos = to
	if not is_nan(face):
		facing = face
	if hero != null:
		hero.pos = to
		hero.move = Vector2.ZERO
		if not is_nan(face):
			hero.facing = face
	position = world.to_3d(to)
	return to


## move: desired direction in world tile space, length <= 1.
func drive(move: Vector2, run: bool, delta: float) -> void:
	if move.length() > 1.0:
		move = move.normalized()
	intent_move = move
	intent_run = run
	if hero != null:
		return
	var s := Hero.ground_speed(world, pos, run, 1.0, ride)
	var before := pos
	if move.length() > 0.01:
		pos = query.move_body(pos, move * s * delta, Tuning.PLAYER_RADIUS, ride, true)
		facing = move.angle()
	speed = before.distance_to(pos) / maxf(delta, 1e-5)
	_sync(delta)


## After the simulation stepped: take the hero's place, so what reads `pos` on
## the next step (the ground under it, the weather on it, a take in front of
## it) reads where the body is and not where it was last drawn.
func take_place() -> void:
	if hero != null:
		pos = hero.pos
		facing = hero.facing
		speed = hero.speed


## Take the hero's place and draw it. `frozen` holds the pose (hitstop).
func sync_view(delta: float, frozen: bool = false) -> void:
	take_place()
	_sync(0.0 if frozen else delta)


## The swing's stroke, from the hero's blow at simulation time `now_ms`: it
## sweeps across the blow box (MobFx.swing_mesh) through the live window, the
## head crossing it from the first live slice to the last, then its tail catches
## up with its head and it is gone.
func draw_swing(now_ms: float) -> void:
	var b := hero.blow if hero != null else null
	var e := now_ms - hero.blow_at if b != null else -1.0
	var from := float(b.windup) if b != null else 0.0
	var gone := (b.windup + b.active + 100.0) if b != null else 0.0
	if b == null or e < from or e > gone:
		if _arc != null:
			_arc.visible = false
		return
	if _arc == null:
		_arc = MeshInstance3D.new()
		_arc.name = "swing"
		_arc_mat = MobFx.swing_material()
		_arc.material_override = _arc_mat
		_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_arc)
	if _arc_blow != b:
		_arc_blow = b
		_arc.mesh = MobFx.swing_mesh(hero.radius, hero.radius + b.reach, b.width, _lands_from_here, b.sweep)
	_arc.visible = true
	var head := clampf((e - from) / maxf(float(b.active), 1.0), 0.0, 1.0)
	var tail := 0.8 * (1.0 - clampf((e - b.windup - b.active - 20.0) / 80.0, 0.0, 1.0))
	_arc_mat.set_shader_parameter(&"head", head)
	_arc_mat.set_shader_parameter(&"tail", minf(tail, head + 0.001))
	_arc.position = Vector3(0, 0.5, 0)
	_arc.rotation = Vector3(0, -hero.facing, 0)


## Whether a blow from where the hero stands lands on ground at `local` (along
## its facing, then across): not a ledge away (FightSim.meets_hero).
func _lands_from_here(local: Vector2) -> bool:
	return sim == null or sim.meets_hero(hero.pos + local.rotated(hero.facing))


## A hit landed on this body: a short bright flash.
##
## `at` is WHERE, in world space, and it is what keeps the flash made of light.
## Given a point, `MobFx.set_flash` writes `flash_at`/`flash_r` into a copy of
## the body's own material and the lit shaders answer with EMISSION over a black
## albedo (world.gdshader, found.gdshader) — the body stays the material it is
## and a part of it goes hot. Given nothing, it falls back to an unshaded paper
## silhouette from the ink era, which is what the player's flash has always been:
## `flash()` never took a point, so the one body the camera is always on was the
## one body still painted over. Vector3.INF means "no point": the whole body.
func flash(seconds: float = 0.07, at: Vector3 = Vector3.INF) -> void:
	_flash_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	_flash_at = at if at.is_finite() else model_centre()


## The middle of the body, for a flash nobody located: pressure and cold strike
## the whole of you, not a plate.
func model_centre() -> Vector3:
	return position + Vector3(0.0, FLASH_MID, 0.0)


## In water over the head, and not standing on something that floats: the gait
## is a stroke, the body is drawn at the waterline, and the slate's own rules
## about what a body may do from there are 40_fight's (Swim).
var swimming := false
var _wake_in := 0.0


## What the water does about a body in it: a ring off each stroke, drawn on the
## surface in the surf own broken white, and one where the body went in. The
## figure itself draws over the water whatever its depth (people are drawn after
## the outline pass), so the rings are what say it is IN the sea and not on it.
const WAKE_EVERY := 0.55
const WAKE_COLD := 3


func _wake(delta: float, was_swimming: bool) -> void:
	if not swimming:
		_wake_in = 0.0
		return
	var at := Vector3(pos.x, Swim.WATER_Y, pos.y)
	if not was_swimming:
		# Going in: a bigger ring, because that is the moment somebody hears.
		MobFx.ring(get_parent(), at, Palette.COLD[WAKE_COLD], 1.05, 0.45)
		Events.sfx.emit(&"splash", at)
	_wake_in -= delta
	if _wake_in > 0.0:
		return
	_wake_in = WAKE_EVERY
	MobFx.ring(get_parent(), at, Palette.COLD[WAKE_COLD], 0.62 + minf(speed, 2.0) * 0.12, 0.5)


## Something has hold: the figure shudders against it.
func shudder(seconds: float = 0.12) -> void:
	_shudder_left = seconds


func _sync(delta: float) -> void:
	var was_swimming := swimming
	swimming = ride == null and Swim.deep(world, pos)
	_wake(delta, was_swimming)
	var target := world.height_at(pos)
	_z = target if delta == 0.0 else lerpf(_z, target, 1.0 - exp(-14.0 * delta))
	if not hanging:
		position = on_land()
	if model and not hanging:
		model.swimming = swimming
		model.rotation.y = -facing
		model.position = Vector3.ZERO
		var held := hero != null and hero.held()
		# Held: pulled over toward the jaw, heels lifting.
		model.rotation.z = lerpf(model.rotation.z, -0.28 if held else 0.0, 1.0 if delta == 0.0 else 1.0 - exp(-18.0 * delta))
		if held:
			model.position.y = 0.05
		if _shudder_left > 0.0 or held:
			var t := Time.get_ticks_msec() * 0.001
			var k := 0.05 if _shudder_left > 0.0 else 0.02
			model.position += Vector3(sin(t * 91.0) * k, 0.0, cos(t * 77.0) * k)
	_shudder_left = maxf(0.0, _shudder_left - delta)
	if model and delta > 0.0:
		model.animate(0.0 if hanging else speed, delta)
	var flashing := Time.get_ticks_msec() < _flash_until
	if flashing != _flashing and model != null:
		_flashing = flashing
		MobFx.set_flash(model, flashing, _flash_at, FLASH_WHOLE)


## Where he is on the land: the node's own place, except up a walker's leg,
## where the node is with the figure and this stays where he left the ground.
func on_land() -> Vector3:
	return Vector3(pos.x, _z + lift, pos.y)


## Where he is heard from, in tile space: `pos`, except up a walker's leg, where
## it is under the figure.
func heard_at() -> Vector2:
	return Vector2(position.x, position.z) if hanging else pos


## Screen-relative input to world-space intent for a camera at yaw_deg.
## Screen up is away from the camera.
static func screen_to_world(input: Vector2, yaw_deg: float) -> Vector2:
	# Camera yaw 45 looks north-west: screen up = (-1,-1)/sqrt2, screen right = (1,-1)/sqrt2.
	var yaw := deg_to_rad(yaw_deg)
	var up := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	return right * input.x + up * -input.y
