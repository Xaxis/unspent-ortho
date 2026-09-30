class_name TourHands
extends RefCounted
## A reader's presses, made with the keys (98_tour `drive`, tests/fight/game_driver.gd):
## `press(verb)` asks, and `step()`, once a physics frame, holds and lets go of the
## real actions the fight reads (40_fight `_read_input`): a swing is a tap of
## `swing` (thrown on the key coming up), a heavy blow is `swing` held past
## FightRules.HEAVY_HOLD_MS, a dodge a tap of `dodge`. Nothing is pressed into
## the simulation directly. The target key is GameDriver's to hold (`locked`).

var _down := {}
## Actions just let go: kept up for a frame, so the fight sees the key come up
## (a swing is thrown on the key coming up; pressed again at once it is a hold).
var _up := {}


func press(verb: StringName) -> void:
	match verb:
		&"swing": _hold(&"swing", 1)
		&"dodge": _hold(&"dodge", 1)
		&"heavy": _hold(&"swing", ceili(FightRules.HEAVY_HOLD_MS / (1000.0 / 60.0)) + 2)


func _hold(action: StringName, frames: int) -> void:
	if _down.has(action) or _up.has(action):
		return
	Input.action_press(action)
	_down[action] = frames


## Once a physics frame: lets go of what has been held its frames.
func step() -> void:
	_up.clear()
	for action: StringName in _down.keys():
		_down[action] = int(_down[action]) - 1
		if int(_down[action]) < 0:
			Input.action_release(action)
			_down.erase(action)
			_up[action] = true


func release_all() -> void:
	for action: StringName in _down.keys():
		Input.action_release(action)
	_down.clear()
