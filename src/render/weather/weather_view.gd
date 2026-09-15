class_name WeatherView
extends Node3D
## What falls through the air around the camera, drawn as marks in the notebook
## (docs/ART.md section 6): rain as short slanted ink strokes gathered into
## columns, splashes as tiny ticks, hail as pale pellets, snow as paper flecks,
## ash as dark specks with the odd ember, dust as blown streaks, heat as a
## wavering line, wind as the odd flick, and lightning as a jagged ruled line.
##
## Follows the camera focus, turned to the camera's yaw so its emission boxes
## cover the screen. Amounts come from WeatherLook.compose(); changing an
## amount never restarts an emitter (the shader thins the marks instead), so
## weather eases in and out without a hitch.

const PRECIP := preload("res://src/render/weather/precip.gdshader")

## Tiles of air above the focus that marks fall through.
const TOP := 11.0
## On screen a world-vertical fall is cos(pitch 57) as long as it is: sideways
## drift per unit fall times this is the stroke's slant in pixels per pixel.
const SLANT_PER_LEAN := 1.0 / 0.5446

enum Mode { STROKE, FLECK, WAVE, FLICK, TICK, SPARK }

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
## Heat: wavering lines rising off hot ground.
var haze: CPUParticles3D
## Wind: a few flicks racing along with a strong wind.
var flicks: CPUParticles3D
## Wisps: cold lights drifting low over the moss at night.
var wisps: CPUParticles3D
var bolt: MeshInstance3D
var _bolt_left := 0.0
var _bolt_hold := false
var _mats: Dictionary = {} # CPUParticles3D -> ShaderMaterial


func setup(cam: CameraRig) -> void:
	camera = cam
	var air := Vector3(16.0, TOP * 0.5, 14.0)
	var mid := Vector3(0, TOP * 0.5, 0)
	# Rain: mostly ink strokes, a third pale ones, so it reads on turf and on sand.
	rain = _emitter("rain", 2600, 0.62, air, mid, false)
	_mat(rain, Mode.STROKE, {"color_a": Palette.INK[2], "color_b": Palette.RIME[4], "mix_b": 0.5, "length_px": Vector2(5, 8), "columns": 0.7})
	splash = _emitter("splash", 260, 0.16, Vector3(15.0, 0.02, 13.0), Vector3.ZERO, false)
	_mat(splash, Mode.TICK, {"color_a": Palette.RIME[4], "color_b": Palette.INK[3], "mix_b": 0.3, "columns": 0.75})
	hail = _emitter("hail", 900, 0.5, air, mid, false)
	_mat(hail, Mode.STROKE, {"color_a": Palette.RIME[5], "color_b": Palette.ASH[4], "mix_b": 0.3, "length_px": Vector2(2, 3), "columns": 0.4})
	# Snow: paper flecks, each with a blue shade pixel under it so a fleck still
	# reads over lying snow.
	snow = _emitter("snow", 5000, 8.0, air, mid, true)
	_mat(snow, Mode.FLECK, {"color_a": Palette.RIME[3], "color_b": Palette.LINEN[5], "mix_b": 1.0, "length_px": Vector2(1, 2), "wander": 2.0, "underline": 1.0})
	flurry = _emitter("flurry", 700, 6.0, air, mid, true)
	_mat(flurry, Mode.FLECK, {"color_a": Palette.RIME[3], "color_b": Palette.LINEN[5], "mix_b": 1.0, "length_px": Vector2(2, 2), "wander": 3.0, "underline": 1.0})
	# Ash: dark specks, a few scraps of burnt paper among them.
	ash = _emitter("ash", 2600, 12.0, air, mid, true)
	_mat(ash, Mode.FLECK, {"color_a": Palette.INK[1], "color_b": Palette.ASH[3], "mix_b": 0.3, "length_px": Vector2(1, 2), "wander": 3.0})
	ember = _emitter("ember", 70, 5.0, Vector3(15.0, 1.5, 13.0), Vector3(0, 0.8, 0), true)
	_mat(ember, Mode.FLECK, {"color_a": Palette.EMBER[4], "color_b": Palette.EMBER[5], "mix_b": 0.3, "length_px": Vector2(1, 1), "wander": 1.0, "glow": 1.0})
	drift = _emitter("drift", 700, 3.0, Vector3(19.0, 2.2, 15.0), Vector3(0, 1.6, 0), true)
	_mat(drift, Mode.FLICK, {"color_a": Palette.SAND[4], "color_b": Palette.LINEN[5], "mix_b": 0.3, "length_px": Vector2(4, 8)})
	# Heat: wavering lines, drawn darker than pale stone and paler than ash so
	# some always read.
	haze = _emitter("haze", 120, 4.0, Vector3(15.0, 0.6, 13.0), Vector3(0, 0.3, 0), true)
	_mat(haze, Mode.WAVE, {"color_a": Palette.SAND[2], "color_b": Palette.LINEN[5], "mix_b": 0.4})
	flicks = _emitter("flicks", 18, 0.9, Vector3(16.0, 1.5, 14.0), Vector3(0, 1.0, 0), true)
	_mat(flicks, Mode.FLICK, {"color_a": Palette.LINEN[4], "color_b": Palette.INK[3], "mix_b": 0.4, "length_px": Vector2(6, 10)})
	wisps = _emitter("wisps", 40, 7.0, Vector3(15.0, 0.5, 13.0), Vector3(0, 0.7, 0), true)
	_mat(wisps, Mode.SPARK, {"color_a": Palette.SPRUCE[5], "color_b": Palette.RIME[5], "mix_b": 0.4, "length_px": Vector2(1, 2), "wander": 5.0, "glow": 1.0, "flicker_rate": 0.7})
	bolt = MeshInstance3D.new()
	bolt.name = "bolt"
	bolt.visible = false
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.extra_cull_margin = 16384.0
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	bm.render_priority = 20
	bolt.material_override = bm
	add_child(bolt)


func _texel() -> float:
	if camera == null or not camera.is_inside_tree():
		return 14.0 / 360.0
	return camera.view_height / maxf(1.0, camera.get_viewport().get_visible_rect().size.y)


func _emitter(n: String, amount: int, life: float, extents: Vector3, offset: Vector3, fades: bool) -> CPUParticles3D:
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
	if fades:
		# Drifting marks come and go over their life: the shader drops a random
		# share of them as alpha falls, so none ever goes translucent.
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.15, Color(1, 1, 1, 1))
		g.add_point(0.85, Color(1, 1, 1, 1))
		p.color_ramp = g
	add_child(p)
	return p


func _mat(p: CPUParticles3D, mode: Mode, params: Dictionary) -> void:
	var m := ShaderMaterial.new()
	m.shader = PRECIP
	m.render_priority = 10
	m.set_shader_parameter("mode", int(mode))
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	p.material_override = m
	_mats[p] = m


## look: WeatherLook.compose() output; wind -1..1; focus: the camera's target.
func update(look: Dictionary, wind: float, focus: Vector3, delta: float) -> void:
	if camera != null:
		rotation.y = deg_to_rad(camera.yaw_deg)
	position = focus
	var storm := float(look.storm)
	# Screen-right in this node's frame is +X, so wind leans everything along X.
	# Rain is always drawn on a slant: straight-down strokes read as scratches.
	var lean := wind * 0.45
	if absf(lean) < 0.14:
		lean = 0.14 if lean >= 0.0 else -0.14
	_drive(rain, float(look.rain), Vector3(lean, -1.0, 0.0), 19.0, {
		"slant": lean * SLANT_PER_LEAN,
		"length_px": Vector2(5, 8) + Vector2(1, 3) * storm,
	})
	_drive(hail, float(look.hail), Vector3(lean * 0.5, -1.0, 0.0), 22.0, {"slant": lean * 0.5 * SLANT_PER_LEAN * 0.3})
	var blizzard := clampf(float(look.snow) - 0.8, 0.0, 0.2) * 5.0 * clampf(absf(wind) * 1.5, 0.0, 1.0)
	_drive(snow, float(look.snow), Vector3(wind * 1.4, -1.0, 0.0), 1.1 + absf(wind) * 2.2, {"wander": 2.0 * (1.0 - absf(wind) * 0.6)})
	_drive(flurry, float(look.snow), Vector3(wind * 1.6, -1.0, 0.0), 1.6 + absf(wind) * 2.6, {})
	_drive(ash, float(look.ash), Vector3(wind * 0.8, -1.0, 0.2), 0.55, {})
	_drive(ember, float(look.ash) * 0.8 + float(look.heat) * 0.15, Vector3(wind * 0.3, 1.0, 0.0), 0.5, {})
	_drive(haze, float(look.heat), Vector3(wind * 0.1, 1.0, 0.0), 0.3, {})
	var blow := signf(wind) if absf(wind) > 0.05 else 1.0
	var sand := float(look.dust)
	var drift_amount := maxf(sand, blizzard)
	var snowy := blizzard / maxf(0.001, sand + blizzard)
	_drive(drift, drift_amount, Vector3(blow, -0.06, 0.1), 5.0 + absf(wind) * 6.0, {
		"facing": blow,
		"color_a": Palette.SAND[4].lerp(Palette.RIME[5], snowy),
		"color_b": Palette.LINEN[5].lerp(Palette.RIME[4], snowy),
	})
	# The odd flick once the wind gets up; the flick is drawn with its head
	# leading, so it flips with the wind.
	var gusty := clampf((absf(wind) - 0.35) / 0.5, 0.0, 1.0) * (1.0 - float(look.fog))
	_drive(flicks, gusty, Vector3(blow, 0.0, 0.0), 9.0 + absf(wind) * 6.0, {"facing": blow})
	_drive(wisps, float(look.get("wisp", 0.0)), Vector3(wind * 0.2 + 0.1, 0.05, 0.1), 0.25, {})
	var wet := clampf(float(look.rain) + float(look.hail) * 0.5, 0.0, 1.0)
	_drive(splash, wet, Vector3(0, 1, 0), 0.25, {})
	splash.position.y = TerrainMesher.WATER_Y + 0.03 - focus.y if wet > 0.0 else 0.0
	if bolt.visible and not _bolt_hold:
		_bolt_left -= delta
		# Three frames of flicker: on, off, on, then gone.
		bolt.visible = _bolt_left > 0.0 and (_bolt_left > 0.18 or _bolt_left < 0.12)


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


## A jagged bolt from the sky to `at` (world space), seeded so shots repeat:
## a paper-white line one or two pixels wide with ink beside it, the way a
## pen draws a strike. hold = stay lit until the next strike (forced shots).
func strike(at: Vector3, seed_value: int, hold: bool = false) -> void:
	var r := Rng.make(seed_value, 0xB017)
	var k := SurfaceTool.new()
	k.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := at + Vector3(r.randf_range(-3.0, 3.0), 26.0, r.randf_range(-3.0, 3.0))
	var tx := _texel()
	var path := _bolt_points(top, at, 12, r)
	# Ink first, a pixel wider on each side, then the white core over it.
	_bolt_path(k, path, tx * 1.5, Palette.INK[1], 0.0)
	_bolt_path(k, path, tx * 0.5, Palette.LINEN[5], 0.02)
	for i in 2:
		var t := r.randf_range(0.2, 0.55)
		var from := top.lerp(at, t) + Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))
		var to := from + Vector3(r.randf_range(-5.0, 5.0), -r.randf_range(4.0, 8.0), r.randf_range(-5.0, 5.0))
		var fork := _bolt_points(from, to, 5, r)
		_bolt_path(k, fork, tx * 1.0, Palette.INK[1], 0.0)
		_bolt_path(k, fork, tx * 0.5, Palette.RIME[5], 0.02)
	bolt.mesh = k.commit()
	bolt.global_transform = Transform3D.IDENTITY
	bolt.visible = true
	_bolt_left = 0.3
	_bolt_hold = hold


func _cam_basis() -> Basis:
	if camera != null:
		return camera.global_transform.basis
	return Basis.from_euler(Vector3(deg_to_rad(-57.0), deg_to_rad(45.0), 0.0))


func _bolt_points(a: Vector3, b: Vector3, steps: int, r: RandomNumberGenerator) -> PackedVector3Array:
	var cb := _cam_basis()
	var out := PackedVector3Array([a])
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a.lerp(b, t)
		if i < steps:
			p += cb.x.normalized() * r.randf_range(-0.7, 0.7) + cb.z * r.randf_range(-0.3, 0.3)
		out.append(p)
	return out


## One ribbon along the path facing the camera; `toward` pulls it a little
## toward the eye so the core is drawn over its ink.
func _bolt_path(k: SurfaceTool, pts: PackedVector3Array, width: float, col: Color, toward: float) -> void:
	var cb := _cam_basis()
	var right := cb.x.normalized()
	var eye := cb.z.normalized() * toward
	for i in range(1, pts.size()):
		var t := float(i) / (pts.size() - 1)
		var w0 := right * width * (1.0 - (t - 1.0 / (pts.size() - 1)) * 0.4)
		var w1 := right * width * (1.0 - t * 0.4)
		var a := pts[i - 1] + eye
		var b := pts[i] + eye
		k.set_color(col)
		k.add_vertex(a - w0)
		k.add_vertex(a + w0)
		k.add_vertex(b + w1)
		k.add_vertex(a - w0)
		k.add_vertex(b + w1)
		k.add_vertex(b - w1)
