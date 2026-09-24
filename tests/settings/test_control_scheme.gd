extends TestCase
## The three ways to hold the game (`ControlScheme`, docs/CONTROLS.md). Each rule
## is one the old map broke without anybody choosing it: Q both crouched and
## dashed (C2), Ctrl+click on a Mac is a right click and the right button is the
## view (C1), and dev mode's letters were three abilities' keys (C4).

## Shift runs and taps a dodge; the arrows walk, and turn the view over the
## shoulder, where game.gd walks only on the move keys that are not look keys.
const PAIRS_ON_PURPOSE := [[&"run", &"dodge"], [&"move_up", &"look_up"], [&"move_down", &"look_down"],
	[&"move_left", &"look_left"], [&"move_right", &"look_right"]]


func _after() -> void:
	PlayerSettings.forget_for_test()
	PlayerSettings.load_once()


func _codes(events: Array) -> Array:
	var out: Array = []
	for spec: Dictionary in events:
		if spec.has("key"):
			out.append(int(spec.key))
	return out


func _buttons(events: Array) -> Array:
	var out: Array = []
	for spec: Dictionary in events:
		if spec.has("button"):
			out.append(int(spec.button))
	return out


func _on_purpose(a: StringName, b: StringName) -> bool:
	for p: Array in PAIRS_ON_PURPOSE:
		if (p[0] == a and p[1] == b) or (p[0] == b and p[1] == a):
			return true
	return false


func test_no_key_or_button_does_two_things_in_any_scheme() -> void:
	for mac: bool in [false, true]:
		for scheme: StringName in ControlScheme.ALL:
			var map := ControlScheme.events(scheme, mac)
			var by_key := {}
			var by_button := {}
			for action: StringName in map:
				for code: int in _codes(map[action]):
					if by_key.has(code) and not _on_purpose(by_key[code], action):
						fail("%s%s: %s is both %s and %s" % [scheme, " (mac)" if mac else "",
							OS.get_keycode_string(code), by_key[code], action])
					by_key[code] = action
				for b: int in _buttons(map[action]):
					check(not by_button.has(b), "%s: button %d is both %s and %s" % [scheme, b, by_button.get(b, &""), action])
					by_button[b] = action


func test_on_a_mac_nothing_is_on_ctrl() -> void:
	# Ctrl+click is a right click there, and the right button is the peek: a
	# crouched swing would turn the camera.
	for scheme: StringName in ControlScheme.ALL:
		var map := ControlScheme.events(scheme, true)
		for action: StringName in map:
			check(not _codes(map[action]).has(KEY_CTRL), "%s on a Mac: %s is on Ctrl" % [scheme, action])
	eq(_codes(ControlScheme.events(ControlScheme.MOUSE, true)[&"crouch"]), [KEY_C], "the Mac crouches on C")
	eq(_codes(ControlScheme.events(ControlScheme.MOUSE, true)[&"craft"]), [KEY_Y], "and makes on Y")
	eq(_codes(ControlScheme.events(ControlScheme.MOUSE, false)[&"crouch"]), [KEY_CTRL], "a PC mouse keeps Ctrl")


func test_a_click_says_the_same_word_as_a_key() -> void:
	for scheme: StringName in [ControlScheme.MOUSE, ControlScheme.TRACKPAD]:
		var swing: Array = ControlScheme.events(scheme, false)[&"swing"]
		check(_codes(swing).has(KEY_J) and _buttons(swing).has(MOUSE_BUTTON_LEFT),
			"%s: the swing is J and a click, one action" % scheme)
	var mouse := ControlScheme.events(ControlScheme.MOUSE, false)
	check(_buttons(mouse[&"shoulder_peek"]).has(MOUSE_BUTTON_RIGHT), "the right button peeks")
	check(_buttons(mouse[&"target"]).has(MOUSE_BUTTON_MIDDLE), "the wheel's click locks")
	check(_buttons(mouse[&"dodge"]).has(MOUSE_BUTTON_XBUTTON1), "the thumb dodges")
	# A trackpad has no right-drag, no middle, no thumb.
	var pad := ControlScheme.events(ControlScheme.TRACKPAD, false)
	for action: StringName in pad:
		for b: int in _buttons(pad[action]):
			eq(b, MOUSE_BUTTON_LEFT, "the trackpad scheme asks only for a click (%s)" % action)


func test_z_locks_in_every_scheme_and_l_too_with_no_mouse() -> void:
	for scheme: StringName in ControlScheme.ALL:
		check(_codes(ControlScheme.events(scheme, false)[&"target"]).has(KEY_Z), "%s: Z locks" % scheme)
	check(_codes(ControlScheme.events(ControlScheme.KEYS, false)[&"target"]).has(KEY_L), "keyboard alone: L as well")
	check(not _codes(ControlScheme.events(ControlScheme.KEYS, false)[&"inventory"]).has(KEY_I),
		"keyboard alone: I is over the fighting hand, so not carrying")


func test_the_cycle_is_never_on_a_move_key() -> void:
	for scheme: StringName in ControlScheme.ALL:
		var map := ControlScheme.events(scheme, false)
		var moves: Array = []
		for a: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
			moves.append_array(_codes(map[a]))
		for a: StringName in [&"target_next", &"target_prev"]:
			for code: int in _codes(map[a]):
				check(not moves.has(code), "%s: %s is a move key" % [scheme, a])


func test_hold_and_press_as_each_scheme_ships_them() -> void:
	for scheme: StringName in ControlScheme.ALL:
		for mac: bool in [false, true]:
			eq(ControlScheme.setting_default(scheme, mac, &"playing.shoulder"), &"toggle",
				"%s: the view is a press" % scheme)
			eq(ControlScheme.setting_default(scheme, mac, &"playing.target"), &"hold", "%s: the lock is held" % scheme)
	eq(ControlScheme.setting_default(ControlScheme.MOUSE, false, &"playing.crouch"), &"hold", "Ctrl is held")
	eq(ControlScheme.setting_default(ControlScheme.MOUSE, true, &"playing.crouch"), &"toggle", "C is pressed")
	eq(ControlScheme.setting_default(ControlScheme.KEYS, false, &"playing.crouch"), &"toggle")


func test_the_first_run_choice() -> void:
	eq(ControlScheme.detect(true, false), ControlScheme.TRACKPAD, "a Mac with no mouse seen is on its trackpad")
	eq(ControlScheme.detect(true, true), ControlScheme.MOUSE, "a Mac that showed a mouse has one")
	eq(ControlScheme.detect(false, false), ControlScheme.MOUSE, "anything else has a mouse")


func test_installing_twice_adds_nothing_twice() -> void:
	for scheme: StringName in ControlScheme.ALL:
		ControlScheme.install(scheme, false)
		var before := {}
		for action: StringName in ControlScheme.events(scheme, false):
			before[action] = InputMap.action_get_events(action).size()
		ControlScheme.install(scheme, false)
		for action: StringName in before:
			eq(InputMap.action_get_events(action).size(), int(before[action]), "%s: %s" % [scheme, action])
	_after()


func test_switching_scheme_moves_the_keys_and_reset_goes_to_the_scheme() -> void:
	PlayerSettings.forget_for_test()
	PlayerSettings.load_once()
	PlayerSettings.set_value(PlayerSettings.SCHEME, ControlScheme.KEYS)
	eq(PlayerSettings.key_of(&"craft"), KEY_Y, "keyboard alone makes on Y")
	check(not _mouse_on(&"swing"), "and the swing answers no click")
	@warning_ignore("return_value_discarded")
	PlayerSettings.bind_key(&"craft", KEY_P)
	eq(PlayerSettings.key_of(&"craft"), KEY_P, "a key the player moved")
	PlayerSettings.set_value(PlayerSettings.SCHEME, ControlScheme.MOUSE)
	eq(PlayerSettings.key_of(&"craft"), KEY_P, "stays where they put it when the scheme changes")
	check(_mouse_on(&"swing"), "while the scheme's click comes back")
	PlayerSettings.reset_key(&"craft")
	eq(PlayerSettings.key_of(&"craft"), KEY_C, "and put back, it goes to the SCHEME's key")
	_after()


func _mouse_on(action: StringName) -> bool:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventMouseButton:
			return true
	return false


func test_dev_keys_never_land_on_a_players_key() -> void:
	# The dev letters were chosen as ones "the game does not already own", and the
	# abilities then took R, V and G (C4).
	for scheme: StringName in ControlScheme.ALL:
		for mac: bool in [false, true]:
			var map := ControlScheme.events(scheme, mac)
			var taken := {}
			for action: StringName in map:
				for code: int in _codes(map[action]):
					taken[code] = action
			for dev: StringName in DevMode.ACTIONS:
				if dev in [&"dev_fly_in", &"dev_fly_out"]:
					continue  # read only while flying, when the flyover owns the zoom
				for code: int in DevMode.ACTIONS[dev]:
					check(not taken.has(code), "%s: %s is on %s, which is %s" % [scheme, dev,
						OS.get_keycode_string(code), taken.get(code, &"")])
