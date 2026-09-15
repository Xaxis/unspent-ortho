class_name AnimalModel
extends FigureModel
## Shared body for animals: one skinned mesh (SkinRig), a gait solver, poses that
## blend, and seed variation. Machines come off the same line; animals do not:
## call vary(seed) and the coat, size and markings change.
##
## Poses (FigureModel.set_pose): &"stand" &"walk" &"alert" &"flee" &"windup"
## &"strike" &"hurt" &"dead", plus &"idle" (= stand), &"attack" (= strike) and,
## for birds, &"fly". Unknown poses are ignored.
##
## Subclasses implement _build_rig() (bones and parts into `rig`, using `rng` for
## variation) and _pose(pose, t, speed) -> {bone: euler, "@bone": offset}.
## Limb conventions follow PersonAnim: +Z swings a hanging limb forward.

const POSES: Array[StringName] = [&"stand", &"walk", &"alert", &"flee", &"windup", &"strike", &"hurt", &"dead", &"fly"]

var rig: SkinRig
var seed_value := 0
## Random source for the current build: everything a subclass varies draws from it.
var rng: RandomNumberGenerator
## Seconds in the current pose, and total.
var pose_time := 0.0
var clock := 0.0
var gait_phase := 0.0
## Last applied pose, for blending into the next one.
var _from: Dictionary = {}
var _blend := 1.0
var _speed := 0.0


func build() -> void:
	_rebuild()


## A different animal of the same kind: coat, size, markings.
func vary(new_seed: int) -> void:
	seed_value = new_seed
	_rebuild()


func _rebuild() -> void:
	rng = Rng.make(seed_value, hash(String(kind)))
	if rig != null and rig.skeleton != null:
		remove_child(rig.skeleton)
		rig.skeleton.queue_free()
	rig = SkinRig.new()
	_build_rig()
	rig.attach(self, material if material != null else FigureModel._default_material())
	clock = rng.randf() * 10.0
	_apply(_pose(&"stand", 0.0, 0.0), 1.0)


func set_pose(p: StringName) -> void:
	match p:
		&"idle": p = &"stand"
		&"attack": p = &"strike"
	if not POSES.has(p) or p == pose:
		return
	_from = _current()
	_blend = 0.0
	pose = p
	pose_time = 0.0


## delta seconds, speed tiles/s actually moved.
func animate(delta: float, speed: float) -> void:
	if rig == null:
		return
	clock += delta
	pose_time += delta
	_speed = speed
	if speed > 0.01:
		gait_phase = fposmod(gait_phase + delta * speed / maxf(0.05, _stride(speed)), 1.0)
	var rate := 14.0 if pose == &"strike" or pose == &"hurt" else 7.0
	_blend = minf(1.0, _blend + delta * rate)
	var target := _pose(pose, pose_time, speed)
	_apply(target, _blend)


func _current() -> Dictionary:
	var d := {}
	for i in rig.names.size():
		d[rig.names[i]] = rig.skeleton.get_bone_pose_rotation(i).get_euler()
		d["@" + String(rig.names[i])] = rig.skeleton.get_bone_pose_position(i) - rig.rest[i]
	return d


func _apply(target: Dictionary, w: float) -> void:
	for i in rig.names.size():
		var n := rig.names[i]
		var r: Vector3 = target.get(n, Vector3.ZERO)
		var o: Vector3 = target.get("@" + String(n), Vector3.ZERO)
		if w < 1.0 and not _from.is_empty():
			var e := smoothstep(0.0, 1.0, w)
			r = (_from.get(n, Vector3.ZERO) as Vector3).lerp(r, e)
			o = (_from.get("@" + String(n), Vector3.ZERO) as Vector3).lerp(o, e)
		rig.pose(i, r, o)


## Override.
func _build_rig() -> void:
	var b := rig.bone(&"root", -1, Vector3.ZERO)
	trunk(rig.kit(b), [[-0.2, 0.15, 0.12, 0.3], [0.2, 0.15, 0.12, 0.3]], 6, Palette.EARTH[2], seed_value)


## Override.
func _pose(_p: StringName, _t: float, _speed: float) -> Dictionary:
	return {}


# ---------------------------------------------------------------- helpers

## A two-segment leg: a tapered upper from the body, a thinner lower, and a paw
## or hoof that sits on the ground. Returns the upper bone.
func leg(n: String, parent: int, at: Vector3, upper: float, lower: float, thick: float, col: Color, foot: Color, foot_len: float = 0.06) -> int:
	var u := rig.bone(StringName(n + "_u"), parent, at)
	var l := rig.bone(StringName(n + "_l"), u, Vector3(0, -upper, 0))
	var sd := seed_value * 7 + hash(n)
	Sculpt.loft(rig.kit(u), [
		[thick * 0.35, thick * 0.4, thick * 0.4, 0.0, 0.0],
		[0.0, thick * 0.66, thick * 0.56, 0.0, 0.0],
		[-upper - 0.01, thick * 0.44, thick * 0.42, 0.0, 0.0],
	], 5, col, false, false, 0.0, 0.08, sd)
	var lk := rig.kit(l)
	Sculpt.loft(lk, [[0.01, thick * 0.44, thick * 0.42, 0.0, 0.0], [-lower + thick * 0.3, thick * 0.3, thick * 0.3, 0.004, 0.0]], 5, col, true, false, 0.0, 0.08, sd + 1)
	Sculpt.loft(lk, [
		[-lower + thick * 0.35, thick * 0.34, thick * 0.34, foot_len * 0.1, 0.0],
		[-lower, thick * 0.34 + foot_len * 0.45, thick * 0.46, foot_len * 0.3, 0.0],
	], 5, foot, false, true, 0.0, 0.06, sd + 2)
	return u


## A lofted trunk along +X: rings of [x, half height, half width, centre y].
## The body of every animal is one of these.
static func trunk(k: MeshKit, rings: Array, n: int, cols: Variant, seed_value: int, wob: float = 0.06, caps: bool = true) -> void:
	var r: Array = []
	for ring: Array in rings:
		r.append([ring[0], ring[1], ring[2], ring[3], ring[4] if ring.size() > 4 else 0.0])
	k.push(Transform3D(Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)), Vector3.ZERO))
	Sculpt.loft(k, r, n, cols, caps, caps, PI / n, wob, seed_value)
	k.pop()


## A flat triangle seen from both sides: ears, fins, tufts.
static func flap(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, col: Color, back: Color) -> void:
	k.tri(a, b, c, col)
	k.tri(a, c, b, back)


## Four-legged gait. `phase` 0..1; `kind` &"walk" (four-beat), &"trot", &"gallop".
## Sets legs fl fr bl br (upper swing, lower bend) into `d`; returns body bob.
static func quad_gait(d: Dictionary, phase: float, kind: StringName, swing: float, bend: float) -> float:
	var offs := {"fl": 0.25, "fr": 0.75, "bl": 0.0, "br": 0.5}
	match kind:
		&"trot":
			offs = {"fl": 0.0, "fr": 0.5, "bl": 0.5, "br": 0.0}
		&"gallop":
			offs = {"fl": 0.0, "fr": 0.08, "bl": 0.5, "br": 0.58}
	for k: String in offs:
		var p := TAU * (phase + float(offs[k]))
		var lift := maxf(0.0, -sin(p))
		d[StringName(k + "_u")] = Vector3(0, 0, swing * cos(p))
		# Front knees fold the hoof back and up in the swing; hind hocks tuck it under.
		if k.begins_with("f"):
			d[StringName(k + "_l")] = Vector3(0, 0, -bend * lift)
		else:
			d[StringName(k + "_l")] = Vector3(0, 0, bend * 0.6 * lift)
	if kind == &"gallop":
		return 0.5 + 0.5 * sin(TAU * phase)
	return 0.5 + 0.5 * cos(2.0 * TAU * phase)


## Override: ground covered by one gait cycle at a speed.
func _stride(speed: float) -> float:
	return 0.5 + speed * 0.12


## Pick one of a list with the build's rng.
func pick(list: Array) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


## A size multiplier in [1 - amount, 1 + amount].
func size_jitter(amount: float) -> float:
	return 1.0 + (rng.randf() * 2.0 - 1.0) * amount



## The gallery row for an animal kind: several seeds, every pose.
static func gallery_for(kind_id: StringName, poses: Array) -> Array:
	var mat := FigureModel._default_material()
	var g := Node3D.new()
	var across := Vector3(1, 0, -1).normalized()
	var down := Vector3(1, 0, 1).normalized()
	for i in poses.size():
		var spec: Array = poses[i]
		var m := FigureModel.create(kind_id, mat) as AnimalModel
		if m == null:
			continue
		m.vary(i * 7 + 1)
		m.rotation.y = PI * 0.25 if i % 2 == 0 else -PI * 0.25
		m.set_pose(spec[0])
		for f in 12:
			m.animate(float(spec[1]) / 12.0, float(spec[2]))
		m.position = across * ((i % 4) - 1.5) * float(spec[3]) + down * (int(i / 4) - 0.5) * float(spec[3]) * 1.2
		g.add_child(m)
	return [{"name": String(kind_id), "node": g}]
