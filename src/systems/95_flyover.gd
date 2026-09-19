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
## play camera is 15.
##
## THE CEILING IS THE WORLD NOW, not a frame rate. It was 120 because past that
## the streamer builds more ground than it can carry — which is true, and on a
## 1300-tile world across five continents it also meant a tool for looking at the
## world could show a tenth of one continent. The owner asked for the whole thing
## (2026-09-18: "make it so I can zoom further out in dev flying over mode so I
## can see the entire world if I want") and has already ruled on the trade
## ("loading time doesnt matter"). So it goes all the way out and it will chug
## while it builds: this is dev mode, the chug is honest, and a tool that cannot
## show you the thing you are reviewing is worse than a slow one.
##
## `ceiling()` is asked per world rather than written down, because a constant
## measured against one world size is a countdown against the next one.
const LEAST := 8.0
const MOST := 120.0


## How wide the frame is on the GROUND, either way, in tiles.
##
## A tilted camera does not see a square. `view_height` is the orthographic size,
## which is the screen's vertical extent in world units -- but the ground is
## raked away at `pitch_deg`, so a run of ground along the screen's down axis is
## foreshortened by its sine and the camera reaches FURTHER across the land that
## way than the number says. Across the screen it reaches exactly the width.
func _reach() -> Vector2:
	var h: float = game.camera.view_height
	var aspect := 16.0 / 9.0
	var vp := get_viewport()
	if vp != null:
		var r := vp.get_visible_rect().size
		if r.y > 0.0:
			aspect = float(r.x) / float(r.y)
	var down := (h * 0.5) / maxf(0.2, sin(deg_to_rad(float(game.camera.pitch_deg))))
	return Vector2(h * aspect * 0.5, down)


## As far out as this world can be looked at: the whole of it and no further.
##
## THE OLD NUMBER WAS THE WORLD'S SIDE AND A MARGIN, and that is not what the
## frame has to hold. At 45 degrees of yaw a square world is a DIAMOND on the
## glass, so what must fit is its diagonal -- `size * sqrt(2)` -- and the frame
## has to hold that both ways at once: across the screen against the aspect, and
## down it against the pitch's foreshortening. Vertically is the binding one by a
## wide margin (1.19 sides against 0.80), which is why zooming all the way out
## used to leave the world short of the frame and black space under it.
func ceiling() -> float:
	if game == null or game.world == null:
		return MOST
	var n := float(game.world.size) * sqrt(2.0)
	var aspect := 16.0 / 9.0
	var vp := get_viewport()
	if vp != null:
		var r := vp.get_visible_rect().size
		if r.y > 0.0:
			aspect = float(r.x) / float(r.y)
	var across := n / aspect
	var down := n * sin(deg_to_rad(float(game.camera.pitch_deg)))
	return maxf(MOST, maxf(across, down) * 1.04)


## Is the whole world already on the glass?
##
## ASKED OF THE CAMERA, NOT OF TRIGONOMETRY. I twice wrote down what the pitch
## and the yaw ought to do to a square of ground and was wrong both times -- the
## world foreshortens far harder than the pitch alone accounts for, so a ceiling
## derived from `sin(pitch)` let the zoom run on long after the world had stopped
## growing on the glass, which is the black half the owner was looking at. The
## camera can be asked where a point lands. Ask it.
func _world_in_frame() -> bool:
	var cam := game.camera
	if cam == null or not cam.is_inside_tree():
		return false
	var n := float(game.world.size)
	var seen := cam.get_viewport().get_visible_rect()
	var box := Rect2()
	var first := true
	for c: Vector2 in [Vector2.ZERO, Vector2(n, 0.0), Vector2(0.0, n), Vector2(n, n)]:
		var at := cam.unproject_position(game.world.to_3d(c))
		if first:
			box = Rect2(at, Vector2.ZERO)
			first = false
		else:
			box = box.expand(at)
	# A hair of margin, so it stops with the world clear of the edge rather than
	# flush against it.
	return seen.grow(-16.0).encloses(box)


## How far the world's four corners sit, on the ground, from the middle of the
## frame -- a vector to add to the focus to bring them back. Zero once centred.
func _off_centre() -> Vector2:
	var cam := game.camera
	if cam == null or not cam.is_inside_tree():
		return Vector2.ZERO
	var n := float(game.world.size)
	var box := Rect2()
	var first := true
	for c: Vector2 in [Vector2.ZERO, Vector2(n, 0.0), Vector2(0.0, n), Vector2(n, n)]:
		var at := cam.unproject_position(game.world.to_3d(c))
		if first:
			box = Rect2(at, Vector2.ZERO)
			first = false
		else:
			box = box.expand(at)
	var want := cam.get_viewport().get_visible_rect().get_center()
	var here := _ground_at(box.get_center())
	var there := _ground_at(want)
	if not here.is_finite() or not there.is_finite():
		return Vector2.ZERO
	return here - there


## The focus, kept so the frame never runs off the edge of the world, and CENTRED
## once the frame is wider than the world is.
##
## Without this the focus was only clamped to the world's own tiles, so a player
## standing near a corner kept the camera there while it zoomed out and the world
## slid into one half of the glass with nothing in the other (owner, 2026-09-18:
## "the bottom 3rd or so is always solid black space and the world isnt centred").
func _framed(at: Vector2) -> Vector2:
	var n := float(game.world.size)
	var r := _reach()
	var out := at
	out.x = n * 0.5 if r.x * 2.0 >= n else clampf(at.x, r.x, n - r.x)
	out.y = n * 0.5 if r.y * 2.0 >= n else clampf(at.y, r.y, n - r.y)
	return out
## What one press of e/c does, as a share: zooming by a fixed number of units is
## crawling when you are far out and violent when you are close in.
const ZOOM_STEP := 1.22
## How long a zoom key is held before it runs on by itself, and by what factor a
## second once it does.
## HOW FAR THE CAMERA TIPS TOWARD STRAIGHT DOWN as it pulls out, in degrees on
## top of the play pitch.
##
## THIS IS WHY THE FAR END LOOKED WRONG AND CLAMPING COULD NOT FIX IT. At the
## play pitch a square world is not a square on the glass: 57 degrees flattens
## its far axis so hard that 1300 tiles across five continents came out as a
## sliver with two thirds of the frame empty under it, and no amount of centring
## or ceiling arithmetic moves that, because the world really is that shape from
## there. A map camera goes overhead as it rises, so the world opens out into the
## frame instead of lying down in it. At the ceiling this is all but straight
## down; a stride above the ground it is untouched, so flying close still looks
## like the game.
const TOP_DOWN := 31.0
const ZOOM_WAIT := 0.25
const ZOOM_RUN := 7.0

## How fast it flies, as SHARES OF THE FRAME a second, not tiles: the whole
## reason the tool is usable at 120 as well as at 15.
const CROSS := 0.62
const CROSS_FAST := 2.1

## THE MOUSE IS A FIRST-CLASS CONTROL HERE, and it was missing for no reason
## anybody ever decided: there was not one `InputEventMouse` in the whole of
## `src/` before this. The keys were built first and nobody came back.
##
## Over a map you are reading rather than a body you are driving, the mouse is
## not a convenience — it is the natural instrument. Drag takes hold of the
## ground and moves it under you, which is the one scheme nobody has to be
## taught, and the wheel zooms about the POINTER rather than the middle of the
## screen, so you go toward the thing you are looking at instead of having to
## centre it first and then zoom.
const WHEEL_STEP := 1.14

## Where the picture is, and where it was taken from, so F5 puts it back.
var flying := false
var _at := Vector2.ZERO
## Seconds a zoom key has been held, for the run-on above.
var _zoom_held := 0.0
## The pitch the game was played at, put back on landing.
var _was_pitch := 0.0
var _was_high := 0.0
var _seen: Dictionary = {}
## The ground the drag took hold of, in tiles, and where the pointer was.
var _grabbed := Vector2.INF


var _regions: DevRegions


func setup(g: Game) -> void:
	super.setup(g)
	# Its own layer, over the world and under dev mode's own app (19), because it
	# is about the world rather than about the slate.
	var layer := CanvasLayer.new()
	layer.name = "flyover"
	layer.layer = 18
	add_child(layer)
	_regions = DevRegions.new()
	_regions.game = g
	layer.add_child(_regions)


func _process(delta: float) -> void:
	if game == null or game.world == null or game.camera == null:
		return
	if _pressed(&"dev_fly"):
		_toggle()
	# The regions may be picked out on the ground as well as from the air: which
	# region you are STANDING in is a fair question at head height too.
	if _pressed(&"dev_regions"):
		_regions.showing = not _regions.showing
		Events.message.emit("Regions shown." if _regions.showing else "Regions hidden.")
	if _regions.showing:
		_regions.step()
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
	_was_pitch = game.camera.pitch_deg
	# Opens at four times the play height: far enough to be obviously a different
	# thing, near enough that what he was standing next to is still recognisable,
	# so the transition itself tells him where he is.
	game.camera.view_height = clampf(_was_high * 4.0, LEAST, ceiling())
	Events.message.emit("Flying. Drag to move, wheel to zoom, wasd too. g names the regions, v comes back.")


func _land() -> void:
	flying = false
	game.watch = Vector3.INF
	game.camera.view_height = _was_high if _was_high > 0.0 else 15.0
	game.camera.pitch_deg = _was_pitch if _was_pitch > 0.0 else CameraRig.PITCH_DEG
	Events.message.emit("Back on the ground.")


func _fly(delta: float) -> void:
	var high := game.camera.view_height
	# A TAP IS ONE STEP AND A HELD KEY KEEPS GOING. It only ever fired on the
	# transition, so every step of the zoom cost a separate press -- and with each
	# step a factor of 1.22, the far end of a 1300-tile world is seventeen taps
	# away. Holding did nothing at all, which is why the zoom felt as though it
	# stopped somewhere short of the world.
	var step := 0.0
	if _pressed(&"dev_fly_in"):
		step -= 1.0
	if _pressed(&"dev_fly_out"):
		step += 1.0
	# Held past the tap, it runs on smoothly rather than stuttering a step at a
	# time, and the rate is a FACTOR a second so it feels the same far out as it
	# does close in.
	var held := 0.0
	if Input.is_action_pressed(&"dev_fly_out"):
		held += 1.0
	if Input.is_action_pressed(&"dev_fly_in"):
		held -= 1.0
	if held != 0.0:
		_zoom_held += delta
	else:
		_zoom_held = 0.0
	var by := pow(ZOOM_STEP, step)
	if _zoom_held > ZOOM_WAIT:
		by *= pow(ZOOM_RUN, held * delta)
	# Out only while there is still world off the edge of the glass. `ceiling()`
	# is a backstop; THIS is the stop, because it is measured rather than derived.
	if by > 1.0 and _world_in_frame():
		by = 1.0
	if by != 1.0:
		game.camera.view_height = clampf(high * by, LEAST, ceiling())
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
	# Overhead as it rises: squared, so it keeps the game's own angle while the
	# flyover is still being used to look at a place rather than at the world.
	var base := _was_pitch if _was_pitch > 0.0 else CameraRig.PITCH_DEG
	var out := clampf(inverse_lerp(LEAST, ceiling(), game.camera.view_height), 0.0, 1.0)
	game.camera.pitch_deg = minf(89.0, base + TOP_DOWN * out * out)
	# ONE OF THESE OWNS THE FOCUS AT A TIME, and it took a frame to see why: the
	# clamp pins the focus to the world's middle whenever the frame is wider than
	# the world, so applying it AND the correction below meant the correction was
	# undone on the very next frame and the world never moved. While there is
	# world off the glass the clamp owns it; once it all fits, the correction does.
	if not _world_in_frame():
		_at = _framed(_at)
	# AND PUT THE WORLD IN THE MIDDLE OF THE GLASS, not the focus point.
	#
	# The rig does not draw what it is looking at dead centre -- it stands off and
	# leans, so the world's middle lands well above the middle of the frame and
	# the whole of the bottom is empty. Pinning the FOCUS to the world's centre,
	# which is what the clamp above does, therefore does not centre the WORLD.
	# This reads where the four corners actually landed and walks the focus until
	# their middle is the frame's middle: a correction against the picture, which
	# needs no theory about where the rig stands.
	else:
		_at += _off_centre()
	# The ground under the picture, so flying over a cliff does not sink the view
	# into it: the camera rig takes a point in the world and stands back from it.
	game.watch = game.world.to_3d(_at)


# --- the mouse -----------------------------------------------------------------

## Drag the ground, and zoom about the pointer.
##
## `_unhandled_input` rather than `_input`, so anything with a page open on the
## glass gets the event first and the slate is never dragged out from under the
## person reading it.
func _unhandled_input(event: InputEvent) -> void:
	if not flying or game == null or game.camera == null or game.input_blocked():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_at(mb.position, 1.0 / WHEEL_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_at(mb.position, WHEEL_STEP)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				# Take hold of the GROUND, not the screen: what is under the pointer
				# when the button goes down is what stays under it while it is held,
				# however far out the zoom is. A drag measured in pixels-to-tiles
				# would need the zoom folded in by hand and would drift.
				_grabbed = _ground_at(mb.position) if mb.pressed else Vector2.INF
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _grabbed.is_finite():
		var now := _ground_at((event as InputEventMouseMotion).position)
		if now.is_finite():
			_go_to(_at + (_grabbed - now))
		get_viewport().set_input_as_handled()


## Zoom, keeping whatever is under the pointer under it.
func _zoom_at(at: Vector2, by: float) -> void:
	var before := _ground_at(at)
	var was := game.camera.view_height
	game.camera.view_height = clampf(was * by, LEAST, ceiling())
	if is_equal_approx(game.camera.view_height, was) or not before.is_finite():
		return
	# The camera has to be where it will BE before the ground under the pointer
	# can be asked again, so the move is made, measured and corrected.
	game.watch = game.world.to_3d(_at)
	game.camera.force_update_transform()
	var after := _ground_at(at)
	if after.is_finite():
		_go_to(_at + (before - after))


## Where a screen point meets the ground, in tiles, or INF. Shares `DevRegions`'
## walk down the ray: the camera is orthographic and the ground is terraced, so a
## plane solve answers for a world that is flat and this one is not.
func _ground_at(at: Vector2) -> Vector2:
	if _regions == null:
		return Vector2.INF
	return _regions.ground_under(game.camera, at, game.world)


## Move the picture, held inside the world.
func _go_to(to: Vector2) -> void:
	var n := float(game.world.size)
	_at.x = clampf(to.x, 0.0, n - 1.0)
	_at.y = clampf(to.y, 0.0, n - 1.0)
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
