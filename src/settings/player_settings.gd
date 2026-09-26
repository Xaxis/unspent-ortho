class_name PlayerSettings
## What the person at the keyboard has set: how loud it is, how big the window
## is, which key does what, and the handful of switches a player expects to find
## (owner, 2026-09-17).
##
## **Not the same thing as a master configuration.** `src/dev/config_schema.gd`
## is the OWNER's: what a build was made to be, packed inside it, and a player
## never sees it. This is the player's, kept on their own device, and a build
## carries none of it. Neither reads the other.
##
##   PlayerSettings.load_once()        read the file (main.gd, once, at boot)
##   PlayerSettings.value(id)          what a setting is now
##   PlayerSettings.set_value(id, v)   set it, apply it, and keep it
##   PlayerSettings.key_of(action)     the key an action is on, rebinds included
##
## A setting is ONE row in `ROWS`: its id (`group.name`), what kind of thing it
## is, its default, and what it may be. The defaults are the game as it ships, so
## a player who never opens the page is playing exactly what the owner built.

## Where the player's own settings are kept, and the two files that are not
## theirs. A test run and a tool run each write their own, the way dev mode keeps
## `user://dev`, `user://test-dev` and `user://tool-dev` apart: a test that saved
## a level once turned the sound down in every shot taken afterwards, and nothing
## on the screen said why.
const FILE := "user://settings.json"
## The runner's is in its own home (RunnerHome), since runners on one machine
## share user://.
static var TEST_FILE := RunnerHome.path().path_join("settings.json")
const TOOL_FILE := "user://tool-settings.json"
const VERSION := 1

## Which of the three this run writes. main.gd sets it before anything reads.
static var file := FILE


## A run that is not a person playing keeps its own: `tool` for a shot or a tour,
## `test` for the runner. Called before `load_once`, and it forgets anything read
## under the old one.
static func use_file(which: StringName) -> void:
	var want := FILE
	match which:
		&"tool":
			want = TOOL_FILE
		&"test":
			want = TEST_FILE
	if want == file:
		return
	file = want
	_values.clear()
	_loaded = false

## Kinds a row may be.
const LEVEL := &"level"    # 0..1, shown as a bar
const SWITCH := &"switch"  # on or off
const CHOICE := &"choice"  # one of `options`

## Groups, in the order the page shows them.
const GROUPS: Array[StringName] = [&"sound", &"picture", &"playing", &"controls"]

## Which of ControlScheme's three the map is: a mouse, a trackpad, the keyboard
## alone. Its default is worked out for the machine (`default_of`), not written.
const SCHEME := &"controls.scheme"

## Every setting. `applies` says what has to be told when it changes:
## &"sound" the buses, &"window" the window, &"" nothing (whoever reads it asks).
const ROWS: Array[Dictionary] = [
	{"id": &"sound.overall", "group": &"sound", "label": "everything", "kind": LEVEL,
		"default": 0.8, "applies": &"sound",
		"help": "how loud the slate and the world are together"},
	{"id": &"sound.world", "group": &"sound", "label": "the world", "kind": LEVEL,
		"default": 1.0, "applies": &"sound",
		"help": "wind, water, work, machines, your own feet"},
	{"id": &"sound.score", "group": &"sound", "label": "the score", "kind": LEVEL,
		"default": 0.8, "applies": &"sound",
		"help": "the music each landscape plays"},
	{"id": &"picture.scale", "group": &"picture", "label": "window", "kind": CHOICE,
		"default": 2, "options": [1, 2, 3, 4], "applies": &"window",
		"help": "whole pixels of yours to one of the game's"},
	{"id": &"picture.fullscreen", "group": &"picture", "label": "fullscreen", "kind": SWITCH,
		"default": false, "applies": &"window"},
	{"id": &"picture.quality", "group": &"picture", "label": "quality", "kind": CHOICE,
		"default": &"auto", "from": &"quality", "applies": &"quality",
		"help": "how much of the picture this machine is asked to draw"},
	# 0..1 across the range `src/systems/09_view.gd` holds (CLOSE..FAR), not a
	# height in world units: a level is what the page's own widget draws, and a
	# unit would put the camera's numbers on it. The default is that file's
	# `level_of(CameraRig.VIEW_HEIGHT)` — written out as a number here because
	# ROWS is a const and cannot call it, and a system's file name cannot be a
	# class_name to call it THROUGH. `tests/settings/test_zoom.gd` asks the real
	# function and fails if this number stops meaning the play camera.
	{"id": &"picture.zoom", "group": &"picture", "label": "how far back the camera sits", "kind": LEVEL,
		"default": 0.24, "applies": &"",
		"help": "+ and - move it while you play; this is where it opens"},
	{"id": &"picture.shake", "group": &"picture", "label": "the camera shakes", "kind": LEVEL,
		"default": 1.0, "applies": &"",
		"help": "how far the picture moves when something lands"},
	{"id": &"picture.flashes", "group": &"picture", "label": "flashes", "kind": SWITCH,
		"default": true, "applies": &"",
		"help": "a struck body goes white for a moment"},
	{"id": &"playing.crouch", "group": &"playing", "label": "crouch", "kind": CHOICE,
		"default": &"hold", "options": [&"hold", &"toggle"], "applies": &"",
		"help": "hold the key down, or press it once"},
	{"id": &"playing.target", "group": &"playing", "label": "reading a machine", "kind": CHOICE,
		"default": &"hold", "options": [&"hold", &"toggle"], "applies": &"",
		"help": "hold the key down, or press it once"},
	# The view over the shoulder (41_shoulder): where a game opens, and whether its
	# key is held or pressed. Opening over the shoulder turns the key round -- held,
	# it looks down on the land -- so one key answers both ways.
	{"id": &"playing.view", "group": &"playing", "label": "where the camera starts", "kind": CHOICE,
		"default": &"top", "options": [&"top", &"shoulder"], "applies": &"",
		"help": "looking down on the land, or over your shoulder"},
	{"id": &"playing.shoulder", "group": &"playing", "label": "the view over your shoulder", "kind": CHOICE,
		"default": &"toggle", "options": [&"hold", &"toggle"], "applies": &"",
		"help": "hold the key down, or press it once"},
	# The whole map at once (ControlScheme). Its `default` is only the fallback for
	# a machine nothing can be learnt about: `default_of` asks the machine.
	{"id": &"controls.scheme", "group": &"controls", "label": "how you hold the game", "kind": CHOICE,
		"default": &"mouse", "options": [&"mouse", &"trackpad", &"keys"], "applies": &"controls",
		"help": "a mouse, a laptop's trackpad, or the keyboard alone"},
]

## The actions a player may put on another key, in the order they meet them.
## Read against the LIVE InputMap, never a hand-written list of letters: the old
## controls page was a const table and had already drifted from the real keys.
const BINDABLE: Array[Dictionary] = [
	{"action": &"move_up", "label": "walk up"},
	{"action": &"move_down", "label": "walk down"},
	{"action": &"move_left", "label": "walk left"},
	{"action": &"move_right", "label": "walk right"},
	{"action": &"run", "label": "run, tap to dodge"},
	{"action": &"dodge", "label": "dodge"},
	{"action": &"crouch", "label": "crouch"},
	{"action": &"jump", "label": "jump up a ledge, over a gap"},
	{"action": &"swing", "label": "swing, or pull free"},
	{"action": &"use", "label": "use what is in reach"},
	{"action": &"drop", "label": "put down what is in hand"},
	{"action": &"target", "label": "lock onto a machine"},
	{"action": &"target_next", "label": "the next one along"},
	{"action": &"target_prev", "label": "the one before"},
	{"action": &"shoulder", "label": "look over your shoulder"},
	{"action": &"look_up", "label": "look up"},
	{"action": &"look_down", "label": "look down"},
	{"action": &"look_left", "label": "look left"},
	{"action": &"look_right", "label": "look right"},
	{"action": &"ride", "label": "board a craft"},
	{"action": &"lamp", "label": "lamp"},
	{"action": &"ability_dash", "label": "dash"},
	{"action": &"ability_scan", "label": "scan"},
	{"action": &"ability_grapple", "label": "grapple"},
	{"action": &"ability_glide", "label": "glide"},
	{"action": &"ability_spoof", "label": "spoof"},
	{"action": &"inventory", "label": "carrying"},
	{"action": &"craft", "label": "making"},
	{"action": &"holding", "label": "your holding"},
	{"action": &"zoom_in", "label": "zoom in"},
	{"action": &"zoom_out", "label": "zoom out"},
	{"action": &"map", "label": "map"},
	{"action": &"journal", "label": "journal"},
	{"action": &"pause", "label": "pause, or back"},
]

static var _values: Dictionary = {}
static var _keys: Dictionary = {}
static var _loaded := false
## Set by whoever applies sound and window, so this file holds no engine calls of
## its own and a headless test can read every rule without a display.
static var on_sound := Callable()
static var on_window := Callable()
static var on_quality := Callable()


static func row(id: StringName) -> Dictionary:
	for r: Dictionary in ROWS:
		if r.id == id:
			return r
	return {}


static func default_of(id: StringName) -> Variant:
	if id == SCHEME:
		return ControlScheme.detect(mac(), mouse_seen)
	var by_scheme: Variant = ControlScheme.setting_default(scheme(), mac(), id)
	if by_scheme != null:
		return by_scheme
	return row(id).get("default", null)


## A mouse has shown itself this run (08_pointer: a wheel's notch, a middle or a
## side button, none of which a trackpad sends). Remembered only by what it
## changes: a Mac that was never told otherwise is moved onto the mouse, and
## that choice is kept, so the next run does not open on the trackpad again.
static var mouse_seen := false


static func saw_mouse() -> void:
	if mouse_seen:
		return
	mouse_seen = true
	if not _values.has(SCHEME) and value(SCHEME) != ControlScheme.MOUSE:
		set_value(SCHEME, ControlScheme.MOUSE)


static func scheme() -> StringName:
	return StringName(str(value(SCHEME)))


## Whether the map is laid out for a Mac. Only the player's own run asks the
## machine: a shot, a tour and a test all answer false, so what they prove and
## picture never depends on which laptop ran them.
static func mac() -> bool:
	return file == FILE and ControlScheme.on_mac()


## The scheme on the map, then the player's own keys over it. What the scheme
## put there is what every reset puts back (`_defaults`).
static func apply_scheme() -> void:
	ControlScheme.install(scheme(), mac())
	_defaults.clear()
	remember_defaults()
	for action: StringName in _keys:
		_apply_key(action, int(_keys[action]))


## A choice's values, in stepping order. A row either names them itself with
## `options` or says where they come from with `from`, so a list that is owned
## somewhere else — the graphics tiers, which five packages read — is never copied
## into this table and cannot drift from it.
static func options_of(r: Dictionary) -> Array:
	match StringName(str(r.get("from", &""))):
		&"quality":
			# `auto` is not a tier: it is "decide for me", and what it decides is
			# Quality.detect(). It leads because it is the honest default.
			var out: Array = [&"auto"]
			out.append_array(Quality.ids())
			return out
	return r.get("options", []) as Array


static func value(id: StringName) -> Variant:
	if not _loaded:
		load_once()
	return _values.get(id, default_of(id))


## True when a switch is on, or a choice is that word: the reader's own question,
## asked in one line (`PlayerSettings.is_set(&"playing.crouch", &"toggle")`).
static func is_set(id: StringName, want: Variant = true) -> bool:
	return value(id) == want


static func set_value(id: StringName, v: Variant) -> void:
	var r := row(id)
	if r.is_empty():
		return
	var clean: Variant = _clean(r, v)
	if _values.get(id, default_of(id)) == clean:
		return
	_values[id] = clean
	_apply_one(r)
	save()


## A value brought inside what its row allows, so a file somebody edited by hand
## can never put the game into a state its own page could not.
static func _clean(r: Dictionary, v: Variant) -> Variant:
	match StringName(str(r.kind)):
		LEVEL:
			return clampf(float(v), 0.0, 1.0)
		SWITCH:
			return bool(v)
		CHOICE:
			var options: Array = options_of(r)
			if options.has(v):
				return v
			# JSON has no StringName and one number kind: match by how it prints.
			for o: Variant in options:
				if str(o) == str(v):
					return o
			return r.get("default")
	return v


## One step along a choice, or a level moved by `by`: what a key press does to
## the row under the cursor.
static func step(id: StringName, by: int) -> void:
	var r := row(id)
	if r.is_empty():
		return
	match StringName(str(r.kind)):
		LEVEL:
			set_value(id, clampf(float(value(id)) + 0.1 * by, 0.0, 1.0))
		SWITCH:
			set_value(id, not bool(value(id)))
		CHOICE:
			var options: Array = options_of(r)
			var at: int = options.find(value(id))
			set_value(id, options[posmod(at + by, options.size())] if not options.is_empty() else value(id))


# --- keys --------------------------------------------------------------------

## The key an action is on: what the player bound, or what the game shipped with.
## Asked of the InputMap, so an action another package added (targeting's `z`, a
## craft's `b`) is named without anybody writing it down twice.
static func key_of(action: StringName) -> int:
	if not InputMap.has_action(action):
		return KEY_NONE
	for e: InputEvent in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k != null:
			return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	return KEY_NONE


## What a key is CALLED, for a line said to the player and for the cap the HUD
## draws. An Array is a cluster said as one word, so `[&"up", &"left", &"down",
## &"right"]` reads "WASD" while those are its keys and reads whatever they are
## rebound to after.
##
## **THIS IS HERE BECAUSE FOUR TEACHERS SPELLED THEIR OWN.** `Events.hint` takes
## a line and a key, and the key is drawn VERBATIM on a cap (`UiSlate.key_cap`).
## Two systems passed the ACTION name `"use"`, so the glass drew a cap reading
## USE where a key belongs, and three more spelled "b." and "E" into the sentence
## from a literal -- right until the player rebinds, after which the game tells
## them to press a key that does nothing. The guide already asked the live
## InputMap and was the only one that did; this is that answer, moved to where
## every teacher can reach it.
static func label_of(entry: Variant) -> String:
	if entry is Array:
		var out := ""
		for a: StringName in entry as Array:
			out += label_of(a)
		return out
	var code := key_of(entry as StringName)
	return "" if code == KEY_NONE else OS.get_keycode_string(code)


## The label as a cap wears it. Lowercase, because the cap letters it itself.
static func cap_of(entry: Variant) -> String:
	return label_of(entry).to_lower()


## Put the live keys into a line that asked for them. A line with no `%s` comes
## back untouched, which is how a lesson that names no key still says itself.
static func spell(line: String, keys: Array) -> String:
	if keys.is_empty() or not line.contains("%s"):
		return line
	var labels: Array = []
	for e: Variant in keys:
		labels.append(label_of(e))
	return line % labels


## Put `action` on `keycode`. Returns the action it was taken from, or &"" — a
## key may only do one thing, and the page says which one it took it off.
static func bind_key(action: StringName, keycode: int) -> StringName:
	var stolen := &""
	for r: Dictionary in BINDABLE:
		var other: StringName = r.action
		if other != action and key_of(other) == keycode:
			stolen = other
			_keys[other] = KEY_NONE
			_apply_key(other, KEY_NONE)
	_keys[action] = keycode
	_apply_key(action, keycode)
	save()
	return stolen


## ONE action back to the keys it shipped with, leaving every other rebind alone.
##
## Without this the only way to undo a rebind was `reset_keys`, which resets
## EVERYTHING and clears the whole table — so anyone who moved one key had a
## choice between putting the rest of the map back too and a `bind_key` to the
## old code, which is not a restore at all: `bind_key` sets an action to exactly
## ONE key, and ten of this game's actions ship with two. `tests/settings/test_taught_keys.gd`
## took that second option, wrote "put back, and nothing else touched" beside it,
## and left `use` on one key for every test that ran after it in the suite.
static func reset_key(action: StringName) -> void:
	if not _keys.has(action):
		return
	_restore(action)
	@warning_ignore("return_value_discarded")
	_keys.erase(action)
	save()


## Back to the keys the game shipped with, and nothing else touched. Several
## actions ship with two (dodge is shift AND k, carrying is tab AND i): all of
## them come back, not just the one the page was showing.
static func reset_keys() -> void:
	for action: StringName in _keys.keys():
		_restore(action)
	_keys.clear()
	save()


## Every key event each action had before anybody rebound anything, remembered
## the first time the map is seen: once an event is erased there is nowhere else
## to read it back from.
static var _defaults: Dictionary = {}


static func remember_defaults() -> void:
	for r: Dictionary in BINDABLE:
		var action: StringName = r.action
		if _defaults.has(action) or not InputMap.has_action(action):
			continue
		var kept: Array[InputEventKey] = []
		for e: InputEvent in InputMap.action_get_events(action):
			var k := e as InputEventKey
			if k != null:
				kept.append(k.duplicate() as InputEventKey)
		_defaults[action] = kept


static func _restore(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	_erase_keys(action)
	for e: InputEventKey in _defaults.get(action, [] as Array[InputEventKey]):
		InputMap.action_add_event(action, e.duplicate())


static func _erase_keys(action: StringName) -> void:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)


static func _apply_key(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	remember_defaults()
	_erase_keys(action)
	if keycode == KEY_NONE:
		return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


# --- the file ----------------------------------------------------------------

static func load_once() -> void:
	if _loaded:
		return
	_loaded = true
	_read_file()
	# The scheme first, then the player's keys over it: a key they moved wins,
	# and "put the keys back" goes to the scheme, not to project.godot.
	apply_scheme()


static func _read_file() -> void:
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return
	var d: Dictionary = json.data
	var values: Dictionary = d.get("values", {})
	for r: Dictionary in ROWS:
		if values.has(String(r.id)):
			_values[r.id] = _clean(r, values[String(r.id)])
	var keys: Dictionary = d.get("keys", {})
	for r: Dictionary in BINDABLE:
		var name := String(r.action)
		if keys.has(name):
			_keys[r.action] = int(keys[name])


static func save() -> void:
	var values := {}
	for id: StringName in _values:
		values[String(id)] = _values[id]
	var keys := {}
	for action: StringName in _keys:
		keys[String(action)] = int(_keys[action])
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": VERSION, "values": values, "keys": keys}, "\t"))
	f.close()


## Everything back to the game as it ships.
static func reset_all() -> void:
	_values.clear()
	reset_keys()
	apply_scheme()
	apply_all()
	save()


# --- applying ----------------------------------------------------------------

static func apply_all() -> void:
	if not _loaded:
		load_once()
	if on_sound.is_valid():
		on_sound.call()
	if on_window.is_valid():
		on_window.call()
	if on_quality.is_valid():
		on_quality.call()


static func _apply_one(r: Dictionary) -> void:
	match StringName(str(r.get("applies", &""))):
		&"sound":
			if on_sound.is_valid():
				on_sound.call()
		&"window":
			if on_window.is_valid():
				on_window.call()
		&"quality":
			if on_quality.is_valid():
				on_quality.call()
		&"controls":
			apply_scheme()


## Only for tests: forget what is in memory and read the runner's file again, so
## a test can prove that what it kept really comes back.
static func reread_for_test() -> void:
	_values.clear()
	_loaded = false
	load_once()


## Only for tests: forget everything read from disk and start clean, in the test
## runner's own file.
static func forget_for_test() -> void:
	use_file(&"test")
	# And the runner's file with it: a test that starts from what the last test
	# wrote is a test whose result depends on what ran before it.
	if FileAccess.file_exists(TEST_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	_values.clear()
	_keys.clear()
	_defaults.clear()
	_loaded = false
