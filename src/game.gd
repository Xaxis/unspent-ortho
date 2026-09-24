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

## WHERE THE PICTURE IS TAKEN FROM, when that is not the player (owner,
## 2026-09-18: "a view where I can zoom out over the entire world, travel over
## everything and zoom into a given landscape"). `Vector3.INF` — the default and
## the whole of normal play — means the player, exactly as before.
##
## ONE FIELD, because the camera and the world's streaming must never disagree
## about where the picture is: `view.focus` decides which chunks exist and
## `camera.target` decides what is drawn, and a flyover that moved only the
## camera would fly over ground nobody had built. They are set together, below,
## from this one place. 95_flyover is its only writer.
var watch := Vector3.INF


func setup(o: BootOptions) -> void:
	options = o
	var t0 := Time.get_ticks_msec()
	# Systems compile on loader threads while the world is generated: parsing
	# them one after another on the main thread cost over half a second.
	var system_files := _system_files()
	for f in system_files:
		ResourceLoader.load_threaded_request("res://src/systems/" + f, "GDScript")
	# The loading page may have made this world (and its view) already.
	world = BootWorld.world(o.seed_value, o.size)
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

	view = BootWorld.view(world)
	view.name = "world"
	add_child(view)

	# One rule for where a game starts, shared with the loading page's first view.
	var start := BootWorld.start_of(world, o)
	player = Player.new()
	player.name = "player"
	add_child(player)
	player.setup(world, query, start, view.world_material())
	if start == world.spawn:
		player.facing = world.spawn_facing

	camera = CameraRig.new()
	# Set BEFORE it enters the tree: `_ready` chooses the projection from it.
	camera.lens = o.lens
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
	# Not DirAccess: an exported build lists `10_sky.gd.remap`, and every system
	# silently went missing on the web.
	for f in ResourceLoader.list_directory("res://src/systems"):
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
## True while a page is up OR somebody is being talked to: a conversation is not
## a screen (it is drawn over the world, owner 2026-09-17) but it holds the keys
## the same way, so every reader that already asked this question keeps working.
## 49_story is its only writer.
var talking := false


func input_blocked() -> bool:
	return not open_screens.is_empty() or talking


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
	# `watch` finite means the picture is not on the player, so the movement keys
	# are not the player's either — they are flying the camera (95_flyover). The
	# body stays exactly where it was left, which is the claim the whole tool
	# rests on: what he is shown is the game as it is, not a game he is nudging.
	elif not input_blocked() and not watch.is_finite():
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# The arrows turn the view over the shoulder (41_shoulder) and walk
		# everywhere else, as they always did (docs/CONTROLS.md, C6).
		if not camera.shoulder and InputMap.has_action(&"look_left"):
			input = (input + Input.get_vector("look_left", "look_right", "look_up", "look_down")).limit_length(1.0)
		run = Input.is_action_pressed("run")
	if Time.get_ticks_msec() / 1000.0 < body.busy_until:
		input = Vector2.ZERO
	# The camera's yaw as it is now, lean and all (CameraRig.yaw_now): the keys
	# must go on matching the screen while a target lock leans the frame. Over the
	# shoulder a lock makes the line to it forward instead (LockOn.intent).
	var lock: Vector2 = player.hero.lock if player.hero != null else Vector2.INF
	player.drive(LockOn.intent(input, camera.yaw_now(), player.pos, lock, camera.shoulder), run, delta)


func _process(_delta: float) -> void:
	if world == null:
		return
	var eye := watch if watch.is_finite() else player.position
	camera.target = eye
	view.focus = Vector2(eye.x, eye.z)
	sky.set_hour(clock.hour())
	hud.set_clock(clock.label())
