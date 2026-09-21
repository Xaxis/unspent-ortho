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


## Where each standing hologram really lands on the glass, asked of the live
## camera. Task #116's whole diagnosis was this print run by hand; keeping it
## behind an environment variable means the next person does not rebuild it.
func _say(here: BiomeDef) -> void:
	var cam := game.camera
	if cam == null:
		return
	var rect := cam.get_viewport().get_visible_rect().size
	var lines := PackedStringArray()
	for i in view.drawn:
		var n := view.node_at(i)
		if n == null:
			continue
		var foot := cam.unproject_position(n.global_position)
		lines.append("%d:foot(%.0f,%.0f)" % [i, foot.x, foot.y])
	var tally := {}
	for r: float in view.roofs:
		tally[r] = int(tally.get(r, 0)) + 1
	print("world HOLO land %s share %.2f houses-near %d roofs %s carry %d drawn %d spans %s -- %s"
		% [here.id if here != null else &"-", view.share, view.roofs.size(),
			tally, view.considered, view.drawn, " ".join(view.spans), " ".join(lines)])


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
	# The view asks the camera itself whether a column is in the picture, because
	# the frame moves: zoom, the target lean, and the third-person glide (#121)
	# all change what fits, and a hologram's foot is high enough off the ground
	# that it leaves the top of the frame long before its building does (#116,
	# tests/render/test_read_reach.gd).
	view.cam = game.camera
	var f3: Vector3 = game.camera.target if game.camera != null else game.player.position
	view.follow(Vector2(f3.x, f3.z))
	if OS.has_environment("UNSPENT_HOLO_DEBUG"):
		_say(here)
