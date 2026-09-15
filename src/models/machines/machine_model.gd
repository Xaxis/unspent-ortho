class_name MachineModel
extends FigureModel
## Shared body for the twelve machines. A kind script (watcher.gd, ...) builds a
## rig of named joints in build(), then describes each pose as offsets from the
## rest rig; this class blends them, runs the gait, and owns every light on the
## body. Everything a mob needs is still the FigureModel contract.
##
## Behaviour rules (art-audio-extract §3, §8; docs/VISION.md §2):
##   walk     perfectly regular: gait phase advances with distance, no noise
##   stand    the idle routine: mechanisms keep their exact cycle, and the status
##            lamps blink the machine's disposition (DISPOSITION_CODE)
##   alert    snaps into its silhouette (a servo, not a blend), scans stop dead
##            centre and the optics lock bright; the status lamps double-blink
##   windup   the working side brightens: the part climbs toward twice its light
##            and the lamps on the part's side go hot
##   hurt     the part's light stutters and goes out; the lamps stutter; nothing
##            flinches: joints hold where they are
##   dead     the lights die in sequence (status, eyes, work lamps, the working
##            part last), and only then the collapse, per joint delay per kind
##   part     amber LENS on part_side, emissive, dimmed when the camera sees
##            the far side; a halo spills round the body
##
## Drawing: every piece a kind builds is queued by surface kind and merged at
## finish_rig() into ONE skinned mesh per kind (body, part, lights, matter), with
## a bone for every node a piece hangs on. Joints stay plain Node3Ds; each frame
## their model-space transforms are copied onto the bones. A node that is hidden
## collapses its bone to a point, which is how lamps blink, scans travel and
## spills appear without a draw call of their own. Budget: <= 6 draw calls a
## machine (body, part, lights, matter, the part's halo, a scan beam).
##
## Kind scripts override: build(), _pose_deltas(), _gait_deltas(), _timing(),
## _routine(), _light_scale(). Joint targets are [dpos, drot] offsets from rest;
## see pr().
##
## This directory is where FigureModel.create(kind) looks for `<kind>.gd`, so
## machine_model, found_kit and machine_gallery are reserved names, never kinds:
## create() hands back its placeholder for the two helpers, and a bare
## MachineModel builds a placeholder rig of its own.

const POSES: Array[StringName] = [&"stand", &"walk", &"alert", &"windup", &"strike", &"hurt", &"dead"]
## Seconds to blend into each pose (per joint; _timing can override).
const BLEND := {&"stand": 0.4, &"walk": 0.3, &"alert": 0.12, &"windup": 0.3, &"strike": 0.07, &"hurt": 0.0, &"dead": 0.55}
## The lights are all out this long before a dead body starts to fall.
const LIGHT_FIRST := 0.42
## When, into the dead pose, each kind of lamp goes out (plus a small stagger
## per lamp); the working part holds on until PART_OUT, stuttering at the end.
const DIE_AT := {&"status": 0.0, &"beam": 0.05, &"scan": 0.08, &"optic": 0.1, &"work": 0.18}
const PART_OUT := 0.34
## A hurt part stutters this long before it stays out.
const STUTTER := 0.3
## The stutter itself, at 24 steps a second: exact, so it reads as a fault, not noise.
const STUTTER_BITS := [1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0]
## Status lamp codes: blinks per cycle for each disposition (VISION §2). Hostile
## machines do not blink: they burn low and steady.
const DISPOSITION_CODE := {&"indifferent": 1, &"wary": 2, &"observant": 3, &"hostile": 0}
## Default disposition by kind (the role in the plan). The disposition system
## sets `disposition` on a live machine; the lamps follow.
const ROLE_DISPOSITION := {
	&"harvester": &"indifferent", &"hauler": &"indifferent", &"cutter": &"indifferent",
	&"sweeper": &"indifferent", &"lineman": &"indifferent", &"warden": &"wary",
	&"watcher": &"observant", &"clerk": &"observant", &"longlegs": &"hostile",
	&"runner": &"hostile", &"dredger": &"hostile", &"flock": &"hostile",
}
## Vertex alpha the FOUND shader reads as a built-in light (found.gdshader:
## 0.5..0.98 steady, brighter lower). A lamp's lens and its hot core.
const LAMP_ALPHA := 0.8
const HOT_ALPHA := 0.55
## Smallest lamp that still reads as a lit pixel or two at gameplay zoom.
const LAMP_MIN := Vector2(0.05, 0.045)
## Direction from a model toward the fixed game camera (yaw 45, pitch 57; the
## camera never rotates). Used when no live camera is available (tests, gallery).
const TO_CAMERA := Vector3(0.3848, 0.8387, 0.3848)
const FOUND_SHADER := preload("res://src/render/found.gdshader")
const NIGHT_KEEP := 0.6
const SURFACES: Array[StringName] = [&"body", &"part", &"lights", &"matter"]

var ramp: Array = []
var part_material: ShaderMaterial
## The built-in lamps: FOUND with no uniform emission (vertex alpha lights them).
var lights_material: ShaderMaterial
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
## What the status lamps blink (DISPOSITION_CODE key).
var disposition: StringName = &"indifferent"
## The merged meshes by surface kind, once built.
var surfaces: Dictionary = {}
var skeleton: Skeleton3D

var _rest: Dictionary = {}
var _from: Dictionary = {}
var _lit := true
var _light := 1.0
var _shown_light := -1.0
var _flare := 0.0
var _dim := 1.0
var _dark_t := 0.0
var _was_running := true
var _stutter_on := true
## [target Object, property, lit Mesh, dark Mesh] for everything the part's light swaps.
var _part_swaps: Array = []
var _glow: MeshInstance3D
var _glow_mat: ShaderMaterial
var _glow_size := 0.7
var _scans: Array = []
var _beams: Array = []
var _dead_only: Array = []
## Lamps: {lamp: Node3D, hot: Node3D, role: StringName, side: bool, order: int}.
var _lamps: Array = []
## Surface kind -> Array of [MeshKit, Node3D] waiting for finish_rig().
var _queued: Dictionary = {}
## Every node between the model and a bone, parents first.
var _chain: Array[Node3D] = []
var _chain_parent: PackedInt32Array = PackedInt32Array()
var _chain_xf: Array[Transform3D] = []
var _chain_shown: PackedByteArray = PackedByteArray()
var _chain_at: Dictionary = {}
## Per bone: chain index (-1 the model itself) and the inverse of its rest pose.
var _bone_chain: PackedInt32Array = PackedInt32Array()
var _bone_bind: Array[Transform3D] = []
var _bone_of: Dictionary = {}
var _bone_last: Array[Transform3D] = []
var _bone_was_shown: PackedByteArray = PackedByteArray()
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
	lights_material = found_material(0.0)
	part_normal = side_normal(part_side)
	disposition = ROLE_DISPOSITION.get(kind, &"indifferent")


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


## A plain node on `parent` that pieces can hang on (a wheel, a lamp, a spill):
## it moves and hides with its own transform and visibility.
func holder(hname: String, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = hname
	n.position = pos
	parent.add_child(n)
	return n


## FOUND body geometry riding on `parent`.
func body_mesh(k: MeshKit, parent: Node3D) -> void:
	_queue(&"body", k, parent)


## Wear on `parent` (patches, grime, cable repairs): FOUND body geometry that
## rides on the joint's `wear` holder, so the machine as built can be told from
## what the years did to it (the mirror test takes the wear off).
func wear_mesh(k: MeshKit, parent: Node3D) -> void:
	_queue(&"body", k, _wear_on(parent))


## A trophy of the trade on `parent` (chaff in an intake, bones in a load, a
## rag on a knee): matter drawn by the hand, on the same `wear` holder.
func wear_matter(k: MeshKit, parent: Node3D) -> void:
	_queue(&"matter", k, _wear_on(parent))


func _wear_on(parent: Node3D) -> Node3D:
	var w := parent.get_node_or_null(^"wear") as Node3D
	return w if w != null else holder("wear", parent)


## Natural matter (ore, spoil, a cut row, bones) on the MADE material: the load
## is the land's, drawn by the hand, even when a machine carries it.
func matter_mesh(k: MeshKit, parent: Node3D) -> void:
	_queue(&"matter", k, parent)


## Geometry on the part material: glows, and swaps to its dark twin when the light goes out.
func part_mesh(k: MeshKit, parent: Node3D) -> void:
	_queue(&"part", k, parent)


## A steady cold light built into the body (kept for kinds that draw their own
## lens shapes): it glows through vertex alpha and goes out with the machine.
func cold_mesh(k: MeshKit, parent: Node3D) -> void:
	var lamp := holder("cold", parent)
	_set_alpha(k, LAMP_ALPHA)
	_queue(&"lights", k, lamp)
	_lamps.append({"lamp": lamp, "hot": null, "role": &"optic", "side": false, "order": _lamps.size(), "ri": _role_count(&"optic")})


## A lamp built into the plate at `c` (local to `parent`), facing `n`: a dark
## glass socket on the body, a cold lens that lights, and a hot core that shows
## when the lamp is driven hard. `role` says what it tells:
##   status  blinks the disposition code; double-blinks on alert; stutters hurt
##   optic   an eye: steady, locks bright on alert
##   work    a work lamp: steady while it works, hot at night and on the part's
##           side through a windup
## `on_part_side` marks a lamp that brightens with the working part.
func add_lamp(parent: Node3D, c: Vector3, n: Vector3, up: Vector3, w: float, h: float, role: StringName, on_part_side: bool = false, col: Color = Palette.COLD[3]) -> void:
	var nn := n.normalized()
	w = maxf(w * 1.3, LAMP_MIN.x)
	h = maxf(h * 1.3, LAMP_MIN.y)
	var socket := FoundKit.kit()
	FoundKit.mark(socket, c, nn, up, w + 0.03, h + 0.03, Palette.INK[1], 0.003)
	FoundKit.mark(socket, c, nn, up, w, h, Palette.COLD[0], 0.005)
	body_mesh(socket, parent)
	var lamp := holder("lamp", parent, c)
	var lk := FoundKit.kit()
	FoundKit.mark(lk, Vector3.ZERO, nn, up, w, h, col, 0.008)
	_set_alpha(lk, LAMP_ALPHA)
	_queue(&"lights", lk, lamp)
	var hot := holder("hot", parent, c)
	var hk := FoundKit.kit()
	FoundKit.mark(hk, Vector3.ZERO, nn, up, maxf(0.03, w * 0.55), maxf(0.03, h * 0.55), Palette.COLD[3], 0.011)
	_set_alpha(hk, HOT_ALPHA)
	_queue(&"lights", hk, hot)
	_lamps.append({"lamp": lamp, "hot": hot, "role": role, "side": on_part_side, "order": _lamps.size(), "ri": _role_count(role)})


func _role_count(role: StringName) -> int:
	var n := 0
	for l: Dictionary in _lamps:
		if l.role == role:
			n += 1
	return n


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
## On alert it stops dead centre: the eye has locked.
func add_scan(parent: Node3D, c: Vector3, n: Vector3, along: Vector3, span: float, h: float, period: float = 2.4) -> void:
	var hold := holder("scan", parent, c)
	var k := FoundKit.kit()
	FoundKit.mark(k, Vector3.ZERO, n, Vector3.UP if absf(n.y) < 0.9 else along.cross(n), minf(0.08, span * 0.3), h, Palette.COLD[3], 0.011)
	_set_alpha(k, LAMP_ALPHA)
	_queue(&"lights", k, hold)
	_scans.append([hold, c, along.normalized(), span, period])


## A beam: a stipple wedge of cold light thrown from `apex` along `dir` (local
## to `parent`), `length` long and `spread` wide at its far end. Drawn by
## beam.gdshader on a plain quad (a light has no plate to flash or blacken).
##   scan  what a watcher, warden or clerk reads: faint by day, it sweeps with
##         its joint, locks and narrows on alert, stutters hurt and dies early
##   work  the wash of a worker's lamps on the ground it works: dark by day, on
##         through dusk and night, harder through a windup when `on_part_side`
func add_beam(parent: Node3D, apex: Vector3, dir: Vector3, length: float, spread: float, role: StringName = &"scan", on_part_side: bool = false) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "beam"
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/models/machines/beam.gdshader")
	mat.render_priority = 10
	mat.set_shader_parameter("beam_length", length)
	mat.set_shader_parameter("beam_spread", spread)
	mat.set_shader_parameter("col", Vector3(Palette.COLD[3].r, Palette.COLD[3].g, Palette.COLD[3].b))
	mat.set_shader_parameter("day_floor", 0.2 if role == &"scan" else 0.0)
	mat.set_shader_parameter("root_width", 0.0 if role == &"scan" else 0.45)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = length + spread
	mi.position = apex
	# The quad's local +X runs along the beam, +Z across it.
	var d := dir.normalized()
	var side := d.cross(Vector3.UP)
	if side.length() < 0.1:
		side = Vector3.BACK
	side = side.normalized()
	mi.basis = Basis(d, side.cross(d), side)
	parent.add_child(mi)
	_beams.append([mi, mat, role, on_part_side])


## A node that only exists once the machine is dead (a spill, a split load),
## appearing `delay` seconds into the dead pose.
func dead_only(n: Node3D, delay: float) -> void:
	n.visible = false
	_dead_only.append([n, delay])


## Call last in build(): records the rest rig and merges every queued piece.
func finish_rig() -> void:
	for jn: StringName in joints:
		var n: Node3D = joints[jn]
		_rest[jn] = [n.position, n.rotation]
		_from[jn] = [n.position, n.rotation]
	_merge()
	_apply_light(0.0)
	_run_lights()
	_sync_bones()


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
	_run_lights()
	_show_dead_only()
	_sync_bones()


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
	_run_lights()
	_show_dead_only()
	_sync_bones()


## False while hurt or dead or switched off: mechanisms stop with the light.
func running() -> bool:
	return _lit and pose != &"hurt" and pose != &"dead"


## 0..1 current light of the working part (after the stepped relight and the stutter).
func light_level() -> float:
	return _shown_light if _stutter_on else 0.0


## Current emission strength on the working part (0 when out, lower when the
## camera sees the far side, higher in a flare or a windup).
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


## Every lamp's state now: role -> Array of 0 (out), 1 (lit), 2 (hot), in build order.
func lamp_levels() -> Dictionary:
	var out := {}
	for l: Dictionary in _lamps:
		var role: StringName = l.role
		if not out.has(role):
			out[role] = []
		var lvl := 0
		if (l.lamp as Node3D).visible:
			lvl = 2 if l.hot != null and (l.hot as Node3D).visible else 1
		(out[role] as Array).append(lvl)
	return out


## True while any scan highlight or beam is showing.
func scanning() -> bool:
	for s: Array in _scans:
		if (s[0] as Node3D).visible:
			return true
	for b: Array in _beams:
		if (b[0] as Node3D).visible:
			return true
	return false


## Where each scan highlight sits along its slit, 0..1 (0.5 is dead centre).
func scan_positions() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for s: Array in _scans:
		var along := ((s[0] as Node3D).position - (s[1] as Vector3)).dot(s[2] as Vector3)
		out.append(along / maxf(1e-5, float(s[3])) + 0.5)
	return out


## Model-space triangles of a merged surface as posed right now, with every
## collapsed (hidden) piece left out: what the skeleton makes of the mesh on the
## GPU, for tests and review tools that measure silhouettes and reach.
func posed_triangles(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return out
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if not arrays[Mesh.ARRAY_BONES] is PackedInt32Array:
		var xf := _model_space(mi)
		for v in verts:
			out.append(xf * v)
		return out
	var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
	_update_chain()
	var skin_xf: Array[Transform3D] = []
	var shown := PackedByteArray()
	for b in _bone_chain.size():
		var c := _bone_chain[b]
		var on := c < 0 or _chain_shown[c] == 1
		shown.append(1 if on else 0)
		skin_xf.append((Transform3D.IDENTITY if c < 0 else _chain_xf[c]) * _bone_bind[b])
	var bpv := bones.size() / maxi(1, verts.size())
	for t in range(0, verts.size(), 3):
		var b := bones[t * bpv]
		if shown[b] == 0:
			continue
		var xf := skin_xf[b]
		out.append(xf * verts[t])
		out.append(xf * verts[t + 1])
		out.append(xf * verts[t + 2])
	return out


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


## Multiplier on the part's light for the current pose: a windup brightens the
## working side toward twice its light, and the strike keeps it there.
func _light_scale() -> float:
	match pose:
		&"windup":
			return 1.0 + 0.9 * smoothstep(0.0, 0.6, minf(pose_time, 1.0))
		&"strike":
			return 1.9
	return 1.0


# -- internals: merging ------------------------------------------------------

func _queue(surface: StringName, k: MeshKit, parent: Node3D) -> void:
	if k.verts.is_empty():
		return
	if not _queued.has(surface):
		_queued[surface] = []
	(_queued[surface] as Array).append([k, parent])


static func _set_alpha(k: MeshKit, a: float) -> void:
	for i in k.colors.size():
		var c := k.colors[i]
		c.a = a
		k.colors[i] = c


func _merge() -> void:
	if _queued.is_empty():
		return
	for surface: StringName in SURFACES:
		if not _queued.has(surface):
			continue
		for piece: Array in _queued[surface]:
			_bone_for(piece[1] as Node3D)
	skeleton = Skeleton3D.new()
	skeleton.name = "skeleton"
	var skin := Skin.new()
	for b in _bone_chain.size():
		skeleton.add_bone("b%d" % b)
		skin.add_bind(b, _bone_bind[b])
		_bone_last.append(Transform3D(Basis(), Vector3(INF, INF, INF)))
		_bone_was_shown.append(2)
	add_child(skeleton)
	for surface: StringName in SURFACES:
		if not _queued.has(surface):
			continue
		var lit := _merged_mesh(_queued[surface] as Array, false)
		var mi := MeshInstance3D.new()
		mi.name = String(surface)
		mi.mesh = lit
		mi.skin = skin
		add_child(mi)
		mi.skeleton = NodePath("../skeleton")
		match surface:
			&"part":
				mi.material_override = part_material
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_part_swaps.append([mi, &"mesh", lit, _merged_mesh(_queued[surface] as Array, true)])
			&"lights":
				mi.material_override = lights_material
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			&"matter":
				mi.material_override = _matter_material()
			_:
				mi.material_override = material
		surfaces[surface] = mi
	_queued.clear()


static var _matter_mat: ShaderMaterial


static func _matter_material() -> ShaderMaterial:
	if _matter_mat == null:
		_matter_mat = ShaderMaterial.new()
		_matter_mat.shader = preload("res://src/render/world.gdshader")
	return _matter_mat


## The bone a node's pieces ride on, registering the node's ancestry in the chain.
func _bone_for(n: Node3D) -> int:
	var key := n.get_instance_id()
	if _bone_of.has(key):
		return int(_bone_of[key])
	var c := _chain_index(n)
	var b := _bone_chain.size()
	_bone_chain.append(c)
	_bone_bind.append(_model_space(n).affine_inverse())
	_bone_of[key] = b
	return b


func _chain_index(n: Node3D) -> int:
	if n == self:
		return -1
	var key := n.get_instance_id()
	if _chain_at.has(key):
		return int(_chain_at[key])
	var parent := n.get_parent() as Node3D
	var pi := _chain_index(parent) if parent != null else -1
	var c := _chain.size()
	_chain.append(n)
	_chain_parent.append(pi)
	_chain_xf.append(Transform3D.IDENTITY)
	_chain_shown.append(1)
	_chain_at[key] = c
	return c


func _merged_mesh(pieces: Array, dark: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var custom0 := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for piece: Array in pieces:
		var k: MeshKit = piece[0]
		var n: Node3D = piece[1]
		var b := _bone_for(n)
		var xf := _bone_bind[b].affine_inverse()
		# Rigid pieces: whole arrays through the rest transform at once (joints never scale).
		verts.append_array(xf * k.verts)
		normals.append_array(Transform3D(xf.basis, Vector3.ZERO) * k.normals)
		bones.append_array(_repeat_ints(b, k.verts.size()))
		weights.append_array(_repeat_weights(k.verts.size()))
		if dark:
			for col in k.colors:
				colors.append(FoundKit.dark_colour(col))
		else:
			colors.append_array(k.colors)
		uvs.append_array(k.uvs)
		uv2s.append_array(k.uv2s)
		custom0.append_array(k.custom0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_CUSTOM0] = custom0
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh


## [b, 0, 0, 0] repeated `count` times, built by doubling.
static func _repeat_ints(b: int, count: int) -> PackedInt32Array:
	var out := PackedInt32Array([b, 0, 0, 0])
	while out.size() < count * 4:
		out.append_array(out.slice(0, mini(out.size(), count * 4 - out.size())))
	return out


static var _weights_cache := PackedFloat32Array()


## [1, 0, 0, 0] repeated `count` times.
static func _repeat_weights(count: int) -> PackedFloat32Array:
	while _weights_cache.size() < count * 4:
		if _weights_cache.is_empty():
			_weights_cache = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
		_weights_cache.append_array(_weights_cache)
	return _weights_cache.slice(0, count * 4)


## Model-space transform and shown flag for every chain node, parents first.
func _update_chain() -> void:
	for c in _chain.size():
		var n := _chain[c]
		var p := _chain_parent[c]
		if p < 0:
			_chain_xf[c] = n.transform
			_chain_shown[c] = 1 if n.visible else 0
		else:
			_chain_xf[c] = _chain_xf[p] * n.transform
			_chain_shown[c] = 1 if n.visible and _chain_shown[p] == 1 else 0


func _sync_bones() -> void:
	if skeleton == null:
		return
	_update_chain()
	for b in _bone_chain.size():
		var c := _bone_chain[b]
		var xf := Transform3D.IDENTITY if c < 0 else _chain_xf[c]
		var on := 1 if c < 0 or _chain_shown[c] == 1 else 0
		if on == _bone_was_shown[b] and xf.is_equal_approx(_bone_last[b]):
			continue
		_bone_last[b] = xf
		_bone_was_shown[b] = on
		skeleton.set_bone_pose_position(b, xf.origin)
		skeleton.set_bone_pose_rotation(b, xf.basis.get_rotation_quaternion())
		# A hidden piece folds to a point: no triangle of it reaches the screen.
		skeleton.set_bone_pose_scale(b, Vector3.ONE if on == 1 else Vector3.ZERO)


# -- internals: pose ----------------------------------------------------------

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
		# Falling accelerates; an alert servo snaps and stops dead; the rest
		# start and stop exactly.
		if pose == &"dead":
			e = e * e
		elif pose == &"alert":
			e = 1.0 - pow(1.0 - e, 3.0)
		else:
			e = smoothstep(0.0, 1.0, e)
		var f: Array = _from[jn]
		n.position = (f[0] as Vector3).lerp(tp, e)
		n.rotation = (f[1] as Vector3).lerp(tr, e)


func _show_dead_only() -> void:
	for d: Array in _dead_only:
		(d[0] as Node3D).visible = pose == &"dead" and pose_time >= float(d[1])


func _run_scans() -> void:
	var locked := pose == &"alert" or pose == &"windup" or pose == &"strike"
	for s: Array in _scans:
		var hold: Node3D = s[0]
		var period: float = s[4]
		# Across, hold, back, hold: the same sweep forever, until it locks.
		var x := 0.5
		if not locked:
			var t := fposmod(clock, period) / period
			x = 0.0
			if t < 0.35:
				x = smoothstep(0.0, 1.0, t / 0.35)
			elif t < 0.5:
				x = 1.0
			elif t < 0.85:
				x = 1.0 - smoothstep(0.0, 1.0, (t - 0.5) / 0.35)
		hold.position = (s[1] as Vector3) + (s[2] as Vector3) * ((x - 0.5) * (s[3] as float))


# -- internals: light ---------------------------------------------------------

func _stutter(t: float) -> bool:
	return int(STUTTER_BITS[int(floorf(maxf(t, 0.0) * 24.0)) % STUTTER_BITS.size()]) == 1


func _apply_light(delta: float) -> void:
	var run := running()
	if run != _was_running:
		_was_running = run
		_dark_t = 0.0
	else:
		_dark_t += delta
	_stutter_on = true
	if run:
		_light = move_toward(_light, 1.0, delta * 4.0) if delta > 0.0 else 1.0
	elif pose == &"dead":
		# The part is the last light on a dying machine, and it flickers going.
		# A body that was already dark keeps what light it had: none.
		if pose_time >= PART_OUT:
			_light = 0.0
		elif pose_time >= PART_OUT - 0.12:
			_stutter_on = _stutter(pose_time * 1.5)
	elif _dark_t < STUTTER and delta > 0.0:
		_stutter_on = _stutter(_dark_t)
	else:
		_light = 0.0
	# Relight in three exact steps; go out at once.
	var shown := floorf(_light * 3.0 + 0.001) / 3.0
	_flare = maxf(0.0, _flare - delta * 3.5)
	var facing := _part_facing()
	var want_dim := 1.0 if facing > -0.15 else 0.35
	_dim = want_dim if delta <= 0.0 else lerpf(_dim, want_dim, 1.0 - exp(-12.0 * delta))
	if shown != _shown_light:
		for sw: Array in _part_swaps:
			(sw[0] as Object).set(sw[1], sw[2] if shown > 0.0 else sw[3])
		_shown_light = shown
	# Emission tops the part up to its own colour however dark the sky is: by day
	# the sun already lights it, by night the light is all its own.
	var dark := darkness()
	# The floor is high enough that a part in its own shadow at noon is still
	# the brightest warm thing on sand: the soft side must read by day.
	var glow := emission * (1.0 + 3.0 * dark)
	var on := shown * (1.0 if _stutter_on else 0.0)
	part_material.set_shader_parameter("emission_strength", (glow * _light_scale() + _flare * 2.5) * on * _dim)
	if _glow != null:
		_glow.visible = on > 0.0
		_glow_mat.set_shader_parameter("strength", on * (0.55 + _flare * 1.6 + 0.35 * (_light_scale() - 1.0)) * lerpf(0.8, 1.0, _dim))
		var s := 1.0 + _flare * 0.6
		_glow.scale = Vector3(s, s, s)


## Every lamp, scan and beam from the pose and the clock: exact patterns only.
func _run_lights() -> void:
	var dark := darkness()
	var run := running()
	var hurt_like := not run and pose != &"dead"
	var flick := _stutter(_dark_t + 0.13)
	for l: Dictionary in _lamps:
		var role: StringName = l.role
		var lvl := 0
		if pose == &"dead":
			var at: float = float(DIE_AT.get(role, 0.1)) + minf(0.06, int(l.ri) * 0.02)
			lvl = 1 if pose_time < minf(at, PART_OUT - 0.02) else 0
		elif hurt_like:
			lvl = 1 if flick and (int(l.order) % 2 == 0 or _dark_t < STUTTER) else 0
		else:
			lvl = _lamp_level(role, bool(l.side), int(l.order), dark)
		(l.lamp as Node3D).visible = lvl > 0
		if l.hot != null:
			(l.hot as Node3D).visible = lvl > 1
	for s: Array in _scans:
		var sv := run
		if pose == &"dead":
			sv = pose_time < float(DIE_AT[&"scan"])
		elif hurt_like:
			sv = flick and _dark_t < STUTTER
		(s[0] as Node3D).visible = sv
	var locked := pose == &"alert" or pose == &"windup" or pose == &"strike"
	for b: Array in _beams:
		var mi: MeshInstance3D = b[0]
		var mat: ShaderMaterial = b[1]
		var work: bool = b[2] == &"work"
		var bv := run and (not work or dark > 0.12)
		if pose == &"dead":
			bv = pose_time < float(DIE_AT[&"work" if work else &"beam"]) and (not work or dark > 0.12)
		elif hurt_like:
			bv = flick and _dark_t < STUTTER and (not work or dark > 0.12)
		mi.visible = bv
		if work:
			var hard := bool(b[3]) and (pose == &"windup" or pose == &"strike")
			mat.set_shader_parameter("strength", 1.2 if hard else 0.6)
			mat.set_shader_parameter("narrow", 1.0)
		else:
			mat.set_shader_parameter("strength", 1.4 if locked else 0.85)
			mat.set_shader_parameter("narrow", 0.55 if locked else 1.0)


## A running machine's lamp: 0 out, 1 lit, 2 hot.
func _lamp_level(role: StringName, side: bool, order: int, dark: float) -> int:
	var locked := pose == &"alert" or pose == &"windup" or pose == &"strike"
	match role:
		&"status":
			if pose == &"alert":
				# Double-blink, fast and hard, over and over.
				var t := fposmod(clock + order * 0.05, 0.6)
				return 2 if t < 0.08 or (t >= 0.16 and t < 0.24) else 0
			if pose == &"windup" or pose == &"strike":
				return 2
			var code: int = DISPOSITION_CODE.get(disposition, 1)
			if code == 0:
				return 1
			# `code` short blinks, then a rest: the same count forever.
			var cycle := 0.3 * code + 1.6
			var t2 := fposmod(clock + order * 0.07, cycle)
			var slot := int(t2 / 0.3)
			return 2 if slot < code and fposmod(t2, 0.3) < 0.12 else 0
		&"optic":
			return 2 if locked else 1
		&"work":
			if side and (pose == &"windup" or pose == &"strike"):
				return 2
			if pose == &"alert":
				return 2
			return 2 if dark > 0.25 else 1
	return 1


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
