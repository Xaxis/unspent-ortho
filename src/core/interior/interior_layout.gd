class_name InteriorLayout
extends RefCounted
## Where everything inside a pocket is, in the POCKET's tile space: pure data,
## laid by a recipe and turned into place by InteriorGen, then read by the world
## it grows, the walls a system hands the query and the model that draws it.

## Rooms, as tile rectangles.
var rooms: Array[Rect2i] = []
## The unit edges walls stand on: {a, b, out (the normal out of the room it
## bounds), kind (&"wall", &"window", &"door", &"inner"), inner (between rooms)}.
## A &"door" is the way in and out; an &"inner" edge between rooms is a doorway.
var edges: Array[Dictionary] = []
## The entry doorway: its middle on the wall line, and the way out through it.
var door := Vector2.ZERO
var door_out := Vector2(0, 1)
## The hearth (a FIRE stands here, against `hearth_wall`) and the table.
var hearth := Vector2.ZERO
var hearth_wall := Vector2(0, -1)
var table := Vector2.ZERO
## How big the pocket is: every room inside it, a tile of nothing round them.
var size := 0
## Which plan the rooms were laid to and which household lives in them: two
## deals off the door's own hash, so no two neighbours share a room.
var plan: StringName = &""
var dressing: StringName = &""
## What stands in the rooms and hangs on their walls, as data: {kind, at (tile
## space), face (the way it looks, into the room), solid (the radius a body is
## stopped at; 0 for a thing on a wall or underfoot)}. The recipe says where;
## the model says what it looks like.
var things: Array[Dictionary] = []
## The ways people walk every day, as [from, to] pairs: the boards along them
## are worn pale.
var walks: Array[PackedVector2Array] = []


## Where a player stands on coming in: a stride inside the doorway.
func inside() -> Vector2:
	return door - door_out * 0.9


## Whether a tile is floor.
func is_floor(x: int, y: int) -> bool:
	for r: Rect2i in rooms:
		if r.has_point(Vector2i(x, y)):
			return true
	return false
