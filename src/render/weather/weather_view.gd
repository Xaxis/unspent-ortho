class_name WeatherView
extends Node3D
## What falls through the air around the camera, drawn as marks in the notebook
## (docs/ART.md section 6): rain as short slanted ink strokes gathered into
## squall curtains, drizzle as a fine pale grain, splashes as tiny ticks and
## rings spreading where water stands, drips from eaves, arms and crowns, hail
## as pale pellets, snow as paper flecks in squalls, ash as dark specks drifting
## in sheets with the odd ember, dust as blown streaks and spinning devils, heat
## as a wavering line, wind as the odd flick, and lightning as a jagged ruled line.
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

enum Mode { STROKE, FLECK, WAVE, FLICK, TICK, SPARK, RING, SWIRL }

## Marks in one dust devil's column.
const DEVIL_MARKS := 260

var camera: CameraRig
var rain: CPUParticles3D
## Drizzle: a fine grain of short pale strokes, slow, hardly slanted.
var drizzle: CPUParticles3D
var splash: CPUParticles3D
## Rings spreading on standing water while it rains.
var rings: CPUParticles3D
## Drips from the drip points (Drips.points), in world space.
var drips: CPUParticles3D
## Spinning dust columns (DustDevils), each its own node and material.
var devils: Array[MeshInstance3D] = []
var hail: CPUParticles3D
var snow: CPUParticles3D
## Fewer, bigger flakes nearer the eye, so snow has depth.
var flurry: CPUParticles3D
## Blown snow streaking along the ground (blizzard, whiteout).
var spindrift: CPUParticles3D
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
var bolt: BoltDraw
var _bolt_layer: CanvasLayer
## Frames since the last strike, and whether it is held lit (forced shots).
var _bolt_frame := 0
var _bolt_hold := false
## A strike shows on these frames after it lands: on, on, off, on, gone.
const BOLT_FRAMES: Array[bool] = [true, true, false, true]
var _mats: Dictionary = {} # CPUParticles3D -> ShaderMaterial
var _masks: Dictionary = {} # CPUParticles3D -> ground_mask it was made with


func setup(cam: CameraRig) -> void:
	camera = cam
	var air := Vector3(16.0, TOP * 0.5, 14.0)
	var mid := Vector3(0, TOP * 0.5, 0)
	# Rain: mostly ink strokes, a third pale ones, so it reads on turf and on sand.
	rain = _emitter("rain", 3400, 0.62, air, mid, false)
	_mat(rain, Mode.STROKE, {"color_a": Palette.INK[2], "color_b": Palette.RIME[4], "mix_b": 0.5, "length_px": Vector2(5, 8), "columns": 1.0, "ground_mask": 3})
	drizzle = _emitter("drizzle", 3600, 1.3, air, mid, false)
	_mat(drizzle, Mode.STROKE, {"color_a": Palette.RIME[4], "color_b": Palette.INK[3], "mix_b": 0.35, "length_px": Vector2(2, 3), "columns": 0.3, "ground_mask": 3})
	splash = _emitter("splash", 260, 0.16, Vector3(15.0, 0.02, 13.0), Vector3.ZERO, false)
	_mat(splash, Mode.TICK, {"color_a": Palette.RIME[4], "color_b": Palette.INK[3], "mix_b": 0.3, "columns": 0.75, "ground_mask": 3})
	rings = _emitter("rings", 220, 0.7, Vector3(15.0, 0.02, 13.0), Vector3.ZERO, false)
	_age_ramp(rings)
	_mat(rings, Mode.RING, {"color_a": Palette.RIME[4], "color_b": Palette.RIME[5], "mix_b": 0.4, "length_px": Vector2(3, 5), "columns": 0.6, "ground_mask": 3})
	# About one drop falling from each drip point at a time, over a short fall,
	# so a drip is a drop and never a line hanging under a crown.
	drips = _emitter("drips", 110, 0.26, Vector3.ZERO, Vector3.ZERO, false)
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	drips.top_level = true
	drips.gravity = Vector3(0, -9.0, 0)
	# Drips are water-blue, with only now and then a pale bead catching the light.
	_mat(drips, Mode.STROKE, {"color_a": Palette.RIME[3], "color_b": Palette.RIME[5], "mix_b": 0.12, "length_px": Vector2(1, 3), "slant": 0.0})
	for i in DustDevils.MAX:
		devils.append(_devil(i))
	hail = _emitter("hail", 900, 0.5, air, mid, false)
	_mat(hail, Mode.STROKE, {"color_a": Palette.RIME[5], "color_b": Palette.ASH[4], "mix_b": 0.3, "length_px": Vector2(2, 3), "columns": 0.4, "ground_mask": 3})
	# Snow: paper flecks, each held by one pixel of cold shade under it, so snow
	# reads pale against the snow already lying on the page and never as the
	# Burning's dark ash (docs/ART.md section 3).
	snow = _emitter("snow", 8000, 8.0, air, mid, true)
	# The rim is the snowfield's own blue shade, not ink: a flake is pale first
	# and held second, and only some of them (mix_b) are held at all.
	_mat(snow, Mode.FLECK, {"color_a": Palette.RIME[3], "color_b": Palette.RIME[5], "mix_b": 0.5, "length_px": Vector2(1, 2.4), "wander": 2.0, "highlight": 1.0, "ground_mask": 1})
	# Flakes near the eye: fewer, three pixels across, falling faster past.
	flurry = _emitter("flurry", 2200, 5.0, Vector3(16.0, 2.0, 14.0), Vector3(0, TOP * 0.8, 0), true)
	_mat(flurry, Mode.FLECK, {"color_a": Palette.RIME[3], "color_b": Palette.RIME[5], "mix_b": 0.7, "length_px": Vector2(2, 3), "wander": 3.0, "highlight": 1.0, "ground_mask": 1})
	# Blown snow: long low streaks racing along the ground in a blizzard and a
	# whiteout — paper on a cold shade rim, like the flecks, so the wind is drawn
	# pale over pale ground and a whiteout is streaks and not specks. A streak is
	# ten times the length of a fleck, so its rim is the palest shade in the ramp
	# and lies under only some of them: a rim as dark as a fleck's, drawn that
	# long and under every one, is a field of dark dashes (docs/ART.md section 3).
	spindrift = _emitter("spindrift", 2400, 2.5, Vector3(19.0, 1.0, 15.0), Vector3(0, 0.9, 0), true)
	_mat(spindrift, Mode.FLICK, {"color_a": Palette.RIME[4], "color_b": Palette.RIME[5], "mix_b": 1.0, "underline": 0.6, "length_px": Vector2(6, 14), "ground_mask": 1})
	# Ash: dark specks, a few scraps of burnt paper among them.
	ash = _emitter("ash", 2600, 12.0, air, mid, true)
	_mat(ash, Mode.FLECK, {"color_a": Palette.INK[1], "color_b": Palette.ASH[3], "mix_b": 0.3, "length_px": Vector2(1, 2), "wander": 3.0, "columns": 0.45, "ground_mask": 2})
	ember = _emitter("ember", 70, 5.0, Vector3(15.0, 1.5, 13.0), Vector3(0, 0.8, 0), true)
	_mat(ember, Mode.FLECK, {"color_a": Palette.EMBER[4], "color_b": Palette.EMBER[5], "mix_b": 0.3, "length_px": Vector2(1, 1), "wander": 1.0, "glow": 1.0, "ground_mask": 2})
	# Blown grit: dusky streaks with pale ones among them, so dust reads over pale
	# stone and over turf alike.
	drift = _emitter("drift", 3200, 3.0, Vector3(19.0, 2.2, 15.0), Vector3(0, 1.6, 0), true)
	_mat(drift, Mode.FLICK, {"color_a": Palette.SAND[1], "color_b": Palette.SAND[5], "mix_b": 0.55, "length_px": Vector2(5, 12)})
	# Heat: wavering lines, drawn darker than pale stone and paler than ash so
	# some always read.
	haze = _emitter("haze", 320, 4.0, Vector3(15.0, 0.6, 13.0), Vector3(0, 0.3, 0), true)
	_mat(haze, Mode.WAVE, {"color_a": Palette.SAND[1], "color_b": Palette.SAND[2], "mix_b": 0.5})
	flicks = _emitter("flicks", 18, 0.9, Vector3(16.0, 1.5, 14.0), Vector3(0, 1.0, 0), true)
	_mat(flicks, Mode.FLICK, {"color_a": Palette.LINEN[4], "color_b": Palette.INK[3], "mix_b": 0.4, "length_px": Vector2(6, 10)})
	wisps = _emitter("wisps", 40, 7.0, Vector3(15.0, 0.5, 13.0), Vector3(0, 0.7, 0), true)
	_mat(wisps, Mode.SPARK, {"color_a": Palette.SPRUCE[5], "color_b": Palette.RIME[5], "mix_b": 0.4, "length_px": Vector2(1, 2), "wander": 5.0, "glow": 1.0, "flicker_rate": 0.7})
	# The bolt is drawn on the page itself, in whole screen pixels, under the HUD.
	_bolt_layer = CanvasLayer.new()
	_bolt_layer.name = "bolt_layer"
	_bolt_layer.layer = -1
	# Drawn in the slate's units like every other page-space layer, or the bolt
	# would strike in the top-left ninth of the frame at the 1920x1080 base.
	UiBase.fit(_bolt_layer)
	add_child(_bolt_layer)
	bolt = BoltDraw.new()
	bolt.name = "bolt"
	bolt.camera = cam
	bolt.visible = false
	_bolt_layer.add_child(bolt)


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


## A particle's age over its life, 0..1, in its colour's green channel (the
## red channel is its random number): for marks that grow, like rings.
func _age_ramp(p: CPUParticles3D) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 0, 1, 1))
	g.set_color(1, Color(1, 1, 1, 1))
	p.color_ramp = g


## One dust devil: DEVIL_MARKS quads, each carrying three random numbers in its
## colour, spun into a column by precip.gdshader's SWIRL mode about the node.
func _devil(i: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := Rng.make(0xDE7, i)
	for m in DEVIL_MARKS:
		var col := Color(r.randf(), r.randf(), r.randf(), 1.0)
		var corners: Array[Vector3] = [Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.add_vertex(corners[k])
	var mi := MeshInstance3D.new()
	mi.name = "devil_%d" % i
	mi.mesh = st.commit()
	mi.top_level = true
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	var m := ShaderMaterial.new()
	m.shader = PRECIP
	m.render_priority = 10
	m.set_shader_parameter("mode", int(Mode.SWIRL))
	# Light sand grit, each grain with an ink shade pixel under it, so the whirl
	# reads over pale stone and over turf; the scuff round its foot is darker.
	m.set_shader_parameter("color_a", Palette.INK[3])
	m.set_shader_parameter("color_b", Palette.SAND[5])
	m.set_shader_parameter("mix_b", 0.8)
	m.set_shader_parameter("scuff_color", Palette.EARTH[2])
	m.set_shader_parameter("scuff_share", 0.3)
	m.set_shader_parameter("length_px", Vector2(1, 2))
	m.set_shader_parameter("underline", 1.0)
	m.set_shader_parameter("seed_phase", float(i) * 1.7)
	mi.material_override = m
	add_child(mi)
	return mi


## Where drips fall from this half-second (Drips.points), world space.
func set_drip_points(points: PackedVector3Array) -> void:
	if points.is_empty():
		return
	drips.emission_points = points


## amount 0..1 (Drips.amount); frozen: nothing drips in the snow.
func set_drips(amount: float, frozen: bool) -> void:
	var a := 0.0 if frozen or drips.emission_points.is_empty() else amount
	_drive(drips, a, Vector3(0, -1, 0), 0.8, {})


## devils: [{at: Vector3 ground point, life: 0..1, seed: int}] (DustDevils.at).
func set_devils(list: Array[Dictionary]) -> void:
	for i in devils.size():
		var mi := devils[i]
		if i >= list.size():
			mi.visible = false
			continue
		var d: Dictionary = list[i]
		mi.visible = true
		mi.global_position = d.at
		(mi.material_override as ShaderMaterial).set_shader_parameter("density", clampf(float(d.life), 0.0, 1.0))


func _mat(p: CPUParticles3D, mode: Mode, params: Dictionary) -> void:
	var m := ShaderMaterial.new()
	m.shader = PRECIP
	m.render_priority = 10
	m.set_shader_parameter("mode", int(mode))
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	p.material_override = m
	_mats[p] = m
	_masks[p] = int(params.get("ground_mask", 0))


## look: WeatherLook.compose() output; wind -1..1; focus: the camera's target.
func update(look: Dictionary, wind: float, focus: Vector3, delta: float) -> void:
	if camera != null:
		rotation.y = deg_to_rad(camera.yaw_now())
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
	var fine := lean * 0.5
	_drive(drizzle, float(look.get("drizzle", 0.0)), Vector3(fine, -1.0, 0.0), 7.5, {"slant": fine * SLANT_PER_LEAN})
	_drive(hail, float(look.hail), Vector3(lean * 0.5, -1.0, 0.0), 22.0, {"slant": lean * 0.5 * SLANT_PER_LEAN * 0.3})
	var whiteout := float(look.get("whiteout", 0.0))
	var blizzard := maxf(clampf(float(look.snow) - 0.8, 0.0, 0.2) * 5.0 * clampf(absf(wind) * 1.5, 0.0, 1.0), whiteout)
	# Snow comes in squalls: dense curtains sweep over with only a thin fall
	# between them. A whiteout is snow everywhere, no gaps.
	var curtains := 0.7 * (1.0 - whiteout)
	var gale := maxf(absf(wind), whiteout)
	_drive(snow, float(look.snow), Vector3(wind * 1.4 + whiteout * signf(wind + 0.001) * 1.2, -1.0, 0.0), 1.1 + gale * 2.2, {"wander": 2.0 * (1.0 - gale * 0.6), "columns": curtains})
	_drive(flurry, float(look.snow), Vector3(wind * 1.6 + whiteout * signf(wind + 0.001) * 1.4, -1.0, 0.0), 1.8 + gale * 2.6, {"columns": curtains})
	var blow_snow := signf(wind) if absf(wind) > 0.05 else 1.0
	_drive(spindrift, blizzard, Vector3(blow_snow, -0.04, 0.1), 7.0 + absf(wind) * 6.0, {"facing": blow_snow})
	_drive(ash, float(look.ash), Vector3(wind * 0.8, -1.0, 0.2), 0.55, {})
	# Embers rise off the burning ground, most of all through its furnace haze.
	_drive(ember, float(look.ash) * 0.8 + float(look.heat) * 0.15 + float(look.get("haze", 0.0)) * 0.7, Vector3(wind * 0.3, 1.0, 0.0), 0.5, {})
	_drive(haze, clampf(float(look.heat) + float(look.get("glare", 0.0)) * 0.5, 0.0, 1.0), Vector3(wind * 0.1, 1.0, 0.0), 0.3, {})
	var blow := signf(wind) if absf(wind) > 0.05 else 1.0
	var sand := float(look.dust)
	# Ash drifts along the ground in a wind, in dark streaks.
	var ash_drift := float(look.ash) * clampf((absf(wind) - 0.2) * 2.0, 0.0, 1.0) * 0.7
	var drift_amount := maxf(sand, ash_drift)
	var ashy := ash_drift / maxf(0.001, sand + ash_drift)
	_drive(drift, drift_amount, Vector3(blow, -0.06, 0.1), 5.0 + absf(wind) * 6.0, {
		"facing": blow,
		"color_a": Palette.SAND[1].lerp(Palette.ASH[1], ashy),
		"color_b": Palette.SAND[5].lerp(Palette.INK[2], ashy),
	})
	# The odd flick once the wind gets up; the flick is drawn with its head
	# leading, so it flips with the wind.
	var gusty := clampf((absf(wind) - 0.35) / 0.5, 0.0, 1.0) * (1.0 - float(look.fog))
	_drive(flicks, gusty, Vector3(blow, 0.0, 0.0), 9.0 + absf(wind) * 6.0, {"facing": blow})
	_drive(wisps, float(look.get("wisp", 0.0)), Vector3(wind * 0.2 + 0.1, 0.05, 0.1), 0.25, {})
	var wet := clampf(float(look.rain) + float(look.hail) * 0.5, 0.0, 1.0)
	_drive(splash, wet, Vector3(0, 1, 0), 0.25, {})
	splash.position.y = TerrainMesher.WATER_Y + 0.03 - focus.y if wet > 0.0 else 0.0
	var ringing := clampf(wet + float(look.get("drizzle", 0.0)) * 0.6, 0.0, 1.0)
	_drive(rings, ringing, Vector3(0, 1, 0), 0.0, {})
	rings.position.y = TerrainMesher.WATER_Y + 0.02 - focus.y if ringing > 0.0 else 0.0
	if not _bolt_hold and _bolt_frame < BOLT_FRAMES.size():
		bolt.visible = BOLT_FRAMES[_bolt_frame]
		_bolt_frame += 1
	elif not _bolt_hold:
		bolt.visible = false


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
	# Forced weather (shots) falls wherever it is asked for.
	m.set_shader_parameter("ground_mask", 0 if Weather.forced_kind != &"" else int(_masks[p]))
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	if not p.emitting:
		# Preprocess fills the air at once, so weather never starts as a curtain
		# falling from the top of the screen.
		p.visible = true
		p.emitting = true
		p.restart()


## A jagged bolt from the top of the screen to `at` (world space), seeded so
## shots repeat (BoltDraw). hold = stay lit until the next strike (forced shots).
func strike(at: Vector3, seed_value: int, hold: bool = false) -> void:
	var rise := 400.0
	if camera != null and camera.is_inside_tree():
		rise = maxf(240.0, camera.unproject_position(at).y - camera.unproject_position(at + Vector3(0, 26.0, 0)).y)
	bolt.set_strike(at, seed_value, rise)
	bolt.visible = true
	_bolt_frame = 0
	_bolt_hold = hold


## Let go of a held bolt. A hold is asked for to stage one still; when the
## staging ends the lightning has to leave the page with it, or it hangs in
## every frame after — in a noon glare, in another landscape, for ever.
func release_bolt() -> void:
	_bolt_hold = false
	_bolt_frame = BOLT_FRAMES.size()
	bolt.visible = false
