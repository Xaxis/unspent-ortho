extends Node
## `perf pace begin LABEL` / `perf pace end LABEL`: how evenly a moving player
## is drawn, measured on the frames between the two lines while the tour's own
## real input (walk, press) moves him. 98_tour dispatches to it; kept out of
## 98_tour so its merges stay mechanical.
##
## Sampled just before each frame is drawn (RenderingServer.frame_pre_draw),
## when every transform the frame will show is set:
##   s  the player's chest on the screen
##   w  a fixed point of ground on the screen (the player's feet at `begin`)
## and three numbers printed at `end`, in pixels of the 1080-row frame:
##   glide   p90/p10 of |d(s - w)| / dt over frames he moves: the player's own
##           speed over the ground as drawn. Even motion is 1.0; a body drawn at
##           simulation steps against a smoothed ground is well over it.
##   jerk    p95 of |d2 w|, the camera's scroll changing from one frame to the
##           next. A steady walk is near 0; a camera chasing a terrace step is not.
##   wobble  p95 of |d2 s|, the player's own place on the screen doing the same.
## It changes nothing and prints numbers; the verdict is the reader's.

const ROWS := 1080.0
## The chest, over the feet: what an eye follows.
const CHEST := 0.85

var _game: Node
var _label := ""
var _anchor := Vector3.ZERO
var _s: Array[Vector2] = []
var _w: Array[Vector2] = []
var _dt: Array[float] = []


static func perf(tour: Node, game: Node, parts: PackedStringArray) -> bool:
	if parts.size() < 3:
		printerr("tour perf pace: begin|end LABEL")
		return false
	var label := parts[3] if parts.size() > 3 else "pace"
	var probe := tour.get_node_or_null(^"pace_perf") as Node
	if parts[2] == "begin":
		if probe != null:
			printerr("tour perf pace: already measuring %s" % probe.get("_label"))
			return false
		probe = (load("res://src/systems/tour/pace_perf.gd") as GDScript).new()
		probe.name = "pace_perf"
		probe.set("_game", game)
		probe.set("_label", label)
		tour.add_child(probe)
		return true
	if parts[2] == "end":
		if probe == null:
			printerr("tour perf pace: end with nothing begun")
			return false
		probe.call(&"report")
		# Out of the tree now, not at the frame's end: a `begin` on the next line
		# must find no probe standing.
		tour.remove_child(probe)
		probe.queue_free()
		return true
	printerr("tour perf pace: begin|end, not %s" % parts[2])
	return false


func _ready() -> void:
	var player: Node3D = _game.get("player")
	_anchor = player.global_position
	RenderingServer.frame_pre_draw.connect(_sample)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sample):
		RenderingServer.frame_pre_draw.disconnect(_sample)


func _sample() -> void:
	var cam := get_viewport().get_camera_3d()
	var player: Node3D = _game.get("player")
	if cam == null or player == null:
		return
	var px := ROWS / get_viewport().get_visible_rect().size.y
	_s.append(cam.unproject_position(player.global_position + Vector3.UP * CHEST) * px)
	_w.append(cam.unproject_position(_anchor) * px)
	_dt.append(get_process_delta_time())


func report() -> void:
	var glide: Array[float] = []
	var jerk: Array[float] = []
	var wobble: Array[float] = []
	for i in range(1, _s.size()):
		var dt := maxf(_dt[i], 1e-4)
		var rel := ((_s[i] - _w[i]) - (_s[i - 1] - _w[i - 1])).length() / dt
		if rel > 1.0:
			glide.append(rel)
		if i >= 2:
			jerk.append(((_w[i] - _w[i - 1]) - (_w[i - 1] - _w[i - 2])).length())
			wobble.append(((_s[i] - _s[i - 1]) - (_s[i - 1] - _s[i - 2])).length())
	glide.sort()
	jerk.sort()
	wobble.sort()
	var spread := _at(glide, 0.9) / maxf(_at(glide, 0.1), 1e-3) if glide.size() > 4 else NAN
	print("perf pace %s: %d frames, %d moving, glide p90/p10 %.2f (p50 %.0f px/s), jerk p95 %.2f px, wobble p95 %.2f px" % [
		_label, _s.size(), glide.size(), spread, _at(glide, 0.5), _at(jerk, 0.95), _at(wobble, 0.95)])


static func _at(sorted: Array[float], q: float) -> float:
	if sorted.is_empty():
		return NAN
	return sorted[clampi(int(round(q * (sorted.size() - 1))), 0, sorted.size() - 1)]
