class_name AbilityCtx
extends RefCounted
## What an ability is handed when it fires: the running game, the moment, and
## two doors back out. Nothing else. An ability never touches a node: it asks
## for a move (`motion`) and for a mark to be drawn (`draw`), and the gear
## system (src/systems/54_gear.gd) does both. That is what makes the five of
## them testable headless.

var game: Game
## Real seconds (Time.get_ticks_msec() / 1000), the clock cooldowns run on.
var now := 0.0
var delta := 0.0
## Set by an ability that takes the body somewhere; the system runs it.
var motion: AbilityMotion = null
## The system's hand: draw.call(what: StringName, args: Dictionary).
var fx := Callable()


func body() -> Body:
	return game.body if game != null else null


func pos() -> Vector2:
	return game.player.pos if game != null and game.player != null else Vector2.ZERO


func facing() -> float:
	return game.player.facing if game != null and game.player != null else 0.0


## Where the body is heading, or where it faces if it is standing still.
func heading() -> Vector2:
	if game == null or game.player == null:
		return Vector2.RIGHT
	var m: Vector2 = game.player.intent_move
	return m.normalized() if m.length() > 0.05 else Vector2.from_angle(game.player.facing)


## World minutes (the clock abilities that last a while are measured on).
func minutes() -> float:
	return game.clock.minutes if game != null and game.clock != null else 0.0


func draw(what: StringName, args: Dictionary = {}) -> void:
	if fx.is_valid():
		fx.call(what, args)
