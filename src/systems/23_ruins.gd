extends GameSystem
## A ruin's walls stop a body (RuinWalls): every standing ruin in the world
## handed to WorldQuery as the circles along its walls, for the whole island
## like the landmarks' mass.
##
## THE WALLS ARE SET ONCE PER QUERY AND WORLD, and again only when a ruin
## falls, and stamped a cell at a time (WorldQuery.set_blocks_by_cell). An
## island holds thousands of ruins and tens of thousands of circles, and
## restamping them on every take and every realm crossing cost a room's way out
## 1.5 s (test_doors): the outside's query comes back from a room with its walls
## still stamped, and a take that was not a ruin changes none of them.

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
	# A walker's foot crushes the ruins in its craters once every system is set
	# up (19_colossi.started), and a ruin crushed kept walls nobody could see.
	Events.fell.connect(_on_fell)


func _exit_tree() -> void:
	if Events.took.is_connected(_on_took):
		Events.took.disconnect(_on_took)
	if Events.fell.is_connected(_on_fell):
		Events.fell.disconnect(_on_fell)


func _set_walls(force: bool) -> void:
	if game == null or game.query == null or game.world == null:
		return
	var q := game.query.get_instance_id()
	var wid := game.world.get_instance_id()
	if not force and int(_stamped.get(q, 0)) == wid:
		return
	game.query.set_blocks_by_cell(&"ruins", RuinWalls.of_world(game.world))
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
	_on_fell()


func _on_fell() -> void:
	if game == null or game.world == null or game.world.get_instance_id() != _ruins_of:
		return
	# Only a ruin brought down moves a wall.
	if _count_fallen() != _fallen:
		_set_walls(true)


func realm_changed(_from: StringName, _to: StringName) -> void:
	_set_walls(false)


## The walls go into the query a cell at a time, the first time a body asks in a
## cell (WorldQuery.set_blocks_by_cell); the cells round him are stamped ahead of
## his feet, one a frame, so the first step into a ruined town is not the one
## that stamps it.
const AHEAD_CELLS := 2


func _process(_delta: float) -> void:
	if game == null or game.query == null or game.player == null:
		return
	@warning_ignore("return_value_discarded")
	game.query.stamp_near(game.player.pos, AHEAD_CELLS)
