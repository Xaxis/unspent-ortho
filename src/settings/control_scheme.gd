class_name ControlScheme
## THE THREE WAYS TO HOLD THE GAME (owner, 2026-09-24; docs/CONTROLS.md): with a
## mouse, with a laptop's trackpad, or with the keyboard alone. A scheme is the
## WHOLE input map for every action the player plays with -- keys, mouse buttons,
## and what the scroll and a trackpad's gestures mean (08_pointer) -- plus how
## the held keys are held by default.
##
##   ControlScheme.install(scheme, mac)   put the scheme's events on every action
##   ControlScheme.detect(mac, mouse)     the first-run choice for this machine
##   ControlScheme.setting_default(...)   hold or toggle, as the scheme ships it
##
## The player's own rebinds sit ON TOP of it (`PlayerSettings`): installing a
## scheme is the "as it came" every reset goes back to, and a rebind replaces
## only the keyboard key of one action, as it always did.
##
## A click and a key say the SAME word (this was MouseControls' rule, and still
## is): the swing's button is an event on `swing`, so nothing in the fight learns
## there is a mouse, and no test over a blow had to change when it arrived.
##
## WHY `mac` IS AN ARGUMENT. On a Mac, Ctrl+click is a right click, and the right
## button is the peek over the shoulder, so crouching and swinging at once would
## turn the camera (C1). There the crouch is C and making moves to Y, avoiding
## Ctrl entirely (owner's ruling). The question is asked once, by whoever
## installs, so every rule here stays a function of its arguments.

const MOUSE := &"mouse"
const TRACKPAD := &"trackpad"
const KEYS := &"keys"
const ALL: Array[StringName] = [MOUSE, TRACKPAD, KEYS]

## A key, a left-hand-only key (the Alt the view answers, never AltGr), a mouse
## button: the three kinds of event a scheme writes.
static func _k(code: int) -> Dictionary:
	return {"key": code}


static func _left(code: int) -> Dictionary:
	return {"key": code, "left": true}


static func _b(button: int) -> Dictionary:
	return {"button": button}


## Every action a scheme owns and its events. An action NOT named here keeps
## whatever it has (dev mode's, the slate's own), so a scheme never reaches into
## a package it does not know.
static func events(scheme: StringName, mac: bool) -> Dictionary:
	var mouse := scheme == MOUSE
	var pad := scheme == TRACKPAD
	var keys := scheme == KEYS
	# Ctrl is the crouch only where a click cannot be turned into a right click by
	# holding it, and only where a hand is on a mouse to keep the left hand free.
	var ctrl_crouch := mouse and not mac
	var m := {
		&"move_up": [_k(KEY_W)],
		&"move_down": [_k(KEY_S)],
		&"move_left": [_k(KEY_A)],
		&"move_right": [_k(KEY_D)],
		# The arrows walk from above and turn the view over the shoulder (game.gd
		# asks for them as a walk whenever the view is not up).
		&"look_up": [_k(KEY_UP)],
		&"look_down": [_k(KEY_DOWN)],
		&"look_left": [_k(KEY_LEFT)],
		&"look_right": [_k(KEY_RIGHT)],
		&"run": [_k(KEY_SHIFT)],
		# Shift taps a dodge (DodgeInput); K dodges at once; the mouse's thumb
		# button dodges with the swing still under the index finger.
		&"dodge": [_k(KEY_SHIFT), _k(KEY_K)] + ([_b(MOUSE_BUTTON_XBUTTON1)] if mouse else []),
		&"swing": [_k(KEY_J)] + ([_b(MOUSE_BUTTON_LEFT)] if mouse or pad else []),
		&"jump": [_k(KEY_SPACE)],
		&"use": [_k(KEY_E), _k(KEY_ENTER)],
		# Never Q: that is the dash (C2).
		&"crouch": [_k(KEY_CTRL)] if ctrl_crouch else [_k(KEY_C)],
		# Z in every scheme (owner's ruling); the wheel's click beside it with a
		# mouse, and L under the fighting hand with none.
		&"target": [_k(KEY_Z)] + ([_b(MOUSE_BUTTON_MIDDLE)] if mouse else []) + ([_k(KEY_L)] if keys else []),
		&"target_next": [_k(KEY_O)],
		&"target_prev": [_k(KEY_U)],
		&"shoulder": [_left(KEY_ALT)],
		&"shoulder_peek": [_b(MOUSE_BUTTON_RIGHT)] if mouse else [],
		&"lamp": [_k(KEY_F)],
		&"ride": [_k(KEY_B)],
		&"drop": [_k(KEY_X)],
		# I sits over the fighting hand with no mouse: a slip would open the page
		# mid-fight, so Tab alone there.
		&"inventory": [_k(KEY_TAB)] + ([] if keys else [_k(KEY_I)]),
		&"craft": [_k(KEY_C)] if ctrl_crouch else [_k(KEY_Y)],
		&"map": [_k(KEY_M)],
		&"journal": [_k(KEY_N)],
		&"holding": [_k(KEY_H)],
		&"pause": [_k(KEY_ESCAPE)],
		&"zoom_in": [_k(KEY_EQUAL), _k(KEY_KP_ADD)],
		&"zoom_out": [_k(KEY_MINUS), _k(KEY_KP_SUBTRACT)],
		&"ability_dash": [_k(KEY_Q)],
		&"ability_scan": [_k(KEY_R)],
		&"ability_grapple": [_k(KEY_T)],
		&"ability_glide": [_k(KEY_G)],
		&"ability_spoof": [_k(KEY_V)],
	}
	return m


## How a scheme holds the keys that may be held or pressed, unless the player has
## said. The view over the shoulder is a press in all three (owner's ruling); the
## crouch is held only where Ctrl is the crouch and a pinky can rest on it.
static func setting_default(scheme: StringName, mac: bool, id: StringName) -> Variant:
	match id:
		&"playing.shoulder":
			return &"toggle"
		&"playing.crouch":
			return &"hold" if scheme == MOUSE and not mac else &"toggle"
		&"playing.target":
			return &"hold"
	return null


## The first-run choice: a Mac that has shown no mouse is a laptop on its own
## trackpad, and everything else has a mouse. Never the keyboard alone -- that is
## chosen, not guessed.
static func detect(mac: bool, mouse_seen: bool) -> StringName:
	return TRACKPAD if mac and not mouse_seen else MOUSE


## Whether this is a Mac, desktop or browser. A tool run or a test answers false
## on any machine (`PlayerSettings` asks), so a picture or a result never depends
## on which laptop took it.
static func on_mac() -> bool:
	if OS.get_name() == "macOS":
		return true
	if OS.has_feature("web") and ClassDB.class_exists(&"JavaScriptBridge"):
		var platform: Variant = Engine.get_singleton(&"JavaScriptBridge").call(&"eval", "navigator.platform || ''", true)
		return str(platform).to_lower().contains("mac")
	return false


## Put the scheme on the map. Every event of every action it names is replaced --
## keys and buttons alike -- and nothing else is touched. Idempotent: the map a
## second install leaves is the map the first left.
static func install(scheme: StringName, mac: bool) -> void:
	var map := events(scheme if ALL.has(scheme) else MOUSE, mac)
	for action: StringName in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for e: InputEvent in InputMap.action_get_events(action):
			if e is InputEventKey or e is InputEventMouseButton:
				InputMap.action_erase_event(action, e)
		for spec: Dictionary in map[action]:
			InputMap.action_add_event(action, _event(spec))


static func _event(spec: Dictionary) -> InputEvent:
	if spec.has("button"):
		var b := InputEventMouseButton.new()
		b.button_index = int(spec.button)
		return b
	var k := InputEventKey.new()
	k.physical_keycode = int(spec.key)
	if spec.get("left", false):
		k.location = KEY_LOCATION_LEFT
	return k
