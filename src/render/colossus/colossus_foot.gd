extends Node3D
## A COLOSSUS'S FOOT UP CLOSE (L0): the near body of any foot within `NEAR` of
## the camera, in the real space every other machine is drawn in
## (src/models/colossus_foot_model.gd has what it is made of).
##
## Reached by path, never by class_name (19_colossi preloads it).
##
## BUILT ON A WORKER, UPLOADED A SURFACE A FRAME. The first foot to come within
## `BUILD` of the camera starts one task that builds every part (a few tens of
## milliseconds of arrays); when it is done, one part a frame goes to the
## renderer, so nothing about a foot coming near is paid in one frame. The
## geometry is the same for every foot of one design, so it is built once.
##
## HANDED OVER ON A STIPPLE, NEVER POPPED: across `FADE` the near foot keeps a
## growing share of the pixels (found.gdshader `lod_keep`) and the far body the
## rest of its own foot and shin below the seam (colossus.gdshader `l0_share`),
## so walking toward a foot, the machinery comes onto it a pixel at a time.
##
## Also the things a landing does where it lands: a ring of dust thrown out
## from each pad, steam from the joints, and the shock that bends the crowns
## (`colossus_shock`, sky.gdshaderinc), and at night the cold ring under the
## drum lighting the ground.

const FootModel := preload("res://src/models/colossus_foot_model.gd")
const DUST := preload("res://src/render/colossus/colossus_dust.gdshader")

## Metres from the camera to the ankle: the near foot is drawn inside NEAR, all
## of it inside NEAR - FADE, and built as soon as one is inside BUILD.
const NEAR := 1250.0
const FADE := 250.0
const BUILD := 2600.0

## Per foot key (walker * 3 + leg): {foot: MeshInstance3D, stub: MeshInstance3D,
## mat: ShaderMaterial, lights: Array[OmniLight3D]}.
var _nodes: Dictionary = {}
## The parts built on the worker, by design id, and the task building them.
var _kits: Dictionary = {}
var _task := -1
var _task_for: StringName = &""
var _task_out: Dictionary = {}
## One shared mesh per design, filled a surface a frame: [foot mesh, stub mesh,
## parts still to upload].
var _meshes: Dictionary = {}
## How much of each walker's legs is the near body's this frame: walker ->
## Vector3 of shares per leg (colossus.gdshader `l0_share`).
var shares: Dictionary = {}
## What the last frame drew, for --stats: feet drawn, surfaces uploaded.
var drawn := 0
var uploaded := 0


## Place and draw the near feet for this frame. `poses` and `defs` are the
## walkers' (colossus_view.gd), `night` 0..1 how much of the dark there is.
func update(cam: Camera3D, defs: Array, poses: Array, night: float) -> void:
	shares.clear()
	drawn = 0
	if cam == null:
		_claim(false)
		_hide_all()
		return
	_claim(false)
	_upload_one()
	var eye := cam.global_position
	var seen := {}
	for i in defs.size():
		var p: Dictionary = poses[i]
		if p.is_empty():
			continue
		var d: RefCounted = defs[i]
		var legs := Vector3.ZERO
		for k in 3:
			var ankle: Vector3 = p.ankles[k]
			var dist := eye.distance_to(ankle)
			if dist < BUILD:
				_want_built(d)
			var share := smoothstep(NEAR, NEAR - FADE, dist)
			if share <= 0.0 or not _ready_for(d):
				continue
			var key := i * 3 + k
			seen[key] = true
			var n := _node(key, d)
			(n.foot as MeshInstance3D).global_transform = p.bones[3 + 3 * k]
			(n.stub as MeshInstance3D).global_transform = _stub_frame(p.bones[2 + 3 * k], ankle)
			(n.foot as MeshInstance3D).visible = true
			(n.stub as MeshInstance3D).visible = true
			# Only what changed goes to the renderer: a material write is a
			# round trip, and a foot standing still in daylight changes nothing.
			var mat: ShaderMaterial = n.mat
			var said := Vector2(share, snappedf(night, 0.01))
			if said != (n.said as Vector2):
				n.said = said
				mat.set_shader_parameter("lod_keep", share)
				mat.set_shader_parameter("glow_scale", lerpf(0.2, 1.0, said.y))
				for l: OmniLight3D in n.lights:
					l.visible = said.y > 0.05
					l.light_energy = said.y * LIGHT_ENERGY
			legs[k] = share
			drawn += 1
		if legs != Vector3.ZERO:
			shares[i] = legs
	for key: int in _nodes:
		if not seen.has(key):
			_show(_nodes[key], false)


## The shin's own frame turned to run UP from the ankle: the bone runs down the
## leg from the knee, and the stub is authored up from the ankle.
static func _stub_frame(shin: Transform3D, ankle: Vector3) -> Transform3D:
	var b := shin.basis
	return Transform3D(Basis(b.x, -b.y, -b.z), ankle)


func _want_built(d: RefCounted) -> void:
	if _kits.has(d.id) or _task >= 0:
		return
	_task_for = d.id
	_task_out = {}
	var out := _task_out
	_task = WorkerThreadPool.add_task(func() -> void:
		for part: StringName in FootModel.PARTS:
			out[part] = FootModel.build(d, part), true, "colossus foot")


func _ready_for(d: RefCounted) -> bool:
	return _meshes.has(d.id) and (_meshes[d.id][2] as Array).is_empty()


## A POOL TASK IS CLAIMED, ALWAYS: waited for the frame it is done, whether or
## not a foot came near enough to want it, and waited out if this node goes
## first. An unclaimed task holds its Callable -- a lambda on this instance --
## in the pool past the instance's life, and the pool frees it at exit: the
## process dies with signal 11 AFTER every test has passed (CI shard 1, exit
## 134, from the first game in a run that came within BUILD of a tread).
func _claim(wait: bool) -> void:
	if _task < 0 or (not wait and not WorkerThreadPool.is_task_completed(_task)):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_kits[_task_for] = _task_out
	_meshes[_task_for] = [ArrayMesh.new(), ArrayMesh.new(), FootModel.PARTS.duplicate()]


func _exit_tree() -> void:
	_claim(true)


## One part a frame from the worker's arrays to the renderer.
func _upload_one() -> void:
	for id: StringName in _meshes:
		var m: Array = _meshes[id]
		var left: Array = m[2]
		if left.is_empty():
			continue
		var part: StringName = left.pop_front()
		var kit: MeshKit = _kits[id][part]
		kit.build(m[1] if part == &"stub" else m[0])
		uploaded += 1
		return


## Plates on a foot this size, over a man-sized machine's.
const PANEL_SCALE := 14.0
## How bright the cold ring under a drum lights the ground at full dark.
const LIGHT_ENERGY := 2.2


func _node(key: int, d: RefCounted) -> Dictionary:
	if _nodes.has(key):
		return _nodes[key]
	var mat := PropModels.found_material().duplicate() as ShaderMaterial
	mat.set_shader_parameter("panel_scale", PANEL_SCALE)
	mat.set_shader_parameter("relief", 0.4)
	# Worn by the land it stands in, but lightly: at this size the wear's own
	# blotches are metres across and read as rock, not as plate.
	mat.set_shader_parameter("wear_take", 0.3)
	var foot := MeshInstance3D.new()
	foot.name = "foot_%d" % key
	foot.mesh = _meshes[d.id][0]
	foot.material_override = mat
	var stub := MeshInstance3D.new()
	stub.name = "stub_%d" % key
	stub.mesh = _meshes[d.id][1]
	stub.material_override = mat
	add_child(foot)
	add_child(stub)
	# Three lamps in the ring under the drum, one over each gap between the toes:
	# at night the ground a person stands on between them is lit from above in
	# the plan's own cold light, and the pads stand in their own dark.
	var lights: Array[OmniLight3D] = []
	for g in 3:
		var a := TAU * (float(g) + 0.5) / 3.0
		var l := OmniLight3D.new()
		l.position = Vector3(cos(a) * 108.0, -66.0, sin(a) * 108.0)
		l.omni_range = 150.0
		l.omni_attenuation = 1.2
		l.light_color = Color(0.7451, 0.7294, 0.8745)
		l.shadow_enabled = false
		l.visible = false
		foot.add_child(l)
		lights.append(l)
	var n := {"foot": foot, "stub": stub, "mat": mat, "lights": lights, "said": Vector2(-1.0, -1.0)}
	_nodes[key] = n
	return n


func _show(n: Dictionary, on: bool) -> void:
	(n.foot as MeshInstance3D).visible = on
	(n.stub as MeshInstance3D).visible = on
	for l: OmniLight3D in n.lights:
		l.visible = on and l.visible
	if not on:
		n.said = Vector2(-1.0, -1.0)


func _hide_all() -> void:
	for key: int in _nodes:
		_show(_nodes[key], false)


## WHAT A LANDING THROWS UP where it lands: a wall of dust thrown out off every
## pad along the ground, and steam falling out of the vents under the drum.
## `pads` are the tread's pad circles (tile space), `ground` the crater floor's
## height, `ankle` the ankle in world space.
func land(pads: Array, ground: float, ankle: Vector3, dust_col: Color) -> void:
	for p: Vector3 in pads:
		_cloud(Vector3(p.x, ground + 2.0, p.y), false, dust_col, float(p.z), DUST_OUT, DUST_HIGH, DUST_SIZE, DUST_SECS, DUST_BILLOWS)
	_cloud(ankle + Vector3(0.0, -72.0, 0.0), true, Color(0.86, 0.87, 0.9), FootModel.VENT_R, FootModel.VENT_R + 40.0, STEAM_FALL, STEAM_SIZE, STEAM_SECS, STEAM_BILLOWS)


## A pad's dust: how long it rolls, how far out and how high it gets, how big a
## billow is at its fullest, and how many billows. The drum's steam likewise.
const DUST_SECS := 16.0
const DUST_OUT := 210.0
const DUST_HIGH := 34.0
const DUST_SIZE := 34.0
const DUST_BILLOWS := 90
const STEAM_SECS := 14.0
const STEAM_FALL := 60.0
const STEAM_SIZE := 26.0
const STEAM_BILLOWS := 48


func _cloud(at: Vector3, steam: bool, col: Color, from_r: float, reach: float, high: float, size: float, secs: float, n: int) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _billows(n, steam)
	var mat := ShaderMaterial.new()
	mat.shader = DUST
	# Over the land and the props it rolls across, under people (10) and the
	# hit marks (12): a cloud of dust hides the ground, never a body.
	mat.render_priority = 8
	mat.set_shader_parameter("dust_col", col)
	mat.set_shader_parameter("steam", steam)
	mat.set_shader_parameter("from_r", from_r)
	mat.set_shader_parameter("reach", reach)
	mat.set_shader_parameter("high", high)
	mat.set_shader_parameter("size", size)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Every billow is placed by the shader, so the engine is told where the
	# whole cloud can reach.
	mi.custom_aabb = AABB(Vector3(-reach - size, -high - size, -reach - size), Vector3(reach + size, high + size, reach + size) * 2.0)
	add_child(mi)
	mi.global_position = at
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void: mat.set_shader_parameter("age", t), 0.0, 1.0, secs)
	tw.tween_callback(mi.queue_free)


static var _clouds: Dictionary = {}


## `n` billows, each a camera-facing quad at the cloud's origin with its own
## bearing, pace, size and lift in its custom data (colossus_dust.gdshader).
## Steam's billows come out of the drum's vents, so their bearings are the vents'.
static func _billows(n: int, steam: bool) -> MultiMesh:
	var key := n * 2 + (1 if steam else 0)
	if _clouds.has(key):
		return _clouds[key]
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		var bearing := Rng.hash01(0xD057, i, 1)
		if steam:
			bearing = (float(i % FootModel.VENTS) + 0.5) / float(FootModel.VENTS)
		mm.set_instance_custom_data(i, Color(bearing, Rng.hash01(0xD057, i, 2), Rng.hash01(0xD057, i, 3), Rng.hash01(0xD057, i, 4)))
	_clouds[key] = mm
	return mm
