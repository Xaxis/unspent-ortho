extends TestCase
## The scroll and a trackpad's gestures (08_pointer, docs/CONTROLS.md): one
## question -- in, out, or the next one along -- answered by whoever holds the
## camera. A held lock cycles and the zoom is off; the view over the shoulder
## moves its eye; otherwise the land zooms. And a wheel, a two-finger scroll and
## a pinch are all read as that question.

const DT := 1.0 / 60.0
var _game: Game


func _make(extra: PackedStringArray = []) -> Game:
	await tree.process_frame
	var args := PackedStringArray(["--size=64", "--seed=4", "--hour=11", "--weather=clear:0"])
	args.append_array(extra)
	_game = Game.new()
	tree.root.add_child(_game)
	_game.setup(BootOptions.parse(args))
	return _game


func _sys(n: String) -> Node:
	for s in _game.systems:
		if s.name == n:
			return s
	return null


func _done() -> void:
	_game.free()


func test_the_land_zooms_when_nothing_holds_the_camera() -> void:
	await _make()
	var h := _game.camera.view_height
	check(bool(_sys("08_pointer").call("offer", Vector2(0.0, 2.0))), "somebody took it")
	gt(_game.camera.view_height, h + 0.01, "two notches out: the land stands further back")
	_done()


func test_a_held_lock_takes_the_scroll_and_the_land_does_not_move() -> void:
	await _make(PackedStringArray(["--spawn=runner,cutter", "--target"]))
	var target := _sys("42_target")
	target.call("_process", 0.1)
	var first: TargetSubject = target.get("locked")
	var h := _game.camera.view_height
	_sys("08_pointer").call("offer", Vector2(0.0, 1.0))
	target.call("_process", 0.1)
	var second: TargetSubject = target.get("locked")
	check(second != null and first != null and second.id != first.id, "the notch cycled the lock")
	eq(_game.camera.view_height, h, "and the zoom did not move")
	_done()


func test_over_the_shoulder_the_scroll_moves_the_eye() -> void:
	await _make(PackedStringArray(["--view=shoulder"]))
	var back := _game.camera.shoulder_back
	var h := _game.camera.view_height
	_sys("08_pointer").call("offer", Vector2(0.0, 2.0))
	gt(_game.camera.shoulder_back, back, "the eye stands further back")
	eq(_game.camera.view_height, h, "and the land's own zoom is left alone")
	_done()


func test_a_wheel_a_pan_and_a_pinch_are_all_notches() -> void:
	await _make()
	var p := _sys("08_pointer")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	eq(p.call("_steps", wheel), Vector2(0.0, 1.0), "a notch down is one step out")
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(0.0, 48.0)
	eq(p.call("_steps", pan), Vector2(0.0, 2.0), "two fingers down two notches' worth")
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.5
	lt((p.call("_steps", pinch) as Vector2).y, 0.0, "fingers apart comes in")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	eq(p.call("_steps", click), Vector2.ZERO, "a click is not a scroll")
	_done()
