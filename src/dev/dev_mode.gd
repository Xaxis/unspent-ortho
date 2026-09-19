class_name DevMode
## Whether dev mode can be reached in this run, and what this machine can do
## with it (docs/DEV.md).
##
##   DevMode.boot(options, args)   main.gd, once: which configuration, armed or not
##   DevMode.reachable()           the dev row shows and ` opens the dev app
##   DevMode.local()               builds, the shelf, deploys, the gate and tours
##   DevMode.chord(now_ms)         a ` struck: three inside CHORD_MS arm it (access chord)
##
## Access comes from the active configuration's `dev.access`, with two rules
## over it. A run by a tool (a shot, a tour, the browser probe, the test runner)
## never reads what the owner chose last time, and reaches nothing unless it is
## given --dev or --config. A run from source for a person is the owner at their
## own machine: it is never below `chord`, so choosing the release configuration
## to try it cannot lock the owner out of dev mode.
##
## Light on purpose (main.gd calls it before the first frame).

## Everything dev mode keeps on a device lives under here. The test runner and
## the tools keep their own, as their saves do, so no test, shot or tour ever
## writes into the owner's notes, configurations or logs.
const USER_ROOT := "user://dev"
const TEST_ROOT := "user://test-dev"
const TOOL_ROOT := "user://tool-dev"
## Three strikes of ` inside this many milliseconds arm dev mode.
const CHORD_MS := 1500
const CHORD_COUNT := 3
const ACCESS: Array[StringName] = [&"off", &"chord", &"open"]

## Actions dev mode adds to the input map while it can be reached, and their keys.
## Every dev action takes a LIST of keys, and every one of them has a letter in
## it, because the function row is not a function row on a laptop (owner,
## 2026-09-18: "the function keys literally dont work or do anything on macbooks
## and many laptops"). On a MacBook F2 is screen brightness unless Fn is held, so
## a dev mode keyed to the function row is a dev mode nobody can open.
##
## The letters are picked from what the GAME does not already own — the player
## has WASD, shift, space, j, k, e, c, i, m, f, q, z, b, h, n, esc and the
## backtick — so none of these can steal a key out from under a press the player
## already means. Keeping the function keys as the second event costs nothing and
## leaves anyone with a real keyboard the binding they already learnt.
const ACTIONS := {
	&"dev_toggle": [KEY_QUOTELEFT],
	&"dev_note": [KEY_O, KEY_F2],
	&"dev_readout": [KEY_R, KEY_F3],
	&"dev_picture": [KEY_P, KEY_F4],
	# Off the player and out over the island (95_flyover). It belongs with the
	# readout and the picture: the three things that change what you are LOOKING
	# at rather than what the world is doing.
	&"dev_fly": [KEY_V, KEY_F5],
	# The zoom gets keys of its OWN rather than borrowing the game's. The first
	# version used `craft` and `crouch`, which are c and ctrl — so the first frame
	# of the proof was the MAKING page, opened four times by the zoom. A dev mode
	# that steals a key the player already owns is a dev mode that lies about what
	# the game does.
	&"dev_fly_in": [KEY_EQUAL],
	&"dev_fly_out": [KEY_MINUS],
	# Every region picked out and named, over the flyover (`DevRegions`).
	&"dev_regions": [KEY_G, KEY_F6],
}

## Armed by the chord (or --dev), and remembered on this device.
static var armed := false
## The readout is on the glass's edge (remembered).
static var readout := false
## A tool's run: see the header. The test runner is one from the start.
static var tool_run := OS.get_cmdline_args().has("-s")
## --dev was given (a tool asking for dev mode), and the page it named, if any.
static var asked := false
static var asked_page := ""
## --config was given.
static var configured := false
## Anything dev mode changed in the running game (cheats, a live rule): a save
## made after it says so.
static var touched := false
static var _strikes: Array[int] = []


## Once, at start-up, before any scene: the active configuration, and whether
## dev mode is armed. `args` are the command line's user arguments, so what was
## named there is never overridden by a configuration.
static func boot(o: BootOptions, args: PackedStringArray) -> void:
	tool_run = o.shot != "" or o.tour != "" or o.probe or OS.get_cmdline_args().has("-s")
	var stamp := DevStamp.current()
	if not flags_allowed(exported(), stamp):
		# A shipped app launched with --dev or --config=dev must not open what its
		# configuration shut.
		o.dev = false
		o.dev_page = ""
		o.config = ""
	asked = o.dev
	asked_page = o.dev_page
	configured = o.config != ""
	if configured:
		var why := GameConfig.use(o.config)
		if why != "":
			push_warning("--config=%s: %s" % [o.config, why])
	elif not stamp.is_empty():
		GameConfig.use_stamp(stamp)
	elif not tool_run and not exported():
		var st := read_state()
		var name := str(st.get("config", "dev"))
		if GameConfig.exists(name):
			GameConfig.use(name)
	if not tool_run:
		var st := read_state()
		armed = bool(st.get("armed", false))
		readout = bool(st.get("readout", false))
	if asked:
		armed = true
	GameConfig.fill_boot(o, explicit(args))
	if reachable():
		ensure_actions()


## Whether --dev and --config are taken: always from source; in an exported build
## only where the build's own configuration lets dev mode in at all.
static func flags_allowed(is_exported: bool, stamp: Dictionary) -> bool:
	if not is_exported:
		return true
	var settings: Dictionary = stamp.get("settings", {})
	return str(settings.get("dev.access", "off")) != "off"


## The option names given on a command line: {"seed": true, ...}.
static func explicit(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a in args:
		if a.begins_with("--"):
			out[a.trim_prefix("--").split("=", true, 1)[0]] = true
	return out


## off, chord or open, for this run.
static func access() -> StringName:
	var a := StringName(str(GameConfig.value("dev.access")))
	if not ACCESS.has(a):
		a = &"off"
	if tool_run:
		if asked:
			return &"open"
		return a if configured else &"off"
	if not exported() and ACCESS.find(a) < ACCESS.find(&"chord"):
		return &"chord"
	return a


static func reachable() -> bool:
	match access():
		&"open":
			return true
		&"chord":
			return armed
	return false


## A strike of the chord key at `now_ms`. True when this strike TURNED dev mode,
## either way: the same three strikes that arm it put it away again (owner,
## 2026-09-18, "a hotkey to toggle into and out of developer mode... pressing the
## backtick 3 times in rapid succession").
##
## It used to arm only, and the way out was a row on the dev app's home page —
## so the gesture the owner asked for existed but went one way, and getting out
## meant finding a menu. A toggle has to be a toggle or nobody trusts it.
##
## Where access is `open` the configuration has already said dev mode is reachable
## and the chord is not the door, so it stays out of the way.
static func chord(now_ms: int) -> bool:
	if access() != &"chord":
		return false
	_strikes.append(now_ms)
	while not _strikes.is_empty() and now_ms - _strikes[0] > CHORD_MS:
		_strikes.remove_at(0)
	if _strikes.size() < CHORD_COUNT:
		return false
	_strikes.clear()
	if armed:
		disarm()
	else:
		arm()
	return true


static func arm() -> void:
	armed = true
	ensure_actions()
	write_state()


## Put dev mode away. Where access is open it stays reachable (the configuration says so).
static func disarm() -> void:
	armed = false
	readout = false
	write_state()


static func set_readout(on: bool) -> void:
	readout = on
	write_state()


# --- the host -----------------------------------------------------------------

static func web() -> bool:
	return OS.has_feature("web")


## An exported build (a template), not a run from source.
static func exported() -> bool:
	return OS.has_feature("template")


## The machine the game is built on: from source, not the web, with the tools beside it.
static func local() -> bool:
	return not exported() and not web() and FileAccess.file_exists(project_path("tools/export.sh"))


## A path inside the project on disk (local runs only).
static func project_path(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join(rel)


## What this run is, in a word or two for the slate.
static func host() -> String:
	if web():
		return "web build" + ("" if OS.has_feature("threads") else ", no threads")
	if exported():
		return "%s app" % OS.get_name().to_lower()
	return "source" if local() else "source, no tools"


## Why a local-only row cannot be done here, in one plain line.
static func why_not_local() -> String:
	if local():
		return ""
	if web() or exported():
		return "Builds are made on the machine the game is built on."
	return "The tools are not beside this copy of the game."


# --- the input map ----------------------------------------------------------------

## Add dev mode's actions to the input map (once). Physical keys, so ` is the key
## left of 1 on any layout.
static func ensure_actions() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in ACTIONS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = code
			InputMap.action_add_event(action, e)


# --- what is remembered on this device ----------------------------------------------

static func user_root() -> String:
	if OS.get_cmdline_args().has("-s"):
		return TEST_ROOT
	return TOOL_ROOT if tool_run else USER_ROOT


static func state_path() -> String:
	return user_root().path_join("state.json")


static func read_state() -> Dictionary:
	if not FileAccess.file_exists(state_path()):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(state_path()))
	return v if v is Dictionary else {}


## Tool runs never write it: a tour must not arm the owner's next session.
static func write_state() -> void:
	if tool_run:
		return
	var st := {"armed": armed, "readout": readout}
	if not exported() and GameConfig.source != &"stamp":
		st["config"] = GameConfig.active
	DirAccess.make_dir_recursive_absolute(user_root())
	var f := FileAccess.open(state_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(st, "\t", true))
		f.close()
