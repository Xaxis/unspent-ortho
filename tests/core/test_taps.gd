extends TestCase
## 00_taps holds a tap shorter than a frame down for that frame, and never adds a
## press to one a frame already saw. Driven by hand, step by step, as the engine
## runs it: physics steps, then the frame's process.

const Taps := preload("res://src/systems/00_taps.gd")


func _taps() -> Node:
	var t: Node = Taps.new()
	var only: Array[StringName] = [&"inventory"]
	t.set("_actions", only)
	return t


## A tour's `tap` lets go inside a physics step, after 00_taps has polled that
## step: the press was held three frames, and the frame after the release pressed
## it again for one. june.tour's `tap inventory` opened the page and the phantom
## press shut it (batch 9 smoke, line 112).
func test_a_press_a_frame_saw_is_not_pressed_again_when_it_lets_go() -> void:
	var t := _taps()
	Input.action_press(&"inventory")
	t.call(&"_physics_process", 0.016)
	t.call(&"_process", 0.016)
	t.call(&"_physics_process", 0.016)
	Input.action_release(&"inventory")
	t.call(&"_process", 0.016)
	check(not Input.is_action_pressed(&"inventory"), "let go stays let go: no press the player never made")
	Input.action_release(&"inventory")
	t.free()


func test_a_tap_inside_one_frame_is_held_for_that_frame_and_let_go_at_the_next() -> void:
	var t := _taps()
	t.call(&"_process", 0.016)
	Input.action_press(&"inventory")
	t.call(&"_physics_process", 0.016)
	Input.action_release(&"inventory")
	t.call(&"_process", 0.016)
	check(Input.is_action_pressed(&"inventory"), "the tap is down for the frame it came and went in")
	t.call(&"_physics_process", 0.016)
	t.call(&"_process", 0.016)
	check(not Input.is_action_pressed(&"inventory"), "and let go at the next")
	Input.action_release(&"inventory")
	t.free()
