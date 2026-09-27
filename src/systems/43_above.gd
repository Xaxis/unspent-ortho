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

## Tiles either side of the player the map covers (a roofed cave is a world
## of spans), and where it was centred.
const WINDOW := 96
var _map_at := Vector2.ZERO
## The map being built on a worker, round `_task_at`.
var _task := -1
var _task_at := Vector2.ZERO
var _task_map: AboveMap
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
	elif _map != null and not _map.ids.is_empty() and game.player.pos.distance_to(_map_at) > WINDOW * 0.5 and _task < 0:
		# Walked toward the window's edge: build it again round the player, on
		# a worker (a window of a roofed cave is 0.1 s), keeping the old until
		# the new is done.
		var w := game.world
		var at: Vector2 = game.player.pos
		_task_at = at
		_task = WorkerThreadPool.add_task(func() -> void:
			_task_map = AboveMap.of(w, at, WINDOW), false, "above map")
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _task_map != null and game.world == _world:
			_take(_task_map, _task_at)
		_task_map = null
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
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_task_map = null
	_world = w
	_share = 0.0
	_fresh = true
	_id = 0
	_take(AboveMap.of(w, game.player.pos, WINDOW), game.player.pos)


## Draw with `m`, a map built round `at`.
func _take(m: AboveMap, at: Vector2) -> void:
	_map = m
	_map_at = at
	if _map.ids.is_empty():
		_mat.set_shader_parameter("above_rect", Vector4.ZERO)
		_mat.set_shader_parameter("above_cut", Vector4(0.0, 0.0, 0.0, 0.0))
		return
	_mat.set_shader_parameter("above_map", ImageTexture.create_from_image(_map.image))
	_mat.set_shader_parameter("above_glow", ImageTexture.create_from_image(_map.glow))
	_mat.set_shader_parameter("above_rect", _map.rect())
	# The hall is seen as its own landscape says (BiomeDef.cave_light).
	var land := BiomeRegistry.by_index(game.world.country_at(floori(at.x), floori(at.y)))
	_mat.set_shader_parameter("cave_light", land.cave_light if land != null else Vector4.ZERO)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


const TOUR_PLACES: Array[String] = ["under_roof", "glide_under_roof", "deep_under_roof"]
## Tiles of roof every way round `deep_under_roof`: no tear, shaft or roof's edge
## nearer, so a frame there is lit by the cave alone.
const DEEP_UNDER := 16
## Tiles of a glide's way out from `glide_under_roof` that must all be under mass.
const GLIDE_UNDER := 8


## `near under_roof`: the nearest walkable tile within 40 under the middle of a
## plateau (its three by three all one mass), so a tour stands under a roof by
## name and never at a coordinate.
func tour_place(what: String) -> Vector2:
	if game == null or game.world == null or game.player == null:
		return Vector2.INF
	if what == "glide_under_roof":
		return _glide_under_roof()
	if what == "deep_under_roof":
		return _deep_under_roof()
	if what != "under_roof":
		return Vector2.INF
	var w := game.world
	var at := game.player.pos
	var best := Vector2.INF
	var best_d := INF
	for dy in range(-40, 41, 2):
		for dx in range(-40, 41, 2):
			var x := floori(at.x) + dx
			var y := floori(at.y) + dy
			var o := w.overhead_at(x, y)
			if o.x < 0 or not game.query.standable(x, y):
				continue
			var core := true
			for ey in range(-1, 2):
				for ex in range(-1, 2):
					if w.overhead_at(x + ex, y + ey) != o:
						core = false
			var d := Vector2(dx, dy).length()
			if core and d < best_d:
				best_d = d
				best = Vector2(x + 0.5, y + 0.5)
	return best


## `near glide_under_roof`: the nearest tile within 60 with room for a body under
## a roof, a drop ahead that a wing launches off (AbilityGlide.launch) and mass
## over the first GLIDE_UNDER tiles of the way out, so a tour flies under the lid
## by name; `tour_face` then turns the body along that way.
var _glide_facing := NAN
func _glide_under_roof() -> Vector2:
	var w := game.world
	var at := game.player.pos
	var best := Vector2.INF
	var best_d := INF
	for dy in range(-60, 61):
		for dx in range(-60, 61):
			var d := Vector2(dx, dy).length()
			if d >= best_d:
				continue
			var x := floori(at.x) + dx
			var y := floori(at.y) + dy
			var o := w.overhead_at(x, y)
			if o.x < 0 or not game.query.standable(x, y) or w.headroom_at(x, y) * WorldData.STEP < Tuning.PLAYER_HEIGHT:
				continue
			var here := Vector2(x + 0.5, y + 0.5)
			for k in 8:
				var way := AbilityGlide.launch(w, game.query, here, Vector2.from_angle(k * TAU / 8.0))
				if way == Vector2.ZERO:
					continue
				var covered := true
				for s in range(1, GLIDE_UNDER + 1):
					var q := here + way * float(s)
					if w.overhead_at(floori(q.x), floori(q.y)).x < 0:
						covered = false
						break
				if covered:
					best_d = d
					best = here
					_glide_facing = way.angle()
					break
	return best


## `near deep_under_roof`: the nearest walkable tile within 80 with room for a
## body under the roof and roof over every tile DEEP_UNDER round it (sampled
## every two), so a tour measures the cave's own light far from any tear.
func _deep_under_roof() -> Vector2:
	var w := game.world
	var at := game.player.pos
	var best := Vector2.INF
	var best_d := INF
	for dy in range(-80, 81, 2):
		for dx in range(-80, 81, 2):
			var d := Vector2(dx, dy).length()
			if d >= best_d:
				continue
			var x := floori(at.x) + dx
			var y := floori(at.y) + dy
			if w.overhead_at(x, y).x < 0 or not game.query.standable(x, y) or w.headroom_at(x, y) * WorldData.STEP < Tuning.PLAYER_HEIGHT:
				continue
			var shut := true
			for ey in range(-DEEP_UNDER, DEEP_UNDER + 1, 2):
				for ex in range(-DEEP_UNDER, DEEP_UNDER + 1, 2):
					if w.overhead_at(x + ex, y + ey).x < 0:
						shut = false
						break
				if not shut:
					break
			if shut:
				best_d = d
				best = Vector2(x + 0.5, y + 0.5)
	return best


func tour_face(what: String) -> float:
	return _glide_facing if what == "glide_under_roof" else NAN


## For tours: `await above_cut` once the cut is fully drawn.
func tour_seen(what: StringName) -> bool:
	if what == &"above_cut":
		return _share >= 1.0
	if what == &"above_whole":
		return _share <= 0.0
	return false
