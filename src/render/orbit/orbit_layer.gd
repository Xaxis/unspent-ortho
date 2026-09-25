extends Node
## THE RING'S OWN SKY LAYER: a second, private world in which the ring is drawn
## in kilometres, from the eye's own place, by a camera AIMED AT THE RING, and lit
## by its own sun -- the REAL one, which sets -- into a texture the seen sky
## (sky_eye.gdshader, src/render/orbit/orbit_sky.gdshaderinc) samples by
## direction.
##
## WHY A LAYER AND NOT A MESH IN THE WORLD. The colossi are drawn in the main
## pass in compressed space, which clamps past 400 km: this body is 300 to
## 1700 km off and cannot be drawn there. And a mesh in the main pass draws OVER
## the dome's clouds, where the ring must stand BEHIND them. In the sky it is
## composited in the right order -- over the air, under the clouds, in front of
## the stars and the sun -- by construction.
##
## WHAT THE LAYER COSTS NOTHING FOR. It is read only while the horizon is in
## frame (`SkyLight.horizon_share` > 0) AND the ring is in the lens's cone, and
## drawn one frame in RENDER_EVERY of those; the rest of the time the sky is
## told (`orbit_on` 0) not to read it. The orthographic game never pays for it.
##
## Reached by path (19_orbit preloads it), no class_name.

const Pass := preload("res://src/core/orbit/orbit_pass.gd")
const Model := preload("res://src/models/orbit/ring_model.gd")
const SHADER := preload("res://src/render/orbit/orbit.gdshader")

## The layer camera's planes, km: nearer than the lowest a pass can be (300)
## by a margin for the wheel's own radius, and past the horizon's 1700.
const NEAR_KM := 50.0
const FAR_KM := 6000.0
## Nearer than this many pixels across, the far body is drawn (the rim alone,
## a quarter of the triangles): at the horizon the wheel is sixty pixels wide.
const NEAR_LOD_PX := 170.0

## The ring's sun by day, and at the land's dusk.
const SUN_DAY := Color(1.0, 0.97, 0.92)
const SUN_DUSK := Color(1.0, 0.74, 0.42)

var def: RefCounted
var seed_value := 0
var viewport: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D
var ring: MeshInstance3D
var mat: ShaderMaterial
var _bodies: Array[ArrayMesh] = []
## What the texture holds is radiance / gain: 1 when the target keeps HDR.
var gain := 1.0
## Whether the layer rendered this frame, and the body it used (1 near, 2 far).
var drawn := false
var lod := 2
## The ring's size on the glass this frame, pixels across (for --stats, a tour).
var px_across := 0.0
## This frame's frame size, the rectangle of it the layer covers (frame pixels,
## and NDC for the sky), and the eye's fov the frustum was cut from.
var screen := Vector2i(16, 16)
var frame_rect := Rect2i()
var rect := Vector4(-1.0, -1.0, 1.0, 1.0)
var fov := 60.0
## The eye's basis this frame, and the layer's own aim (its basis and tan of
## half its square lens), which the sky is handed.
var eye_basis := Basis.IDENTITY
var aim_basis := Basis.IDENTITY
var aim_tan := 0.1
## Whether the layer was drawn this frame, and frames since it last was.
var fresh := false
var _age := 0
## How much the ring's lamps show against this frame's sky (`lamp_seen`).
var lamps_shown := 1.0
## A proof mode: a flat emissive quad in place of the ring (the risk this layer
## was proved on first: an HDR ViewportTexture sampled in a sky shader).
var proof := false
## The loose pieces, dealt once (ring_model.gd `chunk_list`).
var _chunks: Array[Dictionary] = []


func setup(orbit_def: RefCounted, seed_v: int, prove := false) -> void:
	def = orbit_def
	seed_value = seed_v
	proof = prove
	viewport = SubViewport.new()
	viewport.name = "orbit_layer"
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.use_hdr_2d = true
	viewport.disable_3d = false
	viewport.positional_shadow_atlas_size = 0
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(16, 16)
	add_child(viewport)
	camera = Camera3D.new()
	camera.near = NEAR_KM
	camera.far = FAR_KM
	camera.current = true
	viewport.add_child(camera)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = false
	sun.light_energy = 7.0
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	viewport.add_child(sun)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0, 0, 0)
	e.ambient_light_energy = 0.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.glow_enabled = false
	e.fog_enabled = false
	we.environment = e
	viewport.add_child(we)
	ring = MeshInstance3D.new()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# The engine culls on the AABB in layer space, which is honest here: the
	# ring is where it is drawn. The margin is the chunks drifting off the wound.
	ring.extra_cull_margin = 40.0
	if proof:
		var q := QuadMesh.new()
		q.size = Vector2(40.0, 40.0)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.0, 0.0, 0.0)
		m.emission_enabled = true
		# Linear (2.0, 0.43, 0.10): over 1 on purpose, to see whether it survives.
		m.emission = Color(1.0, 0.5, 0.25)
		m.emission_energy_multiplier = 2.0
		ring.mesh = q
		ring.material_override = m
	else:
		_bodies = [Model.build(def, false, seed_value), Model.build(def, true, seed_value)]
		ring.mesh = _bodies[0]
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		ring.material_override = mat
	viewport.add_child(ring)


## The 3D frame's size: the root's, at the tier's render scale, so a layer
## pixel IS a frame pixel.
static func frame_size(vp: Viewport) -> Vector2i:
	var sz := vp.get_visible_rect().size
	var sc := vp.scaling_3d_scale if vp.scaling_3d_scale > 0.0 else 1.0
	return Vector2i(maxi(16, roundi(sz.x * sc)), maxi(16, roundi(sz.y * sc)))


## THE ONE PROJECTION, mirrored by orbit_sky.gdshaderinc `orbit_uv`: a world
## direction `d` onto the layer's glass (0..1, y down), or (-1, -1) off it. The
## layer covers only `rect` of the frame, in NDC (x0, y0 bottom, x1, y1 top).
static func uv_of(basis: Basis, fov_deg: float, aspect: float, d: Vector3, rect := Vector4(-1.0, -1.0, 1.0, 1.0)) -> Vector2:
	var ndc := ndc_of(basis, fov_deg, aspect, d)
	if ndc.x < rect.x or ndc.x > rect.z or ndc.y < rect.y or ndc.y > rect.w:
		return Vector2(-1.0, -1.0)
	return Vector2((ndc.x - rect.x) / (rect.z - rect.x), (rect.w - ndc.y) / (rect.w - rect.y))


## A direction onto the whole frame's NDC, or far off it (behind the lens).
static func ndc_of(basis: Basis, fov_deg: float, aspect: float, d: Vector3) -> Vector2:
	var v := basis.transposed() * d
	if v.z > -1e-4:
		return Vector2(1e9, 1e9)
	var t := tan_of(fov_deg, aspect)
	return Vector2(v.x, v.y) / (-v.z) / t


## tan of half the lens across and up, for a KEEP_HEIGHT camera of vertical
## fov `fov_deg`.
static func tan_of(fov_deg: float, aspect: float) -> Vector2:
	var ty := tan(deg_to_rad(fov_deg) * 0.5)
	return Vector2(ty * aspect, ty)


## THE RECTANGLE OF THE FRAME THE RING CAN COVER, in whole frame pixels
## (x0, y0 top, x1, y1 bottom), or an empty one when it is off the glass: the
## bounding sphere's rim, sixteen directions round it, projected and boxed, a
## margin over, and its size rounded up to `BUCKET` so the target is not
## reallocated every frame as the ring moves.
static func rect_of(basis: Basis, fov_deg: float, screen: Vector2i, centre: Vector3, radius: float) -> Rect2i:
	var aspect := float(screen.x) / float(screen.y)
	var dist := centre.length()
	var c := centre / dist
	var half := asin(clampf(radius / dist, 0.0, 0.999))
	var u := c.cross(Vector3.UP if absf(c.y) < 0.95 else Vector3.RIGHT).normalized()
	var w := c.cross(u)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 16:
		var t := TAU * float(i) / 16.0
		var d := (c * cos(half) + (u * cos(t) + w * sin(t)) * sin(half)).normalized()
		var ndc := ndc_of(basis, fov_deg, aspect, d)
		if ndc.x > 1e8:
			# Part of the sphere is behind the lens: it may cover anything.
			return Rect2i(Vector2i.ZERO, screen)
		var px := Vector2((ndc.x * 0.5 + 0.5) * float(screen.x), (0.5 - ndc.y * 0.5) * float(screen.y))
		lo = lo.min(px)
		hi = hi.max(px)
	var a := Vector2i(floori(lo.x) - MARGIN, floori(lo.y) - MARGIN)
	var b := Vector2i(ceili(hi.x) + MARGIN, ceili(hi.y) + MARGIN)
	var size := b - a
	size = Vector2i(ceili(float(size.x) / BUCKET) * BUCKET, ceili(float(size.y) / BUCKET) * BUCKET)
	var mid := (a + b) / 2
	a = mid - size / 2
	var r := Rect2i(a, size).intersection(Rect2i(Vector2i.ZERO, screen))
	return r


## The frame rectangle in NDC for the sky (x0, y0 bottom, x1, y1 top).
static func ndc_rect(r: Rect2i, screen: Vector2i) -> Vector4:
	var x0 := 2.0 * float(r.position.x) / float(screen.x) - 1.0
	var x1 := 2.0 * float(r.end.x) / float(screen.x) - 1.0
	var y1 := 1.0 - 2.0 * float(r.position.y) / float(screen.y)
	var y0 := 1.0 - 2.0 * float(r.end.y) / float(screen.y)
	return Vector4(x0, y0, x1, y1)


## THE LENS CUT DOWN TO THE RECTANGLE: an off-axis frustum at the near plane
## with the eye's own basis, so a layer pixel is exactly a frame pixel (or a
## quarter of one). tests/render/test_orbit.gd asks the engine's own
## `unproject_position` of a camera cut here.
static func cut(c: Camera3D, basis: Basis, fov_deg: float, screen: Vector2i, r: Vector4) -> void:
	var t := tan_of(fov_deg, float(screen.x) / float(screen.y))
	var n := NEAR_KM
	c.projection = Camera3D.PROJECTION_FRUSTUM
	c.keep_aspect = Camera3D.KEEP_HEIGHT
	c.size = (r.w - r.y) * n * t.y
	c.frustum_offset = Vector2((r.x + r.z) * 0.5 * n * t.x, (r.y + r.w) * 0.5 * n * t.y)
	c.near = n
	c.far = FAR_KM
	c.global_transform = Transform3D(basis, Vector3.ZERO)


const MARGIN := 3
const BUCKET := 32.0


## THE LAYER IS AIMED AT THE RING, not cut out of the eye's own frustum: its
## camera looks straight at the wheel with a square lens just wide enough for
## it, so what it holds does not depend on where the eye is looking and the sky
## samples it by direction (orbit_sky's `orbit_uv`, with this basis and this
## lens). That is what lets it be drawn only one frame in RENDER_EVERY -- the
## wheel crosses the sky at a few pixels a real second -- while the eye turns
## freely between; cut from the eye's frustum, every turn of the head was a
## re-render (measured 1.1 ms a frame of the 1.2 the ring cost).
##
## Its texels are the eye's pixels at the ring, `ss` to a side (the Quality
## column `orbit`), and one to a side once the wheel is under SINGLE_PX across:
## four samples a pixel buy nothing a sixty-pixel ring can show. And never past
## MOST_TEXELS to a side: a wheel overhead is five hundred pixels, and at two to a
## side that was a full frame's worth of fill for a thing whose detail is lamps
## and plate seams (measured, the most of what the layer cost).
const RENDER_EVERY := 4
const SINGLE_PX := 150.0
const MOST_TEXELS := 1024


## The aim for a ring at `centre` (km from the eye) bounded by `radius`: the
## basis looking at it and tan of half the square lens that holds it.
static func aim_of(centre: Vector3, radius: float) -> Array:
	var dist := centre.length()
	var d := centre / dist
	var b := Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)
	var half := asin(clampf(radius / dist, 0.0, 0.999))
	return [b, tan(half) * AIM_MARGIN]


const AIM_MARGIN := 1.06


## Point camera `c` along an aim, square lens, KEEP_HEIGHT.
static func aim(c: Camera3D, basis: Basis, tan_half: float) -> void:
	c.projection = Camera3D.PROJECTION_PERSPECTIVE
	c.keep_aspect = Camera3D.KEEP_HEIGHT
	c.fov = rad_to_deg(2.0 * atan(tan_half))
	c.near = NEAR_KM
	c.far = FAR_KM
	c.global_transform = Transform3D(basis, Vector3.ZERO)


## Pose the layer for this frame. `pose` from OrbitPass.pose, `sun_dir` the real
## sun (SkyLight.sky_sun), `air` SkyLight.seen_air. `wanted` false stands it
## down. Returns whether the sky may read the layer this frame (it may hold a
## frame drawn up to RENDER_EVERY - 1 frames ago; `fresh` says it was drawn now).
func update(cam: Camera3D, pose: Dictionary, sun_dir: Vector3, air: Dictionary, wanted: bool) -> bool:
	drawn = false
	fresh = false
	var ss := int(Quality.current().get("orbit", 1)) if not Quality.current().is_empty() else 1
	if cam == null or not wanted or not bool(pose.get("up", false)) or ss <= 0:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_age = RENDER_EVERY
		return false
	var root := cam.get_viewport()
	screen = frame_size(root)
	var basis := cam.global_transform.basis.orthonormalized()
	var rel: Vector3 = pose.rel
	var dist: float = pose.dist
	var bound := float(def.rim_km) + float(def.sail.x) * 0.3 + 14.0
	# Off the lens's cone altogether: nothing to draw, nothing to read.
	var t := tan_of(cam.fov, float(screen.x) / float(screen.y))
	var cone := atan(Vector2(t.x, t.y).length())
	var half := asin(clampf(bound / maxf(dist, 1.0), 0.0, 1.0))
	if (-basis.z).angle_to(rel / dist) > cone + half:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_age = RENDER_EVERY
		return false
	# The ring's box on the glass, for the probes that read the frame.
	frame_rect = rect_of(basis, cam.fov, screen, rel, bound)
	eye_basis = basis
	fov = cam.fov
	px_across = 2.0 * float(def.rim_km) / dist / (2.0 * t.y) * float(screen.y)
	if px_across < SINGLE_PX:
		ss = 1
	var a := aim_of(rel, bound)
	var tan_half: float = a[1]
	var px_per := float(screen.y) / (2.0 * t.y)
	var n := mini(MOST_TEXELS, ceili(2.0 * tan_half * px_per * float(ss) / BUCKET) * int(BUCKET))
	var want := Vector2i(n, n)
	var near_one := px_across > NEAR_LOD_PX
	var body_changed := (lod == 1) != near_one
	_age += 1
	drawn = true
	if _age < RENDER_EVERY and viewport.size == want and not body_changed:
		# Last frame's picture still holds: the wheel has moved a fraction of a
		# pixel, and the eye turning does not change it.
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return true
	_age = 0
	fresh = true
	if viewport.size != want:
		viewport.size = want
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	aim_basis = a[0]
	aim_tan = tan_half
	aim(camera, aim_basis, aim_tan)
	sun.global_transform = Transform3D(Basis.looking_at(-sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT), Vector3.ZERO)
	# The sun a thing hundreds of kilometres up sees at the land's dusk is the
	# land's own low sun, warmed toward gold as it goes down (and reddened further
	# per fragment where its light grazes the limb, orbit.gdshader `sunlit`).
	sun.light_color = SUN_DAY.lerp(SUN_DUSK, smoothstep(0.30, -0.12, sun_dir.y))
	if proof:
		ring.global_transform = Transform3D(Basis.looking_at(rel / dist, Vector3.UP if absf(rel.y / dist) < 0.99 else Vector3.RIGHT), rel)
	else:
		lod = 1 if near_one else 2
		var body: ArrayMesh = _bodies[1 if near_one else 0]
		if ring.mesh != body:
			ring.mesh = body
		ring.global_transform = Transform3D(pose.basis, rel)
		_feed(pose, sun_dir, air, screen)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return true


func _feed(pose: Dictionary, sun_dir: Vector3, air: Dictionary, size: Vector2i) -> void:
	var dome: Dictionary = air.get("dome", {})
	mat.set_shader_parameter(&"sun_dir", sun_dir)
	mat.set_shader_parameter(&"earth", pose.earth)
	mat.set_shader_parameter(&"planet_km", float(def.planet_km))
	mat.set_shader_parameter(&"px_angle", 2.0 * tan(deg_to_rad(fov) * 0.5) / float(size.y))
	mat.set_shader_parameter(&"glow_color", dome.get(&"dome_glow_color", Color(1.0, 0.55, 0.3)))
	# How much daylit ground lies under the ring, for the light it throws back up
	# onto the hull: the sun's height where the observer stands is a fair guess
	# at the ground four hundred kilometres round.
	mat.set_shader_parameter(&"night", float(dome.get(&"dome_night", 0.0)))
	lamps_shown = lamp_seen(dome.get(&"dome_top_color", Color(0.02, 0.02, 0.04)))
	mat.set_shader_parameter(&"lamp_seen", lamps_shown)
	mat.set_shader_parameter(&"planet_day", smoothstep(-0.08, 0.35, sun_dir.y))
	if _chunks.is_empty():
		_chunks = Model.chunk_list(def, seed_value)
	mat.set_shader_parameter(&"bones", Model.bone_rows(def, seed_value, float(pose.get("minutes", 0.0)), _chunks))


## How much a lamp on the ring shows against a sky whose zenith is `top` (the
## seen sky's own `dome_top_color`): whole under a night sky, gone under a day
## one, and part-way through dusk, when the first lamps come out with the stars.
static func lamp_seen(top: Color) -> float:
	return clampf(1.0 - (top.get_luminance() - LAMP_SKY_DARK) / (LAMP_SKY_DAY - LAMP_SKY_DARK), 0.0, 1.0)


## Zenith luminance under which every lamp shows, and over which none does.
const LAMP_SKY_DARK := 0.15
const LAMP_SKY_DAY := 0.32


## Where a direction lands on the layer's glass, for the proof and a tour.
func uv_for(d: Vector3) -> Vector2:
	return uv_of(aim_basis, rad_to_deg(2.0 * atan(aim_tan)), 1.0, d)
