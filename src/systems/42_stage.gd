extends GameSystem
## THE STAGED LOOK: turn the view to a thing, hold it there a few seconds, turn
## back. The one way the game points the player's eye at something (ROADMAP
## slice 1: the Tether's first sight, a keeper's reveal and its fall), so every
## beat looks the same and none rolls its own camera.
##
##   var stage := get_tree().get_first_node_in_group(&"stage")   # null without it
##   stage.look(at: Vector3, hold: float, reason: StringName) -> bool
##   stage.look_bearing(bearing: float, elevation: float, hold: float, reason, fov := 0.0) -> bool
##   stage.looking() -> bool      stage.why() -> StringName
##   signal looked(why)           the view is back
##
## `bearing` is OrbitPass's: radians, 0 east, PI/2 south; `elevation` radians up;
## `fov` (degrees, 0 for the lens's own) widens the eye to frame a tall thing.
## A look is refused (false) while another is on or the keys are held by a page
## or a talk. For the whole of it the keys are held (Game.staged): nothing walks,
## swings or turns the view under it; the world goes on.
##
## HOW IT LOOKS: the rig turns its eye toward the thing by a weight eased in over
## TURN seconds and out again (CameraRig.stage_weight, the rig's last word on its
## pose). From above the lens is held to the eye for the look (hold_lens), since
## a flat top-down frame cannot turn to anything, and handed back after.
##
## ONCE-ONLY IS THE CALLER'S: the keeper knows it has woken, the wake that it has
## happened. This remembers nothing.

signal looked(why: StringName)

## Seconds to turn in, and out.
const TURN := 0.6

var _why := &""
var _t := 0.0
var _hold := 0.0
var _point := Vector3.INF
var _dir := Vector3.ZERO


func setup(g: Game) -> void:
	super.setup(g)
	add_to_group(&"stage")


func look(at: Vector3, hold: float, reason: StringName) -> bool:
	return _begin(at, Vector3.ZERO, hold, reason)


func look_bearing(bearing: float, elevation: float, hold: float, reason: StringName, fov: float = 0.0) -> bool:
	var dir := Vector3(cos(bearing) * cos(elevation), sin(elevation), sin(bearing) * cos(elevation))
	if not _begin(Vector3.INF, dir, hold, reason):
		return false
	game.camera.stage_fov = fov
	return true


func looking() -> bool:
	return _why != &""


func why() -> StringName:
	return _why


func _begin(point: Vector3, dir: Vector3, hold: float, reason: StringName) -> bool:
	if looking() or game == null or game.camera == null or game.input_blocked():
		return false
	_why = reason
	_t = 0.0
	_hold = maxf(0.0, hold)
	_point = point
	_dir = dir
	game.camera.hold_lens(&"stage", true)
	game.staged = true
	var cam := game.camera
	cam.stage_point = _point
	cam.stage_dir = _dir
	cam.stage_weight = 0.0
	return true


func _process(delta: float) -> void:
	if not looking() or game == null or game.camera == null:
		return
	_t += delta
	# The body is held for the look: the move it is driven by is none.
	game.scripted_move = Vector2.ZERO
	game.scripted_seconds = maxf(game.scripted_seconds, 0.1)
	var total := TURN * 2.0 + _hold
	var w := 1.0
	if _t < TURN:
		w = smoothstep(0.0, 1.0, _t / TURN)
	elif _t > TURN + _hold:
		w = smoothstep(0.0, 1.0, 1.0 - (_t - TURN - _hold) / TURN)
	game.camera.stage_weight = w
	if _t >= total:
		_end()


func _end() -> void:
	var was := _why
	_why = &""
	game.camera.stage_weight = 0.0
	game.camera.stage_point = Vector3.INF
	game.camera.stage_fov = 0.0
	game.camera.hold_lens(&"stage", false)
	game.staged = false
	game.scripted_seconds = 0.0
	looked.emit(was)


func _exit_tree() -> void:
	if looking() and game != null and game.camera != null:
		_end()


## `staging`: a look is on. `staging:WHY`: that look.
func tour_seen(what: StringName) -> bool:
	var s := String(what)
	if s == "staging":
		return looking()
	if s.begins_with("staging:"):
		return looking() and String(_why) == s.substr(8)
	return false
