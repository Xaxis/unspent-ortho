extends GameSystem
## A ruin's walls stop a body (RuinWalls): every standing ruin in the world
## handed to WorldQuery as the circles along its walls, for the whole island
## like the landmarks' mass, and handed again when anything is taken (a ruin
## broken down takes its walls with it) and on a realm crossing.


func setup(g: Game) -> void:
	super.setup(g)
	_set_walls()
	Events.took.connect(_on_took)


func _set_walls() -> void:
	if game == null or game.query == null or game.world == null:
		return
	game.query.set_blocks(&"ruins", RuinWalls.of_world(game.world))


func _on_took(_item: StringName, _count: int) -> void:
	_set_walls()


func realm_changed(_from: StringName, _to: StringName) -> void:
	_set_walls()
