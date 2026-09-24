extends Node
## THE RING'S OWN SKY LAYER: a second, private world in which the ring is drawn
## in kilometres, from the eye's own direction with the eye's own lens, and lit
## by its own sun -- the REAL one, which sets -- into a texture the seen sky
## (sky_eye.gdshader, src/render/orbit/orbit_sky.gdshaderinc) samples on the
## same pixel.
##
## WHY A LAYER AND NOT A MESH IN THE WORLD. The colossi are drawn in the main
## pass in compressed space, which clamps past 400 km: this body is 420 to
## 2000 km off and cannot be drawn there. And a mesh in the main pass draws OVER
## the dome's clouds, where the ring must stand BEHIND them. In the sky it is
## composited in the right order -- over the air, under the clouds, in front of
## the stars and the sun -- by construction.
##
## WHAT THE LAYER COSTS NOTHING FOR. It renders only while the horizon is in
## frame (`SkyLight.horizon_share` > 0) AND the ring is in the lens's cone; the
## rest of the time it is UPDATE_DISABLED and the sky is told (`orbit_on` 0) not
## to read its stale frame. The orthographic game never pays for it.
##
## Reached by path (19_orbit preloads it), no class_name.

const Pass := preload("res://src/core/orbit/orbit_pass.gd")
const Model := preload("res://src/models/orbit/ring_model.gd")
const SHADER := preload("res://src/render/orbit/orbit.gdshader")

## The layer camera's planes, km: nearer than the lowest a pass can be (420)
## by a margin for the wheel's own radius, and past the horizon's 2000.
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
## A proof mode: a flat emissive quad in place of the ring (the risk this layer
## was proved on first: an HDR ViewportTexture sampled in a sky shader).
var proof := false


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
	sun.light_energy = 5.0
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
## direction `d` onto the layer's glass (0..1, y down), or (-1, -1) off it.
static func uv_of(basis: Basis, fov_deg: float, aspect: float, d: Vector3) -> Vector2:
	var v := basis.transposed() * d
	if v.z > -1e-4:
		return Vector2(-1.0, -1.0)
	var t := tan_of(fov_deg, aspect)
	var ndc := Vector2(v.x, v.y) / (-v.z) / t
	if absf(ndc.x) > 1.0 or absf(ndc.y) > 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(0.5 + 0.5 * ndc.x, 0.5 - 0.5 * ndc.y)


## tan of half the lens across and up, for a KEEP_HEIGHT camera of vertical
## fov `fov_deg`.
static func tan_of(fov_deg: float, aspect: float) -> Vector2:
	var ty := tan(deg_to_rad(fov_deg) * 0.5)
	return Vector2(ty * aspect, ty)


## Pose the layer for this frame. `pose` from OrbitPass.pose, `sun_dir` the real
## sun (SkyLight.sky_sun), `air` SkyLight.seen_air. `wanted` false stands it
## down. Returns whether it renders this frame.
func update(cam: Camera3D, pose: Dictionary, sun_dir: Vector3, air: Dictionary, wanted: bool) -> bool:
	drawn = false
	if cam == null or not wanted or not bool(pose.get("up", false)):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return false
	var root := cam.get_viewport()
	var size := frame_size(root)
	var aspect := float(size.x) / float(size.y)
	var basis := cam.global_transform.basis.orthonormalized()
	var rel: Vector3 = pose.rel
	var dist: float = pose.dist
	var half := asin(clampf((float(def.rim_km) + 12.0) / maxf(dist, 1.0), 0.0, 1.0))
	var fwd := -basis.z
	var t := tan_of(cam.fov, aspect)
	var cone := atan(Vector2(t.x, t.y).length())
	if fwd.angle_to(rel / dist) > cone + half:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return false
	if viewport.size != size:
		viewport.size = size
	viewport.msaa_3d = Viewport.MSAA_2X if Quality.forward_plus() else Viewport.MSAA_DISABLED
	camera.global_transform = Transform3D(basis, Vector3.ZERO)
	camera.fov = cam.fov
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	sun.global_transform = Transform3D(Basis.looking_at(-sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT), Vector3.ZERO)
	# The sun a thing four hundred kilometres up sees at the land's dusk is the
	# land's own low sun, warmed toward gold as it goes down (and reddened further
	# per fragment where its light grazes the limb, orbit.gdshader `sunlit`).
	sun.light_color = SUN_DAY.lerp(SUN_DUSK, smoothstep(0.30, -0.12, sun_dir.y))
	px_across = 2.0 * float(def.rim_km) / dist / (2.0 * t.y) * float(size.y)
	if proof:
		# Square to the view, straight along the ring's direction.
		ring.global_transform = Transform3D(Basis.looking_at(rel / dist, Vector3.UP if absf(rel.y / dist) < 0.99 else Vector3.RIGHT), rel)
	else:
		var near_one := px_across > NEAR_LOD_PX
		lod = 1 if near_one else 2
		var body: ArrayMesh = _bodies[1 if near_one else 0]
		if ring.mesh != body:
			ring.mesh = body
		ring.global_transform = Transform3D(pose.basis, rel)
		_feed(pose, sun_dir, air, size)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	drawn = true
	return true


func _feed(pose: Dictionary, sun_dir: Vector3, air: Dictionary, size: Vector2i) -> void:
	var dome: Dictionary = air.get("dome", {})
	mat.set_shader_parameter(&"sun_dir", sun_dir)
	mat.set_shader_parameter(&"earth", pose.earth)
	mat.set_shader_parameter(&"planet_km", float(def.planet_km))
	mat.set_shader_parameter(&"px_angle", 2.0 * tan(deg_to_rad(camera.fov) * 0.5) / float(size.y))
	mat.set_shader_parameter(&"glow_color", dome.get(&"dome_glow_color", Color(1.0, 0.55, 0.3)))
	# How much daylit ground lies under the ring, for the light it throws back up
	# onto the hull: the sun's height where the observer stands is a fair guess
	# at the ground four hundred kilometres round.
	mat.set_shader_parameter(&"night", float(dome.get(&"dome_night", 0.0)))
	mat.set_shader_parameter(&"planet_day", smoothstep(-0.08, 0.35, sun_dir.y))
	mat.set_shader_parameter(&"bones", Model.bone_rows(def, seed_value, float(pose.get("minutes", 0.0))))


## Where a direction lands on the layer's glass, for the proof and a tour.
func uv_for(d: Vector3) -> Vector2:
	var sz := Vector2(viewport.size)
	return uv_of(camera.global_transform.basis, camera.fov, sz.x / sz.y, d)
