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
## The pocket's own props, which the world it grows holds: {kind (PropKind),
## at, face}. A cottage's hearth is a FIRE and its table a BENCH; a hall's crates
## are what it guards. Declared by the recipe, placed by InteriorGen in order, so
## a prop's id (and the saved edits keyed on it) is the recipe's to keep.
var props: Array[Dictionary] = []
## Who is in it: {role (&"warden" keeps it, &"guard" walks it), at, face}. The
## recipe says where they stand; what body each role is, the door decides from
## the land the host stands in (21_doors), because a recipe knows no landscape.
var residents: Array[Dictionary] = []
## Where words can be found (docs/STORY.md fills them): {slot (&"desk",
## &"terminal", &"wall"), at, face}. A recipe says where; the story says what.
var slots: Array[Dictionary] = []
## The ways people walk every day, as [from, to] pairs: the boards along them
## are worn pale.
var walks: Array[PackedVector2Array] = []


## Whether there is a hearth at `hearth` (a chimney breast the walls stand out
## from). A machines' hall has none.
var has_hearth := true


## Every unit edge of every room as a plain wall; one shared by two rooms is an
## inner wall. A recipe then says which are doors, doorways and windows.
func lay_edges() -> void:
	var seen := {}
	for r: Rect2i in rooms:
		for x in range(r.position.x, r.end.x):
			_edge(seen, Vector2(x, r.position.y), Vector2(x + 1, r.position.y), Vector2(0, -1))
			_edge(seen, Vector2(x, r.end.y), Vector2(x + 1, r.end.y), Vector2(0, 1))
		for y in range(r.position.y, r.end.y):
			_edge(seen, Vector2(r.position.x, y), Vector2(r.position.x, y + 1), Vector2(-1, 0))
			_edge(seen, Vector2(r.end.x, y), Vector2(r.end.x, y + 1), Vector2(1, 0))


func _edge(seen: Dictionary, a: Vector2, b: Vector2, out: Vector2) -> void:
	var k := "%d,%d,%d,%d" % [int(a.x * 2), int(a.y * 2), int(b.x * 2), int(b.y * 2)]
	if seen.has(k):
		(seen[k] as Dictionary).inner = true
		return
	var e := {"a": a, "b": b, "out": out, "kind": &"wall", "inner": false}
	seen[k] = e
	edges.append(e)


## Where a player stands on coming in: well inside the doorway. Far enough that
## the shoulder camera's eye, which is never let nearer the head than
## Shoulder.LEAST_BACK, has room behind them inside the room: at a stride in, it
## was pushed out through the doorway and the first frame over the shoulder was
## the backs of the walls against the sky.
func inside() -> Vector2:
	return door - door_out * 1.6


## Whether a tile is floor.
func is_floor(x: int, y: int) -> bool:
	for r: Rect2i in rooms:
		if r.has_point(Vector2i(x, y)):
			return true
	return false
