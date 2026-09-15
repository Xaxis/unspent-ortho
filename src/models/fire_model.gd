class_name FireModel
extends Node3D
## A burning fire, drawn: a bed of embers under charred sticks, flame tongues
## that flicker in stepped frames like a hand-drawn loop, a stipple of smoke
## rising and thinning as it leans with the air, the odd spark as a bright pixel,
## and a light whose pool grows as the day goes. It is the flame only; the hearth
## or ring of stones under it is the FIRE prop's own model (landscape).
##
## Flames and embers are EMBER, the one emitter in the palette, on the world
## shader with emission so they read at night; smoke and sparks are marks
## (SurvivalMarks), never ringed by the outline. The light is an OmniLight3D,
## which world.gdshader steps into pools.
##
##   var f := FireModel.new(); f.build(world_material, prop.id); add_child(f)
##   f.darkness = 0..1     # 0 full day (no pool), 1 night (full pool)

## Drawn frames per second: flames and smoke move on these steps only.
const FPS := 10.0
const SMOKE := 26
const SPARKS := 3
const LIGHT_COLOR := Color(1.0, 0.5, 0.18)
const LIGHT_RANGE := 4.5
const SMOKE_LIFE := 3.2

## 0 in daylight, 1 at night. Scales the light's energy; flames are always lit.
var darkness := 1.0
## Where the smoke leans, tiles/s at the top of its rise.
var wind := Vector2(0.28, -0.12)

var _t := 0.0
var _acc := 0.0
var _tongues: Array[Node3D] = []
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


func build(world_mat: Material, seed_value: int) -> void:
	_seed = seed_value
	_t = Rng.hash01(seed_value, 3) * 10.0
	var glow := glow_material()
	var bed := MeshKit.new()
	bed.rock(0, -0.03, 0, 0.3, 0.1, seed_value, Palette.EMBER[2], 7)
	bed.rock(0.06, 0.0, -0.04, 0.12, 0.08, seed_value + 1, Palette.EMBER[3], 5)
	_add(self, bed, glow)
	var sticks := MeshKit.new()
	sticks.strut(Vector3(-0.26, 0.03, -0.1), Vector3(0.24, 0.12, 0.1), 0.04, 4, Palette.INK[3])
	sticks.strut(Vector3(-0.1, 0.12, 0.26), Vector3(0.1, 0.03, -0.24), 0.04, 4, Palette.EARTH[1])
	sticks.strut(Vector3(0.22, 0.02, 0.2), Vector3(-0.02, 0.16, 0.0), 0.035, 4, Palette.INK[2])
	_add(self, sticks, world_mat)
	# Three tongues round a taller core. Each is a jagged, leaning spike, not a cone:
	# a five-point base with alternate points pulled in, and a tip pushed off true.
	for i in 4:
		var t := Node3D.new()
		var a := float(i) / 3.0 * TAU + 0.4
		t.position = Vector3(cos(a) * 0.09, 0.05, sin(a) * 0.09) if i < 3 else Vector3(0, 0.06, 0)
		t.rotation.y = a
		var k := MeshKit.new()
		var r := 0.14 if i < 3 else 0.1
		var h := 0.5 if i < 3 else 0.62
		_tongue(k, r, h, Palette.EMBER[3] if i != 1 else Palette.EMBER[4], Palette.EMBER[5] if i == 3 else Palette.EMBER[4], seed_value + i)
		_add(t, k, glow)
		add_child(t)
		_tongues.append(t)
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 0.8
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.7, 0)
	add_child(_light)
	_smoke = SurvivalMarks.Pool.new(SurvivalMarks.dot(), SMOKE, SurvivalMarks.material(), self)
	_sparks = SurvivalMarks.Pool.new(SurvivalMarks.dot(), SPARKS, SurvivalMarks.material(), self)
	_draw()


## A flame tongue: an outer spike and an inner, brighter one, both leaning.
static func _tongue(k: MeshKit, r: float, h: float, outer: Color, inner: Color, s: int) -> void:
	for layer in 2:
		var rr := r * (1.0 if layer == 0 else 0.55)
		var hh := h * (1.0 if layer == 0 else 0.7)
		var tip := Vector3((Rng.hash01(s, 1) - 0.3) * rr * 0.9, hh, (Rng.hash01(s, 2) - 0.5) * rr * 0.6)
		var ring: Array[Vector3] = []
		for j in 6:
			var a := float(j) / 6.0 * TAU + Rng.hash01(s, j, 3) * 0.3
			var jr := rr * (1.0 if j % 2 == 0 else 0.55)
			ring.append(Vector3(cos(a) * jr, 0.02 + (0.06 if j % 2 else 0.0) * hh, sin(a) * jr))
		var col := outer if layer == 0 else inner
		for j in 6:
			k.tri(tip, ring[(j + 1) % 6], ring[j], col)


func _process(delta: float) -> void:
	step(delta)


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
	for i in _tongues.size():
		var fl := flick(t, i)
		_tongues[i].scale = Vector3(0.85 + fl * 0.3, 0.5 + fl * 0.95, 0.85 + fl * 0.3)
		_tongues[i].rotation.x = sin(t * 2.3 + i) * 0.18
		_tongues[i].rotation.z = cos(t * 1.9 + i * 2.0) * 0.18
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
		var rise := 0.55 + age * 0.62
		var thread := Vector3(sin(rise * 3.1 - t * 1.3) * 0.1, 0.0, cos(rise * 2.3 - t * 0.9) * 0.07) * (0.3 + k)
		var side := Vector3(Rng.hash01(_seed, i, cycle, 6) - 0.5, 0.0, Rng.hash01(_seed, i, cycle, 7) - 0.5) * (0.03 + 0.16 * k * k)
		var pos := Vector3(0.0, rise, 0.0) + thread + side + lean * age * age * 0.28
		# Ink stipple low down where the smoke is thick, paler specks as it thins.
		var col := Palette.INK[4] if Rng.hash01(_seed, i, cycle, 8) > k else Palette.ASH[3]
		_smoke.put(i, pos, 0.032 + 0.018 * Rng.hash01(_seed, i, cycle, 9), col)
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
		var pos := dir * 0.4 * age + Vector3(0, 0.45 + age * 1.8, 0) + lean * age
		var col := Palette.EMBER[5] if i % 2 else Palette.LENS[3]
		_sparks.put(i, pos, 0.03, Color(col.r, col.g, col.b, 0.0))


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


static func gallery() -> Array:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/render/world.gdshader")
	var f := FireModel.new()
	f.build(mat, 7)
	f.darkness = 0.0 # its pool would light every model on the plinth
	return [{"name": "fire (flame)", "node": f}]
