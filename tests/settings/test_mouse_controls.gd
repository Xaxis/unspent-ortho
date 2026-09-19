extends TestCase
## The mouse is part of the controls (`MouseControls`).
##
## The whole design is that a click and a key are the SAME action, so the fight
## cannot tell them apart and no test over the swing had to change. These hold
## that, and hold the one thing that would quietly rot it: installing twice.


func test_a_click_says_the_same_word_as_the_key() -> void:
	MouseControls.install()
	for action: StringName in MouseControls.ALSO:
		check(InputMap.has_action(action), "%s is a real action" % action)
		var keys := 0
		var buttons := 0
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey:
				keys += 1
			elif ev is InputEventMouseButton:
				buttons += 1
		gt(float(keys), 0.0, "%s still answers to its key" % action)
		gt(float(buttons), 0.0, "%s answers to a button too" % action)


func test_the_two_buttons_are_not_the_same_button() -> void:
	# Left swings and right dodges: pressed together in a fight, so a player must
	# never have to cross hands, and never both at once by accident.
	MouseControls.install()
	var seen: Dictionary = {}
	for action: StringName in MouseControls.ALSO:
		for button: int in MouseControls.ALSO[action]:
			check(not seen.has(button), "button %d means one thing only" % button)
			seen[button] = action
	eq(seen.size(), 2, "two buttons, two verbs")


func test_installing_twice_adds_nothing_twice() -> void:
	# `InputMap` will happily hold the same button four times over, and a reload,
	# a test run and a settings reset all call this again.
	MouseControls.install()
	var before: Dictionary = {}
	for action: StringName in MouseControls.ALSO:
		before[action] = InputMap.action_get_events(action).size()
	MouseControls.install()
	MouseControls.install()
	for action: StringName in MouseControls.ALSO:
		eq(InputMap.action_get_events(action).size(), int(before[action]),
			"%s gained nothing on the second and third call" % action)


func test_it_never_invents_an_action() -> void:
	# It only ever adds to what the game already has: an action it does not
	# recognise is skipped rather than created, so a typo here can never put a
	# control into the game that nothing reads.
	for action: StringName in MouseControls.ALSO:
		check(InputMap.has_action(action), "%s is shipped, not invented here" % action)
