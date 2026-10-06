extends GameSystem
## A TAP SHORTER THAN A FRAME IS STILL A PRESS. Every system finds its own edge
## of a key by polling `Input.is_action_pressed` once a frame (20_realms says why
## not `is_action_just_pressed`), so a key that went down and came up again
## inside one drawn frame was seen by none of them. A slow frame runs several
## physics steps before it draws: at 2 fps on a loaded box, a press of `use`
## held for three of them was lost whole, and beside June it spoke to nobody
## (tests/story/test_era_gates.gd, 4 of 4 here and green on a quiet runner). A
## player's quick tap is the same thing whenever a frame takes longer than the
## tap.
##
## So a key that went down since the last frame (a press event, or seen down at
## a physics step while that frame had it up) and is up again by this one, is
## held down for this one frame and let go at the next. Numbered first, so every
## system's own edge finds it in that same frame. A key still down is never
## touched, and neither is one the last frame already saw down: a press let go
## inside a physics step, after this polled it (a tour's `tap`), was pressed again
## for a frame, and june.tour's `tap inventory` opened the page and shut it
## (tests/core/test_taps.gd).

## The game's own actions; the engine's `ui_` ones are the menus' business.
var _actions: Array[StringName] = []
## Actions seen down since the last frame.
var _seen: Dictionary = {}
## Actions this system holds down for this frame, to let go at the next.
var _holding: Dictionary = {}
## Actions down when the last frame's systems looked: a press they have seen.
var _down: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	for a: StringName in InputMap.get_actions():
		if not String(a).begins_with("ui_"):
			_actions.append(a)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	for a: StringName in _actions:
		if event.is_action_pressed(a):
			_seen[a] = true


func _physics_process(_delta: float) -> void:
	for a: StringName in _actions:
		# What this system holds down is its own press, not one seen; and a key the
		# last frame saw down is a press it has had.
		if not _holding.has(a) and not _down.has(a) and Input.is_action_pressed(a):
			_seen[a] = true


func _process(_delta: float) -> void:
	for a: StringName in _holding:
		# Let go, unless the key was pressed again while it was held.
		if not _seen.has(a):
			Input.action_release(a)
	_holding.clear()
	for a: StringName in _seen:
		if not Input.is_action_pressed(a):
			Input.action_press(a)
			_holding[a] = true
	_seen.clear()
	_down.clear()
	for a: StringName in _actions:
		if Input.is_action_pressed(a):
			_down[a] = true
