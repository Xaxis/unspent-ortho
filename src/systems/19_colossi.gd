extends GameSystem
## The walking megastructures in the sky (src/core/colossus/, the drawing in
## src/render/colossus/). This owns none of the drawing: it hands the view the
## world clock, the camera that is drawing, and the air the sky composed, and
## says whether the sky can be seen at all.
##
## THEY ARE DRAWN ONLY WHILE THE HORIZON IS IN FRAME (`SkyLight.horizon_share`
## above 0), which is the eye-level and over-the-shoulder view. The play camera
## looks down at the ground and a walker fifty kilometres up is never in its
## frustum, so the orthographic game draws nothing and pays one comparison.
## Under a roof (a cave, `SkyLight.closed`) or a lid of smog there is no sky to
## stand in, and they stand down.
##
## Numbered after the sky (10) so the air it reads is this frame's, and before
## the realms (20), which may swap the world under it.
##
## `--colossi=off` takes them away for a run (the only honest way to measure
## what they cost), and `--colossus=W@MINUTE` shows walker W alone, standing
## where its walk puts it MINUTE world minutes into the clock, and walking on
## from there -- a moment of the gait staged by name rather than waited for.

const ViewScript := preload("res://src/render/colossus/colossus_view.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")

var view: ViewScript
var _only := -1
var _stage := NAN
var _start := 0.0


func setup(g: Game) -> void:
	super.setup(g)
	if g.options.colossi == &"off":
		set_process(false)
		return
	var defs: Array = Def.walkers(g.world.size)
	var spec: String = g.options.colossus
	if spec != "":
		var parts := spec.split("@")
		_only = clampi(parts[0].to_int(), 0, defs.size() - 1)
		if parts.size() > 1:
			_stage = parts[1].to_float()
		defs = [defs[_only]]
	view = ViewScript.new()
	view.name = "colossi"
	add_child(view)
	view.setup(defs, g.world.seed_value, g.world.size)
	_start = g.clock.minutes if g.clock != null else 0.0


## The walk's own minute: the world clock, or the staged minute and however long
## has passed since the game began.
func minutes() -> float:
	var now: float = game.clock.minutes if game.clock != null else 0.0
	if is_nan(_stage):
		return now
	return _stage + (now - _start)


func _process(_delta: float) -> void:
	if view == null or game == null or game.sky == null:
		return
	var cam := get_viewport().get_camera_3d()
	var air: Dictionary = game.sky.seen_air()
	var open := game.sky.closed < 0.5 and SkyLight.last_lid() < 0.5
	view.update(cam, minutes(), air, open and float(air.share) > 0.0)


## For `--stats`: where each walker is from the camera, whether it was drawn,
## and what posing them cost this frame -- the numbers a frame is staged by
## (`--face` toward a bearing) and a budget is argued from.
func stats_line() -> String:
	if view == null:
		return "\nworld colossi: off"
	var cam := get_viewport().get_camera_3d()
	var out := "\nworld colossi: pose %d us" % view.last_pose_usec
	if cam != null:
		var f := -cam.global_transform.basis.z
		out += ", the camera looks at bearing %.0f" % fposmod(rad_to_deg(atan2(f.z, f.x)), 360.0)
	for i in view.defs.size():
		var p: Dictionary = view.poses[i]
		if p.is_empty() or cam == null:
			continue
		var o: Vector3 = (p.hub as Transform3D).origin
		var e := cam.global_position
		var flat := Vector2(o.x - e.x, o.z - e.z)
		# --face's own convention: degrees, 0 east, 90 south.
		out += "\nworld colossus %s: %s, %.0f km at bearing %.0f, hub %.0f deg up, leg %d in the air" % [
			view.defs[i].id, "drawn" if view.drawn[i] else "not drawn", flat.length() / 1000.0,
			fposmod(rad_to_deg(atan2(flat.y, flat.x)), 360.0),
			rad_to_deg(atan2(o.y - e.y, flat.length())), int(p.swinging)]
	return out


## A tour asks the LIVE view, never a latch: a walker is either on the glass
## this frame or it is not.
func tour_seen(what: StringName) -> bool:
	if view == null:
		return false
	match what:
		&"colossus":
			return view.drawn.has(true)
		&"colossus_step":
			for p: Dictionary in view.poses:
				if not p.is_empty() and int(p.swinging) >= 0:
					return true
			return false
	return false
