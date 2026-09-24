extends GameSystem
## Tours: drive a real game through its real input and capture frames, in one run.
##   tools/tour.sh tours/first_minutes.tour        (or --tour=path on any boot)
##
## A tour is a text file, one command per line, `#` comments:
##   at X,Y                 teleport the player (tile space)
##   at KIND:NAME           stand where a system says (`cast:maren`: beside a named person)
##   at prop:NAME           stand beside the nearest prop of that kind (PropKind.NAMES,
##                          a space written as _), facing it, in reach of `use`: a tour
##                          takes from the world without knowing where the world put it
##   village N              teleport beside village N
##   near KIND[,KIND]       stand beside the nearest prop of a kind, facing it; a
##                          name that is no prop kind is asked of the systems'
##                          `tour_place` (`near colossus_foot`: under an ankle)
##   ground KIND[,KIND]     stand on the nearest tile of a ground (Ground.NAMES, a
##                          space written as _), so a tour that needs heather or
##                          moss under it says so instead of pinning a coordinate
##                          that the next change to worldgen quietly invalidates
##   place NAME             teleport to a named place (GenPlaces: spawn, a country, an ecotone a-b, a landmark)
##   ledge up|across|down   stand, facing it, where a jump of that kind lands: the
##                          nearest spot `Jump.find` names, never a coordinate
##   leap SECS              walk the way the player FACES for SECS on the real move
##                          path and press the real jump key at the end of it, so a
##                          jump is taken on the move the way a player takes one
##   hour H                 set the world clock hour (same day)
##   weather KIND:S[:bolt][:wind=W]  force the sky as --weather does (`weather rules`
##                          hands it back); wind=W holds the wind at W, -1..1
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
##                          in the world now (mob:KIND, prop:KIND, folk,
##                          station:fire, app:map, a hazard, a pressure) — never
##                          events that happened (took, made, killed, hit: those
##                          are `await`, not `with`).
##                          pixels:RRGGBB[:N] asks the PICTURE instead: at least N
##                          pixels of that colour, for a subject the world cannot
##                          be asked about (a stolen neon tube is a handful of
##                          pixels of a hue nothing else on screen wears).
##   until WHAT SECS        let the world run and STOP the moment WHAT is true, or
##                          after SECS; never fails. `wait` is a promise about what
##                          the world will not do in that time, and a tour standing
##                          still in front of a hunter cannot make it: a watch ends
##                          when what is being watched changes (tours/wild.tour)
##   await WHAT SECS        wait until the player could see WHAT, or fail the tour
##                          after SECS: tell (a body winding up a blow), grip (held),
##                          free (no longer held), ring (a blow rang off plate),
##                          hit (a blow hurt a body), hurt (the player was struck),
##                          killed (a body went down), made (something was made),
##                          took (something was taken), strike (lightning flashed);
##                          slept (a night went by at a fire), skipped (any jump in
##                          world time: sleeping, eating, being carried off);
##                          mob (a live body in frame), mob:KIND (one of that kind:
##                          the roster id or its prefix, so mob:dog finds dog.yard),
##                          down:KIND (one of that kind in frame and not alive),
##                          body:KIND (either); on_round (a live body in frame and
##                          nothing in it aware of the player) / noticed (one in
##                          frame that HAS noticed) — what a frame of a machine at
##                          work claims, and what ends that watch;
##                          prop:KIND (a standing prop of that
##                          kind is in frame: a hulk, a fire tower, the pylon a
##                          frame is named after); lamp / unlit (the player's lamp
##                          is lit, or is not); land:ID (the landscape type under
##                          the player; `land:a|b` when either answer is honest,
##                          as a step out of an ecotone is; `land:surface` for any
##                          landscape that realm lays);
##                          border:A-B (the player is in the band between two
##                          landscape types, which is what an ecotone frame is of);
##                          swimming:KIND (a body of that kind is in frame and out
##                          of its depth: what a frame of something crossing is of),
##                          swimming (the body is in water over its head and
##                          taking it on its own: Swim), wading (it is in the
##                          shallows); folk, crowd, dog, gulls
##                          (people and animals: see src/systems/tour/tour_people.gd);
##                          and whatever a system answers for with tour_seen(what)
##                          (75_music: score, score_pad, score_pulse, score_tense,
##                          score_dissonance, score_grid, score_texture, score_phrase,
##                          score_resolve; and of the blend score_blend, score_here,
##                          score_in:LAND, score_full, score_unbroken)
##   walkto folk|dog|refuse SECS  walk to a villager the camera can see, a village dog,
##                          or within sight of a tip's gulls (tour_people.gd)
##   perf stats begin|end LABEL [raw]  the --stats block over just the lines between
##                          (tour/stats_perf.gd); needs --stats
##   perf folk N SECS DRAWS MS  rendered cost of N villagers in view (tour_people.gd)
##   perf fore SECS DRAWS MS    rendered cost of the foreground layer hanging over
##                          this frame, shown and hidden in turn (fore_perf.gd)
##   perf foliage SECS [MS]  rendered cost of every leaf card in the loaded chunks,
##                          shown and hidden in turn (foliage_perf.gd)
##   perf decor SECS [MS]    the same for every chunk's baked decor: grass, stones, litter
##   perf colour            what this renderer does to a value in ALBEDO (render_probe.gd)
##   perf features NAME     every expensive thing the frame has, off and on, world held
##                          still: which ones this renderer really draws (render_probe.gd)
##   perf scale LIST SECS   frame cost at each render scale in LIST (render_probe.gd)
##   walkto mob|part|plate SECS  steer the real walk for up to SECS toward the
##                          nearest body (mob), round it to its working part (part)
##                          or to the plated side opposite (plate), re-aimed every
##                          step the way a player steers, ending turned to face it
##                          (nothing happens when no body is left)
##   walkto shaft SECS      the same steering toward the nearest shaft, stopping
##                          inside its reach: a return BY NAME, where a timed walk
##                          back ends wherever the props on the way let it
##                          (realms.tour's did, once the scatter laid new props)
##   choose ID              on an open page, tap move_down (the real key) until the
##                          row ID is chosen; fails if it never comes round
##   coast calm|wild        calm: clear the bodies about and stop new ones coming
##                          (so a scripted stretch is not a random fight); wild: resume
##   spawn KIND[@DEG]       put a roster body (e.g. runner, harvester) in view in
##                          front of the player, as --spawn does at boot; fails the
##                          tour when the roster has no such kind, when nothing was
##                          placed, or when what was placed landed outside the frame
##                          the camera is actually showing (which is the whole of
##                          what `in view` means to the frame that follows).
##                          `@DEG` turns it to a bearing instead of facing the
##                          player, for a frame about the MODEL rather than the
##                          fight; a yaw out of test_machines_silhouette.gd is
##                          `@-yaw` (Spawner.staged says why)
##   try N ... end          run the lines between up to N times until they all
##                          succeed (a player who misses a blow tries again)
##   stale SLOT [WAY]       age a save this tour has already written into one from
##                          another build (SaveStaging): `version` (the default)
##                          takes it back to a file with no WorldStamp, what every
##                          save on a player's disk today is; `landscape` leaves
##                          the stamp and moves the ground under it. The one
##                          staging command that touches a file, because no boot
##                          flag can fake a save an older build wrote
##   echo TEXT              print a line to the log
##   mouse DX,DY [SECS]     move the mouse DX,DY screen pixels (right, down) over SECS
##                          (default 0.3) as real motion events, the way a hand turns
##                          the view over the shoulder (41_shoulder)
##   key ACTION             a real key event for ACTION's first key, down then up: what
##                          pages that read input events need (the title)
##   same A B TOL [X,Y,W,H] shots A and B (already taken) differ by at most TOL, the mean
##                          per-channel difference 0..1, over the whole frame or only the
##                          rectangle given (shot pixels, 2x); fails otherwise and prints it
##   same A B no_more_than C D [SLACK] [X,Y,W,H]
##                          the pair A,B differs no more than the pair C,D does
##                          (plus SLACK, default 0; either extra may come first,
##                          a crop being the one with commas in it). The honest
##                          form when the claim is "DOING this changed the picture
##                          no more than doing NOTHING did": an absolute bar there
##                          is pinned to how much the WORLD animates and not to
##                          what the action did, so it goes red for swaying tufts
##                          and says nothing about the action. Measured on
##                          sky-polish: the control pair sat at 0.0095 of a 0.010
##                          bar while the lamp it exists to measure sat at 0.0078,
##                          one noisy run from a red that would have taught nobody
##                          anything. A pair that cannot be compared at all fails
##                          BOTH forms rather than reading as equally broken.
## A tour outlives the game it began in: when that game gives way to the title or
## to a loaded game, the runner stays at the tree's root and follows the next game.
## Awaits for that: title (the title is up, its coast drawn), game (a new game has
## started since the last action), saved (a save was written), asked (`use` has
## asked where a fire would go and wants a second press); and station:NAME
## (a station of that name, e.g. fire, is in reach of the player).
##   await title SECS       the title's slate has woken over its coast (a tour booted
##                          with --scene=title, or one whose game gave way to the title)
##   await character SECS   the character page "new game" opens on the title is up
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
	_say_state("start")
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
		if not cmd in ["wait", "shot", "echo", "await", "tap", "press", "key", "same", "stale"] and not is_instance_valid(game):
			# On the title there is no game to walk or teleport yet.
			cmd = "no game"
		print("tour t=%.2fs fps=%d: %s" % [Time.get_ticks_msec() / 1000.0, Engine.get_frames_per_second(), line])
		var ok := true
		match cmd:
			"at":
				if parts[1].begins_with("prop:"):
					ok = _stand_by(parts[1].substr(5))
				elif parts[1].contains(":"):
					# KIND:NAME that a system owns (`cast:maren`): whichever answers
					# `tour_place` says where, so the runner knows no story names.
					ok = _stand_at_named(parts[1])
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
				# Not a kind of prop: something a system stands you by (`near
				# colossus_foot`, 19_colossi `tour_place`).
				if want.is_empty():
					ok = _stand_at_named(parts[1])
				else:
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
						# Work left in it, OR nothing can be done to it at all — a house
						# is not in the takes table, and `near house` means stand at
						# one. Said outright instead of leaning on work_left, which
						# answers true for a prop use_target will never offer.
						if _near_used.has(p2.id):
							continue
						if Survival.work_left(game, p2) or not Takes.workable(p2.kind):
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
			"ledge":
				var found := Jump.find(game.world, game.query, game.player.pos, StringName(parts[1]))
				if found.is_empty():
					printerr("tour: no %s jump within reach of %s" % [parts[1], game.player.pos])
					ok = false
				else:
					_teleport(found.at)
					var face: float = (found.dir as Vector2).angle()
					game.player.facing = face
					if game.player.hero != null:
						game.player.hero.facing = face
			"leap":
				# The screen direction that walks the way the player faces, for the
				# camera as it is right now: the tour holds a direction on the glass,
				# as a player does, never a world vector.
				var facing := Vector2.from_angle(game.player.facing)
				var yaw := deg_to_rad(game.camera.yaw_now())
				var up := Vector2(-sin(yaw), -cos(yaw))
				var right := Vector2(cos(yaw), -sin(yaw))
				game.scripted_move = Vector2(facing.dot(right), -facing.dot(up))
				game.scripted_run = false
				var walk_for := parts[1].to_float()
				game.scripted_seconds = walk_for + 0.2
				while game.scripted_seconds > 0.2:
					await get_tree().physics_frame
				Input.action_press("jump")
				for i in 3:
					await get_tree().process_frame
				await get_tree().physics_frame
				Input.action_release("jump")
				# Back to the tour at once: the next line is usually a frame of the
				# body in the air, and a jump is over in half a second.
				game.scripted_seconds = 0.0
			"place":
				var pp := GenPlaces.find(game.world, parts[1])
				if pp.x < 0.0:
					ok = false
				else:
					_teleport(pp)
			"village":
				var vi := parts[1].to_int()
				if vi < game.world.villages.size():
					_teleport(game.world.village_stand(game.world.villages[vi]))
				else:
					ok = false
			"hour":
				var day := floorf(game.clock.minutes / 1440.0)
				game.clock.minutes = day * 1440.0 + parts[1].to_float() * 60.0
			"zoom":
				# Through the view system, which owns the height and puts its own
				# value back every frame; writing the camera directly lasted one
				# frame. See 09_view.set_height.
				var view_sys := _system("09_view")
				if view_sys != null and view_sys.has_method(&"set_height"):
					view_sys.call(&"set_height", parts[1].to_float())
				else:
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
				# AND LET GO WHERE SOMETHING CAN SEE IT, for exactly the reason above
				# read backwards. Without this the release and the NEXT press land in
				# one frame, so anything watching for a rising edge never sees the key
				# come up and two taps of one key are one press. It cost a real frame:
				# `tours/story.tour` tapped `move_down` twice to reach the third reply,
				# moved once, and shot `03-said-nothing` showing the keeper answering
				# the SECOND reply — green, and proving the opposite of its own name.
				# Thirteen sites across eleven tours were written against the broken
				# behaviour; they are listed in the task and re-run with this.
				await get_tree().process_frame
				await get_tree().physics_frame
			"wait":
				await get_tree().create_timer(parts[1].to_float()).timeout
			"shot":
				ok = await _shot_checked(parts)
			"await":
				ok = await _await(parts[1], parts[2].to_float() if parts.size() > 2 else 5.0)
			"until":
				await _until(parts[1], parts[2].to_float() if parts.size() > 2 else 5.0)
			"spawn":
				ok = await _spawn(parts[1])
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
				if parts.size() > 1 and parts[1] == "fore":
					ok = await ForePerf.perf(self, game, parts)
				elif parts.size() > 1 and parts[1] == "stats":
					ok = (preload("res://src/systems/tour/stats_perf.gd")).perf(self, game, parts)
				elif parts.size() > 1 and parts[1] == "lens":
					ok = await (preload("res://src/systems/tour/lens_perf.gd")).perf(self, game, parts)
				elif parts.size() > 1 and parts[1] in FoliagePerf.LAYERS:
					ok = await FoliagePerf.perf(self, game, parts)
				elif parts.size() > 1 and parts[1] in RenderProbe.KINDS:
					ok = await RenderProbe.run(self, game, parts)
				else:
					ok = await TourPeople.perf(self, game, parts)
			"stale":
				var why := SaveStaging.age(SaveSlots.path(parts[1].to_int()),
					StringName(parts[2]) if parts.size() > 2 else &"version")
				if why != "":
					printerr("tour: stale %s: %s" % [parts[1], why])
				ok = why == ""
			"echo":
				print("tour: ", line.substr(5))
			"key":
				ok = await _key(parts[1])
			"mouse":
				var md := parts[1].split(",")
				await _mouse(Vector2(md[0].to_float(), md[1].to_float()),
					parts[2].to_float() if parts.size() > 2 else 0.3)
			"same":
				if parts.size() > 5 and parts[3] == "no_more_than":
					# SLACK and the crop are both optional and either may come
					# first: the crop is the one with commas in it, so a crop
					# written without a slack can never be read as a slack of 0.
					var slack := 0.0
					var crop := ""
					for i in range(6, parts.size()):
						if parts[i].contains(","):
							crop = parts[i]
						else:
							slack = parts[i].to_float()
					ok = _no_more_than(parts[1], parts[2], parts[4], parts[5], slack, crop)
				else:
					ok = _same(parts[1], parts[2], parts[3].to_float() if parts.size() > 3 else 0.02, parts[4] if parts.size() > 4 else "")
			_:
				ok = false
		if not ok and not tries.is_empty() and int(tries.back()[1]) > 0:
			# A player who misses tries again: back to the top of the block.
			tries.back()[1] = int(tries.back()[1]) - 1
			print("tour %s line %d: '%s' did not come; trying the block again" % [_name, n, line])
			_say_state("retry")
			li = int(tries.back()[0])
			await get_tree().create_timer(0.6).timeout
			continue
		if not ok:
			printerr("tour %s line %d: cannot do '%s'" % [_name, n, line])
			_say_state("failed")
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
	# A frame named for a night gone by is the one thing the picture cannot show
	# on its own: dawn looks like dusk. core_loop's "16-slept-to-morning" was a
	# picture of 22:05 with the footer still offering `e fire - sleep`.
	Events.time_skipped.connect(func(_m: float, reason: StringName) -> void:
		_seen["skipped"] = true
		if reason == &"sleep":
			_seen["slept"] = true)


## How much slower this machine is than an idle one, 1.0 to 8.0.
##
## A tour's budgets bound "it never came" — they are not a measure of how fast
## the world opens. With a wave's worth of tours running one after another a
## world can take three times as long to open as it does on a quiet laptop, and
## a budget that does not stretch turns that into a failed proof and a frame
## thrown away: exactly the trap `test_exit` fell into with a frame count, one
## commit before this one. Mirrors `TestCase.machine_slack()`; `src` must not
## depend on `tests`, so the arithmetic is deliberately written in both places.
static func machine_slack() -> float:
	if _slack > 0.0:
		return _slack
	_slack = 1.0
	var load := 0.0
	if FileAccess.file_exists("/proc/loadavg"):
		var f := FileAccess.open("/proc/loadavg", FileAccess.READ)
		if f != null:
			load = float(f.get_line().split(" ")[0])
	# A page cannot start a process (tools/web.sh --tour): it asks nothing, and
	# the budgets stay as written.
	if load <= 0.0 and not OS.has_feature("web"):
		var out: Array = []
		if OS.execute("sysctl", ["-n", "vm.loadavg"], out) == 0 and not out.is_empty():
			# { 50.49 60.10 63.36 }
			var parts := String(out[0]).replace("{", "").replace("}", "").strip_edges().split(" ", false)
			if not parts.is_empty():
				load = float(parts[0])
	if load > 0.0:
		_slack = clampf(load / float(maxi(1, OS.get_processor_count())), 1.0, 8.0)
	return _slack


static var _slack := 0.0


## `until WHAT SECS` — the honest opposite of `await`: let the world run, and
## stop the moment WHAT is true or SECS have passed, whichever comes first. It
## never fails.
##
## `wait` is a promise about what the world will NOT do in that time, and a tour
## that stands still for thirteen seconds in front of a hunter is making a
## promise the world does not keep: `tours/wild.tour` failed about one run in
## three that way, and every frame after the machine looked up was also a lie
## about its own subject. A watch that ends when the thing being watched changes
## is what a player does, and it is what a tour should write.
func _until(what: String, secs: float) -> void:
	var stop := Time.get_ticks_msec() + int(secs * 1000.0 * machine_slack())
	while not _answered(what) and Time.get_ticks_msec() < stop:
		await get_tree().physics_frame
	_forget(what)


func _await(what: String, secs: float) -> bool:
	var until := Time.get_ticks_msec() + int(secs * 1000.0 * machine_slack())
	var ok := _answered(what)
	while not ok and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		ok = _answered(what)
	_forget(what)
	if not ok:
		printerr("tour %s: no %s within %.1f s%s" % [_name, what, secs, _instead(what)])
	return ok


## AN AWAIT MEANS SINCE I LAST ASKED. A question that has been answered is spent,
## here and in every system that keeps a latch of its own — the runner's `_seen`
## was always consumed, but the erase reached this dictionary and no further, so
## a system's latch answered every later await for free.
##
## That is how machine-read.tour hid a real bug for two waves: its night theft
## pressed `use` once where a survey post needs three, so nothing was robbed and
## no machine turned, and `await theft` passed anyway off a theft earlier in the
## run. Only the runner knows when a tour asked a question, so only the runner
## can spend the answer.
func _forget(what: String) -> void:
	_seen.erase(what)
	if not is_instance_valid(game):
		return
	for sys in game.systems:
		sys.tour_forget(StringName(what))


## Answered when the word has been seen, or is true now — except `game`, which
## is set the moment the systems are wired and so is already true while the
## loading page is still drawn over the whole screen. A tour that awaits a game
## means the game a player can SEE, so it waits for the page to lift, the same
## thing main.gd's own ready line waits for. Without this, continuing a save
## photographed the loading page at 98% and called it the world that came back.
func _answered(what: String) -> bool:
	if not (_seen.has(what) or _now_true(what)):
		return false
	if what == "game":
		return get_tree().get_nodes_in_group(&"boot_page").is_empty()
	return true


func _now_true(what: String) -> bool:
	if what == "character":
		# The character page is up on the title and awake.
		var tc := title if is_instance_valid(title) else get_tree().root.find_child("title", true, false) as UiTitle
		return tc != null and tc.character != null and tc.character.is_open and tc.character.wake >= 1.0
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
	# The fire's FIRST press: `use` has asked where it would go and is waiting for
	# a second. Read live off `Survival.build_asked` rather than latched, because
	# the ask expires on its own and a latch would go on saying yes after it had.
	# It is here because a frame called "asked where" was a picture of the player
	# picking up a stone -- the press had answered a pebble in reach, which is the
	# key working correctly, and nothing in the tour could tell.
	if what == "asked":
		return Survival.build_asked(game).is_finite()
	if what == "mob" or what.begins_with("mob:"):
		return _body_in_frame(what.substr(4), 1)
	# What a body in frame has made of the player, which is the difference between
	# watching a machine work and standing in front of a hunter: `on_round` is a
	# live body in frame and nothing aware of you, `noticed` is one that has you.
	if what == "noticed" or what == "on_round":
		var seen := false
		for n: Node in get_tree().get_nodes_in_group(&"mobs"):
			if not bool(n.get("alive")) or not _in_frame(n.get("pos") as Vector2, 0.5):
				continue
			seen = true
			if bool(n.get("aware")):
				return what == "noticed"
		return seen and what == "on_round"
	if what.begins_with("down:"):
		return _body_in_frame(what.substr(5), -1)
	if what.begins_with("body:"):
		return _body_in_frame(what.substr(5), 0)
	if what == "lamp":
		return game.body.lamp_lit
	if what == "unlit":
		return not game.body.lamp_lit
	if what.begins_with("swimming:"):
		# A body of that kind, alive, in frame and out of its depth: what a frame
		# of something crossing the water is actually of (Swim).
		var kind := Roster.resolve(what.substr(9))
		for n: Node in get_tree().get_nodes_in_group(&"mobs"):
			if not bool(n.get("alive")) or (kind != &"" and StringName(n.get("kind")) != kind):
				continue
			if Swim.deep(game.world, n.get("pos")) and _body_in_frame(what.substr(9), 1):
				return true
		return false
	if what == "talking" or what == "reading" or what.begins_with("knows:") or what.begins_with("beat:"):
		# The story answers for itself (49_story.tour_seen), and a frame of a
		# conversation is a frame of one whether or not anybody is in shot.
		for sys in game.systems:
			if sys.has_method("tour_seen") and bool(sys.call("tour_seen", StringName(what))):
				return true
		return false
	if what == "swimming":
		# In water over the head and taking it under its own steam (Swim): a
		# present-tense fact about the body, which is what a  claim is for.
		return game.player.swimming
	if what == "wading":
		return Ground.is_shallow(game.world.ground_at(floori(game.player.pos.x), floori(game.player.pos.y)))
	if what.begins_with("land:"):
		# `land:a|b` for a frame taken where either answer is honest: a walk out
		# of an ecotone lands in one of the two, and which one is a fact about
		# one seed's border, not about what the frame is showing.
		#
		# A REALM's name stands for every landscape that realm lays (`land:surface`):
		# the ground itself says which world the player is in, where `realm:` only
		# reads 20_realms' flag. A hand-written list of the landscapes a shaft might
		# come up in named eight of twenty-one and went red on the first shaft that
		# rose anywhere newer.
		var def := BiomeRegistry.at(game.world, game.player.pos)
		for id: String in what.substr(5).split("|", false):
			if def.id == StringName(id):
				return true
			if Realm.KINDS.has(StringName(id)) and def.realms.has(Realm.land_realm(StringName(id))):
				return true
		return false
	if what.begins_with("border:"):
		return _on_border(what.substr(7))
	if what.begins_with("prop:"):
		return _prop_in_frame(what.substr(5))
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
func _stand_at_named(what: String) -> bool:
	for sys in game.systems:
		if not sys.has_method(&"tour_place"):
			continue
		var p: Vector2 = sys.call(&"tour_place", what)
		if p != Vector2.INF:
			_teleport(p)
			# And facing what it stood you by, where the system says which way that is.
			if sys.has_method(&"tour_face"):
				var toward: float = sys.call(&"tour_face", what)
				if not is_nan(toward):
					Survival.face(game, toward)
					# Over the shoulder the view stands behind the body it faces.
					if game.camera != null:
						game.camera.shoulder_yaw = (load("res://src/core/view/shoulder.gd") as GDScript).call(&"yaw_behind", toward)
			return true
	printerr("tour %s: nothing answers at %s" % [_name, what])
	return false


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
	# A station is not something you take from, so `use_target` never names one:
	# what "at the fire" means for a fire, a bench or a kiln is being inside
	# crafting reach of it, which is the same question `station:NAME` asks. A
	# tour that stands where it laid a fire and then claims `station:fire` was
	# failing two runs in three on a hard-coded spot 1.6 tiles out.
	var station: Array = Survival.STATION_KINDS.get(kind, [])
	var reach := best.solid + Tuning.PLAYER_RADIUS + 0.45
	for turn in 12:
		var a := TAU * turn / 12.0
		var spot := best.pos + Vector2.from_angle(a) * reach
		if not game.query.standable(floori(spot.x), floori(spot.y)):
			continue
		_teleport(spot)
		Survival.face(game, (best.pos - spot).angle())
		if not station.is_empty():
			if Survival.stations_near(game).has(StringName(station[0])):
				return true
			continue
		var t := Survival.use_target(game)
		if t != null and t.kind == kind:
			return true
		# A thing with something written on it is a use target too now, and
		# survival's own use_target never names one: it only ever offered what
		# could be WORKED (src/systems/49_story.gd, docs/STORY.md).
		if StoryProps.readable(kind) and best.pos.distance_to(game.player.pos) - best.solid <= StoryProps.REACH:
			return true
	printerr("tour %s: nothing stands beside the %s at %s" % [_name, name, best.pos])
	return false


## Put the player beside `found` with it under the hand, trying each way round
## as `at prop:` does. Standing next to a thing is not the same as having it in
## reach — what the ruin left beside it can be nearer, and `use` takes what is
## in front — so this stops when the prop really is the target, and fails
## otherwise rather than leaving the tour pressing use on empty air.
func _stand_at(found: WorldProp, said: String) -> bool:
	# Stand inside the reach that is ACTUALLY in force. Survival measures reach
	# from the prop's edge and halves it in the dark (DARK_REACH 0.6), while a
	# fixed gap of PLAYER_RADIUS + 0.42 puts the player 0.70 out — so every
	# `near` in a tour set at night stood just outside the hand and failed,
	# whatever it was standing at. Found by machine-read.tour, whose whole
	# second half is at 23:00.
	var hand := Survival.DARK_REACH if Survival.in_the_dark(game) else Survival.REACH
	# A prop nothing can be done TO is one a tour stands beside to look at: a
	# house is not in the takes table, so it can never be a use target, and
	# asking for one is asking for something the game cannot give. Standing
	# against it and facing it is the whole of what `near house` ever meant.
	var only_looked_at := not Takes.workable(found.kind)
	# Two ways of standing, in the order a player would: at arm's length, and
	# then pressed right up against it. `use_target` scores by the edge a thing
	# is from, so in a works field thick with what the ruin left, a survey at
	# arm's length loses to a scrap of plate nearer the boot and `near survey`
	# fails standing directly in front of one. Pressed against it, nothing but
	# an overlapping prop can outscore it. Found by machine-read.tour line 143,
	# among the thousand-odd evidence props a works lays down.
	var gaps: Array[float] = [
		minf(Tuning.PLAYER_RADIUS + 0.42, hand - 0.08),
		Tuning.PLAYER_RADIUS + 0.02,
	]
	var away := (game.player.pos - found.pos).normalized()
	if away.length() < 0.5:
		away = Vector2(1, 0)
	var reach := found.solid
	for gap: float in gaps:
		reach = found.solid + maxf(gap, 0.05)
		for turn in 13:
			# The side the player is already on first, then round.
			var spot := found.pos + (away if turn == 0 else Vector2.from_angle(TAU * (turn - 1) / 12.0)) * reach
			if turn > 0 and not game.query.standable(floori(spot.x), floori(spot.y)):
				continue
			_teleport(spot)
			Survival.face(game, (found.pos - spot).angle())
			await get_tree().physics_frame
			if only_looked_at:
				if game.player.pos.distance_to(found.pos) <= reach + 0.35:
					print("tour near %s: standing at it (nothing to do to a %s)" % [said, said])
					return true
				continue
			var t := Survival.use_target(game)
			if t != null and t.id == found.id:
				print("tour near %s: %s" % [said, Survival.describe_target(game)])
				return true
	printerr("tour %s: stood all round the %s at %s and it never came under the hand (reach %.2f, edge %.2f)"
		% [_name, said, found.pos, hand, reach - found.solid])
	return false


## Every `walkto` target, the one list: `tests/tours/test_tour_claims.gd` reads it,
## so a new target cannot be written into a tour and refused by a stale copy.
const WALK_TARGETS: Array[String] = ["folk", "dog", "refuse", "mob", "part", "plate", "shaft"]


func _walk_to(what: String, secs: float) -> bool:
	var sim := game.player.sim
	if sim == null or not what in ["mob", "part", "plate", "shaft"]:
		return false
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	if what == "shaft":
		while Time.get_ticks_msec() < until:
			var shaft := Portals.nearest(game.world, sim.hero.pos)
			if shaft == null:
				return false
			var d := shaft.pos - sim.hero.pos
			# Well inside the reach, so a step's overshoot cannot carry it back out.
			if d.length() <= Portal.REACH * 0.6:
				game.scripted_seconds = 0.0
				return true
			var dir := d.normalized()
			game.scripted_move = _keys_toward(dir)
			game.scripted_run = false
			game.scripted_seconds = 0.05
			await get_tree().physics_frame
		game.scripted_seconds = 0.0
		printerr("tour %s: walked toward the nearest shaft for %.1f s and it never came into reach" % [_name, secs])
		return false
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
		var dir := d.normalized()
		game.scripted_move = _keys_toward(dir)
		game.scripted_run = false
		game.scripted_seconds = 0.05
		await get_tree().physics_frame
	game.scripted_seconds = 0.0
	if facing_mob != null:
		# Turned to it the way a player does: a touch of the key toward it.
		var dir := (facing_mob.pos - sim.hero.pos).normalized()
		game.scripted_move = _keys_toward(dir) * 0.2
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
func _spawn(token: String) -> bool:
	var mobs := _system("30_mobs")
	if mobs == null or not mobs.has_method("place_near_player"):
		printerr("tour %s: no 30_mobs to spawn a %s" % [_name, token])
		return false
	var staged := Spawner.staged(token)
	var id: StringName = staged.id
	var kind := token
	if id == &"":
		printerr("tour %s: the roster has no %s" % [_name, token])
		return false
	# The spawner scores where a body lands by what the camera shows, and it read
	# the camera once, at setup. A tour that has zoomed since would have its body
	# placed for the frame it used to have.
	var spawner: Object = mobs.get("spawner")
	if spawner != null and game.camera != null:
		spawner.set("view_height", game.camera.view_height)
	var placed: Variant = mobs.call("place_near_player", id, staged.facing)
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


## `border:A-B` — the player stands in the transition band between landscape
## types A and B (the `WorldData.country2`/`blend` contract worldgen writes).
## An ecotone frame is OF a border, and `land:` cannot say so: on the band
## either type is the answer, so "coast-moss" declaring `land:coast` would pass
## or fail on which side of one tile the walk happened to stop.
func _on_border(pair: String) -> bool:
	var ids := pair.split("-", false)
	if ids.size() != 2:
		printerr("tour %s: border:%s wants two landscape ids joined by a dash" % [_name, pair])
		return false
	var w := game.world
	var x := floori(game.player.pos.x)
	var y := floori(game.player.pos.y)
	if not w.in_bounds(x, y):
		return false
	var i := y * w.size + x
	if w.blend[i] <= 0.0:
		return false
	var want := [BiomeRegistry.index_of(StringName(ids[0])), BiomeRegistry.index_of(StringName(ids[1]))]
	if want.has(-1):
		printerr("tour %s: no landscape type in border:%s" % [_name, pair])
		return false
	var have := [int(w.country[i]), int(w.country2[i])]
	want.sort()
	have.sort()
	return want == have


## A standing prop of kind `name` (PropKind.NAMES, a space written as _) inside
## the frame the camera is drawing. Half the landscape tour's frames are OF a
## thing the world put somewhere — a hulk on the sand, a fire tower over the
## pines, the pylon the score's grid layer comes from — and until this existed
## the vocabulary could not say so, so those frames were unguarded by
## construction: `place` puts the camera where the landmark was recorded, and
## nothing asked whether the landmark was still there when the shutter fell.
func _prop_in_frame(name: String) -> bool:
	var kind := PropKind.NAMES.find(name.replace("_", " "))
	if kind < 0:
		printerr("tour %s: no prop kind %s" % [_name, name])
		return false
	for q in game.query.props_near(game.player.pos, PROP_SIGHT):
		if q.kind != kind or game.world.depleted.has(q.id):
			continue
		if _in_frame(q.pos, 0.5):
			return true
	return false

## How far out a `prop:` subject looks. The camera at the fight zoom shows about
## 20 tiles; at the widest a tour sets, nearer 60.
const PROP_SIGHT := 90.0


## The nearest standable tile INSIDE a patch of one of these grounds, searched
## in rings out from the player, so `ground heath` is a fact about the world and
## not about one seed's coordinates. The whole PATCH square round it has to be
## that ground too: a tour that says it is down in the heather must be able to
## take a few steps in any direction and still be in it, or the frame it shoots
## proves the ground it happened to land on and nothing else.
const PATCH := 3

## Ground of one of `want`, nearest first — and by preference with nothing on it
## that the hand would rather take.
##
## `ground` exists so a tour can stand on OPEN ground and press use. But `use`
## takes the nearest thing in reach, so a grass tile with a bench beside it
## answers "bench - make" and the fire the tour came to lay is never laid: that
## is tours/saves line 17, in a spawn village the houses work made busier. The
## fallback keeps a tour that only wants to stand on a kind of ground working
## where there is no clear tile at all, and says so rather than pretending.
func _ground_near(want: Array[int]) -> Vector2:
	if want.is_empty():
		return Vector2.INF
	for clear_only: bool in [true, false]:
		var p := _ground_ring(want, clear_only)
		if p != Vector2.INF:
			if not clear_only:
				printerr("tour %s: no %s clear of props near %s; standing on %s with something in reach"
					% [_name, Ground.NAMES[want[0]], game.player.pos, p])
			return p
	return Vector2.INF


func _ground_ring(want: Array[int], clear_only: bool) -> Vector2:
	var from := game.player.pos
	var cx := floori(from.x)
	var cy := floori(from.y)
	for r in 90:
		for i in range(-r, r + 1):
			for p: Vector2i in [Vector2i(cx + i, cy - r), Vector2i(cx + i, cy + r),
					Vector2i(cx - r, cy + i), Vector2i(cx + r, cy + i)]:
				# The player is the body being staged and the player can swim, so
				# deep water is a place to stand a tour on now (Swim).
				if not game.query.standable(p.x, p.y, null, true) or not _all_ground(want, p):
					continue
				var spot := Vector2(p.x + 0.5, p.y + 0.5)
				if clear_only and not _hand_is_empty_at(spot):
					continue
				return spot
	return Vector2.INF


## Nothing at all standing at `spot`: not a thing to gather, not a station, not
## the corner of a house. Open ground means open, because `use` on it falls back
## through eat and sleep to laying a fire, and that last one wants a clear spot
## as well as an empty hand — a bench 1.6 tiles off is enough to answer the key
## with "bench - make" and lay nothing.
func _hand_is_empty_at(spot: Vector2) -> bool:
	var clear := Survival.STATION_REACH + 0.6
	for q: WorldProp in game.query.props_near(spot, clear + 3.0):
		if game.world.depleted.has(q.id):
			continue
		if spot.distance_to(q.pos) - q.solid <= clear:
			return false
	return true


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
	# Say it was a warp, so nothing goes on showing what was true where we left.
	# Every reference frame in the canon carried the last place's message line
	# under the new place's badge before this (#101).
	Events.warped.emit(p)


## A real key event for the first key bound to `action`, held across whole frames.
## Motion events, spread over whole frames, through the engine's own input queue:
## whatever reads the mouse reads these exactly as it reads a hand.
func _mouse(by: Vector2, secs: float) -> void:
	var left := secs
	var sent := Vector2.ZERO
	while true:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		left -= dt
		var share := clampf(1.0 - left / maxf(secs, 1e-3), 0.0, 1.0)
		var step := by * share - sent
		sent += step
		var ev := InputEventMouseMotion.new()
		ev.relative = step
		ev.screen_relative = step
		Input.parse_input_event(ev)
		if left <= 0.0:
			break
	await get_tree().process_frame


## THE STATE A TOUR IS IN, printed as it starts and whenever a line fails or a
## block tries again: which game is running (its instance, so a second game is
## visible as a new number), what that game was booted with, and what the world
## says now. A tour that failed under load with the wrong thing in hand, the
## wrong sky and the wrong hour could not say which of them had been lost or
## when, and the frame alone could not either (integ-cam, 2026-09-24).
func _say_state(when: String) -> void:
	if not is_instance_valid(game):
		print("tour %s state %s: no game" % [_name, when])
		return
	var o: BootOptions = game.options
	var held: StringName = game.inventory.held if game.inventory != null else &""
	var alive := 0
	var sim: FightSim = game.player.sim if game.player != null else null
	if sim != null:
		alive = sim.living()
	var lock := "none"
	for s in game.systems:
		if s.name == "42_target" and s.get("locked") != null:
			lock = String((s.get("locked") as TargetSubject).kind)
	print("tour %s state %s: game #%d booted seed %d hour %.2f weather '%s' held '%s' give %s | now %s held '%s' sky '%s' lock %s bodies %d" % [
		_name, when, game.get_instance_id(), o.seed_value, o.hour, o.weather, o.held, str(o.give),
		game.clock.label() if game.clock != null else "?", held, String(Weather.forced_kind), lock, alive])


## The keys a player would hold to walk `dir` in the world, read the way the game
## reads them now (LockOn.keys_for): the screen's own yaw, or the line to a held
## lock over the shoulder. The walk used to assume the top view's fixed yaw, so
## over the shoulder it steered by a camera that was not there.
func _keys_toward(dir: Vector2) -> Vector2:
	var lock: Vector2 = game.player.hero.lock if game.player.hero != null else Vector2.INF
	return LockOn.keys_for(dir, game.camera.yaw_now(), game.player.pos, lock, game.camera.shoulder)


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


## How far apart two saved frames are over `crop`, or **-1.0 when the question
## cannot be asked** — a frame missing, the two different sizes, or the crop not
## inside them. `frame_difference` answers 1.0 for all three, which fails an
## absolute bar honestly enough but would make two unanswerable pairs read as
## EQUAL to each other, and a relational assertion pass on a tour that saved no
## frames at all. So the unanswerable case is a value of its own here.
func _difference(a: String, b: String, crop: String) -> float:
	var ia := Image.load_from_file(_out.path_join(a + ".png"))
	var ib := Image.load_from_file(_out.path_join(b + ".png"))
	if ia == null or ib == null or ia.is_empty() or ib.is_empty() or ia.get_size() != ib.get_size():
		printerr("tour %s: %s and %s cannot be compared" % [_name, a, b])
		return -1.0
	var rect := Rect2i()
	if crop != "":
		var c := crop.split(",")
		if c.size() != 4:
			return -1.0
		rect = Rect2i(c[0].to_int(), c[1].to_int(), c[2].to_int(), c[3].to_int())
		if not Rect2i(Vector2i.ZERO, ia.get_size()).encloses(rect):
			printerr("tour %s: crop %s is not inside a %s frame" % [_name, crop, ia.get_size()])
			return -1.0
	return frame_difference(ia, ib, rect)


func _same(a: String, b: String, tol: float, crop: String) -> bool:
	var d := _difference(a, b, crop)
	if d < 0.0:
		return false
	print("tour %s: %s against %s%s differs by %.4f (at most %.4f)" % [_name, a, b, "" if crop == "" else " at " + crop, d, tol])
	return d <= tol


## `same A B no_more_than C D [SLACK] [CROP]`: A,B moved the picture no more than
## the control pair C,D did. See the header for why an absolute bar is the wrong
## instrument for that claim.
func _no_more_than(a: String, b: String, c: String, d: String, slack: float, crop: String) -> bool:
	var moved := _difference(a, b, crop)
	var control := _difference(c, d, crop)
	if moved < 0.0 or control < 0.0:
		return false
	print("tour %s: %s against %s differs by %.4f%s, against %s / %s at %.4f%s" % [_name, a, b, moved,
		"" if crop == "" else " at " + crop, c, d, control,
		"" if is_zero_approx(slack) else " + %.4f allowed" % slack])
	return moved <= control + slack


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

## How far a lit thing may be washed toward the page and still count as its own
## colour. A stolen neon tube is EMISSION: its own light carries it toward white
## as it burns, so the flat palette value never reaches the picture. Measured on
## the tube in tours/houses at 22:30, the palette's (255, 64, 204) arrives as
## (217, 136, 217) along the run and (255, 160, 255) at its core — so asking for
## the palette value alone found NONE of it, and frames with the tube plainly in
## them were being thrown away as frames that only claimed one.
##
## The cap is the whole of what makes this mean anything, because every colour
## washes to the same white in the end and an uncapped rule counts the slate's
## own phosphor and the sea's foam as whatever tube was asked for. Measured on
## one frame WITH a tube and one WITHOUT, both carrying the HUD: at 0.4 the tube
## reads 264 pixels of magenta and none of cyan or green, and the frame with no
## tube reads none of any of the three. At 0.75 the tubeless frame starts
## matching its own green text.
const PIXEL_WASH := 0.4


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
			printerr("tour %s: shot %s claims %s and the world has none%s" % [_name, label, w, _instead(w)])
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


## What the world holds instead, for the subjects where knowing it is the whole
## of the diagnosis. A refused frame that only says "no bonelands here" costs
## another run to find out where the walk really ended; one that says which
## ground it is standing on is a fix.
func _instead(what: String) -> String:
	if not is_instance_valid(game):
		return ""
	if what.begins_with("land:") or what.begins_with("border:"):
		var p := game.player.pos
		var x := floori(p.x)
		var y := floori(p.y)
		var here := BiomeRegistry.at(game.world, p).id
		if not game.world.in_bounds(x, y):
			return " (the player is off the world at %s)" % p
		var i := y * game.world.size + x
		var other := BiomeRegistry.by_index(int(game.world.country2[i])).id
		if game.world.blend[i] > 0.0:
			return " (at %s the ground is %s, on its border with %s)" % [p, here, other]
		return " (at %s the ground is %s, no border)" % [p, here]
	if what == "mob" or what.begins_with("mob:") or what.begins_with("down:") or what.begins_with("body:"):
		var seen := PackedStringArray()
		for n: Node in get_tree().get_nodes_in_group(&"mobs"):
			seen.append("%s%s" % [n.get("kind"), "" if bool(n.get("alive")) else " (down)"])
		return " (bodies about: %s)" % (", ".join(seen) if seen.size() > 0 else "none")
	if what.begins_with("station:"):
		return " (in reach: %s)" % ", ".join(Survival.stations_near(game))
	if what.begins_with("prop:"):
		return " (at %s)" % game.player.pos
	if what == "slept" or what == "skipped":
		var why := Survival.sleep_refusal(game)
		return " (%s; hands %s; `use` here would %s)" % [
			"the body would lie down" if why == "" else "it will not sleep: " + why,
			"busy" if Survival.busy(game) else "free",
			Survival.describe_target(game)]
	return ""


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
## After this long with no drawn frame, the tour stops waiting to be asked and
## draws one itself. A healthy shot is drawn inside a frame or two, so this only
## ever runs where the platform has already stopped — and it runs SOON, because
## every millisecond spent waiting for the shutter is a millisecond the shot is
## late for the moment it is named after.
const DRAW_NUDGE := 0.25
## A world minute is the coarsest thing a frame shows (the HUD clock), so a wait
## that cost one has already made the picture a picture of a different moment.
const DRAW_DRIFT := 1.0


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
##
## The world is held still across the whole wait. Waiting for the shutter used
## to run the game: a stall of a couple of seconds put the clock two to four
## world minutes past the moment the tour staged, and every frame shot after a
## stall was of a later evening than the frames beside it — which is how the
## canon came to differ from itself run to run. A shot is of the moment the line
## before it made, however long the platform takes to hand it over.
func _drawn() -> bool:
	var began := Time.get_ticks_msec()
	var until := began + int(DRAW_WAIT * 1000.0)
	var seen := [false]
	var nudge_at := began + int(DRAW_NUDGE * 1000.0)
	var nudged := false
	var mark := func() -> void: seen[0] = true
	var tree := get_tree()
	var was_paused := tree.paused
	var clock_was := game.clock.minutes if is_instance_valid(game) and game.clock != null else 0.0
	# This node is PROCESS_MODE_ALWAYS, so the tour goes on running while the
	# game it is photographing does not.
	tree.paused = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	while not seen[0] and Time.get_ticks_msec() < until:
		await tree.process_frame
		if not seen[0] and Time.get_ticks_msec() >= nudge_at:
			# Draw one into the viewport's own texture, which is what a shot
			# reads. Nothing is presented: there is no one at that window.
			nudged = true
			RenderingServer.force_draw(false)
	tree.paused = was_paused
	var waited := (Time.get_ticks_msec() - began) / 1000.0
	var drift := absf(game.clock.minutes - clock_was) if is_instance_valid(game) and game.clock != null else 0.0
	if not seen[0]:
		RenderingServer.frame_post_draw.disconnect(mark)
		printerr("tour %s: the window was not asked to draw for %.0f s and would not be made to, so there is no frame to take" % [_name, waited])
		return false
	if waited >= DRAW_SLOW or nudged:
		print("tour %s: waited %.1f s for a drawn frame%s, and the world stood still for it (%.2f world minutes)"
			% [_name, waited, " and drew one itself" if nudged else "", drift])
	if drift > DRAW_DRIFT:
		printerr("tour %s: waiting for the shutter cost %.2f world minutes; the frame is not of the moment it was staged for" % [_name, drift])
		return false
	return true


func _save_frame(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	# In a web build (tools/web.sh --tour) a file written here lands in the page's
	# memory and nobody can open it, so the frame is handed to the page as a
	# download and the harness keeps it. At the base's own size: the 2x below is
	# nearest, so it holds nothing more, and encoding it in wasm costs seconds.
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), label + ".png", "image/png")
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	_last_frame = img
	var path := _out.path_join(label + ".png")
	if not OS.has_feature("web"):
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
			if is_like(d[i], d[i + 1], d[i + 2], w):
				n += 1
				break
		i += 3
	return n


## One pixel against one wanted colour: that colour, or that colour washed up to
## PIXEL_WASH of the way to white by its own light.
##
## How far it has washed is read off the channel with the most room to move,
## which is the one that says most about how hard the thing is burning: for the
## magenta tube that is green (64 of 255), and green is exactly the channel that
## made asking for the flat value fail.
static func is_like(r: int, g: int, b: int, w: Vector3i) -> bool:
	var head := Vector3i(255 - w.x, 255 - w.y, 255 - w.z)
	var most := maxi(head.x, maxi(head.y, head.z))
	var k := 0.0
	if most >= 1:
		var got := r if most == head.x else (g if most == head.y else b)
		var was := w.x if most == head.x else (w.y if most == head.y else w.z)
		k = clampf(float(got - was) / float(most), 0.0, PIXEL_WASH)
	var tol := float(PIXEL_TOLERANCE)
	return (absf(float(r) - (float(w.x) + k * float(head.x))) <= tol
		and absf(float(g) - (float(w.y) + k * float(head.y))) <= tol
		and absf(float(b) - (float(w.z) + k * float(head.z))) <= tol)
