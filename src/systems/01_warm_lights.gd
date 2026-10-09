extends GameSystem
## THE FIRST LOCAL LIGHT MUST NOT FREEZE THE GAME. On the web (WebGL through
## ANGLE on Metal) a shader program is built the first time it draws, 0.2 to 6 s
## cold, and Godot's Compatibility renderer has no precompile. A material has a
## program per LIGHT STATE: whether its base pass carries a directional light,
## an omni, a spot (only lights that cast no shadow go in the base pass), and
## whether an additive pass exists (a light casts). Doors, dusk, a fire and a
## tear each changed that state, and each froze a frame for seconds.
##
## **SO THE STATE NEVER CHANGES.** A shadowless directional light, an omni and
## a spot stand for the whole game, BLACK (they add nothing to any pixel), with
## a reach no scene leaves: every material is drawn with all three in its base
## pass on every frame, and the lights a scene brings only add to lists the
## program already has. Measured over tours/every-room.tour (tools/web.sh
## --programs, which fails a run on any program first drawn at an event): 0 at
## every door, by day and night, and at dusk; p95 frame cost lower than without
## (the lidded hall 21.0 against 23.7 ms, the tear 31.0 against 42.3, the open
## coast 22.5 against 25.6). They take two of the renderer's eight lights per
## object. They stand on Compatibility only: Forward+ has no program per light
## state, so on the desktop they built nothing and were shaded on every pixel.
##
## What stays is the one axis the lights cannot fix: what casts. The sun always
## does outdoors; a sealed room has nothing that does; a room's own lights cast
## too, and the renderer folds the first casting light into the base pass (a
## program of its own) and draws what it reaches into its shadow map (another).
## So the boot draws four states, HOLD frames each: the sun casting alone,
## NOTHING casting (every casting light held shadowless), the sun with one black
## spot casting over the player, and the sun as it casts when the eye looks out
## (four blended splits, under the seen sky: SkyLight.warm_look_out), which the
## shoulder's band switches to and nothing at the start draws. Alone, not all at once: with the spot
## over them the particles built only the spot's variant, and a hall's steam
## still froze its door (measured).
##
## A room, a landscape or a machine also draws materials nothing at the start
## does. Each is drawn here for the warm-up frames, on a small quad or a few
## particles at the player's feet, from the same builder its user calls (a
## material with the same settings is the same shader, so the same program),
## and kept for the life of the game: **A BUILT-IN MATERIAL'S SHADER LIVES ONLY
## WHILE ONE OF ITS MATERIALS DOES**, and freed with the quads a room built the
## very same programs again at its door (measured, byte for byte). A system
## with a shader of its own answers `warm(on)` and shows it for these frames
## (21_doors' iris).

## Frames each warm-up state is held, so it is drawn at least once whatever the
## boot's pacing; and how many states there are.
const HOLD := 3
const STATES := 4
## Past any world's edge from wherever the camera is, so the lights reach
## everything on every frame, the first one back outside a room included (the
## camera's focus is still the room's then).
const REACH := 100000.0

var _omni: OmniLight3D
var _spot: SpotLight3D
## Casts for the last HOLD frames only, then goes.
var _caster: SpotLight3D
var _quads: Array[MeshInstance3D] = []
## The warmed materials, held after the quads go, so their shaders stay built.
var _keep: Array[Material] = []
## What is drawn as particles, which is its own (instanced) program: the window
## motes, the hearth's smoke and sparks, the weather's grains.
var _motes: Array[Node3D] = []
var _frame := 0
## What only the eye level draws, shown in the look-out state alone and casting
## into the sun's four splits there: the meadow's instanced grass (its shadow
## program and its lit one), a colossus on the horizon, and a fall's ribbons.
var _eye: Array[GeometryInstance3D] = []
## Microseconds spent in each state's frames, and when the last frame began.
var _state_usec := PackedInt64Array([0, 0, 0, 0])
var _last_usec := 0
## Every light that cast when the warm-up began, to cast again after it.
var _casting: Array[Light3D] = []


func setup(g: Game) -> void:
	super.setup(g)
	# After the sky has set the sun for the frame, so the held shadows hold.
	process_priority = 1000
	_caster = SpotLight3D.new()
	_caster.name = "warm_caster"
	_caster.spot_range = 40.0
	_caster.spot_angle = 60.0
	var stand: Array[Light3D] = [_caster]
	# THE STAND-INS ARE COMPATIBILITY'S ALONE. Forward+ lights by clusters, so its
	# programs never change with the lights a scene brings; there the three only
	# put two lights in every cluster and a third in the directional loop, shaded
	# on every pixel to add nothing.
	if not Quality.forward_plus():
		_omni = OmniLight3D.new()
		_omni.name = "constant_omni"
		_omni.omni_range = REACH
		_spot = SpotLight3D.new()
		_spot.name = "constant_spot"
		_spot.spot_range = REACH
		_spot.spot_angle = 170.0
		var dir := DirectionalLight3D.new()
		dir.name = "constant_dir"
		dir.rotation = Vector3(-PI * 0.3, 0.4, 0.0)
		stand.append_array([_omni, _spot, dir])
	for l: Light3D in stand:
		l.light_energy = 1.0
		l.light_color = Color.BLACK
		l.light_volumetric_fog_energy = 0.0
		l.shadow_enabled = false
		g.add_child(l)
	_caster.shadow_enabled = true
	_keep = _room_materials()
	for m: Material in _keep:
		var q := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.05, 0.05)
		q.mesh = mesh
		q.material_override = m
		g.add_child(q)
		_quads.append(q)
	_motes.append((load("res://src/systems/21_doors.gd") as GDScript).call(&"motes_in_air") as Node3D)
	var steam := (load("res://src/models/interior/weapons_hall_model.gd") as GDScript).call(&"steam_material") as Material
	for m: Material in [FireModel.smoke_material(), FireModel.spark_material(), steam]:
		_keep.append(m)
		var p := CPUParticles3D.new()
		p.amount = 4
		p.mesh = FireModel.smoke_mesh()
		p.material_override = m
		_motes.append(p)
	# Custom shaders, each shared by every use of it (one Shader resource, one
	# program): a machine's glowing parts and its scan beam (machine_model), the
	# fight's marks, one shader per kind (MobFx._shader), a tear's glass column
	# (11_dome, hidden until a tear stands), a flier's shadow (flier_view) and
	# grass, whose own shadow program (it bends in the wind) a room's casting
	# lights need and the start's ground may not have under the caster.
	var shared: Array[Shader] = [
		preload("res://src/models/machines/part_glow.gdshader"),
		preload("res://src/models/machines/beam.gdshader"),
		preload("res://src/render/shaft_column.gdshader"),
		preload("res://src/render/depth/flier_shade.gdshader"),
		preload("res://src/render/foliage/grass.gdshader"),
	]
	for key: StringName in [&"over", &"ground", &"swing", &"line"]:
		shared.append(MobFx._shader(key))
	for sh: Shader in shared:
		var m := ShaderMaterial.new()
		m.shader = sh
		_keep.append(m)
		var quad := MeshInstance3D.new()
		quad.mesh = QuadMesh.new()
		quad.material_override = m
		_motes.append(quad)
	var precip := ShaderMaterial.new()
	precip.shader = WeatherView.PRECIP
	_keep.append(precip)
	var grains := CPUParticles3D.new()
	grains.amount = 4
	grains.mesh = FireModel.smoke_mesh()
	grains.material_override = precip
	_motes.append(grains)
	var devil := MeshInstance3D.new()
	devil.mesh = QuadMesh.new()
	devil.material_override = precip
	_motes.append(devil)
	for sh: Shader in [preload("res://src/render/foliage/grass.gdshader"), preload("res://src/render/falls/streak.gdshader")]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = QuadMesh.new()
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D.IDENTITY)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		_eye.append(mmi)
		_eye_material(mmi, sh)
	var colossus := MeshInstance3D.new()
	colossus.mesh = QuadMesh.new()
	_eye.append(colossus)
	_eye_material(colossus, preload("res://src/render/colossus/colossus.gdshader"))
	for n: GeometryInstance3D in _eye:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		n.visible = false
		g.add_child(n)
	for n: Node3D in _motes:
		# Alive on the first frame: particles not yet emitted draw nothing, and
		# the casting state lasts only HOLD frames.
		if n is CPUParticles3D:
			(n as CPUParticles3D).preprocess = 1.0
		g.add_child(n)


## True once the rack is gone. Until then it stands at the player's feet, so
## nothing may show the game before this: the boot page holds its cover
## (BootPage's draw stage) and a shot waits (main._shoot).
func done() -> bool:
	return _frame > HOLD * STATES


func _process(_delta: float) -> void:
	if game == null or game.player == null:
		return
	var focus: Vector3 = game.camera.target if game.camera != null else game.player.position
	if _omni != null:
		_omni.position = focus + Vector3(0.0, 3.0, 0.0)
		_spot.position = focus + Vector3(0.0, 40.0, 0.0)
		_spot.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	if _frame > HOLD * STATES:
		return
	var now := Time.get_ticks_usec()
	if _frame > 0:
		_state_usec[mini((_frame - 1) / HOLD, STATES - 1)] += now - _last_usec
	_last_usec = now
	if _frame == 0:
		# Every system is set up by the first frame; not all are at this one's setup.
		for sys: Node in game.systems:
			if sys.has_method(&"warm"):
				sys.call(&"warm", true)
		for n: Node in game.find_children("*", "Light3D", true, false):
			if n != _caster and (n as Light3D).shadow_enabled:
				_casting.append(n as Light3D)
	# The sun casting alone, then nothing casting, as in a sealed room, then the
	# sun and the caster; then every shadow back and the quads gone.
	var sealed := _frame >= HOLD and _frame < HOLD * 2
	for l: Light3D in _casting:
		if is_instance_valid(l):
			l.shadow_enabled = not sealed
	_caster.visible = _frame >= HOLD * 2 and _frame < HOLD * 3
	var looking := _frame >= HOLD * 3
	if looking and game.sky != null:
		game.sky.warm_look_out()
	for n: GeometryInstance3D in _eye:
		n.visible = looking
	_frame += 1
	if _frame > HOLD * STATES:
		# What the warm-up costs, per state, measured: the boot is the first thing
		# a player waits on, so each state has to earn its frames.
		print("boot warm lights: %s ms (sun, sealed, caster, look out)" % ", ".join(
			Array(_state_usec).map(func(u: int) -> String: return "%.0f" % (u / 1000.0))))
		_casting.clear()
		_caster.queue_free()
		for q: MeshInstance3D in _quads:
			q.queue_free()
		_quads.clear()
		for n: Node3D in _motes:
			n.queue_free()
		_motes.clear()
		for n: GeometryInstance3D in _eye:
			n.queue_free()
		_eye.clear()
		for sys: Node in game.systems:
			if sys.has_method(&"warm"):
				sys.call(&"warm", false)
		return
	var at: Vector3 = game.player.position
	_caster.position = at + Vector3(0.0, 12.0, 0.0)
	_caster.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	for i in _quads.size():
		_quads[i].position = at + Vector3(0.1 * float(i), 0.05, 0.0)
	for n: Node3D in _motes:
		n.position = at + Vector3(0.0, 0.5, 0.0)
	for n: GeometryInstance3D in _eye:
		n.position = at + Vector3(0.0, 0.5, 0.0)


## One of the eye level's shaders on `n`, kept past the warm-up (a shader's
## programs live only while one of its materials does).
func _eye_material(n: GeometryInstance3D, sh: Shader) -> void:
	var m := ShaderMaterial.new()
	m.shader = sh
	_keep.append(m)
	n.material_override = m


## What a room draws that nothing outside does, from the builders the rooms use.
static func _room_materials() -> Array[Material]:
	var out: Array[Material] = []
	var doors := load("res://src/systems/21_doors.gd") as GDScript
	out.append(doors.call(&"beam_template") as Material)
	out.append(doors.call(&"mote_material") as Material)
	out.append(WorldView.void_material())
	out.append((load("res://src/systems/15_lights.gd") as GDScript).call(&"glow_material") as Material)
	out.append((load("res://src/models/interior/cottage_model.gd") as GDScript).call(&"_unshaded") as Material)
	out.append((load("res://src/models/interior/weapons_hall_model.gd") as GDScript).call(&"steam_material") as Material)
	out.append(FireModel.smoke_material())
	out.append(FireModel.spark_material())
	return out
