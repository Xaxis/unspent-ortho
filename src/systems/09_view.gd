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

## AT THE BOTTOM OF THE ZOOM THE CAMERA COMES DOWN OFF ITS PERCH (owner, twice:
## "when player zooms all the way in when it reaches maximum zoom in the camera
## should glide to third person perspective").
##
## Spent over the last of the zoom's own range rather than triggered when it
## bottoms out, which is what makes it a GLIDE: the angle is a function of how
## far in you are, so it comes down as you lean in and goes back up as you pull
## out, and there is no state to be in and no moment where the picture jumps. A
## press is a nudge toward it and a hold is the whole move, which is the same
## gesture the zoom already is.
##
## **THE ANGLE ALSO DECIDES HOW MUCH GROUND IS STREAMED, AND 38 IS WHERE THAT
## STOPS GROWING.** `WorldView.view_half_extent` derives the near square from the
## camera's PITCH, and its `rise` term is `6 / tan(pitch)` -- the room a
## six-unit-high thing needs to show from behind. That term runs away as the
## camera lowers, so a lower angle asks for MORE ground, not less. The near
## radius in tiles at 16:9:
##
##     play zoom (15) at 57 degrees      19.7
##     zoomed in (9)  at 57              13.4
##     zoomed in (9)  at 38              18.5   <- still under play zoom
##     zoomed in (9)  at 30              22.4   <- MORE than play zoom
##
## At 30 the act of leaning in asks for a wider square than standing back does,
## which is backwards. At 38 it does not, and 38 was the sheet's other strong
## frame -- the figure in profile, terrace faces reading as walls -- so the
## picture and the streaming agree there.
##
## **WHAT THIS IS NOT: A MEASURED FIX FOR THE OWNER'S ZOOM LURCH.** That was
## claimed here and the claim was wrong twice over. The arithmetic above is
## sound, but the near square measured SIX chunks at both zooms, so the
## difference bought no rebuild at the place it was tested. And the far figures
## that looked like it confirmed something -- `far 4/121` at play against
## `far 64/121` zoomed in -- are BUILT so far of the island's total, not wanted:
## `far_wanted()` returns `n * n` always. A progress counter read as a demand
## counter, which is the `drawn = 4` bug in another coat. The zoom transition
## itself has not been measured; this number rests on the arithmetic and the
## picture, and nothing else.
## How much of the zoom's range the glide is spent over, from the near end.
const GLIDE_BAND := 0.16
const THIRD_PITCH := 38.0

var _level := 0.0
var _saved := 0.0
var _save_in := 0.0


static func level_of(height: float) -> float:
	return clampf(inverse_lerp(CLOSE, FAR, height), 0.0, 1.0)


static func height_of(level: float) -> float:
	return lerpf(CLOSE, FAR, clampf(level, 0.0, 1.0))


## The camera's pitch for a zoom level: the play angle everywhere except the last
## `GLIDE_BAND` of the way in, where it eases to `THIRD_PITCH`. Smoothstepped, so
## the tip-over has no corner in it at either end — a linear ramp reads as the
## camera being dragged, and the whole ask was that it GLIDE.
static func pitch_of(level: float) -> float:
	var t := clampf(inverse_lerp(GLIDE_BAND, 0.0, level), 0.0, 1.0)
	return lerpf(CameraRig.PITCH_DEG, THIRD_PITCH, t * t * (3.0 - 2.0 * t))


## A shot or a tour: never reads the player's zoom and never writes it (setup).
var _tool := false


func setup(g: Game) -> void:
	super.setup(g)
	# A shot or a tour that was given `--zoom=` is staging a picture and this
	# must not take it back; anything else opens where the player left it.
	#
	# **EXCEPT A TOOL RUN, WHICH OPENS AT THE SHIPPED ZOOM AND WRITES NOTHING
	# BACK.** A tour's `zoom 9` went through `set_height`, `_process` saved the
	# level to tool-settings.json like a player's own keys, and the NEXT tool run
	# opened there: the canon's frames 1-17 were shot at whatever zoom the tour
	# before them had left (measured: the file held 0.2, height 14, left by the
	# canon's own closing `zoom 14`; after a probe ending on `zoom 9`, height 9).
	# A picture that depends on what ran before it cannot be compared with
	# anything.
	_tool = g.options.shot != "" or g.options.tour != ""
	if g.options.zoom > 0.0:
		_level = level_of(g.camera.view_height)
	else:
		_level = float(PlayerSettings.default_of(&"picture.zoom")) if _tool else float(PlayerSettings.value(&"picture.zoom"))
		g.camera.view_height = height_of(_level)
	# A game opening at the bottom of the zoom opens in third person, rather than
	# snapping down to it on the first frame the keys are read.
	g.camera.pitch_deg = pitch_of(_level)
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
	# Written every frame and not only while a key is down, so the angle cannot be
	# left behind by anything else that moves the level — and so a system that
	# borrowed the camera and put its own pitch back (95_flyover) is corrected on
	# the first frame this file owns it again.
	game.camera.pitch_deg = pitch_of(_level)
	# Written once the hand comes off the key, not on every frame of the sweep:
	# a setting file is not a place to put sixty writes a second.
	if not _tool and absf(_level - _saved) > SETTLE:
		_save_in = 0.6 if way != 0.0 else maxf(0.0, _save_in - delta)
		if way == 0.0 and _save_in <= 0.0:
			_saved = _level
			PlayerSettings.set_value(&"picture.zoom", _level)
			PlayerSettings.save()


## Put the camera at a view height and KEEP it there.
##
## **A TOUR'S `zoom` WAS WRITING A FIELD THIS FILE OVERWRITES.** 98_tour set
## `camera.view_height` directly, and `_process` here puts it straight back from
## `_level` on the next frame — so `zoom 9` in a tour moved the camera for one
## frame and then undid itself, and any frame shot after it was at whatever the
## player setting said. A command that does nothing is worse than a missing one,
## because the tour reads as having proved something about a zoomed camera.
##
## Going through the level rather than the height also means the glide comes with
## it: a tour that zooms all the way in gets the third-person pitch a player
## would get, instead of a close camera still looking straight down.
func set_height(h: float) -> void:
	_level = level_of(h)
	if game != null and game.camera != null:
		game.camera.view_height = height_of(_level)
		game.camera.pitch_deg = pitch_of(_level)


func tour_seen(what: StringName) -> bool:
	match what:
		&"zoomed_out":
			return game != null and game.camera != null and game.camera.view_height > CameraRig.VIEW_HEIGHT + 1.0
		&"zoomed_in":
			return game != null and game.camera != null and game.camera.view_height < CameraRig.VIEW_HEIGHT - 1.0
		&"third_person":
			# Asked of the LIVE camera and not of `_level`, so a tour proves the
			# picture and not this file's own bookkeeping.
			return game != null and game.camera != null \
				and game.camera.pitch_deg < lerpf(CameraRig.PITCH_DEG, THIRD_PITCH, 0.5)
	return false
