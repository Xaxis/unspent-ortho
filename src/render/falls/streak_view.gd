extends Node3D
## THE FALLS AS THEY ARE DRAWN: one draw a live fall, a MultiMesh of ribbons on
## streak.gdshader (its header says what each part is and why a ribbon knows
## only how long ago its head passed). This file hands a fall's numbers over
## once, when it lights, and its clock, its light and the sky's air every frame.
##
## Reached by path, never by class_name (src/systems/21_falls.gd preloads it).
##
## WHAT THE ENGINE CANNOT DO FOR IT, AND THIS DOES INSTEAD (as colossus_view.gd):
##  - CULLING. Every vertex is placed by the shader in compressed space, nowhere
##    near the mesh's own box, so each fall carries a custom AABB round the
##    camera as big as the far plane, which the engine always keeps.
##  - AIR. The dome's own numbers from SkyLight.seen_air, so a streak is behind
##    the same clouds and through the same air as the ring and the colossi.

const Sched := preload("res://src/core/sky/fall_schedule.gd")
const Colossi := preload("res://src/render/colossus/colossus_view.gd")
const SHADER := preload("res://src/render/falls/streak.gdshader")

## Segments along a ribbon: enough for a train's twist over hundreds of km, and
## for one passing close overhead to be a curve and never a run of steps.
const STEPS := 128
## Parts a fall is drawn in: the body, six pieces, the flash.
const PARTS := 8
## Transparent world geometry is drawn only with a priority of its own: under
## everything else that is transparent in the frame (weather, dust, marks),
## because every streak is behind all of it.
const PRIORITY := -20

## A class's look: its head's true radius (m), halo (px), how fast its wake cools
## (s), its train's own glow, how much light its train scatters, its energy on
## the glass at REF_KM, how much of it daylight leaves to be seen, and how much
## light it throws on the land at REF_KM (21_falls).
const LOOK := {
	&"dust": {"core": 60.0, "halo": 3.0, "wake": 0.10, "own": 0.5, "scatter": 0.0, "energy": 5.0, "day": 0.0},
	&"fragment": {"core": 140.0, "halo": 4.5, "wake": 0.16, "own": 0.8, "scatter": 0.9, "energy": 4.0, "day": 0.12},
	&"mass": {"core": 420.0, "halo": 8.0, "wake": 0.26, "own": 1.0, "scatter": 1.2, "energy": 9.0, "day": 1.0},
}
## The range at which a class's energy is as stated; nearer is brighter, further
## dimmer, within ENERGY_SPAN of it.
const REF_KM := 150.0
const ENERGY_SPAN := Vector2(0.25, 1.8)

var _strip: ArrayMesh
var _solved := Vector2(-1.0, -1.0)
var _l := 25.0
## Falls drawn this frame (--stats, a tour asks the live count).
var drawn := 0


func _ready() -> void:
	_strip = strip_mesh()


## A strip of STEPS segments, UV.x 0..1 along it and UV.y 0 or 1 across, and one
## more pair at UV.x 2 that the shader stands in front of the head.
static func strip_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in STEPS + 2:
		var u := float(i) / float(STEPS) if i <= STEPS else 2.0
		for s in 2:
			v.append(Vector3(0.0, 0.0, 0.0))
			uv.append(Vector2(u, float(s)))
	for i in STEPS + 1:
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## A fall has lit: its node, its material, and every number that holds for its
## whole life. `entry` is 21_falls' live record ({f, pieces, age}); this adds
## `node` and `mat` to it.
func add(entry: Dictionary) -> void:
	var f: Dictionary = entry.f
	var look: Dictionary = LOOK[f.kind]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _strip
	mm.instance_count = PARTS
	for i in PARTS:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(float(i), 0.0, 0.0, 0.0))
	var node := MultiMeshInstance3D.new()
	node.name = "fall_%d" % int(f.id)
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.render_priority = PRIORITY
	var p0 := Sched.point(f, 0.0) * 1000.0
	mat.set_shader_parameter("f_p0", p0)
	mat.set_shader_parameter("f_dir", f.dir)
	mat.set_shader_parameter("f_len", Sched.path_km(f) * 1000.0)
	mat.set_shader_parameter("f_secs", f.secs)
	mat.set_shader_parameter("f_tb", Sched.break_secs(f))
	mat.set_shader_parameter("f_sb", Sched.break_s(f))
	mat.set_shader_parameter("f_train", f.train_secs)
	var dirs: Array[Vector4] = []
	var ks: Array[Vector4] = []
	for i in 6:
		dirs.append(Vector4.ZERO)
		ks.append(Vector4(1.0, 0.0, 0.0, 0.0))
	var ps: Array = entry.pieces
	for i in mini(ps.size(), 6):
		var d: Vector3 = ps[i].dir
		dirs[i] = Vector4(d.x, d.y, d.z, float(ps[i].speed) * 1000.0)
		ks[i] = Vector4(float(ps[i].life), 0.0, 0.0, 0.0)
	mat.set_shader_parameter("f_piece_dir", dirs)
	mat.set_shader_parameter("f_piece_k", ks)
	mat.set_shader_parameter("f_pieces", ps.size())
	mat.set_shader_parameter("f_core_m", look.core)
	mat.set_shader_parameter("f_halo_px", look.halo)
	mat.set_shader_parameter("f_wake_s", look.wake)
	mat.set_shader_parameter("f_train_own", look.own)
	mat.set_shader_parameter("f_scatter", look.scatter)
	var sid: int = f.shape
	mat.set_shader_parameter("f_wind", Vector4(lerpf(70.0, 140.0, Rng.hash01(sid, 1)), lerpf(1500.0, 3000.0, Rng.hash01(sid, 2)),
		Rng.hash01(sid, 3) * TAU, Rng.hash01(sid, 4) * TAU))
	node.material_override = mat
	node.visible = false
	add_child(node)
	entry.node = node
	entry.mat = mat
	entry.energy = float(look.energy) * clampf(REF_KM / maxf(Sched.point(f, Sched.anchor_s(f)).length(), 1.0), ENERGY_SPAN.x, ENERGY_SPAN.y)


func remove(entry: Dictionary) -> void:
	var node: Node = entry.get("node")
	if node != null:
		node.queue_free()
	entry.erase("node")
	entry.erase("mat")


## Every live fall's clock and light, and the sky it is seen in. `wanted` false
## hides them all (the top-down camera, a roof, a lid of smog).
func update(cam: Camera3D, live: Array, air: Dictionary, wanted: bool) -> void:
	drawn = 0
	var see := wanted and cam != null and cam.projection == Camera3D.PROJECTION_PERSPECTIVE
	var dome: Dictionary = air.get("dome", {})
	var night := float(dome.get(&"dome_night", 0.0))
	var rows := 1080.0
	var eye := Vector3.ZERO
	if see:
		_solve(cam.far)
		eye = cam.global_position
		if cam.is_inside_tree():
			rows = maxf(1.0, cam.get_viewport().get_visible_rect().size.y)
	var px_angle := 2.0 * tan(deg_to_rad(cam.fov if cam != null else 60.0) * 0.5) / rows
	for e: Dictionary in live:
		var node: MultiMeshInstance3D = e.get("node")
		if node == null:
			continue
		node.visible = see
		if not see:
			continue
		drawn += 1
		node.custom_aabb = AABB(eye - Vector3.ONE * cam.far, Vector3.ONE * cam.far * 2.0)
		var f: Dictionary = e.f
		var mat: ShaderMaterial = e.mat
		var age: float = e.age
		var en: float = e.energy
		mat.set_shader_parameter("f_origin", Vector3(eye.x, 0.0, eye.z))
		mat.set_shader_parameter("f_age", age)
		mat.set_shader_parameter("f_head", Sched.head_level(f, age) * en)
		mat.set_shader_parameter("f_flash", Sched.flash_level(f, age) * en)
		var ps: Array = e.pieces
		var ks: Array[Vector4] = []
		for i in 6:
			if i < ps.size():
				ks.append(Vector4(float(ps[i].life), Sched.piece_level(f, ps[i], age) * en * 0.8, 0.0, 0.0))
			else:
				ks.append(Vector4(1.0, 0.0, 0.0, 0.0))
		mat.set_shader_parameter("f_piece_k", ks)
		mat.set_shader_parameter("f_vis", lerpf(float(LOOK[f.kind].day), 1.0, clampf(night, 0.0, 1.0)))
		mat.set_shader_parameter("comp_d0", cam.far * Colossi.KNEE)
		mat.set_shader_parameter("comp_max", cam.far * Colossi.CEILING)
		mat.set_shader_parameter("comp_l", _l)
		mat.set_shader_parameter("px_angle", px_angle)
		mat.set_shader_parameter("thick", air.get("thick", 0.0))
		for k: StringName in dome:
			mat.set_shader_parameter(k, dome[k])


func _solve(far_p: float) -> void:
	var key := Vector2(far_p, 0.0)
	if key == _solved:
		return
	_solved = key
	_l = Colossi.solve_scale(far_p * Colossi.KNEE, far_p * Colossi.CEILING, Colossi.REACH)
