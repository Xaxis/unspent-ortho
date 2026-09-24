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

const Walk := preload("res://src/core/colossus/colossus_walk.gd")

var view: ViewScript
var _only := -1
var _stage := NAN
var _start := 0.0
## The walk's minute last frame: the steps between it and this frame's are the
## ones that land now (colossus_walk.gd `steps_between`, which fires nothing
## across a skip).
var _last := NAN
## What a landing sends the player, still on its way: [real seconds left, what
## (&"quake" | &"thump" | &"boom"), where it landed, how far that is].
var _coming: Array = []
## How loud the colossi are where the player stands, 0..1, for the far drone
## (70_audio reads it off the group `&"colossi"`, SoundMix `bed_colossus`).
var hum := 0.0
## How much of a colossus the view is turned toward, 0..1: while it is, the
## shoulder view may tip up far enough to take it in whole (41_shoulder,
## Shoulder.GAZE_LEAST).
var gaze := 0.0
## Landings felt this run, for --stats and the proof: none is ever latched.
var felt_count := 0


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
	add_to_group(&"colossi")


## The walk's own minute: the world clock, or the staged minute and however long
## has passed since the game began.
func minutes() -> float:
	var now: float = game.clock.minutes if game.clock != null else 0.0
	if is_nan(_stage):
		return now
	return _stage + (now - _start)


func _process(delta: float) -> void:
	if view == null or game == null or game.sky == null:
		return
	var cam := get_viewport().get_camera_3d()
	var air: Dictionary = game.sky.seen_air()
	var open := game.sky.closed < 0.5 and SkyLight.last_lid() < 0.5
	var m := minutes()
	view.update(cam, m, air, open and float(air.share) > 0.0)
	# Steps are FELT wherever the sky is open, looking down or out: the ground
	# does not care which way the camera points.
	_land(m if open else NAN)
	_arrive(delta)
	_listen(cam, open)


## Every foot that came down since last frame sends the player three things,
## each at its own real speed: the ground's shake and thump at 3 km/s, the
## boom through the air at 343 m/s.
func _land(m: float) -> void:
	if not is_nan(_last) and not is_nan(m):
		var here := _player_at()
		for i in view.defs.size():
			for e: Dictionary in Walk.steps_between(view.defs[i], view.routes[i], _last, m):
				var at: Vector3 = e.at
				var d := at.distance_to(here)
				if Walk.felt(d).x <= 0.0 and d > Walk.FELT_FAR * 1.5:
					continue
				_coming.append([Walk.ground_delay(d), &"quake", at, d])
				_coming.append([Walk.ground_delay(d), &"thump", at, d])
				_coming.append([Walk.air_delay(d), &"boom", at, d])
	_last = m


func _arrive(delta: float) -> void:
	var i := 0
	while i < _coming.size():
		var c: Array = _coming[i]
		c[0] = float(c[0]) - delta
		if float(c[0]) > 0.0:
			i += 1
			continue
		_coming.remove_at(i)
		var d: float = c[3]
		match c[1]:
			&"quake":
				var f := Walk.felt(d)
				felt_count += 1
				if game.camera != null and f.x > 0.0:
					# Slower the further it has come.
					game.camera.quake(f.x, f.y, lerpf(2.2, 1.0, clampf(d / Walk.FELT_FAR, 0.0, 1.0)))
			&"thump":
				Events.sfx.emit(&"colossus_step", c[2])
			&"boom":
				Events.sfx.emit(&"colossus_boom", c[2])


## The drone's level, and which way the view is turned: both from the walkers'
## live poses, never latched.
func _listen(cam: Camera3D, open: bool) -> void:
	hum = 0.0
	gaze = 0.0
	if not open:
		return
	var here := _player_at()
	var fwd := Vector2.ZERO
	if cam != null:
		var f := -cam.global_transform.basis.z
		fwd = Vector2(f.x, f.z).normalized()
	for p: Dictionary in view.poses:
		if p.is_empty():
			continue
		var o: Vector3 = (p.hub as Transform3D).origin
		var flat := Vector2(o.x - here.x, o.z - here.z)
		var d := flat.length()
		# Loud under it, still there on the skyline.
		var h := clampf(1.0 - log(maxf(d, 25000.0) / 25000.0) / log(12.0), 0.12, 1.0)
		if int(p.swinging) >= 0:
			h = minf(1.0, h * 1.25)
		hum = maxf(hum, h)
		if fwd != Vector2.ZERO and d > 1.0:
			var off := rad_to_deg(absf(fwd.angle_to(flat / d)))
			gaze = maxf(gaze, smoothstep(GAZE_WIDE, GAZE_WIDE * 0.5, off))


## Degrees either side of the view's bearing a walker may stand and still draw
## the gaze up to it.
const GAZE_WIDE := 50.0


func _player_at() -> Vector3:
	var p: Vector2 = game.player.pos if game.player != null else Vector2.ZERO
	return Vector3(p.x, 0.0, p.y)


## For `--stats`: where each walker is from the camera, whether it was drawn,
## and what posing them cost this frame -- the numbers a frame is staged by
## (`--face` toward a bearing) and a budget is argued from.
func stats_line() -> String:
	if view == null:
		return "\nworld colossi: off"
	var cam := get_viewport().get_camera_3d()
	var out := "\nworld colossi: pose %d us, %d landings felt, %d on their way, hum %.2f, gaze %.2f" % [view.last_pose_usec, felt_count, _coming.size(), hum, gaze]
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
		&"colossus_quake":
			return game.camera != null and game.camera.quaking()
		&"colossus_step":
			for p: Dictionary in view.poses:
				if not p.is_empty() and int(p.swinging) >= 0:
					return true
			return false
	return false
