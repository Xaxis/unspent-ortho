extends TestCase
## THE WAKE (48_wake, ROADMAP slice 1 step 1a): a new game starts him under the
## water in the shallows off the spawn beach, the black site behind him and
## Maren at the water's edge; he rises, and the record's first lines come on the
## rise. A game that has woken before, or one started somewhere by name, is not
## put in the surf.

const Sx := preload("res://tests/save/save_fixture.gd")
const ARGS := ["--seed=1", "--hour=10", "--weather=clear:0", "--wake"]
## Past the rise (48_wake.RISE), on the wall clock the rise runs on.
const RISE_WAIT := 2.0


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


## The record's first lines as they are said, in order. Only those: standing in
## the sea, the body is also told it is soaked through.
func _lines() -> Array[String]:
	var said: Array[String] = []
	var wake: Array = StoryContent.WAKE[&"surface"] + StoryContent.WAKE[&"shallows"]
	Events.message.connect(func(line: String) -> void:
		if line in wake:
			said.append(line))
	return said


func test_a_new_game_wakes_in_the_surf_with_the_site_behind_and_maren_ahead() -> void:
	var said := _lines()
	var g := Sx.game(tree, ARGS)
	var w := g.world
	var ground := w.ground_at(floori(g.player.pos.x), floori(g.player.pos.y))
	check(Ground.is_water(ground) and not Ground.is_deep(ground), "he starts in wading water, not on the beach and not swimming")
	gt(g.player.sunk, 1.0, "and under it")
	var site := BlackSite.site(w)
	var to_site := (site - g.player.pos).angle()
	# Facing the shore, the site is behind him: his facing and the site's bearing
	# point well apart.
	gt(absf(angle_difference(g.player.facing, to_site)), deg_to_rad(120.0), "the black site stands behind him")
	await process_frames(2)
	eq(said, StoryContent.WAKE[&"surface"], "the record's first lines, as he breaks the water")
	var cast := Sx.system(g, "49_cast")
	var maren: Dictionary = {}
	for row: Dictionary in cast.get("people"):
		if row.character == &"maren":
			maren = row
	check(not maren.is_empty(), "Maren is cast")
	if not maren.is_empty():
		var at: Vector2 = maren.pos
		check(not Ground.is_water(w.ground_at(floori(at.x), floori(at.y))), "Maren stands dry")
		lt(at.distance_to(g.player.pos), 6.0, "at the water's edge he rises in")
	var from := g.player.pos
	Input.action_press(&"move_up")
	await _wall(0.8)
	Input.action_release(&"move_up")
	lt(from.distance_to(g.player.pos), 0.05, "held still while he rises")
	await _wall(RISE_WAIT)
	eq(g.player.sunk, 0.0, "risen")
	eq(said.slice(2, 5), StoryContent.WAKE[&"shallows"], "and the rest as he stands in the surf")
	Sx.end(g)


func test_a_game_that_has_woken_is_not_put_back_in_the_surf() -> void:
	Sx.use_root("wake-load")
	var a := Sx.game(tree, ARGS)
	await _wall(RISE_WAIT)
	var stood := a.player.pos
	eq(str(Sx.system(a, "05_save").call("save_to", 1)), "", "saved after the wake")
	Sx.end(a)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), "", "the slot boots")
	var b := Sx.game(tree, [], o)
	eq(b.player.sunk, 0.0, "a loaded game is not sunk again")
	lt(b.player.pos.distance_to(stood), 0.01, "it stands where it was saved")
	Sx.end(b)
	Sx.finish()


func test_a_start_by_name_is_not_staged_in_the_surf() -> void:
	var said := _lines()
	var g := Sx.game(tree, ARGS + ["--place=spawn"])
	var ground := g.world.ground_at(floori(g.player.pos.x), floori(g.player.pos.y))
	check(not Ground.is_water(ground), "a --place start stands where it was put")
	eq(g.player.sunk, 0.0, "not sunk")
	await process_frames(2)
	eq(said.size(), 5, "and still hears the first morning, once")
	Sx.end(g)


func test_a_game_booted_straight_into_the_world_starts_on_dry_land() -> void:
	var said := _lines()
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	var ground := g.world.ground_at(floori(g.player.pos.x), floori(g.player.pos.y))
	check(not Ground.is_water(ground), "a test, a shot or a tour stands at the spawn, dry")
	eq(g.player.sunk, 0.0, "not sunk")
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
	var soaked := String(Hazards.LINES[&"wet"])
	gt(g.body.wet, 0.0, "standing in the sea, he is wet: the state applies")
	for l: Dictionary in g.hud.messages.lines:
		check(String(l.text) in (Sx.system(g, "48_wake").call(&"own_lines") as Array), "only the record's lines on the glass, not '%s'" % l.text)
	check(soaked in g.hud.get("_kept"), "survival's line is kept while the wake holds the glass")
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
