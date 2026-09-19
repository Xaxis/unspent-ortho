class_name MouseControls
## THE MOUSE IS PART OF THE CONTROLS, not an accessory (owner, 2026-09-18:
## "fundamentally for both dev mode flying over and for controlling the player,
## why didnt you integrate the mouse as a fundamental control").
##
## He was right and the answer was not a design decision: there was not one
## `InputEventMouse` anywhere in `src/` before today. The keyboard actions were
## built first and nobody went back.
##
## WHAT THIS DOES AND WHY IT IS THE SMALLEST THING THAT COULD: it adds mouse
## buttons as EXTRA EVENTS on actions the game already has. Nothing in the fight
## learns about a mouse — `FightSim`, the swing's windows, the dodge's rules and
## every test over them go on reading `swing` and `dodge` exactly as before, and
## what changed is only that two more buttons say those words. A click cannot
## behave differently from the key, because there is no second path for it to
## behave differently in.
##
## Registered at RUNTIME rather than written into `project.godot`, for two
## reasons. The settings page reads the LIVE `InputMap` (`PlayerSettings.key_of`),
## so a mouse binding shows up there like any other; and `project.godot`'s action
## lines are a single serialised blob per action, which is a bad thing to edit by
## hand in a repository three sessions share.
##
## WHAT IS DELIBERATELY NOT HERE. Free aim — the body facing the pointer — and
## picking a target by pointing at it are both worth having and both change the
## fight rather than the input map: free aim gives `Hero.facing` a second writer,
## and hover-targeting changes what `Targeting` considers. They are a combat pass
## of their own, and the owner has said to come back and perfect it.

## Action id -> mouse buttons that also mean it.
##
## Left is the swing because it is the verb the hand expects, and right is the
## dodge because the two are pressed together and a player should never have to
## cross hands to answer a blow.
const ALSO := {
	&"swing": [MOUSE_BUTTON_LEFT],
	&"dodge": [MOUSE_BUTTON_RIGHT],
}


## Put them on. Idempotent, so a second call (a reload, a test) adds nothing
## twice — `InputMap` would happily hold the same button four times over.
static func install() -> void:
	for action: StringName in ALSO:
		if not InputMap.has_action(action):
			continue
		for button: int in ALSO[action]:
			if _has(action, button):
				continue
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


## Whether that action already answers to that button.
static func _has(action: StringName, button: int) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == button:
			return true
	return false
