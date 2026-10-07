class_name Keys
## A KEY IS DOWN WHILE IT IS HELD, OR FOR ONE FRAME AFTER A TAP TOO SHORT FOR A
## FRAME TO SEE (src/systems/00_taps.gd). Every system finds its own edge of a key
## by polling it once a frame, so read a game action through `down`, never through
## `Input.is_action_pressed`: a tap that came and went inside one slow frame is
## down here for that frame, and the engine never knew it.
##
##   Keys.down(&"use") -> bool
##
## 00_taps never writes the engine's input state. When it held a tap down with
## Input.action_press, a press anything else made through code on that same key
## during the hold (a tour's `tap`, a test) was let go with it: test_journal's key
## closed nothing, 1 run in 8 on CI (tests/core/test_taps.gd).

## Actions tapped since the frame before last (00_taps `_process`): down for this
## frame's systems and the next frame's physics steps, then up.
static var tapped: Dictionary = {}


static func down(action: StringName) -> bool:
	return Input.is_action_pressed(action) or tapped.has(action)


## Nothing tapped: a new game, or a test, starts with every key up.
static func forget() -> void:
	tapped.clear()
