extends GameSystem
## GROUND ABOVE THE GROUND, SEEN FROM ABOVE (docs/ABOVE.md S2; docs/LOOK.md law
## 3): mass hung over the player is architecture, and from the top view it is
## drawn cut at a section plane, the player's ground and SECTION above it, with
## an inked cap along the cut, as a room's near walls are. Only the connected
## mass the player is under is cut (AboveMap's ids), never a disc through rock.
## The cut eases in as the player walks under and out as they leave, by the
## plane coming down from over the mass, and it stands down over the shoulder,
## where a roof is a ceiling and the eye already stops under it.
##
## Writes the world material's `above_map`, `above_rect` (once a world) and
## `above_cut` (every frame): (the mass's id, the plane's height, the share of
## the cut drawn 0..1, unused). A world with nothing overhead costs one check.

## The section plane over the player's ground: a room's wall height
## (InteriorKind.wall_h), so a cave hall and a cottage are cut alike.
const SECTION := 2.4
## Seconds the cut takes to come in or go out.
const EASE := 0.45

var _mat: ShaderMaterial
var _world: WorldData
var _map: AboveMap
var _id := 0
var _share := 0.0
var _fresh := true


func setup(g: Game) -> void:
	super.setup(g)
	_mat = g.view.world_material() if g.view != null else null


func _process(delta: float) -> void:
	if _mat == null or game == null or game.world == null or game.player == null:
		return
	if game.world != _world:
		_bind(game.world)
	if _map == null or _map.ids.is_empty():
		return
	var at := game.player.pos
	var id := _map.id_at(floori(at.x), floori(at.y))
	var over := id != 0 and game.world.overhead_at(floori(at.x), floori(at.y)).x >= 0
	var top_view := 1.0 - (game.camera.shoulder_share() if game.camera != null else 0.0)
	var want := top_view if over else 0.0
	# A world's first frame has nothing to ease from: the cut starts where it
	# belongs (a game begun, or a shot, under a roof opens already cut).
	_share = want if _fresh else move_toward(_share, want, delta / EASE)
	_fresh = false
	# Keep the last mass while the cut goes out, so it closes over the one it
	# opened.
	if over:
		_id = id
	var plane := game.view.surface_height(at) + SECTION
	_mat.set_shader_parameter("above_cut", Vector4(_id, plane, _share, 0.0))


func _bind(w: WorldData) -> void:
	_world = w
	_map = AboveMap.of(w)
	_share = 0.0
	_fresh = true
	_id = 0
	if _map.ids.is_empty():
		_mat.set_shader_parameter("above_rect", Vector4.ZERO)
		_mat.set_shader_parameter("above_cut", Vector4(0.0, 0.0, 0.0, 0.0))
		return
	_mat.set_shader_parameter("above_map", ImageTexture.create_from_image(_map.image))
	_mat.set_shader_parameter("above_rect", _map.rect())


## For tours: `await above_cut` once the cut is fully drawn.
func tour_seen(what: StringName) -> bool:
	if what == &"above_cut":
		return _share >= 1.0
	if what == &"above_whole":
		return _share <= 0.0
	return false
