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
##   await WHAT SECS        wait until the player could see WHAT, or fail the tour
##                          after SECS: tell (a body winding up a blow), grip (held),
##                          free (no longer held), ring (a blow rang off plate),
##                          hit (a blow hurt a body), hurt (the player was struck),
##                          killed (a body went down), made (something was made),
##                          took (something was taken)
##   walkto mob|part|plate SECS  steer the real walk for up to SECS toward the
##                          nearest body (mob), round it to its working part (part)
##                          or to the plated side opposite (plate), re-aimed every
##                          step the way a player steers, ending turned to face it
##   choose ID              on an open page, tap move_down (the real key) until the
##                          row ID is chosen; fails if it never comes round
##   coast calm|wild        calm: clear the bodies about and stop new ones coming
##                          (so a scripted stretch is not a random fight); wild: resume
##   spawn KIND             put a roster body (e.g. runner, harvester) in view in
##                          front of the player, as --spawn does at boot
##   echo TEXT              print a line to the log
## Unknown commands fail the tour (exit 1) so a typo never passes silently.
## Everything else (giving items, forcing weather) belongs to BootOptions flags
## on the boot, or to real play inside the tour.

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
	_listen()
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
		if not cmd in ["wait", "shot", "echo", "await"]:
			_seen.clear()
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
			"await":
				ok = await _await(parts[1], parts[2].to_float() if parts.size() > 2 else 5.0)
			"spawn":
				ok = _spawn(StringName(parts[1]))
			"choose":
				ok = await _choose(StringName(parts[1]))
			"coast":
				ok = _coast(parts[1] == "calm")
			"walkto":
				ok = await _walk_to(parts[1], parts[2].to_float() if parts.size() > 2 else 1.0)
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


## What the player could have seen happen since the last action command
## (anything but wait, shot, echo and await): what an await is satisfied by.
var _seen: Dictionary = {}


func _listen() -> void:
	Events.hit.connect(func(_a: Object, target: Object, damage: int, plate: bool, _at: Vector3) -> void:
		if plate:
			_seen["ring"] = true
		elif damage > 0 and target == game.player:
			_seen["hurt"] = true
		elif damage > 0:
			_seen["hit"] = true)
	Events.killed.connect(func(_k: StringName, _at: Vector3) -> void: _seen["killed"] = true)
	Events.made.connect(func(_i: StringName, _n: int) -> void: _seen["made"] = true)
	Events.took.connect(func(_i: StringName, _n: int) -> void: _seen["took"] = true)


func _await(what: String, secs: float) -> bool:
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	var ok := _seen.has(what) or _now_true(what)
	while not ok and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		ok = _seen.has(what) or _now_true(what)
	_seen.erase(what)
	if not ok:
		printerr("tour %s: no %s within %.1f s" % [_name, what, secs])
	return ok


func _now_true(what: String) -> bool:
	var sim := game.player.sim
	match what:
		"grip":
			return game.body.grip > 0
		"free":
			return game.body.grip <= 0
		"tell":
			if sim == null:
				return false
			for m in sim.mobs:
				if m.alive and m.blow_phase(sim.now) == &"windup":
					return true
	return false


func _walk_to(what: String, secs: float) -> bool:
	var sim := game.player.sim
	if sim == null or not what in ["mob", "part", "plate"]:
		return false
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	var facing_mob: MobState = null
	while Time.get_ticks_msec() < until:
		var hero := sim.hero
		var best: MobState = null
		for m in sim.mobs:
			if m.alive and not m.removed and (best == null or m.pos.distance_to(hero.pos) < best.pos.distance_to(hero.pos)):
				best = m
		if best == null:
			return false
		var target := best.pos
		var close := best.radius + hero.radius + 0.5
		if what != "mob":
			var off := 0.0
			match best.part:
				&"back": off = PI
				&"left": off = -PI * 0.5
				&"right": off = PI * 0.5
			if what == "plate":
				off += PI
			target = best.pos + Vector2.from_angle(best.facing + off) * (best.radius + hero.radius + 0.45)
			close = 0.2
		facing_mob = best
		var d := target - hero.pos
		if d.length() <= close:
			break
		# Screen right is world (1,-1)/sqrt2 and screen down (1,1)/sqrt2.
		var dir := d.normalized()
		game.scripted_move = Vector2(dir.x - dir.y, dir.x + dir.y) * 0.7071
		game.scripted_run = false
		game.scripted_seconds = 0.05
		await get_tree().physics_frame
	game.scripted_seconds = 0.0
	if facing_mob != null:
		# Turned to it the way a player does: a touch of the key toward it.
		var dir := (facing_mob.pos - sim.hero.pos).normalized()
		game.scripted_move = Vector2(dir.x - dir.y, dir.x + dir.y) * 0.7071 * 0.2
		game.scripted_seconds = 0.02
		while game.scripted_seconds > 0.0:
			await get_tree().physics_frame
	return true


func _system(n: String) -> GameSystem:
	for sys in game.systems:
		if sys.name == n:
			return sys
	return null


func _choose(id: StringName) -> bool:
	var ui := _system("90_ui")
	if ui == null:
		return false
	for i in 40:
		var page: UiScreen = ui.call("top")
		if page == null:
			return false
		if page.menu.selected().get("id", &"") == id:
			return true
		Input.action_press("move_down")
		for f in 3:
			await get_tree().process_frame
		Input.action_release("move_down")
		for f in 3:
			await get_tree().process_frame
	return false


func _coast(calm: bool) -> bool:
	var mobs := _system("30_mobs")
	if mobs == null:
		return false
	var coast: Variant = mobs.get("coast")
	(coast as Object).set("spawning", not calm)
	if calm:
		game.player.sim.clear_mobs()
	return true


func _spawn(kind: StringName) -> bool:
	for sys in game.systems:
		if sys.name == "30_mobs" and sys.has_method("place_near_player"):
			return sys.call("place_near_player", Roster.resolve(String(kind))) != null
	return false


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
	# A jump is not a walk: the light of the place arrives at once, not eased
	# in from the far end of the island.
	var sky := _system("10_sky")
	if sky != null:
		sky.call("_update", 0.0, true)


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
