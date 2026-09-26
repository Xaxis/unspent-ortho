class_name PersonModel
extends Node3D
## A person: one skinned mesh on a skeleton, dressed from a look spec, holding
## one thing, animated procedurally. Faces +X at rotation 0 (the same convention
## as Player.facing: set rotation.y = -facing).
##
## Drawn per docs/LOOK.md: MADE in the hand (person.gdshader, Ink.HAND hatching,
## never on skin), no ink outline but a one-pixel rim in the person's own colours
## (person_rim.gdshader), FOUND salvage and glims on found.gdshader.
##
## Contract used by fight, survival and later NPCs:
##   build(material)               make the figure (call once, before or after set_look). People
##                                 always draw with PersonModel.material(); a material given here
##                                 is used only if it is already on the person shader.
##   animate(speed, delta)         every frame: speed in tiles/s actually moved
##   play_action(action, seconds)  &"swing" &"heavy" &"dodge" &"work" &"hurt" &"eat" &"carried" &"downed"
##                                 also &"work_break" &"work_dig" &"work_fell" &"work_cut" &"gather";
##                                 &"" clears. seconds <= 0 uses the natural length, and
##                                 &"carried"/&"downed" hold until replaced. A swing is phased by
##                                 the held tool's windup/active/recovery: pass their sum.
##   set_held(item)                the held tool in the right hand (&"" = bare hands)
##   set_look(spec)                see PersonLook: build, hat, coat, hair, shirt, trouser, boot, salvage...
## Read-only helpers: busy(), action_progress(), hand_position(), tool_tip().
##
## Cost (a village is dozens of these): `pose_hz` > 0 poses the skeleton on a
## stepped clock at that rate instead of every frame, staggered per person so a
## crowd never poses on the same frame, and skips the pose while the figure is
## hidden, off camera, or frozen and already posed. Timers, gait and actions
## still advance every call, so busy() and action_progress() stay exact. The
## player keeps 0 (every frame: a fight must read on the frame it happens);
## villagers use CROWD_HZ. The shadow twin shows only while the sun casts.

var look: Dictionary = PersonLook.normalize({})
var held: StringName = &""
var action: StringName = &""
## Seconds left in the current action (0 when idle or holding a held action).
var action_left := 0.0
var rig: SkinRig

const PERSON_SHADER := preload("res://src/models/people/person.gdshader")

## Poses per second; 0 = every animate() call. See the header.
var pose_hz := 0.0
## In water over its head: the gait is a stroke and not a walk (Swim). Whoever
## places the figure says so — the model knows nothing about the world.
var swimming := false
## Skeleton poses applied so far (tests and budgets count them).
var poses_applied := 0
const CROWD_HZ := 12.0
## The key light of the world this figure stands in (SkyLight.sun), set by
## whoever places it (35_folk for villagers and the player). Null: the shadow
## twin always shows.
var sun: DirectionalLight3D

var _dims: Dictionary = PersonBody.dims(&"man")
var _step_left := -1.0
## How many figures have taken their first stepped pose (the stagger's counter),
## and the step between one and the next: the golden ratio, so each new person
## lands in the widest gap left in the period and a crowd of any size is spread.
## Counting in equal steps instead put twenty of them on one frame, because a
## period of a twelfth of a second holds sixty-odd counts inside a single frame.
static var _staggered := 0
const STAGGER_STEP := 0.6180339887498949
var _posed_frozen := false
var _sun_check := 0.0
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
## Down in the heather (Body.crouched; the disposition system writes it): knees
## bent, hips dropped, the back low and the head up, so the silhouette at
## 640x360 is plainly half a body shorter and still reads as a person moving.
var crouched := false
var _crouch := 0.0
## How far the hips drop, as a share of the leg, and how fast it gets there.
const CROUCH_DROP := 0.42
const CROUCH_RATE := 9.0
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
	var rebuild_bones: bool = rig != null and (next.build != look.build or next.gaunt != look.gaunt)
	look = next
	_dims = PersonBody.dims(look.build, look.gaunt)
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
		# Ignored, so a system with a newer verb never breaks a figure (see PersonAnim.ACTIONS).
		return
	action = a
	_action_t = 0.0
	_action_len = seconds if seconds > 0.0 else PersonAnim.default_seconds(a, held)
	if PersonAnim.HELD.has(a) and seconds <= 0.0:
		_action_len = 0.0
	action_left = _action_len
	_frozen = -1.0
	_posed_frozen = false
	# Swings and dodges must read on the first frame: no blend-in to wait for.
	if a == &"swing" or a == &"heavy" or a == &"dodge" or a == &"hurt":
		_weight = 1.0


## Let an action held by `pose_at` run on from where it was held: a heavy blow's
## drawn-back tool let go into the strike (40_fight).
func unfreeze() -> void:
	_frozen = -1.0
	_posed_frozen = false


## Freeze an action at seconds `t` into it (gallery, shots, tests). Replaces any action.
func pose_at(a: StringName, t: float, seconds: float = 0.0) -> void:
	play_action(a, seconds)
	_action_t = t
	_frozen = t
	_weight = 1.0
	_posed_frozen = false
	_step_left = 0.0
	animate(0.0, 0.0)


func busy() -> bool:
	return action != &""


## How tall this figure is built, in world units: what a roster row calls
## `height` for everything that has one (the water reads it to know where to cut).
func stature() -> float:
	return float(_dims.get(&"hip_y", 0.7)) + float(_dims.get(&"torso", 0.45)) + float(_dims.get(&"head", 0.35))


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
	if swimming:
		# A stroke keeps its own time: a body going nowhere in deep water is
		# treading it, not standing in it.
		var share := lerpf(PersonAnim.TREAD_SHARE, 1.0, clampf(_speed / 1.4, 0.0, 1.0))
		_phase = fposmod(_phase + delta * share / PersonAnim.STROKE_SECONDS, 1.0)
	elif _speed > 0.05:
		_phase = fposmod(_phase + delta * _speed / PersonAnim.cycle_length(_speed, leg), 1.0)
	_shadow_follows_sun(delta)
	# The action's clock runs on every call; only the pose waits for its step.
	var ended := &""
	var ended_len := 0.0
	if action != &"":
		if _frozen < 0.0:
			_action_t += delta
		if _action_len > 0.0 and _action_t >= _action_len and _frozen < 0.0:
			ended = action
			ended_len = _action_len
			_end_action()
		else:
			action_left = maxf(0.0, _action_len - _action_t)
			_weight = minf(1.0, _weight + delta * 18.0) if delta > 0.0 else _weight
	if action == &"" and ended == &"" and _weight > 0.0:
		_weight = maxf(0.0, _weight - delta * 7.0)
	var want := 0.0 if is_nan(gaze) or _weight > 0.0 else gaze
	_gaze_now = lerpf(_gaze_now, want, 1.0 - exp(-5.0 * delta)) if delta > 0.0 else want
	if not _pose_due(delta):
		if ended != &"":
			# The last frame of an action that ended between steps is still what
			# the body blends out of.
			_last = _resolved(ended, ended_len, ended_len)
		return
	var klass := HeldTools.klass(held)
	var pose := PersonAnim.stroke(_phase, _speed, _clock, _dims, klass) if swimming \
		else PersonAnim.locomotion(_phase, _speed, _clock, _dims, klass)
	if ended != &"":
		_last = _resolved(ended, ended_len, ended_len)
	elif action != &"":
		_last = _resolved(action, _action_t, _action_len)
	if _last != null and _weight > 0.0:
		# A copy: _last may be a cached pose other people are wearing too.
		var act := _last.copy()
		if PersonAnim.UPPER_ONLY.has(action) and _speed > 0.3:
			var move := smoothstep(0.3, 1.5, _speed)
			for b: StringName in PersonAnim.LOWER:
				act.rot[b] = act.r(b).lerp(pose.r(b), move)
				act.off[b] = act.o(b).lerp(pose.o(b), move)
		pose = PersonAnim.mix(pose, act, _smooth(_weight))
	_crouch = move_toward(_crouch, 1.0 if crouched else 0.0, delta * CROUCH_RATE) if delta > 0.0 else (1.0 if crouched else 0.0)
	if _crouch > 0.001:
		_crouch_pose(pose)
	if absf(_gaze_now) > 0.002 and _weight <= 0.0:
		# A watched head overrides the idle glance; the chest turns a little with it.
		var h := pose.r(&"head")
		pose.rot[&"head"] = Vector3(h.x, lerpf(h.y, _gaze_now * 0.75, minf(1.0, absf(_gaze_now) * 3.0)), h.z)
		var s := pose.r(&"spine")
		pose.rot[&"spine"] = Vector3(s.x, s.y + _gaze_now * 0.25, s.z)
	_apply(pose)
	_posed_frozen = _frozen >= 0.0


## Fold the stance down over whatever the body is already doing: thighs forward,
## shins back under them, the hips down and back, the spine over the knees and
## the head brought up to look out of it. It is an offset, not a pose of its
## own, so a crouching body still walks, swings and works.
##
## It has to READ at 640x360 from a camera 45 degrees up (docs/LOOK.md), and
## that is the whole difficulty: dropping a body and pitching its back forward
## lays the coat flat across the screen and the figure becomes one pale
## horizontal lump with a line through it (wave A2, art finding 8). What reads
## instead is ASYMMETRY and a gap -- one knee further forward than the other,
## the knees apart, the hips carried back behind them, the head clear of the
## back and turned a little off the line of travel, and the arms folded in so
## the torso is not one unbroken field. A person down in the heather, not a
## person who has been squashed.
func _crouch_pose(p: PersonAnim.Pose) -> void:
	var k := _crouch
	var leg: float = _dims.thigh + _dims.shin
	var bend := func(b: StringName, d: Vector3) -> void:
		p.rot[b] = p.r(b) + d * k
	# The lead knee (left) comes further up and further forward than the other.
	bend.call(&"thigh_l", Vector3(0.22, 0, 1.05))
	bend.call(&"thigh_r", Vector3(-0.30, 0, 0.72))
	bend.call(&"shin_l", Vector3(0, 0, -1.78))
	bend.call(&"shin_r", Vector3(0, 0, -1.42))
	bend.call(&"foot_l", Vector3(0, 0, 0.70))
	bend.call(&"foot_r", Vector3(0, 0, 0.55))
	# Less pitch than the drop wants: pitched right over, the back is the whole
	# silhouette and the head disappears into it.
	bend.call(&"spine", Vector3(0, 0.16, -0.30))
	bend.call(&"head", Vector3(0, -0.24, 0.42))
	# Elbows in and forearms up: a dark band between the head and the back.
	bend.call(&"arm_l", Vector3(0.16, 0, 0.62))
	bend.call(&"arm_r", Vector3(-0.16, 0, 0.44))
	# Only the free hand folds, and only when it IS free: the tool hand keeps
	# whatever grip the action put it in, and a haft that takes both hands keeps
	# both, so a crouched swing is still the same swing.
	if not HeldTools.two_handed(held):
		bend.call(&"fore_l", Vector3(0, 0, 0.75))
	p.off[&"hips"] = p.o(&"hips") + Vector3(-0.17, -leg * CROUCH_DROP, 0.0) * k
	p.off[&"hem"] = p.o(&"hem") + Vector3(-0.05, -leg * CROUCH_DROP * 0.4, 0) * k


## Whether this call should pose the skeleton (see the header). Always on a
## zero delta (a posed frame for a shot, a test or a rebuild).
func _pose_due(delta: float) -> bool:
	if pose_hz <= 0.0 or delta <= 0.0:
		return true
	if _step_left < 0.0:
		# The stagger: each person's first step lands at its own point in the period.
		# Counted here rather than taken from the instance id, because an id carries
		# everything the process allocated before this body: one package's tests
		# running first moved the whole crowd onto the same beat, and the test that
		# watches for exactly that went red for a reason that had nothing to do with
		# people. A counter spreads them the same way in every run.
		_step_left = fposmod(float(_staggered) * STAGGER_STEP, 1.0) / pose_hz
		_staggered += 1
	_step_left -= delta
	if _step_left > 0.0:
		return false
	_step_left = fmod(_step_left, 1.0 / pose_hz) + 1.0 / pose_hz
	if _posed_frozen:
		return false
	if is_inside_tree():
		if not is_visible_in_tree():
			return false
		var cam := get_viewport().get_camera_3d()
		if cam != null and not cam.is_position_in_frustum(global_position + Vector3(0, 0.7, 0)) and not cam.is_position_in_frustum(global_position):
			return false
	return true


## The shadow twin draws only while the sun casts shadows: at night, in heavy
## overcast, and indoors it is a skinned mesh drawn into a shadow map for nothing.
## Whoever stands the figure in a world hands it that world's sun (`sun`); with
## none the twin always shows.
func _shadow_follows_sun(delta: float) -> void:
	if rig == null or rig.shadow == null:
		return
	_sun_check -= delta
	if _sun_check > 0.0:
		return
	_sun_check = 0.25
	var s: DirectionalLight3D = sun if is_instance_valid(sun) else null
	# Nothing swimming lays a shadow on the water it is in: the twin under a body
	# in the sea is what gave away that the figure was floating above the sheet
	# rather than through it.
	rig.shadow.visible = not swimming and (s == null or (s.visible and s.shadow_enabled))


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
	var key := "%s|%d|%s|%s|%d|%d" % [look.build, look.gaunt, held, a, roundi(length * 1000.0), frame]
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
	# A released freeze moves again on the next step.
	_posed_frozen = false


static func _smooth(w: float) -> float:
	return w * w * (3.0 - 2.0 * w)


func _apply(p: PersonAnim.Pose) -> void:
	_applied = p
	poses_applied += 1
	for i in rig.names.size():
		var n := rig.names[i]
		rig.pose(i, p.r(n), p.o(n))
	var food := rig.find(&"food")
	rig.skeleton.set_bone_pose_scale(food, Vector3.ONE * maxf(0.001, p.food))


func _make_rig() -> void:
	if rig != null and rig.skeleton != null:
		remove_child(rig.skeleton)
		rig.skeleton.queue_free()
	rig = PersonBody.make_rig(look.build, look.gaunt)
	_dims = PersonBody.dims(look.build, look.gaunt)
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
		# And drawn through the land where the land hides it (render/behind.gdshader).
		var behind := ShaderMaterial.new()
		behind.shader = preload("res://src/render/behind.gdshader")
		behind.render_priority = 12
		rim.next_pass = behind
	return _person_mat


## Triangles in the body (and clothes, hair, salvage), excluding the held tool.
func body_triangles() -> int:
	return rig.triangle_count([&"body", &"salvage", &"salvage_glow", &"gear", &"gear_glow", &"food"])


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
	out.append_array(_items("people builds", builds, mat, 5, 0.56, FACE_CAMERA))

	var crowd: Array = []
	for spec: Dictionary in PersonLook.crowd(11, 10):
		crowd.append([spec, &"", ""])
	out.append_array(_items("people looks", crowd, mat, 5, 0.56, FACE_CAMERA))

	var hats: Array = []
	for h: StringName in PersonLook.HATS:
		hats.append([{"hat": h, "hat_col": "earth:3" if hats.size() % 2 else "slate:2", "coat": PersonLook.COATS[hats.size() % PersonLook.COATS.size()]}, &"", String(h)])
	out.append_array(_items("people hats coats", hats, mat, 4, 0.62, FACE_CAMERA))

	var hair: Array = []
	var k := 0
	for st: StringName in PersonLook.HAIR_STYLES:
		hair.append([{"hair_style": st, "hair": PersonLook.HAIR_PRESETS[k % PersonLook.HAIR_PRESETS.size()], "beard": PersonLook.BEARDS[k % PersonLook.BEARDS.size()], "skin": PersonLook.SKIN_WINDOWS[k % 4], "skin_v": 1 + k % 3}, &"", String(st)])
		k += 1
	out.append_array(_items("people hair beards", hair, mat, 4, 0.62, FACE_RIGHT))

	var kit: Array = []
	k = 0
	for part: StringName in PersonLook.SALVAGE:
		var spec := PersonLook.random(40 + k, k)
		spec.salvage = [part]
		spec.side = 1
		kit.append([spec, &"", String(part)])
		k += 1
	out.append_array(_items("people salvage", kit, mat, 4, 0.72, FACE_CAMERA))

	# The last people of each land, dressed by its hazards: four to a land.
	for def: BiomeDef in BiomeRegistry.all():
		var folk: Array = []
		var n := 0
		for spec: Dictionary in PersonLook.villagers(500 + hash(def.id) % 1000, 4, def.hazards):
			folk.append([spec, &"", String(spec.trade) if n == 0 else ""])
			n += 1
		out.append_array(_items("people land %s" % def.id, folk, mat, 4, 0.6, FACE_CAMERA))

	# Each piece of mended gear, seen from the front and from behind.
	var gear_rows: Array = []
	k = 0
	for g: StringName in PersonLook.GEAR:
		var spec := PersonLook.random(60 + k, k)
		spec.gear = [g]
		spec.salvage = []
		spec.coat = [&"none", &"jerkin"][k % 2]
		spec.hat = &"none" if g == &"goggles" else spec.hat
		gear_rows.append([spec, &"", String(g)])
		k += 1
	for start in range(0, gear_rows.size(), 2):
		var g2 := Node3D.new()
		var labels: PackedStringArray = []
		for i in range(start, mini(start + 2, gear_rows.size())):
			var row: Array = gear_rows[i]
			for turn in 2:
				var pm := make(row[0], &"", mat)
				pm.rotation.y = FACE_CAMERA + (PI if turn == 1 else 0.0)
				_place(g2, pm, (i - start) * 2 + turn, 2, 0.7, row[2])
			labels.append(String(row[2]))
		out.append({"name": "people gear: " + " ".join(labels), "node": g2})

	var trades: Array = []
	for tr: StringName in PersonLook.TRADES:
		trades.append([PersonLook.dress(PersonLook.random(77, trades.size()), {}, tr, 77 + trades.size()), &"", String(tr)])
	out.append_array(_items("people trades", trades, mat, 3, 0.62, FACE_CAMERA))

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
	# One-handed blows share a cell in pairs; a two-handed swing reaches a whole cell.
	var swings: Array = []
	var heavy: Array = []
	for id: StringName in [&"", &"knife", &"billhook", &"axe_hand", &"stun_hand", &"axe_felling", &"pick", &"stave", &"boathook"]:
		var ms := HeldTools.swing_ms(id)
		var row := [PersonLook.random(120, swings.size() + heavy.size()), id, String(HeldTools.klass(id)) + (" " + String(id) if id != &"" else ""), &"swing", (ms[0] + ms[1] * 0.45) / 1000.0]
		if HeldTools.two_handed(id):
			heavy.append(row)
		else:
			swings.append(row)
	out.append_array(_items("person swings", swings, mat, 2, 1.5, FACE_RIGHT, 2))
	out.append_array(_items("person swings heavy", heavy, mat, 1, 1.0, FACE_RIGHT, 1))

	# Every action at its most expressive frame. The ones that throw the body across
	# the ground (the roll, the fall, being carried) take a cell each.
	var big: Array = [
		[PersonLook.random(90, 0), &"knife", "dodge", &"dodge", 0.17],
		[PersonLook.random(90, 3), &"knife", "downed", &"downed", 2.0],
		[PersonLook.random(90, 4), &"", "carried", &"carried", 0.6],
		[PersonLook.random(90, 9), &"", "gather", &"gather", 0.45],
	]
	out.append_array(_items("person actions big", big, mat, 1, 1.0, FACE_RIGHT, 1))
	var acts: Array = [
		[PersonLook.random(90, 1), &"knife", "hurt", &"hurt", 0.07], [PersonLook.random(90, 2), &"", "eat", &"eat", 0.4],
		[PersonLook.random(90, 5), &"pick", "break", &"work_break", 0.52], [PersonLook.random(90, 6), &"mattock", "dig", &"work_dig", 0.7],
		[PersonLook.random(90, 7), &"axe_felling", "fell", &"work_fell", 0.66], [PersonLook.random(90, 8), &"billhook", "cut", &"work_cut", 0.1],
	]
	out.append_array(_items("person actions", acts, mat, 2, 1.5, FACE_RIGHT, 2))

	var made: Array = []
	for id: StringName in HeldTools.MADE:
		made.append([PersonLook.random(200, made.size()), id, String(id)])
	out.append_array(_items("person tools made", made, mat, 3, 0.8, FACE_CAMERA))
	var found: Array = []
	for id: StringName in HeldTools.FOUND:
		found.append([PersonLook.random(300, found.size()), id, String(id)])
	out.append_array(_items("person tools found", found, mat, 3, 0.8, FACE_CAMERA))
	return out


## Gallery items of people, `per` to an item (default two rows of `cols`) so every
## item fits one gallery square. A row is [spec, held, label] or
## [spec, held, label, action, seconds in].
static func _items(title: String, rows: Array, mat: Material, cols: int, spacing: float, facing: float, per: int = 0) -> Array:
	var out: Array = []
	if per <= 0:
		per = cols * 2
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
			_place(g, pm, i - start, cols, spacing, row[2], ceili(float(mini(per, rows.size() - start)) / cols))
			if String(row[2]) != "":
				labels.append(String(row[2]))
		var name := title if rows.size() <= per else "%s %s" % [title, "abcdefghijklmnop"[part]]
		if not labels.is_empty():
			name += ": " + " ".join(labels)
		out.append({"name": name, "node": g})
		part += 1
	return out


## Lay subject i out along screen-right (world +X-Z) in rows that step toward the camera.
static func _place(g: Node3D, n: Node3D, i: int, cols: int, spacing: float, label: String, rows: int = 2) -> void:
	var across := Vector3(1, 0, -1).normalized()
	var down := Vector3(1, 0, 1).normalized()
	var col := i % cols
	var row := i / cols
	n.position = across * (col - (cols - 1) * 0.5) * spacing + down * (row - (rows - 1) * 0.5) * maxf(0.85, spacing)
	g.add_child(n)
	n.set_meta(&"label", label)
