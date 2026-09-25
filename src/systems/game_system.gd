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


## What a system that keeps the OUTSIDE does at a door (20_realms calls a
## system's `indoors(inside)` through a door instead of `realm_changed`, and says
## why there). This is the common half: stop processing, and hide what was drawn
## -- `layers` and this system's own 3D children -- putting back exactly what was
## showing, so a thing hidden on purpose before the door stays hidden after it.
var _hid_indoors: Array[Node3D] = []


func sleep_indoors(inside: bool, layers: Array[Node3D] = []) -> void:
	set_process(not inside)
	set_physics_process(not inside)
	if not inside:
		for n: Node3D in _hid_indoors:
			if is_instance_valid(n):
				n.visible = true
		_hid_indoors.clear()
		return
	var all: Array[Node3D] = layers.duplicate()
	for c: Node in get_children():
		if c is Node3D:
			all.append(c as Node3D)
	for n: Node3D in all:
		if n != null and n.visible:
			n.visible = false
			_hid_indoors.append(n)
