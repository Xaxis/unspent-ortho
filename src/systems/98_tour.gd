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
##   ground KIND[,KIND]     stand on the nearest tile of a ground (Ground.NAMES, a
##                          space written as _), so a tour that needs heather or
##                          moss under it says so instead of pinning a coordinate
##                          that the next change to worldgen quietly invalidates
##   place NAME             teleport to a named place (GenPlaces: spawn, a country, an ecotone a-b, a landmark)
##   hour H                 set the world clock hour (same day)
##   weather KIND:S[:bolt]  force the sky as --weather does (`weather rules` hands it back)
##   zoom F                 camera view height
##   walk DX,DY SECS [run]  hold a SCREEN direction for SECS (real input path)
##   press ACTION [SECS]    hold an input action (use, swing, dodge, inventory, craft, lamp, pause, map...)
##   hold ACTION            hold it down across the lines that follow (a stance: crouch)
##   release ACTION         let it go again
##   tap ACTION             press and release one frame later
##   wait SECS              let the world run
##   shot NAME [with SUBJECT[,SUBJECT]]
##                          save shots/tour/<tour>/<NAME>.png (2x nearest). `with`
##                          names what the frame is OF: each subject is waited for
##                          (up to SUBJECT_WAIT), and checked again the instant the
##                          frame is taken. A frame whose name claims a keeper and
##                          holds no keeper fails the tour instead of passing as
##                          evidence. Subjects are present tense — things that are
##                          in the world now (mob:KIND, folk, station:fire, app:map,
##                          a hazard, a pressure) — never events that happened
##                          (took, made, killed, hit: those are `await`, not `with`).
##                          pixels:RRGGBB[:N] asks the PICTURE instead: at least N
##                          pixels of that colour, for a subject the world cannot
##                          be asked about (a stolen neon tube is a handful of
##                          pixels of a hue nothing else on screen wears).
##   await WHAT SECS        wait until the player could see WHAT, or fail the tour
##                          after SECS: tell (a body winding up a blow), grip (held),
##                          free (no longer held), ring (a blow rang off plate),
##                          hit (a blow hurt a body), hurt (the player was struck),
##                          killed (a body went down), made (something was made),
##                          took (something was taken), strike (lightning flashed);
##                          mob (a live body in frame), mob:KIND (one of that kind:
##                          the roster id or its prefix, so mob:dog finds dog.yard),
##                          down:KIND (one of that kind in frame and not alive),
##                          body:KIND (either); lamp (the player's lamp is lit),
##                          land:ID (the landscape type under the player);
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
##                          front of the player, as --spawn does at boot; fails the
##                          tour when the roster has no such kind, when nothing was
##                          placed, or when what was placed landed outside the frame
##                          the camera is actually showing (which is the whole of
##                          what `in view` means to the frame that follows)
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
## The frame a `shot` just took, for the subjects that ask the picture itself.
var _last_frame: Image


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
					_near_used[found.id] = true
					ok = await _stand_at(found, parts[1])
			"ground":
				var want: Array[int] = []
				for gname: String in parts[1].split(",", false):
					var gi := Ground.NAMES.find(gname.replace("_", " "))
					if gi >= 0:
						want.append(gi)
				var gp := _ground_near(want)
				if gp == Vector2.INF:
					printerr("tour: no %s ground within reach of %s" % [parts[1], game.player.pos])
					ok = false
				else:
					_teleport(gp)
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
			"hold":
				# Held across the lines that follow, so a stance (crouch) or a
				# modifier can be on while the player walks, looks and shoots.
				Input.action_press(parts[1])
				if not _held.has(parts[1]):
					_held.append(parts[1])
				await get_tree().physics_frame
			"release":
				Input.action_release(parts[1])
				_held.erase(parts[1])
				await get_tree().physics_frame
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
				ok = await _shot_checked(parts)
			"await":
				ok = await _await(parts[1], parts[2].to_float() if parts.size() > 2 else 5.0)
			"spawn":
				ok = await _spawn(StringName(parts[1]))
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
			@warning_ignore("return_value_discarded")
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
	if what == "mob" or what.begins_with("mob:"):
		return _body_in_frame(what.substr(4), 1)
	if what.begins_with("down:"):
		return _body_in_frame(what.substr(5), -1)
	if what.begins_with("body:"):
		return _body_in_frame(what.substr(5), 0)
	if what == "lamp":
		return game.body.lamp_lit
	if what.begins_with("land:"):
		return BiomeRegistry.at(game.world, game.player.pos).id == StringName(what.substr(5))
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


## Put the player beside `found` with it under the hand, trying each way round
## as `at prop:` does. Standing next to a thing is not the same as having it in
## reach — what the ruin left beside it can be nearer, and `use` takes what is
## in front — so this stops when the prop really is the target, and fails
## otherwise rather than leaving the tour pressing use on empty air.
func _stand_at(found: WorldProp, said: String) -> bool:
	var reach := found.solid + Tuning.PLAYER_RADIUS + 0.42
	var away := (game.player.pos - found.pos).normalized()
	if away.length() < 0.5:
		away = Vector2(1, 0)
	for turn in 13:
		# The side the player is already on first, then round.
		var spot := found.pos + (away if turn == 0 else Vector2.from_angle(TAU * (turn - 1) / 12.0)) * reach
		if turn > 0 and not game.query.standable(floori(spot.x), floori(spot.y)):
			continue
		_teleport(spot)
		Survival.face(game, (found.pos - spot).angle())
		await get_tree().physics_frame
		var t := Survival.use_target(game)
		if t != null and t.id == found.id:
			print("tour near %s: %s" % [said, Survival.describe_target(game)])
			return true
	printerr("tour %s: stood all round the %s at %s and it never came under the hand" % [_name, said, found.pos])
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


## Put a body where the camera can see it, and say so out loud. A tour's next
## line is almost always a frame named after this body, so a spawn that quietly
## put nothing anywhere — or put it behind the camera — turns the tour into
## evidence of the opposite of what it claims (playtest wave A, finding 5).
func _spawn(kind: StringName) -> bool:
	var mobs := _system("30_mobs")
	if mobs == null or not mobs.has_method("place_near_player"):
		printerr("tour %s: no 30_mobs to spawn a %s" % [_name, kind])
		return false
	var id := Roster.resolve(String(kind))
	if id == &"":
		printerr("tour %s: the roster has no %s" % [_name, kind])
		return false
	# The spawner scores where a body lands by what the camera shows, and it read
	# the camera once, at setup. A tour that has zoomed since would have its body
	# placed for the frame it used to have.
	var spawner: Object = mobs.get("spawner")
	if spawner != null and game.camera != null:
		spawner.set("view_height", game.camera.view_height)
	var placed: Variant = mobs.call("place_near_player", id)
	var m := placed as MobState
	if m == null:
		printerr("tour %s: nothing placed a %s near %s" % [_name, kind, game.player.pos])
		return false
	# The node and its model are made on the next frames; the frustum test needs them.
	for i in 3:
		await get_tree().process_frame
	if not _in_frame(m.pos, 0.5):
		printerr("tour %s: the %s went to %s, outside the frame at the player (%s, zoom %.1f)"
			% [_name, kind, m.pos, game.player.pos, game.camera.view_height if game.camera != null else 0.0])
		return false
	print("tour spawn %s: %s at %s, %.1f tiles off, in frame" % [kind, m.kind, m.pos, m.pos.distance_to(game.player.pos)])
	return true


## Whether a tile-space spot, `lift` metres up, falls inside the frame the camera
## is drawing. The camera is the only authority on what a shot will contain.
func _in_frame(p: Vector2, lift: float) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(game):
		return false
	return cam.is_position_in_frustum(game.world.to_3d(p) + Vector3(0.0, lift, 0.0))


## A body in the frame, of `want` (a roster id, or the prefix before the dot:
## `mob:dog` finds dog.yard) or of any kind when it is empty. `life`: 1 alive
## (mob:), -1 down (down:), 0 either (body:) — a hulk on the ground is still
## the thing a frame named "down in daylight" is of.
func _body_in_frame(want: String, life: int) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var id := Roster.resolve(want) if want != "" else &""
	if want != "" and id == &"":
		printerr("tour %s: the roster has no %s" % [_name, want])
		return false
	for n: Node in get_tree().get_nodes_in_group(&"mobs"):
		var alive := bool(n.get("alive"))
		if (life > 0 and not alive) or (life < 0 and alive):
			continue
		if id != &"" and StringName(n.get("kind")) != id:
			continue
		var node3d := n as Node3D
		if node3d != null and cam.is_position_in_frustum(node3d.global_position + Vector3(0.0, 0.5, 0.0)):
			return true
	return false


## The nearest standable tile INSIDE a patch of one of these grounds, searched
## in rings out from the player, so `ground heath` is a fact about the world and
## not about one seed's coordinates. The whole PATCH square round it has to be
## that ground too: a tour that says it is down in the heather must be able to
## take a few steps in any direction and still be in it, or the frame it shoots
## proves the ground it happened to land on and nothing else.
const PATCH := 3

func _ground_near(want: Array[int]) -> Vector2:
	if want.is_empty():
		return Vector2.INF
	var from := game.player.pos
	var cx := floori(from.x)
	var cy := floori(from.y)
	for r in 90:
		for i in range(-r, r + 1):
			for p: Vector2i in [Vector2i(cx + i, cy - r), Vector2i(cx + i, cy + r),
					Vector2i(cx - r, cy + i), Vector2i(cx + r, cy + i)]:
				if game.query.standable(p.x, p.y) and _all_ground(want, p):
					return Vector2(p.x + 0.5, p.y + 0.5)
	return Vector2.INF


func _all_ground(want: Array[int], p: Vector2i) -> bool:
	for dy in range(-PATCH, PATCH + 1):
		for dx in range(-PATCH, PATCH + 1):
			if not want.has(game.world.ground_at(p.x + dx, p.y + dy)):
				return false
	return true


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


## Things that HAPPENED. A frame cannot hold one of these, so naming one as a
## shot's subject is a mistake worth failing on rather than passing silently.
const EVENTS := ["took", "made", "killed", "hit", "hurt", "ring", "strike", "saved", "theft", "turned"]
## How long a shot waits for the subjects it declares before giving up on them.
const SUBJECT_WAIT := 3.0
## How far a pixel may be from a `pixels:` colour and still count, per channel
## (0..255). Every lit colour is tinted by the hour and the weather through
## sky_apply(), so an exact match would only ever hold at one minute of one day.
const PIXEL_TOLERANCE := 40


## `shot NAME [with A,B]`. A tour's frames are the evidence every wave is read
## from, so a frame that claims a subject must hold it: each subject is waited
## for, and asked again the instant the shutter falls, because a body can die or
## walk out of the frame between the await and the picture.
func _shot_checked(parts: PackedStringArray) -> bool:
	var label := parts[1]
	var subjects: Array[String] = []
	if parts.size() > 2:
		if parts[2] != "with" or parts.size() < 4:
			printerr("tour %s: shot %s: expected `with SUBJECT[,SUBJECT]`" % [_name, label])
			return false
		var rest := " ".join(Array(parts).slice(3))
		for w: String in rest.split(",", false):
			subjects.append(w.strip_edges())
	for w: String in subjects:
		if EVENTS.has(w):
			printerr("tour %s: shot %s: `%s` happens, it is not something a frame holds; await it instead" % [_name, label, w])
			return false
		if w.begins_with("pixels:"):
			continue
		if not await _hold_true(w, SUBJECT_WAIT):
			printerr("tour %s: shot %s claims %s and the world has none" % [_name, label, w])
			return false
	if not await _shot(label):
		return false
	for w: String in subjects:
		if not (_pixels_held(w) if w.begins_with("pixels:") else _now_true(w)):
			# No frame that proves the opposite of its name is left on disk to be
			# read as evidence by whoever comes next.
			DirAccess.remove_absolute(_out.path_join(label + ".png"))
			printerr("tour %s: %s.png claims %s and does not hold it; the frame was thrown away" % [_name, label, w])
			return false
	if not subjects.is_empty():
		print("tour shot %s holds %s" % [label, ", ".join(subjects)])
	return true


## Wait for something to be true NOW (not for something to have happened): the
## only question a frame can answer.
func _hold_true(what: String, secs: float) -> bool:
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	while not _now_true(what):
		if Time.get_ticks_msec() >= until:
			return false
		await get_tree().physics_frame
	return true


## How long a shot will wait for the platform to draw a frame before it gives up
## and says so. frame_post_draw only fires on a frame that was really drawn, and
## a tool run's window is one pixel across in a corner of some display
## (project.godot, .editor): macOS sometimes stops asking it to draw at all, and
## then a tour used to sit in silence until its whole timeout ran out with no
## frames and no reason. A shot that waits at all says how long.
const DRAW_WAIT := 60.0
const DRAW_SLOW := 1.0


func _shot(label: String) -> bool:
	if is_instance_valid(game):
		game.view.ensure_near(game.player.pos)
	for i in 3:
		await get_tree().process_frame
	if not await _drawn():
		return false
	_save_frame(label)
	return true


## Wait for one drawn frame. False (and a line saying why) when the platform
## never drew one: the caller fails the tour rather than saving whatever stale
## pixels the viewport still holds, which would be the very thing this file
## exists to prevent — a frame that is not of the moment it is named for.
func _drawn() -> bool:
	var began := Time.get_ticks_msec()
	var until := began + int(DRAW_WAIT * 1000.0)
	var seen := [false]
	var mark := func() -> void: seen[0] = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	while not seen[0] and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	var waited := (Time.get_ticks_msec() - began) / 1000.0
	if not seen[0]:
		RenderingServer.frame_post_draw.disconnect(mark)
		printerr("tour %s: the window was not asked to draw for %.0f s, so there is no frame to take" % [_name, waited])
		return false
	if waited >= DRAW_SLOW:
		print("tour %s: waited %.1f s for a drawn frame" % [_name, waited])
	return true


func _save_frame(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	_last_frame = img
	var path := _out.path_join(label + ".png")
	img.save_png(path)
	print("tour shot ", path)


## `pixels:RRGGBB[:N]` — the frame just taken really carries at least N pixels of
## that colour (PIXEL_TOLERANCE per channel). The only subject that asks the
## picture instead of the world, for things the world cannot be asked about: a
## stolen neon tube is a handful of pixels of one hue and nothing else on screen
## is that hue, so this is what tells a frame that has one from a frame that
## claims one.
func _pixels_held(subject: String) -> bool:
	if _last_frame == null:
		return false
	var least := subject.split(":")[2].to_int() if subject.split(":").size() > 2 else 1
	var n := pixels_like(_last_frame, subject)
	print("tour %s: %s -> %d pixels (wanted %d)" % [_name, subject, n, least])
	return n >= least


## How many pixels of `img` are within PIXEL_TOLERANCE of any colour a
## `pixels:RRGGBB[+RRGGBB...][:N]` subject names. Static so the gate can hold it
## to a picture whose answer is known without running a game.
static func pixels_like(img: Image, subject: String) -> int:
	var parts := subject.split(":")
	if parts.size() < 2 or img == null or img.is_empty():
		return 0
	var wants: Array[Vector3i] = []
	for hex: String in parts[1].split("+", false):
		var c := Color.from_string("#" + hex, Color.BLACK)
		wants.append(Vector3i(int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)))
	var flat := img.duplicate() as Image
	flat.convert(Image.FORMAT_RGB8)
	var d := flat.get_data()
	var n := 0
	var i := 0
	while i < d.size():
		for w: Vector3i in wants:
			if absi(d[i] - w.x) <= PIXEL_TOLERANCE and absi(d[i + 1] - w.y) <= PIXEL_TOLERANCE and absi(d[i + 2] - w.z) <= PIXEL_TOLERANCE:
				n += 1
				break
		i += 3
	return n
