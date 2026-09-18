extends GameSystem
## The machines that cross overhead, where a landscape has asked for them
## (`BiomeDef.fliers`). The layer itself is `src/render/depth/flier_view.gd` and
## this owns none of it: it points the view at the world and the camera, and
## tells it where the player is and what time it is.
##
## Numbered between the foreground pieces (13) and the lights (15) for the same
## reason 13 is where it is: a machine in the air casts into the shadow map the
## sun is already drawing, and 15 decides how many LOCAL lights may cast on top
## of that. Nothing here asks for a light of its own — the strip and the beacon
## are the neon mark on the model, which every lit shader already burns after
## dark on the machines' power.
##
## A landscape that has not asked gets nothing built, so this costs the coast
## one comparison a frame.

const FlierViewScript := preload("res://src/render/depth/flier_view.gd")

var view: FlierView


func setup(g: Game) -> void:
	super.setup(g)
	view = FlierViewScript.new()
	view.name = "fliers"
	add_child(view)
	view.setup(g.world, g.camera, g.view.world_material() if g.view != null else null)
	_take_budget()


## A crossing points everything at the other realm's world, and the traffic over
## a cave is not the traffic over a city: the count is the new landscape's.
func realm_changed(_from: StringName, _to: StringName) -> void:
	if view != null and game != null:
		view.rebind(game.world)
		_take_budget()


func _take_budget() -> void:
	if view == null or game == null:
		return
	var here := BiomeRegistry.at(game.world, game.player.pos)
	view.budget = 0 if here == null else here.fliers


func _process(_delta: float) -> void:
	if view == null or game == null:
		return
	# The landscape under the player decides, and it is asked every frame rather
	# than latched: a player walking out of the city walks out from under its
	# traffic, which is the whole of what the number means.
	_take_budget()
	if view.budget <= 0:
		view.follow(Vector2.ZERO, 0.0)
		return
	var f3: Vector3 = game.camera.target if game.camera != null else game.player.position
	view.follow(Vector2(f3.x, f3.z), game.clock.minutes if game.clock != null else 0.0)
