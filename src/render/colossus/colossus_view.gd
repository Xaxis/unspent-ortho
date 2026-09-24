extends Node3D
## THE COLOSSI AS THEY ARE DRAWN: one body per walker (L1 near, L2 far), posed from the
## world clock and drawn in compressed space (colossus.gdshader's header says
## what that is and why it keeps every angle).
##
## Reached by path, never by class_name (src/systems/19_colossi.gd preloads it),
## so a pull cannot leave the global class cache without it.
##
## WHAT THE ENGINE CANNOT DO FOR IT, AND THIS DOES INSTEAD:
##  - CULLING. The engine culls a mesh against its AABB in world space, and a
##    compressed vertex is nowhere near its world position. So the mesh carries
##    a custom AABB round the CAMERA, as big as the far plane, which the engine
##    always keeps; and this file does the real test itself, on angles: a walker
##    whose bounding sphere is outside the lens's cone is hidden.
##  - POSE. Ten rigid frames a walker (colossus_walk.gd), handed over as rows.
##  - AIR. The sky's own numbers and the land's fog, from SkyLight.seen_air, so
##    the machine closes into exactly the haze the land does.
##  - SHADOWS. It casts none: the sun's shadow map covers 140 units.

const Model := preload("res://src/models/colossus_model.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")
const Route := preload("res://src/core/colossus/colossus_route.gd")
const SHADER := preload("res://src/render/colossus/colossus.gdshader")

## Compressed space: the knee as a share of far, the ceiling as a share of far,
## and the distance at which the log reaches the ceiling.
const KNEE := 0.82
const CEILING := 0.995
const REACH := 400000.0
## A walker's bounding sphere: centred this high over its hub's ground, and this
## wide (the planted feet and the spire both inside it).
const BOUND_UP := 48000.0
const BOUND_R := 62000.0
## Nearer than this (hub to eye, metres) a walker is drawn with its L1 body,
## the machinery on its legs; further, L2. At 90 km a shin's cable run is under
## half a pixel, so the switch is where nothing that changes can be seen.
const NEAR_LOD := 90000.0
## THE SWITCH IS DITHERED, NEVER POPPED: for `LOD_BAND` either side of
## `NEAR_LOD` both bodies are drawn, each on its own half of a screen-pinned
## stipple whose share moves with the distance (colossus.gdshader `lod_cut`),
## so the machinery comes onto the legs a pixel at a time as a walker nears.
## Stipple and not alpha: both keep writing depth, so neither sees through the
## other and nothing sorts.
const LOD_BAND := 8000.0

var defs: Array = []
var routes: Array = []
## Each walker's two bodies, each on its own instance and material: [L2, L1].
var _meshes: Array = []
var _mats: Array = []
## Which body each walker was MOSTLY drawn with this frame: 1 near, 2 far; and
## how much of it was the near one, 0..1 (1 or 0 outside the band).
var lod: Array[int] = []
var lod_share: Array[float] = []
## Per walker: whether it was drawn this frame, its last pose, its distance and
## bearing from the camera (for --stats and a tour).
var drawn: Array[bool] = []
var poses: Array[Dictionary] = []
var last_pose_usec := 0
var _solved := Vector3(-1.0, -1.0, -1.0)
var _l := 25.0


func setup(walker_defs: Array, seed_value: int, world_size: int) -> void:
	defs = walker_defs
	for d: RefCounted in defs:
		routes.append(Route.make(d, seed_value, world_size))
		var pair: Array[MeshInstance3D] = []
		var mats: Array[ShaderMaterial] = []
		for near_one: bool in [false, true]:
			var mi := MeshInstance3D.new()
			mi.name = "%s_%s" % [String(d.id), "l1" if near_one else "l2"]
			mi.mesh = Model.build(d, near_one)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			var mat := ShaderMaterial.new()
			mat.shader = SHADER
			mat.set_shader_parameter("lod_near", near_one)
			mi.material_override = mat
			mi.visible = false
			add_child(mi)
			pair.append(mi)
			mats.append(mat)
		_meshes.append(pair)
		_mats.append(mats)
		lod.append(2)
		lod_share.append(0.0)
		drawn.append(false)
		poses.append({})


## Pose every walker at `minutes` and put it where `cam` can see it, in the air
## `air` describes (SkyLight.seen_air). `wanted` false hides them all -- and
## still POSES them, because a walker nobody can see still hums, still casts its
## shadow across the land under the top-down camera, and is still where its
## gait says it is.
func update(cam: Camera3D, minutes: float, air: Dictionary, wanted: bool) -> void:
	if cam == null or not wanted:
		var t_hidden := Time.get_ticks_usec()
		for i in _meshes.size():
			poses[i] = Walk.pose(defs[i], routes[i], minutes)
			for mi: MeshInstance3D in _meshes[i]:
				mi.visible = false
			drawn[i] = false
		last_pose_usec = Time.get_ticks_usec() - t_hidden
		return
	var ortho := cam.projection == Camera3D.PROJECTION_ORTHOGONAL
	_solve(cam.near, cam.far)
	var eye := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var aspect := 16.0 / 9.0
	if cam.is_inside_tree():
		var sz := cam.get_viewport().get_visible_rect().size
		aspect = sz.x / maxf(1.0, sz.y)
	var rows := 1080.0
	if cam.is_inside_tree():
		rows = maxf(1.0, cam.get_viewport().get_visible_rect().size.y)
	var px_angle := 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / rows
	var box := AABB(eye - Vector3.ONE * cam.far, Vector3.ONE * cam.far * 2.0)
	var dome: Dictionary = air.get("dome", {})
	var fog: Vector4 = air.get("fog", Vector4(18.0, 900.0, 1.0, 1.0))
	var thick: float = air.get("thick", 0.0)
	var night: float = float(dome.get(&"dome_night", 0.0))
	var t0 := Time.get_ticks_usec()
	for i in defs.size():
		var p: Dictionary = Walk.pose(defs[i], routes[i], minutes)
		poses[i] = p
		var see := ortho or in_view(eye, fwd, cam.fov, aspect, (p.hub as Transform3D).origin)
		drawn[i] = see
		var share := near_share(eye.distance_to((p.hub as Transform3D).origin))
		lod_share[i] = share
		lod[i] = 1 if share >= 0.5 else 2
		var pair: Array = _meshes[i]
		(pair[0] as MeshInstance3D).visible = see and share < 1.0
		(pair[1] as MeshInstance3D).visible = see and share > 0.0
		if not see:
			continue
		for j in 2:
			if not (pair[j] as MeshInstance3D).visible:
				continue
			(pair[j] as MeshInstance3D).custom_aabb = box
			_dress(_mats[i][j], i, p, cam, ortho, fog, thick, night, px_angle, air, dome, share)
	last_pose_usec = Time.get_ticks_usec() - t0


## How much of each leg of walker `i` the near foot (colossus_foot.gd) has taken
## this frame; the far body gives those pixels up below the seam.
func set_l0(i: int, share: Vector3) -> void:
	if _l0_said.get(i, Vector3(-1, -1, -1)) == share:
		return
	_l0_said[i] = share
	for mat: ShaderMaterial in _mats[i]:
		mat.set_shader_parameter("l0_share", share)


var _l0_said: Dictionary = {}


## How much of a walker `d` metres off is drawn with its near body: 0 past the
## band, 1 inside it, eased across it.
static func near_share(d: float) -> float:
	return smoothstep(NEAR_LOD + LOD_BAND, NEAR_LOD - LOD_BAND, d)


func _dress(mat: ShaderMaterial, i: int, p: Dictionary, cam: Camera3D, ortho: bool, fog: Vector4,
		thick: float, night: float, px_angle: float, air: Dictionary, dome: Dictionary, share: float) -> void:
	mat.set_shader_parameter("lod_cut", share)
	mat.set_shader_parameter("bone_rows", rows_of(p.bones))
	mat.set_shader_parameter("comp_d0", cam.far * KNEE)
	mat.set_shader_parameter("comp_max", cam.far * CEILING)
	mat.set_shader_parameter("comp_l", _l)
	mat.set_shader_parameter("comp_ortho", ortho)
	mat.set_shader_parameter("land_fog", fog)
	mat.set_shader_parameter("thick", thick)
	mat.set_shader_parameter("lens_glow", night)
	mat.set_shader_parameter("px_angle", px_angle)
	mat.set_shader_parameter("leg_len", Vector2(float(defs[i].thigh), float(defs[i].shin)))
	mat.set_shader_parameter("spire_y", float(defs[i].spire_top) - float(defs[i].hip_height))
	mat.set_shader_parameter("l0_on", air.has("l0_dir"))
	if air.has("l0_dir"):
		mat.set_shader_parameter("l0_dir", air["l0_dir"])
		mat.set_shader_parameter("l0_size", air["l0_size"])
		mat.set_shader_parameter("l0_color", air["l0_color"])
		mat.set_shader_parameter("l0_energy", air["l0_energy"])
	for k: StringName in dome:
		mat.set_shader_parameter(k, dome[k])


## Whether a walker whose hub stands at `hub` can be on the glass of a lens at
## `eye` looking along `fwd`: its bounding sphere against the cone round the
## frame's diagonal. Conservative on purpose -- a walker drawn off the glass costs
## one draw, a walker culled on it is a machine the size of a mountain range
## vanishing (tests/render/test_colossus.gd sweeps every yaw and pitch for it).
static func in_view(eye: Vector3, fwd: Vector3, fov_deg: float, aspect: float, hub: Vector3) -> bool:
	var centre := Vector3(hub.x, BOUND_UP, hub.z)
	var to := centre - eye
	var dist := to.length()
	if dist < BOUND_R:
		return true
	var cone := atan(tan(deg_to_rad(fov_deg) * 0.5) * sqrt(1.0 + aspect * aspect))
	return fwd.angle_to(to) < cone + asin(clampf(BOUND_R / dist, 0.0, 1.0))


## The rigid frames as the shader's rows (colossus.gdshader `bone_rows`).
static func rows_of(bones: Array) -> Array:
	var out: Array = []
	for t: Transform3D in bones:
		var b := t.basis
		out.append(Vector4(b.x.x, b.y.x, b.z.x, t.origin.x))
		out.append(Vector4(b.x.y, b.y.y, b.z.y, t.origin.y))
		out.append(Vector4(b.x.z, b.y.z, b.z.z, t.origin.z))
	return out


func _solve(near_p: float, far_p: float) -> void:
	var key := Vector3(near_p, far_p, 0.0)
	if key == _solved:
		return
	_solved = key
	_l = solve_scale(far_p * KNEE, far_p * CEILING, REACH)


## The log's scale `l` for which d0 + l * ln(1 + (reach - d0) / l) = top. The
## slope at the knee is 1 for any l, so this is the only number to find.
static func solve_scale(d0: float, top: float, reach: float) -> float:
	var lo := 1e-3
	var hi := top - d0
	for i in 60:
		var mid := (lo + hi) * 0.5
		var g := d0 + mid * log(1.0 + (reach - d0) / mid)
		if g > top:
			hi = mid
		else:
			lo = mid
	return lo


## THE SAME RULE AS THE SHADER'S VERTEX STAGE, for tests: a view-space point
## moved along its own ray (or, orthographic, along the axis) into the room
## between the knee and the far plane.
static func compress(v: Vector3, _near_p: float, far_p: float, ortho: bool) -> Vector3:
	var d0 := far_p * KNEE
	var top := far_p * CEILING
	var l := solve_scale(d0, top, REACH)
	if ortho:
		var depth := -v.z
		return Vector3(v.x, v.y, -_len(depth, d0, top, l))
	var d := v.length()
	if d <= d0:
		return v
	return v * (_len(d, d0, top, l) / d)


static func _len(d: float, d0: float, top: float, l: float) -> float:
	if d <= d0:
		return d
	return minf(d0 + l * log(1.0 + (d - d0) / l), top)
