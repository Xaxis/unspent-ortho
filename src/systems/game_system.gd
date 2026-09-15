class_name GameSystem
extends Node
## A self-contained piece of the running game (weather, mobs, needs, HUD,
## audio...). Game instantiates every script in res://src/systems/ whose file
## name starts with two digits, in file-name order, and calls setup(game).
## Adding a system never requires editing game.gd.
##
##   10_*  world and sky      30_* actors and mobs    50_* player systems
##   70_*  audio              90_* ui
##
## Systems talk through Events and through game's public fields, never by
## finding each other's nodes.

var game: Game


## Called once, after the world, player, camera and view exist.
func setup(_game: Game) -> void:
	game = _game


## Called once, after every system's setup and before the first frame is drawn:
## the moment a loaded game is applied (05_save), so nothing a later setup does
## overwrites it.
func started() -> void:
	pass
