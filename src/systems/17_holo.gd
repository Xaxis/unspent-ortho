extends GameSystem
## The holograms standing over a city's roofs, where a landscape has asked for
## them (`BiomeDef.holograms`). The layer is `src/render/depth/holo_view.gd` and
## this owns none of it: it points the view at the world and the query, and tells
## it where the player is.
##
## Numbered after the lights (15) and the vents (16) because it is not a light:
## it asks for no lamp, casts nothing and takes no shadow. It is additive
## geometry that writes no depth, which is the whole of why it may stand where a
## solid thing would have to stipple out of the player's way.
##
## A landscape that has not asked builds nothing, so this costs the coast one
## comparison a frame.

const HoloViewScript := preload("res://src/render/depth/holo_view.gd")

var view: HoloView


func setup(g: Game) -> void:
	super.setup(g)
	view = HoloViewScript.new()
	view.name = "holo"
	add_child(view)
	view.setup(g.world, g.query)


## A crossing points everything at the other realm's world. There is no
## advertising in a cave, and the share is the new landscape's.
func realm_changed(_from: StringName, _to: StringName) -> void:
	if view != null and game != null:
		view.rebind(game.world, game.query)


func _process(_delta: float) -> void:
	if view == null or game == null:
		return
	# The landscape under the player decides, asked every frame rather than
	# latched: walking out of the city is walking out from under its advertising.
	var here := BiomeRegistry.at(game.world, game.player.pos)
	view.share = 0.0 if here == null else here.holograms
	if view.share <= 0.0:
		view.follow(Vector2(INF, INF))
		return
	var f3: Vector3 = game.camera.target if game.camera != null else game.player.position
	view.follow(Vector2(f3.x, f3.z))
