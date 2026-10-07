extends GameSystem
## A TAP SHORTER THAN A FRAME IS STILL A PRESS. Every system finds its own edge
## of a key by polling it once a frame (20_realms says why not
## `is_action_just_pressed`), so a key that went down and came up again inside one
## drawn frame was seen by none of them. A slow frame runs several physics steps
## before it draws: at 2 fps on a loaded box, a press of `use` held for three of
## them was lost whole, and beside June it spoke to nobody
## (tests/story/test_era_gates.gd, 4 of 4 there and green on a quiet runner). A
## player's quick tap is the same thing whenever a frame takes longer than the
## tap.
##
## So a key that went down since the last frame (a press event, or seen down at a
## physics step while that frame had it up) and is up again by this one is put in
## `Keys.tapped`: down to `Keys.down` for this frame's systems and the next frame's
## physics steps, then up. Numbered first, so every system's own edge finds it in
## that same frame. A key the last frame already saw down is a press the systems
## have had: a press let go inside a physics step after this polled it (a tour's
## `tap`) is no tap.
##
## THE ENGINE'S INPUT STATE IS NEVER WRITTEN HERE (src/settings/keys.gd says why).

## The game's own actions; the engine's `ui_` ones are the menus' business.
var _actions: Array[StringName] = []
## Actions that went down since the last frame.
var _seen: Dictionary = {}
## Actions down (to Keys.down) when the last frame's systems looked.
var _down: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	Keys.forget()
	for a: StringName in InputMap.get_actions():
		if not String(a).begins_with("ui_"):
			_actions.append(a)


func _exit_tree() -> void:
	Keys.forget()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	for a: StringName in _actions:
		if event.is_action_pressed(a):
			_seen[a] = true


func _physics_process(_delta: float) -> void:
	for a: StringName in _actions:
		if not _down.has(a) and Input.is_action_pressed(a):
			_seen[a] = true


func _process(_delta: float) -> void:
	Keys.tapped.clear()
	for a: StringName in _seen:
		if not Input.is_action_pressed(a):
			Keys.tapped[a] = true
	_seen.clear()
	_down.clear()
	for a: StringName in _actions:
		if Keys.down(a):
			_down[a] = true
