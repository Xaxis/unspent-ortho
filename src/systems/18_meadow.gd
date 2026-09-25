extends GameSystem
## The meadow ring round the player at eye level (MeadowView): it follows the
## player over whichever world view is drawn, stands only while the drawing
## camera sees the horizon (the rule every eye-level change follows,
## SkyLight.sees_horizon), and takes its reach and thickness from the tier
## (Quality `grass_reach`, `grass_density`).

var meadow: MeadowView
var _bound: WorldView


func setup(g: Game) -> void:
	super.setup(g)
	meadow = MeadowView.new()
	meadow.name = "meadow"
	add_child(meadow)
	meadow.setup(preload("res://src/render/foliage/grass.gdshader"))


func _process(_delta: float) -> void:
	if game == null or game.player == null:
		return
	var tier := Quality.current()
	meadow.configure(float(tier.get("grass_reach", 0)), float(tier.get("grass_density", 0.0)))
	var view: WorldView = game.view
	if view != _bound:
		if _bound != null and is_instance_valid(_bound) and _bound.chunk_built.is_connected(meadow.chunk_changed):
			_bound.chunk_built.disconnect(meadow.chunk_changed)
		_bound = view
		if view != null:
			view.chunk_built.connect(meadow.chunk_changed)
	meadow.follow(view, game.player.pos, SkyLight.sees_horizon(get_viewport().get_camera_3d()))


## `meadow`: the ring is standing round the player now, with plants in it.
func tour_seen(what: StringName) -> bool:
	return what == &"meadow" and meadow != null and meadow.visible and meadow.plants > 0
