extends TestCase
## The gear system inside a real running game: --fit puts gear on, the
## resistances reach the body and take the edge off the place, the real input
## actions fire the abilities, the slate's gear page fits things with one key,
## and all of it comes back through a save.

var game: Game


func _boot(extra: PackedStringArray = PackedStringArray()) -> Node:
	var args := PackedStringArray(["--seed=1", "--size=48", "--hour=12"])
	args.append_array(extra)
	game = Game.new()
	tree.root.add_child(game)
	game.setup(BootOptions.parse(args))
	return _system("54_gear")


func test_fitted_gear_reaches_the_body_and_takes_the_edge_off_the_place() -> void:
	var sys := _boot(["--fit=wrap_warm,mod_wadding"])
	check(sys != null, "54_gear loaded")
	var l: Loadout = sys.get("loadout")
	eq(l.item(&"body"), &"wrap_warm", "--fit put the wrap on")
	eq(l.modules(&"body"), [&"mod_wadding"] as Array[StringName], "and wadded it")
	check(game.inventory.has(&"wrap_warm"), "anything fitted is carried")
	gt(float(game.body.resist.get(&"cold", 0.0)), 0.4, "the body resists cold now")
	# The same bitter night, with and without.
	var p := Hazards.Place.new()
	p.hazards = {&"cold": 0.9}
	p.hour = 20.0
	var raw := Hazards.felt(p)
	var wrapped := Hazards.after_resist(raw, game.body.resist)
	var bare := Hazards.after_resist(raw, {})
	lt(float(wrapped[&"cold"]), float(bare[&"cold"]), "the wrap is felt")
	gt(float(bare[&"cold"]), Hazards.BITE, "bare, a cold night bites")
	lt(float(wrapped[&"cold"]), Hazards.BITE, "wrapped, it does not")
	game.free()


func test_the_real_key_fires_an_ability_and_it_moves_the_body() -> void:
	var sys := _boot(["--fit=glide_wing,mod_spring"])
	var book: AbilityBook = sys.get("book")
	check(book.has(&"dash") and book.has(&"glide"), "the wing and the coil grant two")
	game.player.hero.wind = game.player.hero.max_wind
	var before := game.player.pos
	Input.action_press(&"ability_dash")
	await tree.physics_frame
	Input.action_release(&"ability_dash")
	for i in 20:
		await tree.physics_frame
	gt(before.distance_to(game.player.pos), 1.0, "the press threw the body a burst")
	eq(game.player.hero.pos, game.player.pos, "and the fight body went with it")
	near(game.player.lift, 0.0, 1e-6, "feet back on the ground")
	check(sys.call("tour_seen", &"ability:dash"), "a tour can see it happened")
	game.free()


func test_an_ability_refuses_out_loud_and_never_fires_what_is_not_fitted() -> void:
	var sys := _boot()
	eq(sys.call("fire", &"dash"), &"nothing", "nothing is fitted")
	eq(sys.call("fire", &"glide"), &"nothing")
	game.free()
	sys = _boot(["--fit=glide_wing"])
	# Standing on the flat: there is nothing to step off.
	eq(sys.call("fire", &"glide"), &"no_drop")
	check(Ability.refusal_line(&"no_drop") != "", "and it says so")
	game.free()


func test_the_gear_page_fits_sockets_swaps_and_clears_with_one_key() -> void:
	var sys := _boot(["--give=wrap_warm:1,oilskin:1,mod_wadding:1"])
	var l: Loadout = sys.get("loadout")
	var feed: Dictionary = SlateFeeds.feed(&"loadout", game)
	eq((feed.slots as Array).size(), Gear.SLOTS.size(), "a row per slot")
	eq(StringName(feed.slots[0].id), Gear.SLOTS[0])
	check(SlateFeeds.act(&"loadout", game, &"nowhere").begins_with("!"), "a row that is not a slot refuses")
	var said := SlateFeeds.act(&"loadout", game, &"body")
	check(said.to_lower().contains("oilskin") or said.to_lower().contains("warm"), "it put something on: %s" % said)
	check(l.item(&"body") != &"", "and it is fitted")
	SlateFeeds.act(&"loadout", game, &"body")
	eq(l.modules(&"body").size(), 1, "the next press fills its socket")
	SlateFeeds.act(&"loadout", game, &"body")
	check(l.item(&"body") != &"", "the next swaps to the other piece carried")
	var second := l.item(&"body")
	SlateFeeds.act(&"loadout", game, &"body")
	eq(l.item(&"body"), &"", "and the last takes it off")
	check(second != &"", "having been through both")
	check(SlateFeeds.act(&"loadout", game, &"head").begins_with("!"), "nothing carried for the head")
	game.free()


## The hand's row answers about the hand: what is held is carrying's business,
## and this page binds a module to the haft and takes it off again. It used to
## answer "You carry nothing for that." about a slot that was already full.
func test_the_hands_row_binds_to_the_haft_and_never_answers_about_pieces() -> void:
	var sys := _boot(["--held=knife", "--give=mod_grip:1"])
	var l: Loadout = sys.get("loadout")
	eq(l.item(Gear.HAND_SLOT), &"knife", "the loadout follows what is held")
	gt(float(Gear.sockets(&"knife")), 0.0, "a haft takes a binding")
	var said := SlateFeeds.act(&"loadout", game, Gear.HAND_SLOT)
	check(not said.begins_with("!"), "it did something: %s" % said)
	eq(l.modules(Gear.HAND_SLOT), [&"mod_grip"] as Array[StringName], "the grip is on the knife")
	gt(float(game.body.resist.get(&"resonance", 0.0)), 0.3, "and the body is answering with it")
	var again := SlateFeeds.act(&"loadout", game, Gear.HAND_SLOT)
	check(not again.begins_with("!"), "the next press takes it off: %s" % again)
	eq(l.modules(Gear.HAND_SLOT).size(), 0, "unbound")
	eq(l.item(Gear.HAND_SLOT), &"knife", "and the tool is still in hand: this page never swaps it")
	game.free()


func test_gear_dropped_comes_off_and_the_abilities_go_with_it() -> void:
	var sys := _boot(["--fit=glide_wing"])
	var book: AbilityBook = sys.get("book")
	check(book.has(&"glide"))
	game.inventory.remove(&"glide_wing")
	check(not book.has(&"glide"), "no wing, no glide")
	eq((sys.get("loadout") as Loadout).item(&"back"), &"", "and the slot is empty")
	game.free()


func test_the_loadout_and_the_cooldowns_come_back_through_a_save() -> void:
	var sys := _boot(["--fit=rebreather,mod_filter"])
	sys.call("fire", &"scan")
	var saved: Variant = JSON.parse_string(JSON.stringify(sys.call("_save")))
	var resist := game.body.resist.duplicate()
	game.free()
	sys = _boot()
	eq((sys.get("loadout") as Loadout).item(&"head"), &"", "a fresh game wears nothing")
	# What a load does: the creel first (SaveCore), then each system's own key.
	game.inventory.add(&"rebreather")
	game.inventory.add(&"mod_filter")
	sys.call("_load", saved)
	eq((sys.get("loadout") as Loadout).item(&"head"), &"rebreather", "the loadout came back")
	eq(game.body.resist, resist, "and so did what it keeps off")
	check(SaveGame.registered(&"gear"), "the system registered its key")
	game.free()


func test_a_scan_marks_the_machines_and_nothing_else() -> void:
	var sys := _boot(["--fit=scanner_lens", "--spawn=harvester"])
	var before := game.get_child_count()
	eq(sys.call("fire", &"scan"), &"", "the lens reads")
	sys.call("_scan_marks", 40.0, true)
	gt(float(game.get_child_count() - before), 0.0, "marks were laid on the page")
	check(sys.call("tour_seen", &"ability:scan"))
	game.free()


func test_the_wing_is_on_the_body_while_it_glides_and_folds_away_after() -> void:
	var sys := _boot(["--fit=glide_wing"])
	var here := game.player.pos
	sys.call("_start_motion", AbilityMotion.glide(here, Vector2.RIGHT, AbilityGlide.SPEED, AbilityGlide.FALL,
		AbilityGlide.SECONDS, game.world.height_at(here) + 4.0))
	var wing := game.player.model.get_node_or_null("glide_wing") as GlideWingModel
	check(wing != null, "the wing is on the body")
	# The wing opens on physics steps: wait until it is open, not for a count of
	# process frames, which a cold process runs through before it is.
	var opening := Time.get_ticks_msec() + int(10000 * TestCase.machine_slack())
	while wing.open <= 0.9 and Time.get_ticks_msec() < opening:
		await tree.physics_frame
		await tree.process_frame
	check(wing.is_visible_in_tree(), "and on screen once it is flying")
	gt(wing.open, 0.9, "it opened")
	gt(game.player.lift, 0.5, "and the body is off the ground")
	# Both idioms, in one object: plate on found.gdshader, frame on the world's.
	var plate := wing.get_node("spar1/plate") as MeshInstance3D
	var frame := wing.get_node("spar1/frame") as MeshInstance3D
	gt(float(plate.mesh.get_surface_count()), 0.0, "the plate has faces")
	gt(float(frame.mesh.get_surface_count()), 0.0, "and so does the made frame")
	var plate_shader := (plate.material_override as ShaderMaterial).shader
	var frame_shader := (frame.material_override as ShaderMaterial).shader
	check(plate_shader != frame_shader, "and they are not the same material (docs/ART.md §12)")
	check(String(plate_shader.resource_path).contains("found"), "the plate is FOUND")
	# It faces the camera's way up: a flat panel wound face-down would vanish.
	var aabb := plate.mesh.get_aabb()
	gt(aabb.size.x * aabb.size.z, 0.05, "the panels have a spread to be seen")
	# The flight is stepped on physics frames: wait for the landing, not for a
	# count of process frames, which a cold process runs through far faster.
	var until := Time.get_ticks_msec() + int(20000 * TestCase.machine_slack())
	while Time.get_ticks_msec() < until:
		await tree.physics_frame
		await tree.process_frame
		if game.player.lift <= 0.0 and wing.open <= 0.0:
			break
	near(game.player.lift, 0.0, 1e-6, "it lands")
	near(wing.open, 0.0, 1e-6, "and the wing folds back against the spine")
	check(not wing.visible, "out of the way when it is not flying")
	game.free()


func test_something_else_moving_the_body_ends_the_flight() -> void:
	var sys := _boot(["--fit=glide_wing"])
	var here := game.player.pos
	sys.call("_start_motion", AbilityMotion.glide(here, Vector2.RIGHT, AbilityGlide.SPEED, AbilityGlide.FALL,
		AbilityGlide.SECONDS, game.world.height_at(here) + 6.0))
	await tree.physics_frame
	await tree.physics_frame
	check(game.player.lift > 0.0, "flying")
	# A teleport (a tour's `at`, a load, a machine carrying you off).
	var away := here + Vector2(40, 40)
	game.player.hero.pos = away
	game.player.pos = away
	for i in 4:
		await tree.physics_frame
	near(game.player.lift, 0.0, 1e-6, "the flight gave way to it rather than flying the body on")
	eq(game.player.pos, away, "and the body stayed where it was put")
	for i in 30:
		await tree.process_frame
	var wing := game.player.model.get_node_or_null("glide_wing") as GlideWingModel
	check(wing != null and not wing.visible, "the wing folded away")
	game.free()


func _system(part: String) -> Node:
	for s in game.systems:
		if String(s.name).contains(part):
			return s
	return null


func test_what_is_fitted_is_worn_in_the_world_and_drawn_on_the_page() -> void:
	var sys := _boot(["--fit=oilskin,scanner_lens"])
	var model: PersonModel = game.player.model
	eq(model.look.coat, &"oilskin", "the walking figure wears the oilskin")
	check((model.look.salvage as Array).has(&"lens"), "and the scanner lens")
	var figure: Dictionary = SlateFeeds.feed(&"loadout", game).get("figure", {})
	check(not figure.is_empty(), "the gear page is handed a body to draw")
	eq(var_to_str(PersonLook.normalize(figure.look)), var_to_str(model.look), "the page draws exactly what the world shows")
	eq(StringName(figure.held), game.inventory.held, "holding the same thing")
	var l: Loadout = sys.get("loadout")
	l.clear_slot(&"body")
	eq(model.look.coat, &"none", "the oilskin off, off the figure too")
	check((model.look.salvage as Array).has(&"lens"), "the lens stays on")
	game.free()
