extends GameSystem
## DEBRIS FALLING THROUGH THE SKY (src/core/sky/fall_schedule.gd says when and
## what; the drawing is src/render/falls/). The fractured platform sheds pieces
## round its passes, and they burn through the air over the island: dust as a
## short streak, a fragment breaking up into glowing pieces and leaving a train
## that twists in the high winds for a minute or two, and now and then a mass --
## a fireball that can be seen by day, whose boom rolls in minutes later.
## Nothing here lands (a fall in the world is its own slice).
##
## THE CLOCK SAYS WHEN, THE BODY SAYS HOW LONG: a fall lights at its world
## minute (`FallSchedule.between` last frame's minute and this one's, nothing
## across a skip), and from then on it ages in REAL seconds, the way the eye
## watches it -- so a tour's `hour` pinning the clock cannot stop one halfway.
## A skip clears the sky: the player did not watch those trains fade.
##
## SEEN ONLY WHILE THE HORIZON IS IN FRAME, like the ring and the colossi. The
## top-down game reads a fall by what it does to the land: its light, thrown
## from where it is in the sky by a light of its own (and SkyLight's `flash`,
## which the rain turns pale by), and a mass's boom through the felt queue
## (src/core/sky/rumble.gd), with a shake as the shock goes over.
##
## Numbered after 21_doors and after the sky (10), so the air it reads is this
## frame's and its flash is laid over the lightning's before SkyLight composes.
##
## `--fall=off` takes the falls away for a run; `--fall=CLASS@AT[/B]` (AT an
## hour of the first day under 24, a world minute from 24) stages that one fall
## alone, its middle on bearing B (or, with no B, the bearing the view is turned
## to when it lights), crossing the view; several are joined with
## commas. A staged fall lights again whenever the clock is put back before its
## minute and comes up to it again. `:age=S` holds every fall S real seconds
## after it lit, for a frame of one moment of it; `:bench` measures what drawing
## them costs.

const Sched := preload("res://src/core/sky/fall_schedule.gd")
const Def := preload("res://src/core/orbit/orbit_def.gd")
const Rumble := preload("res://src/core/sky/rumble.gd")
const ViewScript := preload("res://src/render/falls/streak_view.gd")

## How much light a class throws on the land at REF_KM, and the most any sky of
## falls may throw (a mass overhead is a moment of hard dawn, never noon).
const LAND := {&"dust": 0.0, &"fragment": 0.06, &"mass": 0.32}
const LAND_MOST := 1.6
## The land's light falls off as the square of how far the fall is, from here,
## within this much of it.
const LAND_SPAN := Vector2(0.05, 6.0)
const LIGHT_COLOR := Color(0.86, 0.95, 1.0)
## A light this strong on the land is a flash a player sees (tour `fall_flash`).
const FLASH_SEEN := 0.35
## The shake a mass's shock gives as it goes over: strength (world units), real
## seconds, how slow.
const BOOM_SHAKE := Vector3(0.09, 3.2, 1.1)
## How long after its boom has come a tour may still say it was heard.
const BOOM_HEARD := 4.0

var def: RefCounted
var view: ViewScript
var rumble := Rumble.new()
## The live falls: {f, pieces, age (real s), node, mat, energy}.
var live: Array = []
var _last := NAN
var _stages: Array = []
## Falls lit this run (--stats; a tour asks the live sky, never this).
var lit_count := 0
var light: DirectionalLight3D
## The light on the land this frame, and SkyLight's flash share of it.
var land := 0.0
var since_boom := INF
var last_process_usec := 0
## Published on the group `&"colossi"` as 19_orbit's is, so the shoulder view
## (41_shoulder) may tip up past its ordinary limit to follow a fall burning
## high, knowing nothing of falls; `hum` is 0 (70_audio reads it off the group).
var gaze := 0.0
var hum := 0.0
## Degrees either side of the view's bearing a high fall may burn and still draw
## the gaze up, and the least elevation that needs the view tipped (19_orbit's).
const GAZE_WIDE := 50.0
const GAZE_FROM := 28.0


func setup(g: Game) -> void:
	super.setup(g)
	var spec: String = g.options.fall
	if spec == "off":
		set_process(false)
		return
	def = Def.ring()
	var now: float = g.clock.minutes if g.clock != null else 0.0
	for one: String in spec.get_slice(":", 0).split(",", false):
		var st := Sched.parse_stage(one)
		if st.is_empty():
			push_warning("--fall: no such fall '%s'" % one)
			continue
		var at: float = st.at
		var minute := at if at >= 24.0 else floorf(now / 1440.0) * 1440.0 + at * 60.0
		var bearing: float = st.bearing
		_stages.append({"f": Sched.staged(def, g.world.seed_value, st.kind, minute, 90.0 if is_nan(bearing) else bearing),
			"kind": st.kind, "bearing": bearing, "armed": true})
	view = ViewScript.new()
	view.name = "falls"
	add_child(view)
	light = DirectionalLight3D.new()
	light.name = "fall_light"
	light.shadow_enabled = false
	light.light_color = LIGHT_COLOR
	light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	light.visible = false
	add_child(light)
	add_to_group(&"colossi")
	if spec.contains(":bench"):
		_bench.call_deferred()
	if spec.contains(":age="):
		_bench_hold = spec.get_slice(":age=", 1).get_slice(":", 0).to_float()


func _process(delta: float) -> void:
	if view == null or game == null or game.sky == null:
		return
	var t0 := Time.get_ticks_usec()
	var m: float = game.clock.minutes if game.clock != null else 0.0
	_light_up(m)
	_last = m
	var i := 0
	while i < live.size():
		var e: Dictionary = live[i]
		if _bench_hold < 0.0:
			e.age = float(e.age) + delta
		else:
			e.age = _bench_hold
		if float(e.age) > Sched.life_secs(e.f):
			view.remove(e)
			live.remove_at(i)
			continue
		i += 1
	var cam := get_viewport().get_camera_3d()
	var air: Dictionary = game.sky.seen_air()
	var open: bool = game.sky.closed < 0.5 and SkyLight.last_lid() < 0.5
	view.update(cam, live, air, open and float(air.share) > 0.0 and not _held_off)
	_shine(air, open)
	_look(cam, open)
	_hear(delta)
	last_process_usec = Time.get_ticks_usec() - t0


## Whatever lit between last frame's minute and this one's: the schedule's, or
## the staged ones alone. A skip lights nothing and clears the sky.
func _light_up(m: float) -> void:
	if is_nan(_last):
		for s: Dictionary in _stages:
			if absf(m - float(s.f.minute)) < 0.5:
				_fire(s)
		return
	if m < _last or m - _last > Sched.SKIP:
		_clear()
		for s: Dictionary in _stages:
			if m < float(s.f.minute):
				s.armed = true
		return
	if not _stages.is_empty():
		for s: Dictionary in _stages:
			var at: float = s.f.minute
			if bool(s.armed) and at > _last and at <= m:
				_fire(s)
		return
	for f: Dictionary in Sched.between(def, game.world.seed_value, _last, m):
		_add(f)


## A staged fall with no bearing of its own lights on the bearing the view is
## turned to when it lights, so a frame need not know which way a camera faces.
func _fire(s: Dictionary) -> void:
	s.armed = false
	var f: Dictionary = (s.f as Dictionary).duplicate()
	var cam := get_viewport().get_camera_3d()
	if is_nan(float(s.bearing)) and cam != null:
		var fwd := -cam.global_transform.basis.z
		var b := fposmod(rad_to_deg(atan2(fwd.z, fwd.x)), 360.0)
		f = Sched.staged(def, game.world.seed_value, s.kind, float(f.minute), b)
	_add(f)


func _add(f: Dictionary) -> void:
	var e := {"f": f, "pieces": Sched.pieces_of(f), "age": 0.0}
	view.add(e)
	live.append(e)
	lit_count += 1
	if f.kind == &"mass":
		# Its boom from the nearest part of its flight low enough to carry one,
		# and the shake of the shock going over with it.
		var here := _player_at()
		var near := Sched.point(f, Sched.anchor_s(f)) * 1000.0
		var at := here + Vector3(near.x, 0.0, near.z)
		var d := near.length()
		rumble.send(Sched.boom_secs(f), &"fall_boom", at, d)


func _clear() -> void:
	for e: Dictionary in live:
		view.remove(e)
	live.clear()
	rumble.clear()


## THE LIGHT ON THE LAND: every fall's glow (FallSchedule.glow) at its class's
## strength, falling off as the square of how far off it is, thrown from where
## the brightest one is in the sky; mostly taken by cloud. SkyLight's `flash`
## takes the share of it a flash of lightning would (the rain goes pale by it).
func _shine(air: Dictionary, open: bool) -> void:
	land = 0.0
	var from := Vector3.UP
	var best := 0.0
	if open:
		for e: Dictionary in live:
			var f: Dictionary = e.f
			var at := Sched.light_at(f, e.pieces, float(e.age))
			var k: float = LAND[f.kind]
			if k <= 0.0 or at.y <= 0.0:
				continue
			var near := clampf(pow(ViewScript.REF_KM / maxf(at.length(), 1.0), 2.0), LAND_SPAN.x, LAND_SPAN.y)
			var g := k * Sched.glow(f, e.pieces, float(e.age)) * near
			land += g
			if g > best:
				best = g
				from = at.normalized()
	var dome: Dictionary = air.get("dome", {})
	land = minf(land, LAND_MOST) * (1.0 - float(dome.get(&"dome_cover", 0.0)) * 0.6)
	light.visible = land > 0.002
	light.light_energy = land * float(game.sky.trim.get("sun", 1.0))
	if light.visible:
		light.global_transform = Transform3D(Basis.looking_at(-from, Vector3.UP if absf(from.y) < 0.99 else Vector3.RIGHT), Vector3.ZERO)
	game.sky.flash = maxf(game.sky.flash, clampf(land / LAND_MOST, 0.0, 1.0) * 0.5)


## The gaze: a fall still burning, high enough that the ordinary limit would cut
## it off, near the way the view is turned.
func _look(cam: Camera3D, open: bool) -> void:
	gaze = 0.0
	if not open or cam == null:
		return
	var f3 := -cam.global_transform.basis.z
	var fwd := Vector2(f3.x, f3.z)
	for e: Dictionary in live:
		var f: Dictionary = e.f
		if Sched.glow(f, e.pieces, float(e.age)) <= 0.05:
			continue
		var d := Sched.light_at(f, e.pieces, float(e.age)).normalized()
		var el := rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))
		if el < GAZE_FROM:
			continue
		var off := 0.0
		var flat := Vector2(d.x, d.z)
		if el < 75.0 and fwd.length() > 1e-3 and flat.length() > 1e-3:
			off = rad_to_deg(absf(fwd.normalized().angle_to(flat.normalized())))
		gaze = maxf(gaze, smoothstep(GAZE_WIDE, GAZE_WIDE * 0.5, off) * smoothstep(GAZE_FROM, GAZE_FROM + 12.0, el))


func _hear(delta: float) -> void:
	since_boom += delta
	for c: Dictionary in rumble.arrive(delta):
		if c.what != &"fall_boom":
			continue
		since_boom = 0.0
		Events.sfx.emit(&"fall_boom", c.at)
		if game.camera != null:
			game.camera.quake(BOOM_SHAKE.x, BOOM_SHAKE.y, BOOM_SHAKE.z)


func _player_at() -> Vector3:
	var p: Vector2 = game.player.pos if game.player != null else Vector2.ZERO
	return Vector3(p.x, 0.0, p.y)


## The world under the player changed: the sky over it is the same sky, but
## nothing on its way from the old one is still coming.
func realm_changed(_from: StringName, _to: StringName) -> void:
	if view != null:
		_clear()


## WHAT THE FALLS COST (`--fall=CLASS@AT/B:bench`), the ring's bench method
## (19_orbit `_bench`): the staged fall held at BENCH_AGE seconds, its train out
## and its pieces burning, and whole frames drawn back to back with force_draw,
## BENCH_FRAMES at a time, the falls drawn and held off in turn, BENCH_ROUNDS
## times; the median of each arm's mean frame, and the difference.
const BENCH_ROUNDS := 7
const BENCH_FRAMES := 120
const BENCH_AGE := 5.5
var _bench_hold := -1.0
var _held_off := false


func _bench() -> void:
	for i in 60:
		await get_tree().process_frame
	_bench_hold = BENCH_AGE
	if live.is_empty():
		for s: Dictionary in _stages:
			_fire(s)
	for i in 30:
		await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var ms: Array = [[], []]
	for r in BENCH_ROUNDS:
		for arm in 2:
			_held_off = arm == 1
			for i in 4:
				await get_tree().process_frame
			RenderingServer.force_sync()
			var t0 := Time.get_ticks_usec()
			for i in BENCH_FRAMES:
				RenderingServer.force_draw(true, 0.0)
			RenderingServer.force_sync()
			(ms[arm] as Array).append((Time.get_ticks_usec() - t0) / 1000.0 / float(BENCH_FRAMES))
	_held_off = false
	var med: Array[float] = []
	for arm in 2:
		var a: Array = ms[arm]
		a.sort()
		med.append(float(a[a.size() / 2]))
	print("world falls bench (%s, quality %s, load %s): frame %.2f ms with %d falls drawn, %.2f held off; the falls cost %.2f ms a frame (rounds with %s, without %s); 21_falls main-thread %d us" % [
		"Forward+" if Quality.forward_plus() else "Compatibility", Quality.current_id(), str(OS.get_environment("UNSPENT_LOAD")),
		med[0], live.size(), med[1], med[0] - med[1], str(ms[0]), str(ms[1]), last_process_usec])
	print("world falls bench: %s" % stats_line().strip_edges())


## For `--stats`: what is in the sky and what is on its way.
func stats_line() -> String:
	if view == null:
		return "\nworld falls: off"
	var out := "\nworld falls: %d live, %d drawn, %d lit this run, land light %.3f, %d on their way, %d us" % [
		live.size(), view.drawn, lit_count, land, rumble.size(), last_process_usec]
	for e: Dictionary in live:
		var f: Dictionary = e.f
		var at := Sched.point(f, Sched.anchor_s(f))
		out += "\nworld fall %d: %s at %.1f s of %.1f, %.0f km off at bearing %.0f, %.0f deg up, head %.2f flash %.2f" % [
			int(f.id), f.kind, float(e.age), Sched.life_secs(f), at.length(), fposmod(rad_to_deg(atan2(at.z, at.x)), 360.0),
			rad_to_deg(asin(at.normalized().y)), Sched.head_level(f, float(e.age)), Sched.flash_level(f, float(e.age))]
	return out


## A tour asks the LIVE sky, never a latch:
##   fall          a fall's head is burning on the glass now
##   fall_breakup  a breakup is flashing now
##   fall_train    a train hangs in the sky after its fall has gone out
##   fall_flash    a fall is lighting the land now, strongly enough to see
##   fall_coming   a boom is on its way
##   fall_boom     a boom arrived in the last BOOM_HEARD seconds
func tour_seen(what: StringName) -> bool:
	if view == null:
		return false
	var drawn := view.drawn > 0
	match what:
		&"fall":
			for e: Dictionary in live:
				if Sched.glow(e.f, e.pieces, float(e.age)) - Sched.flash_level(e.f, float(e.age)) > 0.05:
					return drawn
			return false
		&"fall_breakup":
			for e: Dictionary in live:
				if Sched.flash_level(e.f, float(e.age)) > 0.5:
					return drawn
			return false
		&"fall_train":
			for e: Dictionary in live:
				var f: Dictionary = e.f
				if int(f.pieces) > 0 and float(e.age) > float(f.secs) + 2.0:
					return drawn
			return false
		&"fall_flash":
			return land > FLASH_SEEN
		&"fall_coming":
			return rumble.size() > 0
		&"fall_boom":
			return since_boom < BOOM_HEARD
	return false
