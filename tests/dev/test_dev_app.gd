extends TestCase
## Dev mode inside a real (small) game: its system is loaded, its app is on the
## slate and reached from home, opens beside a hostile, and every in-play page
## does what it says through the game's own doors. A tool run that does not ask
## for dev mode has none of it.

var _was := {}


func _keep() -> void:
	_was = {"tool_run": DevMode.tool_run, "asked": DevMode.asked, "configured": DevMode.configured, "armed": DevMode.armed,
		"readout": DevMode.readout, "page": DevMode.asked_page}
	DevSession.reset()


func _restore() -> void:
	DevMode.tool_run = _was.tool_run
	DevMode.asked = _was.asked
	DevMode.configured = _was.configured
	DevMode.armed = _was.armed
	DevMode.readout = _was.readout
	DevMode.asked_page = _was.page
	DevSession.reset()
	GameConfig.clear()
	if Weather.forced_kind != &"":
		Weather.unforce()


func _make(dev: bool, extra: PackedStringArray = []) -> Game:
	DevMode.asked = dev
	var args := PackedStringArray(["--size=64", "--seed=4"])
	args.append_array(extra)
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(args))
	return g


func _sys(g: Game, n: String) -> Node:
	for s in g.systems:
		if s.name == n:
			return s
	return null


func _open(g: Game) -> UiDevScreen:
	var ui := _sys(g, "90_ui")
	check(bool(ui.call("open_screen", &"dev")), "the dev app opens")
	return ui.call("top") as UiDevScreen


func test_a_tool_run_that_does_not_ask_has_no_dev_app() -> void:
	_keep()
	var g := _make(false)
	var dev := _sys(g, "94_dev")
	check(dev != null, "94_dev is loaded from src/systems")
	eq(dev.get("screen"), null, "no app when nobody asked")
	check(not bool(_sys(g, "90_ui").call("open_screen", &"dev")), "and nothing to open")
	g.free()
	_restore()


func test_the_app_opens_beside_a_hostile_and_steps_in_and_out_of_pages() -> void:
	_keep()
	var g := _make(true)
	var mob := Node.new()
	var body := GDScript.new()
	body.source_code = "extends Node\nvar pos := Vector2.ZERO\nvar alive := true\nvar kind := &\"runner\"\n"
	body.reload()
	mob.set_script(body)
	mob.set("pos", g.player.pos + Vector2(3, 0))
	mob.add_to_group(&"mobs")
	tree.root.add_child(mob)
	var s := _open(g)
	check(s != null, "the dev app is on top, a machine close or not")
	eq(s.page().heading(), "HOME")
	s.select(&"config")
	s.handle(&"confirm")
	eq(s.page().heading(), "CONFIGURATION", "e steps into a page")
	s.handle(&"back")
	eq(s.page().heading(), "HOME", "esc backs out one level")
	s.handle(&"dev_toggle")
	check(not s.is_open, "` shuts it from anywhere")
	mob.free()
	g.free()
	_restore()


func test_home_lists_the_dev_row_only_where_dev_mode_is_reachable() -> void:
	_keep()
	var g := _make(true)
	var ui := _sys(g, "90_ui")
	ui.call("open_screen", &"pause")
	var home: UiPauseScreen = ui.call("top")
	home.refresh()
	var ids := home.menu.rows.map(func(r: Dictionary) -> StringName: return r.get("id", &""))
	check(ids.has(&"dev"), "a dev row on home")
	home.select(&"dev")
	home.handle(&"confirm")
	check(ui.call("top") is UiDevScreen, "and it opens the dev app over home")
	g.free()
	DevMode.asked = false
	var plain := _make(false)
	var ui2 := _sys(plain, "90_ui")
	ui2.call("open_screen", &"pause")
	var home2: UiPauseScreen = ui2.call("top")
	check(not home2.menu.rows.map(func(r: Dictionary) -> StringName: return r.get("id", &"")).has(&"dev"), "no dev row where it cannot be reached")
	plain.free()
	_restore()


func test_live_rules_reach_the_running_game() -> void:
	_keep()
	GameConfig.clear()
	var g := _make(true)
	var s := _open(g)
	s.open_at(&"config", &"rules.clock")
	s.handle(&"right")
	var dev := _sys(g, "94_dev")
	dev.call("_process", 0.0)
	eq(g.clock.rate, 2.0, "the clock runs at the edited rate at once")
	check(GameConfig.edits.has("rules.clock"), "as an edit, not kept")
	s.open_at(&"body", &"harm")
	for i in 3:
		s.handle(&"left")
	dev.call("_process", 0.0)
	eq(GameConfig.value("rules.harm"), 0.0)
	eq(g.player.hero.harm, 0.0, "harm taken none: the fight body takes nothing")
	s.open_at(&"spawn", &"machines")
	s.handle(&"right")
	dev.call("_process", 0.0)
	eq(bool((_sys(g, "30_mobs").get("coast") as Object).get("spawning")), false, "bodies stop coming")
	check(DevMode.touched, "and the game is marked as touched")
	g.free()
	_restore()


func test_a_blow_does_what_harm_says() -> void:
	var hero := Hero.new()
	hero.harm = 0.5
	var sim := FightSim.new(null, null, hero, Moment.new())
	hero.health = 12
	sim._hurt_hero(MobState.new(), 4, Vector2.RIGHT, 0.0, 0)
	eq(hero.health, 10, "half of four")
	hero.harm = 0.0
	sim._hurt_hero(MobState.new(), 4, Vector2.RIGHT, 0.0, 0)
	eq(hero.health, 10, "none of four")


func test_go_time_body_things_and_bodies_act_on_the_game() -> void:
	_keep()
	var g := _make(true)
	var s := _open(g)
	# Go: a landscape's row moves the player there and shuts the app.
	s.open_at(&"go")
	var go := s.page() as DevPageGo
	var target := {}
	for p: Dictionary in DevCheats.places(g):
		if String(p.id).begins_with("village_") or String(p.id).begins_with("land_"):
			if (p.pos as Vector2).distance_to(g.player.pos) > 4.0:
				target = p
				break
	if not target.is_empty():
		s.select(target.id)
		s.handle(&"confirm")
		check(g.player.pos.distance_to(target.pos) < 3.0, "the player stands at %s" % target.label)
		check(g.player.hero.pos.distance_to(g.player.pos) < 0.01, "and the fight body with them")
		check(not s.is_open, "the app shuts so the place is seen")
		check(DevSession.came_from.is_finite(), "and remembers where it left from")
	check(go != null)
	s = _open(g)
	# Time: noon, and weather held and handed back.
	s.open_at(&"time", &"noon")
	s.handle(&"confirm")
	near(g.clock.hour(), 12.0, 0.01, "noon")
	s.open_at(&"time", &"weather")
	s.handle(&"right")
	check(Weather.forced_kind != &"", "weather is held")
	s.handle(&"left")
	eq(Weather.forced_kind, &"", "and handed back to the land")
	# Body.
	g.body.health = 3
	s.open_at(&"body", &"mend")
	s.handle(&"confirm")
	eq(g.body.health, g.body.max_health, "mended")
	s.open_at(&"body", &"fed")
	s.handle(&"right")
	check(DevSession.fed)
	g.body.fed_until = g.clock.minutes - 900.0
	_sys(g, "94_dev").call("_process", 0.0)
	check(g.body.fed_until > g.clock.minutes, "held fed over what the game wrote")
	# Things.
	s.open_at(&"give", &"driftwood")
	var before := g.inventory.count(&"driftwood")
	s.handle(&"confirm")
	eq(g.inventory.count(&"driftwood"), before + 1, "gave one")
	# Bodies: the region's file, and a body put down.
	s.open_at(&"spawn", &"file")
	s.handle(&"right")
	eq(DevCheats.file_here(g).level, &"wary", "the file stepped up a level")
	var n := (_sys(g, "30_mobs").get("sim") as FightSim).mobs.size()
	s.open_at(&"spawn", &"runner")
	s.handle(&"confirm")
	eq((_sys(g, "30_mobs").get("sim") as FightSim).mobs.size(), n + 1, "a runner put down")
	g.free()
	_restore()


func test_a_line_is_typed_kept_and_the_key_that_kept_it_does_nothing_more() -> void:
	_keep()
	var g := _make(true)
	var s := _open(g)
	s.open_at(&"notes", &"words")
	s.handle(&"confirm")
	check(s.editing(), "e on words starts a line")
	for c in "the ford".to_utf8_buffer():
		s.type_key(KEY_A, c)
	s.type_key(KEY_BACKSPACE, 0)
	s.handle(&"confirm")
	check(s.editing(), "e while typing is a letter, not a row")
	s.type_key(KEY_ENTER, 0)
	check(not s.editing())
	eq((s.page() as DevPageNotes).get("_words"), "the for", "kept as typed, backspace and all")
	s.handle(&"confirm")
	check(not s.editing(), "the enter that kept it is not a press on the page the same frame")
	s.open_at(&"notes", &"words")
	s.handle(&"confirm")
	s.handle(&"back")
	check(not s.editing() and s.is_open, "esc drops the line and leaves the app up")
	g.free()
	_restore()


func test_a_note_keeps_the_state_that_stages_it_again() -> void:
	_keep()
	var g := _make(true, PackedStringArray(["--hour=19.5", "--give=driftwood:3", "--weather=rain:0.5"]))
	var note := DevNotes.make(g, "look", "the ford is dark")
	eq(note.kind, "look")
	eq(int(note.state.seed), 4)
	near(float(note.state.hour), 19.5, 0.05)
	eq(int(note.state.carried.get("driftwood", 0)), 3)
	check(bool(note.state.weather_held))
	var cmd := str(note.repro)
	for part: String in ["tools/shot.sh shots/notes/%s.png" % note.id, "--seed=4", "--size=64", "--hour=19.5", "--weather=rain:0.5", "--give=driftwood:3"]:
		check(cmd.contains(part), "the command has %s: %s" % [part, cmd])
	var back := DevNotes.restage(JSON.parse_string(DevNotes.text(note)))
	eq(back.seed_value, 4)
	eq(back.size, 64)
	check(back.at.distance_to(g.player.pos) < 0.2, "at the place")
	eq(back.weather, "rain:0.5")
	eq(int(back.give.get(&"driftwood", 0)), 3)
	eq(DevNotes.write(note, null), "")
	var kept := DevNotes.list()
	check(kept.size() >= 1 and kept[0].id == note.id, "kept, newest first")
	check(DevNotes.folder().begins_with(DevMode.TEST_ROOT), "in the test runner's own folder, never the owner's")
	DevNotes.remove(note)
	check(DevNotes.list().filter(func(n: Dictionary) -> bool: return n.id == note.id).is_empty(), "and thrown away")
	g.free()
	_restore()


func test_local_pages_say_why_not_where_the_tools_are_not() -> void:
	_keep()
	var g := _make(true)
	var s := _open(g)
	var rows := DevPageHome.new()
	rows.screen = s
	rows.game = g
	for r: Dictionary in rows.rows():
		if r.get("id") in [&"builds", &"proofs"]:
			eq(UiMenu.enabled(r), DevMode.local(), "%s is open only on the machine the game is built on" % r.id)
	g.free()
	_restore()


func test_play_and_restage_replace_the_game_and_keep_their_saves_apart() -> void:
	_keep()
	var root_was := SaveSlots.root
	var holder := Node.new()
	tree.root.add_child(holder)
	DevMode.asked = true
	var g := Game.new()
	g.name = "game"
	holder.add_child(g)
	g.setup(BootOptions.parse(["--size=48", "--seed=7"]))
	GameConfig.clear()
	GameConfig.set_value("world.seed", 9)
	GameConfig.set_value("world.size", 256)
	GameConfig.set_value("world.hour", 5.0)
	DevPlay.config(g)
	check(SaveSlots.root.begins_with("user://dev-saves/"), "a game dev mode starts saves apart: %s" % SaveSlots.root)
	await tree.process_frame
	await tree.process_frame
	var next: Game = null
	for c in holder.get_children():
		if c is Game and c != g:
			next = c
	check(next != null, "a new game took its place")
	if next != null:
		eq(next.world.seed_value, 9, "on the configuration's island")
		eq(next.world.size, 256)
		near(next.clock.hour(), 5.0, 0.05, "at its hour")
		check(DevMode.touched, "and it is a dev game from the start")
		var note := DevNotes.make(next, "bug", "")
		DevPlay.note(next, note)
		await tree.process_frame
		await tree.process_frame
		var staged: Game = null
		for c in holder.get_children():
			if c is Game and c != next and is_instance_valid(c) and not c.is_queued_for_deletion():
				staged = c
		check(staged != null, "a note restaged")
		if staged != null:
			var at := Vector2(float(note.state.pos[0]), float(note.state.pos[1]))
			check(staged.player.pos.distance_to(at) < 1.5, "where the note was taken")
			eq(staged.world.seed_value, 9, "on the note's island")
	holder.free()
	SaveSlots.root = root_was
	_restore()


func test_the_slate_edge_hides_and_a_picture_is_asked_for_without_error() -> void:
	_keep()
	var g := _make(true)
	var s := _open(g)
	var dev := _sys(g, "94_dev")
	s.open_at(&"view", &"hud")
	s.handle(&"right")
	s.handle(&"dev_toggle")
	dev.call("_process", 0.0)
	check(not g.hud.visible, "the slate's edge is hidden")
	_sys(g, "90_ui").call("open_screen", &"inventory")
	(_sys(g, "90_ui").call("top") as UiScreen).handle(&"back")
	dev.call("_process", 0.0)
	check(not g.hud.visible, "and stays hidden after an app closes")
	DevSession.hud_hidden = false
	dev.call("_process", 0.0)
	check(g.hud.visible, "and comes back")
	dev.call("picture_soon")
	check(not g.hud.visible, "nothing of the slate while the picture is taken")
	g.free()
	_restore()
