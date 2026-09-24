extends RefCounted
## HOW A COLOSSUS STANDS AT A GIVEN WORLD MINUTE: pure, periodic, and the only
## place its gait is decided.
##
## `pose(def, route, minutes)` is a function of its arguments and nothing else.
## Nothing integrates and nothing is saved: the world clock IS the walk. That is
## what makes a machine this size affordable to be exact about -- a shot at a
## minute, a tour that waits for a step, and the frame after a save loads all see
## the one pose the clock says, and the step events a later slice fires are
## found by asking two minutes the same question.
##
## THE GAIT is a tripod wave: in each cycle every leg steps once, in turn, and
## only one is ever in the air, because a tripod on two legs falls over. Leg k's
## j-th swing runs over cycles [j + k/3, j + k/3 + swing share); before it the
## foot stands on plant j-1, after it on plant j. A plant is a point on the
## route, at the middle of the rest it will stand through, set out to the side
## at the leg's own bearing from the heading there, so the hub -- which rides the
## three feet's centroid -- is over the route when all three are down.
##
## A swing is lift straight up, carry, lower straight down, with a long eased
## set-down: the foot is slowest in the last few hundred metres, which is where
## a thing that size is most dangerous and where a player will be looking.
##
## Knees are two-bone IK on rigid bones, bent outward and up away from the hub,
## so the legs arch like a spider's rather than folding under the body.
##
## World units are metres; positions are `Vector3(x, height, z)` over sea level
## (the land's own heights are a few units and do not matter at this scale).

## Out of a swing's share of the cycle: how much is spent lifting, and where the
## lowering begins. The carry runs across the middle.
const LIFT_END := 0.18
const LOWER_FROM := 0.74
## The carry's own span (it overlaps both ends, so the foot leaves on a diagonal
## and arrives on one rather than turning a right angle in the sky).
const CARRY := Vector2(0.10, 0.90)


## Plant `j` of leg `k`: where that foot stands after its j-th swing -- on the
## tread world generation cut for it, if it has one (`route.treads`), and
## otherwise where the gait alone would set it.
static func plant(def: RefCounted, route: RefCounted, k: int, j: int) -> Vector3:
	var t: Vector4 = route.tread_of(k, j)
	if not is_nan(t.x):
		return Vector3(t.x, t.y, t.z)
	return natural_plant(def, route, k, j)


## Where the gait alone sets plant `j` of leg `k`: a point on the route at the
## middle of the rest it will stand through, set out to the side at the leg's own
## bearing from the heading there.
static func natural_plant(def: RefCounted, route: RefCounted, k: int, j: int) -> Vector3:
	var u := _plant_u(def, k, j)
	var at: Vector2 = route.at(u)
	var h := natural_yaw(def, route, k, j)
	var p := at + Vector2(cos(h), sin(h)) * float(def.feet_circle)
	return Vector3(p.x, 0.0, p.y)


static func _plant_u(def: RefCounted, k: int, j: int) -> float:
	var f: float = def.swing_share()
	return float(j) + float(k) / 3.0 + (1.0 + f) * 0.5


## WHICH WAY A PLANTED FOOT FACES: out from the body along the leg's own bearing
## at the plant, fixed from the moment it lands until it lifts. A foot turned by
## the hub instead swivelled its pads across the ground while it stood, as the
## other legs stepped; a foot that stands in a crater cannot.
static func natural_yaw(def: RefCounted, route: RefCounted, k: int, j: int) -> float:
	return route.heading(_plant_u(def, k, j)) + deg_to_rad(float(def.slots[k]))


static func plant_yaw(def: RefCounted, route: RefCounted, k: int, j: int) -> float:
	var t: Vector4 = route.tread_of(k, j)
	if not is_nan(t.w):
		return t.w
	return natural_yaw(def, route, k, j)


## Where foot `k` is at `minutes` (its pad, on the ground or in the air), how far
## through a swing it is (-1 when it is planted), which way it faces, and the
## plant it stands on or is on its way to.
static func foot(def: RefCounted, route: RefCounted, k: int, minutes: float) -> Array:
	var f: float = def.swing_share()
	var u := minutes / float(def.cycle_minutes)
	var v := u - float(k) / 3.0
	var j := floori(v)
	var s := (v - float(j)) / f
	if s >= 1.0:
		return [plant(def, route, k, j), -1.0, plant_yaw(def, route, k, j), j]
	var from := plant(def, route, k, j - 1)
	var to := plant(def, route, k, j)
	var carry := smoothstep(CARRY.x, CARRY.y, s)
	var up := smoothstep(0.0, LIFT_END, s)
	var down := smoothstep(LOWER_FROM, 1.0, s)
	# Squared on the way down: the set-down eases in, and the last stretch is the
	# slowest part of the whole step.
	var high := float(def.lift) * up * (1.0 - down) * (1.0 - down)
	var p := from.lerp(to, carry)
	# Lifted from the ground it stood on and lowered onto the ground it will
	# stand on: a crater floor is a few metres over the sea the gait assumes.
	p.y = high + lerpf(from.y, to.y, down)
	var yaw := lerp_angle(plant_yaw(def, route, k, j - 1), plant_yaw(def, route, k, j), carry)
	return [p, s, yaw, j]


## The whole body at `minutes`.
##   hub: Transform3D -- origin at the hub's centre at hip height, facing +X
##        along the heading (`rotation.y = -heading`, as every model here)
##   hips, knees, ankles, feet: Array[Vector3] per leg
##   swinging: the leg in the air, or -1
##   bones: Array[Transform3D], the rigid frames the model rides on
##          (colossus_model.gd: 0 hub, then thigh, shin, foot per leg)
static func pose(def: RefCounted, route: RefCounted, minutes: float) -> Dictionary:
	var t := fposmod(minutes + float(route.offset), float(route.lap_minutes()))
	var feet: Array[Vector3] = []
	var yaws: Array[float] = []
	var swinging := -1
	for k in 3:
		var fs: Array = foot(def, route, k, t)
		feet.append(fs[0])
		yaws.append(fs[2])
		if float(fs[1]) >= 0.0:
			swinging = k
	var mid := (feet[0] + feet[1] + feet[2]) / 3.0
	var u := t / float(def.cycle_minutes)
	var heading: float = route.heading(u)
	# A slow roll at the stride's own period: the body settles onto each new foot.
	var roll := sin(u * TAU * 3.0) * float(def.sway)
	var hub := Transform3D(Basis(Vector3.UP, -heading), Vector3(mid.x, float(def.hip_height) + roll, mid.z))
	var hips: Array[Vector3] = []
	var knees: Array[Vector3] = []
	var ankles: Array[Vector3] = []
	var bones: Array[Transform3D] = [hub]
	for k in 3:
		var a := deg_to_rad(float(def.slots[k]))
		var hip := hub * (Vector3(cos(a), 0.0, sin(a)) * float(def.hip_ring))
		var ankle := feet[k] + Vector3(0.0, float(def.ankle_up), 0.0)
		var out := Vector3(ankle.x - hub.origin.x, 0.0, ankle.z - hub.origin.z)
		if out.length() < 1.0:
			out = hub.basis * Vector3(cos(a), 0.0, sin(a))
		var knee := knee_of(hip, ankle, float(def.thigh), float(def.shin), out.normalized() + Vector3.UP * 0.6)
		hips.append(hip)
		knees.append(knee)
		ankles.append(ankle)
		var outward := out.normalized()
		bones.append(segment(hip, knee, outward))
		bones.append(segment(knee, ankle, outward))
		# The foot stands upright, facing the way it was set down (`plant_yaw`).
		bones.append(Transform3D(Basis(Vector3.UP, -yaws[k]), ankle))
	return {"hub": hub, "hips": hips, "knees": knees, "ankles": ankles, "feet": feet,
		"yaws": yaws, "swinging": swinging, "bones": bones}


## Two-bone IK: the knee between `a` and `c` on bones of length `l1` and `l2`,
## bent toward `pole`. Out of reach it straightens toward the target, so the
## lengths are only ever broken by a pose the route should never ask for.
static func knee_of(a: Vector3, c: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var ac := c - a
	var d := clampf(ac.length(), absf(l1 - l2) + 1.0, l1 + l2 - 1.0)
	var axis := ac.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var side := (pole - axis * pole.dot(axis)).normalized()
	return a + axis * (l1 * cos_a) + side * (l1 * sqrt(maxf(0.0, 1.0 - cos_a * cos_a)))


## A rigid bone from `a` to `b`: origin at `a`, its Y along the bone, its X
## toward `outward` (so the panels of a leg face the same way on every leg), and
## a right-handed Z.
static func segment(a: Vector3, b: Vector3, outward: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var x := outward - y * outward.dot(y)
	if x.length() < 1e-4:
		x = Vector3.UP.cross(y)
	x = x.normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), a)


## Longest stretch of world time a frame may span and still fire its steps. A
## longer one is a skip (a night slept, a load), and a skip fires NOTHING: the
## player did not live through those footfalls, and forty of them arriving at
## once would be the world lying about what just happened.
const STEP_SKIP := 30.0


## Every foot that came down in (m0, m1], in order: {leg, minute, at}. Found by
## asking the clock, never latched, so a shot, a tour and a loaded game agree on
## when a foot lands and a frame can never fire one twice.
static func steps_between(def: RefCounted, route: RefCounted, m0: float, m1: float) -> Array:
	var out: Array = []
	if m1 <= m0 or m1 - m0 > STEP_SKIP:
		return out
	var cyc := float(def.cycle_minutes)
	var f: float = def.swing_share()
	var off := float(route.offset)
	for k in 3:
		# Swing j of leg k ends at cycle j + k/3 + f of the walk's own clock.
		var base := float(k) / 3.0 + f
		var j0 := ceili((m0 + off) / cyc - base)
		var j1 := floori((m1 + off) / cyc - base)
		for j in range(j0, j1 + 1):
			var minute := (float(j) + base) * cyc - off
			if minute > m0 and minute <= m1:
				out.append({"leg": k, "minute": minute, "at": plant(def, route, k, j)})
	out.sort_custom(_earlier)
	return out


## WHAT A LANDING DOES TO THE PERSON IT IS FELT BY, `d` metres off: (how far the
## picture moves, in world units, and for how many real seconds). A third of a
## unit at a kilometre, and it falls off with the LOG of distance so the looming
## walker fifty kilometres out is still felt in the chest; nothing past 150 km.
## The further off, the longer and slower the roll, as the ground spreads it.
const FELT_NEAR := 1000.0
const FELT_FAR := 150000.0
const FELT_MOST := 0.35
static func felt(d: float) -> Vector2:
	var x := clampf(log(maxf(d, FELT_NEAR) / FELT_NEAR) / log(FELT_FAR / FELT_NEAR), 0.0, 1.0)
	var strength := FELT_MOST * pow(1.0 - x, 0.7) if x < 1.0 else 0.0
	return Vector2(strength, lerpf(2.5, 5.0, x))


## Real seconds for a landing to reach the player through the ground (3 km/s) and
## through the air (343 m/s). Real, not world: they are what a body perceives.
static func ground_delay(d: float) -> float:
	return d / 3000.0


static func air_delay(d: float) -> float:
	return d / 343.0


## THE LEGS WHOSE SHADOW FALLS ON THE PLAYER'S GROUND, as tapered capsules
## [a, b, radius at a, radius at b] for sky.gdshaderinc `sky_colossus`: a shadow far too big for any
## shadow map, cast the way a cloud's is, by asking per fragment. `sun` is the
## way to the real sun; `around` the ground being drawn and `reach` how far
## round it. A capsule is kept only if its shadow on the ground (the leg carried
## down the sun's ray to sea level) passes within `reach` -- so the frame where
## nothing of theirs falls near hands over nothing, and that is nearly all of
## them. Nearest first, at most `SHADOW_MOST`.
const SHADOW_MOST := 8
static func shadow_capsules(def: RefCounted, p: Dictionary, sun: Vector3, around: Vector3, reach: float) -> Array:
	var out: Array = []
	if p.is_empty() or sun.y < 0.02:
		return out
	var parts: Array = []
	var hub: Transform3D = p.hub
	var tr: Vector2 = def.thigh_r
	var sr: Vector2 = def.shin_r
	# TAPERED, as the legs are: a shin is 800 m at the knee and 110 at the ankle,
	# and one mean radius drew the shadow of its foot end four times too wide --
	# a soft blot where a leg standing on the land throws a narrow, hard band.
	for k in 3:
		parts.append([p.hips[k], p.knees[k], tr.x, tr.y])
		parts.append([p.knees[k], p.ankles[k], sr.x, sr.y])
		# The foot: its drum, three hundred metres across and standing its own
		# height over the ground, and a toe down to each pad -- the shade a person
		# standing in a tread stands in (colossus_foot_model.gd has the shape).
		var ankle: Vector3 = p.ankles[k]
		var yaw: float = (p.yaws as Array)[k] if p.has("yaws") else 0.0
		parts.append([ankle + Vector3(0.0, -60.0, 0.0), ankle + Vector3(0.0, 4.0, 0.0), 150.0, 150.0])
		for toe in 3:
			var a := yaw + TAU * float(toe) / 3.0
			var dir := Vector3(cos(a), 0.0, sin(a))
			parts.append([ankle + dir * 66.0 + Vector3(0.0, -64.0, 0.0),
				ankle + dir * float(def.toe_reach) + Vector3(0.0, 12.0 - float(def.ankle_up), 0.0), 21.0, 18.0])
	var lo := hub.origin + Vector3(0.0, float(def.hub_low) - float(def.hip_height), 0.0)
	var hi := hub.origin + Vector3(0.0, float(def.hub_high) - float(def.hip_height), 0.0)
	parts.append([lo, hi, float(def.hub_radius) * 0.8, float(def.hub_radius) * 0.5])
	var scored: Array = []
	for c: Array in parts:
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var r: float = maxf(float(c[2]), float(c[3]))
		var ga := a - sun * (a.y / sun.y)
		var gb := b - sun * (b.y / sun.y)
		var g := Geometry2D.get_closest_point_to_segment(Vector2(around.x, around.z), Vector2(ga.x, ga.z), Vector2(gb.x, gb.z))
		var off := g.distance_to(Vector2(around.x, around.z))
		# A round leg's shadow on flat ground is stretched by the sun's slant.
		if off < reach + r / sun.y:
			scored.append([off, c])
	scored.sort_custom(_nearer)
	for i in mini(scored.size(), SHADOW_MOST):
		out.append(scored[i][1])
	return out


static func _nearer(a: Array, b: Array) -> bool:
	return float(a[0]) < float(b[0])


static func _earlier(a: Dictionary, b: Dictionary) -> bool:
	return float(a.minute) < float(b.minute)
