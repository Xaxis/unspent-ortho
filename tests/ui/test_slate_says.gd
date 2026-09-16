extends TestCase
## The lines the slate speaks and the keys it names: every tab says how it is
## reached, the location ping is exact after a jump as well as a walk, the goal
## stands where it can be read, and a teaching line is said in its own moment
## or not at all.


# --- every tab names its key ---------------------------------------------------

func test_every_tab_names_the_key_that_reaches_it() -> void:
	for tab: Array in UiSlate.TABS:
		var app: StringName = tab[0]
		var key := UiSlate.tab_key(app)
		check(key != "", "%s names a key" % app)
		if tab[2] == "":
			check(UiSlate.tab_under_home(app), "%s is reached inside home" % app)
			eq(key, UiSlate.tab_key(UiSlate.UNDER), "%s names home's key, not one of its own" % app)
	eq(UiSlate.tab_key(&"map"), "m", "an app with its own key names it")
	check(not UiSlate.tab_under_home(&"map"), "and is not under home")
	eq(UiSlate.tab_key(&"no_such_app"), "", "nothing else is a tab")


func test_the_strip_draws_home_before_what_hangs_off_it() -> void:
	var s := UiPauseScreen.new()
	tree.root.add_child(s)
	s.open()
	s.settle()
	var said := await _words(s)
	var want := ["slate", "i", "CARRY", "c", "MAKE", "m", "MAP", "esc", "HOME", "GEAR", "READS", "SAVES"]
	var got: Array[String] = []
	for w: String in said:
		if want.has(w) and not got.has(w):
			got.append(w)
	eq(got, want as Array[String], "every tab, each behind the key that reaches it")
	s.free()


func test_home_lights_its_own_tab_and_not_the_slate_name() -> void:
	var s := UiPauseScreen.new()
	tree.root.add_child(s)
	s.open()
	s.settle()
	var tone := {}
	UiDraw.tape.clear()
	UiDraw.taping = true
	s.queue_redraw()
	await tree.process_frame
	UiDraw.taping = false
	for w: Dictionary in UiDraw.tape:
		if w.kind == &"text" and w.ci == s:
			tone[String(w.text)] = w.col
	UiDraw.tape.clear()
	eq(tone.get("HOME"), UiTheme.BRIGHT, "home is lit while home is on the glass")
	eq(tone.get("slate"), UiTheme.TEXT_DIM, "the device's name is not the lit tab")
	s.free()


func _words(s: UiScreen) -> Array[String]:
	UiDraw.tape.clear()
	UiDraw.taping = true
	s.queue_redraw()
	await tree.process_frame
	UiDraw.taping = false
	var out: Array[String] = []
	for w: Dictionary in UiDraw.tape:
		if w.kind == &"text" and w.ci == s:
			out.append(String(w.text))
	UiDraw.tape.clear()
	return out


# --- the location ping ---------------------------------------------------------

func test_a_walked_border_settles_and_a_jump_is_said_at_once() -> void:
	var w := UiPlaceWatch.new()
	eq(w.step(&"coast", 0.1), &"coast", "where you wake is said at once")
	eq(w.step(&"moss", 0.1), &"", "a toe over the line is not a landscape")
	eq(w.step(&"moss", UiPlaceWatch.SETTLE), &"moss", "holding there is")
	eq(w.step(&"snowfield", 0.016), &"", "another border, walked: it settles first")
	eq(w.step(&"snowfield", 0.016, true), &"snowfield", "but a jump is where you are now")
	eq(w.step(&"sea", 1.0), &"", "the sea is never announced")
	eq(w.announced, &"snowfield", "and does not unsay the land")


func test_a_jump_is_told_from_a_walk_by_how_far_it_went() -> void:
	check(UiPlaceWatch.jumped(Vector2(10, 10), Vector2(200, 30)), "a teleport")
	check(not UiPlaceWatch.jumped(Vector2(10, 10), Vector2(10.3, 10)), "a step")


# --- the goal and the teaching channel -----------------------------------------

func _hud() -> Hud:
	var hud := Hud.new()
	tree.root.add_child(hud)
	return hud


func test_the_goal_stands_until_something_louder_needs_the_space() -> void:
	var hud := _hud()
	hud.set_goal("A fire before dark: three driftwood and two stones.")
	check(hud.goal_shown(), "it stands")
	hud.show_place("moss")
	hud.settle()
	check(not hud.goal_shown(), "the location ping has the space while it pings")
	hud._place_age = Hud.PLACE_IN + Hud.PLACE_HOLD + Hud.PLACE_OUT + 1.0
	check(hud.goal_shown(), "and gives it back")
	hud.set_quiet(true)
	check(not hud.goal_shown(), "no text in a fight")
	hud.set_quiet(false)
	hud.show_message("A fire before dark: three driftwood and two stones.")
	check(not hud.goal_shown(), "and it is not said twice while the line is still up")
	hud.set_goal("")
	check(not hud.goal_shown(), "nothing to want, nothing said")
	hud.free()


func test_a_teaching_line_is_said_now_or_not_at_all() -> void:
	var hud := _hud()
	Events.hint.emit("WASD walks, Shift runs.", "wasd")
	eq(hud.messages.visible().size(), 1, "said in its moment")
	hud.messages.lines.clear()
	hud.set_quiet(true)
	Events.hint.emit("Night. F lights the lamp.", "f")
	eq(hud.messages.visible().size(), 0, "nothing in a fight")
	hud.set_quiet(false)
	hud._process(0.016)
	eq(hud.messages.visible().size(), 0, "and it is not replayed when the fight ends")
	# A line about the world still waits, and is said once the fight is over.
	hud.set_quiet(true)
	Events.message.emit("Took 2 timber.")
	eq(hud.messages.visible().size(), 0, "a world line waits in a fight")
	hud.set_quiet(false)
	gt(float(hud.messages.visible().size()), 0.0, "and is said when it is over")
	hud.free()


func test_the_guide_speaks_on_the_teaching_channel() -> void:
	var src := (load("res://src/systems/58_guide.gd") as GDScript).source_code
	check(src.contains("Events.hint.emit(line, key)"), "the guide's lines are teaching lines")
	check(not src.contains("Events.message.emit(line)"), "and none of them goes on the queued line")


## The lesson a fight owes the player — rang off plate, never found the lit
## side — is the one lesson whose moment is "the fight is over", and the
## commonest ending is a machine breaking off while it is still roused and
## still inside the radius that hushes the slate. A teaching line said into
## that is dropped, not queued, so the guide must hold it until the glass will
## take it, and must not retire it before it has been said.
func test_the_plate_lesson_waits_for_the_glass_and_is_never_lost() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=64"])))
	_calm(g)
	var guide: Node = g.get_node("58_guide")
	var line: String = (load("res://src/systems/58_guide.gd") as GDScript).get_script_constant_map()["SIDE_LINE"]
	# A machine five tiles off, roused: the glass is hushed while it is there.
	var mob := _hostile(g.player.pos + Vector2(5, 0))
	for i in 3:
		await tree.process_frame
	check(g.hud.messages.quiet, "a machine that close hushes the glass")
	# A blow rang off its plate, and then it broke off without dying.
	Events.hit.emit(null, mob, 0, true, Vector3.ZERO)
	Events.fight_ended.emit(&"away")
	for i in 4:
		guide.call("_process", 5.0)
	check(not (guide.get("retired") as Dictionary).has(&"side"), "the lesson is not spent into a hushed glass")
	check(not _said_line(g.hud, line), "and nothing is said there")
	# It gives up and goes: now the lesson can be read.
	mob.free()
	for i in 3:
		await tree.process_frame
	guide.call("_process", 5.0)
	check(_said_line(g.hud, line), "the lesson is said once the machine is off: %s" % str(g.hud.messages.lines))
	check((guide.get("retired") as Dictionary).has(&"side"), "and retires then, not before")
	eq(String(guide.get("_lesson")), "", "nothing is owed after it is said")
	g.queue_free()
	await frames(1)


func _said_line(hud: Hud, line: String) -> bool:
	for l in hud.messages.lines:
		if String(l.text) == line:
			return true
	return hud.messages.waiting.has(line)


## Nothing the world spawns wanders into these tests: what is near is put there.
func _calm(g: Game) -> void:
	for s in g.systems:
		if s.name == "30_mobs":
			(s.get("coast") as Object).set("spawning", false)
	if g.player.sim != null:
		g.player.sim.clear_mobs()


func _hostile(at: Vector2) -> Node:
	var mob := Node.new()
	var s := GDScript.new()
	s.source_code = "extends Node\nvar pos := Vector2.ZERO\nvar alive := true\nvar kind := &\"runner\"\n"
	s.reload()
	mob.set_script(s)
	mob.set("pos", at)
	mob.add_to_group(&"mobs")
	tree.root.add_child(mob)
	return mob
