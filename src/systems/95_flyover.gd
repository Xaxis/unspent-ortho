extends GameSystem
## FLYING OVER THE WHOLE ISLAND (owner, 2026-09-18: "a view where I can zoom out
## over the entire world and see everything, all the landscapes, and travel over
## everything and zoom into a given landscape so I can explore the world and give
## meaningful feedback").
##
## F5 takes the picture off the player and puts it in the air over wherever he
## was standing. WASD flies it, and the speed rides the zoom, so one press
## crosses about the same share of the frame however far out you are — flying at
## a walking pace over a five-hundred-tile island is the difference between a
## tool somebody uses and one they try once. Shift is faster, e/c the zoom, F5
## again puts it back on the player's shoulder.
##
## THE PLAYER IS NOT MOVED AND NOTHING IS SIMULATED DIFFERENTLY. This writes
## `Game.watch` and the camera's `view_height` and nothing else in the world: the
## body stays where it was, the machines go on doing what they were doing, the
## clock runs. It is a camera, not a cheat, so what he is looking at is the game
## as it actually is — which is the whole point of being able to look.
##
## WHY IT IS ONE FIELD AND NOT TWO. `Game.watch` feeds the camera AND the world's
## streaming focus from one place (`game.gd`). A flyover that moved only the
## camera would fly over ground nobody had built and show him a hole where a
## landscape is, which is worse than not having the tool: he would be giving
## feedback on a bug in the instrument.
##
## THE CEILING IS MEASURED AND IT IS REAL. The world is streamed in chunks around
## the focus and the wanted set grows with the SQUARE of the view height, so
## there is a height past which the machine is building more ground than it can
## carry and the frame stops being evidence about anything. `MOST` is that
## ceiling. To see the whole island at once, that is what the survey (m) is for,
## and dev mode now draws it whole — the two are one tool: read the map for where
## to go, fly there to see what it actually looks like.

## How high the picture may be taken from, in world units of view height. The
## play camera is 15. `MOST` is not "as far as the arithmetic allows" — see the
## header: past it the streamer is the thing you are looking at.
const LEAST := 8.0
const MOST := 120.0
## What one press of e/c does, as a share: zooming by a fixed number of units is
## crawling when you are far out and violent when you are close in.
const ZOOM_STEP := 1.22

## How fast it flies, as SHARES OF THE FRAME a second, not tiles: the whole
## reason the tool is usable at 120 as well as at 15.
const CROSS := 0.62
const CROSS_FAST := 2.1

## Where the picture is, and where it was taken from, so F5 puts it back.
var flying := false
var _at := Vector2.ZERO
var _was_high := 0.0
var _seen: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)


func _process(delta: float) -> void:
	if game == null or game.world == null or game.camera == null:
		return
	if _pressed(&"dev_fly"):
		_toggle()
	if not flying:
		return
	# A page on the glass holds every other key, and the map is the page most
	# likely to be open while flying: reading it and flying at once would mean
	# the arrows did two things.
	if game.input_blocked():
		return
	_fly(delta)


## Never while dev mode is out of reach — in a shipped build whose configuration
## forbids it, F5 is not a key.
func _pressed(action: StringName) -> bool:
	if not DevMode.reachable() or not InputMap.has_action(action):
		return false
	var down := Input.is_action_pressed(action)
	var was: bool = _seen.get(action, false)
	_seen[action] = down
	return down and not was


func _toggle() -> void:
	if flying:
		_land()
		return
	flying = true
	_at = game.player.pos
	_was_high = game.camera.view_height
	# Opens at four times the play height: far enough to be obviously a different
	# thing, near enough that what he was standing next to is still recognisable,
	# so the transition itself tells him where he is.
	game.camera.view_height = clampf(_was_high * 4.0, LEAST, MOST)
	Events.message.emit("Flying. wasd to cross, e/c to zoom, F5 to come back.")


func _land() -> void:
	flying = false
	game.watch = Vector3.INF
	game.camera.view_height = _was_high if _was_high > 0.0 else 15.0
	Events.message.emit("Back on the ground.")


func _fly(delta: float) -> void:
	var high := game.camera.view_height
	if _pressed(&"dev_fly_in"):
		game.camera.view_height = clampf(high / ZOOM_STEP, LEAST, MOST)
	if _pressed(&"dev_fly_out"):
		game.camera.view_height = clampf(high * ZOOM_STEP, LEAST, MOST)
	var input := Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down"))
	if input.length_squared() > 0.0:
		# Screen-relative, through the camera's own yaw, for the same reason the
		# player's keys are: the arrows must match the picture.
		var go := Player.screen_to_world(input.limit_length(1.0), game.camera.yaw_now())
		var pace := (CROSS_FAST if Input.is_action_pressed(&"run") else CROSS) * high
		_at += go * pace * delta
		var n := float(game.world.size)
		_at.x = clampf(_at.x, 0.0, n - 1.0)
		_at.y = clampf(_at.y, 0.0, n - 1.0)
	# The ground under the picture, so flying over a cliff does not sink the view
	# into it: the camera rig takes a point in the world and stands back from it.
	game.watch = game.world.to_3d(_at)


## What the readout and a tour ask.
func where() -> Vector2:
	return _at


func tour_seen(what: StringName) -> bool:
	match what:
		&"flying":
			return flying
		&"grounded":
			return not flying
	return false
