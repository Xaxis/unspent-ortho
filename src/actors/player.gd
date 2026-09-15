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
var _z := 0.0
var _mat: ShaderMaterial
## Real-time msec until which a hit flash shows (real time, so a held shot still lets it go).
var _flash_until := 0
var _shudder_left := 0.0
var _arc: MeshInstance3D
var _arc_blow: Blow


func setup(w: WorldData, q: WorldQuery, at: Vector2, material: Material) -> void:
	world = w
	query = q
	pos = at
	_z = w.height_at(at)
	# Its own copy of the lit material so a hurt can flash this body and nothing else.
	var mat: Material = material
	if material is ShaderMaterial:
		_mat = (material as ShaderMaterial).duplicate() as ShaderMaterial
		mat = _mat
	model = PersonModel.new()
	model.name = "model"
	add_child(model)
	model.build(mat)
	_sync(0.0)


## move: desired direction in world tile space, length <= 1.
func drive(move: Vector2, run: bool, delta: float) -> void:
	if move.length() > 1.0:
		move = move.normalized()
	intent_move = move
	intent_run = run
	if hero != null:
		return
	var s := Hero.ground_speed(world, pos, run)
	var before := pos
	if move.length() > 0.01:
		pos = query.move_body(pos, move * s * delta, Tuning.PLAYER_RADIUS)
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


## The swing's smear, from the hero's blow at simulation time `now_ms`: it
## shows just before the box is live and sweeps out through it, then thins away.
func draw_swing(now_ms: float) -> void:
	var b := hero.blow if hero != null else null
	var e := now_ms - hero.blow_at if b != null else -1.0
	var from := (b.windup - 30.0) if b != null else 0.0
	var to := (b.windup + b.active + 80.0) if b != null else 0.0
	if b == null or e < from or e > to:
		if _arc != null:
			_arc.visible = false
		return
	if _arc == null:
		_arc = MeshInstance3D.new()
		_arc.name = "swing"
		_arc.material_override = MobFx.glow_material()
		_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_arc)
	if _arc_blow != b:
		_arc_blow = b
		_arc.mesh = MobFx.smear_mesh(hero.radius + b.reach, b.width, Palette.LINEN[5])
	_arc.visible = true
	var k := clampf((e - from) / maxf(1.0, to - from), 0.0, 1.0)
	_arc.position = Vector3(0, 0.55, 0)
	_arc.rotation = Vector3(0, -hero.facing, 0)
	# Sweep out over the first half, thin to nothing over the second.
	var sweep := minf(1.0, k * 2.2)
	var thin := 1.0 if k < 0.55 else lerpf(1.0, 0.1, (k - 0.55) / 0.45)
	_arc.scale = Vector3(lerpf(0.55, 1.0, sweep), thin, lerpf(0.15, 1.0, sweep))


## A hit landed on this body: a short bright flash.
func flash(seconds: float = 0.07) -> void:
	_flash_until = Time.get_ticks_msec() + int(seconds * 1000.0)


## Something has hold: the figure shudders against it.
func shudder(seconds: float = 0.12) -> void:
	_shudder_left = seconds


func _sync(delta: float) -> void:
	var target := world.height_at(pos)
	_z = target if delta == 0.0 else lerpf(_z, target, 1.0 - exp(-14.0 * delta))
	position = Vector3(pos.x, _z, pos.y)
	if model:
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
	if _mat != null:
		_mat.set_shader_parameter(&"emission_strength", 0.7 if Time.get_ticks_msec() < _flash_until else 0.0)


## Screen-relative input to world-space intent for a camera at yaw_deg.
## Screen up is away from the camera.
static func screen_to_world(input: Vector2, yaw_deg: float) -> Vector2:
	# Camera yaw 45 looks north-west: screen up = (-1,-1)/sqrt2, screen right = (1,-1)/sqrt2.
	var yaw := deg_to_rad(yaw_deg)
	var up := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	return right * input.x + up * -input.y
