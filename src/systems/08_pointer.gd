extends GameSystem
## THE SCROLL AND A TRACKPAD'S GESTURES (docs/CONTROLS.md). A wheel's notch, a
## two-finger scroll and a pinch are one question -- "further in or further
## out, or the next one along" -- and whoever holds the camera answers it:
##
##   a held lock          (42_target)   cycles the lock; the zoom is off
##   the view up          (41_shoulder) the eye in or out along the view
##   otherwise            (09_view)     the land's own zoom
##
## Each is offered the step in that order (`take_scroll`), and the first to take
## it has it, so this file knows none of them by name. The flyover reads the
## wheel itself and has the picture while it flies, so nothing is offered then.
##
## A two-finger scroll reaches Godot on a Mac as a PAN gesture, not a wheel (a
## browser still sends a wheel), and a pinch as MAGNIFY; a mouse's wheel is a
## button. That difference is also how a mouse shows itself on a machine that
## opened on the trackpad scheme (`PlayerSettings.saw_mouse`).

## Pixels of two-finger travel that make one notch of a wheel.
const PAN_STEP := 24.0
## How many notches a pinch is worth per unit of magnification.
const PINCH_STEPS := 6.0


func _input(event: InputEvent) -> void:
	if game == null or game.camera == null:
		return
	var steps := _steps(event)
	if steps == Vector2.ZERO:
		return
	if game.watch.is_finite() or game.input_blocked():
		return
	offer(steps)


## Hand `steps` to whichever system holds the camera, last-loaded first: a lock
## (42) outranks the view over the shoulder (41), which outranks the land (09).
func offer(steps: Vector2) -> bool:
	for i in range(game.systems.size() - 1, -1, -1):
		var s: Node = game.systems[i]
		if s != self and s.has_method(&"take_scroll") and bool(s.call(&"take_scroll", steps)):
			return true
	return false


## An event as notches: y is further OUT (and the next lock) positive, x across.
## Zero for anything that is not a scroll.
func _steps(event: InputEvent) -> Vector2:
	var mb := event as InputEventMouseButton
	if mb != null:
		if not mb.pressed:
			return Vector2.ZERO
		var f := mb.factor if mb.factor > 0.0 else 1.0
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_wheel_seen()
				return Vector2(0.0, -f)
			MOUSE_BUTTON_WHEEL_DOWN:
				_wheel_seen()
				return Vector2(0.0, f)
			MOUSE_BUTTON_WHEEL_LEFT:
				return Vector2(-f, 0.0)
			MOUSE_BUTTON_WHEEL_RIGHT:
				return Vector2(f, 0.0)
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2:
				PlayerSettings.saw_mouse()
		return Vector2.ZERO
	var pan := event as InputEventPanGesture
	if pan != null:
		return pan.delta / PAN_STEP
	var pinch := event as InputEventMagnifyGesture
	if pinch != null:
		# Fingers apart is closer in.
		return Vector2(0.0, -(pinch.factor - 1.0) * PINCH_STEPS)
	return Vector2.ZERO


## A wheel is a mouse on a desktop, where a trackpad scrolls by gesture instead.
## A browser sends a trackpad's scroll as a wheel too, so there it proves nothing
## and only a middle or a side button counts.
func _wheel_seen() -> void:
	if not OS.has_feature("web"):
		PlayerSettings.saw_mouse()
