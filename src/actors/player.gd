class_name Player
extends Node3D
## The player in the world. Position lives in tile space (`pos`); the node's 3D
## transform is derived from it every frame. Movement is `drive()`, which takes
## an intent in WORLD space so tests and bots can call it without input devices.

var world: WorldData
var query: WorldQuery
## Tile-space position.
var pos := Vector2.ZERO
## Radians. 0 = east (+x), PI/2 = south (+y).
var facing := PI * 0.5
## Tiles per second actually moved last step.
var speed := 0.0
var model: PersonModel
var _z := 0.0


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
	var g := world.ground_at(floori(pos.x), floori(pos.y))
	var s := Tuning.RUN_SPEED if run else Tuning.WALK_SPEED
	if g == Ground.WATER:
		s *= Tuning.WADE_FACTOR
	var before := pos
	if move.length() > 0.01:
		pos = query.move_body(pos, move * s * delta, Tuning.PLAYER_RADIUS)
		facing = move.angle()
	speed = before.distance_to(pos) / maxf(delta, 1e-5)
	_sync(delta)


func _sync(delta: float) -> void:
	var target := world.height_at(pos)
	_z = target if delta == 0.0 else lerpf(_z, target, 1.0 - exp(-14.0 * delta))
	position = Vector3(pos.x, _z, pos.y)
	if model:
		model.rotation.y = -facing
		model.animate(speed, delta)


## Screen-relative input to world-space intent for a camera at yaw_deg.
## Screen up is away from the camera.
static func screen_to_world(input: Vector2, yaw_deg: float) -> Vector2:
	# Camera yaw 45 looks north-west: screen up = (-1,-1)/sqrt2, screen right = (1,-1)/sqrt2.
	var yaw := deg_to_rad(yaw_deg)
	var up := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	return right * input.x + up * -input.y
