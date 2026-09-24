extends GameSystem
## THE RING IN THE SKY (src/core/orbit/, the drawing in src/render/orbit/): a
## fractured platform four hundred kilometres up, going over in PASSES.
##
## This owns none of the drawing. Every frame it poses the ring off the world
## clock (OrbitPass.pose, pure), hands its layer the eye camera, the real sun and
## the sky's own air, and tells the seen sky (sky_eye.gdshader, `DOME_ORBIT`)
## where on its glass the layer lands -- or that it is not to be read at all.
##
## SEEN ONLY WHILE THE HORIZON IS IN FRAME, like the colossi: the play camera
## looks down at the ground, the layer stands down and the orthographic game pays
## one comparison. Under a roof or a lid of smog there is no sky to see it in.
##
## Numbered after 19_colossi, which it stands beside, and after the sky (10), so
## the air it reads is this frame's.
##
## It publishes a `gaze` on the group `&"colossi"` exactly as 19_colossi does, so
## the shoulder view (41_shoulder, Shoulder.GAZE_LEAST) may tip up to take in a
## ring passing high without knowing anything about rings; its `hum` is 0.
##
## `--orbit=off` takes it away for a run; `--orbit=zenith@H` stages a pass whose
## peak stands overhead at hour H of the first day (or world minute H, 24 and
## up), alone.

const Def := preload("res://src/core/orbit/orbit_def.gd")
const Pass := preload("res://src/core/orbit/orbit_pass.gd")
const LayerScript := preload("res://src/render/orbit/orbit_layer.gd")

## Degrees either side of the view's bearing a high pass may stand and still
## draw the gaze up to it; and the least elevation that needs the view tipped.
const GAZE_WIDE := 50.0
const GAZE_FROM := 28.0
## The ring by day (`frame_probe`): at least PALE_LEAST hull pixels, lighter
## than the sky beside them by PALE_LIFT on the whole, and no more than
## PALE_DARK_MOST of them darker by DARKER (about four levels of eight bits):
## the sails, the scorch and the window rows are dark on purpose (a noon frame
## measured 15%), and a hull drawn as a silhouette is nearly all of it.
const PALE_LEAST := 300
const PALE_LIFT := 0.01
const PALE_DARK_MOST := 0.25
const DARKER := 0.016
## How much of the night sky's glow the hull stands in front of (orbit_sky's
## `orbit_mass`): enough that an eclipsed wheel reads as a darker ring.
const MASS_AT_NIGHT := 0.35

var def: RefCounted
var layer: LayerScript
var pose: Dictionary = {}
var _staged: Dictionary = {}
## Read by 41_shoulder and 70_audio off the group, as 19_colossi's are.
var gaze := 0.0
var hum := 0.0
## How sunlit the ring's centre is this frame (OrbitPass.sunlit), 0..1.
var lit := 0.0
var last_pose_usec := 0


func setup(g: Game) -> void:
	super.setup(g)
	var spec: String = g.options.orbit
	if spec == "off":
		set_process(false)
		SkyLight.orbit_shade = 0.0
		return
	def = Def.ring()
	var proof := spec.begins_with("proof")
	if spec.contains("@"):
		var tail := spec.split("@")[1]
		var at := tail.to_float()
		var now: float = g.clock.minutes if g.clock != null else 0.0
		var peak := at if at >= 24.0 else floorf(now / 1440.0) * 1440.0 + at * 60.0
		# "/B": the bearing it rises at, so a frame can be staged in front of a
		# camera whose bearing is fixed (the shoulder view's).
		var head := Pass.heading(g.world.seed_value)
		if tail.contains("/"):
			head = tail.split("/")[1].to_float() + 180.0
		_staged = Pass.make_pass(def, 0, peak - Pass.window_min(def) * 0.5, float(def.peak_most) + 1.5, head, 1.0)
	layer = LayerScript.new()
	layer.name = "orbit"
	add_child(layer)
	layer.setup(def, g.world.seed_value, proof)
	add_to_group(&"colossi")
	if spec.ends_with(":ab"):
		_ab.call_deferred()


func _process(_delta: float) -> void:
	if layer == null or game == null or game.sky == null:
		return
	var cam := get_viewport().get_camera_3d()
	var air: Dictionary = game.sky.seen_air()
	var open: bool = game.sky.closed < 0.5 and SkyLight.last_lid() < 0.5
	var m: float = game.clock.minutes if game.clock != null else 0.0
	var t0 := Time.get_ticks_usec()
	var t_all := t0
	pose = Pass.pose(def, game.world.seed_value, m, _staged if not _staged.is_empty() else _pass_for(m))
	pose["minutes"] = m
	last_pose_usec = Time.get_ticks_usec() - t0
	var h: float = game.sky.clock_hour
	var sun := SkyLight.sky_sun(h, float(SkyLight.sun_at(h).azimuth))
	lit = Pass.sunlit(def, (pose.rel as Vector3) - (pose.earth as Vector3), sun)
	var on := layer.update(cam, pose, sun, air, open and float(air.share) > 0.0 and not _held_off)
	_tell_sky(cam, on, air)
	_wake(cam, sun, air, open and float(air.share) > 0.0 and not _held_off)
	_shine(sun, air, open)
	_look(cam, open)
	last_process_usec = Time.get_ticks_usec() - t_all


## What this system's own frame cost on the main thread, all of it (--stats, A/B).
var last_process_usec := 0
## The pass in hand, kept: a pass is built with its whole sky-arc table, and the
## same pass holds for thirty-three world hours.
var _pass: Dictionary = {}


func _pass_for(m: float) -> Dictionary:
	if _pass.is_empty() or m < float(_pass.rise) - Pass.period_min(def) or m > float(_pass.set):
		_pass = Pass.next_pass(def, game.world.seed_value, m)
	return _pass


## WHAT THE RING COSTS, measured in the running game (`--orbit=zenith@H:ab`):
## the same view with the layer rendering and held off, alternated AB_ROUNDS
## times with vsync off, the median frame interval of each, and the layer's own
## render CPU and GPU where the renderer answers (on this machine the GPU half
## answers zero, and says so). A number measured on one side only is a guess
## about the other, so both sides are the same process, the same frame and the
## same load, a second apart.
const AB_ROUNDS := 10
const AB_SECS := 1.0
var _held_off := false


func _ab() -> void:
	for i in 90:
		await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rid := layer.viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var on_ms: Array[float] = []
	var off_ms: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var mem_on := 0.0
	var mem_off := 0.0
	for r in AB_ROUNDS:
		for off: bool in [false, true]:
			_held_off = off
			for i in 10:
				await RenderingServer.frame_post_draw
			var frames: Array[float] = []
			var until := Time.get_ticks_msec() + int(AB_SECS * 1000.0)
			var last := Time.get_ticks_usec()
			while Time.get_ticks_msec() < until:
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				frames.append((now - last) / 1000.0)
				last = now
				if not off:
					cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
					gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			frames.sort()
			(off_ms if off else on_ms).append(frames[frames.size() / 2])
			var mem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
			if off:
				mem_off = mem
			else:
				mem_on = mem
	_held_off = false
	# Each round's ON beside the OFF that followed it a second later: the paired
	# differences' median is the cost, which a load that drifts over the run
	# cannot move the way it moves either side alone.
	var diffs: Array[float] = []
	for i in mini(on_ms.size(), off_ms.size()):
		diffs.append(on_ms[i] - off_ms[i])
	diffs.sort()
	on_ms.sort()
	off_ms.sort()
	cpu.sort()
	gpu.sort()
	var g := gpu[gpu.size() / 2] if not gpu.is_empty() else 0.0
	print("world orbit ab: the ring costs %.2f ms a frame (median of %d paired rounds, %.2f .. %.2f); 19_orbit's own main-thread work %d us" % [diffs[diffs.size() / 2], diffs.size(), diffs[0], diffs[diffs.size() - 1], last_process_usec])
	print("world orbit ab (%s, quality %s, load %s): frame %.2f ms with the ring, %.2f ms held off (median of %d rounds), layer render cpu %.3f ms, gpu %s, video memory %.1f MB with / %.1f MB held off (the target stays allocated)" % [
		"Forward+" if Quality.forward_plus() else "Compatibility", Quality.current_id(),
		str(OS.get_environment("UNSPENT_LOAD")), on_ms[on_ms.size() / 2], off_ms[off_ms.size() / 2], AB_ROUNDS,
		cpu[cpu.size() / 2] if not cpu.is_empty() else 0.0, ("%.3f ms" % g) if g > 0.0 else "UNMEASURED", mem_on, mem_off])
	print("world orbit ab: %s" % stats_line().strip_edges())


## THE WAKE (orbit_sky.gdshaderinc `orbit_wake_at`): the shards strung along
## the orbit, drawn as the arc of THIS pass across the sky -- the one up, or the
## next to rise -- with how sunlit the orbit is at each point. Shown only against
## a sky dark enough for a point to show (the same rule as the ring's lamps).
var wake_shown := 0.0


func _wake(cam: Camera3D, sun: Vector3, air: Dictionary, seen: bool) -> void:
	var e: Environment = game.sky.env.environment if game.sky.env != null else null
	if e == null or e.sky == null or not (e.sky.sky_material is ShaderMaterial):
		return
	var m := e.sky.sky_material as ShaderMaterial
	var dome: Dictionary = air.get("dome", {})
	wake_shown = LayerScript.lamp_seen(dome.get(&"dome_top_color", Color(0.3, 0.4, 0.6))) if seen and cam != null else 0.0
	m.set_shader_parameter(&"orbit_wake_on", wake_shown * WAKE_BRIGHT)
	if wake_shown <= 0.0:
		return
	var p: Dictionary = pose.pass
	var pts: Array[Vector4] = []
	var n := Vector3.ZERO
	var first := Vector3.ZERO
	for i in WAKE_POINTS:
		# Even in SKY ANGLE (OrbitPass.theta_of), not round the planet: the sky
		# finds its segment by angle, and the shards are dealt along it evenly.
		var th := Pass.theta_of(p, float(i) / float(WAKE_POINTS - 1))
		var rel := Pass.rel_at(def, p, th)
		var d := rel.normalized()
		if i == 0:
			first = d
		pts.append(Vector4(d.x, d.y, d.z, Pass.sunlit(def, rel - (pose.earth as Vector3), sun)))
	var last := Vector3(pts[WAKE_POINTS - 1].x, pts[WAKE_POINTS - 1].y, pts[WAKE_POINTS - 1].z)
	var mid := Vector3(pts[WAKE_POINTS / 2].x, pts[WAKE_POINTS / 2].y, pts[WAKE_POINTS / 2].z)
	n = (first - mid).cross(last - mid).normalized()
	var stray := 0.0
	for q: Vector4 in pts:
		stray = maxf(stray, absf(Vector3(q.x, q.y, q.z).dot(n)))
	m.set_shader_parameter(&"orbit_wake", pts)
	m.set_shader_parameter(&"orbit_wake_plane", Vector4(n.x, n.y, n.z, stray + 0.03))
	m.set_shader_parameter(&"orbit_wake_arc", float(p.arc))
	# The angles round the arc's own axis are measured from its MIDDLE point, so
	# neither end can wrap past a half turn whatever the arc's shape.
	var e1 := (mid - n * mid.dot(n)).normalized()
	var e2 := n.cross(e1)
	var a0 := atan2(first.dot(e2), first.dot(e1))
	var a1 := atan2(last.dot(e2), last.dot(e1))
	if a1 < a0:
		e2 = -e2
		a0 = -a0
		a1 = -a1
	m.set_shader_parameter(&"orbit_wake_e1", e1)
	m.set_shader_parameter(&"orbit_wake_e2", e2)
	m.set_shader_parameter(&"orbit_wake_span", Vector2(a0, a1))
	var rows := float(layer.screen.y)
	m.set_shader_parameter(&"orbit_px", 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / rows)


const WAKE_POINTS := 17
const WAKE_BRIGHT := 1.0


## RINGSHINE: a cold second fill on the land from the ring's bearing, the way
## a moon lights a night, CAPPED at RINGSHINE_MOST of the moon's own light so a
## night stays really dark (docs/LOOK.md law 2), and it goes out at eclipse --
## the land darkens a step as the Earth's shadow reaches the wheel. It is sunlit
## plate four hundred kilometres up: brightest overhead, less near the horizon,
## nothing by day. A DirectionalLight3D of its own, casting nothing.
##
## And the transit: when the hull crosses the sun as seen from here, the sun's
## light on the land is taken down by as much of its disc as is covered
## (`SkyLight.orbit_shade`, which SkyLight spends on the sun alone).
const RINGSHINE_MOST := 1.5
const RINGSHINE_COLOR := Color(0.70, 0.80, 1.0)
var ringshine: DirectionalLight3D
var shine := 0.0
var shade := 0.0


## How much of the capped ringshine falls, 0..1: as sunlit as the wheel is, as
## far as night has fallen, as near as it is (the square of overhead distance
## over its distance: a smaller wheel is less sky), faded at the horizon, and
## mostly taken by cloud.
static func shine_of(sunlit: float, night: float, near_share: float, up: float, cover: float) -> float:
	var n := clampf(near_share, 0.0, 1.0)
	return clampf(sunlit, 0.0, 1.0) * clampf(night, 0.0, 1.0) * n * n * smoothstep(0.0, 0.12, up) \
		* (1.0 - clampf(cover, 0.0, 1.0) * 0.8)


## The ringshine light's energy for a share: never more than RINGSHINE_MOST moons.
static func ringshine_energy(share: float) -> float:
	return SkyLight.MOON_NIGHT * RINGSHINE_MOST * clampf(share, 0.0, 1.0)


func _shine(sun: Vector3, air: Dictionary, open: bool) -> void:
	if ringshine == null:
		ringshine = DirectionalLight3D.new()
		ringshine.name = "ringshine"
		ringshine.shadow_enabled = false
		ringshine.light_color = RINGSHINE_COLOR
		ringshine.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		add_child(ringshine)
	var dome: Dictionary = air.get("dome", {})
	var night: float = float(dome.get(&"dome_night", SkyLight.night_dark(game.sky.clock_hour)))
	shine = 0.0
	shade = 0.0
	if open and bool(pose.get("up", false)):
		shine = shine_of(lit, night, float(def.altitude_km) / float(pose.dist), (pose.dir as Vector3).y, float(dome.get(&"dome_cover", 0.0)))
		shade = Pass.sun_cover(def, pose, sun)
	var trim: float = float(game.sky.trim.get("sun", 1.0))
	ringshine.light_energy = ringshine_energy(shine) * trim
	ringshine.visible = ringshine.light_energy > 0.001
	if ringshine.visible:
		var d: Vector3 = pose.dir
		ringshine.global_transform = Transform3D(Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT), Vector3.ZERO)
	SkyLight.orbit_shade = shade


## The seen sky's half of the bargain: where the layer lands and whether to read
## it. Only the seen sky knows `DOME_ORBIT`; the procedural sky has no such
## uniform and is never touched.
func _tell_sky(cam: Camera3D, on: bool, air: Dictionary) -> void:
	var e: Environment = game.sky.env.environment if game.sky.env != null else null
	if e == null or e.sky == null or not (e.sky.sky_material is ShaderMaterial):
		return
	var m := e.sky.sky_material as ShaderMaterial
	m.set_shader_parameter(&"orbit_on", 1.0 if on else 0.0)
	if not on:
		return
	var sz := Vector2(layer.screen)
	var t := LayerScript.tan_of(cam.fov, sz.x / sz.y)
	m.set_shader_parameter(&"orbit_rect", layer.rect)
	m.set_shader_parameter(&"orbit_layer", layer.viewport.get_texture())
	m.set_shader_parameter(&"orbit_view", layer.camera.global_transform.basis.transposed())
	m.set_shader_parameter(&"orbit_tan", t)
	m.set_shader_parameter(&"orbit_gain", layer.gain)
	var night: float = float((air.get("dome", {}) as Dictionary).get(&"dome_night", 0.0))
	m.set_shader_parameter(&"orbit_mass", MASS_AT_NIGHT * night)
	m.set_shader_parameter(&"orbit_thick", float(air.get("thick", 0.0)))


## Which way the view is turned, for the gaze: only a pass standing high enough
## that the ordinary limit would cut it off.
func _look(cam: Camera3D, open: bool) -> void:
	gaze = 0.0
	if not open or cam == null or not bool(pose.get("up", false)):
		return
	var el: float = pose.elevation
	if el < GAZE_FROM:
		return
	var f := -cam.global_transform.basis.z
	var fwd := Vector2(f.x, f.z)
	var d: Vector3 = pose.dir
	var flat := Vector2(d.x, d.z)
	var off := 0.0
	if el < 75.0 and fwd.length() > 1e-3 and flat.length() > 1e-3:
		off = rad_to_deg(absf(fwd.normalized().angle_to(flat.normalized())))
	gaze = smoothstep(GAZE_WIDE, GAZE_WIDE * 0.5, off) * smoothstep(GAZE_FROM, GAZE_FROM + 12.0, el)


## For `--stats`: where the ring stands, whether its layer rendered and what
## posing it cost -- the numbers a frame is staged by and a budget argued from.
func stats_line() -> String:
	if layer == null:
		return "\nworld orbit: off"
	var p: Dictionary = pose
	if p.is_empty():
		return "\nworld orbit: not posed"
	var probe := ""
	var fp := frame_probe()
	if not fp.is_empty():
		probe = ", on the glass: hull %+.4f over the sky beside it, %.1f%% of it darker, over %d px" % [float(fp.lift), float(fp.dark) * 100.0, int(fp.n)]
	var rid := layer.viewport.get_viewport_rid()
	probe += ", layer %d draws %d tris, target %dx%d over frame rect %s, lamps shown %.2f" % [
		RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		layer.viewport.size.x, layer.viewport.size.y, str(layer.frame_rect), layer.lamps_shown]
	var nxt: Dictionary = Pass.next_pass(def, game.world.seed_value, float(p.minutes)) if _staged.is_empty() else _staged
	return "\nworld orbit: %s, lod %d, %.0f px across, pose %d us, %s at %.0f deg up bearing %.0f, %.0f km, sunlit %.2f, gaze %.2f, pass %d peaks %.0f deg, rises at minute %.0f (hour %.1f)" % [
		"drawn" if layer.drawn else "not drawn", layer.lod, layer.px_across, last_pose_usec,
		"up" if bool(p.up) else "down", float(p.elevation), float(p.bearing), float(p.dist), lit, gaze,
		int(nxt.k), float(nxt.peak_el), float(nxt.rise), fposmod(float(nxt.rise) / 60.0, 24.0)] + probe


## THE RING BY DAY, read off the live pictures -- the layer's (what the ring IS
## on each pixel) and the finished frame's (what the sky made of it) -- over
## every whole hull pixel, against the open sky nearest it along the row:
##   lift     the mean of (hull - sky) in luminance: by day the hull is PALE, a
##            mass lit from below by the sunlit planet and from above by the sun,
##            the way the daytime moon is a pale thing and never a hole
##   dark     the share of hull pixels darker than the sky beside them by more
##            than DARKER: a hull drawn as a silhouette is most of them
##   n        how many hull pixels that was asked over
## Empty when the layer did not render. It reads two textures back from the
## GPU, so it is for a tour's question and --stats, never a frame's work.
func frame_probe() -> Dictionary:
	if layer == null or not layer.drawn:
		return {}
	var li := layer.viewport.get_texture().get_image()
	var fi := get_viewport().get_texture().get_image()
	if li == null or fi == null:
		return {}
	var lsz := li.get_size()
	var map := _mapping(lsz, fi.get_size(), layer.frame_rect)
	var lift := 0.0
	var darker := 0
	var n := 0
	for y in range(0, lsz.y):
		for x in range(0, lsz.x):
			var l := li.get_pixel(x, y)
			if l.a < 0.95:
				continue
			var lum := fi.get_pixelv(_frame_px(map, x, y)).get_luminance()
			# The open sky nearest along the row, either side.
			for step in range(3, 20):
				var hit := false
				for sx: int in [x - step, x + step]:
					if sx < 0 or sx >= lsz.x or li.get_pixel(sx, y).a > 0.02:
						continue
					var d := lum - fi.get_pixelv(_frame_px(map, sx, y)).get_luminance()
					lift += d
					darker += 1 if d < -DARKER else 0
					n += 1
					hit = true
					break
				if hit:
					break
	return {"lift": lift / float(maxi(n, 1)), "dark": float(darker) / float(maxi(n, 1)), "n": n}


## A layer pixel to the frame pixel it lands on: the layer covers `rect` of the
## 3D frame (layer.screen), which the readback holds at its own size.
func _mapping(lsz: Vector2i, fsz: Vector2i, rect: Rect2i) -> Array:
	var to_frame := Vector2(fsz) / Vector2(layer.screen)
	return [Vector2(rect.position) * to_frame, Vector2(rect.size) / Vector2(lsz) * to_frame, fsz]


func _frame_px(map: Array, x: int, y: int) -> Vector2i:
	var fsz: Vector2i = map[2]
	var p := Vector2i((map[0] as Vector2) + Vector2(x + 0.5, y + 0.5) * (map[1] as Vector2))
	return p.clamp(Vector2i(3, 3), fsz - Vector2i(4, 4))


## THE STARS GO OUT BEHIND THE HULL, asked of the SAME PIXELS in two frames a
## few frames apart: one with the ring, and one with the ring's layer held off
## (as the cost A/B holds it), with the world, the clock and the camera where
## they were. The dark hull's pixels are taken from the first; the stars on them
## are counted in both. True when they show without the ring and not with it.
## Asking the same pixels in two different skies -- two patches, or one patch
## before and after the pass moved on -- could not tell a hull that hides the
## stars from one they are drawn straight through: the field is sparse, the
## plaque on the slate fades over the top of the frame, and the frame's bloom
## spreads the ring's own lamps over its dark plate (all three measured).
const STARS_LEAST := 12
## Measured: as built, 72 on the hull with the ring against 488 without (0.15,
## the ring's own glow in the frame's bloom); with the stars drawn through the
## hull, 1587 against 1339.
const STARS_HID := 0.3
## Frames the held-off look waits for the sky to be drawn without the ring.
const STAR_HOLD_FRAMES := 4
## Shares of the frame's height the slate draws over the sky, top and bottom.
const HUD_TOP := 0.14
const HUD_BOTTOM := 0.1
var _star_then: Dictionary = {}
## Stars seen on the dark hull's pixels (with the ring, without), summed since
## the tour last asked.
var last_star_count := Vector2i(-1, -1)
var _stars_total := Vector2i.ZERO


## A tour's answered question is spent (98_tour): the sum starts again.
func tour_forget(what: StringName) -> void:
	if what == &"ring_hides_stars":
		_stars_total = Vector2i.ZERO
		_star_then = {}
		_held_off = false


func _stars_come_out() -> bool:
	if layer == null:
		return false
	if _star_then.is_empty():
		if not layer.drawn:
			return false
		RenderingServer.force_draw()
		var li := layer.viewport.get_texture().get_image()
		var fi := get_viewport().get_texture().get_image()
		if li == null or fi == null:
			return false
		_star_then = {"frame_no": Engine.get_process_frames(), "layer": li, "frame": fi, "rect": layer.frame_rect}
		_held_off = true
		return false
	if Engine.get_process_frames() - int(_star_then.frame_no) < STAR_HOLD_FRAMES:
		return false
	# A tool run's window is off the screen, and the root is not drawn again
	# unless something asks: ask, so this is the frame with the ring held off.
	RenderingServer.force_draw()
	var bare := get_viewport().get_texture().get_image()
	_held_off = false
	var li: Image = _star_then.layer
	var with_ring: Image = _star_then.frame
	var rect: Rect2i = _star_then.rect
	_star_then = {}
	if bare == null:
		return false
	var fsz := bare.get_size()
	var map := _mapping(li.get_size(), fsz, rect)
	var lit := _lit_cells(li)
	var reach := int(ceilf(3.0 * float(li.get_width()) / float(rect.size.x))) + 1
	var hidden := 0
	var shown := 0
	for y in range(reach, li.get_height() - reach):
		for x in range(reach, li.get_width() - reach):
			var c := li.get_pixel(x, y)
			if c.a < 0.95 or c.r + c.g + c.b > 0.03 or lit.has(Vector2i(x / LIT_CELL, y / LIT_CELL)):
				continue
			var round_dark := true
			for o: Vector2i in [Vector2i(-reach, 0), Vector2i(reach, 0), Vector2i(0, -reach), Vector2i(0, reach)]:
				var n := li.get_pixelv(Vector2i(x, y) + o)
				if n.a < 0.95:
					round_dark = false
					break
			if not round_dark:
				continue
			var fp := _frame_px(map, x, y)
			if float(fp.y) < float(fsz.y) * HUD_TOP or float(fp.y) > float(fsz.y) * (1.0 - HUD_BOTTOM):
				continue
			hidden += 1 if _spike(with_ring, fp) else 0
			shown += 1 if _spike(bare, fp) else 0
	# Summed over every ask since the tour last asked: the hull covers only a
	# few stars at a time (it is a thirtieth of a steradian, and the dome holds
	# about 126 stars a steradian), so one look is too few to tell anything.
	_stars_total += Vector2i(hidden, shown)
	last_star_count = _stars_total
	return _stars_total.y >= STARS_LEAST and float(_stars_total.x) <= float(_stars_total.y) * STARS_HID


## THE RING'S OWN LIGHT, in cells of LIT_CELL layer pixels: every cell holding a
## lit pixel of the layer (a lamp, an ember, a lit plate) and the cells round
## it. The frame's bloom spreads a lamp several pixels over the dark hull beside
## it, and a spike there is the ring shining, not a star showing through it
## (measured: 140 "stars" on the dark hull of an eclipsed frame, every one of
## them in a lamp's glow).
const LIT_CELL := 8


static func _lit_cells(img: Image) -> Dictionary:
	var out := {}
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.05:
				var k := Vector2i(x / LIT_CELL, y / LIT_CELL)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						out[k + Vector2i(dx, dy)] = true
	return out


## A star: a spot two or three pixels across, brighter than its surround asked
## three pixels out, past its own glow.
static func _spike(img: Image, p: Vector2i) -> bool:
	var around := 0.0
	for o: Vector2i in [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(0, 3)]:
		around += img.get_pixelv(p + o).get_luminance()
	return img.get_pixelv(p).get_luminance() - around * 0.25 > 0.035


## A tour asks the LIVE layer, never a latch.
func tour_seen(what: StringName) -> bool:
	if layer == null:
		return false
	match what:
		&"ring":
			return layer.drawn
		&"ring_up":
			return bool(pose.get("up", false))
		&"ring_lit":
			return layer.drawn and lit > 0.5
		&"ringshine":
			return shine > 0.2
		&"ring_transit":
			return shade > 0.05
		&"wake":
			return wake_shown > 0.5
		&"ring_eclipsed":
			return layer.drawn and lit < 0.05
		&"ring_pale":
			# By day the hull is a pale mass: lighter than the sky beside it on
			# the whole, and almost nowhere darker.
			var p := frame_probe()
			return not p.is_empty() and int(p.n) >= PALE_LEAST and float(p.lift) > PALE_LIFT and float(p.dark) < PALE_DARK_MOST
		&"ring_hides_stars":
			return _stars_come_out()
	return false
