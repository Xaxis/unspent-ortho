extends TestCase
## A direction on an app moves the list on the frame it goes down, whether or not
## it is still held when the slate reads the keys: a tap struck and let go between
## two frames (a browser's key event, a quick finger, a slow frame) is not lost.
## A key already down as the app opens (the walk that was going on) is not a press
## on it, and a held key repeats only after the menu standard's delay.

var _game: Game


func _make() -> Node:
	_game = Game.new()
	tree.root.add_child(_game)
	_game.setup(BootOptions.parse(["--size=48", "--seed=4"]))
	for s in _game.systems:
		if s.name == "90_ui":
			return s
	return null


func _done() -> void:
	for a: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(a)
	tree.paused = false
	_game.free()


func test_a_tap_between_two_frames_moves_the_list() -> void:
	var ui := _make()
	check(bool(ui.call("open_screen", &"pause")))
	var home: UiScreen = ui.call("top")
	# The frame the app opened on reads no press.
	await tree.process_frame
	await tree.process_frame
	var from := home.menu.index
	# Down and up before the slate reads the keys: nothing is held when it looks.
	Input.action_press(&"move_down")
	Input.action_release(&"move_down")
	await tree.process_frame
	await tree.process_frame
	eq(home.menu.index, from + 1, "the tap moved the list though nothing was held when it was read")
	for i in 4:
		await tree.process_frame
	eq(home.menu.index, from + 1, "and once only")
	_done()


func test_a_key_held_as_the_app_opens_does_not_move_it_and_a_held_key_repeats_late() -> void:
	var ui := _make()
	Input.action_press(&"move_down")
	for i in 3:
		await tree.process_frame
	check(bool(ui.call("open_screen", &"pause")))
	var home: UiScreen = ui.call("top")
	var from := home.menu.index
	for i in 4:
		await tree.process_frame
	eq(home.menu.index, from, "the walk that was going on is not a press on home")
	Input.action_release(&"move_down")
	for i in 2:
		await tree.process_frame
	Input.action_press(&"move_down")
	for i in 2:
		await tree.process_frame
	eq(home.menu.index, from + 1, "a fresh press moves it once")
	var until := Time.get_ticks_msec() + int(3000 * TestCase.machine_slack())
	while home.menu.index == from + 1 and Time.get_ticks_msec() < until:
		await tree.process_frame
	check(home.menu.index != from + 1, "held past the delay, it repeats")
	_done()
