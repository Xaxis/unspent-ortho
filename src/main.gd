extends Node
## Entry point. Parses command-line options, boots the requested scene, and in
## --shot mode waits for the world to be built, captures one frame, and quits.
##
## A title or a game started for play goes through the loading page (BootPage),
## which makes the world without freezing the window. Shots build the scene at
## once. This script names no game class (it loads them by path): naming one here
## would compile nearly every script before the first frame could be drawn.
## When the first frame of a world is drawn it prints `boot ready <scene> <ms>`
## (tools/web.sh waits for that line).

var options: BootOptions
var _t0 := 0


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	options = BootOptions.parse(OS.get_cmdline_user_args())
	SaveSlots.use_options(options)
	if options.shot == "":
		# Every scene that appears (the title, then a game started from it) says when it is up.
		child_entered_tree.connect(func(n: Node) -> void:
			if n.name == &"game" or n.name == &"title":
				_ready_line.call_deferred(n))
	# A player launching the game gets the title; tools always pass options.
	if OS.get_cmdline_user_args().is_empty():
		options.scene = "title"
	# The master configuration this run is made from, and whether dev mode can be
	# reached (docs/DEV.md). A game booted straight from the command line is a new
	# game, and takes a configuration's start as the title's New game does.
	DevMode.boot(options, OS.get_cmdline_user_args())
	if options.scene == "game":
		GameConfig.fill_new_game(options, DevMode.explicit(OS.get_cmdline_user_args()))
	_take_focus_if_a_person_is_playing()
	var root: Node
	match options.scene:
		"gallery":
			root = load("res://src/gallery.gd").new()
			add_child(root)
			root.call("setup", options)
		"loading":
			root = BootPage.preview(self, options)
		"title":
			if options.shot != "":
				root = BootPage.make_title(self, options)
			else:
				root = BootPage.open_title(self, options)
			if options.tour != "":
				# The tour outlives the title: it waits for the slate, starts a game,
				# drives it. The title may still be on the loading page: the runner
				# finds it by name when it is up.
				var runner: Node = load("res://src/systems/98_tour.gd").new()
				add_child(runner)
				runner.call("run_on_title", root if root.name == &"title" else null)
		_:
			if options.shot != "":
				root = BootPage.make_game(self, options)
			else:
				root = BootPage.open_game(self, options)
	if root.get_parent() == null:
		add_child(root)
	if options.shot != "":
		_shoot()


## The window opens unfocusable (project.godot, display/window/size/no_focus) so
## that the hundred shots and tours an hour this project runs never take the
## keyboard away from whoever is using the machine. A session meant for a person
## takes the focus back here: a tool run is the one that was handed a --shot or
## a --tour to do, and it is the only kind that stays out of the way.
func _take_focus_if_a_person_is_playing() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if options.shot != "" or options.tour != "":
		return
	get_window().set_flag(Window.FLAG_NO_FOCUS, false)
	DisplayServer.window_move_to_foreground()
	get_window().grab_focus()


## Wait for `scene`'s first drawn frame of its world, then say so (and probe it).
func _ready_line(scene: Node) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(scene) and scene.is_inside_tree():
		# Once the loading page has lifted: a game is up when the ground under the
		# player is drawn (the rest streams in); the title once its coast shows
		# through the ink it fades up from.
		var view := scene.get_node_or_null("world")
		if view != null and get_tree().get_nodes_in_group(&"boot_page").is_empty():
			var here: Variant = view.call("chunk_at", view.get("focus"))
			var menu: Variant = scene.get("menu")
			var inked := menu is Object and menu.get("fade") is float and float(menu.get("fade")) > 0.5
			if here != null and (scene.name != &"title" or (int(view.call("pending")) == 0 and not inked)):
				break
		await get_tree().process_frame
	if not is_instance_valid(scene) or not scene.is_inside_tree():
		return
	await RenderingServer.frame_post_draw
	var now := Time.get_ticks_msec()
	print("boot ready %s %d ms (engine %d ms, main at %d ms)" % [scene.name, now - t0, now, _t0])
	if options.probe:
		var probe: Node = load("res://src/boot/web_probe.gd").new()
		probe.set("scene", scene)
		add_child(probe)


func _shoot() -> void:
	# Let a scripted walk finish, then settle.
	var game := get_node_or_null("game")
	if game != null:
		while float(game.get("scripted_seconds")) > 0.0:
			await get_tree().physics_frame
		var player: Node3D = game.get("player")
		game.get("view").call("ensure_near", player.get("pos"))
		game.get("camera").call("snap_to", player.position)
	for i in options.frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if options.scale > 1:
		img.resize(img.get_width() * options.scale, img.get_height() * options.scale, Image.INTERPOLATE_NEAREST)
	var path := options.shot
	if not path.is_absolute_path():
		path = ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("shot %s %s" % [path, "ok" if err == OK else "FAILED %d" % err])
	get_tree().quit(0 if err == OK else 1)
