extends GameSystem
## Tours: drive a real game through its real input and capture frames, in one run.
##   tools/tour.sh tours/first_minutes.tour        (or --tour=path on any boot)
##
## A tour is a text file, one command per line, `#` comments:
##   at X,Y                 teleport the player (tile space)
##   village N              teleport beside village N
##   hour H                 set the world clock hour (same day)
##   zoom F                 camera view height
##   walk DX,DY SECS [run]  hold a SCREEN direction for SECS (real input path)
##   press ACTION [SECS]    hold an input action (use, swing, dodge, inventory, craft, lamp, pause, map...)
##   tap ACTION             press and release one frame later
##   wait SECS              let the world run
##   shot NAME              save shots/tour/<tour>/<NAME>.png (2x nearest)
##   echo TEXT              print a line to the log
## Unknown commands fail the tour (exit 1) so a typo never passes silently.
## Everything else (spawning machines, giving items) belongs to BootOptions flags
## on the first line's boot, or to real play inside the tour.

var _lines: PackedStringArray = []
var _name := ""
var _out := ""
var _held: Array[String] = []


func setup(g: Game) -> void:
	super.setup(g)
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tour="):
			path = a.trim_prefix("--tour=")
	if path == "":
		return
	var abs_path := path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		push_error("tour: cannot open %s" % abs_path)
		get_tree().quit(1)
		return
	_lines = f.get_as_text().split("\n")
	_name = abs_path.get_file().get_basename()
	_out = ProjectSettings.globalize_path("res://").path_join("shots/tour").path_join(_name)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	# Let the first view settle.
	for i in 6:
		await get_tree().process_frame
	var n := 0
	for raw in _lines:
		n += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		var cmd := parts[0]
		print("tour t=%.2fs fps=%d: %s" % [Time.get_ticks_msec() / 1000.0, Engine.get_frames_per_second(), line])
		var ok := true
		match cmd:
			"at":
				var p := parts[1].split(",")
				_teleport(Vector2(p[0].to_float(), p[1].to_float()))
			"village":
				var vi := parts[1].to_int()
				if vi < game.world.villages.size():
					_teleport((game.world.villages[vi].pos as Vector2) + Vector2(3, 3))
				else:
					ok = false
			"hour":
				var day := floorf(game.clock.minutes / 1440.0)
				game.clock.minutes = day * 1440.0 + parts[1].to_float() * 60.0
			"zoom":
				game.camera.view_height = parts[1].to_float()
			"walk":
				var d := parts[1].split(",")
				game.scripted_move = Vector2(d[0].to_float(), d[1].to_float())
				game.scripted_run = parts.size() > 3 and parts[3] == "run"
				game.scripted_seconds = parts[2].to_float()
				while game.scripted_seconds > 0.0:
					await get_tree().physics_frame
			"press":
				var secs := parts[2].to_float() if parts.size() > 2 else 0.25
				Input.action_press(parts[1])
				await get_tree().create_timer(secs).timeout
				Input.action_release(parts[1])
			"tap":
				# Hold across whole process AND physics frames, or a press made right
				# after a shot can be released before any system polls it.
				Input.action_press(parts[1])
				for i in 3:
					await get_tree().process_frame
				await get_tree().physics_frame
				Input.action_release(parts[1])
			"wait":
				await get_tree().create_timer(parts[1].to_float()).timeout
			"shot":
				await _shot(parts[1])
			"echo":
				print("tour: ", line.substr(5))
			_:
				ok = false
		if not ok:
			printerr("tour %s line %d: cannot do '%s'" % [_name, n, line])
			get_tree().quit(1)
			return
	print("tour %s done -> %s" % [_name, _out])
	get_tree().quit(0)


func _teleport(p: Vector2) -> void:
	# The fight body owns the player's place in a running game; move it too, or
	# the next step puts the player straight back.
	if game.player.hero != null:
		game.player.hero.pos = p
		game.player.hero.move = Vector2.ZERO
	game.player.pos = p
	game.player.position = game.world.to_3d(p)
	game.view.ensure_near(p)
	game.camera.snap_to(game.player.position)


func _shot(label: String) -> void:
	game.view.ensure_near(game.player.pos)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var path := _out.path_join(label + ".png")
	img.save_png(path)
	print("tour shot ", path)
