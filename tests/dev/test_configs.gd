extends TestCase
## Master configurations (docs/DEV.md): every file in configs/ holds only settings
## the schema declares, with values the game's content allows; bases merge under
## a configuration; edits are live and kept only when kept; a start takes what a
## configuration says and never what the command line already named.

const SCRATCH := "user://test-dev-configs"


func _after() -> void:
	GameConfig.clear()


func test_every_configuration_checks_against_the_schema_and_the_content() -> void:
	var names := GameConfig.names()
	for want: String in ["dev", "playtest", "release"]:
		check(names.has(want), "configs/%s.json is there" % want)
	for name in names:
		var r := GameConfig.resolve(name)
		check(r.ok, "%s resolves: %s" % [name, r.why])
		if r.ok:
			eq(ConfigChoices.problems(r.settings), PackedStringArray(), "%s holds only what the game allows" % name)
	_after()


func test_every_setting_has_a_default_that_passes_its_own_check() -> void:
	var groups := {}
	for row: Dictionary in ConfigSchema.ROWS:
		eq(ConfigChoices.check(row.id, ConfigSchema.default_of(row.id)), "", "%s's default" % row.id)
		check(ConfigSchema.GROUPS.has(row.group), "%s is in a known group" % row.id)
		check(String(row.id).begins_with(row.group + "."), "%s is named for its group" % row.id)
		check(["boot", "new", "live", "build"].has(row.applies), "%s says when it applies" % row.id)
		check(str(row.get("note", "")) != "", "%s says what it does" % row.id)
		groups[row.group] = true
	eq(groups.size(), ConfigSchema.GROUPS.size(), "every group has a setting")


## The defaults are the game as it was before configurations existed, so a run
## with none active is unchanged: a shot, a tour, the test runner.
func test_the_defaults_are_the_game_as_it_is() -> void:
	GameConfig.clear()
	eq(int(GameConfig.value("world.size")), Tuning.WORLD_SIZE)
	eq(float(GameConfig.value("world.hour")), Tuning.START_HOUR)
	eq(float(GameConfig.value("rules.clock")), Tuning.MINUTES_PER_SECOND)
	eq(str(GameConfig.value("dev.access")), "off", "nothing ships with dev mode unless a configuration says so")
	var o := BootOptions.parse(["--seed=3"])
	var before := [o.seed_value, o.size, o.hour, o.place, o.weather, o.give.duplicate(), o.fit.duplicate(), o.lamp]
	GameConfig.fill_boot(o, {"seed": true})
	GameConfig.fill_new_game(o)
	eq([o.seed_value, o.size, o.hour, o.place, o.weather, o.give, o.fit, o.lamp], before, "no configuration, no change to a start")


func test_a_base_merges_under_and_release_turns_dev_mode_off() -> void:
	var r := GameConfig.resolve("release")
	check(r.ok, r.why)
	eq(r.chain, PackedStringArray(["release", "playtest"]))
	eq(str(r.settings.get("dev.access")), "off")
	eq(str(r.settings.get("build.channel")), "release")
	eq(str(r.settings.get("build.version")), str(GameConfig.resolve("playtest").settings.get("build.version")), "the version comes up from playtest")


func test_a_file_that_names_an_unknown_setting_or_a_bad_value_is_refused() -> void:
	check(not GameConfig.parse('{"settings": {"rules.flying": true}}', "x").ok, "an unknown setting")
	check(not GameConfig.parse('{"settings": {"world.size": 500}}', "x").ok, "a size that is not offered")
	check(not GameConfig.parse('{"settings": {"world.seed": 0}}', "x").ok, "a seed out of range")
	check(not GameConfig.parse('{"settings": {"builds.targets": []}}', "x").ok, "a build of nothing")
	check(not GameConfig.parse('not json', "x").ok)
	var ok := GameConfig.parse('{"settings": {"world.size": 384.0, "start.kit": {"driftwood": 3.0}}}', "x")
	check(ok.ok, ok.why)
	eq(typeof(ok.settings["world.size"]), TYPE_INT, "numbers come back as the game reads them")
	eq(typeof(ok.settings["start.kit"]["driftwood"]), TYPE_INT)
	eq(ConfigChoices.check("start.kit", {"unobtainium": 1}).is_empty(), false, "a kit of nothing that exists")
	eq(ConfigChoices.check("world.start", "atlantis").is_empty(), false, "a start nowhere")
	eq(ConfigChoices.check("world.start", "snowfield"), "", "a landscape is a start")


func test_edits_are_live_and_dropped_when_set_back() -> void:
	check(GameConfig.use("playtest") == "")
	var kept: Variant = GameConfig.value("rules.clock")
	eq(GameConfig.set_value("rules.clock", 10.0), "")
	eq(float(GameConfig.value("rules.clock")), 10.0, "an edit reads at once")
	check(GameConfig.edits.has("rules.clock"))
	eq(GameConfig.set_value("rules.clock", kept), "")
	check(not GameConfig.edits.has("rules.clock"), "set back, it is no edit at all")
	check(GameConfig.set_value("rules.clock", 7.0) != "", "a value the setting does not offer")
	_after()


func test_a_start_takes_the_configuration_but_never_over_the_command_line() -> void:
	GameConfig.clear()
	GameConfig.set_value("world.hour", 19.5)
	GameConfig.set_value("world.start", "moss")
	GameConfig.set_value("world.weather", "fog")
	GameConfig.set_value("world.weather_strength", 0.5)
	GameConfig.set_value("start.kit", {"driftwood": 4})
	GameConfig.set_value("start.fit", ["glide_wing"])
	GameConfig.set_value("start.lamp", true)
	var o := BootOptions.new()
	GameConfig.fill_new_game(o)
	eq(o.hour, 19.5)
	eq(o.place, "moss")
	eq(o.weather, "fog:0.5")
	eq(int(o.give.get(&"driftwood", 0)), 4)
	eq(o.fit, PackedStringArray(["glide_wing"]))
	check(o.lamp)
	var args := PackedStringArray(["--hour=6", "--at=10,10", "--give=stone:1"])
	var named := BootOptions.parse(args)
	GameConfig.fill_new_game(named, DevMode.explicit(args))
	eq(named.hour, 6.0, "the hour named stays")
	eq(named.place, "", "a place named by --at is not moved")
	eq(named.give, {&"stone": 1}, "the kit named stays as named")
	var loaded := BootOptions.new()
	loaded.load_slot = 1
	GameConfig.fill_new_game(loaded)
	eq(loaded.hour, Tuning.START_HOUR, "a loaded game is the save's, not the configuration's")
	_after()


func test_keep_as_writes_only_what_differs_from_the_base_and_reads_back() -> void:
	# Written to a scratch folder standing in for configs/, so the test never
	# touches the repository's own configurations.
	check(GameConfig.use("playtest") == "")
	GameConfig.set_value("rules.harm", 0.5)
	var text := GameConfig.to_text("playtest", {"rules.harm": 0.5})
	var back := GameConfig.parse(text, "scratch")
	check(back.ok, back.why)
	eq(back.base, "playtest")
	eq(back.settings, {"rules.harm": 0.5})
	check(not GameConfig.valid_name("Has Spaces"))
	check(not GameConfig.valid_name(""))
	check(GameConfig.valid_name("playtest-2"))
	eq(GameConfig.keep_as("no good"), "A name is small letters, digits and dashes.")
	var pasted := GameConfig.parse(GameConfig.export_text(), "pasted")
	check(pasted.ok, "what is copied out pastes back in: %s" % pasted.why)
	eq(float(pasted.settings.get("rules.harm", 1.0)), 0.5, "with the edit in it")
	eq(str(pasted.settings.get("dev.access", "")), "chord", "and what the base said, so it stands on its own")
	_after()


func test_choices_step_round_and_say_what_they_are() -> void:
	eq(ConfigChoices.step("world.size", 768, 1), 256, "a choice wraps")
	eq(ConfigChoices.step("world.size", 512, -1), 384)
	eq(ConfigChoices.step("start.lamp", false, 1), true)
	eq(ConfigChoices.step("world.seed", 99999, 1), 1)
	eq(ConfigChoices.show("rules.clock", 1.0), "x1  a day in 24 min")
	eq(ConfigChoices.show("rules.clock", 0.0), "stopped")
	eq(ConfigChoices.show("rules.harm", 0.0), "none")
	eq(ConfigChoices.show("world.hour", 19.5), "19:30")
	eq(ConfigChoices.show("builds.targets", ["web", "web-nothreads"]), "web web no threads")
	check(ConfigChoices.options("world.start").has("spawn"))
	check(ConfigChoices.options("world.weather").has("rules"))


func test_a_loaded_game_keeps_its_own_island() -> void:
	GameConfig.clear()
	GameConfig.set_value("world.seed", 42)
	GameConfig.set_value("world.size", 256)
	var o := BootOptions.new()
	o.seed_value = 7
	o.size = 512
	o.load_slot = 0
	GameConfig.fill_boot(o, {"load": true})
	eq([o.seed_value, o.size], [7, 512], "--load filled the save's seed and size; a configuration never overwrites them")
	var fresh := BootOptions.new()
	GameConfig.fill_boot(fresh)
	eq([fresh.seed_value, fresh.size], [42, 256], "a new start takes them")
	GameConfig.clear()


func test_a_pasted_configuration_is_exactly_what_was_pasted() -> void:
	# The one in use opens dev mode; the paste (copied out of a release build) says
	# nothing of dev mode, because off is the default and a copy leaves defaults out.
	check(GameConfig.use("dev") == "")
	eq(str(GameConfig.value("dev.access")), "open")
	var parsed := GameConfig.parse('{"name": "test-pasted", "settings": {"build.channel": "release", "world.hour": 6.5}}', "x")
	check(parsed.ok, parsed.why)
	var name := "test-pasted-%d" % Time.get_ticks_usec()
	eq(GameConfig.keep_pasted(parsed.settings, name), "")
	var back := GameConfig.resolve(name)
	check(back.ok, back.why)
	eq(back.settings, {"build.channel": "release", "world.hour": 6.5}, "nothing of dev rode in")
	eq(str(GameConfig.value("dev.access")), "off", "and dev mode is off in it")
	DirAccess.remove_absolute(GameConfig.user_dir().path_join(name + ".json"))
	GameConfig.clear()
