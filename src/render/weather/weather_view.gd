class_name WeatherView
extends Node3D
## What falls through the air around the camera: rain in columns with splashes,
## hail, snow, drifting ash with embers, blown dust, and lightning. Follows the
## camera focus, turned to the camera's yaw so its emission boxes cover exactly
## the screen. Amounts come from WeatherLook.compose(); changing an amount never
## restarts an emitter (the shader thins the particles instead), so weather
## eases in and out without a hitch.

const PRECIP := preload("res://src/render/weather/precip.gdshader")

## Tiles of air above the focus that marks fall through.
const TOP := 11.0

var camera: CameraRig
var rain: CPUParticles3D
var splash: CPUParticles3D
var hail: CPUParticles3D
var snow: CPUParticles3D
## Fewer, bigger flakes nearer the eye, so snow has depth.
var flurry: CPUParticles3D
var ash: CPUParticles3D
var ember: CPUParticles3D
## Blown streaks: sand in a dust storm, snow in a blizzard.
var drift: CPUParticles3D
## Pale specks rising in the heat.
var motes: CPUParticles3D
var bolt: MeshInstance3D
var _bolt_left := 0.0
var _bolt_hold := false
var _mats: Dictionary = {} # CPUParticles3D -> ShaderMaterial


func setup(cam: CameraRig) -> void:
	camera = cam
	var tx := _texel()
	var air := Vector3(16.0, TOP * 0.5, 14.0)
	var mid := Vector3(0, TOP * 0.5, 0)
	rain = _emitter("rain", 1700, 0.62, air, mid)
	_mat(rain, {"color_a": Palette.RIME[4], "color_b": Palette.RIME[5], "mix_b": 0.2, "size": Vector2(tx, 0.5), "opacity": 0.62})
	splash = _emitter("splash", 320, 0.2, Vector3(15.0, 0.02, 13.0), Vector3.ZERO)
	_mat(splash, {"color_a": Palette.RIME[4], "color_b": Palette.RIME[5], "mix_b": 0.5, "flake": 1.0, "size": Vector2(0, tx * 1.2), "opacity": 0.75, "texel": tx})
	hail = _emitter("hail", 1000, 0.5, air, mid)
	_mat(hail, {"color_a": Palette.RIME[5], "color_b": Palette.ASH[4], "mix_b": 0.3, "size": Vector2(tx, 0.14), "opacity": 0.95})
	snow = _emitter("snow", 2600, 8.0, air, mid)
	_mat(snow, {"color_a": Palette.RIME[5], "color_b": Palette.RIME[4], "mix_b": 0.3, "flake": 1.0, "size": Vector2(0, tx * 2.0), "sway": 0.35, "opacity": 1.0, "texel": tx})
	flurry = _emitter("flurry", 160, 6.0, air, mid)
	_mat(flurry, {"color_a": Palette.RIME[5], "color_b": Palette.RIME[5], "flake": 1.0, "size": Vector2(0, tx * 3.0), "sway": 0.6, "opacity": 1.0, "texel": tx})
	ash = _emitter("ash", 1700, 12.0, air, mid)
	_mat(ash, {"color_a": Palette.ASH[3], "color_b": Palette.LINEN[4], "mix_b": 0.18, "flake": 1.0, "size": Vector2(0, tx * 2.0), "sway": 0.7, "opacity": 0.95, "texel": tx})
	ember = _emitter("ember", 90, 5.0, Vector3(15.0, 1.5, 13.0), Vector3(0, 0.8, 0))
	_mat(ember, {"color_a": Palette.EMBER[4], "color_b": Palette.EMBER[5], "mix_b": 0.3, "flake": 1.0, "size": Vector2(0, tx * 1.2), "sway": 0.25, "opacity": 1.0, "glow": 1.0, "texel": tx})
	drift = _emitter("drift", 1300, 3.0, Vector3(19.0, 2.2, 15.0), Vector3(0, 1.6, 0))
	_mat(drift, {"color_a": Palette.SAND[4], "color_b": Palette.LINEN[5], "mix_b": 0.3, "size": Vector2(tx, 0.7), "opacity": 0.7})
	motes = _emitter("motes", 140, 6.0, Vector3(15.0, 1.0, 13.0), Vector3(0, 0.3, 0))
	_mat(motes, {"color_a": Palette.LINEN[5], "color_b": Palette.EMBER[5], "mix_b": 0.2, "flake": 1.0, "size": Vector2(0, tx * 1.1), "sway": 0.2, "opacity": 0.55, "texel": tx})
	# Marks that drift fade in and out over their life; rain and hail are whole
	# all the way to the ground.
	for p: CPUParticles3D in [snow, flurry, ash, drift, ember, splash, motes]:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.12, Color(1, 1, 1, 1))
		g.add_point(0.85, Color(1, 1, 1, 1))
		p.color_ramp = g
	bolt = MeshInstance3D.new()
	bolt.name = "bolt"
	bolt.visible = false
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.extra_cull_margin = 16384.0
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	bm.render_priority = 20
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt.material_override = bm
	add_child(bolt)


func _texel() -> float:
	if camera == null or not camera.is_inside_tree():
		return 14.0 / 360.0
	return camera.view_height / maxf(1.0, camera.get_viewport().get_visible_rect().size.y)


func _emitter(n: String, amount: int, life: float, extents: Vector3, offset: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emitting = false
	p.visible = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.position = offset
	p.gravity = Vector3.ZERO
	p.spread = 0.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.extra_cull_margin = 16384.0
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	p.mesh = q
	# A random number per particle, in the red channel.
	var r := Gradient.new()
	r.set_color(0, Color(0, 1, 1, 1))
	r.set_color(1, Color(1, 1, 1, 1))
	p.color_initial_ramp = r
	add_child(p)
	return p


func _mat(p: CPUParticles3D, params: Dictionary) -> void:
	var m := ShaderMaterial.new()
	m.shader = PRECIP
	m.render_priority = 10
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	p.material_override = m
	_mats[p] = m


## look: WeatherLook.compose() output; wind -1..1; focus: the camera's target.
func update(look: Dictionary, wind: float, focus: Vector3, delta: float) -> void:
	if camera != null:
		rotation.y = deg_to_rad(camera.yaw_deg)
	position = focus
	var tx := _texel()
	# Screen-right in this node's frame is +X, so wind leans everything along X.
	var lean := wind * 0.45
	_drive(rain, float(look.rain), Vector3(lean, -1.0, 0.0), 19.0, {"fall": _world_dir(Vector3(lean, -1.0, 0.0)), "size": Vector2(tx, 0.42 + 0.2 * float(look.storm))})
	_drive(hail, float(look.hail), Vector3(lean * 0.5, -1.0, 0.0), 22.0, {"fall": _world_dir(Vector3(lean * 0.5, -1.0, 0.0))})
	var blizzard := clampf(float(look.snow) - 0.8, 0.0, 0.2) * 5.0 * clampf(absf(wind) * 1.5, 0.0, 1.0)
	_drive(snow, float(look.snow), Vector3(wind * 1.4, -1.0, 0.0), 1.1 + absf(wind) * 2.2, {"sway": 0.35 * (1.0 - absf(wind) * 0.6)})
	_drive(flurry, float(look.snow), Vector3(wind * 1.6, -1.0, 0.0), 1.6 + absf(wind) * 2.6, {})
	_drive(ash, float(look.ash), Vector3(wind * 0.8, -1.0, 0.2), 0.55, {})
	_drive(ember, float(look.ash) * 0.8 + float(look.heat) * 0.2, Vector3(wind * 0.3, 1.0, 0.0), 0.5, {})
	_drive(motes, float(look.heat), Vector3(wind * 0.2, 1.0, 0.0), 0.35, {})
	var blow := signf(wind) if absf(wind) > 0.05 else 1.0
	var sand := float(look.dust)
	var drift_amount := maxf(sand, blizzard)
	var snowy := blizzard / maxf(0.001, sand + blizzard)
	_drive(drift, drift_amount, Vector3(blow, -0.06, 0.1), 5.0 + absf(wind) * 6.0, {
		"fall": _world_dir(Vector3(-blow, 0.0, 0.0)),
		"color_a": Palette.SAND[4].lerp(Palette.RIME[5], snowy),
		"color_b": Palette.LINEN[5].lerp(Palette.RIME[4], snowy),
	})
	var wet := clampf(float(look.rain) + float(look.hail) * 0.5, 0.0, 1.0)
	_drive(splash, wet, Vector3(0, 1, 0), 0.25, {})
	splash.position.y = TerrainMesher.WATER_Y + 0.03 - focus.y if wet > 0.0 else 0.0
	if bolt.visible and not _bolt_hold:
		_bolt_left -= delta
		# Three frames of flicker: on, off, on, then gone.
		bolt.visible = _bolt_left > 0.0
		var ph := _bolt_left
		(bolt.material_override as StandardMaterial3D).albedo_color.a = 1.0 if (ph > 0.18 or (ph < 0.12 and ph > 0.0)) else 0.0


## Particles are emitted in this node's frame; the shader wants world space.
func _world_dir(local: Vector3) -> Vector3:
	return (Basis(Vector3.UP, rotation.y) * local).normalized()


func _drive(p: CPUParticles3D, amount: float, dir: Vector3, speed: float, params: Dictionary) -> void:
	var on := amount > 0.002
	if not on:
		if p.emitting:
			p.emitting = false
			p.visible = false
		return
	p.direction = dir.normalized()
	p.initial_velocity_min = speed * 0.9
	p.initial_velocity_max = speed * 1.1
	var m: ShaderMaterial = _mats[p]
	# Density is not linear in what the eye reads: a light rain wants more than
	# a tenth of the drops of a downpour.
	m.set_shader_parameter("density", sqrt(clampf(amount, 0.0, 1.0)))
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	if not p.emitting:
		# Preprocess fills the air at once, so weather never starts as a curtain
		# falling from the top of the screen.
		p.visible = true
		p.emitting = true
		p.restart()


## A jagged bolt from the sky to `at` (world space), seeded so shots repeat.
## hold = stay lit until the next strike (forced shots).
func strike(at: Vector3, seed_value: int, hold: bool = false) -> void:
	var r := Rng.make(seed_value, 0xB017)
	var k := SurfaceTool.new()
	k.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := at + Vector3(r.randf_range(-3.0, 3.0), 26.0, r.randf_range(-3.0, 3.0))
	var tx := _texel()
	_bolt_path(k, top, at, 12, tx * 1.6, r, Palette.RIME[5])
	# Two forks off the upper half.
	for i in 2:
		var t := r.randf_range(0.2, 0.55)
		var from := top.lerp(at, t) + Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))
		var to := from + Vector3(r.randf_range(-5.0, 5.0), -r.randf_range(4.0, 8.0), r.randf_range(-5.0, 5.0))
		_bolt_path(k, from, to, 5, tx * 0.9, r, Palette.RIME[4])
	bolt.mesh = k.commit()
	bolt.global_transform = Transform3D.IDENTITY
	bolt.visible = true
	(bolt.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, 1)
	_bolt_left = 0.3
	_bolt_hold = hold


func _bolt_path(k: SurfaceTool, a: Vector3, b: Vector3, steps: int, width: float, r: RandomNumberGenerator, col: Color) -> void:
	var cam_basis := Basis.from_euler(Vector3(deg_to_rad(-57.0), deg_to_rad(45.0), 0.0))
	if camera != null:
		cam_basis = camera.global_transform.basis
	var right := cam_basis.x.normalized()
	var prev := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a.lerp(b, t)
		if i < steps:
			p += right * r.randf_range(-0.7, 0.7) + cam_basis.z * r.randf_range(-0.3, 0.3)
		var w := right * width * (1.0 - t * 0.5)
		k.set_color(col)
		k.add_vertex(prev - w)
		k.add_vertex(prev + w)
		k.add_vertex(p + w)
		k.add_vertex(prev - w)
		k.add_vertex(p + w)
		k.add_vertex(p - w)
		prev = p
