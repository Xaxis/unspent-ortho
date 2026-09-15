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
## Set by scripted walks (--walk) and bots; overrides device input while > 0.
var scripted_move := Vector2.ZERO
var scripted_run := false
var scripted_seconds := 0.0


func setup(o: BootOptions) -> void:
	options = o
	var t0 := Time.get_ticks_msec()
	world = WorldGen.generate(o.seed_value, o.size)
	var t1 := Time.get_ticks_msec()
	query = WorldQuery.new(world)
	clock = WorldClock.new(o.hour)

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
	player = Player.new()
	player.name = "player"
	add_child(player)
	player.setup(world, query, start, view.world_material())

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
	if o.walk_seconds > 0.0:
		scripted_move = o.walk
		scripted_run = o.run
		scripted_seconds = o.walk_seconds
	print("world %d gen %d ms, view %d ms" % [o.seed_value, t1 - t0, Time.get_ticks_msec() - t1])


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
	else:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		run = Input.is_action_pressed("run")
	player.drive(Player.screen_to_world(input, camera.yaw_deg), run, delta)


func _process(_delta: float) -> void:
	if world == null:
		return
	camera.target = player.position
	view.focus = player.pos
	sky.set_hour(clock.hour())
	hud.set_clock(clock.label())
