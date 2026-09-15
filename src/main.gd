extends Node
## Entry point. Parses command-line options, boots the requested scene, and in
## --shot mode waits for the world to be built, captures one frame, and quits.

var options: BootOptions


func _ready() -> void:
	options = BootOptions.parse(OS.get_cmdline_user_args())
	# A player launching the game gets the title; tools always pass options.
	if OS.get_cmdline_user_args().is_empty():
		options.scene = "title"
	var root: Node
	match options.scene:
		"gallery":
			root = load("res://src/gallery.gd").new()
			add_child(root)
			root.call("setup", options)
		"title":
			root = UiTitle.new()
			add_child(root)
			(root as UiTitle).setup(options)
		_:
			var game := Game.new()
			game.name = "game"
			add_child(game)
			game.setup(options)
			root = game
	if root.get_parent() == null:
		add_child(root)
	if options.shot != "":
		_shoot()


func _shoot() -> void:
	# Let a scripted walk finish, then settle.
	var game := get_node_or_null("game") as Game
	if game != null:
		while game.scripted_seconds > 0.0:
			await get_tree().physics_frame
		game.view.ensure_near(game.player.pos)
		game.camera.snap_to(game.player.position)
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
