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
## The title opens this far (tiles) from any village, and keeps clear of them for
## its first stretch of drift: the first thing seen is the land, not houses.
const VILLAGE_CLEAR := 28.0
const DRIFT_AHEAD := 36.0

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
## The next coast's view and opening, set up on the worker alongside its world.
var _next_view: WorldView
var _next_opening: Array = []
## A new coast's chunks are streaming in behind the ink; it fades up once they are all built.
var _revealing := false
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
		_show(WorldGen.generate(seed_value, o.size), seed_value, null, [], true)
		_fade = 0.0
	else:
		_begin(seed_value)
	menu.open()


func _begin(s: int) -> void:
	_next_seed = s
	_next_world = null
	_next_view = null
	var size := options.size
	# World, view set-up (the mesher's fields) and the opening are all slow; none of
	# them touch the tree, so they are made on a worker. Chunks stream in later.
	_task = WorkerThreadPool.add_task(func() -> void:
		var w := WorldGen.generate(s, size)
		var v := WorldView.new()
		v.name = "world"
		v.setup(w)
		_next_opening = UiTitle.opening(w)
		_next_view = v
		_next_world = w)


## Show world `w`. `v` is its view, already set up (or null to set one up now).
## `now` builds every chunk at once (a shot); otherwise they stream in.
func _show(w: WorldData, s: int, v: WorldView = null, open: Array = [], now: bool = false) -> void:
	if view != null:
		view.queue_free()
	world = w
	seed_value = s
	if v == null:
		v = WorldView.new()
		v.name = "world"
		v.setup(w)
	if open.is_empty():
		open = UiTitle.opening(w)
	view = v
	_focus = open[0]
	_heading = open[1]
	view.focus = _focus
	if not now:
		# One chunk a frame keeps the menu answering while the coast is drawn.
		view.builds_per_frame = 1
	add_child(view)
	_hour = HOURS[posmod(s, HOURS.size())]
	sky.set_hour(_hour)
	if now:
		view.ensure_near(_focus)
	camera.snap_to(w.to_3d(_focus))
	_shown_for = 0.0
	menu.queue_redraw()


## Where the title's drift begins and which way it goes: [focus: Vector2, heading:
## Vector2]. On land well clear of every village, favouring a shore in frame and
## changing ground (contours to draw), heading the way that stays clear longest.
static func opening(w: WorldData) -> Array:
	var n := w.size
	var centre := Vector2(n, n) * 0.5
	var margin := minf(40.0, n * 0.2)
	var best := Vector2(-1, -1)
	var best_score := -INF
	var step := maxi(2, n / 40)
	for gy in range(int(margin), int(n - margin), step):
		for gx in range(int(margin), int(n - margin), step):
			if w.level_at(gx, gy) <= 0:
				continue
			var p := Vector2(gx + 0.5, gy + 0.5)
			var clear := UiTitle._village_clearance(w, p)
			if clear < VILLAGE_CLEAR:
				continue
			var sea := 0
			var levels := {}
			for k in 16:
				for r: float in [5.0, 10.0]:
					var q := p + Vector2.from_angle(k * TAU / 16.0) * r
					var l := w.level_at(clampi(floori(q.x), 0, n - 1), clampi(floori(q.y), 0, n - 1))
					if l <= 0:
						sea += 1
					levels[l] = true
			var shore := 1.0 - absf(sea / 32.0 - 0.3) * 2.5
			var relief := minf(levels.size(), 5) / 5.0
			var score := shore + relief * 0.8 + minf(clear, 60.0) / 200.0 + Rng.hash01(w.seed_value, gx, gy, 0x717) * 0.05
			if score > best_score:
				best_score = score
				best = p
	if best.x < 0.0:
		best = w.spawn
	# The heading: of eight, the one whose drift stays furthest from villages,
	# leaning toward the middle of the world where the land is.
	var heading := Vector2(1, 0.4).normalized()
	var best_h := -INF
	for k in 8:
		var d := Vector2.from_angle(k * TAU / 8.0 + 0.3)
		var worst := INF
		for i in range(1, 10):
			worst = minf(worst, UiTitle._village_clearance(w, best + d * DRIFT_AHEAD * i / 9.0))
		var toward := d.dot((centre - best).normalized()) if best.distance_to(centre) > 1.0 else 0.0
		var h := minf(worst, VILLAGE_CLEAR * 1.5) + toward * 6.0
		if h > best_h:
			best_h = h
			heading = d
	return [best, heading]


static func _village_clearance(w: WorldData, p: Vector2) -> float:
	var clear := INF
	for v: Dictionary in w.villages:
		clear = minf(clear, (v.pos as Vector2).distance_to(p))
	return clear


func _process(delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_fade_to = 1.0
	if _task < 0 and _next_world != null and _fade >= 1.0:
		_show(_next_world, _next_seed, _next_view, _next_opening)
		_next_world = null
		_next_view = null
		_revealing = true
	if _revealing and view.pending() == 0:
		_revealing = false
		_fade_to = 0.0
	if _starting and _fade >= 1.0:
		_start_game()
		return
	_fade = move_toward(_fade, _fade_to, delta / FADE_SECONDS)
	menu.fade = _fade
	if world == null:
		return
	_shown_for += delta
	if not _revealing:
		_focus += _heading * PAN_SPEED * delta
	# Turn gently back toward the middle before running off the land.
	var centre := Vector2(world.size, world.size) * 0.5
	if _focus.distance_to(centre) > world.size * 0.3:
		_heading = _heading.lerp((centre - _focus).normalized(), delta * 0.2).normalized()
	camera.target = world.to_3d(_focus)
	view.focus = _focus
	sky.set_hour(_hour + _shown_for / 60.0)
	if _shown_for > SEED_SECONDS and not _drawing():
		_begin(seed_value + 1)


## Show another coast now (left/right on the seed row).
func change_seed(d: int) -> void:
	if _drawing():
		return
	_begin(maxi(1, seed_value + d))


## A coast is on its way (on the worker, or waiting behind the ink) or the game is starting.
func _drawing() -> bool:
	return _task >= 0 or _next_world != null or _starting


func new_game() -> void:
	if _starting:
		return
	_starting = true
	_fade_to = 1.0
	Events.sfx.emit(&"menu_select", Vector3.ZERO)


func _exit_tree() -> void:
	# A coast being drawn on a worker writes into this node; wait it out.
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	# A view set up on the worker but never shown is not in the tree: free it here.
	if _next_view != null and not _next_view.is_inside_tree():
		_next_view.free()
		_next_view = null


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
