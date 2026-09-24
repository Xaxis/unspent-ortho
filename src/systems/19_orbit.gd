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
## The daytime ghost (`frame_probe`): at least this many unlit hull pixels, no
## further than this in luminance from the open sky beside them (about four
## levels of eight bits: a hull drawn as a silhouette is tens).
const GHOST_LEAST := 300
## How much of the night sky's glow the hull stands in front of (orbit_sky's
## `orbit_mass`): enough that an eclipsed wheel reads as a darker ring.
const MASS_AT_NIGHT := 0.35
const GHOST_MOST := 0.016

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
		return
	def = Def.ring()
	var proof := spec.begins_with("proof")
	if spec.contains("@"):
		var at := spec.split("@")[1].to_float()
		var now: float = g.clock.minutes if g.clock != null else 0.0
		var peak := at if at >= 24.0 else floorf(now / 1440.0) * 1440.0 + at * 60.0
		_staged = Pass.make_pass(def, 0, peak - Pass.window_min(def) * 0.5, float(def.peak_most) + 1.5,
			Pass.heading(g.world.seed_value), 1.0)
	layer = LayerScript.new()
	layer.name = "orbit"
	add_child(layer)
	layer.setup(def, g.world.seed_value, proof)
	add_to_group(&"colossi")


func _process(_delta: float) -> void:
	if layer == null or game == null or game.sky == null:
		return
	var cam := get_viewport().get_camera_3d()
	var air: Dictionary = game.sky.seen_air()
	var open: bool = game.sky.closed < 0.5 and SkyLight.last_lid() < 0.5
	var m: float = game.clock.minutes if game.clock != null else 0.0
	var t0 := Time.get_ticks_usec()
	pose = Pass.pose(def, game.world.seed_value, m, _staged)
	pose["minutes"] = m
	last_pose_usec = Time.get_ticks_usec() - t0
	var h: float = game.sky.clock_hour
	var sun := SkyLight.sky_sun(h, float(SkyLight.sun_at(h).azimuth))
	lit = Pass.sunlit(def, (pose.rel as Vector3) - (pose.earth as Vector3), sun)
	var on := layer.update(cam, pose, sun, air, open and float(air.share) > 0.0)
	_tell_sky(cam, on, air)
	_look(cam, open)


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
	var sz := Vector2(layer.viewport.size)
	var t := LayerScript.tan_of(cam.fov, sz.x / sz.y)
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
		probe = ", on the glass: unlit hull %.4f from the sky beside it over %d px" % [float(fp.ghost), int(fp.ghost_n)]
	var nxt: Dictionary = Pass.next_pass(def, game.world.seed_value, float(p.minutes)) if _staged.is_empty() else _staged
	return "\nworld orbit: %s, lod %d, %.0f px across, pose %d us, %s at %.0f deg up bearing %.0f, %.0f km, sunlit %.2f, gaze %.2f, pass %d peaks %.0f deg, rises at minute %.0f (hour %.1f)" % [
		"drawn" if layer.drawn else "not drawn", layer.lod, layer.px_across, last_pose_usec,
		"up" if bool(p.up) else "down", float(p.elevation), float(p.bearing), float(p.dist), lit, gaze,
		int(nxt.k), float(nxt.peak_el), float(nxt.rise), fposmod(float(nxt.rise) / 60.0, 24.0)] + probe


## THE DAYTIME GHOST, read off the live pictures -- the layer's (what the ring
## IS on each pixel) and the finished frame's (what the sky made of it):
##   ghost    the mean difference in luminance between the UNLIT hull and the
##            open sky a few pixels beside it along the row (by day the hull is
##            the sky's own colour, a ghost of a wheel like the daytime moon)
##   ghost_n  how many unlit hull pixels that was asked over
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
	var fsz := fi.get_size()
	var k := Vector2(fsz) / Vector2(lsz)
	var uv := layer.uv_for(pose.dir)
	var c := Vector2i(uv * Vector2(lsz))
	var r := int(layer.px_across * 0.5 * float(lsz.y) / float(layer.viewport.size.y)) + 12
	var lo := (c - Vector2i(r, r)).clamp(Vector2i(2, 2), lsz - Vector2i(3, 3))
	var hi := (c + Vector2i(r, r)).clamp(Vector2i(2, 2), lsz - Vector2i(3, 3))
	var ghost := 0.0
	var ghost_n := 0
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var l := li.get_pixel(x, y)
			if l.a < 0.95 or l.r + l.g + l.b > 0.03:
				continue
			var lum := fi.get_pixelv(Vector2i(Vector2(x + 0.5, y + 0.5) * k)).get_luminance()
			# The open sky nearest along the row, either side.
			for step in range(3, 14):
				var hit := false
				for sx: int in [x - step, x + step]:
					if sx < 0 or sx >= lsz.x or li.get_pixel(sx, y).a > 0.02:
						continue
					ghost += absf(lum - fi.get_pixelv(Vector2i(Vector2(sx + 0.5, y + 0.5) * k)).get_luminance())
					ghost_n += 1
					hit = true
					break
				if hit:
					break
	return {"ghost": ghost / float(maxi(ghost_n, 1)), "ghost_n": ghost_n}


## THE STARS GO OUT BEHIND THE HULL, asked of the SAME PIXELS twice: the dark
## hull's pixels are remembered with the frame they were in, and once the pass
## has carried the ring off them (STAR_WAIT_MS later, a hundred-odd pixels at
## the pace) the same pixels are asked again, now open sky. The star field is
## fixed on the dome, so whatever stars those pixels hold now they held then:
## true when they show now and did not then. A count over two different patches
## of sky could not say that -- a field this sparse leaves a band of hull empty
## by chance about as often as not, and it certified a sky with the stars drawn
## straight through the hull (measured). Asked by a tour; the camera must hold
## still between the two looks.
const STAR_WAIT_MS := 4000
var _star_then: Dictionary = {}
## Stars seen on the same pixels (hull then, sky now) by the last ask.
var last_star_count := Vector2i(-1, -1)


func _stars_come_out() -> bool:
	if layer == null or not layer.drawn:
		return false
	var now_ms := Time.get_ticks_msec()
	if not _star_then.is_empty() and now_ms - int(_star_then.ms) < STAR_WAIT_MS:
		return false
	var li := layer.viewport.get_texture().get_image()
	var fi := get_viewport().get_texture().get_image()
	if li == null or fi == null:
		return false
	if _star_then.is_empty():
		_star_then = {"ms": now_ms, "layer": li, "frame": fi}
		return false
	var old_l: Image = _star_then.layer
	var old_f: Image = _star_then.frame
	_star_then = {}
	var lsz := li.get_size()
	var fsz := fi.get_size()
	var k := Vector2(fsz) / Vector2(lsz)
	var then := 0
	var now := 0
	for y in range(3, lsz.y - 3):
		for x in range(3, lsz.x - 3):
			var was := old_l.get_pixel(x, y)
			if was.a < 0.95 or was.r + was.g + was.b > 0.03:
				continue
			if li.get_pixel(x, y).a > 0.0 or li.get_pixel(x - 2, y).a > 0.0 or li.get_pixel(x + 2, y).a > 0.0 or li.get_pixel(x, y - 2).a > 0.0 or li.get_pixel(x, y + 2).a > 0.0:
				continue
			var fp := Vector2i(Vector2(x + 0.5, y + 0.5) * k)
			if fp.x < 3 or fp.y < 3 or fp.x >= fsz.x - 3 or fp.y >= fsz.y - 3:
				continue
			then += 1 if _spike(old_f, fp) else 0
			now += 1 if _spike(fi, fp) else 0
	last_star_count = Vector2i(then, now)
	return now >= 3 and float(then) <= float(now) * 0.2


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
		&"ring_eclipsed":
			return layer.drawn and lit < 0.05
		&"ring_ghost":
			# By day the unlit hull is within a few levels of the sky beside it.
			var p := frame_probe()
			return not p.is_empty() and int(p.ghost_n) >= GHOST_LEAST and float(p.ghost) < GHOST_MOST
		&"ring_hides_stars":
			return _stars_come_out()
	return false
