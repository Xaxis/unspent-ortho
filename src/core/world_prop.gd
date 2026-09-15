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


func _init(p_id: int, p_kind: int, p_pos: Vector2, p_rot: float, p_scale: float) -> void:
	id = p_id
	kind = p_kind
	pos = p_pos
	rot = p_rot
	scale = p_scale
	solid = PropKind.SOLID[kind] * scale
