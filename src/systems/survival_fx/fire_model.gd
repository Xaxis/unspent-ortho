class_name FireModel
extends Node3D
## A burning fire, drawn whole: a low ring of hearth stones round a floor of ash,
## a bed of embers under charred sticks leant together, flame tongues that rise
## well clear of the stones and flicker in stepped frames like a hand-drawn loop,
## a stipple of smoke rising and thinning as it leans with the air, the odd spark
## as a bright pixel, and a light whose pool grows as the day goes.
##
## The hearth is MADE (world material, strata strokes); flames and embers are
## EMBER, the one emitter in the palette, never hatched (docs/ART.md §5-6); smoke
## and sparks are marks (SurvivalMarks). The light is an OmniLight3D, which
## world.gdshader steps into pools. Pass hearth = false where the FIRE prop's own
## model already draws the stones.
##
##   var f := FireModel.new(); f.build(world_material, prop.id); add_child(f)
##   f.darkness = 0..1     # 0 full day (no pool), 1 night (full pool)

## Drawn frames per second: flames and smoke move on these steps only.
const FPS := 10.0
const SMOKE := 22
## Drawn frames of the flame's silhouette.
const FRAMES := 5
## Degrees the flame's plane leans back from upright toward the camera.
const FLAME_LEAN := 35.0
## Screen pixels: the radius of a smoke dot and a spark, whatever the zoom.
const DOT_PX := 1.0
## The whole fire is drawn a little larger than its footprint: it is the one warm
## thing a person makes, and has to read from across the screen.
const SIZE := 1.15
const SPARKS := 3
const LIGHT_COLOR := Color(1.0, 0.5, 0.18)
const LIGHT_RANGE := 4.5
const SMOKE_LIFE := 3.2
## Radius of the hearth ring, and how high its stones stand: the flame clears them.
const HEARTH_RADIUS := 0.4
const HEARTH_HEIGHT := 0.22

## 0 in daylight, 1 at night. Scales the light's energy; flames are always lit.
var darkness := 1.0
## Where the smoke leans, tiles/s at the top of its rise.
var wind := Vector2(0.28, -0.12)

var _t := 0.0
var _acc := 0.0
var _flame: MeshInstance3D
var _frames: Array[ArrayMesh] = []
var _frame := 0
var _step := -1
var _light: OmniLight3D
var _smoke: SurvivalMarks.Pool
var _sparks: SurvivalMarks.Pool
var _seed := 0

static var _glow: ShaderMaterial


static func glow_material() -> ShaderMaterial:
	if _glow == null:
		_glow = ShaderMaterial.new()
		_glow.shader = preload("res://src/render/world.gdshader")
		_glow.set_shader_parameter("emission_strength", 0.85)
	return _glow


func build(world_mat: Material, seed_value: int, hearth: bool = true) -> void:
	_seed = seed_value
	_t = Rng.hash01(seed_value, 3) * 10.0
	var glow := glow_material()
	if hearth:
		var ring := MeshKit.new()
		ring.style = Ink.CONTOUR
		ring.style2 = Ink.CONTOUR
		# The ash floor inside the ring, then the stones, each its own size and lean.
		ring.prism(0, -0.03, 0, HEARTH_RADIUS - 0.02, 0.012, HEARTH_RADIUS - 0.04, 10, Palette.ASH[1], Palette.ASH[1], 0.2)
		for i in 9:
			var a := float(i) / 9.0 * TAU + (Rng.hash01(seed_value, i, 21) - 0.5) * 0.3
			var r := HEARTH_RADIUS + (Rng.hash01(seed_value, i, 22) - 0.5) * 0.06
			var sz := 0.09 + Rng.hash01(seed_value, i, 23) * 0.04
			var col := Palette.STONE[3] if i % 3 == 0 else (Palette.STONE[2] if i % 3 == 1 else Palette.SLATE[3])
			ring.rock(cos(a) * r, -0.04, sin(a) * r, sz, HEARTH_HEIGHT * (0.7 + Rng.hash01(seed_value, i, 24) * 0.4), seed_value * 11 + i, col, 5)
		_add(self, ring, world_mat)
	# Fire is light: embers and flames are never hatched.
	var bed := MeshKit.new()
	bed.style = Ink.NONE
	bed.style2 = Ink.NONE
	bed.rock(0, -0.02, 0, 0.25, 0.08, seed_value, Palette.EMBER[2], 8)
	for i in 7:
		var a := float(i) * 2.39996 + Rng.hash01(seed_value, i, 31)
		var r := 0.07 + Rng.hash01(seed_value, i, 32) * 0.14
		bed.rock(cos(a) * r, 0.01, sin(a) * r, 0.045, 0.06, seed_value + 40 + i, Palette.EMBER[4] if i % 2 else Palette.EMBER[3], 4)
	_add(self, bed, glow)
	# Charred sticks leant together over the embers.
	var sticks := MeshKit.new()
	for i in 4:
		var a := float(i) / 4.0 * TAU + 0.35 + (Rng.hash01(seed_value, i, 33) - 0.5) * 0.4
		var foot := Vector3(cos(a) * 0.32, 0.01, sin(a) * 0.32)
		var top := Vector3(cos(a + 2.2) * 0.04, 0.3 + Rng.hash01(seed_value, i, 34) * 0.06, sin(a + 2.2) * 0.04)
		sticks.strut(foot, top, 0.036, 4, Palette.EARTH[1] if i % 2 else Palette.INK[2])
	_add(self, sticks, world_mat)
	# The flame is drawn, not modelled: a flat silhouette of licking tongues held
	# square to the page, in FRAMES hand-drawn frames that the fire flips between.
	_flame = MeshInstance3D.new()
	_flame.material_override = glow
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.position = Vector3(0, 0.05, 0)
	add_child(_flame)
	for f in FRAMES:
		_frames.append(_flame_frame(seed_value, f))
	_flame.mesh = _frames[0]
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 0.8
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.8, 0)
	add_child(_light)
	_smoke = SurvivalMarks.Pool.new(SurvivalMarks.dot(), SMOKE, SurvivalMarks.material(), self)
	_sparks = SurvivalMarks.Pool.new(SurvivalMarks.dot(), SPARKS, SurvivalMarks.material(), self)
	scale = Vector3.ONE * SIZE
	_draw()


## World units across `n` screen pixels under the camera drawing this fire.
func _px(n: float) -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var h := cam.size if cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL else 14.0
	return n * h / 360.0 / SIZE


## One drawn frame of the flame, in the XY plane facing +Z: an outer tongue shape
## of ember orange with five licking tips, a yellower heart inside it and a white-hot
## core at the foot. Every frame's tips differ, and the tallest always clears the hearth.
static func _flame_frame(s: int, frame: int) -> ArrayMesh:
	var k := MeshKit.new()
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	var layers := [[1.0, Palette.EMBER[3], 0.0], [0.68, Palette.EMBER[4], 0.012], [0.36, Palette.EMBER[5], 0.024]]
	for layer: Array in layers:
		var sc: float = layer[0]
		var col: Color = layer[1]
		var z: float = layer[2]
		var pts: Array[Vector3] = []
		var tips := 5
		var half := 0.24 * sc
		pts.append(Vector3(-half, 0.0, z))
		for i in tips:
			var u := (float(i) + 0.5) / tips
			# Tall in the middle, short at the sides, each tip thrown a little off true.
			var mid := 1.0 - absf(u - 0.5) * 1.3
			var h := (0.34 + 0.56 * mid * (0.7 + Rng.hash01(s, frame, i, 1) * 0.5)) * (0.75 + 0.25 * sc)
			var x := (u - 0.5) * 2.0 * half * 0.9 + (Rng.hash01(s, frame, i, 2) - 0.5) * 0.06 * sc
			pts.append(Vector3(x, h * sc + 0.02 * (1.0 - sc), z))
			if i < tips - 1:
				# The notch between two tips, down a way into the body of the flame.
				var nu := (float(i) + 1.0) / tips
				var nx := (nu - 0.5) * 2.0 * half * 0.85
				var nh := h * sc * (0.45 + Rng.hash01(s, frame, i, 3) * 0.2)
				pts.append(Vector3(nx, nh, z))
		pts.append(Vector3(half, 0.0, z))
		var centre := Vector3(0.0, 0.08 * sc, z)
		# Counter-clockwise seen from the eye (+Z): right to left over the top.
		for i in pts.size() - 1:
			k.tri(centre, pts[i + 1], pts[i], col)
		k.tri(centre, Vector3(0.0, -0.02, z), pts[pts.size() - 1], col)
		k.tri(centre, pts[0], Vector3(0.0, -0.02, z), col)
	return k.build()


func _process(delta: float) -> void:
	step(delta)


## Hold the flame's plane square to the camera's heading, leant back part of the way
## toward the eye so a steep view does not squash it: a figure cut from the page.
func _face_page() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var yaw := cam.global_rotation.y if cam != null else deg_to_rad(45.0)
	var r := Vector3(-deg_to_rad(FLAME_LEAN), yaw, 0.0)
	if _flame.is_inside_tree():
		_flame.global_rotation = r
	else:
		_flame.rotation = r


## Flicker from incommensurate sines: steady enough to read, never visibly looping.
static func flick(t: float, i: int) -> float:
	return 0.5 + 0.22 * sin(t * 7.3 + i * 1.7) + 0.16 * sin(t * 12.9 + i * 4.1) + 0.12 * sin(t * 3.1 + i * 2.3)


func step(delta: float) -> void:
	_t += delta
	_acc += delta
	# The light breathes smoothly; the drawing changes only on its frames.
	_light.light_energy = darkness * (1.0 + flick(_t * 0.8, 9) * 0.25)
	_light.visible = darkness > 0.02
	if _acc < 1.0 / FPS:
		return
	_acc = fmod(_acc, 1.0 / FPS)
	_draw()


func _draw() -> void:
	var t := floorf(_t * FPS) / FPS
	# Flip to a frame that is never the one just shown, and breathe its height a little.
	var step := floori(_t * FPS)
	if step != _step:
		_step = step
		_frame = (_frame + 1 + floori(Rng.hash01(_seed, step, 13) * (FRAMES - 1))) % FRAMES
	_flame.mesh = _frames[_frame]
	_flame.scale = Vector3(1.0, 0.85 + flick(t, 0) * 0.3, 1.0)
	_face_page()
	var lean := Vector3(wind.x, 0.0, wind.y)
	# Smoke: pale dots that rise, sway and lean, spread as they go, and drop out
	# one by one; what is left near the top is a few specks, the way a pen fades it.
	for i in SMOKE:
		var age := fposmod(t + i * (SMOKE_LIFE / SMOKE), SMOKE_LIFE)
		var k := age / SMOKE_LIFE
		var cycle := floori((t + i * (SMOKE_LIFE / SMOKE)) / SMOKE_LIFE)
		if Rng.hash01(_seed, i, cycle, 5) < k * k * 1.1:
			_smoke.hide(i)
			continue
		# One wavering thread of smoke that every dot follows, loosening as it climbs.
		var rise := 0.95 + age * 0.62
		var thread := Vector3(sin(rise * 3.1 - t * 1.3) * 0.1, 0.0, cos(rise * 2.3 - t * 0.9) * 0.07) * (0.3 + k)
		var side := Vector3(Rng.hash01(_seed, i, cycle, 6) - 0.5, 0.0, Rng.hash01(_seed, i, cycle, 7) - 0.5) * (0.03 + 0.16 * k * k)
		var pos := Vector3(0.0, rise, 0.0) + thread + side + lean * age * age * 0.28
		# Pen stipple low down where the smoke is thick (ink on a pale ground, paper on a
		# dark one), and specks of ash as it thins.
		var col := SurvivalMarks.CONTRAST if Rng.hash01(_seed, i, cycle, 8) > k * 0.8 else Palette.ASH[4]
		_smoke.put(i, pos, _px(DOT_PX * (0.9 + 0.5 * Rng.hash01(_seed, i, cycle, 9))), col)
	# Sparks: not a stream. Now and then one bright pixel jumps up and is gone.
	for i in SPARKS:
		var span := 0.7 + Rng.hash01(_seed, i) * 0.9
		var run := t * (0.9 + i * 0.17) + i * 0.37
		var age := fposmod(run, span)
		var cycle := floori(run / span)
		if Rng.hash01(_seed, i, cycle, 11) > 0.45 or age > 0.45:
			_sparks.hide(i)
			continue
		var dir := Vector3(Rng.hash01(_seed, i, cycle) - 0.5, 0.0, Rng.hash01(_seed, i, cycle, 12) - 0.5)
		var pos := dir * 0.4 * age + Vector3(0, 0.7 + age * 1.8, 0) + lean * age
		var col := Palette.EMBER[5] if i % 2 else Palette.LENS[3]
		_sparks.put(i, pos, _px(DOT_PX), Color(col.r, col.g, col.b, 0.0))


func _add(parent: Node3D, k: MeshKit, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## How dark it is for a fire's light at world hour h: none by day, a little at
## dusk, full through the night. (source NightFall: 20:00-21:00 in, 04:30-06:00 out,
## started an hour early so the pool is already there when the light goes gold)
static func darkness_at(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= 12.0:
		return clampf((h - 19.0) / 2.0, 0.0, 1.0)
	return clampf((6.5 - h) / 2.0, 0.0, 1.0)
