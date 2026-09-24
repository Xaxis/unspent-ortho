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

## While a play session is up, this file names its process id, so the focus
## guard (tools/_focus_guard.sh) can tell a person playing from a tool run.
const PLAY_MARK := "/tmp/unspent-playing"

var options: BootOptions
var _t0 := 0


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	options = BootOptions.parse(OS.get_cmdline_user_args())
	if not options.problems.is_empty():
		# Never a game made from options that were misread: it is a different
		# island at a different hour, and nothing on the screen says so.
		for p: String in options.problems:
			printerr("boot: %s" % p)
		get_tree().quit(2)
		return
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
	# reached (docs/DESIGN.md). A game booted straight from the command line is a new
	# game, and takes a configuration's start as the title's New game does.
	DevMode.boot(options, OS.get_cmdline_user_args())
	if options.scene == "game":
		GameConfig.fill_new_game(options, DevMode.explicit(OS.get_cmdline_user_args()))
	_take_focus_if_a_person_is_playing()
	# Named before the settings are applied, because applying them is what puts a
	# graphics tier in force (SettingsApply.quality) and a named tier beats both
	# doors. The root viewport already exists here, so the tier lands before the
	# first frame and before any scene is built.
	SettingsApply.quality_asked = options.quality
	_read_player_settings()
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


## Locally, a run of this project opens OFF the screen, unfocusable and silent
## (project.godot: no_focus and an initial_position far outside any display,
## both `.editor` so an exported build is untouched). That is the only way to
## cover every run: a tool script can be taught manners, but the ad-hoc run an
## agent writes for itself cannot, and there are a great many of those.
##
## A session a person means to play undoes all three here: the window comes back
## to the middle of their screen, takes the keyboard, and keeps its sound. That
## is a run with no tool arguments at all, one that says so with
## UNSPENT_KEEP_FOCUS=1, or any page in a browser.
## What the person at this keyboard has set, before anything is drawn or heard
## (src/settings/). A tool run reads them too — a shot of the settings page has
## to show the same page a player sees — but the window rows and the master mute
## are left alone for one, which SettingsApply decides for itself.
func _read_player_settings() -> void:
	# A shot or a tour keeps its own settings file: one that wrote the player's
	# would change what the next run of the game looked and sounded like.
	PlayerSettings.use_file(&"player" if _a_person_is_playing() else &"tool")
	# Installs the control scheme (ControlScheme) and then the player's own keys
	# over it, so a binding they changed still wins and a reset goes to the scheme.
	PlayerSettings.load_once()
	SettingsApply.install(_a_person_is_playing())


func _take_focus_if_a_person_is_playing() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not _a_person_is_playing():
		# Nobody is listening to this one, and on a machine running six builders
		# the sound of six games at once is its own kind of rudeness.
		if OS.get_environment("UNSPENT_SOUND") != "1":
			AudioServer.set_bus_mute(0, true)
		return
	var w := get_window()
	w.set_flag(Window.FLAG_NO_FOCUS, false)
	# Locally the window comes up one pixel across, so a person playing gets it
	# back to the size the game is meant to be looked at, in the middle of their
	# screen. An exported build already opens that way and is only centred here.
	# Two whole pixels to one of the SLATE's, which is 1280x720 — measured off
	# UiBase.DESIGN and not off the 1920x1080 base, or a player would be handed a
	# 3840x2160 window. The world still renders at the full base inside it.
	var want := SettingsApply.window_size(2)
	if w.size.x < want.x:
		w.size = want
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_PRIMARY)
	w.position = screen.position + (screen.size - w.size) / 2
	DisplayServer.window_move_to_foreground()
	w.grab_focus()
	# While this is up, the keyboard is the player's: tools/_focus_guard.sh reads
	# this mark and leaves a play session alone, where it would take the keyboard
	# straight back off a shot or a tour.
	var mark := FileAccess.open(PLAY_MARK, FileAccess.WRITE)
	if mark != null:
		mark.store_string(str(OS.get_process_id()))
		mark.close()


func _a_person_is_playing() -> bool:
	# A page in a browser is always somebody playing. "Has arguments" means a tool
	# run only for the Godot binary on this machine; on the web the arguments are
	# the address, and the shell lets through only what a visitor may pass
	# (--seed, --scene, --probe; never --shot or --tour). Reading them as a tool
	# run muted the master bus for anyone who opened a seed link, and for every
	# page tools/web.sh loads. The harness's browser is kept quiet by the browser
	# (Playwright's headless Chromium runs with --mute-audio), not by the game.
	if OS.has_feature("web"):
		return true
	# An exported build is somebody's copy of the game, however it was launched: the
	# commit that brought the mute in said this scheme must never touch one, and on
	# the web it did. Only a shot or a tour is still a tool run here, so a build a
	# tool proves stays quiet and a player who passes `--args -- --seed=3` hears it.
	if OS.has_feature("template") and options.shot == "" and options.tour == "":
		return true
	if OS.get_environment("UNSPENT_KEEP_FOCUS") == "1":
		return true
	if options.shot != "" or options.tour != "":
		return false
	return OS.get_cmdline_user_args().is_empty()


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
	# And again on the far side of that await: a scene can be taken down DURING
	# it. The title frees itself the moment it hands over to a loaded game, so
	# continuing a save raced this line and read `name` off a freed object —
	# which a tour sees as a SCRIPT ERROR and a player would see as a crash on
	# the ordinary way back into their game.
	if not is_instance_valid(scene) or not scene.is_inside_tree():
		return
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


func _exit_tree() -> void:
	# The pool is drained before the process is allowed to come apart, and this is
	# the last place that can be true of a game, a shot or a tour: the scene root
	# leaves the tree once, at the end, whichever of the six `quit()` doors was
	# taken. 90_ui drains too, but only while a game is up — a shot that quits
	# from the title, or a tour between games, goes out past it.
	#
	# BY PATH, not by class name, for the reason this file's header gives: naming
	# UiSketch here pulls the whole UI package into main.gd's compile, and that
	# lands before the Events autoload exists — measured, it took game.gd,
	# crafting.gd and survival.gd down with it as load errors.
	#
	# A sketch cannot be cancelled (WorkerThreadPool has no such call), so waiting
	# is the only way to end one, and the cost is the tail of one raster against a
	# process that is leaving anyway. Without it the main thread tears the
	# scripting language down with a worker still inside `_bake`, and it is a coin
	# toss: the worker reads freed memory and takes signal 11 in `_poly_of` — a
	# line that only reads an array — or the main thread blocks forever on
	# GDScript's own recursive lock, which the worker holds.
	(load("res://src/ui/ui_sketch.gd") as GDScript).call("wait")
	(load("res://src/ui/ui_slate.gd") as GDScript).call("wait")
	if FileAccess.file_exists(PLAY_MARK):
		var f := FileAccess.open(PLAY_MARK, FileAccess.READ)
		var whose := f.get_as_text().strip_edges() if f != null else ""
		if f != null:
			f.close()
		if whose == str(OS.get_process_id()):
			DirAccess.remove_absolute(PLAY_MARK)
