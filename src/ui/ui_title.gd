class_name UiTitle
extends Node3D
## The title: UNSPENT lettered on a label over a live coast that drifts slowly
## past, a new seed every little while. New game starts on the coast being
## shown. Built like Game (world, view, sky, camera) but with no player.
##   godot --path .                              (no arguments boots here)
##   tools/shot.sh shots/ui/title.png --scene=title

## Seconds a coast is shown before the next one is drawn.
const SEED_SECONDS := 36.0
const PAN_SPEED := 1.1
const FADE_SECONDS := 1.2
## Hours the drifting coast is shown at, one per seed, so the title changes light too.
const HOURS: Array[float] = [16.8, 9.5, 19.4, 7.2, 12.5]

var options: BootOptions
var seed_value := 1
var world: WorldData
var view: WorldView
var sky: SkyLight
var camera: CameraRig
var menu: UiTitleMenu

var _layer: CanvasLayer
var _focus := Vector2.ZERO
var _heading := Vector2.ONE
var _shown_for := 0.0
var _fade := 1.0 # 1 = ink
var _fade_to := 0.0
var _next_world: WorldData
var _next_seed := 0
var _task := -1
var _starting := false
var _hour := 12.0


func setup(o: BootOptions) -> void:
	options = o
	name = "title"
	seed_value = o.seed_value
	sky = SkyLight.new()
	sky.name = "sky"
	add_child(sky)
	camera = CameraRig.new()
	camera.name = "camera"
	camera.follow_rate = 2.0
	add_child(camera)
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	menu = UiTitleMenu.new()
	menu.title = self
	_layer.add_child(menu)
	if o.shot != "":
		# A shot has a few frames, not a second: draw the coast now and show it.
		_show(WorldGen.generate(seed_value, o.size), seed_value)
		_fade = 0.0
	else:
		_begin(seed_value)
	menu.open()


func _begin(s: int) -> void:
	_next_seed = s
	_next_world = null
	_task = WorkerThreadPool.add_task(func() -> void: _next_world = WorldGen.generate(s, options.size))


func _show(w: WorldData, s: int) -> void:
	if view != null:
		view.queue_free()
	world = w
	seed_value = s
	view = WorldView.new()
	view.name = "world"
	add_child(view)
	view.setup(w)
	# Start a little inland of the spawn and drift across the land, away from the nearest edge.
	_focus = w.spawn
	var centre := Vector2(w.size, w.size) * 0.5
	_heading = (centre - _focus).normalized().rotated(0.6) if _focus.distance_to(centre) > 8.0 else Vector2(1, 0.4).normalized()
	_hour = HOURS[posmod(s, HOURS.size())]
	sky.set_hour(_hour)
	view.ensure_near(_focus)
	camera.snap_to(w.to_3d(_focus))
	_shown_for = 0.0
	menu.queue_redraw()


func _process(delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_fade_to = 1.0
	if _task < 0 and _next_world != null and _fade >= 1.0:
		_show(_next_world, _next_seed)
		_next_world = null
		_fade_to = 0.0
	if _starting and _fade >= 1.0:
		_start_game()
		return
	_fade = move_toward(_fade, _fade_to, delta / FADE_SECONDS)
	menu.fade = _fade
	if world == null:
		return
	_shown_for += delta
	_focus += _heading * PAN_SPEED * delta
	# Turn gently back toward the middle before running off the land.
	var centre := Vector2(world.size, world.size) * 0.5
	if _focus.distance_to(centre) > world.size * 0.3:
		_heading = _heading.lerp((centre - _focus).normalized(), delta * 0.2).normalized()
	camera.target = world.to_3d(_focus)
	view.focus = _focus
	sky.set_hour(_hour + _shown_for / 60.0)
	if _shown_for > SEED_SECONDS and _task < 0 and not _starting:
		_begin(seed_value + 1)


## Show another coast now (left/right on the seed row).
func change_seed(d: int) -> void:
	if _task >= 0 or _starting:
		return
	_begin(maxi(1, seed_value + d))


func new_game() -> void:
	if _starting:
		return
	_starting = true
	_fade_to = 1.0
	Events.sfx.emit(&"menu_select", Vector3.ZERO)


func _start_game() -> void:
	var o := BootOptions.new()
	o.seed_value = seed_value
	o.size = options.size
	var game := Game.new()
	game.name = "game"
	var parent := get_parent()
	menu.close()
	parent.remove_child(self)
	parent.add_child(game)
	game.setup(o)
	queue_free()


## Replace a running game with the title (pause -> to the title).
static func replace_game(game: Game) -> void:
	var parent := game.get_parent()
	game.get_tree().paused = false
	var o := BootOptions.new()
	o.seed_value = game.options.seed_value + 1
	o.size = game.options.size
	var t := UiTitle.new()
	parent.remove_child(game)
	game.queue_free()
	parent.add_child(t)
	t.setup(o)
