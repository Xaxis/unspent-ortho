class_name WorldProp
extends RefCounted
## One placed static thing: a tree, a rock, an ore node, a house.

var id: int
var kind: int
## Centre in tiles.
var pos: Vector2
## Radians about the vertical axis.
var rot: float
var scale: float
## Collision radius in tiles (already scaled). 0 = passable.
var solid: float
## Which model of this kind, or -1 to take the one its id hashes to. World gen
## sets it where the ARRANGEMENT matters and chance is not good enough: a village
## deals its houses one variant each so no two silhouettes in it repeat.
var variant := -1
## How much of it is still there, 1 whole down to 0 (Harvest.shown). Taking from a
## thing that the taking CONSUMES works it down: the drawing reads this, and so
## does what stops a body. Not saved — `SaveCore` puts the takes back and the rule
## works it out again.
var shown := 1.0


func _init(p_id: int, p_kind: int, p_pos: Vector2, p_rot: float, p_scale: float) -> void:
	id = p_id
	kind = p_kind
	pos = p_pos
	rot = p_rot
	scale = p_scale
	solid = PropKind.SOLID[kind] * scale
