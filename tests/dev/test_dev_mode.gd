extends TestCase
## Who can reach dev mode (docs/DESIGN.md): tool runs reach nothing unless asked;
## a build reaches what its configuration says; the owner's source run is never
## locked out; the chord arms in three strikes and not in three slow ones.

var _was := {}


func _keep() -> void:
	_was = {"tool_run": DevMode.tool_run, "asked": DevMode.asked, "configured": DevMode.configured,
		"armed": DevMode.armed, "readout": DevMode.readout}


func _restore() -> void:
	DevMode.tool_run = _was.tool_run
	DevMode.asked = _was.asked
	DevMode.configured = _was.configured
	DevMode.armed = _was.armed
	DevMode.readout = _was.readout
	GameConfig.clear()


func test_a_tool_run_reaches_nothing_unless_it_asks() -> void:
	_keep()
	DevMode.tool_run = true
	DevMode.asked = false
	DevMode.configured = false
	GameConfig.use("dev")
	eq(DevMode.access(), &"off", "a shot or a tour never sees the owner's dev configuration")
	DevMode.configured = true
	eq(DevMode.access(), &"open", "unless it was handed one with --config")
	GameConfig.use("release")
	eq(DevMode.access(), &"off")
	DevMode.asked = true
	eq(DevMode.access(), &"open", "--dev asks for it")
	check(DevMode.reachable())
	_restore()


func test_the_owner_at_their_own_machine_is_never_locked_out() -> void:
	_keep()
	DevMode.tool_run = false
	DevMode.asked = false
	DevMode.armed = false
	GameConfig.use("release")
	# The test runner is a run from source, as the owner's is.
	eq(DevMode.access(), &"chord", "release says off; from source it is still a chord away")
	check(not DevMode.reachable())
	GameConfig.use("dev")
	eq(DevMode.access(), &"open")
	check(DevMode.reachable())
	_restore()


func test_the_chord_arms_on_three_quick_strikes_only() -> void:
	_keep()
	DevMode.tool_run = true # never writes the owner's state file
	DevMode.asked = false
	DevMode.configured = true
	DevMode.armed = false
	GameConfig.use("playtest")
	eq(DevMode.access(), &"chord")
	check(not DevMode.chord(1000))
	check(not DevMode.chord(2000))
	check(not DevMode.chord(3000), "three strikes a second apart are not the chord")
	check(not DevMode.armed)
	check(not DevMode.chord(10000))
	check(not DevMode.chord(10400))
	check(DevMode.chord(10800), "three inside a second and a half are")
	check(DevMode.armed and DevMode.reachable())
	for action: StringName in DevMode.ACTIONS:
		check(InputMap.has_action(action), "%s is on the input map once armed" % action)
	_restore()


## The owner asked for a hotkey "to toggle into and out of developer mode"
## (2026-09-18). It armed only for its whole life, and the way out was a row on
## the dev app's home page — so the gesture existed and went one way.
func test_the_same_chord_puts_dev_mode_away_again() -> void:
	_keep()
	DevMode.tool_run = true
	DevMode.asked = false
	DevMode.configured = true
	DevMode.armed = false
	DevMode.readout = true
	GameConfig.use("playtest")
	check(not DevMode.chord(1000))
	check(not DevMode.chord(1400))
	check(DevMode.chord(1800), "three quick strikes arm it")
	check(DevMode.reachable())
	check(not DevMode.chord(1900), "and the count starts again, so a fourth strike is not a fifth")
	check(not DevMode.chord(2200))
	check(DevMode.chord(2500), "three more put it away")
	check(not DevMode.armed and not DevMode.reachable())
	check(not DevMode.readout, "and the readout goes off the glass with it")
	# Where the configuration itself says dev mode is open the chord is not the
	# door, so it must not become a way to shut what the build declared.
	DevMode.armed = true
	GameConfig.use("dev")
	eq(DevMode.access(), &"open")
	check(not DevMode.chord(3000))
	check(not DevMode.chord(3200))
	check(not DevMode.chord(3400), "the chord is ignored where access is open")
	check(DevMode.reachable())
	_restore()


func test_a_stamp_is_what_a_build_says_it_is() -> void:
	_keep()
	var r := GameConfig.resolve("playtest")
	var stamp := DevStamp.make("playtest", r, "web", "release", "a1b2c3d", true, 1789560000)
	eq(stamp.channel, "playtest")
	eq(stamp.version, str(r.settings["build.version"]))
	eq(DevStamp.label(stamp), "playtest %s a1b2c3d+" % stamp.version, "a dirty tree is marked")
	eq(stamp.chain, ["playtest"])
	# Through JSON and back, as a build reads it.
	var back: Dictionary = JSON.parse_string(JSON.stringify(stamp))
	GameConfig.use_stamp(back)
	eq(GameConfig.source, &"stamp")
	eq(GameConfig.active, "playtest")
	eq(str(GameConfig.value("dev.access")), "chord")
	eq(typeof(GameConfig.value("world.size")), TYPE_INT)
	eq(DevStamp.current(), {}, "a run from source never believes a stamp")
	var none := DevStamp.make("", {"chain": PackedStringArray(), "settings": {}}, "mac", "debug", "", false, 0)
	GameConfig.use_stamp(none)
	eq(str(GameConfig.value("dev.access")), "off", "a build of no configuration has no dev mode")
	_restore()


func test_the_command_line_names_are_read_as_named() -> void:
	eq(DevMode.explicit(PackedStringArray(["--seed=3", "--run", "--config=dev", "plain"])), {"seed": true, "run": true, "config": true})
	var o := BootOptions.parse(["--dev=config:rules.clock", "--config=playtest"])
	check(o.dev)
	eq(o.dev_page, "config:rules.clock")
	eq(o.config, "playtest")
	check(BootOptions.parse(["--dev"]).dev)
	eq(BootOptions.parse(["--dev"]).dev_page, "")


func test_a_build_of_no_configuration_is_a_release_with_nothing_on_its_title() -> void:
	var none := DevStamp.make("", {"chain": PackedStringArray(), "settings": {}}, "web", "release", "a1b2c3d", false, 0)
	eq(none.channel, "release", "what tools/deploy.sh sends the domain")


func test_a_shipped_build_takes_dev_flags_only_where_its_stamp_lets_dev_mode_in() -> void:
	check(DevMode.flags_allowed(false, {}), "from source, always")
	check(not DevMode.flags_allowed(true, {}), "a build of no configuration: never")
	check(not DevMode.flags_allowed(true, {"settings": {"dev.access": "off"}}), "a release: never")
	check(DevMode.flags_allowed(true, {"settings": {"dev.access": "chord"}}), "a playtest: yes")
