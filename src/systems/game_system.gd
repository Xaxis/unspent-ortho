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


## Spend the latch behind `what`, if this system keeps one: an `await` means
## SINCE I LAST ASKED, and only the runner knows when a tour asked. 98_tour calls
## this on every system the moment an await or an until is answered, beside the
## erase of its own `_seen`.
##
## A latch IS the declaration that a key is an EVENT. So a system that computes
## every answer from the live world overrides nothing and changes not at all,
## and a system that latches spends the latch here — otherwise the first theft of
## a run answers every `await theft` after it, which is how machine-read.tour
## pressed `use` once where a survey post needs three, robbed nothing, turned no
## machine, and reported green for two waves.
func tour_forget(_what: StringName) -> void:
	pass
