extends GameSystem
## A ruin's walls stop a body (RuinWalls): every standing ruin in the world
## handed to WorldQuery as the circles along its walls, for the whole island
## like the landmarks' mass.
##
## THE WALLS ARE STAMPED ONCE PER QUERY AND WORLD, and again only when a ruin
## falls. An island holds thousands of ruins and tens of thousands of circles,
## and restamping them on every take and every realm crossing cost a room's
## way out 1.5 s (test_doors): the outside's query comes back from a room with
## its walls still stamped, and a take that was not a ruin changes none of them.

## Which world's walls each query carries: query instance id -> world instance id.
var _stamped := {}
## The ruins of the world last stamped, by prop id, and how many had fallen.
var _ruin_ids := PackedInt32Array()
var _ruins_of := 0
var _fallen := 0


func setup(g: Game) -> void:
	super.setup(g)
	_set_walls(true)
	Events.took.connect(_on_took)


func _exit_tree() -> void:
	if Events.took.is_connected(_on_took):
		Events.took.disconnect(_on_took)


func _set_walls(force: bool) -> void:
	if game == null or game.query == null or game.world == null:
		return
	var q := game.query.get_instance_id()
	var wid := game.world.get_instance_id()
	if not force and int(_stamped.get(q, 0)) == wid:
		return
	game.query.set_blocks(&"ruins", RuinWalls.of_world(game.world))
	_stamped[q] = wid
	_ruins_of = wid
	_ruin_ids = RuinWalls.ids_of(game.world)
	_fallen = _count_fallen()


func _count_fallen() -> int:
	# A keyed lookup per ruin, never the world's taken list walked or held.
	var n := 0
	for id in _ruin_ids:
		if game.world.depleted.has(id):
			n += 1
	return n


func _on_took(_item: StringName, _count: int) -> void:
	if game == null or game.world == null or game.world.get_instance_id() != _ruins_of:
		return
	# Only a ruin brought down moves a wall.
	if _count_fallen() != _fallen:
		_set_walls(true)


func realm_changed(_from: StringName, _to: StringName) -> void:
	_set_walls(false)
