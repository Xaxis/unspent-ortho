extends SceneTree
## Every shader the game draws with, compiled by the real renderer and drawn: a
## SHADER ERROR on any of them fails tools/shaders.sh, and through it preflight.
## The gate's tests run on the dummy renderer, which compiles nothing, so a shader
## an include broke (sky_apply's PROJECTION_MATRIX, 2026-10-01) passed every test
## and showed only in the frames.
##   godot --path . -s tools/gd/shaders.gd
## Each *.gdshader under res://src goes on what its type draws on: a quad in front
## of a camera, a rect on the canvas, the sky. So do the shaders the game builds
## in code: MobFx's marks and the doors' iris. Prints "shaders: N built, N drawn"
## once FRAMES frames have drawn, and quits.

const ROOT := "res://src"
const FRAMES := 6
## MobFx._shader's keys: one shader each.
const MARKS: Array[StringName] = [&"over", &"flat", &"ground", &"among", &"swing", &"line", &"flash"]

var _frames := 0
var _built := 0


func _initialize() -> void:
	var paths: Array[String] = []
	_collect(ROOT, paths)
	paths.sort()
	var shaders: Array[Shader] = []
	for p: String in paths:
		var s := load(p) as Shader
		if s == null:
			printerr("SHADER ERROR: %s did not load" % p)
			continue
		shaders.append(s)
	for key: StringName in MARKS:
		shaders.append(MobFx._shader(key))
	shaders.append(load("res://src/systems/21_doors.gd").call(&"_iris") as Shader)
	_built = shaders.size()
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var n := 0
	for s: Shader in shaders:
		var m := ShaderMaterial.new()
		m.shader = s
		match s.get_mode():
			Shader.MODE_CANVAS_ITEM:
				var r := ColorRect.new()
				r.size = Vector2(32, 32)
				r.position = Vector2(32 * (n % 16), 32 * (n / 16))
				r.material = m
				canvas.add_child(r)
			Shader.MODE_SKY:
				var env := Environment.new()
				env.background_mode = Environment.BG_SKY
				env.sky = Sky.new()
				env.sky.sky_material = m
				var we := WorldEnvironment.new()
				we.environment = env
				world.add_child(we)
			Shader.MODE_PARTICLES:
				var p := GPUParticles3D.new()
				p.process_material = m
				p.draw_pass_1 = QuadMesh.new()
				p.position = Vector3(n % 8 - 3.5, n / 8 - 2.0, -6.0)
				world.add_child(p)
			Shader.MODE_FOG:
				var f := FogVolume.new()
				f.material = m
				f.position = Vector3(0, 0, -4)
				world.add_child(f)
			_:
				var q := MeshInstance3D.new()
				q.mesh = QuadMesh.new()
				q.material_override = m
				q.position = Vector3(n % 8 - 3.5, n / 8 - 2.0, -6.0)
				world.add_child(q)
		n += 1


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < FRAMES:
		return false
	print("shaders: %d built, %d drawn over %d frames" % [_built, _built, _frames])
	return true


func _collect(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gdshader"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
