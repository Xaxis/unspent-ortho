extends GameSystem
## The player's own zoom (owner, 2026-09-19: "it shouldnt have to be dev mode,
## just in normal play a user can press + or - to zoom in and out").
##
## `+` and `-` were dev mode's, read only by the flyover, so a player who cannot
## open dev mode could not change the view at all. They are ordinary actions now
## — in the InputMap, on the keys page, rebindable like every other — and this
## system is the only thing in a normal game that writes
## `CameraRig.view_height`.
##
## **THE RANGE IS A READABILITY DECISION, NOT A TECHNICAL ONE.** Streaming stopped
## being the limit when the coarse world landed (`world_far.gd`): the camera can
## now be pulled back to the whole island without building anything. What still
## binds is the fight. `CLOSE` is as near as the frame can come before a machine
## walking in from off-screen arrives with no warning, and `FAR` is as far as a
## body can go before it is a token rather than a person — measured against the
## play height of 15, which stays the default and the middle of the feel.
##
## It is a PLAYER SETTING, so it survives the session and can be set on the
## settings page as well as by the keys; `picture.zoom` is 0..1 across the range
## rather than a height in world units, because a level is what the page's own
## widget draws and a unit would leak the camera's numbers onto it.
##
## The flyover keeps the same two keys on purpose — one pair of keys for one
## idea — and this stands down entirely while it is up, or a single press would
## be spent twice on the same camera.

## The nearest and furthest the play camera may sit, as view height in world
## units. `CameraRig.VIEW_HEIGHT` (15) is inside them and is still the default.
const CLOSE := 9.0
const FAR := 34.0
## Factors per second while a key is held, so a press is a nudge and a hold is a
## sweep, and the two are the same gesture at different lengths.
const RATE := 1.55
## Under this the keys are doing nothing and the setting is not worth writing.
const SETTLE := 0.0005

var _level := 0.0
var _saved := 0.0
var _save_in := 0.0


static func level_of(height: float) -> float:
	return clampf(inverse_lerp(CLOSE, FAR, height), 0.0, 1.0)


static func height_of(level: float) -> float:
	return lerpf(CLOSE, FAR, clampf(level, 0.0, 1.0))


func setup(g: Game) -> void:
	super.setup(g)
	# A shot or a tour that was given `--zoom=` is staging a picture and this
	# must not take it back; anything else opens where the player left it.
	if g.options.zoom > 0.0:
		_level = level_of(g.camera.view_height)
	else:
		_level = float(PlayerSettings.value(&"picture.zoom"))
		g.camera.view_height = height_of(_level)
	_saved = _level


func _process(delta: float) -> void:
	if game == null or game.camera == null:
		return
	# Anything that has taken the camera has taken these keys with it. Asked as a
	# CAPABILITY and not by name, the way 42_target gathers `target_rows`: this
	# file should not know that a flyover exists, and the next thing that drives
	# the camera gets the same stand-down for free by answering the same method.
	for s in game.systems:
		if s.has_method(&"owns_zoom") and bool(s.call(&"owns_zoom")):
			return
	if game.input_blocked():
		return
	var way := 0.0
	if Input.is_action_pressed(&"zoom_in"):
		way -= 1.0
	if Input.is_action_pressed(&"zoom_out"):
		way += 1.0
	if way != 0.0:
		var by := pow(RATE, way * delta)
		_level = level_of(height_of(_level) * by)
		game.camera.view_height = height_of(_level)
	# Written once the hand comes off the key, not on every frame of the sweep:
	# a setting file is not a place to put sixty writes a second.
	if absf(_level - _saved) > SETTLE:
		_save_in = 0.6 if way != 0.0 else maxf(0.0, _save_in - delta)
		if way == 0.0 and _save_in <= 0.0:
			_saved = _level
			PlayerSettings.set_value(&"picture.zoom", _level)
			PlayerSettings.save()


func tour_seen(what: StringName) -> bool:
	match what:
		&"zoomed_out":
			return game != null and game.camera != null and game.camera.view_height > CameraRig.VIEW_HEIGHT + 1.0
		&"zoomed_in":
			return game != null and game.camera != null and game.camera.view_height < CameraRig.VIEW_HEIGHT - 1.0
	return false
