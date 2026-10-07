extends TestCase
## 00_taps makes a tap shorter than a frame down to `Keys.down` for that frame,
## never adds a press to one a frame already saw, and never writes the engine's
## input state. Driven by hand, step by step, as the engine runs it: physics
## steps, then the frame's process.

const Taps := preload("res://src/systems/00_taps.gd")
const A := &"inventory"


func _taps() -> Node:
	Keys.forget()
	Input.action_release(A)
	var t: Node = Taps.new()
	var only: Array[StringName] = [A]
	t.set("_actions", only)
	return t


func _done(t: Node) -> void:
	_hand(t, false)
	Input.action_release(A)
	Keys.forget()
	t.free()


func _frame(t: Node) -> void:
	t.call(&"_physics_process", 0.016)
	t.call(&"_process", 0.016)


func test_a_tap_inside_one_frame_is_down_for_that_frame_and_up_at_the_next() -> void:
	var t := _taps()
	_frame(t)
	Input.action_press(A)
	t.call(&"_physics_process", 0.016)
	Input.action_release(A)
	t.call(&"_process", 0.016)
	check(Keys.down(A), "the tap is down for the frame it came and went in")
	t.call(&"_physics_process", 0.016)
	check(Keys.down(A), "and for the next frame's physics steps")
	t.call(&"_process", 0.016)
	check(not Keys.down(A), "and up at the next frame")
	_done(t)


## A tour's `tap` lets go inside a physics step, after 00_taps has polled that
## step: the press was held three frames, and the frame after the release had it
## down again for one. june.tour's `tap inventory` opened the page and shut it.
func test_a_press_a_frame_saw_is_no_tap_when_it_lets_go() -> void:
	var t := _taps()
	Input.action_press(A)
	_frame(t)
	t.call(&"_physics_process", 0.016)
	Input.action_release(A)
	t.call(&"_process", 0.016)
	check(not Keys.down(A), "let go stays let go: no press the player never made")
	_done(t)


## A tap is down to Keys, and nowhere else: the engine's own state is the hand's.
func test_a_tap_never_writes_the_engines_input() -> void:
	var t := _taps()
	_frame(t)
	Input.action_press(A)
	t.call(&"_physics_process", 0.016)
	Input.action_release(A)
	t.call(&"_process", 0.016)
	check(Keys.down(A), "the tap is down to Keys")
	check(not Input.is_action_pressed(A), "and up to the engine, as the hand left it")
	_done(t)


## When a tap was held down with Input.action_press, a press made on the same key
## during the hold (a tour, a test) was let go with it at the next frame:
## test_journal's key closed nothing, 1 run in 8 on CI.
func test_a_press_made_during_a_tap_is_not_let_go_with_it() -> void:
	var t := _taps()
	_frame(t)
	Input.action_press(A)
	t.call(&"_physics_process", 0.016)
	Input.action_release(A)
	t.call(&"_process", 0.016)
	Input.action_press(A)
	_frame(t)
	_frame(t)
	check(Keys.down(A), "the press made during the tap is still down two frames on")
	check(Input.is_action_pressed(A), "to the engine as well")
	_done(t)


## And a real press during the tap, let go by the hand, leaves nothing down: a
## quick double tap of a move key must not walk him on alone. (The old hold kept
## its own press down here, but the engine let it go with the hand's key: this
## held on both, and guards it.)
func test_nothing_stays_down_once_the_hand_lets_go() -> void:
	var t := _taps()
	_frame(t)
	_hand(t, true)
	t.call(&"_physics_process", 0.016)
	_hand(t, false)
	t.call(&"_process", 0.016)
	_hand(t, true)
	_frame(t)
	_hand(t, false)
	_frame(t)
	_frame(t)
	check(not Keys.down(A), "let go, the key is up")
	check(not Input.is_action_pressed(A), "to the engine too")
	_done(t)


## The hand on the key: the action's own keyboard key, its event handed to the
## engine and to 00_taps (which is not in a tree here, so gets no event itself).
func _hand(t: Node, down: bool) -> void:
	var ev: InputEvent = null
	for e: InputEvent in InputMap.action_get_events(A):
		if e is InputEventKey:
			ev = e.duplicate()
			break
	check(ev != null, "the key has a keyboard key to press")
	(ev as InputEventKey).pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	t.call(&"_input", ev)
