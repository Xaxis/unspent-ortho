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
	# What each part of the setup costs, said on one line: on the web the whole of
	# it is the press's `start`, seconds on the main thread.
	var parts := {}
	var t := Time.get_ticks_usec()
	query = WorldQuery.new(world)
	clock = WorldClock.new(o.hour)
	body = Body.new()
	body.fed_until = clock.minutes + 6.0 * 60.0
	inventory = Inventory.new()
	inventory.add(&"knife")
	inventory.set_held(&"knife")

	t = _took(parts, "state", t)
	sky = SkyLight.new()
	sky.name = "sky"
	add_child(sky)
	t = _took(parts, "sky", t)

	view = BootWorld.view(world)
	view.name = "world"
	add_child(view)
	t = _took(parts, "view", t)

	# One rule for where a game starts, shared with the loading page's first view.
	var start := BootWorld.start_of(world, o)
	player = Player.new()
	player.name = "player"
	add_child(player)
	player.setup(world, query, start, view.world_material())
	if start == world.spawn:
		player.facing = world.spawn_facing
	t = _took(parts, "player", t)

	camera = CameraRig.new()
	# Set BEFORE it enters the tree: `_ready` chooses the projection from it.
	camera.lens = o.lens
	camera.name = "camera"
	if o.zoom > 0.0:
		camera.view_height = o.zoom
	add_child(camera)
	camera.snap_to(player.position)
	t = _took(parts, "camera", t)

	hud = Hud.new()
	hud.name = "hud"
	add_child(hud)
	t = _took(parts, "hud", t)

	view.ensure_near(player.pos)
	t = _took(parts, "near", t)
	sky.set_hour(clock.hour())
	Events.screen_changed.connect(func(n: StringName, open: bool) -> void:
		if open:
			open_screens[n] = true
		else:
			open_screens.erase(n))
	_load_systems(system_files)
	_took(parts, "systems", t)
	if o.walk_seconds > 0.0:
		scripted_move = o.walk
		scripted_run = o.run
		scripted_seconds = o.walk_seconds
	print("world %d gen %d ms, view %d ms" % [o.seed_value, t1 - t0, Time.get_ticks_msec() - t1])
	var said := PackedStringArray()
	for k: String in parts:
		said.append("%s %d" % [k, int(parts[k])])
	print("boot setup (ms): %s" % ", ".join(said))


static func _took(parts: Dictionary, what: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	parts[what] = roundi((now - since) / 1000.0)
	return now


func _system_files() -> Array[String]:
	var files: Array[String] = []
	# Not DirAccess: an exported build lists `10_sky.gd.remap`, and every system
	# silently went missing on the web.
	for f in ResourceLoader.list_directory("res://src/systems"):
		if f.ends_with(".gd") and f.substr(0, 2).is_valid_int():
			files.append(f)
	files.sort()
	return files


## Setting up a system slower than this is named on the `boot systems` line: the
## loading page's `start` stage is all of them, and on the web it is seconds.
const SLOW_SYSTEM_MS := 50


func _load_systems(files: Array[String]) -> void:
	var cost := {}
	var setup_usec := 0
	for f in files:
		var t := Time.get_ticks_usec()
		var path := "res://src/systems/" + f
		var script := ResourceLoader.load_threaded_get(path) as GDScript
		if script == null:
			script = load(path) as GDScript
		var sys: GameSystem = script.new()
		sys.name = f.get_basename()
		add_child(sys)
		sys.setup(self)
		systems.append(sys)
		var us := Time.get_ticks_usec() - t
		setup_usec += us
		cost[String(sys.name)] = us
	var started_usec := 0
	for sys in systems:
		var t := Time.get_ticks_usec()
		sys.started()
		var us := Time.get_ticks_usec() - t
		started_usec += us
		cost["%s started" % sys.name] = us
	# Every system is in the totals and the slow ones are named, slowest first: on
	# the web this is most of the press's main-thread wait (the page's `start`).
	var names := cost.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(cost[a]) > int(cost[b]))
	var slow := PackedStringArray()
	for n: String in names:
		if int(cost[n]) >= SLOW_SYSTEM_MS * 1000:
			slow.append("%s %d" % [n, int(cost[n]) / 1000])
	print("boot systems %d ms (setup %d, started %d), %d at %d ms or more: %s" % [(setup_usec + started_usec) / 1000,
		setup_usec / 1000, started_usec / 1000, slow.size(), SLOW_SYSTEM_MS, ", ".join(slow)])


## True while somebody is being talked to: a conversation is not a screen (it is
## drawn over the world, owner 2026-09-17) but it holds the keys the same way.
## 49_story is its only writer.
var talking := false
## True while a staged look holds the view (42_stage is its only writer): the keys
## are held as for a page, so nothing turns the view or swings under it.
var staged := false
## True while he is up a walker's leg (43_climb is its only writer): the move and
## use keys are the climb's, and nothing on the ground below reads them.
var aloft := false


## THE LAND'S KEYS (move, use, swing, dodge, crouch, drop, gear, the view's own)
## are not his while a page, a talk or a staged look holds the keys, nor up a
## walker's leg, where move and use are the climb's and the rest act on a land
## he is not on.
func input_blocked() -> bool:
	return keys_held() or aloft


## HIS OWN KEYS (the lamp; the slate's pages, 90_ui) are his on the leg too: only
## a page, a talk or a staged look holds them.
func keys_held() -> bool:
	return not open_screens.is_empty() or talking or staged


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
		# Over the shoulder the arrows turn the view (41_shoulder), so the walk
		# there is the move keys that are not also look keys (docs/CONTROLS.md, C6).
		if camera.shoulder:
			input = Vector2(_walk_apart(&"move_right") - _walk_apart(&"move_left"),
				_walk_apart(&"move_down") - _walk_apart(&"move_up")).limit_length(1.0)
		run = Input.is_action_pressed("run")
	if Survival.now_real() < body.busy_until:
		input = Vector2.ZERO
	# The camera's yaw as it is now, lean and all (CameraRig.yaw_now): the keys
	# must go on matching the screen while a target lock leans the frame. Over the
	# shoulder a lock makes the line to it forward instead (LockOn.intent).
	var lock: Vector2 = player.hero.lock if player.hero != null else Vector2.INF
	player.drive(LockOn.intent(input, camera.yaw_now(), player.pos, lock, camera.shoulder), run, delta)


## 1 when a key of `action` is down that is not also a look key.
static func _walk_apart(action: StringName) -> float:
	var look := StringName(String(action).replace("move_", "look_"))
	for e: InputEvent in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k == null or (InputMap.has_action(look) and InputMap.action_has_event(look, k)):
			continue
		if Input.is_physical_key_pressed(k.physical_keycode):
			return 1.0
	return 0.0


func _process(_delta: float) -> void:
	if world == null:
		return
	# On the land, not up a leg: the land streams and the rig waits where he left it.
	var eye := watch if watch.is_finite() else player.on_land()
	camera.target = eye
	view.focus = Vector2(eye.x, eye.z)
	sky.set_hour(clock.hour())
	hud.set_clock(clock.label())
