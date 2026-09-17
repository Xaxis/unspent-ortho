extends TestCase
## Targeting inside a real (small) game: holding the key locks the nearest
## threat and leans the camera, the keys cycle and sweep, letting go puts
## everything back — and none of it touches the fight. The last test is the
## rule the owner's ruling turned round: words on the glass only when the
## player asks for them by holding the key.

var _game: Game


func _make(extra: PackedStringArray = []) -> Node:
	var args := PackedStringArray(["--size=64", "--seed=4", "--hour=11", "--weather=clear:0"])
	args.append_array(extra)
	_game = Game.new()
	tree.root.add_child(_game)
	_game.setup(BootOptions.parse(args))
	for s in _game.systems:
		if s.name == "42_target":
			return s
	return null


func _done() -> void:
	for a: StringName in [&"target", &"ability_scan", &"move_left", &"move_right"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	_game.free()


func test_holding_the_key_locks_the_nearest_threat_and_leans_the_camera() -> void:
	var sys := _make(PackedStringArray(["--spawn=runner", "--target"]))
	check(sys != null, "42_target is loaded from src/systems")
	sys.call("_process", 0.1)
	var locked: MobState = sys.get("locked")
	check(locked != null, "a body is locked")
	eq(locked.kind, &"runner")
	var cam := _game.camera
	check(not is_equal_approx(cam.lean_zoom, 1.0), "the camera is asked to zoom")
	check(absf(cam.lean_pitch) > 0.1, "and to lean its pitch")
	check(cam.lean_bias.length() > 0.01, "and to bias the frame toward what is read")
	var read: Dictionary = sys.get("read")
	check(not read.is_empty(), "the slate has a read of it")
	eq(str(read.name), "runner")
	check(str(read.thinking) != "", "and says what it is thinking")
	_done()


func test_letting_go_puts_the_camera_back_and_the_reads_away() -> void:
	var sys := _make(PackedStringArray(["--spawn=runner", "--target"]))
	sys.call("_process", 0.1)
	check(sys.get("locked") != null)
	sys.set("_forced", false)
	sys.call("_process", 0.1)
	eq(sys.get("locked"), null, "nothing is locked")
	check((sys.get("read") as Dictionary).is_empty(), "and nothing is read")
	var cam := _game.camera
	eq(cam.lean_zoom, 1.0, "the camera is asked for no zoom")
	eq(cam.lean_pitch, 0.0)
	eq(cam.lean_yaw, 0.0)
	eq(cam.lean_bias, Vector3.ZERO)
	for i in 30:
		cam._process(0.05)
	check(not cam.leaning(), "and it eases back square")
	_done()


func test_the_keys_cycle_the_lock_and_sweep_the_field() -> void:
	var sys := _make(PackedStringArray(["--spawn=runner,cutter,watcher", "--target"]))
	sys.call("_process", 0.1)
	var first: MobState = sys.get("locked")
	check(first != null)
	Input.action_press(&"move_right")
	sys.call("_process", 0.1)
	Input.action_release(&"move_right")
	var second: MobState = sys.get("locked")
	check(second != null and second != first, "right cycles to another body")
	Input.action_press(&"ability_scan")
	sys.call("_process", 0.1)
	Input.action_release(&"ability_scan")
	check(bool(sys.get("sweeping")), "the scan key sweeps the field")
	eq(sys.get("locked"), null, "a sweep locks nothing")
	var field: Array = sys.get("field")
	check(field.size() >= 2, "and reads the field: %d" % field.size())
	var rows: Array = sys.get("rows")
	eq(rows.size(), field.size(), "one row a body")
	check(_game.camera.lean_zoom > 1.0, "the camera stands back for a field")
	_done()


func test_targeting_changes_nothing_in_the_fight() -> void:
	var sys := _make(PackedStringArray(["--spawn=runner", "--target"]))
	var sim := _game.player.sim
	var body: MobState = sim.mobs[0]
	var before := {"health": body.health, "pos": body.pos, "mood": body.mood, "facing": body.facing,
		"hero_health": sim.hero.health, "hero_pos": sim.hero.pos, "hero_facing": sim.hero.facing}
	sim.out.clear()
	for i in 10:
		sys.call("_process", 0.05)
	eq(body.health, before.health, "the body is not touched")
	eq(body.pos, before.pos)
	eq(body.mood, before.mood)
	eq(body.facing, before.facing)
	eq(sim.hero.health, before.hero_health, "and neither is the player")
	eq(sim.hero.pos, before.hero_pos)
	eq(sim.hero.facing, before.hero_facing, "targeting never aims a blow")
	eq(sim.out.size(), 0, "and the fight hears nothing from it")
	_done()


## The owner's ruling, drawn: every body carries a wordless tag at all times, and
## words appear only while the key is held (docs/DESIGN.md §Targeting).
func test_words_only_when_the_player_asks_for_them() -> void:
	var sys := _make(PackedStringArray(["--spawn=runner"]))
	var view: UiTargetView = sys.get("view")
	await tree.process_frame
	UiDraw.tape.clear()
	UiDraw.taping = true
	view._canvas.queue_redraw()
	await tree.process_frame
	var words := 0
	var marks := 0
	for d: Dictionary in UiDraw.tape:
		# Only what targeting drew: the slate's own edge readouts are the HUD's.
		if d.ci != view._canvas:
			continue
		if d.kind == &"text":
			words += 1
		else:
			marks += 1
	UiDraw.taping = false
	eq(words, 0, "nothing is written over a fight nobody asked about")
	check(marks > 0, "but the body still carries its tag: %d marks" % marks)
	sys.set("_forced", true)
	sys.call("_process", 0.1)
	UiDraw.tape.clear()
	UiDraw.taping = true
	view._canvas.queue_redraw()
	await tree.process_frame
	var said := PackedStringArray()
	for d: Dictionary in UiDraw.tape:
		if d.ci == view._canvas and d.kind == &"text":
			said.append(str(d.text))
	UiDraw.taping = false
	check(said.size() > 4, "held, the slate says what it is: %s" % said)
	check(said.has("RUNNER  hunter") or said.has("RUNNER hunter"), "its name and its place in the plan: %s" % said)
	var lines := " ".join(said)
	check(lines.contains("blow"), "what it hits with")
	check(lines.contains("sees"), "what it can sense")
	_done()
