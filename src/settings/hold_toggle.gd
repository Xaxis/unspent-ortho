class_name HoldToggle
## A key a player may press once instead of holding down (owner, 2026-09-17).
##
## Two of this game's keys are held rather than pressed — crouching, and the slate
## put on a machine — because what they do lasts exactly as long as the key is
## down. That is the right default and a poor requirement: holding a key for
## minutes is the commonest thing an accessibility setting is asked to undo.
##
##   HoldToggle.on(&"crouch", &"playing.crouch")
##
## In hold mode this is `Input.is_action_pressed` and nothing more. In toggle mode
## a press flips it and it stays where it was put. The latch is dropped whenever
## the game stops asking (`forget`), so a key left on cannot follow the player
## into the next game or out of a page.

static var _on: Dictionary = {}
static var _was: Dictionary = {}
## Action -> the process frame its latch last flipped in.
static var _flipped: Dictionary = {}


## Is this action "down" now, under the player's own rule for it?
static func on(action: StringName, setting: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	var now := Input.is_action_pressed(action)
	if not PlayerSettings.is_set(setting, &"toggle"):
		_on[action] = now
		_was[action] = now
		return now
	# A key struck and let go inside one frame is still a press: the browser
	# delivers taps that way, and a toggle that misses them is a toggle that
	# sometimes does nothing.
	# A press, or a tap made and let go inside one frame (a browser delivers taps
	# that way), but never a key that was ALREADY down last time this was asked:
	# that is how closing a page put the latch straight back on.
	var before := bool(_was.get(action, false))
	var went_down := (now or Input.is_action_just_pressed(action)) and not before
	_was[action] = now
	# One flip a frame, whoever asks: the engine reads a key pressed and released
	# inside a frame as just pressed for the whole of it, so asking twice in one
	# frame would turn it on and straight back off.
	var frame := Engine.get_process_frames()
	if went_down and int(_flipped.get(action, -1)) != frame:
		_flipped[action] = frame
		_on[action] = not bool(_on.get(action, false))
	return bool(_on.get(action, false))


## Let go of everything: a game ending, a page opening over the world, a body
## that was crouching being put somewhere else.
static func forget() -> void:
	_on.clear()
	_flipped.clear()
	# What is down right now is absorbed rather than forgotten, so a key still
	# held when everything was let go is not read as a fresh press.
	for action: StringName in _was.keys():
		_was[action] = InputMap.has_action(action) and Input.is_action_pressed(action)


## Put one latch back where its owner last saw it, after a `forget` it did not
## ask for. A page opening lets go of a crouch and a lock, which is right for
## both; a VIEW is not a stance, and one pressed on should still be on when the
## page closes (41_shoulder). The key held down right now is absorbed, as
## `forget` absorbs it, so putting a latch back is never read as a press.
static func put(action: StringName, on: bool) -> void:
	_on[action] = on
	_was[action] = InputMap.has_action(action) and Input.is_action_pressed(action)


## Whether anything is latched on, for a system that wants to know.
static func any_on() -> bool:
	for k: StringName in _on:
		if bool(_on[k]):
			return true
	return false
