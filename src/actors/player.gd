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
var _z := 0.0
## Real-time msec until which a hit flash shows (real time, so a held shot still lets it go).
var _flash_until := 0
var _shudder_left := 0.0
var _arc: MeshInstance3D
var _arc_blow: Blow
var _arc_mat: ShaderMaterial
var _flashing := false


func setup(w: WorldData, q: WorldQuery, at: Vector2, material: Material) -> void:
	world = w
	query = q
	pos = at
	_z = w.height_at(at)
	model = PersonModel.new()
	model.name = "model"
	add_child(model)
	model.build(material)
	_sync(0.0)


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


## After the simulation stepped: take the hero's place and draw it. `frozen` holds the pose (hitstop).
func sync_view(delta: float, frozen: bool = false) -> void:
	if hero != null:
		pos = hero.pos
		facing = hero.facing
		speed = hero.speed
	_sync(0.0 if frozen else delta)


## The swing's stroke, from the hero's blow at simulation time `now_ms`: it
## sweeps across the blow box through the live window, then its tail catches up
## with its head and it is gone.
func draw_swing(now_ms: float) -> void:
	var b := hero.blow if hero != null else null
	var e := now_ms - hero.blow_at if b != null else -1.0
	var from := (b.windup - 20.0) if b != null else 0.0
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
		_arc.mesh = MobFx.swing_mesh(hero.radius + b.reach, b.width)
	_arc.visible = true
	var head := clampf((e - from) / (b.active + 40.0), 0.0, 1.0)
	var tail := 0.8 * (1.0 - clampf((e - b.windup - b.active - 20.0) / 80.0, 0.0, 1.0))
	_arc_mat.set_shader_parameter(&"head", head)
	_arc_mat.set_shader_parameter(&"tail", minf(tail, head + 0.001))
	_arc.position = Vector3(0, 0.5, 0)
	_arc.rotation = Vector3(0, -hero.facing, 0)


## A hit landed on this body: a short bright flash.
func flash(seconds: float = 0.07) -> void:
	_flash_until = Time.get_ticks_msec() + int(seconds * 1000.0)


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
	position = Vector3(pos.x, _z + lift, pos.y)
	if model:
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
		if delta > 0.0:
			model.animate(speed, delta)
	var flashing := Time.get_ticks_msec() < _flash_until
	if flashing != _flashing and model != null:
		_flashing = flashing
		MobFx.set_flash(model, flashing)


## Screen-relative input to world-space intent for a camera at yaw_deg.
## Screen up is away from the camera.
static func screen_to_world(input: Vector2, yaw_deg: float) -> Vector2:
	# Camera yaw 45 looks north-west: screen up = (-1,-1)/sqrt2, screen right = (1,-1)/sqrt2.
	var yaw := deg_to_rad(yaw_deg)
	var up := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	return right * input.x + up * -input.y
