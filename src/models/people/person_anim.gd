class_name PersonAnim
## Procedural animation for people, as pure functions from time to a Pose.
## No nodes: tests sample poses directly, and PersonModel applies them to its rig.
##
## Joint conventions (the person faces +X, their right is +Z):
##   limb  rot.z > 0 swings a hanging limb forward (PI/2 points it ahead, PI up)
##         rot.x abducts a hanging limb (right arm: negative is outward)
##         rot.y sweeps a raised limb across (positive toward the left)
##   shin  rot.z < 0 bends the knee;  fore rot.z > 0 bends the elbow
##   spine rot.z < 0 leans forward;   rot.y > 0 brings the right shoulder forward
##   head  rot.y > 0 looks left
## A key may also carry `aim` (tool direction in root space) and `ik_l` / `ik_r`
## (hand targets in root space); resolve() turns those into joint angles.

const GAIT_WALK := 3.4
const GAIT_RUN := 5.4


class Pose:
	extends RefCounted
	var rot: Dictionary = {} # StringName -> Vector3 euler
	var off: Dictionary = {} # StringName -> Vector3 offset from rest
	var aim := Vector3.ZERO # tool +Y direction in root space; zero = use rot
	var edge := Vector3(0, -1, 0) # which way the tool's +X (the edge) should face
	var ik_l := Vector3.INF
	var ik_r := Vector3.INF
	var pole_l := Vector3(-0.3, -1.0, -0.7)
	var pole_r := Vector3(-0.3, -1.0, 0.7)
	var off_grip := false # left hand to the tool's off grip
	var food := 0.0 # scale of the food in the left hand

	func r(b: StringName) -> Vector3:
		return rot.get(b, Vector3.ZERO)

	func o(b: StringName) -> Vector3:
		return off.get(b, Vector3.ZERO)

	func copy() -> Pose:
		var p := Pose.new()
		p.rot = rot.duplicate()
		p.off = off.duplicate()
		p.aim = aim
		p.edge = edge
		p.ik_l = ik_l
		p.ik_r = ik_r
		p.pole_l = pole_l
		p.pole_r = pole_r
		p.off_grip = off_grip
		p.food = food
		return p

	## Values from `d` override: keys "bone" -> euler, "@bone" -> offset, and the specials.
	func with(d: Dictionary) -> Pose:
		var p := copy()
		for k: String in d:
			match k:
				"aim": p.aim = d[k]
				"edge": p.edge = d[k]
				"ik_l": p.ik_l = d[k]
				"ik_r": p.ik_r = d[k]
				"pole_l": p.pole_l = d[k]
				"pole_r": p.pole_r = d[k]
				"off_grip": p.off_grip = d[k]
				"food": p.food = d[k]
				_:
					if k.begins_with("@"):
						p.off[StringName(k.substr(1))] = d[k]
					else:
						p.rot[StringName(k)] = d[k]
		return p


## Blend two RESOLVED poses (joint angles only).
static func mix(a: Pose, b: Pose, t: float) -> Pose:
	if t <= 0.0:
		return a
	if t >= 1.0:
		return b
	var p := Pose.new()
	for k: StringName in a.rot:
		p.rot[k] = (a.rot[k] as Vector3).lerp(b.r(k), t)
	for k: StringName in b.rot:
		if not p.rot.has(k):
			p.rot[k] = Vector3.ZERO.lerp(b.rot[k], t)
	for k: StringName in a.off:
		p.off[k] = (a.off[k] as Vector3).lerp(b.o(k), t)
	for k: StringName in b.off:
		if not p.off.has(k):
			p.off[k] = Vector3.ZERO.lerp(b.off[k], t)
	p.food = lerpf(a.food, b.food, t)
	return p


## Key-framed blend of UNRESOLVED poses (aim and ik lerp too).
static func mix_keys(a: Pose, b: Pose, t: float) -> Pose:
	var p := mix(a, b, t)
	if a.aim != Vector3.ZERO and b.aim != Vector3.ZERO:
		p.aim = a.aim.normalized().slerp(b.aim.normalized(), t) if absf(a.aim.normalized().dot(b.aim.normalized())) < 0.9999 else b.aim
	else:
		p.aim = b.aim if t >= 0.5 else a.aim
	p.edge = a.edge.lerp(b.edge, t)
	p.off_grip = b.off_grip if t >= 0.5 else a.off_grip
	if a.ik_l != Vector3.INF and b.ik_l != Vector3.INF:
		p.ik_l = a.ik_l.lerp(b.ik_l, t)
	else:
		p.ik_l = b.ik_l if t >= 0.5 else a.ik_l
	if a.ik_r != Vector3.INF and b.ik_r != Vector3.INF:
		p.ik_r = a.ik_r.lerp(b.ik_r, t)
	else:
		p.ik_r = b.ik_r if t >= 0.5 else a.ik_r
	p.pole_l = a.pole_l.lerp(b.pole_l, t)
	p.pole_r = a.pole_r.lerp(b.pole_r, t)
	return p


# ---------------------------------------------------------------- kinematics

## Global (model-space) transform of bone b under pose p.
static func fk(rig: SkinRig, p: Pose, b: int) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var chain: Array[int] = []
	var i := b
	while i >= 0:
		chain.push_front(i)
		i = rig.parents[i]
	for j: int in chain:
		var n := rig.names[j]
		xf = xf * Transform3D(Basis(Quaternion.from_euler(p.r(n))), rig.rest[j] + p.o(n))
	return xf


## Turn aim and ik into joint angles. Returns a new pose with only rot/off/food.
static func resolve(rig: SkinRig, p: Pose, tool_id: StringName) -> Pose:
	var q := p.copy()
	var root_b := fk(rig, q, rig.find(&"root")).basis
	if q.ik_r != Vector3.INF:
		_ik(rig, q, &"r", root_b * q.ik_r + fk(rig, q, rig.find(&"root")).origin, root_b * q.pole_r)
	var two := q.off_grip and HeldTools.two_handed(tool_id)
	var reach := rig.rest[rig.find(&"fore_l")].length() + rig.rest[rig.find(&"hand_l")].length() + 0.045
	var ai := rig.find(&"arm_l")
	_aim(rig, q, root_b)
	if two:
		# When the off hand cannot reach the haft, bring the tool hand across and in,
		# as a person does: a few greedy nudges of the right arm, re-aiming each time.
		var nudges: Array[Vector3] = [Vector3(0.1, 0, 0), Vector3(-0.1, 0, 0), Vector3(0, 0.1, 0), Vector3(0, -0.1, 0), Vector3(0, 0, 0.1)]
		for i in 12:
			var gap := _off_gap(rig, q, tool_id, ai, reach)
			if gap <= 0.0:
				break
			var best := Vector3.ZERO
			var best_gap := gap
			var ar := q.r(&"arm_r")
			var fr := q.r(&"fore_r")
			for n: Vector3 in nudges:
				q.rot[&"arm_r"] = ar + Vector3(n.x, n.y, 0)
				q.rot[&"fore_r"] = fr + Vector3(0, 0, n.z)
				_aim(rig, q, root_b)
				var g := _off_gap(rig, q, tool_id, ai, reach)
				if g < best_gap:
					best_gap = g
					best = n
			q.rot[&"arm_r"] = ar + Vector3(best.x, best.y, 0)
			q.rot[&"fore_r"] = fr + Vector3(0, 0, best.z)
			_aim(rig, q, root_b)
			if best == Vector3.ZERO:
				break
	if two:
		_ik(rig, q, &"l", off_hand_target(rig, q, tool_id), root_b * q.pole_l)
	elif q.ik_l != Vector3.INF:
		_ik(rig, q, &"l", root_b * q.ik_l + fk(rig, q, rig.find(&"root")).origin, root_b * q.pole_l)
	q.aim = Vector3.ZERO
	q.ik_l = Vector3.INF
	q.ik_r = Vector3.INF
	q.off_grip = false
	return q


## How far past the off arm's reach its grip on the haft is (<= 0: reachable).
static func _off_gap(rig: SkinRig, q: Pose, tool_id: StringName, ai: int, reach: float) -> float:
	var shoulder := fk(rig, q, rig.parents[ai]) * rig.rest[ai]
	return off_hand_target(rig, q, tool_id).distance_to(shoulder) - reach * 0.985


## Point the tool along q.aim (root space) with its edge toward q.edge.
static func _aim(rig: SkinRig, q: Pose, root_b: Basis) -> void:
	if q.aim == Vector3.ZERO:
		return
	var hand := fk(rig, q, rig.find(&"hand_r"))
	var y := (root_b * q.aim).normalized()
	var hint := root_b * q.edge
	var x := hint - y * hint.dot(y)
	if x.length() < 0.05:
		x = root_b * Vector3(1, 0, 0)
		x = x - y * x.dot(y)
		if x.length() < 0.05:
			x = root_b * Vector3(0, 0, 1)
	x = x.normalized()
	q.rot[&"tool"] = (hand.basis.inverse() * Basis(x, y, x.cross(y))).get_euler()


## Where the off hand goes on a two-handed haft (model space): the preferred grip
## when the arm reaches it, else the nearest reachable point along the grip range.
static func off_hand_target(rig: SkinRig, q: Pose, tool_id: StringName) -> Vector3:
	var tool := fk(rig, q, rig.find(&"tool"))
	var ai := rig.find(&"arm_l")
	var shoulder := fk(rig, q, rig.parents[ai]) * rig.rest[ai]
	var reach := rig.rest[rig.find(&"fore_l")].length() + rig.rest[rig.find(&"hand_l")].length() + 0.045
	var pref := tool * Vector3(0, HeldTools.off_grip(tool_id), 0)
	if pref.distance_to(shoulder) <= reach * 0.96:
		return pref
	var span := HeldTools.off_range(tool_id)
	var a := tool * Vector3(0, span.x, 0)
	var ab := tool * Vector3(0, span.y, 0) - a
	var t := clampf((shoulder - a).dot(ab) / maxf(1e-6, ab.length_squared()), 0.0, 1.0)
	var near_pt := a + ab * t
	# Of the reachable stretch, keep as close to the preferred grip as the arm allows.
	for i in 8:
		var mid := near_pt.lerp(pref, 1.0 - (i + 1) / 8.0)
		if mid.distance_to(shoulder) <= reach * 0.96:
			return mid
	return near_pt


## Two-bone IK: put the hand's grip point on `target` (model space), elbow toward `pole`.
static func _ik(rig: SkinRig, q: Pose, side: StringName, target: Vector3, pole: Vector3) -> void:
	var arm := StringName("arm_" + side)
	var fore := StringName("fore_" + side)
	var hand := StringName("hand_" + side)
	var ai := rig.find(arm)
	var parent := fk(rig, q, rig.parents[ai])
	var s := parent * rig.rest[ai]
	var l1 := rig.rest[rig.find(fore)].length()
	var l2 := rig.rest[rig.find(hand)].length() + 0.045
	var to := target - s
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.002)
	var dir := to.normalized() if to.length() > 1e-4 else Vector3.DOWN
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 1e-3:
		perp = Vector3(-1, 0, 0) - dir * (-dir.x)
	perp = perp.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var a := acos(ca)
	var elbow := s + (dir * cos(a) + perp * sin(a)) * l1
	var ce := clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0)
	var bend := PI - acos(ce)
	var u := (elbow - s).normalized()
	var hand_pt := s + dir * d
	var f := (hand_pt - elbow).normalized()
	var x := f - u * f.dot(u)
	if x.length() < 1e-3:
		x = perp - u * perp.dot(u)
		x = -x
	x = x.normalized()
	var y := -u
	var z := x.cross(y)
	var want := Basis(x, y, z)
	q.rot[arm] = (parent.basis.inverse() * want).get_euler()
	q.rot[fore] = Vector3(0, 0, bend)
	q.rot[hand] = Vector3.ZERO


# ---------------------------------------------------------------- locomotion

## Stride length of one full gait cycle (two steps) at a speed, for a leg length.
static func cycle_length(speed: float, leg: float) -> float:
	return leg * (1.9 + 0.3 * speed)


## Standing, walking and running, blended by speed. `phase` is the gait cycle
## (0 = left heel strike), `t` the figure's clock in seconds (breath, glances).
static func locomotion(phase: float, speed: float, t: float, d: Dictionary, klass: StringName) -> Pose:
	var move := smoothstep(0.15, 1.2, speed)
	var run := smoothstep(GAIT_WALK + 0.4, GAIT_RUN - 0.2, speed)
	var stoop: float = d.get("stoop", 0.0)
	var p := Pose.new()

	# --- idle: breath (a posed settle, feet planted), a slow weight shift, a glance.
	var breath := sin(t * TAU / 3.4)
	var shift := sin(t * TAU / 7.3)
	var glance := sin(t * TAU / 5.1) * 0.5 + sin(t * TAU / 11.7) * 0.5
	var arms: float = d.get("arms", 0.08)
	var knees: float = d.get("knees", 0.0)
	var idle := {
		&"spine": Vector3(0, 0, -stoop - 0.02 + breath * 0.02),
		&"head": Vector3(0, glance * 0.28, stoop * 0.8 + breath * -0.015),
		&"arm_l": Vector3(arms + breath * 0.015, 0, 0.04 + stoop * 0.3),
		&"arm_r": Vector3(-arms - breath * 0.015, 0, 0.04 + stoop * 0.3),
		&"fore_l": Vector3(0, 0, 0.14 + knees * 0.5),
		&"fore_r": Vector3(0, 0, 0.14 + knees * 0.5),
		&"thigh_l": Vector3(0.05, 0, 0.03 + knees - shift * 0.02),
		&"thigh_r": Vector3(-0.05, 0, -0.03 + knees - shift * 0.02),
		&"shin_l": Vector3(0, 0, -0.04 - knees * 2.0 + maxf(0.0, shift) * -0.1),
		&"shin_r": Vector3(0, 0, -0.04 - knees * 2.0 + maxf(0.0, -shift) * -0.1),
		&"foot_l": Vector3(0, 0, knees),
		&"foot_r": Vector3(0, 0, knees),
		&"hips": Vector3(shift * 0.03, 0, 0),
		&"hem": Vector3(0, 0, 0),
		&"aerial": Vector3(breath * 0.02, 0, -0.12 + shift * 0.03),
		&"aerial_tip": Vector3(0, 0, -0.1 + breath * 0.03),
		&"tally": Vector3(0, 0, 0),
	}
	var idle_off := {
		&"hips": Vector3(0, -absf(shift) * 0.008 - knees * knees * 0.5, shift * 0.018),
		&"spine": Vector3(0, breath * 0.006, 0),
	}

	# --- walk and run, one cycle = two steps.
	var c := cos(TAU * phase)
	var s := sin(TAU * phase)
	var sr := sin(TAU * (phase + 0.5))
	var thigh_a := lerpf(0.52, 0.9, run)
	var fwd_bias := lerpf(0.0, 0.18, run)
	var knee_swing := lerpf(0.95, 1.75, run)
	var knee_stance := lerpf(0.12, 0.35, run)
	var bob := lerpf(0.035, 0.07, run)
	var arm_a := lerpf(0.5, 0.85, run)
	var elbow := lerpf(0.25, 1.45, run)
	var lean := lerpf(-0.07, -0.3, run) - stoop
	# Down (lowest) just after each contact; head lands a beat later.
	var drop := -bob * (0.5 + 0.5 * cos(2.0 * TAU * (phase - 0.08)))
	var head_drag := -bob * 0.4 * (0.5 + 0.5 * cos(2.0 * TAU * (phase - 0.17)))
	var knee_l := -(knee_stance * maxf(0.0, sin(2.0 * TAU * phase)) * 0.6 + knee_swing * pow(maxf(0.0, -s), 1.3))
	var knee_r := -(knee_stance * maxf(0.0, sin(2.0 * TAU * phase)) * 0.6 + knee_swing * pow(maxf(0.0, -sr), 1.3))
	var th_l := fwd_bias + thigh_a * c
	var th_r := fwd_bias - thigh_a * c
	var gait := {
		&"hips": Vector3(0.05 * s, -0.12 * c, 0),
		&"spine": Vector3(-0.04 * s, 0.26 * c, lean),
		&"head": Vector3(0.03 * s, -0.14 * c, -lean * 0.75 + 0.05 * cos(2.0 * TAU * (phase - 0.2))),
		&"thigh_l": Vector3(0.03, 0, th_l),
		&"thigh_r": Vector3(-0.03, 0, th_r),
		&"shin_l": Vector3(0, 0, knee_l),
		&"shin_r": Vector3(0, 0, knee_r),
		&"foot_l": Vector3(0, 0, -(th_l + knee_l) * 0.7 + 0.25 * maxf(0.0, c) * (1.0 - run) - 0.35 * maxf(0.0, -c) * maxf(0.0, s)),
		&"foot_r": Vector3(0, 0, -(th_r + knee_r) * 0.7 + 0.25 * maxf(0.0, -c) * (1.0 - run) - 0.35 * maxf(0.0, c) * maxf(0.0, sr)),
		&"arm_l": Vector3(0.1, 0, -arm_a * c + run * 0.2),
		&"arm_r": Vector3(-0.1, 0, arm_a * c + run * 0.2),
		&"fore_l": Vector3(0, 0, elbow + 0.3 * maxf(0.0, -c)),
		&"fore_r": Vector3(0, 0, elbow + 0.3 * maxf(0.0, c)),
		# Coat hems drag behind the body and swing a beat after the hips.
		&"hem": Vector3(0.07 * sin(TAU * phase - 0.9), 0.1 * c, -lerpf(0.12, 0.42, run) - 0.07 * sin(2.0 * TAU * (phase - 0.22))),
		&"aerial": Vector3(0.05 * s, 0, -0.3 - lerpf(0.1, 0.35, run) + 0.08 * cos(2.0 * TAU * (phase - 0.25))),
		&"aerial_tip": Vector3(0.08 * s, 0, -0.25 + 0.14 * cos(2.0 * TAU * (phase - 0.33))),
		&"tally": Vector3(0.3 * sin(TAU * phase - 1.2), 0, -0.2 * cos(2.0 * TAU * phase)),
	}
	var gait_off := {
		&"hips": Vector3(0, drop + run * 0.02 - move * 0.015, -0.022 * s * (1.0 - run)),
		&"head": Vector3(0, head_drag - drop * 0.3, 0),
	}
	for k: StringName in idle:
		p.rot[k] = (idle[k] as Vector3).lerp(gait.get(k, Vector3.ZERO), move)
	for k: StringName in gait:
		if not p.rot.has(k):
			p.rot[k] = Vector3.ZERO.lerp(gait[k], move)
	for k: StringName in idle_off:
		p.off[k] = (idle_off[k] as Vector3).lerp(gait_off.get(k, Vector3.ZERO), move)
	for k: StringName in gait_off:
		if not p.off.has(k):
			p.off[k] = Vector3.ZERO.lerp(gait_off[k], move)
	_carry(p, klass, move, run, c, t)
	return p


## How the held thing rides while walking: blades forward in the fist, heavy
## tools on the shoulder, poles upright like a staff.
static func _carry(p: Pose, klass: StringName, move: float, run: float, c: float, t: float) -> void:
	match klass:
		&"fist":
			pass
		&"blade", &"hook", &"axe", &"point":
			p.rot[&"tool"] = Vector3(0, 0, -1.25 + 0.2 * move)
		&"heavy", &"pick":
			var bob := 0.04 * c * move
			p.rot[&"arm_r"] = Vector3(-0.2, 0, 0.35 + bob + run * 0.2)
			p.rot[&"fore_r"] = Vector3(0, 0, 1.95)
			p.rot[&"tool"] = Vector3(0.1, 0, -1.2 - run * 0.2)
		&"sweep", &"thrust":
			p.rot[&"arm_r"] = Vector3(-0.12, 0, 0.3 + 0.12 * c * move)
			p.rot[&"fore_r"] = Vector3(0, 0, 0.9)
			p.rot[&"tool"] = Vector3(0, 0, -0.9 + 0.08 * sin(t))


# ---------------------------------------------------------------- actions

const ACTIONS: Array[StringName] = [&"swing", &"dodge", &"work", &"work_break", &"work_dig", &"work_fell", &"work_cut", &"gather", &"hurt", &"eat", &"carried", &"downed"]
## Actions with no natural end: they hold their last pose until replaced.
const HELD: Array[StringName] = [&"carried", &"downed"]
## Actions whose legs follow the gait when the body is moving (a swing creeps).
const UPPER_ONLY: Array[StringName] = [&"swing", &"eat"]
const LOWER: Array[StringName] = [&"hips", &"thigh_l", &"thigh_r", &"shin_l", &"shin_r", &"foot_l", &"foot_r", &"hem"]


static func default_seconds(action: StringName, tool_id: StringName) -> float:
	match action:
		&"swing":
			var ms := HeldTools.swing_ms(tool_id)
			return (ms[0] + ms[1] + ms[2]) / 1000.0
		&"dodge": return 0.42
		&"hurt": return 0.45
		&"eat": return 2.4
		&"carried", &"downed": return 0.0
	return 2.0


## The work verb a held tool gives (design-extract §9): what &"work" means in the hand.
static func work_for(tool_id: StringName) -> StringName:
	var def := Items.def(tool_id)
	var verb: StringName = def.get("verb", &"")
	if verb == &"":
		match HeldTools.klass(tool_id):
			&"pick": verb = &"dig" if String(tool_id).begins_with("mattock") else &"break"
			&"axe", &"heavy": verb = &"fell"
			&"blade", &"hook": verb = &"cut"
	match verb:
		&"break": return &"work_break"
		&"dig": return &"work_dig"
		&"fell": return &"work_fell"
		&"cut": return &"work_cut"
	return &"gather"


## Sample an action. `t` is seconds since it started, `seconds` its length (<= 0 = held).
static func action(name: StringName, t: float, seconds: float, d: Dictionary, tool_id: StringName) -> Pose:
	var klass := HeldTools.klass(tool_id)
	match name:
		&"swing":
			return swing(klass, clampf(t / maxf(seconds, 1e-3), 0.0, 1.0), HeldTools.swing_ms(tool_id), d)
		&"dodge":
			return dodge(t, seconds, d)
		&"hurt":
			return hurt(clampf(t / maxf(seconds, 1e-3), 0.0, 1.0), d)
		&"eat":
			return eat(t, d)
		&"carried":
			return carried(t, d)
		&"downed":
			return downed(t, d)
		&"work":
			return action(work_for(tool_id), t, seconds, d, tool_id)
		&"work_break", &"work_dig", &"work_fell", &"work_cut", &"gather":
			return work(name, t, d, tool_id)
	return Pose.new()


static func _stand(d: Dictionary) -> Pose:
	var p := Pose.new()
	var stoop: float = d.get("stoop", 0.0)
	var arms: float = d.get("arms", 0.08)
	var knees: float = d.get("knees", 0.0)
	return p.with({
		"spine": Vector3(0, 0, -stoop), "head": Vector3(0, 0, stoop * 0.8),
		"arm_l": Vector3(arms, 0, 0.04 + stoop * 0.3), "arm_r": Vector3(-arms, 0, 0.04 + stoop * 0.3),
		"fore_l": Vector3(0, 0, 0.14), "fore_r": Vector3(0, 0, 0.14),
		"thigh_l": Vector3(0.05, 0, knees), "thigh_r": Vector3(-0.05, 0, knees),
		"shin_l": Vector3(0, 0, -knees * 2.0), "shin_r": Vector3(0, 0, -knees * 2.0),
		"foot_l": Vector3(0, 0, knees), "foot_r": Vector3(0, 0, knees), "@hips": Vector3(0, -knees * knees * 0.5, 0),
		"tool": Vector3(0, 0, -1.2), "aerial": Vector3(0, 0, -0.12), "aerial_tip": Vector3(0, 0, -0.1),
	})


## The fighting stance every swing starts and ends in: knees soft, left foot
## forward, weight low, hands up.
static func guard(klass: StringName, d: Dictionary) -> Pose:
	var stoop: float = d.get("stoop", 0.0)
	var two := klass == &"heavy" or klass == &"pick" or klass == &"sweep" or klass == &"thrust"
	var p := _stand(d).with({
		"@hips": Vector3(0, -0.045, 0),
		"hips": Vector3(0, -0.22, 0),
		"spine": Vector3(0, 0.08, -0.14 - stoop * 0.6),
		"head": Vector3(0, 0.12, 0.1 + stoop * 0.5),
		"thigh_l": Vector3(0.06, 0, 0.36), "shin_l": Vector3(0, 0, -0.34), "foot_l": Vector3(0, 0, -0.02),
		"thigh_r": Vector3(-0.1, 0, -0.26), "shin_r": Vector3(0, 0, -0.3), "foot_r": Vector3(0, 0, 0.5),
		"arm_l": Vector3(0.25, 0, 0.55), "fore_l": Vector3(0, 0, 1.35),
		"arm_r": Vector3(-0.2, 0, 0.35), "fore_r": Vector3(0, 0, 1.2),
		"hem": Vector3(0, 0, -0.08),
	})
	match klass:
		&"fist":
			p = p.with({"arm_r": Vector3(-0.3, 0, 0.3), "fore_r": Vector3(0, 0, 1.9), "arm_l": Vector3(0.3, 0, 0.6), "fore_l": Vector3(0, 0, 1.8)})
		&"blade", &"hook", &"axe":
			p = p.with({"aim": Vector3(0.6, 0.8, 0.05), "edge": Vector3(1, 0, 0)})
		&"point":
			p = p.with({"arm_r": Vector3(-0.15, 0, 0.9), "fore_r": Vector3(0, 0, 0.6), "aim": Vector3(1, 0.1, 0)})
		&"heavy", &"pick":
			p = p.with({"arm_r": Vector3(-0.1, 0.2, 0.75), "fore_r": Vector3(0, 0, 0.9), "aim": Vector3(0.45, 0.9, -0.1), "edge": Vector3(1, 0, 0), "off_grip": true})
		&"sweep":
			p = p.with({"arm_r": Vector3(-0.1, 0.25, 0.55), "fore_r": Vector3(0, 0, 1.0), "aim": Vector3(0.7, 0.55, -0.35), "off_grip": true})
		&"thrust":
			p = p.with({"arm_r": Vector3(-0.15, 0, 0.2), "fore_r": Vector3(0, 0, 1.2), "aim": Vector3(1, 0.12, -0.12), "off_grip": true, "pole_l": Vector3(0, -1, -0.5)})
	if two:
		p = p.with({"off_grip": true})
	return p


## The swing keys per class: [wind, strike, follow], each over guard().
static func swing_keys(klass: StringName, d: Dictionary) -> Array[Pose]:
	var g := guard(klass, d)
	var wind := g
	var strike := g
	var follow := g
	match klass:
		&"fist":
			wind = g.with({"hips": Vector3(0, -0.35, 0), "spine": Vector3(0, -0.45, -0.1), "arm_r": Vector3(-0.35, 0, -0.1), "fore_r": Vector3(0, 0, 2.2), "head": Vector3(0, 0.35, 0.1)})
			strike = g.with({"@hips": Vector3(0.05, -0.06, 0), "hips": Vector3(0, 0.25, 0), "spine": Vector3(0, 0.45, -0.3), "arm_r": Vector3(0.05, 0.25, 1.5), "fore_r": Vector3(0, 0, 0.05), "arm_l": Vector3(0.3, 0, 0.2), "fore_l": Vector3(0, 0, 2.0), "head": Vector3(0, -0.3, 0.2), "thigh_l": Vector3(0.06, 0, 0.55), "shin_l": Vector3(0, 0, -0.5)})
			follow = strike.with({"spine": Vector3(0, 0.5, -0.32), "arm_r": Vector3(0.05, 0.3, 1.45)})
		&"blade":
			# A forehand slash: cocked out to the right, across to the left.
			wind = g.with({"hips": Vector3(0, -0.35, 0), "spine": Vector3(0, -0.55, -0.08), "head": Vector3(0, 0.45, 0.1),
				"arm_r": Vector3(-0.2, -1.05, 1.1), "fore_r": Vector3(0, 0, 1.3), "aim": Vector3(-0.3, 0.75, 0.6), "edge": Vector3(0, 0, -1),
				"arm_l": Vector3(0.2, 0.3, 1.0), "fore_l": Vector3(0, 0, 0.7)})
			strike = g.with({"@hips": Vector3(0.05, -0.07, 0), "hips": Vector3(0, 0.15, 0), "spine": Vector3(0, 0.3, -0.3), "head": Vector3(0, -0.15, 0.2),
				"arm_r": Vector3(0, -0.05, 1.45), "fore_r": Vector3(0, 0, 0.2), "aim": Vector3(1, 0.05, -0.2), "edge": Vector3(0, 0, -1),
				"arm_l": Vector3(0.35, 0, 0.25), "fore_l": Vector3(0, 0, 1.3), "thigh_l": Vector3(0.06, 0, 0.55), "shin_l": Vector3(0, 0, -0.45)})
			follow = strike.with({"spine": Vector3(0, 0.7, -0.34), "head": Vector3(0, -0.45, 0.2), "hips": Vector3(0, 0.3, 0),
				"arm_r": Vector3(0.1, 1.15, 1.25), "fore_r": Vector3(0, 0, 0.45), "aim": Vector3(0.2, -0.1, -1), "edge": Vector3(-0.4, 0, -1),
				"arm_l": Vector3(0.4, 0, -0.35), "fore_l": Vector3(0, 0, 1.0)})
		&"hook":
			# High on the right, a long diagonal down across the body.
			wind = g.with({"hips": Vector3(0, -0.35, 0), "spine": Vector3(0, -0.6, 0.06), "head": Vector3(0, 0.5, 0.05),
				"arm_r": Vector3(-0.35, -0.7, 2.5), "fore_r": Vector3(0, 0, 1.0), "aim": Vector3(-0.6, 0.5, 0.6), "edge": Vector3(0, 1, 0),
				"arm_l": Vector3(0.2, 0.3, 1.1), "fore_l": Vector3(0, 0, 0.6)})
			strike = g.with({"@hips": Vector3(0.05, -0.08, 0), "hips": Vector3(0, 0.2, 0), "spine": Vector3(0, 0.3, -0.35), "head": Vector3(0, -0.2, 0.25),
				"arm_r": Vector3(0.1, 0.1, 1.4), "fore_r": Vector3(0, 0, 0.15), "aim": Vector3(0.9, -0.35, -0.3), "edge": Vector3(0, -1, -0.5),
				"arm_l": Vector3(0.35, 0, 0.1), "fore_l": Vector3(0, 0, 1.3), "thigh_l": Vector3(0.06, 0, 0.6), "shin_l": Vector3(0, 0, -0.5)})
			follow = strike.with({"spine": Vector3(0, 0.6, -0.45), "head": Vector3(0, -0.4, 0.3),
				"arm_r": Vector3(0.6, 0.9, 0.6), "fore_r": Vector3(0, 0, 0.3), "aim": Vector3(0.1, -0.8, -0.6), "edge": Vector3(-0.5, 0, -1)})
		&"axe":
			# One hand overhead and back, chop down through the target.
			wind = g.with({"hips": Vector3(0, -0.3, 0), "spine": Vector3(0, -0.45, 0.15), "head": Vector3(0, 0.35, -0.05),
				"arm_r": Vector3(-0.3, -0.2, 2.75), "fore_r": Vector3(0, 0, 1.0), "aim": Vector3(-0.75, -0.25, 0.1), "edge": Vector3(0, 1, 0),
				"arm_l": Vector3(0.25, 0.2, 1.3), "fore_l": Vector3(0, 0, 0.4), "thigh_l": Vector3(0.06, 0, 0.3)})
			strike = g.with({"@hips": Vector3(0.06, -0.1, 0), "hips": Vector3(0, 0.2, 0), "spine": Vector3(0, 0.25, -0.42), "head": Vector3(0, -0.15, 0.35),
				"arm_r": Vector3(-0.05, 0, 1.45), "fore_r": Vector3(0, 0, 0.1), "aim": Vector3(1, -0.3, 0), "edge": Vector3(0, -1, 0),
				"arm_l": Vector3(0.3, 0, 0.1), "fore_l": Vector3(0, 0, 1.4), "thigh_l": Vector3(0.06, 0, 0.62), "shin_l": Vector3(0, 0, -0.55)})
			follow = strike.with({"spine": Vector3(0, 0.35, -0.55), "arm_r": Vector3(0.1, 0.2, 0.55), "fore_r": Vector3(0, 0, 0.2), "aim": Vector3(0.4, -1, -0.15), "edge": Vector3(-1, 0, 0)})
		&"heavy", &"pick":
			# Two hands, all the way up and over: the heaviest silhouette change.
			var deep := 0.12 if klass == &"heavy" else 0.0
			wind = g.with({"@hips": Vector3(-0.03, -0.02, 0), "hips": Vector3(0, -0.25 - deep, 0), "spine": Vector3(0, -0.3 - deep * 2.0, 0.28), "head": Vector3(0, 0.25, -0.15),
				"arm_r": Vector3(-0.15, 0.1, 2.85), "fore_r": Vector3(0, 0, 0.7), "aim": Vector3(-0.85, -0.35, 0.05), "edge": Vector3(0, 1, 0), "off_grip": true,
				"pole_l": Vector3(0.2, 0.3, -1), "thigh_l": Vector3(0.06, 0, 0.25), "thigh_r": Vector3(-0.1, 0, -0.35)})
			strike = g.with({"@hips": Vector3(0.07, -0.12, 0), "hips": Vector3(0, 0.12, 0), "spine": Vector3(0, 0.12, -0.5), "head": Vector3(0, -0.1, 0.4),
				"arm_r": Vector3(-0.05, 0.1, 1.35), "fore_r": Vector3(0, 0, 0.1), "aim": Vector3(1, -0.2, -0.05), "edge": Vector3(0, -1, 0), "off_grip": true,
				"pole_l": Vector3(-0.2, -1, -0.8), "thigh_l": Vector3(0.06, 0, 0.7), "shin_l": Vector3(0, 0, -0.65), "thigh_r": Vector3(-0.1, 0, -0.45), "shin_r": Vector3(0, 0, -0.35)})
			follow = strike.with({"@hips": Vector3(0.08, -0.16, 0), "spine": Vector3(0, 0.15, -0.75), "head": Vector3(0, -0.1, 0.55),
				"arm_r": Vector3(0.05, 0.1, 0.55), "fore_r": Vector3(0, 0, 0.1), "aim": Vector3(0.35, -1, -0.05), "edge": Vector3(-1, 0, 0)})
		&"sweep":
			# Flat and wide, right to left, the shaft level through the middle.
			wind = g.with({"hips": Vector3(0, -0.45, 0), "spine": Vector3(0, -0.7, -0.05), "head": Vector3(0, 0.55, 0.05),
				"arm_r": Vector3(-0.1, -0.9, 1.05), "fore_r": Vector3(0, 0, 0.9), "aim": Vector3(-0.55, 0.25, 0.8), "edge": Vector3(0, 0, -1), "off_grip": true,
				"pole_l": Vector3(0, -1, 0)})
			strike = g.with({"@hips": Vector3(0.04, -0.08, 0), "hips": Vector3(0, 0.2, 0), "spine": Vector3(0, 0.25, -0.22), "head": Vector3(0, -0.2, 0.15),
				"arm_r": Vector3(0, -0.1, 1.2), "fore_r": Vector3(0, 0, 0.35), "aim": Vector3(1, 0.05, -0.15), "edge": Vector3(0, 0, -1), "off_grip": true,
				"pole_l": Vector3(0, -1, -0.3), "thigh_l": Vector3(0.06, 0, 0.55), "shin_l": Vector3(0, 0, -0.45)})
			follow = strike.with({"hips": Vector3(0, 0.35, 0), "spine": Vector3(0, 0.75, -0.25), "head": Vector3(0, -0.5, 0.15),
				"arm_r": Vector3(0.1, 1.0, 1.15), "fore_r": Vector3(0, 0, 0.5), "aim": Vector3(0.1, 0.05, -1), "edge": Vector3(-1, 0, 0)})
		&"thrust":
			# Draw the shaft back along its own line, then drive it out with the whole body.
			wind = g.with({"@hips": Vector3(-0.06, -0.03, 0), "hips": Vector3(0, -0.35, 0), "spine": Vector3(0, -0.35, 0.1), "head": Vector3(0, 0.3, -0.05),
				"arm_r": Vector3(-0.2, 0, -0.35), "fore_r": Vector3(0, 0, 1.5), "aim": Vector3(1, 0.15, -0.05), "off_grip": true,
				"thigh_l": Vector3(0.06, 0, 0.3), "shin_l": Vector3(0, 0, -0.2), "thigh_r": Vector3(-0.1, 0, -0.2), "shin_r": Vector3(0, 0, -0.6)})
			strike = g.with({"@hips": Vector3(0.14, -0.12, 0), "hips": Vector3(0, 0.1, 0), "spine": Vector3(0, 0.15, -0.45), "head": Vector3(0, -0.1, 0.35),
				"arm_r": Vector3(-0.1, 0, 1.2), "fore_r": Vector3(0, 0, 0.35), "aim": Vector3(1, -0.02, 0), "off_grip": true,
				"thigh_l": Vector3(0.06, 0, 0.85), "shin_l": Vector3(0, 0, -0.75), "thigh_r": Vector3(-0.1, 0, -0.55), "shin_r": Vector3(0, 0, -0.1)})
			follow = strike.with({"@hips": Vector3(0.16, -0.13, 0), "spine": Vector3(0, 0.2, -0.5), "arm_r": Vector3(-0.1, 0, 1.4), "fore_r": Vector3(0, 0, 0.15)})
		&"point":
			wind = g.with({"spine": Vector3(0, -0.25, 0.05), "arm_r": Vector3(-0.2, 0, 1.2), "fore_r": Vector3(0, 0, 1.1), "aim": Vector3(0.6, 0.8, 0), "head": Vector3(0, 0.2, 0.05)})
			strike = g.with({"@hips": Vector3(0.02, -0.05, 0), "spine": Vector3(0, 0.3, -0.18), "head": Vector3(0, -0.25, 0.12),
				"arm_r": Vector3(0, 0.25, 1.55), "fore_r": Vector3(0, 0, 0.05), "aim": Vector3(1, 0.0, 0), "arm_l": Vector3(0.3, 0, 0.9), "fore_l": Vector3(0, 0, 1.6)})
			# The kick: the device throws the arm up and back.
			follow = strike.with({"spine": Vector3(0, 0.2, 0.08), "arm_r": Vector3(0, 0.2, 1.9), "fore_r": Vector3(0, 0, 0.5), "aim": Vector3(0.7, 0.7, 0), "head": Vector3(0, -0.2, -0.05)})
	return [wind, strike, follow]


## A swing at normalized time u, phased by the weapon's [windup, active, recovery] ms.
static func swing(klass: StringName, u: float, ms: Array[int], d: Dictionary) -> Pose:
	var total := float(maxi(1, ms[0] + ms[1] + ms[2]))
	var tw := ms[0] / total
	var ta := (ms[0] + ms[1]) / total
	var keys := swing_keys(klass, d)
	var g := guard(klass, d)
	var tm := lerpf(tw, ta, 0.45)
	if u < tw * 0.82:
		# Anticipation: out of the guard fast, easing into the extreme.
		return mix_keys(g, keys[0], _ease_out(u / (tw * 0.82)))
	if u < tw:
		return keys[0]
	if u < tm:
		# The blow accelerates into contact.
		return mix_keys(keys[0], keys[1], _ease_in((u - tw) / maxf(1e-4, tm - tw)))
	if u < ta:
		return mix_keys(keys[1], keys[2], _ease_out((u - tm) / maxf(1e-4, ta - tm)))
	# Follow-through holds a moment, then the body gathers back to guard.
	var rec := (u - ta) / maxf(1e-4, 1.0 - ta)
	return mix_keys(keys[2], g, smoothstep(0.15, 1.0, rec))


## Dodge: a committed tuck-and-roll along the facing. The body closes into a
## ball BEFORE it turns and opens only after it has come round, so every frame of
## the roll is one round outline with the tool pulled in, never limbs mid-turn.
## The burst is the first ~72% of the lock; the rest is landing low and rising.
static func dodge(t: float, seconds: float, d: Dictionary) -> Pose:
	var dur := seconds if seconds > 0.0 else 0.42
	var hip_y: float = d.get("hip_y", 0.6)
	var coil_end := minf(0.06, dur * 0.14)
	var roll_end := dur * 0.72
	var st := _stand(d)
	var tuck := st.with({
		# Sat back on the hips with the knees at the chest and the back rounded over
		# them: a ball from any side, since the camera mostly sees the curved back.
		"@hips": Vector3(-0.04, -hip_y * 0.45, 0),
		"hips": Vector3(0, 0, 0.55),
		"spine": Vector3(0, 0, -1.05), "head": Vector3(0, 0, -0.85),
		"thigh_l": Vector3(0.1, 0, 2.05), "shin_l": Vector3(0, 0, -2.6), "thigh_r": Vector3(-0.1, 0, 2.0), "shin_r": Vector3(0, 0, -2.6),
		"foot_l": Vector3(0, 0, 0.6), "foot_r": Vector3(0, 0, 0.6),
		"arm_l": Vector3(0.1, 0, 0.75), "fore_l": Vector3(0, 0, 2.1), "arm_r": Vector3(-0.1, 0, 0.75), "fore_r": Vector3(0, 0, 2.1),
		"hem": Vector3(0, 0, -0.9), "aerial": Vector3(0, 0, -1.2), "aerial_tip": Vector3(0, 0, -0.4), "tool": Vector3(0, 0, -0.2),
	})
	var coil := st.with({
		"@hips": Vector3(0.03, -hip_y * 0.3, 0), "spine": Vector3(0, 0, -0.85), "head": Vector3(0, 0, 0.1),
		"thigh_l": Vector3(0.08, 0, 1.3), "shin_l": Vector3(0, 0, -1.7), "thigh_r": Vector3(-0.08, 0, 0.5), "shin_r": Vector3(0, 0, -1.5),
		"foot_l": Vector3(0, 0, 0.4), "foot_r": Vector3(0, 0, 1.0),
		"arm_l": Vector3(0.25, 0, 0.9), "fore_l": Vector3(0, 0, 1.6), "arm_r": Vector3(-0.25, 0, 0.9), "fore_r": Vector3(0, 0, 1.6),
		"hem": Vector3(0, 0, -0.5), "tool": Vector3(0, 0, -0.35),
	})
	var land := st.with({
		"@hips": Vector3(0, -hip_y * 0.28, 0), "spine": Vector3(0, 0, -0.55), "head": Vector3(0, 0, 0.4),
		"thigh_l": Vector3(0.1, 0, 1.25), "shin_l": Vector3(0, 0, -1.6), "thigh_r": Vector3(-0.1, 0, -0.1), "shin_r": Vector3(0, 0, -1.7),
		"foot_l": Vector3(0, 0, 0.35), "foot_r": Vector3(0, 0, 0.9),
		"arm_l": Vector3(0.6, 0, 0.9), "fore_l": Vector3(0, 0, 0.7), "arm_r": Vector3(-0.55, 0, 0.6), "fore_r": Vector3(0, 0, 0.8),
		"hem": Vector3(0, 0, 0.3), "tool": Vector3(0, 0, -1.6),
	})
	if t < coil_end:
		return mix_keys(st, coil, _ease_out(t / coil_end))
	if t < roll_end:
		var u := (t - coil_end) / (roll_end - coil_end)
		var p := mix_keys(coil, tuck, smoothstep(0.0, 0.16, u))
		p = mix_keys(p, land, smoothstep(0.86, 1.0, u))
		# One full turn about the lateral axis, only while balled, pivoting at the
		# ball's middle; the ball rides a low arc over the ground.
		var ang := -TAU * smoothstep(0.14, 0.86, u)
		var centre := Vector3(0.04, hip_y * 0.42, 0)
		var basis := Basis(Vector3.BACK, ang)
		p.rot[&"root"] = Vector3(0, 0, ang)
		p.off[&"root"] = centre - basis * centre + Vector3(0, sin(u * PI) * 0.05, 0)
		return p
	return mix_keys(land, st, smoothstep(0.0, 1.0, (t - roll_end) / maxf(1e-3, dur - roll_end)))


## Hurt: the blow snaps the head and chest back, arms fly, a stagger, then a sag.
static func hurt(u: float, d: Dictionary) -> Pose:
	var st := _stand(d)
	var stoop: float = d.get("stoop", 0.0)
	var snap := st.with({
		"@hips": Vector3(-0.08, -0.03, 0), "@root": Vector3(-0.05, 0, 0),
		"spine": Vector3(0.1, -0.2, 0.42 - stoop * 0.5), "head": Vector3(0.15, 0.2, 0.55),
		"arm_l": Vector3(0.7, 0, 0.9), "fore_l": Vector3(0, 0, 0.9), "arm_r": Vector3(-0.8, 0, 0.7), "fore_r": Vector3(0, 0, 1.0),
		"thigh_l": Vector3(0.1, 0, -0.1), "shin_l": Vector3(0, 0, -0.5), "thigh_r": Vector3(-0.1, 0, 0.35), "shin_r": Vector3(0, 0, -0.2),
		"foot_l": Vector3(0, 0, 0.5), "hem": Vector3(0, 0, 0.5), "aerial": Vector3(0, 0, 0.6), "aerial_tip": Vector3(0, 0, 0.5), "tool": Vector3(0, 0, -0.4),
	})
	var sag := st.with({
		"@hips": Vector3(-0.04, -0.07, 0), "@root": Vector3(-0.08, 0, 0),
		"spine": Vector3(0, 0.05, -0.35 - stoop), "head": Vector3(0, -0.1, -0.2),
		"arm_l": Vector3(0.2, 0, 0.35), "fore_l": Vector3(0, 0, 1.2), "arm_r": Vector3(-0.1, 0, 0.3), "fore_r": Vector3(0, 0, 0.9),
		"thigh_l": Vector3(0.05, 0, 0.3), "shin_l": Vector3(0, 0, -0.5), "thigh_r": Vector3(-0.05, 0, -0.1), "shin_r": Vector3(0, 0, -0.45),
		"foot_l": Vector3(0, 0, 0.2), "foot_r": Vector3(0, 0, 0.5), "hem": Vector3(0, 0, -0.15),
	})
	if u < 0.14:
		return mix_keys(st, snap, _ease_out(u / 0.14))
	if u < 0.5:
		return mix_keys(snap, sag, smoothstep(0.0, 1.0, (u - 0.14) / 0.36))
	return mix_keys(sag, st, smoothstep(0.0, 1.0, (u - 0.5) / 0.5))


## Eat: food in the left hand, bites on a loop; the head comes down to meet it.
static func eat(t: float, d: Dictionary) -> Pose:
	var period := loop_period(&"eat", &"")
	var u := fposmod(t, period) / period
	var head_y: float = d.get("hip_y", 0.6) + 0.05 + float(d.get("torso", 0.41))
	var mouth := Vector3(float(d.get("head_d", 0.27)) * 0.5 + 0.06, head_y + float(d.get("head", 0.29)) * 0.15, -0.02)
	var chest := Vector3(0.22, head_y - 0.25, -0.08)
	var bite := smoothstep(0.0, 0.35, u) * (1.0 - smoothstep(0.55, 0.9, u))
	var chew := sin(t * TAU * 4.0) * 0.04 * (1.0 - bite)
	var st := _stand(d)
	return st.with({
		"ik_l": chest.lerp(mouth, bite), "pole_l": Vector3(0.2, -1, -1),
		"food": 1.0,
		"spine": Vector3(0, 0.1, -0.08 - float(d.get("stoop", 0.0)) - bite * 0.06),
		"head": Vector3(0, -0.05, -0.22 * bite + chew + float(d.get("stoop", 0.0)) * 0.8),
		"arm_r": Vector3(-0.08, 0, 0.12), "fore_r": Vector3(0, 0, 0.4),
	})


## Limp: hanging over something that is carrying the body off. The pose hangs
## from the root at waist height; the carrier positions the model.
static func carried(t: float, d: Dictionary) -> Pose:
	var hip_y: float = d.get("hip_y", 0.6)
	var sway := sin(t * 1.9) * 0.09
	var sway2 := sin(t * 1.9 - 0.7) * 0.12
	var p := _stand(d).with({
		"root": Vector3(0, 0, -1.45),
		"@root": Vector3(-hip_y * 0.1, 0.25, 0),
		"spine": Vector3(0, 0, -0.35), "head": Vector3(0.25, 0.3, -0.9 + sway),
		# Everything hangs: in the body frame, "down" is backwards and then some.
		"arm_l": Vector3(0.1, 0, 1.2 + sway2), "fore_l": Vector3(0, 0, 0.35), "arm_r": Vector3(-0.15, 0, 1.1 + sway2), "fore_r": Vector3(0, 0, 0.4),
		"thigh_l": Vector3(0.05, 0, -0.1 + sway), "shin_l": Vector3(0, 0, -1.25), "thigh_r": Vector3(-0.05, 0, -0.25 + sway), "shin_r": Vector3(0, 0, -1.05),
		"foot_l": Vector3(0, 0, 0.6), "foot_r": Vector3(0, 0, 0.6),
		"hem": Vector3(0, 0, 1.3), "aerial": Vector3(0, 0, 1.2), "aerial_tip": Vector3(0, 0, 0.4), "tool": Vector3(0, 0, -2.8),
	})
	return p


## Downed: the knees go, the body folds forward and lies face down, breathing.
static func downed(t: float, d: Dictionary) -> Pose:
	var hip_y: float = d.get("hip_y", 0.6)
	var depth: float = d.get("depth", 0.22)
	var st := _stand(d)
	var buckle := st.with({
		"@hips": Vector3(-0.05, -hip_y * 0.42, 0), "spine": Vector3(0.1, 0.1, -0.6), "head": Vector3(0, 0, -0.4),
		"thigh_l": Vector3(0.1, 0, 1.4), "shin_l": Vector3(0, 0, -2.3), "thigh_r": Vector3(-0.1, 0, 1.2), "shin_r": Vector3(0, 0, -2.2),
		"foot_l": Vector3(0, 0, 0.9), "foot_r": Vector3(0, 0, 1.0),
		"arm_l": Vector3(0.3, 0, 0.3), "fore_l": Vector3(0, 0, 0.3), "arm_r": Vector3(-0.3, 0, 0.2), "fore_r": Vector3(0, 0, 0.3),
		"tool": Vector3(0, 0, -1.8),
	})
	var breath := sin(t * TAU / 2.6) * 0.012
	var lying := st.with({
		"root": Vector3(0, 0, -PI * 0.5),
		"@root": Vector3(-hip_y * 0.55, depth * 0.52 + 0.01 + breath, 0),
		"spine": Vector3(0.12, 0, 0.05), "head": Vector3(0.1, 0.95, 0.12),
		"arm_l": Vector3(0.1, 0, 2.7), "fore_l": Vector3(0, 0, 0.5), "arm_r": Vector3(-0.35, 0, 0.25), "fore_r": Vector3(0, 0, 0.3),
		"thigh_l": Vector3(0.15, 0, 0.5), "shin_l": Vector3(0, 0, -0.9), "thigh_r": Vector3(-0.08, 0, -0.05), "shin_r": Vector3(0, 0, -0.15),
		"foot_l": Vector3(0, 0, 1.2), "foot_r": Vector3(0, 0, 1.4),
		"hem": Vector3(0, 0, 0.1), "aerial": Vector3(0.8, 0, -0.9), "tool": Vector3(0, 0, -2.0),
	})
	if t < 0.22:
		return mix_keys(st, buckle, _ease_in(t / 0.22))
	if t < 0.6:
		return mix_keys(buckle, lying, _ease_in((t - 0.22) / 0.38))
	# A small bounce on landing, then stillness.
	var settle := (t - 0.6) / 0.2
	if settle < 1.0:
		var p := lying.with({})
		p.off[&"root"] = lying.o(&"root") + Vector3(0, sin(settle * PI) * 0.035, 0)
		return p
	return lying


## Seconds before a looping action repeats exactly (0 = it does not loop): lets
## PersonModel cache resolved poses instead of solving IK every frame.
static func loop_period(name: StringName, tool_id: StringName) -> float:
	match name:
		&"work":
			return loop_period(work_for(tool_id), tool_id)
		&"work_break": return 0.95
		&"work_dig": return 1.15
		&"work_fell": return 0.9
		&"work_cut": return 0.55
		&"gather": return 1.7
		&"eat": return 1.0
		&"carried": return TAU / 1.9
	return 0.0


## Work loops keyed to real seconds, so a long job keeps an honest tempo.
static func work(verb: StringName, t: float, d: Dictionary, tool_id: StringName) -> Pose:
	var klass := HeldTools.klass(tool_id)
	var stoop: float = d.get("stoop", 0.0)
	match verb:
		&"work_break", &"work_dig":
			var dig := verb == &"work_dig"
			var period := loop_period(verb, tool_id)
			var u := fposmod(t, period) / period
			var g := guard(&"pick", d)
			var up := g.with({"@hips": Vector3(-0.02, -0.03, 0), "hips": Vector3(0, -0.2, 0), "spine": Vector3(0, -0.2, 0.2 - stoop * 0.5), "head": Vector3(0, 0.2, 0.05),
				"arm_r": Vector3(-0.1, 0.1, 2.75), "fore_r": Vector3(0, 0, 0.8), "aim": Vector3(-0.8, -0.2, 0.05), "edge": Vector3(0, 1, 0), "off_grip": true, "pole_l": Vector3(0.2, 0.3, -1)})
			var down := g.with({"@hips": Vector3(0.03, -0.14, 0), "hips": Vector3(0, 0.1, 0), "spine": Vector3(0, 0.1, -0.85 - stoop * 0.3), "head": Vector3(0, -0.1, 0.5),
				"arm_r": Vector3(0, 0.1, 0.75), "fore_r": Vector3(0, 0, 0.15), "aim": Vector3(0.3 if dig else 0.55, -1, -0.05), "edge": Vector3(1, 0, 0) if dig else Vector3(-1, 0, 0), "off_grip": true,
				"pole_l": Vector3(-0.3, -1, -0.6), "thigh_l": Vector3(0.1, 0, 0.7), "shin_l": Vector3(0, 0, -0.75), "thigh_r": Vector3(-0.1, 0, -0.45), "shin_r": Vector3(0, 0, -0.5)})
			var lever := down.with({"@hips": Vector3(-0.03, -0.12, 0), "spine": Vector3(0, 0.0, -0.55), "arm_r": Vector3(-0.1, 0.1, 0.35), "fore_r": Vector3(0, 0, 0.5), "aim": Vector3(0.9, -0.55, -0.05)})
			if u < 0.42:
				return mix_keys(down if not dig else lever, up, smoothstep(0.0, 1.0, u / 0.42))
			if u < 0.58:
				return mix_keys(up, down, _ease_in((u - 0.42) / 0.16))
			if dig and u < 0.8:
				return mix_keys(down, lever, smoothstep(0.0, 1.0, (u - 0.58) / 0.22))
			return down if not dig else lever
		&"work_fell":
			# Level chops at a trunk: the twist is the power.
			var period := loop_period(verb, tool_id)
			var u := fposmod(t, period) / period
			var two := klass == &"heavy"
			var g := guard(klass if klass == &"axe" or klass == &"heavy" else &"axe", d)
			var back := g.with({"hips": Vector3(0, -0.45, 0), "spine": Vector3(0, -0.85, -0.1 - stoop * 0.5), "head": Vector3(0, 0.75, 0.05),
				"arm_r": Vector3(-0.5, -1.2, 1.35), "fore_r": Vector3(0, 0, 1.1), "aim": Vector3(-0.5, 0.2, 0.85), "edge": Vector3(0, 0, -1), "off_grip": two,
				"arm_l": Vector3(0.2, 0.2, 0.9), "fore_l": Vector3(0, 0, 0.9), "pole_l": Vector3(0, -1, 0)})
			var hit := g.with({"@hips": Vector3(0.03, -0.08, 0), "hips": Vector3(0, 0.25, 0), "spine": Vector3(0, 0.3, -0.25 - stoop * 0.5), "head": Vector3(0, -0.2, 0.1),
				"arm_r": Vector3(0, 0.1, 1.3), "fore_r": Vector3(0, 0, 0.2), "aim": Vector3(0.75, 0.0, -0.66), "edge": Vector3(0.3, 0, -1), "off_grip": two,
				"arm_l": Vector3(0.3, 0, 0.3), "fore_l": Vector3(0, 0, 1.3), "pole_l": Vector3(0, -1, -0.4),
				"thigh_l": Vector3(0.06, 0, 0.5), "shin_l": Vector3(0, 0, -0.4)})
			if u < 0.55:
				return mix_keys(hit, back, smoothstep(0.0, 1.0, u / 0.55))
			if u < 0.72:
				return mix_keys(back, hit, _ease_in((u - 0.55) / 0.17))
			return hit
		&"work_cut":
			# Down on one knee, the stuff held in the left hand, short saws with the right.
			var period := loop_period(verb, tool_id)
			var u := fposmod(t, period) / period
			var saw := sin(u * TAU)
			var hip_y: float = d.get("hip_y", 0.6)
			var knee := _stand(d).with({
				"@hips": Vector3(-0.08, -hip_y * 0.45, 0),
				"spine": Vector3(0, 0.15 + saw * 0.06, -0.55 - stoop * 0.3), "head": Vector3(0, -0.1, 0.3),
				"thigh_l": Vector3(0.05, 0, 1.45), "shin_l": Vector3(0, 0, -1.5), "foot_l": Vector3(0, 0, 0.05),
				"thigh_r": Vector3(-0.08, 0, -0.1), "shin_r": Vector3(0, 0, -1.9), "foot_r": Vector3(0, 0, 1.6),
				"ik_l": Vector3(0.48, 0.3, -0.12), "pole_l": Vector3(0, -1, -1),
				"arm_r": Vector3(-0.1, 0.15, 0.7 + saw * 0.3), "fore_r": Vector3(0, 0, 0.9 - saw * 0.3),
				"aim": Vector3(0.6, -0.75, -0.35 + saw * 0.1), "edge": Vector3(0, -1, 0),
				"hem": Vector3(0, 0, 0.4),
			})
			return knee
		&"gather":
			var period := loop_period(verb, tool_id)
			var u := fposmod(t, period) / period
			var hip_y: float = d.get("hip_y", 0.6)
			var st := _stand(d)
			var reach := st.with({
				"@hips": Vector3(-0.1, -hip_y * 0.28, 0),
				"spine": Vector3(0, -0.1, -1.05), "head": Vector3(0, 0.1, 0.55),
				"thigh_l": Vector3(0.1, 0, 0.85), "shin_l": Vector3(0, 0, -1.1), "foot_l": Vector3(0, 0, 0.25),
				"thigh_r": Vector3(-0.1, 0, 0.35), "shin_r": Vector3(0, 0, -1.0), "foot_r": Vector3(0, 0, 0.65),
				"ik_l": Vector3(0.5, 0.06, -0.14), "ik_r": Vector3(0.52, 0.06, 0.12),
				"pole_l": Vector3(0, 1, -0.5), "pole_r": Vector3(0, 1, 0.5),
				"hem": Vector3(0, 0, 0.5), "tool": Vector3(0, 0, -0.5),
			})
			var stow := st.with({
				"@hips": Vector3(0, -0.02, 0), "spine": Vector3(0, 0.25, -0.12 - stoop), "head": Vector3(0, 0.3, 0.2),
				"ik_l": Vector3(-0.08, hip_y + 0.02, -0.28), "pole_l": Vector3(0.5, 0, -1),
				"arm_r": Vector3(-0.1, 0, 0.1), "fore_r": Vector3(0, 0, 0.3),
			})
			if u < 0.35:
				return mix_keys(stow, reach, smoothstep(0.0, 1.0, u / 0.35))
			if u < 0.5:
				return reach
			if u < 0.85:
				return mix_keys(reach, stow, smoothstep(0.0, 1.0, (u - 0.5) / 0.35))
			return stow
	return _stand(d)


static func _ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x


static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)
