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

const PERSON_SHADER := preload("res://src/models/people/person.gdshader")
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
## The pose last put on the skeleton. Positions are read from it by FK, because a
## Skeleton3D only refreshes its global poses inside a running tree.
var _applied: PersonAnim.Pose


func build(mat: Material) -> void:
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == PERSON_SHADER:
		_person_mat = mat
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
			_last = _resolved(action, _action_len, _action_len)
			_end_action()
		else:
			action_left = maxf(0.0, _action_len - _action_t)
			_weight = minf(1.0, _weight + delta * 18.0) if delta > 0.0 else _weight
			_last = _resolved(action, _action_t, _action_len)
	if action == &"" and _weight > 0.0:
		_weight = maxf(0.0, _weight - delta * 7.0)
	if _last != null and _weight > 0.0:
		# A copy: _last may be a cached pose other people are wearing too.
		var act := _last.copy()
		if PersonAnim.UPPER_ONLY.has(action) and _speed > 0.3:
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


## Resolved (IK-solved) action poses, shared by everyone of a build holding the
## same thing: a village of workers costs a lookup a frame, not an IK solve.
## Time is quantised to 1/60 s and folded into the loop for looping actions.
static var _pose_cache: Dictionary = {}


func _resolved(a: StringName, t: float, length: float) -> PersonAnim.Pose:
	var period := PersonAnim.loop_period(a, held)
	var tq := t
	if period > 0.0:
		tq = fposmod(t, period)
	elif a == &"downed":
		# Cheap (no IK) and it breathes for ever: never cached.
		return PersonAnim.resolve(rig, PersonAnim.action(a, t, length, _dims, held), held)
	var frame := roundi(tq * 60.0)
	var key := "%s|%s|%s|%d|%d" % [look.build, held, a, roundi(length * 1000.0), frame]
	var hit: PersonAnim.Pose = _pose_cache.get(key)
	if hit != null:
		return hit
	if _pose_cache.size() > 6000:
		_pose_cache.clear()
	var p := PersonAnim.resolve(rig, PersonAnim.action(a, frame / 60.0 + (t - tq), length, _dims, held), held)
	_pose_cache[key] = p
	return p


func _end_action() -> void:
	action = &""
	action_left = 0.0
	_action_t = 0.0
	_action_len = 0.0
	_frozen = -1.0


static func _smooth(w: float) -> float:
	return w * w * (3.0 - 2.0 * w)


func _apply(p: PersonAnim.Pose) -> void:
	_applied = p
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
	rig.attach(self, _material(), true)


func _dress() -> void:
	rig.clear_parts()
	PersonBody.dress(rig, look)
	HeldTools.build(rig, held)
	rig.rebuild(_material(), true)


func _material() -> Material:
	return material()


static var _person_mat: ShaderMaterial


## The material every person draws with (src/models/people/person.gdshader): the
## MADE look plus the readability rim, in the pass after the ink outline. A
## material passed to build() is used only if it is already on that shader.
static func material() -> ShaderMaterial:
	if _person_mat == null:
		_person_mat = ShaderMaterial.new()
		_person_mat.shader = PERSON_SHADER
		_person_mat.render_priority = 10
		var rim := ShaderMaterial.new()
		rim.shader = preload("res://src/models/people/person_rim.gdshader")
		rim.render_priority = 10
		_person_mat.next_pass = rim
	return _person_mat


## Triangles in the body (and clothes, hair, salvage), excluding the held tool.
func body_triangles() -> int:
	return rig.triangle_count([&"body", &"salvage", &"salvage_glow", &"food"])


func tool_triangles() -> int:
	return rig.triangle_count([&"tool", &"tool_glow"])


## Model-space position of the right hand's grip (hit sparks, carried items).
func hand_position() -> Vector3:
	return bone_transform(&"tool").origin


## Model-space transform of any bone under the current pose.
func bone_transform(bone: StringName) -> Transform3D:
	if _applied == null or rig.find(bone) < 0:
		return Transform3D.IDENTITY
	return PersonAnim.fk(rig, _applied, rig.find(bone))


## Model-space position of the held tool's far end.
func tool_tip() -> Vector3:
	var reach := 0.3
	match HeldTools.klass(held):
		&"heavy", &"pick": reach = 0.5
		&"sweep", &"thrust": reach = 0.8
		&"fist": reach = 0.0
	return bone_transform(&"tool") * Vector3(0, reach, 0)


static func make(spec: Dictionary, item: StringName = &"", mat: Material = null) -> PersonModel:
	var p := PersonModel.new()
	p.set_look(spec)
	p.held = item
	p.build(mat)
	return p


# ---------------------------------------------------------------- gallery

const FACE_CAMERA := -PI * 0.25
const FACE_RIGHT := PI * 0.25


static func gallery() -> Array:
	var mat := material()
	var out: Array = []

	var player := make({}, &"knife", mat)
	player.rotation.y = FACE_CAMERA
	out.append({"name": "player", "node": player})

	var builds: Array = []
	for b: StringName in PersonLook.BUILDS:
		var old := b == &"old" or b == &"bent"
		builds.append([{"build": b, "hair_style": &"thin" if old else &"crop", "hair": &"grey" if old else &"dark"}, &"", String(b)])
	out.append_array(_items("people builds", builds, mat, 5, 0.52, FACE_CAMERA))

	var crowd: Array = []
	for spec: Dictionary in PersonLook.crowd(11, 10):
		crowd.append([spec, &"", ""])
	out.append_array(_items("people looks", crowd, mat, 5, 0.52, FACE_CAMERA))

	var hats: Array = []
	for h: StringName in PersonLook.HATS:
		hats.append([{"hat": h, "hat_col": "earth:3" if hats.size() % 2 else "slate:2", "coat": PersonLook.COATS[hats.size() % PersonLook.COATS.size()]}, &"", String(h)])
	out.append_array(_items("people hats coats", hats, mat, 4, 0.52, FACE_CAMERA))

	var hair: Array = []
	var k := 0
	for st: StringName in PersonLook.HAIR_STYLES:
		hair.append([{"hair_style": st, "hair": PersonLook.HAIR_PRESETS[k % PersonLook.HAIR_PRESETS.size()], "beard": PersonLook.BEARDS[k % PersonLook.BEARDS.size()], "skin": PersonLook.SKIN_WINDOWS[k % 4], "skin_v": 1 + k % 3}, &"", String(st)])
		k += 1
	out.append_array(_items("people hair beards", hair, mat, 4, 0.52, FACE_RIGHT))

	var kit: Array = []
	k = 0
	for part: StringName in PersonLook.SALVAGE:
		var spec := PersonLook.random(40 + k, k)
		spec.salvage = [part]
		spec.side = 1
		kit.append([spec, &"", String(part)])
		k += 1
	out.append_array(_items("people salvage", kit, mat, 4, 0.55, FACE_CAMERA))

	var gait := Node3D.new()
	var gaits: Array = [[PersonAnim.GAIT_WALK, 0.0], [PersonAnim.GAIT_WALK, 0.25], [PersonAnim.GAIT_RUN, 0.0], [PersonAnim.GAIT_RUN, 0.25]]
	for i in gaits.size():
		var g: Array = gaits[i]
		var pm := make({"coat": &"long", "coat_col": "earth:2"} if i < 2 else {}, &"knife", mat)
		pm._phase = g[1]
		pm.animate(g[0], 0.0)
		pm.rotation.y = FACE_RIGHT
		_place(gait, pm, i, 2, 1.0, "")
	out.append({"name": "person walk run", "node": gait})

	# Each swing at the moment the blow lands: the most telling frame of the fight.
	var swings: Array = []
	for id: StringName in [&"", &"knife", &"billhook", &"axe_hand", &"axe_felling", &"pick", &"stave", &"boathook", &"stun_hand"]:
		var ms := HeldTools.swing_ms(id)
		var total := float(ms[0] + ms[1] + ms[2])
		swings.append([PersonLook.random(120, swings.size()), id, String(HeldTools.klass(id)), &"swing", (ms[0] + ms[1] * 0.45) / 1000.0])
	out.append_array(_items("person swings", swings, mat, 3, 1.0, FACE_RIGHT))

	var acts: Array = [
		[PersonLook.random(90, 0), &"knife", "dodge", &"dodge", 0.17], [PersonLook.random(90, 1), &"knife", "hurt", &"hurt", 0.07],
		[PersonLook.random(90, 2), &"", "eat", &"eat", 0.4], [PersonLook.random(90, 3), &"knife", "downed", &"downed", 2.0],
		[PersonLook.random(90, 4), &"", "carried", &"carried", 0.6], [PersonLook.random(90, 5), &"pick", "break", &"work_break", 0.52],
		[PersonLook.random(90, 6), &"mattock", "dig", &"work_dig", 0.7], [PersonLook.random(90, 7), &"axe_felling", "fell", &"work_fell", 0.66],
		[PersonLook.random(90, 8), &"knife", "cut", &"work_cut", 0.1], [PersonLook.random(90, 9), &"", "gather", &"gather", 0.45],
	]
	out.append_array(_items("person actions", acts, mat, 2, 1.25, FACE_RIGHT))

	var made: Array = []
	for id: StringName in HeldTools.MADE:
		made.append([PersonLook.random(200, made.size()), id, String(id)])
	out.append_array(_items("person tools made", made, mat, 3, 0.8, FACE_CAMERA))
	var found: Array = []
	for id: StringName in HeldTools.FOUND:
		found.append([PersonLook.random(300, found.size()), id, String(id)])
	out.append_array(_items("person tools found", found, mat, 3, 0.8, FACE_CAMERA))
	return out


## Gallery items of people, at most two rows each so every item fits one gallery
## square. A row is [spec, held, label] or [spec, held, label, action, seconds in].
static func _items(title: String, rows: Array, mat: Material, cols: int, spacing: float, facing: float) -> Array:
	var out: Array = []
	var per := cols * 2
	var part := 0
	for start in range(0, rows.size(), per):
		var g := Node3D.new()
		var labels: PackedStringArray = []
		for i in range(start, mini(start + per, rows.size())):
			var row: Array = rows[i]
			var pm := make(row[0], row[1], mat)
			if row.size() > 4:
				pm.pose_at(row[3], row[4])
			pm.rotation.y = facing
			_place(g, pm, i - start, cols, spacing, row[2])
			if String(row[2]) != "":
				labels.append(String(row[2]))
		var name := title if rows.size() <= per else "%s %s" % [title, "abcdefgh"[part]]
		if not labels.is_empty():
			name += ": " + " ".join(labels)
		out.append({"name": name, "node": g})
		part += 1
	return out


## Lay subject i out along screen-right (world +X-Z) in rows that step toward the camera.
static func _place(g: Node3D, n: Node3D, i: int, cols: int, spacing: float, label: String) -> void:
	var across := Vector3(1, 0, -1).normalized()
	var down := Vector3(1, 0, 1).normalized()
	var col := i % cols
	var row := i / cols
	n.position = across * (col - (cols - 1) * 0.5) * spacing + down * (row - 0.5) * maxf(0.85, spacing)
	g.add_child(n)
	n.set_meta(&"label", label)
