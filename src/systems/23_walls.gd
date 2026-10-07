extends GameSystem
## What a walled prop stops a body with is its drawn walls (PropWalls), made by
## WorldQuery a cell at a time from the world as it stands. This tells the query
## when one of them falls, is taken or comes back, so the cells holding walls are
## made again as they are next asked about.
##
## Only a walled prop's change moves a wall: a take of anything else (a reed, a
## log) leaves every cell as it was, and a room's way out comes back to a query
## whose walls are still made.

## The walled props of the world last watched, by prop id, and how many were down.
var _ids := PackedInt32Array()
var _of := 0
var _fallen := 0


func setup(g: Game) -> void:
	super.setup(g)
	_watch()
	Events.took.connect(_on_took)
	# A walker's foot crushes the ruins in its craters once every system is set
	# up (19_colossi.started), and a ruin crushed kept walls nobody could see.
	Events.fell.connect(_on_fell)


func _exit_tree() -> void:
	if Events.took.is_connected(_on_took):
		Events.took.disconnect(_on_took)
	if Events.fell.is_connected(_on_fell):
		Events.fell.disconnect(_on_fell)


func _watch() -> void:
	if game == null or game.world == null:
		return
	_of = game.world.get_instance_id()
	_ids = PropWalls.ids_of(game.world)
	_fallen = _count_fallen()


func _count_fallen() -> int:
	# A keyed lookup per walled prop, never the world's taken list walked or held.
	var n := 0
	for id in _ids:
		if game.world.depleted.has(id):
			n += 1
	return n


func _on_took(_item: StringName, _count: int) -> void:
	_on_fell()


func _on_fell() -> void:
	if game == null or game.world == null or game.query == null:
		return
	if game.world.get_instance_id() != _of:
		_watch()
	var now := _count_fallen()
	if now != _fallen:
		_fallen = now
		game.query.walls_changed()


func realm_changed(_from: StringName, _to: StringName) -> void:
	_watch()
