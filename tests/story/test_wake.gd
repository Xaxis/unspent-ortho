extends TestCase
## THE WAKE (48_wake, ROADMAP slice 1 step 1a): a new game opens on him washed
## up face down on the tideline of the spawn beach, the black site out in the
## sea behind him and Maren a few paces along the water; he lies out cold, comes
## to, gets up off the sand, and the record's first lines come on those moments.
## A game that has woken before, or one started somewhere by name, is not put
## on the tideline.

const Sx := preload("res://tests/save/save_fixture.gd")
const Wake := preload("res://src/systems/48_wake.gd")
const ARGS := ["--seed=1", "--hour=10", "--weather=clear:0", "--wake"]
## Past the waking (out cold, then up), on the wall clock it runs on.
const RISE_WAIT := Wake.OUT + PersonAnim.RISE_SECONDS + 0.5


func _wall(secs: float) -> void:
	await tree.create_timer(secs).timeout


## Until the wake lets the glass go (it holds it through the Tether's first
## sight), or `most` seconds.
func _until_let_go(g: Game, most: float) -> void:
	var wake := Sx.system(g, "48_wake")
	var t := 0.0
	while t < most and bool(wake.call(&"holds_glass")):
		await _wall(0.25)
		t += 0.25


## The record's first lines as they are said, in order. Only those: out of the
## sea, the body is also told it is soaked through.
func _lines() -> Array[String]:
	var said: Array[String] = []
	var wake: Array = StoryContent.WAKE[&"comes_to"] + StoryContent.WAKE[&"stands"]
	Events.message.connect(func(line: String) -> void:
		if line in wake:
			said.append(line))
	return said


func _touches_water(w: WorldData, p: Vector2) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if Ground.is_water(w.ground_at(floori(p.x) + d.x, floori(p.y) + d.y)):
			return true
	return false


func test_a_new_game_wakes_on_the_tideline_with_the_site_behind_and_maren_by() -> void:
	var said := _lines()
	var g := Sx.game(tree, ARGS)
	var w := g.world
	var ground := w.ground_at(floori(g.player.pos.x), floori(g.player.pos.y))
	check(not Ground.is_water(ground), "he lies on the sand, not in the sea")
	check(_touches_water(w, g.player.pos), "at the water's edge, where the sea left him")
	eq(g.player.model.action, &"downed", "face down, out cold")
	# Lying with his head into a terrace a step up, the view saw no body at all.
	var level := w.level_at(floori(g.player.pos.x), floori(g.player.pos.y))
	var head := g.player.pos + Vector2.from_angle(g.player.facing) * WakeSpot.HEAD
	eq(w.level_at(floori(head.x), floori(head.y)), level, "his head up the beach on his own level, in the open")
	var site := BlackSite.site(w)
	var to_site := (site - g.player.pos).angle()
	# Lying with his head up the beach, the site is behind him: his facing and
	# the site's bearing point well apart.
	gt(absf(angle_difference(g.player.facing, to_site)), deg_to_rad(120.0), "the black site stands behind him")
	gt(SurvivalState.of(g).wet_until, g.clock.minutes, "out of the sea, soaked through")
	await process_frames(2)
	eq(said.size(), 0, "nothing is said while he is out cold")
	var cast := Sx.system(g, "49_cast")
	var maren: Dictionary = {}
	for row: Dictionary in cast.get("people"):
		if row.character == &"maren":
			maren = row
	check(not maren.is_empty(), "Maren is cast")
	if not maren.is_empty():
		var at: Vector2 = maren.pos
		check(not Ground.is_water(w.ground_at(floori(at.x), floori(at.y))), "Maren stands dry")
		var apart := at.distance_to(g.player.pos)
		check(apart > 1.0 and apart < 5.0, "a few paces from him (%.1f)" % apart)
	var from := g.player.pos
	# Pressed and let go before a press may bring him round: he stays down.
	Input.action_press(&"move_up")
	await _wall(Wake.OUT_LEAST * 0.6)
	Input.action_release(&"move_up")
	lt(from.distance_to(g.player.pos), 0.05, "held still while he is down")
	eq(g.player.model.action, &"downed", "still out cold")
	await _wall(Wake.OUT - Wake.OUT_LEAST * 0.6 + 0.2)
	eq(said, StoryContent.WAKE[&"comes_to"], "he comes to by himself, and the record's first lines")
	eq(g.player.model.action, &"rise", "and gets up off the sand")
	lt(from.distance_to(g.player.pos), 0.05, "held still while he gets up")
	await _wall(PersonAnim.RISE_SECONDS + 0.3)
	check(g.player.model.action != &"downed" and g.player.model.action != &"rise", "on his feet")
	eq(said.slice(2, 5), StoryContent.WAKE[&"stands"], "and the rest as he stands")
	Sx.end(g)


func test_a_press_brings_him_round_sooner() -> void:
	var g := Sx.game(tree, ARGS)
	await _wall(Wake.OUT_LEAST + 0.2)
	eq(g.player.model.action, &"downed", "out cold until something is pressed")
	Input.action_press(&"use")
	await process_frames(3)
	Input.action_release(&"use")
	eq(g.player.model.action, &"rise", "a press, and he comes to")
	Sx.end(g)


func test_a_game_that_has_woken_is_not_put_back_on_the_tideline() -> void:
	Sx.use_root("wake-load")
	var a := Sx.game(tree, ARGS)
	await _wall(RISE_WAIT)
	var stood := a.player.pos
	eq(str(Sx.system(a, "05_save").call("save_to", 1)), "", "saved after the wake")
	Sx.end(a)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), "", "the slot boots")
	var b := Sx.game(tree, [], o)
	check(b.player.model.action != &"downed", "a loaded game is not laid on the tideline again")
	lt(b.player.pos.distance_to(stood), 0.01, "it stands where it was saved")
	Sx.end(b)
	Sx.finish()


func test_a_start_by_name_is_not_staged_on_the_tideline() -> void:
	var said := _lines()
	var g := Sx.game(tree, ARGS + ["--place=spawn"])
	var ground := g.world.ground_at(floori(g.player.pos.x), floori(g.player.pos.y))
	check(not Ground.is_water(ground), "a --place start stands where it was put")
	check(g.player.model.action != &"downed", "on its feet")
	await process_frames(2)
	eq(said.size(), 5, "and still hears the first morning, once")
	Sx.end(g)


func test_a_game_booted_straight_into_the_world_starts_on_dry_land() -> void:
	var said := _lines()
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	var ground := g.world.ground_at(floori(g.player.pos.x), floori(g.player.pos.y))
	check(not Ground.is_water(ground), "a test, a shot or a tour stands at the spawn, dry")
	check(g.player.model.action != &"downed", "on its feet")
	await process_frames(2)
	eq(said.size(), 5, "and hears the first morning, once")
	Sx.end(g)


func test_no_goal_or_key_hint_is_on_the_glass_until_the_wake_is_over() -> void:
	var hints: Array[String] = []
	var on_hint := func(line: String, _key: String = "") -> void: hints.append(line)
	Events.hint.connect(on_hint)
	var g := Sx.game(tree, ARGS)
	await _wall(RISE_WAIT + 2.5)
	eq(g.hud.goal, "", "no goal pinned over his first breath")
	eq(hints.size(), 0, "and nothing taught")
	# Over when he has spoken to her (48_wake's end, 49_cast.stand undone).
	@warning_ignore("return_value_discarded")
	Story.meet(&"maren")
	await _until_let_go(g, 12.0)
	await _wall(1.0)
	# The goal is her errand (Guide._goal_of): met but not yet led, nothing is
	# wanted of him; her talk gives the lead on its obvious replies
	# (test_guide_lead), and then the goal stands.
	eq(g.hud.goal, "", "the wake over, but no lead given yet: no goal")
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	await _wall(1.0)
	check(g.hud.goal != "", "the goal once the wake is over and she has given her lead")
	Events.hint.disconnect(on_hint)
	Sx.end(g)
	Story.forget()


func test_only_the_record_speaks_while_the_wake_holds_the_glass() -> void:
	var g := Sx.game(tree, ARGS)
	await _wall(RISE_WAIT + 3.0)
	gt(g.body.wet, 0.0, "out of the sea, he is wet: the state applies")
	var other := "A line that is not the record's."
	Events.message.emit(other)
	await process_frames(2)
	for l: Dictionary in g.hud.messages.lines:
		check(String(l.text) in (Sx.system(g, "48_wake").call(&"own_lines") as Array), "only the record's lines on the glass, not '%s'" % l.text)
	check(other in g.hud.get("_kept"), "any other line is kept while the wake holds the glass")
	@warning_ignore("return_value_discarded")
	Story.meet(&"maren")
	await _until_let_go(g, 12.0)
	await _wall(0.5)
	eq((g.hud.get("_kept") as Array).size(), 0, "and let go once the wake is over")
	Sx.end(g)


func test_the_first_sight_turns_the_view_to_the_tether_and_back() -> void:
	await _first_sight(ARGS)


## Under --stats as well: 12_landscape holds every system's process flag then, and
## the wake read the orbit's flag as "no sky", so a measured run never turned to
## the Tether (tools/perf-real.sh on home-coast).
func test_the_first_sight_comes_in_a_measured_run_too() -> void:
	await _first_sight(ARGS + ["--stats"])


func _first_sight(args: Array) -> void:
	var g := Sx.game(tree, args)
	var stage: Node = tree.get_first_node_in_group(&"stage")
	var saw: Array[StringName] = []
	stage.looked.connect(func(w: StringName) -> void: saw.append(w))
	var looked_at_it := false
	var t := 0.0
	while t < 14.0 and saw.is_empty():
		if bool(stage.call(&"looking")) and stage.call(&"why") == &"tether" and g.camera.stage_weight >= 0.99:
			var orbit := Sx.system(g, "19_orbit")
			var b := float(orbit.call(&"tether_bearing"))
			var fwd := -g.camera.global_basis.z
			looked_at_it = looked_at_it or absf(angle_difference(atan2(fwd.z, fwd.x), b)) < deg_to_rad(4.0)
		await _wall(0.2)
		t += 0.2
	eq(saw, [&"tether"] as Array[StringName], "the wake turns the view once, to the Tether")
	check(looked_at_it, "on the Tether's bearing")
	Sx.end(g)
