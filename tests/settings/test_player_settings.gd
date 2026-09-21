extends TestCase
## What a player sets, and what it is not (owner, 2026-09-17): their own device's
## settings, kept in their own file, nowhere near a save and nowhere near the
## master configuration a build was made from.


## This runner has no per-test hook, so every test says it itself: the settings
## a test writes go in the runner own file and never in the player's.
func test_every_row_is_the_game_as_it_ships_until_somebody_changes_it() -> void:
	PlayerSettings.forget_for_test()
	for r: Dictionary in PlayerSettings.ROWS:
		eq(PlayerSettings.value(r.id), r.default, "%s starts at what the owner built" % r.id)
		check(PlayerSettings.GROUPS.has(r.group), "%s belongs to a group the page shows" % r.id)
		check(String(r.id).begins_with(String(r.group) + "."), "%s is named for its group" % r.id)
		check(String(r.get("label", "")) != "", "%s has words a player can read" % r.id)


func test_a_value_is_brought_inside_what_its_row_allows() -> void:
	PlayerSettings.forget_for_test()
	PlayerSettings.set_value(&"sound.world", 4.0)
	eq(PlayerSettings.value(&"sound.world"), 1.0, "a level cannot go over full")
	PlayerSettings.set_value(&"sound.world", -2.0)
	eq(PlayerSettings.value(&"sound.world"), 0.0)
	PlayerSettings.set_value(&"picture.scale", 11)
	eq(PlayerSettings.value(&"picture.scale"), PlayerSettings.default_of(&"picture.scale"),
		"a choice nobody offered falls back to what it came as")
	PlayerSettings.set_value(&"playing.crouch", &"toggle")
	check(PlayerSettings.is_set(&"playing.crouch", &"toggle"))


func test_a_key_press_steps_a_row_the_way_the_page_does() -> void:
	PlayerSettings.forget_for_test()
	PlayerSettings.set_value(&"sound.score", 0.5)
	PlayerSettings.step(&"sound.score", 1)
	near(float(PlayerSettings.value(&"sound.score")), 0.6, 0.001)
	PlayerSettings.step(&"sound.score", -1)
	near(float(PlayerSettings.value(&"sound.score")), 0.5, 0.001)
	PlayerSettings.step(&"picture.flashes", 1)
	eq(PlayerSettings.value(&"picture.flashes"), false, "a switch is the other one")
	PlayerSettings.step(&"picture.flashes", 1)
	eq(PlayerSettings.value(&"picture.flashes"), true)
	# A choice wraps, so a player holding one direction never gets stuck at an end.
	var scales: Array = PlayerSettings.row(&"picture.scale").options
	PlayerSettings.set_value(&"picture.scale", scales.back())
	PlayerSettings.step(&"picture.scale", 1)
	eq(PlayerSettings.value(&"picture.scale"), scales.front())


func test_a_level_is_decibels_the_mix_can_live_with() -> void:
	PlayerSettings.forget_for_test()
	near(SettingsApply.level_db(1.0), 0.0, 0.001, "full is the mix as it was tuned")
	lt(SettingsApply.level_db(0.5), 0.0, "half is quieter")
	eq(SettingsApply.level_db(0.0), SettingsApply.SILENT_DB, "and nothing is silence")
	gt(SettingsApply.level_db(0.01), SettingsApply.SILENT_DB - 0.001, "never below the floor")


## The keys page is drawn from the live input map, so an action another package
## adds is named without anybody writing it down a second time.
func test_the_keys_page_reads_the_map_and_not_a_list_of_letters() -> void:
	PlayerSettings.forget_for_test()
	for b: Dictionary in PlayerSettings.BINDABLE:
		check(String(b.get("label", "")) != "", "%s has words" % b.action)
	# Every bindable action the project ships with is really there. (An action a
	# package adds at load — targeting's, a craft's — is allowed to be absent in a
	# headless test, and the page leaves out what this build does not have.)
	var known := 0
	for b: Dictionary in PlayerSettings.BINDABLE:
		if InputMap.has_action(b.action):
			known += 1
			check(PlayerSettings.key_of(b.action) != KEY_NONE, "%s is on a key" % b.action)
	gt(known, 8, "most of the map is bindable: %d" % known)


func test_a_key_may_only_do_one_thing() -> void:
	PlayerSettings.forget_for_test()
	if not InputMap.has_action(&"map") or not InputMap.has_action(&"lamp"):
		return
	PlayerSettings.remember_defaults()
	var lamp_was := PlayerSettings.key_of(&"lamp")
	var stolen := PlayerSettings.bind_key(&"map", lamp_was)
	eq(stolen, &"lamp", "the page says which one it was taken off")
	eq(PlayerSettings.key_of(&"map"), lamp_was)
	eq(PlayerSettings.key_of(&"lamp"), KEY_NONE, "and that one has nothing until it is given one")
	PlayerSettings.reset_keys()
	eq(PlayerSettings.key_of(&"lamp"), lamp_was, "put back is really put back")
	# And put back whole: several actions ship with two keys, and taking one of
	# them off must not lose the other for good.
	var two := &"dodge" if InputMap.has_action(&"dodge") else &""
	if two != &"":
		var had := InputMap.action_get_events(two).size()
		PlayerSettings.bind_key(two, KEY_F9)
		eq(InputMap.action_get_events(two).size(), 1, "bound to one key it is on one key")
		PlayerSettings.reset_keys()
		eq(InputMap.action_get_events(two).size(), had, "and every key it came with comes back")


func test_what_is_kept_comes_back_and_is_not_a_save() -> void:
	PlayerSettings.forget_for_test()
	PlayerSettings.set_value(&"sound.score", 0.3)
	PlayerSettings.set_value(&"picture.flashes", false)
	PlayerSettings.save()
	PlayerSettings.reread_for_test()
	near(float(PlayerSettings.value(&"sound.score")), 0.3, 0.001)
	eq(PlayerSettings.value(&"picture.flashes"), false)
	# It is its own file: not a save slot, not dev mode's state, not a configuration.
	check(PlayerSettings.file.begins_with("user://"))
	check(not PlayerSettings.file.begins_with(SaveSlots.PLAYER_ROOT), "never in with the saves")
	check(not PlayerSettings.file.begins_with(DevMode.USER_ROOT), "never in with dev mode's")
	eq(PlayerSettings.file, PlayerSettings.TEST_FILE, "and a test never writes the player's own")
	for r: Dictionary in ConfigSchema.ROWS:
		check(PlayerSettings.row(r.id).is_empty(),
			"%s is the owner's to set in a build, not the player's" % r.id)
	# **AND PUT THE GLOBAL BACK, BECAUSE THIS ONE HAS A VICTIM.** Every test in
	# this file opens with `forget_for_test`, which protects it from whatever ran
	# before — and protects nothing from IT. This test is the only one that leaves
	# a setting changed AND saved, and `picture.flashes` false is read live by
	# `MobFx.set_flash`, which then refuses to make the per-part material copy at
	# all. Proved directly: with it left false,
	# `test_marks.gd:test_the_flash_is_written_into_a_copy_and_never_into_a_shared_material`
	# gets `material_override == shared` and fails, in another directory, for a
	# reason nothing in its own file mentions. `forget_for_test` clears the values,
	# the keys and the runner's own settings file, so it is a whole teardown and
	# not a hopeful one.
	PlayerSettings.forget_for_test()


## A key a player asked to press once must behave like one, and the two keys that
## offer it are the two this game holds down (crouch, and the slate on a machine).
func test_a_held_key_can_be_made_a_pressed_one() -> void:
	PlayerSettings.forget_for_test()
	HoldToggle.forget()
	if not InputMap.has_action(&"crouch"):
		return
	# Hold: it is down exactly while the key is down.
	Input.action_press(&"crouch")
	check(HoldToggle.on(&"crouch", &"playing.crouch"), "held down it is on")
	Input.action_release(&"crouch")
	check(not HoldToggle.on(&"crouch", &"playing.crouch"), "and let go it is off")
	# Toggle: a press flips it and it stays.
	PlayerSettings.set_value(&"playing.crouch", &"toggle")
	HoldToggle.forget()
	# A frame between letting go and pressing: a key still down when everything
	# was let go is not a new press, which is the rule that keeps a page closing
	# from putting the latch back on.
	await tree.process_frame
	Input.action_press(&"crouch")
	check(HoldToggle.on(&"crouch", &"playing.crouch"), "a press puts it on")
	Input.action_release(&"crouch")
	check(HoldToggle.on(&"crouch", &"playing.crouch"), "and it stays on with the key let go")
	HoldToggle.forget()
	await tree.process_frame
	Input.action_release(&"crouch")
	check(not HoldToggle.on(&"crouch", &"playing.crouch"), "and a game that ends drops it")
	PlayerSettings.set_value(&"playing.crouch", &"hold")
