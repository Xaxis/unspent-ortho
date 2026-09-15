class_name MachineModel
extends FigureModel
## Shared body for the twelve machines. A kind script (watcher.gd, ...) builds a
## rig of named joints in build(), then describes each pose as offsets from the
## rest rig; this class blends them, runs the gait, and owns the working part's
## light. Everything a mob needs is still the FigureModel contract.
##
## Behaviour rules (art-audio-extract §3, §8):
##   walk     perfectly regular: gait phase advances with distance, no noise
##   alert    changes the silhouette more than any walk pose (tested)
##   hurt     the light goes out; nothing flinches: joints hold where they are
##   dead     light first, then the collapse, per joint delay per kind
##   part     amber LENS on part_side, emissive, dimmed when the camera sees
##            the far side; a halo spills round the body
##
## Kind scripts override: build(), _pose_deltas(), _gait_deltas(), _timing(),
## _routine(). Joint targets are [dpos, drot] offsets from rest; see pr().
##
## This directory is where FigureModel.create(kind) looks for `<kind>.gd`, so
## machine_model, found_kit and machine_gallery are reserved names, never kinds:
## create() hands back its placeholder for the two helpers, and a bare
## MachineModel builds a placeholder rig of its own.

const POSES: Array[StringName] = [&"stand", &"walk", &"alert", &"windup", &"strike", &"hurt", &"dead"]
## Seconds to blend into each pose (per joint; _timing can override).
const BLEND := {&"stand": 0.4, &"walk": 0.3, &"alert": 0.22, &"windup": 0.3, &"strike": 0.07, &"hurt": 0.0, &"dead": 0.55}
## The light goes out this long before a dead body starts to fall.
const LIGHT_FIRST := 0.3
## Direction from a model toward the fixed game camera (yaw 45, pitch 57; the
## camera never rotates). Used when no live camera is available (tests, gallery).
const TO_CAMERA := Vector3(0.3848, 0.8387, 0.3848)
const FOUND_SHADER := preload("res://src/render/found.gdshader")
const NIGHT_KEEP := 0.6

var ramp: Array = []
var part_material: ShaderMaterial
var cold_material: ShaderMaterial
var joints: Dictionary = {}
## Tiles moved per full gait cycle (two steps).
var stride := 1.0
## Gait speed used when the walk pose is forced at zero speed (tiles/s).
var nominal_speed := 1.5
var part_anchor: Node3D
var part_normal := Vector3.RIGHT
var emission := 0.45
## Degrees the gallery turns the working part away from the camera, so the
## silhouette shows side-on as well (a cutter's disc must be seen face-on).
var gallery_turn := 30.0
var pose_time := 0.0
var clock := 0.0
var gait := 0.0
var walk_w := 0.0
var speed_now := 0.0

var _rest: Dictionary = {}
var _from: Dictionary = {}
var _lit := true
var _light := 1.0
var _shown_light := -1.0
var _flare := 0.0
var _dim := 1.0
var _part_meshes: Array = []
var _glow: MeshInstance3D
var _glow_mat: ShaderMaterial
var _glow_size := 0.7
var _scans: Array = []
var _dead_only: Array = []
## The delta of the animate() call in progress (0 while settling).
var _dt := 0.0


## Offsets for one joint in a pose: position offset and euler rotation offset.
static func pr(dpos: Vector3, drot: Vector3 = Vector3.ZERO) -> Array:
	return [dpos, drot]


static func r(drot: Vector3) -> Array:
	return [Vector3.ZERO, drot]


# -- building ---------------------------------------------------------------

## Kinds override this without calling it. A bare MachineModel (never a kind)
## still gets a rig, so nothing downstream finds its materials missing.
func build() -> void:
	begin_rig()
	var k := FoundKit.kit()
	FoundKit.lathe(k, Vector3.ZERO, Vector3.UP, [Vector2(0.3, 0.0), Vector2(0.3, 0.8), Vector2(0.2, 0.9)], 8, ramp, PI / 8.0)
	body_mesh(k, joint(&"body", self, Vector3.ZERO))
	finish_rig()


## Call first in build(): ramp, materials, part side. Machines are FOUND: every
## part of them is on found.gdshader whatever material the caller offered (the
## world's MADE material would hatch them, and they must never look drawn).
func begin_rig() -> void:
	ramp = Palette.MACHINE.get(String(kind), Palette.FOUND)
	material = found_material(0.0)
	part_material = found_material(emission)
	cold_material = found_material(0.2)
	part_normal = side_normal(part_side)


static func found_material(emission_strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOUND_SHADER
	m.set_shader_parameter("emission_strength", emission_strength)
	# A live machine keeps more of its colour at night than salvage does.
	m.set_shader_parameter("night_keep", NIGHT_KEEP)
	return m


static func side_normal(side: StringName) -> Vector3:
	match side:
		&"back": return Vector3.LEFT
		&"left": return Vector3.FORWARD
		&"right": return Vector3.BACK
		&"none": return Vector3.ZERO
	return Vector3.RIGHT


func joint(jname: StringName, parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = String(jname)
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	joints[jname] = n
	return n


func body_mesh(k: MeshKit, parent: Node3D) -> MeshInstance3D:
	return add_mesh(k, parent)


static var _matter_mat: ShaderMaterial


## A mesh of natural matter (ore, spoil, a cut row) on the MADE material: the
## load is the land's, drawn by the hand, even when a machine carries it.
func matter_mesh(k: MeshKit, parent: Node3D) -> MeshInstance3D:
	if _matter_mat == null:
		_matter_mat = ShaderMaterial.new()
		_matter_mat.shader = preload("res://src/render/world.gdshader")
	var mi := MeshInstance3D.new()
	mi.name = "matter"
	mi.mesh = k.build()
	mi.material_override = _matter_mat
	parent.add_child(mi)
	return mi


## A mesh on the part material: glows, and swaps to its dark twin when the light goes out.
func part_mesh(k: MeshKit, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var lit := k.build()
	mi.mesh = lit
	mi.material_override = part_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_part_meshes.append([mi, lit, FoundKit.darkened(k).build()])
	return mi


## A mesh on the cold material (visor slits' moving highlight, sensor lights).
func cold_mesh(k: MeshKit, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var lit := k.build()
	mi.mesh = lit
	mi.material_override = cold_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_part_meshes.append([mi, lit, FoundKit.darkened(k).build()])
	return mi


## Where the working part is (local to `parent`), and how big its halo is.
func set_part_anchor(parent: Node3D, pos: Vector3, glow_size: float = 0.7) -> void:
	part_anchor = Node3D.new()
	part_anchor.name = "part"
	part_anchor.position = pos
	parent.add_child(part_anchor)
	_glow_size = glow_size
	_glow = MeshInstance3D.new()
	_glow.name = "glow"
	var q := QuadMesh.new()
	q.size = Vector2(glow_size, glow_size)
	_glow.mesh = q
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = preload("res://src/models/machines/part_glow.gdshader")
	_glow_mat.render_priority = 10
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.position = part_normal * 0.06
	part_anchor.add_child(_glow)


## A COLD highlight that travels a visor slit and holds at each end: the plate
## is looking. `c` centre of the slit, `along` its direction, `span` travel.
func add_scan(parent: Node3D, c: Vector3, n: Vector3, along: Vector3, span: float, h: float, period: float = 2.4) -> void:
	var holder := Node3D.new()
	holder.name = "scan"
	parent.add_child(holder)
	var k := FoundKit.kit()
	FoundKit.mark(k, Vector3.ZERO, n, Vector3.UP if absf(n.y) < 0.9 else along.cross(n), minf(0.08, span * 0.3), h, Palette.COLD[3], 0.011)
	cold_mesh(k, holder)
	_scans.append([holder, c, along.normalized(), span, period])


## A node that only exists once the machine is dead (a spill, a split load),
## appearing `delay` seconds into the dead pose.
func dead_only(n: Node3D, delay: float) -> void:
	n.visible = false
	_dead_only.append([n, delay])


## Call last in build(): records the rest rig.
func finish_rig() -> void:
	for jn: StringName in joints:
		var n: Node3D = joints[jn]
		_rest[jn] = [n.position, n.rotation]
		_from[jn] = [n.position, n.rotation]
	_apply_light(0.0)


# -- the contract -----------------------------------------------------------

func set_pose(p: StringName) -> void:
	if p == pose or not POSES.has(p):
		return
	for jn: StringName in joints:
		var n: Node3D = joints[jn]
		_from[jn] = [n.position, n.rotation]
	pose = p
	pose_time = 0.0


func animate(delta: float, speed: float) -> void:
	_dt = delta
	clock += delta
	pose_time += delta
	speed_now = speed
	if pose != &"hurt" and pose != &"dead":
		var forced := pose == &"walk"
		var moving := speed > 0.05 or forced
		var v := maxf(speed, nominal_speed if forced else 0.0)
		gait += delta * v / stride
		walk_w = move_toward(walk_w, 1.0 if moving else 0.0, delta * 5.0)
	_apply_pose()
	_routine(delta, running())
	_run_scans()
	_apply_light(delta)
	_show_dead_only()


func set_part_lit(lit: bool) -> void:
	_lit = lit


func flare_part() -> void:
	if running():
		_flare = 1.0


## Jump to the end of the current pose's blend (gallery, tests, teleports).
func settle() -> void:
	_dt = 0.0
	pose_time = 1000.0
	if pose != &"walk":
		walk_w = 0.0
	_apply_pose()
	_routine(0.0, running())
	_run_scans()
	_apply_light(0.0)
	_show_dead_only()


## False while hurt or dead or switched off: mechanisms stop with the light.
func running() -> bool:
	return _lit and pose != &"hurt" and pose != &"dead"


## 0..1 current light of the working part (after the stepped relight).
func light_level() -> float:
	return _shown_light


## Current emission strength on the working part (0 when out, lower when the
## camera sees the far side, higher in a flare).
func part_emission() -> float:
	return float(part_material.get_shader_parameter("emission_strength"))


func part_position() -> Vector3:
	if part_anchor == null:
		return super()
	if part_anchor.is_inside_tree():
		return part_anchor.global_position
	return transform * model_space(part_anchor).origin


## Transform of a descendant relative to this model (works outside the tree).
func model_space(n: Node3D) -> Transform3D:
	return _model_space(n)


# -- for kind scripts to override ------------------------------------------

## joint name -> pr(dpos, drot) for pose `p` (rest for joints not listed).
func _pose_deltas(_p: StringName) -> Dictionary:
	return {}


## joint name -> pr(dpos, drot) at gait phase `phase` (in strides), added on
## top of the pose while walking.
func _gait_deltas(_phase: float) -> Dictionary:
	return {}


## Vector2(delay, duration) for a joint entering pose `p`.
func _timing(p: StringName, _joint: StringName) -> Vector2:
	return Vector2(LIGHT_FIRST if p == &"dead" else 0.0, BLEND.get(p, 0.3))


## Continuous mechanisms (disc, brushes, comb, iris). `on` false = stopped.
func _routine(_delta: float, _on: bool) -> void:
	pass


## Multiplier on the part's light for the current pose (a warden's band at full).
func _light_scale() -> float:
	return 1.0


# -- internals ---------------------------------------------------------------

func _apply_pose() -> void:
	if pose == &"hurt":
		return
	var pd := _pose_deltas(pose)
	var gd: Dictionary = {}
	if walk_w > 0.0 and pose != &"dead":
		gd = _gait_deltas(gait)
	for jn: StringName in joints:
		var n: Node3D = joints[jn]
		var rest: Array = _rest[jn]
		var tp: Vector3 = rest[0]
		var tr: Vector3 = rest[1]
		if pd.has(jn):
			var d: Array = pd[jn]
			tp += d[0] as Vector3
			tr += d[1] as Vector3
		if gd.has(jn):
			var g: Array = gd[jn]
			tp += (g[0] as Vector3) * walk_w
			tr += (g[1] as Vector3) * walk_w
		var tm := _timing(pose, jn)
		var e := 1.0
		if tm.y > 0.0:
			e = clampf((pose_time - tm.x) / tm.y, 0.0, 1.0)
		elif pose_time < tm.x:
			e = 0.0
		# Falling accelerates; servos start and stop exactly.
		e = e * e if pose == &"dead" else smoothstep(0.0, 1.0, e)
		var f: Array = _from[jn]
		n.position = (f[0] as Vector3).lerp(tp, e)
		n.rotation = (f[1] as Vector3).lerp(tr, e)


func _show_dead_only() -> void:
	for d: Array in _dead_only:
		(d[0] as Node3D).visible = pose == &"dead" and pose_time >= float(d[1])


func _run_scans() -> void:
	for s: Array in _scans:
		var holder: Node3D = s[0]
		var period: float = s[4]
		# Across, hold, back, hold: the same sweep forever.
		var t := fposmod(clock, period) / period
		var x := 0.0
		if t < 0.35:
			x = smoothstep(0.0, 1.0, t / 0.35)
		elif t < 0.5:
			x = 1.0
		elif t < 0.85:
			x = 1.0 - smoothstep(0.0, 1.0, (t - 0.5) / 0.35)
		holder.position = (s[1] as Vector3) + (s[2] as Vector3) * ((x - 0.5) * (s[3] as float))
		holder.visible = running()


func _apply_light(delta: float) -> void:
	var want := 1.0 if running() else 0.0
	if want <= 0.0:
		_light = 0.0
	else:
		_light = move_toward(_light, 1.0, delta * 4.0) if delta > 0.0 else 1.0
	# Relight in three exact steps; go out at once.
	var shown := floorf(_light * 3.0 + 0.001) / 3.0
	_flare = maxf(0.0, _flare - delta * 3.5)
	var facing := _part_facing()
	var want_dim := 1.0 if facing > -0.15 else 0.35
	_dim = want_dim if delta <= 0.0 else lerpf(_dim, want_dim, 1.0 - exp(-12.0 * delta))
	if shown != _shown_light:
		for pm: Array in _part_meshes:
			if pm[0] is MeshInstance3D:
				(pm[0] as MeshInstance3D).mesh = pm[1] if shown > 0.0 else pm[2]
		_shown_light = shown
	# Emission tops the part up to its own colour however dark the sky is: by day
	# the sun already lights it, by night the light is all its own.
	var dark := darkness()
	# The floor is high enough that a part in its own shadow at noon is still
	# the brightest warm thing on sand: the soft side must read by day.
	var glow := emission * (1.0 + 3.0 * dark)
	part_material.set_shader_parameter("emission_strength", (glow * _light_scale() + _flare * 2.5) * shown * _dim)
	cold_material.set_shader_parameter("emission_strength", (0.2 + 0.6 * dark) * shown)
	if _glow != null:
		_glow.visible = shown > 0.0
		_glow_mat.set_shader_parameter("strength", shown * (0.55 + _flare * 1.6) * lerpf(0.8, 1.0, _dim))
		var s := 1.0 + _flare * 0.6
		_glow.scale = Vector3(s, s, s)


static var _dark_frame := -1
static var _dark := 0.0
static var _sun: WeakRef


## 0 in full daylight .. about 0.5 at night, read once a frame for every machine.
## A global shader parameter cannot be read back outside the editor, so this asks
## the scene: a sky node's darkness() when it has one, else the key light's
## energy and colour (the sky dims its sun at night).
static func darkness() -> float:
	var f := Engine.get_process_frames()
	if f == _dark_frame:
		return _dark
	_dark_frame = f
	var sun := _find_sun()
	if sun == null:
		_dark = 0.0
		return _dark
	var sky := sun.get_parent()
	if sky != null and sky.has_method(&"darkness"):
		_dark = clampf(float(sky.call(&"darkness")), 0.0, 1.0)
	else:
		var c := sun.light_color
		_dark = clampf(1.0 - sun.light_energy * (c.r + c.g + c.b) / 3.0, 0.0, 1.0)
	return _dark


static func _find_sun() -> DirectionalLight3D:
	if _sun != null and _sun.get_ref() != null:
		return _sun.get_ref() as DirectionalLight3D
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var found := tree.root.find_children("*", "DirectionalLight3D", true, false)
	if found.is_empty():
		return null
	_sun = weakref(found[0])
	return found[0] as DirectionalLight3D


## Dot of the working part's outward normal with the direction to the camera.
func _part_facing() -> float:
	if part_anchor == null or part_normal == Vector3.ZERO:
		return 1.0
	var to_cam := TO_CAMERA
	var xf := _model_space(part_anchor)
	var model_basis := basis
	if is_inside_tree():
		model_basis = global_transform.basis
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			to_cam = cam.global_transform.basis.z
	return (model_basis * (xf.basis * part_normal)).normalized().dot(to_cam)


## Transform of a descendant relative to this model.
func _model_space(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != self:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
