extends GameSystem
## A camera at EYE LEVEL, staged for a picture (`--eye=H,P,F`), so the world can
## be looked at to the horizon before the play camera can stand there.
##
## The owner has ruled that the game gets a true over-the-shoulder view ("should
## be able to see parts of the sky and the horizon"). The play camera for that is
## built elsewhere (`CameraRig`); this is only the STAND the horizon work is
## judged from, so the land, the far world, the air and the sky can be made to
## hold up at eye level without waiting for it. It is the same three numbers the
## rig will take -- height over the ground, pitch down, vertical fov -- so a frame
## shot here and a frame shot from the rig can be held to each other.
##
## Off unless asked: with no `--eye` this system does nothing at all, so every
## frame of the game as it ships is untouched.
##
## It is a Camera3D of its own made CURRENT, and not a mode of the rig, because
## the rig is another builder's file. Everything that asks the viewport which
## camera is drawing (the streamer, the air, the shadow range) asks it, which is
## exactly what the horizon work has to be measured against.

## How far behind the player the eye stands, in world units: over the shoulder,
## so the player is in the frame and the land runs out past them.
const BACK := 3.2
## Never lower than this over the ground under the eye itself, so a slope rising
## behind the player cannot put the lens inside the hill.
const CLEAR := 0.6

var _cam: Camera3D
var _yaw := 0.0


func setup(g: Game) -> void:
	super.setup(g)
	if g.options.eye == Vector3.ZERO:
		set_process(false)
		return
	_cam = Camera3D.new()
	_cam.name = "eye"
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.fov = clampf(g.options.eye.z, 10.0, 120.0)
	_cam.near = 0.1
	_cam.far = SkyLight.SEE * 1.15
	add_child(_cam)


func started() -> void:
	if _cam == null:
		return
	_yaw = game.player.facing
	_cam.make_current()
	_place()
	# A still picture has to hold the whole view the eye can see, and the far
	# world is built by workers over the first seconds of a game.
	if game.options.shot != "":
		game.view.ensure_near(game.player.pos)
		game.view.ensure_far()


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	var o := game.options.eye
	var ahead := Vector2(cos(_yaw), sin(_yaw))
	var foot: Vector2 = game.player.pos - ahead * BACK
	var ground := maxf(game.view.surface_height(foot), game.view.surface_height(game.player.pos))
	var at := Vector3(foot.x, ground + maxf(o.x, CLEAR), foot.y)
	_cam.global_position = at
	# Facing along the player's own bearing (x east, y south), pitched down.
	var look := Vector3(ahead.x, 0.0, ahead.y)
	_cam.look_at(at + look, Vector3.UP)
	_cam.rotate_object_local(Vector3.RIGHT, -deg_to_rad(o.y))
