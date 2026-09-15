class_name Game
extends Node3D
## The running game: one world, its view, the player, the camera, the sky, the
## HUD. Built entirely in code from BootOptions so every state is reachable from
## the command line and from tests.

var options: BootOptions
var world: WorldData
var query: WorldQuery
var clock: WorldClock
var view: WorldView
var player: Player
var camera: CameraRig
var sky: SkyLight
var hud: Hud
var body: Body
var inventory: Inventory
## Systems loaded from res://src/systems/NN_*.gd, in file-name order.
var systems: Array[GameSystem] = []
## Open UI screens by name; while any is open, gameplay input is ignored.
var open_screens: Dictionary = {}
## Set by scripted walks (--walk) and bots; overrides device input while > 0.
var scripted_move := Vector2.ZERO
var scripted_run := false
var scripted_seconds := 0.0


func setup(o: BootOptions) -> void:
	options = o
	var t0 := Time.get_ticks_msec()
	# Systems compile on loader threads while the world is generated: parsing
	# them one after another on the main thread cost over half a second.
	var system_files := _system_files()
	for f in system_files:
		ResourceLoader.load_threaded_request("res://src/systems/" + f, "GDScript")
	world = WorldGen.generate(o.seed_value, o.size)
	var t1 := Time.get_ticks_msec()
	query = WorldQuery.new(world)
	clock = WorldClock.new(o.hour)
	body = Body.new()
	body.fed_until = clock.minutes + 6.0 * 60.0
	inventory = Inventory.new()
	inventory.add(&"knife")
	inventory.set_held(&"knife")

	sky = SkyLight.new()
	sky.name = "sky"
	add_child(sky)

	view = WorldView.new()
	view.name = "world"
	add_child(view)
	view.setup(world)

	var start := world.spawn
	if o.village >= 0 and o.village < world.villages.size():
		start = (world.villages[o.village].pos as Vector2) + Vector2(3, 3)
	elif o.at.x >= 0:
		start = o.at
	elif o.place != "" and GenPlaces.find(world, o.place).x >= 0:
		start = GenPlaces.find(world, o.place)
	player = Player.new()
	player.name = "player"
	add_child(player)
	player.setup(world, query, start, view.world_material())
	if start == world.spawn:
		player.facing = world.spawn_facing

	camera = CameraRig.new()
	camera.name = "camera"
	if o.zoom > 0.0:
		camera.view_height = o.zoom
	add_child(camera)
	camera.snap_to(player.position)

	hud = Hud.new()
	hud.name = "hud"
	add_child(hud)

	view.ensure_near(player.pos)
	sky.set_hour(clock.hour())
	Events.screen_changed.connect(func(n: StringName, open: bool) -> void:
		if open:
			open_screens[n] = true
		else:
			open_screens.erase(n))
	_load_systems(system_files)
	if o.walk_seconds > 0.0:
		scripted_move = o.walk
		scripted_run = o.run
		scripted_seconds = o.walk_seconds
	print("world %d gen %d ms, view %d ms" % [o.seed_value, t1 - t0, Time.get_ticks_msec() - t1])


func _system_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open("res://src/systems")
	if dir == null:
		return files
	for f in dir.get_files():
		if f.ends_with(".gd") and f.substr(0, 2).is_valid_int():
			files.append(f)
	files.sort()
	return files


func _load_systems(files: Array[String]) -> void:
	for f in files:
		var path := "res://src/systems/" + f
		var script := ResourceLoader.load_threaded_get(path) as GDScript
		if script == null:
			script = load(path) as GDScript
		var sys: GameSystem = script.new()
		sys.name = f.get_basename()
		add_child(sys)
		sys.setup(self)
		systems.append(sys)
	for sys in systems:
		sys.started()


## True while gameplay input should be ignored (a screen is open, or the body is busy).
func input_blocked() -> bool:
	return not open_screens.is_empty()


func _physics_process(delta: float) -> void:
	if world == null:
		return
	clock.advance(delta)
	var input := Vector2.ZERO
	var run := false
	if scripted_seconds > 0.0:
		input = scripted_move
		run = scripted_run
		scripted_seconds -= delta
	elif not input_blocked():
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		run = Input.is_action_pressed("run")
	if Time.get_ticks_msec() / 1000.0 < body.busy_until:
		input = Vector2.ZERO
	player.drive(Player.screen_to_world(input, camera.yaw_deg), run, delta)


func _process(_delta: float) -> void:
	if world == null:
		return
	camera.target = player.position
	view.focus = player.pos
	sky.set_hour(clock.hour())
	hud.set_clock(clock.label())
