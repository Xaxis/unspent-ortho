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
## `--colossus=W@treadN` (or `@treadN+M`, `@treadN-M`) is the moment walker W's
## foot comes down in tread N of this world, and M world minutes after or before.
##
## A FOOT IN THE REGION (slice 3). The straddling walker steps back into the
## craters world generation cut for it (src/core/colossus/colossus_treads.gd,
## src/core/worldgen/gen_treads.gd). While one of its feet is down in a tread,
## or less than `BLOCK_FROM` over it, its pads stop bodies (`set_blocks`) and a
## body caught under one is put out at its edge; what stands where a pad comes
## down is crushed, worked out again from the clock at load and not saved. Its
## landing throws dust off every pad, vents steam, and sends a shock through
## everything that sways. Near the camera the foot is drawn in real space by
## colossus_foot.gd (L0), whose share of the pixels the far body gives up.

const ViewScript := preload("res://src/render/colossus/colossus_view.gd")
const FootScript := preload("res://src/render/colossus/colossus_foot.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")
const Treads := preload("res://src/core/colossus/colossus_treads.gd")

const Walk := preload("res://src/core/colossus/colossus_walk.gd")

var view: ViewScript
var foot: FootScript
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
	var tread_spec := ""
	if spec != "":
		var parts := spec.split("@")
		_only = clampi(parts[0].to_int(), 0, defs.size() - 1)
		if parts.size() > 1:
			if parts[1].begins_with("tread"):
				tread_spec = parts[1]
			else:
				_stage = parts[1].to_float()
		defs = [defs[_only]]
	view = ViewScript.new()
	view.name = "colossi"
	add_child(view)
	view.setup(defs, g.world.seed_value, g.world.size)
	Treads.hand_over(view.defs, view.routes, g.world.landmarks)
	if tread_spec != "":
		_stage = _tread_minute(tread_spec)
	foot = FootScript.new()
	foot.name = "colossus_feet"
	add_child(foot)
	_start = g.clock.minutes if g.clock != null else 0.0
	add_to_group(&"colossi")


## The walk minute a staged `treadN[+M|-M]` names: when the foot comes down in
## this world's Nth tread, offset by M world minutes. NAN when this
## world has no such tread, which stages nothing.
func _tread_minute(spec: String) -> float:
	var s := spec.trim_prefix("tread")
	var off := 0.0
	for sign: String in ["+", "-"]:
		var at := s.find(sign)
		if at > 0:
			off = s.substr(at + 1).to_float() * (1.0 if sign == "+" else -1.0)
			s = s.left(at)
	# Counted as `place treadN` counts them (GenPlaces.find): tread0 and tread1
	# are both the first.
	var n := maxi(0, s.to_int() - 1)
	var seen := 0
	for m: Dictionary in game.world.landmarks:
		if StringName(m.get("kind", &"")) != &"tread":
			continue
		if seen == n:
			for i in view.defs.size():
				if view.defs[i].id == StringName(m.walker):
					return Treads.lands_at(view.defs[i], view.routes[i], int(m.leg), int(m.j)) + off
		seen += 1
	push_warning("--colossus: this world has no %s" % spec)
	return NAN


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
	# The near feet: drawn whichever way the camera looks, down or out, because a
	# foot standing in the region is on the land and not in the sky.
	var dome: Dictionary = air.get("dome", {})
	var t0 := Time.get_ticks_usec()
	foot.update(cam, view.defs, view.poses, float(dome.get(&"dome_night", 0.0)))
	for i in view.defs.size():
		view.set_l0(i, foot.shares.get(i, Vector3.ZERO))
	var t1 := Time.get_ticks_usec()
	_treads(m, delta)
	var t2 := Time.get_ticks_usec()
	# Steps are FELT wherever the sky is open, looking down or out: the ground
	# does not care which way the camera points.
	_land(m if open else NAN)
	_arrive(delta)
	var t3 := Time.get_ticks_usec()
	_listen(cam, open)
	_cast(open)
	_cost = Vector4(t1 - t0, t2 - t1, t3 - t2, Time.get_ticks_usec() - t3)


## What this frame's parts cost, microseconds: the near feet, the treads, the
## landings on their way, the drone and the shadows (--stats).
var _cost := Vector4.ZERO


## How far round the player a leg's shadow is looked for: the land the eye can
## see at the horizon (Shoulder.FAR) and a little more.
const SHADOW_REACH := 1600.0
## How many leg shadows were handed to the land this frame (--stats, a tour).
var shadows := 0


## The legs' shadows on the land, as capsules in globals (sky.gdshaderinc
## `sky_colossus`), from the REAL sun -- the one the sky draws -- which is low
## at dusk and gone at night, so a leg's shadow runs long across the land at
## evening and there is none after dark.
func _cast(open: bool) -> void:
	var caps: Array = []
	var sun := Vector3.ZERO
	if open:
		var h: float = game.sky.clock_hour
		sun = SkyLight.sky_sun(h, float(SkyLight.sun_at(h).azimuth))
		var here := _player_at()
		for i in view.defs.size():
			caps.append_array(Walk.shadow_capsules(view.defs[i], view.poses[i], sun, here, SHADOW_REACH))
	caps.resize(mini(caps.size(), Walk.SHADOW_MOST))
	shadows = caps.size()
	RenderingServer.global_shader_parameter_set(&"colossus_sun", Vector4(sun.x, sun.y, sun.z, float(shadows)))
	for m in 4:
		var cols: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
		for j in 2:
			var i := m * 2 + j
			if i < caps.size():
				var c: Array = caps[i]
				var a: Vector3 = c[0]
				var b: Vector3 = c[1]
				cols[j * 2] = Vector4(a.x, a.y, a.z, float(c[2]))
				cols[j * 2 + 1] = Vector4(b.x, b.y, b.z, float(c[3]))
		RenderingServer.global_shader_parameter_set(StringName("colossus_legs%d" % m), Projection(cols[0], cols[1], cols[2], cols[3]))


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


## A foot this far over its tread, or less, already stops a body: the last few
## hundred metres of the set-down are the slowest part of the step, and nobody
## should be able to walk in under a pad that is about to land.
const BLOCK_FROM := 300.0
## How far past a pad's edge a body is put when one comes down on it.
const PUSH_CLEAR := 1.2
## A landing is FELT at its tread only if the walk moved less than this since the
## last frame (world minutes): across a skip (a night slept, a load) it has not
## landed now, it has been standing there.
const LANDED_WITHIN := 5.0
## How fast the shock of a landing runs out through what sways, metres a real
## second, and how long it runs.
const SHOCK_SPEED := 70.0
const SHOCK_SECS := 11.0

## Pads that stop bodies now, as handed to the query (tile space).
var blocks: Array[Vector3] = []
## Which feet (walker * 3 + leg) stood on a tread last frame.
var _down: Dictionary = {}
var _tread_last := NAN
## Landings in the treads this run, for --stats. A tour asks the live world
## (`colossus_tread`), never this.
var tread_landings := 0
## The shock running now: [where (tile space), real seconds since the landing].
var _shock: Array = []


## WHAT THE FEET IN THE TREADS DO TO THE REGION, from the clock: which pads stop
## bodies, who is put out from under one, what is crushed, and -- only when a
## foot has come down since the last frame -- the landing itself.
func _treads(m: float, delta: float) -> void:
	var circles: Array[Vector3] = []
	var now_down := {}
	var skipped := is_nan(_tread_last) or is_nan(m) or absf(m - _tread_last) > LANDED_WITHIN
	_tread_last = m
	if not is_nan(m):
		for i in view.defs.size():
			var d: RefCounted = view.defs[i]
			for o: Dictionary in Treads.over(d, view.routes[i], m):
				var t: Vector4 = o.tread
				var pads := Treads.pads(d, Vector2(t.x, t.z), t.w)
				if float(o.height) < BLOCK_FROM:
					for p: Vector3 in pads:
						circles.append(Vector3(p.x, p.y, p.z + 1.0))
				if bool(o.planted):
					var key := i * 3 + int(o.leg)
					now_down[key] = true
					if not _down.has(key):
						_crush(pads)
						if not skipped:
							_landed(d, pads, t, (view.poses[i].ankles as Array)[int(o.leg)])
	_down = now_down
	if circles != blocks:
		blocks = circles
		if game.query != null:
			game.query.set_blocks(&"colossi", blocks)
	if not blocks.is_empty():
		_push_out(blocks)
	_run_shock(delta)


## Everything standing where a pad is now: crushed, for good. Asked again the
## moment a foot stands in a tread -- including the first frame of a loaded game
## -- so it is worked out from the clock and never saved.
func _crush(pads: Array[Vector3]) -> void:
	var w := game.world
	for p: Vector3 in pads:
		var at := Vector2(p.x, p.y)
		for q: WorldProp in game.query.props_near(at, p.z + 4.0):
			if w.depleted.has(q.id) and is_inf(float(w.depleted[q.id])):
				continue
			if q.pos.distance_to(at) > p.z + q.solid:
				continue
			w.depleted[q.id] = INF
			if game.view != null:
				game.view.refresh_props(q)


## A body under a pad is put out at its edge, the nearest way.
func _push_out(pads: Array[Vector3]) -> void:
	var pl := game.player
	if pl != null:
		var to := _outside(pads, pl.pos)
		if to != pl.pos:
			# The fight body owns the player's place in a running game: both move,
			# or the next frame puts them back under the pad.
			pl.pos = to
			if pl.hero != null:
				pl.hero.pos = to
	if pl != null and pl.sim != null:
		for mob: MobState in pl.sim.mobs:
			mob.pos = _outside(pads, mob.pos)


static func _outside(pads: Array[Vector3], at: Vector2) -> Vector2:
	for p: Vector3 in pads:
		var c := Vector2(p.x, p.y)
		var d := at - c
		if d.length() < p.z + PUSH_CLEAR:
			var out := d.normalized() if d.length() > 0.01 else Vector2.RIGHT
			return c + out * (p.z + PUSH_CLEAR)
	return at


## A foot has come down in a tread: the region feels it.
func _landed(d: RefCounted, pads: Array[Vector3], t: Vector4, ankle: Vector3) -> void:
	tread_landings += 1
	var w := game.world
	var centre := Vector2(t.x, t.z)
	var dust := Palette.ASH[3]
	var gi := floori(centre.y) * w.size + floori(centre.x)
	if gi >= 0 and gi < w.ground.size():
		dust = GroundColors.wash(w.ground[gi], w.country[gi])
	foot.land(pads, t.y, ankle, dust)
	# The quake, the thump and the boom are the step's own (`_land`), which every
	# landing sends however near it is.
	_shock = [centre, 0.0]


func _run_shock(delta: float) -> void:
	if _shock.is_empty():
		return
	_shock[1] = float(_shock[1]) + delta
	var s: float = _shock[1]
	var c: Vector2 = _shock[0]
	if s > SHOCK_SECS:
		_shock = []
		RenderingServer.global_shader_parameter_set(&"colossus_shock", Vector4.ZERO)
		return
	RenderingServer.global_shader_parameter_set(&"colossus_shock", Vector4(c.x, c.y, s * SHOCK_SPEED, 1.0 - s / SHOCK_SECS))


## The world under the player changed (a shaft, a gate): its treads are the new
## world's, and nothing of the old one's pads may stop a body here.
func realm_changed(_from: StringName, _to: StringName) -> void:
	if view == null:
		return
	for r: RefCounted in view.routes:
		r.treads.clear()
	Treads.hand_over(view.defs, view.routes, game.world.landmarks)
	blocks = []
	_down = {}
	if game.query != null:
		game.query.set_blocks(&"colossi", blocks)


## For `--stats`: where each walker is from the camera, whether it was drawn,
## and what posing them cost this frame -- the numbers a frame is staged by
## (`--face` toward a bearing) and a budget is argued from.
func stats_line() -> String:
	if view == null:
		return "\nworld colossi: off"
	var cam := get_viewport().get_camera_3d()
	var out := "\nworld colossi: pose %d us, %d landings felt, %d on their way, hum %.2f, gaze %.2f, %d leg shadows on the land, the player at %.0f,%.0f" % [view.last_pose_usec, felt_count, _coming.size(), hum, gaze, shadows, _player_at().x, _player_at().z]
	out += "\nworld colossi cost (us): feet %d, treads %d, landings %d, drone and shadows %d" % [_cost.x, _cost.y, _cost.z, _cost.w]
	out += "\nworld colossi feet: %d drawn near, %d surfaces uploaded, %d feet down in treads, %d pads stopping bodies, %d landings in the treads" % [foot.drawn, foot.uploaded, _down.size(), blocks.size(), tread_landings]
	for key: int in _down:
		var a: Vector3 = (view.poses[key / 3].ankles as Array)[key % 3]
		out += ", walker %d leg %d's ankle over %.0f,%.0f" % [key / 3, key % 3, a.x, a.z]
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
		&"colossus_shadow":
			return shadows > 0
		&"colossus_quake":
			return game.camera != null and game.camera.quaking()
		&"colossus_step":
			for p: Dictionary in view.poses:
				if not p.is_empty() and int(p.swinging) >= 0:
					return true
			return false
		&"colossus_foot":
			return foot != null and foot.drawn > 0
		&"colossus_tread":
			return not _down.is_empty()
		&"colossus_blocks":
			return not blocks.is_empty()
	return false


## What `near NAME` may ask of this system (tests/tours/test_tour_claims.gd reads
## it, since no prop kind answers them).
const TOUR_PLACES := ["colossus_foot", "colossus_pad"]


## `near colossus_foot` (or `at colossus:foot`): under the ankle of the nearest
## tread, between its toes. `near colossus_pad`: outside the nearest crater,
## beyond its pad, facing it and the ankle behind it.
func tour_place(what: String) -> Vector2:
	var pad := what == "colossus_pad" or what == "colossus:pad"
	if not pad and what != "colossus_foot" and what != "colossus:foot":
		return Vector2.INF
	var here: Vector2 = game.player.pos
	var best := Vector2.INF
	_facing = NAN
	for m: Dictionary in game.world.landmarks:
		if StringName(m.get("kind", &"")) != &"tread":
			continue
		var spots: Array[Vector2] = [m.pos as Vector2]
		var faces: Array[float] = [float(m.yaw)]
		if pad:
			spots.clear()
			faces.clear()
			for p: Vector3 in (m.pads as Array):
				var c := Vector2(p.x, p.y)
				var out := (c - (m.pos as Vector2)).normalized()
				spots.append(c + out * PAD_STAND)
				faces.append((-out).angle())
		for s in spots.size():
			if best == Vector2.INF or spots[s].distance_to(here) < best.distance_to(here):
				best = spots[s]
				_facing = faces[s]
	return best


var _facing := NAN
## How far from a pad's middle `near colossus_pad` stands: outside the foot, past
## the crater's lip, looking back in at the pad with the toe and the drum rising
## behind it, far enough off that the whole pad is in the frame.
const PAD_STAND := 72.0


## Which way `tour_place` stood the player to face: at a pad, toward it; under
## the ankle, out along the first toe.
func tour_face(what: String) -> float:
	return _facing if what.begins_with("colossus") else NAN
