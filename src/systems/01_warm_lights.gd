extends GameSystem
## THE FIRST LOCAL LIGHT MUST NOT FREEZE THE GAME. A material has a shader
## program for each set of lights its base pass is drawn with, and on the web
## (WebGL through ANGLE on Metal) each program is built the first time it
## draws: a door stood 3 to 8 s on one frame, the first dusk too. Godot's
## Compatibility renderer has no precompile; its answer is to draw everything
## once, in each state, while the game is loading.
##
## WHICH STATES, measured (tools/web.sh --programs over tours/first-lights.tour,
## and the lights live in each). A program is chosen by whether its base pass
## carries a directional light, an omni, a spot (the base pass takes only the
## lights that cast no shadow) and whether an additive pass exists (a light
## casts; the sun always does). By day the only directional lights are the
## casting sun and the figures' own, so the boot's base pass has none; the
## fire brings an omni into it. At dusk the sky adds a second, shadowless
## directional light, and the base pass takes it, alone and with the lamps'
## omnis (36 programs); a door brings a room's spots as well (27 more), and a
## room where nothing casts, the same with no additive pass. So while the boot
## page still covers the game this draws everything by the player's start in
## each of those states, a few frames each: a faint shadowless directional
## light beside the sun, then a faint omni, then a spot; and each again with
## NOTHING casting, as in a room (the sun and every light that casts, the
## lantern too, are held shadowless for those frames). Then every shadow is put
## back.
##
## A room also draws materials nothing outside does: its windows' beams and the
## motes in them, the dark under the pocket, its unshaded panes and glow, a
## hall's steam, and its hearth's smoke and sparks, which outdoors are drawn
## with an additive pass and in a room without one.
## Each is drawn here too, on a small quad at the player's feet, from the same
## builder the room uses: a material with the same settings is the same shader,
## so it is the same program. The weather's rain, snow and dust share one
## shader, drawn here both ways its layers are (particles, and a devil's mesh).
## A system with a shader of its own answers `warm(on)` and shows it for these
## frames (21_doors' iris). **A BUILT-IN MATERIAL'S SHADER LIVES ONLY WHILE ONE
## OF ITS MATERIALS DOES.** Godot shares a
## built-in material's shader among every material with its settings and frees
## it with the last of them; freed with the warm-up's quads, a room built the
## very same programs again at its door (measured, byte for byte). So the
## materials are kept for the life of the game.

## Frames each state is held, so it is drawn at least once whatever the boot's
## pacing.
const HOLD := 3
## Per step: [something casts, a shadowless directional, omni, spot]. Every
## combination a scene can make: while something casts (outdoors, the sun
## always does), each of the three in or out of the base pass; where nothing
## casts (a room), the directional is always there. A machines' hall lights
## by spots alone and a shut landscape's tears by spots at noon, so a set
## taken only from a cottage and dusk still froze at a hall's door (measured).
const STEPS: Array[Array] = [
	[true, false, false, false], [true, false, true, false], [true, false, false, true], [true, false, true, true],
	[true, true, false, false], [true, true, true, false], [true, true, false, true], [true, true, true, true],
	[false, true, false, false], [false, true, true, false], [false, true, false, true], [false, true, true, true],
]
## Faint: a light the renderer draws with, never one a player sees.
const ENERGY := 0.02
const REACH := 14.0

var _omni: OmniLight3D
var _spot: SpotLight3D
var _dir: DirectionalLight3D
var _quads: Array[MeshInstance3D] = []
## The room materials, held after the quads go, so their shaders stay built.
var _keep: Array[Material] = []
## What a room draws as particles, which is its own (instanced) program: the
## window motes, the hearth's smoke and sparks.
var _motes: Array[Node3D] = []
var _frame := 0
## Every light that cast when the warm-up began, to cast again after it.
var _casting: Array[Light3D] = []


func setup(g: Game) -> void:
	super.setup(g)
	# After the sky has set the sun for the frame, so the shadowless sun holds.
	process_priority = 1000
	_omni = OmniLight3D.new()
	_omni.name = "warm_omni"
	_omni.omni_range = REACH
	_spot = SpotLight3D.new()
	_spot.name = "warm_spot"
	_spot.spot_range = REACH
	_spot.spot_angle = 70.0
	_dir = DirectionalLight3D.new()
	_dir.name = "warm_dir"
	_dir.rotation = Vector3(-PI * 0.3, 0.4, 0.0)
	for l: Light3D in [_omni, _spot, _dir]:
		l.light_energy = 1.0
		l.light_color = Color.BLACK
		l.light_volumetric_fog_energy = 0.0
		l.shadow_enabled = false
		l.visible = true
		g.add_child(l)
	_omni.omni_range = 100000.0
	_spot.spot_range = 100000.0
	_spot.spot_angle = 170.0
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
	# The shaders of a machine and a fight, each shared by every use of it: a
	# machine's glowing parts and its scan beam (machine_model), and the fight's
	# marks, one shader per kind (MobFx._shader). A hall's guards bring them
	# into a room's light.
	var shared: Array[Shader] = [
		preload("res://src/models/machines/part_glow.gdshader"),
		preload("res://src/models/machines/beam.gdshader"),
	]
	for key: StringName in [&"over", &"flat", &"ground", &"among", &"swing", &"line"]:
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
	for n: Node3D in _motes:
		g.add_child(n)


func _process(_delta: float) -> void:
	if game == null or game.player == null:
		return
	if _frame == 0:
		# Every system is set up by the first frame; not all are at this one's setup.
		for sys: Node in game.systems:
			if sys.has_method(&"warm"):
				sys.call(&"warm", true)
		for n: Node in game.find_children("*", "Light3D", true, false):
			if (n as Light3D).shadow_enabled:
				_casting.append(n as Light3D)
	# The second half of the warm-up: nothing casting, as in a sealed room, so
	# the programs without an additive pass are built too.
	for l: Light3D in _casting:
		if is_instance_valid(l):
			l.shadow_enabled = _frame < HOLD or _frame >= HOLD * 2
	_frame += 1
	# EXPERIMENT (constant light set): the three lights stay for the whole game,
	# black, riding the camera's focus, so every frame draws in one light state.
	var focus: Vector3 = game.camera.target if game.camera != null else game.player.position
	_omni.position = focus + Vector3(0.0, 3.0, 0.0)
	_spot.position = focus + Vector3(0.0, 40.0, 0.0)
	_spot.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	if _quads.is_empty():
		return
	if _frame > HOLD * 2:
		_casting.clear()
		for q: MeshInstance3D in _quads:
			q.queue_free()
		_quads.clear()
		for n: Node3D in _motes:
			n.queue_free()
		_motes.clear()
		for sys: Node in game.systems:
			if sys.has_method(&"warm"):
				sys.call(&"warm", false)
		return
	var at: Vector3 = game.player.position
	for i in _quads.size():
		_quads[i].position = at + Vector3(0.1 * float(i), 0.05, 0.0)
	for n: Node3D in _motes:
		n.position = at + Vector3(0.0, 0.5, 0.0)


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
