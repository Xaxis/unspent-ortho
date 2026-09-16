extends GameSystem
## Tours: drive a real game through its real input and capture frames, in one run.
##   tools/tour.sh tours/first_minutes.tour        (or --tour=path on any boot)
##
## A tour is a text file, one command per line, `#` comments:
##   at X,Y                 teleport the player (tile space)
##   at prop:NAME           stand beside the nearest prop of that kind (PropKind.NAMES,
##                          a space written as _), facing it, in reach of `use`: a tour
##                          takes from the world without knowing where the world put it
##   village N              teleport beside village N
##   near KIND[,KIND]       stand beside the nearest prop of a kind, facing it
##   place NAME             teleport to a named place (GenPlaces: spawn, a country, an ecotone a-b, a landmark)
##   hour H                 set the world clock hour (same day)
##   weather KIND:S[:bolt]  force the sky as --weather does (`weather rules` hands it back)
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
##                          took (something was taken), strike (lightning flashed);
##                          folk, crowd, dog, gulls
##                          (people and animals: see src/systems/tour/tour_people.gd);
##                          and whatever a system answers for with tour_seen(what)
##                          (75_music: score, score_pad, score_pulse, score_tense,
##                          score_dissonance, score_grid, score_texture, score_phrase,
##                          score_resolve; and of the blend score_blend, score_here,
##                          score_in:LAND, score_full, score_unbroken)
##   walkto folk|dog|refuse SECS  walk to a villager the camera can see, a village dog,
##                          or within sight of a tip's gulls (tour_people.gd)
##   perf folk N SECS DRAWS MS  rendered cost of N villagers in view (tour_people.gd)
##   walkto mob|part|plate SECS  steer the real walk for up to SECS toward the
##                          nearest body (mob), round it to its working part (part)
##                          or to the plated side opposite (plate), re-aimed every
##                          step the way a player steers, ending turned to face it
##                          (nothing happens when no body is left)
##   choose ID              on an open page, tap move_down (the real key) until the
##                          row ID is chosen; fails if it never comes round
##   coast calm|wild        calm: clear the bodies about and stop new ones coming
##                          (so a scripted stretch is not a random fight); wild: resume
##   spawn KIND             put a roster body (e.g. runner, harvester) in view in
##                          front of the player, as --spawn does at boot
##   try N ... end          run the lines between up to N times until they all
##                          succeed (a player who misses a blow tries again)
##   echo TEXT              print a line to the log
##   key ACTION             a real key event for ACTION's first key, down then up: what
##                          pages that read input events need (the title)
##   same A B TOL [X,Y,W,H] shots A and B (already taken) differ by at most TOL, the mean
##                          per-channel difference 0..1, over the whole frame or only the
##                          rectangle given (shot pixels, 2x); fails otherwise and prints it
## A tour outlives the game it began in: when that game gives way to the title or
## to a loaded game, the runner stays at the tree's root and follows the next game.
## Awaits for that: title (the title is up, its coast drawn), game (a new game has
## started since the last action), saved (a save was written); and station:NAME
## (a station of that name, e.g. fire, is in reach of the player).
##   await title SECS       the title's slate has woken over its coast (a tour booted
##                          with --scene=title, or one whose game gave way to the title)
##   await game SECS        a new game has started since the last action (new game or
##                          Continue on the title, a load); every command after it drives it
##   await app:NAME SECS    the slate shows app NAME (inventory crafting map pause
##                          loadout reads saves), awake; app:none = no app is up
## Unknown commands fail the tour (exit 1) so a typo never passes silently.
## A tour booted on the title (--scene=title) is run by a runner main.gd puts
## beside the title; when new game starts, the game's own tour system hands the
## game to that runner instead of starting the tour again.
## Everything else (giving items, forcing weather) belongs to BootOptions flags
## on the boot, or to real play inside the tour.

var _lines: PackedStringArray = []
var _name := ""
var _out := ""
var _held: Array[String] = []
## Prop ids this tour has already stood at, so `near` moves on to the next one.
var _near_used: Dictionary = {}
## The node running the tour, while one runs; later games hand themselves to it.
static var _runner: Node = null
## Set when the tour began on the title.
var title: UiTitle


func setup(g: Game) -> void:
	super.setup(g)
	if is_instance_valid(_runner) and _runner != self:
		_runner.set("game", g)
		(_runner.get("_seen") as Dictionary)["game"] = true
		return
	_start()


## main.gd's hook: run the tour from the title, before any game exists.
func run_on_title(t: UiTitle) -> void:
	title = t
	name = "tour"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start()


func _start() -> void:
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
	_runner = self
	_run.call_deferred()


func _run() -> void:
	# Out from under the game, so the tour goes on when the game gives way.
	reparent(get_tree().root)
	_listen()
	# Let the first view settle.
	for i in 6:
		await get_tree().process_frame
	# The loading page draws the first frames of any start: a tour begins on the
	# world it is going to walk, not on the page over it.
	var lift := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < lift and not get_tree().get_nodes_in_group(&"boot_page").is_empty():
		await get_tree().process_frame
	# Open try blocks: [line index of `try`, attempts left].
	var tries: Array[Array] = []
	var li := -1
	while li + 1 < _lines.size():
		li += 1
		var n := li + 1
		var line := _lines[li].strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		var cmd := parts[0]
		if cmd == "try":
			if tries.is_empty() or tries.back()[0] != li:
				tries.append([li, maxi(1, parts[1].to_int() if parts.size() > 1 else 3) - 1])
			continue
		if cmd == "end":
			if not tries.is_empty():
				tries.pop_back()
			continue
		if not cmd in ["wait", "shot", "echo", "await", "same"]:
			_seen.clear()
		if not cmd in ["wait", "shot", "echo", "await", "tap", "press", "key", "same"] and not is_instance_valid(game):
			# On the title there is no game to walk or teleport yet.
			cmd = "no game"
		print("tour t=%.2fs fps=%d: %s" % [Time.get_ticks_msec() / 1000.0, Engine.get_frames_per_second(), line])
		var ok := true
		match cmd:
			"at":
				if parts[1].begins_with("prop:"):
					ok = _stand_by(parts[1].substr(5))
				else:
					var p := parts[1].split(",")
					_teleport(Vector2(p[0].to_float(), p[1].to_float()))
			"near":
				# Stand beside the nearest prop of a kind and face it, so a tour
				# proves work on real props instead of coordinates a new world moves.
				var want: Array[int] = []
				for name: String in parts[1].split(",", false):
					var ki := PropKind.NAMES.find(name.replace("_", " "))
					if ki >= 0:
						want.append(ki)
				var from: Vector2 = game.player.pos
				var found: WorldProp = null
				# The nearest one that still has work in it: a boulder already
				# picked over is no proof of anything.
				var best := INF
				for p2: WorldProp in game.query.props_near(from, 90.0):
					if not want.has(p2.kind):
						continue
					var d := from.distance_squared_to(p2.pos)
					if d >= best:
						continue
					if not _near_used.has(p2.id) and Survival.work_left(game, p2):
						best = d
						found = p2
				if found == null or want.is_empty():
					printerr("tour: no %s within reach of %s" % [parts[1], from])
					ok = false
				else:
					var off := (from - found.pos).normalized()
					if off.length() < 0.5:
						off = Vector2(1, 0)
					_near_used[found.id] = true
					_teleport(found.pos + off * (found.solid + 0.42))
					game.player.facing = (found.pos - game.player.pos).angle()
					if game.player.hero != null:
						game.player.hero.facing = game.player.facing
					await get_tree().physics_frame
					print("tour near %s: %s" % [parts[1], Survival.describe_target(game)])
			"place":
				var pp := GenPlaces.find(game.world, parts[1])
				if pp.x < 0.0:
					ok = false
				else:
					_teleport(pp)
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
			"weather":
				var sky_sys := _system("10_sky")
				ok = sky_sys != null and bool(sky_sys.call("apply_weather", parts[1]))
				if ok:
					sky_sys.call("_update", 0.0, true)
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
				if parts[1] in ["folk", "refuse", "dog"]:
					ok = await TourPeople.walk(self, game, parts[1], parts[2].to_float() if parts.size() > 2 else 1.0)
				else:
					ok = await _walk_to(parts[1], parts[2].to_float() if parts.size() > 2 else 1.0)
			"perf":
				ok = await TourPeople.perf(self, game, parts)
			"echo":
				print("tour: ", line.substr(5))
			"key":
				ok = await _key(parts[1])
			"same":
				ok = _same(parts[1], parts[2], parts[3].to_float() if parts.size() > 3 else 0.02, parts[4] if parts.size() > 4 else "")
			_:
				ok = false
		if not ok and not tries.is_empty() and int(tries.back()[1]) > 0:
			# A player who misses tries again: back to the top of the block.
			tries.back()[1] = int(tries.back()[1]) - 1
			print("tour %s line %d: '%s' did not come; trying the block again" % [_name, n, line])
			li = int(tries.back()[0])
			await get_tree().create_timer(0.6).timeout
			continue
		if not ok:
			printerr("tour %s line %d: cannot do '%s'" % [_name, n, line])
			# What the page showed when it failed, to see why.
			await _shot("FAILED-line%d" % n)
			get_tree().quit(1)
			return
	print("tour %s done -> %s" % [_name, _out])
	get_tree().quit(0)


## What the player could have seen happen since the last action command
## (anything but wait, shot, echo and await): what an await is satisfied by.
var _seen: Dictionary = {}


func _listen() -> void:
	Events.saved.connect(func(_slot: int, _reason: StringName) -> void: _seen["saved"] = true)
	Events.hit.connect(func(_a: Object, target: Object, damage: int, plate: bool, _at: Vector3) -> void:
		if plate:
			_seen["ring"] = true
		elif damage > 0 and is_instance_valid(game) and target == game.player:
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
	if what == "title":
		# Lit, and the coast faded up behind it.
		var t := title if is_instance_valid(title) else get_tree().root.find_child("title", true, false) as UiTitle
		return t != null and t.world != null and t.menu != null and t.menu.is_lit() and t.menu.fade < 0.05
	if not is_instance_valid(game):
		return false
	if what.begins_with("app:"):
		var ui := _system("90_ui")
		var top: UiScreen = ui.call("top") if ui != null else null
		var want := what.substr(4)
		return (top == null and want == "none") or (top != null and String(top.screen_name) == want and top.wake >= 1.0)
	if what.begins_with("station:"):
		return Survival.stations_near(game).has(StringName(what.trim_prefix("station:")))
	var sim := game.player.sim
	match what:
		"grip":
			return game.body.grip > 0
		"free":
			return game.body.grip <= 0
		"strike":
			var sky_sys := _system("10_sky")
			return sky_sys != null and float(sky_sys.get("since_strike")) < 0.2
		"tell":
			if sim == null:
				return false
			for m in sim.mobs:
				if m.alive and m.blow_phase(sim.now) == &"windup":
					return true
		"folk", "crowd", "dog", "gulls":
			return TourPeople.sees(game, what)
	for sys in game.systems:
		if sys.has_method("tour_seen") and bool(sys.call("tour_seen", what)):
			return true
	return false


## Stand beside the nearest standing prop of kind `name`, facing it, so `use`
## takes from it. Props move with the world (worldgen, the strand the spawn lays,
## what is built), so a tour names what it wants instead of the tile it lay on
## last month. It tries each way round until the prop is the thing under the hand:
## what the ruin left beside it can be nearer, and `use` takes what is in front.
func _stand_by(name: String) -> bool:
	var kind := PropKind.NAMES.find(name.replace("_", " "))
	if kind < 0:
		return false
	var best: WorldProp = null
	for q in game.query.props_near(game.player.pos, 60.0):
		if q.kind != kind or game.world.depleted.has(q.id):
			continue
		if best == null or q.pos.distance_to(game.player.pos) < best.pos.distance_to(game.player.pos):
			best = q
	if best == null:
		printerr("tour %s: no %s within 60 tiles of %s" % [_name, name, game.player.pos])
		return false
	var reach := best.solid + Tuning.PLAYER_RADIUS + 0.45
	for turn in 12:
		var a := TAU * turn / 12.0
		var spot := best.pos + Vector2.from_angle(a) * reach
		if not game.query.standable(floori(spot.x), floori(spot.y)):
			continue
		_teleport(spot)
		Survival.face(game, (best.pos - spot).angle())
		var t := Survival.use_target(game)
		if t != null and t.kind == kind:
			return true
	printerr("tour %s: nothing stands beside the %s at %s" % [_name, name, best.pos])
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
			# Nothing (left) to steer to: a body put down on the way is not a failure.
			break
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


## A real key event for the first key bound to `action`, held across whole frames.
func _key(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	for e in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k == null:
			continue
		var down := k.duplicate() as InputEventKey
		down.pressed = true
		Input.parse_input_event(down)
		for i in 3:
			await get_tree().process_frame
		await get_tree().physics_frame
		var up := k.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
		await get_tree().process_frame
		return true
	return false


func _same(a: String, b: String, tol: float, crop: String) -> bool:
	var ia := Image.load_from_file(_out.path_join(a + ".png"))
	var ib := Image.load_from_file(_out.path_join(b + ".png"))
	var rect := Rect2i()
	if crop != "":
		var c := crop.split(",")
		if c.size() != 4:
			return false
		rect = Rect2i(c[0].to_int(), c[1].to_int(), c[2].to_int(), c[3].to_int())
	var d := frame_difference(ia, ib, rect)
	print("tour %s: %s against %s%s differs by %.4f (at most %.4f)" % [_name, a, b, "" if crop == "" else " at " + crop, d, tol])
	return d <= tol


## Mean per-channel difference of two frames, 0 (the same) .. 1, over `rect`
## (the whole frame when empty); 1 when they cannot be compared (missing, not
## the same size, or the rectangle not inside them).
static func frame_difference(a: Image, b: Image, rect: Rect2i = Rect2i()) -> float:
	if a == null or b == null or a.is_empty() or a.get_size() != b.get_size():
		return 1.0
	if rect.has_area():
		if not Rect2i(Vector2i.ZERO, a.get_size()).encloses(rect):
			return 1.0
		a = a.get_region(rect)
		b = b.get_region(rect)
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var da := a.get_data()
	var db := b.get_data()
	var sum := 0
	for i in da.size():
		sum += absi(da[i] - db[i])
	return sum / (255.0 * da.size())


func _shot(label: String) -> void:
	if not is_instance_valid(game):
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_frame(label)
		return
	game.view.ensure_near(game.player.pos)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_frame(label)


func _save_frame(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var path := _out.path_join(label + ".png")
	img.save_png(path)
	print("tour shot ", path)
