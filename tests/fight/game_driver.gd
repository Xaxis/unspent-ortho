extends RefCounted
## A reader (tests/fight/reader.gd and its kin) playing a RUNNING game: each
## physics frame it decides as it does in a bare simulation, and its walk goes
## in through the game's own input path (Game.scripted_move, as keys on the
## screen: LockOn.keys_for), so the ground, the camera and 40_fight's copy of the
## intent all stand between its hands and the body, as they do for a player. Its
## swing and dodge are taps of the real actions (TourHands).
##
##   var d := GameDriver.new(game, PlateReader.new(game.player.sim))
##   while ...: d.step(); await tree.physics_frame

const Shoulder := preload("res://src/core/view/shoulder.gd")

var game: Game
var reader: Variant


var hands := TourHands.new()
## Holds the target key throughout, as a player in a boss fight does: the lock
## is 42_target's, taken from the key like any other.
var locked := false


func _init(g: Game, r: Variant) -> void:
	game = g
	reader = r
	reader.hands = hands


func step() -> void:
	var hero := game.player.sim.hero
	hands.step()
	if locked and not Input.is_action_pressed(&"target"):
		Input.action_press(&"target")
	reader.act()
	_look(hero)
	var dir := hero.move
	game.scripted_move = LockOn.keys_for(dir.normalized() if dir.length() > 0.01 else Vector2.ZERO,
		game.camera.yaw_now(), game.player.pos, hero.lock, game.camera.shoulder) * minf(1.0, dir.length())
	game.scripted_run = hero.run
	game.scripted_seconds = 0.05


## Lets go of every key the driver holds.
func release() -> void:
	hands.release_all()
	if locked:
		Input.action_release(&"target")


## Over the shoulder a swing goes where the view looks (CameraRig.aim), so a
## player turns the view onto what they mean to hit with the mouse: the reader's
## facing, as motion of the real pointer (41_shoulder). A lock owns the turn.
func _look(hero: Hero) -> void:
	var cam := game.camera
	if not cam.shoulder or LockOn.locked(hero.lock):
		return
	var turn: float = Shoulder.turn(cam.shoulder_yaw, Shoulder.yaw_along(Vector2.from_angle(hero.facing)))
	if absf(turn) < 0.5:
		return
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(-turn / Shoulder.MOUSE_DEG, 0.0)
	e.screen_relative = e.relative
	Input.parse_input_event(e)
	Input.flush_buffered_events()
