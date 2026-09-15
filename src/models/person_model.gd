class_name PersonModel
extends Node3D
## A person: one skinned mesh on a skeleton, dressed from a look spec, holding
## one thing, animated procedurally. Faces +X at rotation 0 (the same convention
## as Player.facing: set rotation.y = -facing).
##
## Contract used by fight, survival and later NPCs:
##   build(material)               make the figure (call once, before or after set_look)
##   animate(speed, delta)         every frame: speed in tiles/s actually moved
##   play_action(action, seconds)  &"swing" &"dodge" &"work" &"hurt" &"eat" &"carried" &"downed"
##                                 also &"work_break" &"work_dig" &"work_fell" &"work_cut" &"gather";
##                                 &"" clears. seconds <= 0 uses the natural length, and
##                                 &"carried"/&"downed" hold until replaced. A swing is phased by
##                                 the held tool's windup/active/recovery: pass their sum.
##   set_held(item)                the held tool in the right hand (&"" = bare hands)
##   set_look(spec)                see PersonLook: build, hat, coat, hair, shirt, trouser, boot, salvage...
## Read-only helpers: busy(), action_progress(), hand_position(), tool_tip().

var look: Dictionary = PersonLook.normalize({})
var held: StringName = &""
var action: StringName = &""
## Seconds left in the current action (0 when idle or holding a held action).
var action_left := 0.0
var rig: SkinRig

var _mat: Material
var _dims: Dictionary = PersonBody.dims(&"man")
var _phase := 0.0
var _clock := 0.0
var _speed := 0.0
var _action_t := 0.0
var _action_len := 0.0
var _weight := 0.0
var _last: PersonAnim.Pose
var _frozen := -1.0
## Where the head looks, radians from facing (positive = left); NAN = its own glances.
var gaze := NAN
var _gaze_now := 0.0


func build(material: Material) -> void:
	_mat = material
	_clock = float(hash(PersonLook.signature(look)) % 1000) * 0.013
	_make_rig()
	animate(0.0, 0.0)


func set_look(spec: Dictionary) -> void:
	var next := PersonLook.normalize(spec)
	var rebuild_bones: bool = rig != null and next.build != look.build
	look = next
	_dims = PersonBody.dims(look.build)
	if rig == null:
		return
	if rebuild_bones:
		_make_rig()
	else:
		_dress()
	animate(0.0, 0.0)


func set_held(item: StringName) -> void:
	if item == held and rig != null:
		return
	held = item
	if rig != null:
		_dress()
		animate(0.0, 0.0)


func play_action(a: StringName, seconds: float) -> void:
	if a == &"":
		_end_action()
		return
	if not PersonAnim.ACTIONS.has(a):
		push_warning("PersonModel: unknown action %s" % a)
		return
	action = a
	_action_t = 0.0
	_action_len = seconds if seconds > 0.0 else PersonAnim.default_seconds(a, held)
	if PersonAnim.HELD.has(a) and seconds <= 0.0:
		_action_len = 0.0
	action_left = _action_len
	_frozen = -1.0
	# Swings and dodges must read on the first frame: no blend-in to wait for.
	if a == &"swing" or a == &"dodge" or a == &"hurt":
		_weight = 1.0


## Freeze an action at seconds `t` into it (gallery, shots, tests). Replaces any action.
func pose_at(a: StringName, t: float, seconds: float = 0.0) -> void:
	play_action(a, seconds)
	_action_t = t
	_frozen = t
	_weight = 1.0
	animate(0.0, 0.0)


func busy() -> bool:
	return action != &""


## 0..1 through the current action (held actions report 1 once settled).
func action_progress() -> float:
	if action == &"":
		return 0.0
	if _action_len <= 0.0:
		return 1.0
	return clampf(_action_t / _action_len, 0.0, 1.0)


## speed: tiles/second actually moved. delta: seconds.
func animate(speed: float, delta: float) -> void:
	if rig == null:
		return
	_clock += delta
	_speed = lerpf(_speed, speed, 1.0 - exp(-12.0 * delta)) if delta > 0.0 else speed
	var leg: float = _dims.thigh + _dims.shin + _dims.boot
	if _speed > 0.05:
		_phase = fposmod(_phase + delta * _speed / PersonAnim.cycle_length(_speed, leg), 1.0)
	var klass := HeldTools.klass(held)
	var pose := PersonAnim.locomotion(_phase, _speed, _clock, _dims, klass)
	if action != &"":
		if _frozen < 0.0:
			_action_t += delta
		if _action_len > 0.0 and _action_t >= _action_len and _frozen < 0.0:
			_last = PersonAnim.resolve(rig, PersonAnim.action(action, _action_len, _action_len, _dims, held), held)
			_end_action()
		else:
			action_left = maxf(0.0, _action_len - _action_t)
			_weight = minf(1.0, _weight + delta * 18.0) if delta > 0.0 else _weight
			_last = PersonAnim.resolve(rig, PersonAnim.action(action, _action_t, _action_len, _dims, held), held)
	if action == &"" and _weight > 0.0:
		_weight = maxf(0.0, _weight - delta * 7.0)
	if _last != null and _weight > 0.0:
		var act := _last
		if PersonAnim.UPPER_ONLY.has(action) and _speed > 0.3:
			act = _last.copy()
			var move := smoothstep(0.3, 1.5, _speed)
			for b: StringName in PersonAnim.LOWER:
				act.rot[b] = act.r(b).lerp(pose.r(b), move)
				act.off[b] = act.o(b).lerp(pose.o(b), move)
		pose = PersonAnim.mix(pose, act, _smooth(_weight))
	var want := 0.0 if is_nan(gaze) or _weight > 0.0 else gaze
	_gaze_now = lerpf(_gaze_now, want, 1.0 - exp(-5.0 * delta)) if delta > 0.0 else want
	if absf(_gaze_now) > 0.002 and _weight <= 0.0:
		# A watched head overrides the idle glance; the chest turns a little with it.
		var h := pose.r(&"head")
		pose.rot[&"head"] = Vector3(h.x, lerpf(h.y, _gaze_now * 0.75, minf(1.0, absf(_gaze_now) * 3.0)), h.z)
		var s := pose.r(&"spine")
		pose.rot[&"spine"] = Vector3(s.x, s.y + _gaze_now * 0.25, s.z)
	_apply(pose)


func _end_action() -> void:
	action = &""
	action_left = 0.0
	_action_t = 0.0
	_action_len = 0.0
	_frozen = -1.0


static func _smooth(w: float) -> float:
	return w * w * (3.0 - 2.0 * w)


func _apply(p: PersonAnim.Pose) -> void:
	for i in rig.names.size():
		var n := rig.names[i]
		rig.pose(i, p.r(n), p.o(n))
	var food := rig.find(&"food")
	rig.skeleton.set_bone_pose_scale(food, Vector3.ONE * maxf(0.001, p.food))


func _make_rig() -> void:
	if rig != null and rig.skeleton != null:
		remove_child(rig.skeleton)
		rig.skeleton.queue_free()
	rig = PersonBody.make_rig(look.build)
	_dims = PersonBody.dims(look.build)
	PersonBody.dress(rig, look)
	HeldTools.build(rig, held)
	rig.attach(self, _material())


func _dress() -> void:
	rig.clear_parts()
	PersonBody.dress(rig, look)
	HeldTools.build(rig, held)
	rig.rebuild(_material())


func _material() -> Material:
	if _mat == null:
		var m := ShaderMaterial.new()
		m.shader = preload("res://src/render/world.gdshader")
		_mat = m
	return _mat


## Triangles in the body (and clothes, hair, salvage), excluding the held tool.
func body_triangles() -> int:
	return rig.triangle_count([&"body", &"salvage", &"salvage_glow", &"food"])


func tool_triangles() -> int:
	return rig.triangle_count([&"tool", &"tool_glow"])


## Model-space position of the right hand's grip (hit sparks, carried items).
func hand_position() -> Vector3:
	return rig.bone_global(rig.find(&"tool")).origin


## Model-space position of the held tool's far end.
func tool_tip() -> Vector3:
	var reach := 0.3
	match HeldTools.klass(held):
		&"heavy", &"pick": reach = 0.5
		&"sweep", &"thrust": reach = 0.8
		&"fist": reach = 0.0
	return rig.bone_global(rig.find(&"tool")) * Vector3(0, reach, 0)


static func make(spec: Dictionary, item: StringName = &"", material: Material = null) -> PersonModel:
	var p := PersonModel.new()
	p.set_look(spec)
	p.held = item
	p.build(material)
	return p


# ---------------------------------------------------------------- gallery

const FACE_CAMERA := -PI * 0.25
const FACE_RIGHT := PI * 0.25


static func gallery() -> Array:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/render/world.gdshader")
	var out: Array = []

	var player := make({}, &"knife", mat)
	player.rotation.y = FACE_CAMERA
	out.append({"name": "player", "node": player})

	var walk := make({}, &"knife", mat)
	walk.rotation.y = FACE_RIGHT
	for i in 20:
		walk.animate(PersonAnim.GAIT_WALK, 0.0165)
	out.append({"name": "person walking", "node": walk})

	var run := make({"coat": &"long", "coat_col": "earth:2", "hat": &"cap"}, &"pick", mat)
	run.rotation.y = FACE_RIGHT
	for i in 23:
		run.animate(PersonAnim.GAIT_RUN, 0.0165)
	out.append({"name": "person running", "node": run})

	var builds: Array = []
	for b: StringName in PersonLook.BUILDS:
		builds.append([{"build": b, "hair_style": &"crop" if b != &"old" else &"thin", "hair": &"dark" if b != &"old" else &"grey"}, &"", String(b)])
	out.append({"name": "people builds", "node": _group(builds, mat, 5, FACE_CAMERA)})

	var crowd: Array = []
	for spec: Dictionary in PersonLook.crowd(11, 10):
		crowd.append([spec, &"", ""])
	out.append({"name": "people looks", "node": _group(crowd, mat, 5, FACE_CAMERA)})

	var kit: Array = []
	var k := 0
	for part: StringName in PersonLook.SALVAGE:
		var spec := PersonLook.random(40 + k, k)
		spec.salvage = [part]
		spec.side = 1
		kit.append([spec, &"", String(part)])
		k += 1
	out.append({"name": "people salvage", "node": _group(kit, mat, 4, FACE_CAMERA)})

	var acts: Array = [
		[&"dodge", 0.17, &"knife"], [&"hurt", 0.07, &"knife"], [&"eat", 0.4, &""], [&"downed", 2.0, &"knife"],
		[&"carried", 0.6, &""], [&"work_break", 0.52, &"pick"], [&"work_dig", 0.7, &"mattock"], [&"work_fell", 0.66, &"axe_felling"],
		[&"work_cut", 0.1, &"knife"], [&"gather", 0.45, &""],
	]
	var act_group := Node3D.new()
	for i in acts.size():
		var a: Array = acts[i]
		var pm := make(PersonLook.random(90, i), a[2], mat)
		pm.pose_at(a[0], a[1])
		pm.rotation.y = FACE_RIGHT
		_place(act_group, pm, i, 4, 0.95, String(a[0]))
	out.append({"name": "person actions", "node": act_group})

	var swings: Array = [[&"", 0.42], [&"knife", 0.5], [&"billhook", 0.45], [&"axe_hand", 0.3], [&"axe_felling", 0.36], [&"pick", 0.55], [&"stave", 0.5], [&"boathook", 0.5], [&"stun_hand", 0.55]]
	var sw := Node3D.new()
	for i in swings.size():
		var s: Array = swings[i]
		var pm := make(PersonLook.random(120, i), s[0], mat)
		pm.pose_at(&"swing", s[1] * PersonAnim.default_seconds(&"swing", s[0]))
		pm.rotation.y = FACE_RIGHT
		_place(sw, pm, i, 3, 1.05, String(HeldTools.klass(s[0])))
	out.append({"name": "person swings", "node": sw})

	var made: Array = []
	for id: StringName in HeldTools.MADE:
		made.append([PersonLook.random(200, made.size()), id, String(id)])
	out.append({"name": "person tools made", "node": _group(made, mat, 4, FACE_CAMERA, 0.9)})
	var found: Array = []
	for id: StringName in HeldTools.FOUND:
		found.append([PersonLook.random(300, found.size()), id, String(id)])
	out.append({"name": "person tools found", "node": _group(found, mat, 4, FACE_CAMERA, 0.9)})
	return out


## A small formation of people: [spec, held, label] rows, `cols` across the screen.
static func _group(rows: Array, mat: Material, cols: int, facing: float, spacing: float = 0.62) -> Node3D:
	var g := Node3D.new()
	for i in rows.size():
		var row: Array = rows[i]
		var pm := make(row[0], row[1], mat)
		pm.rotation.y = facing
		_place(g, pm, i, cols, spacing, row[2])
	return g


## Lay subject i out along screen-right (world +X-Z) in rows that step toward the camera.
static func _place(g: Node3D, n: Node3D, i: int, cols: int, spacing: float, label: String) -> void:
	var across := Vector3(1, 0, -1).normalized()
	var down := Vector3(1, 0, 1).normalized()
	var col := i % cols
	var row := i / cols
	n.position = across * (col - (cols - 1) * 0.5) * spacing + down * (row - 0.5) * 1.15
	g.add_child(n)
	n.set_meta(&"label", label)
