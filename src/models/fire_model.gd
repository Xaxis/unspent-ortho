class_name FireModel
extends Node3D
## A burning fire, animated: an ember bed with two charred sticks, four flame
## tongues that flicker, sparks going up, smoke leaning with the air, and a
## light whose pool grows as the day goes. It is the flame only; the hearth or
## ring of stones under it is the FIRE prop's own model (landscape).
##
## Flames and embers are EMBER, the one emitter in the palette; they use the
## world shader with emission so they stay bright at night. The light is an
## OmniLight3D, which world.gdshader quantises into stepped pools.
##
##   var f := FireModel.new(); f.build(world_material, prop.id); add_child(f)
##   f.darkness = 0..1     # 0 full day (no pool), 1 night (full pool)

const SMOKE := 8
const SPARKS := 6
const LIGHT_COLOR := Color(1.0, 0.5, 0.18)
const LIGHT_RANGE := 4.5

## 0 in daylight, 1 at night. Scales the light's energy; flames are always lit.
var darkness := 1.0
## Where the smoke leans, tiles/s at the top of its rise.
var wind := Vector2(0.28, -0.12)

var _t := 0.0
var _tongues: Array[Node3D] = []
var _light: OmniLight3D
var _smoke: MultiMesh
var _sparks: MultiMesh
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
	var cols: Array[Color] = [Palette.EMBER[3], Palette.EMBER[4], Palette.EMBER[3], Palette.EMBER[5]]
	for i in 4:
		var t := Node3D.new()
		var a := float(i) / 3.0 * TAU + 0.4
		t.position = Vector3(cos(a) * 0.08, 0.06, sin(a) * 0.08) if i < 3 else Vector3(0, 0.08, 0)
		var k := MeshKit.new()
		if i < 3:
			k.prism(0, 0, 0, 0.13, 0.6, 0.0, 4, cols[i], Color(0, 0, 0, 0), a)
		else:
			k.prism(0, 0, 0, 0.08, 0.42, 0.0, 4, cols[i], Color(0, 0, 0, 0), 0.3)
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
	var puff := MeshKit.new()
	puff.block(0, -0.05, 0, 0.1, 0.1, 0.1, Color.WHITE)
	_smoke = _pool(puff, SMOKE, world_mat)
	var spark := MeshKit.new()
	spark.block(0, 0, 0, 0.035, 0.035, 0.035, Color.WHITE)
	_sparks = _pool(spark, SPARKS, glow)
	step(0.0)


func _process(delta: float) -> void:
	step(delta)


## Flicker from incommensurate sines: steady enough to read, never visibly looping.
static func flick(t: float, i: int) -> float:
	return 0.5 + 0.22 * sin(t * 7.3 + i * 1.7) + 0.16 * sin(t * 12.9 + i * 4.1) + 0.12 * sin(t * 3.1 + i * 2.3)


func step(delta: float) -> void:
	_t += delta
	var t := _t
	for i in _tongues.size():
		var fl := flick(t, i)
		_tongues[i].scale = Vector3(0.8 + fl * 0.35, 0.55 + fl * 0.9, 0.8 + fl * 0.35)
		_tongues[i].rotation = Vector3(sin(t * 2.3 + i) * 0.2, t * (0.6 + i * 0.25), cos(t * 1.9 + i * 2.0) * 0.2)
	_light.light_energy = darkness * (1.0 + flick(t * 0.8, 9) * 0.4)
	_light.visible = darkness > 0.02
	# Smoke: a thin column of pale wisps that rise, sway, lean with the air and
	# shrink away; small enough that the ink outline reads them as smoke, not stones.
	var life := 2.6
	var lean := Vector3(wind.x, 0.0, wind.y)
	for i in SMOKE:
		var age := fposmod(t + i * (life / SMOKE), life)
		var k := age / life
		var sway := Vector3(sin(t * 1.7 + i * 2.1) * 0.08 * k, 0.0, cos(t * 1.3 + i) * 0.06 * k)
		var pos := Vector3(0.0, 0.6 + age * 0.85, 0.0) + sway + lean * age * age * 0.3
		var s := (1.0 - k) * (0.35 + 0.65 * sin(minf(k * 4.0, 1.0) * PI * 0.5))
		_smoke.set_instance_transform(i, Transform3D(Basis(Vector3.UP, i * 1.3 + age * 0.4).scaled(Vector3.ONE * s), pos))
		_smoke.set_instance_color(i, Palette.ASH[4].lerp(Palette.ASH[3], k))
	for i in SPARKS:
		var span := 0.9 + Rng.hash01(_seed, i) * 0.7
		var run := t * (0.8 + i * 0.13) + i * 0.37
		var age := fposmod(run, span)
		var cycle := floorf(run / span)
		var dir := Vector3(Rng.hash01(_seed, i, int(cycle)) - 0.5, 0.0, Rng.hash01(_seed, i, int(cycle) + 7) - 0.5)
		var pos := dir * 0.5 * age + Vector3(0, 0.3 + age * 1.4, 0) + lean * age * 0.5
		var s := clampf(1.0 - age / span, 0.0, 1.0)
		_sparks.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), pos))
		_sparks.set_instance_color(i, Palette.EMBER[5] if i % 2 else Palette.EMBER[4])


func _add(parent: Node3D, k: MeshKit, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _pool(k: MeshKit, n: int, mat: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = k.build()
	mm.instance_count = n
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 64.0
	add_child(mmi)
	return mm


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
