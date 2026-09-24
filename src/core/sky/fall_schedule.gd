extends RefCounted
## WHEN THE WRECK COMES DOWN, as a pure function of the seed and the world clock:
## the fractured platform (src/core/orbit/) sheds pieces, and they burn through
## the sky over the island (the orbit design, section 2). Falls IN THE SKY only
## -- nothing here lands; a fall in the world is its own schedule.
##
## THE CLOCK IS CUT INTO BUCKETS of BUCKET world minutes. Each bucket deals
## SLOTS chances by hash, each at its own minute in the bucket, and a chance is
## a fall when a second hash is under the rate at that minute -- so a fall is a
## fact about its minute, found the same way whatever frames the clock was cut
## into, and `between` never fires one twice or loses one on a frame's edge.
##
## THE RATE CROWDS ROUND THE PASSES: RATE falls a world hour times
## (FLOOR + LIFT * wake), `wake` 1 while the ring is up and dying away over
## WAKE_TAIL minutes either side, because the wound sheds along its own track.
##
## ONE RADIANT: every piece comes in along the orbit's own heading
## (OrbitPass.heading) dipping at the world's one entry angle, within SPREAD
## degrees -- so traced back, every streak on one night meets at one point of the
## sky, the way a real shower's do.
##
## Everything is in the observer's frame and in KILOMETRES (x east, y up,
## z south), like the orbit: the few kilometres the player walks are nothing
## against a fall eighty up and three hundred off, so the sky is the same sky
## everywhere on the island. The planet's curve is the drawing's business
## (streak.gdshader drops a far path below the horizon as the colossi's is).
##
## No class_name (reached by path).

const Pass := preload("res://src/core/orbit/orbit_pass.gd")
const Rumble := preload("res://src/core/sky/rumble.gd")

const BUCKET := 30.0
const SLOTS := 6
## A frame longer than this (world minutes) is a skip -- a night slept, a load,
## a tour's `hour` -- and fires nothing (as colossus_walk.gd STEP_SKIP).
const SKIP := 30.0
## Falls a world hour far from any pass (RATE * FLOOR) and under one
## (RATE * (FLOOR + LIFT)).
const RATE := 0.8
const FLOOR := 0.35
const LIFT := 1.65
const WAKE_TAIL := 150.0
## Degrees off the radiant a fall's heading may stand.
const SPREAD := 8.0
## The world's entry angle below the horizontal, degrees (least, most).
const DIP := Vector2(8.0, 18.0)
## How far off a fall's ANCHOR stands over the ground, km -- where it breaks up,
## or the middle of a dust streak's path (`anchor_s`): dust and
## fragments over the whole sky, log-uniform (near ones rarer, as the ground
## under a patch of sky grows with its distance); a mass only near enough for
## its boom to arrive while the sky still holds its train.
const RANGE := Vector2(30.0, 850.0)
const MASS_RANGE := Vector2(10.0, 40.0)
## Shares of the classes: 70% dust, 25% fragment, 5% mass.
const DUST_SHARE := 0.70
const FRAGMENT_SHARE := 0.95

const KINDS: Array[StringName] = [&"dust", &"fragment", &"mass"]

const SALT_SLOT := 88101
const SALT_KEEP := 88102
const SALT_KIND := 88103
const SALT_DIP := 88104
const SALT_SHAPE := 88105


## How near the ring's track the clock is, 0..1: 1 while a pass is up, dying
## away over WAKE_TAIL minutes either side of its window.
static func wake(def: RefCounted, seed_value: int, minutes: float) -> float:
	var period := Pass.period_min(def)
	var window := Pass.window_min(def)
	var ph := Pass.phase(def, seed_value)
	var k := floori((minutes - ph) / period)
	var best := 0.0
	for j in range(k - 1, k + 2):
		var rise := ph + float(j) * period
		var gap := maxf(maxf(rise - minutes, minutes - (rise + window)), 0.0)
		best = maxf(best, exp(-gap / WAKE_TAIL))
	return best


## Falls a world hour at `minutes`.
static func rate_at(def: RefCounted, seed_value: int, minutes: float) -> float:
	return RATE * (FLOOR + LIFT * wake(def, seed_value, minutes))


## Where every fall comes in from: a unit direction up into the sky, back along
## the orbit's heading at the world's entry angle.
static func radiant(seed_value: int) -> Vector3:
	return -_heading(seed_value, 0.0, 0.0)


## The world's entry angle, degrees.
static func dip(seed_value: int) -> float:
	return lerpf(DIP.x, DIP.y, Rng.hash01(seed_value, SALT_DIP))


## A unit direction of travel: the orbit's heading turned `yaw` degrees, dipping
## the world's angle plus `down` degrees.
static func _heading(seed_value: int, yaw: float, down: float) -> Vector3:
	var h := deg_to_rad(Pass.heading(seed_value) + yaw)
	var e := deg_to_rad(dip(seed_value) + down)
	return Vector3(cos(h) * cos(e), -sin(e), sin(h) * cos(e))


## Every fall that BEGINS in (m0, m1], in the clock's order. Nothing across a
## skip, nothing for a clock put back.
static func between(def: RefCounted, seed_value: int, m0: float, m1: float) -> Array:
	var out: Array = []
	if m1 <= m0 or m1 - m0 > SKIP:
		return out
	for b in range(floori(m0 / BUCKET), floori(m1 / BUCKET) + 1):
		for s in SLOTS:
			var minute := (float(b) + Rng.hash01(seed_value, SALT_SLOT, b, s)) * BUCKET
			if minute <= m0 or minute > m1:
				continue
			var keep := rate_at(def, seed_value, minute) * BUCKET / 60.0 / float(SLOTS)
			if Rng.hash01(seed_value, SALT_KEEP, b, s) >= keep:
				continue
			out.append(_make(seed_value, b * SLOTS + s, minute, _kind_of(Rng.hash01(seed_value, SALT_KIND, b, s))))
	out.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a.minute) < float(c.minute))
	return out


static func _kind_of(h: float) -> StringName:
	if h < DUST_SHARE:
		return &"dust"
	if h < FRAGMENT_SHARE:
		return &"fragment"
	return &"mass"


## Fall `id` of class `kind` at `minute`: its whole shape from hashes of its id.
##   dir          unit direction of travel
##   range_km     its anchor (`anchor_s`) over the ground, from the observer
##   azimuth      degrees (0 east, 90 south) to that anchor
##   entry_km / break_km / end_km   heights it lights up, breaks up, goes out
##   secs         real seconds from lighting up to going out
##   train_secs   real seconds the train it leaves still shows
##   pieces       how many it breaks into (0: dust does not)
##   shape        a seed for everything the drawing deals by hash
static func _make(seed_value: int, id: int, minute: float, kind: StringName) -> Dictionary:
	var r := func(i: int) -> float: return Rng.hash01(seed_value, SALT_SHAPE, id, i)
	var yaw := (float(r.call(0)) - 0.5) * 2.0 * 6.0
	var down := (float(r.call(1)) - 0.5) * 2.0 * 4.0
	var span := MASS_RANGE if kind == &"mass" else RANGE
	var range_km := span.x * pow(span.y / span.x, float(r.call(2)))
	var f := {"id": id, "minute": minute, "kind": kind, "dir": _heading(seed_value, yaw, down),
		"range_km": range_km, "azimuth": float(r.call(3)) * 360.0, "shape": int(float(r.call(4)) * 1e6)}
	_heights(f, r)
	return f


static func _heights(f: Dictionary, r: Callable) -> void:
	match f.kind:
		&"dust":
			f.entry_km = lerpf(98.0, 110.0, float(r.call(5)))
			f.end_km = lerpf(78.0, 90.0, float(r.call(6)))
			f.break_km = f.end_km
			f.secs = lerpf(0.6, 1.4, float(r.call(7)))
			f.train_secs = lerpf(0.8, 2.0, float(r.call(8)))
			f.pieces = 0
		&"fragment":
			f.entry_km = lerpf(105.0, 115.0, float(r.call(5)))
			f.end_km = lerpf(35.0, 48.0, float(r.call(6)))
			f.break_km = lerpf(56.0, 72.0, float(r.call(7)))
			f.secs = lerpf(3.5, 6.0, float(r.call(8)))
			f.train_secs = lerpf(40.0, 110.0, float(r.call(9)))
			f.pieces = 3 + mini(3, int(float(r.call(10)) * 4.0))
		_:
			f.entry_km = lerpf(110.0, 118.0, float(r.call(5)))
			f.end_km = lerpf(20.0, 28.0, float(r.call(6)))
			f.break_km = lerpf(38.0, 48.0, float(r.call(7)))
			f.secs = lerpf(7.0, 11.0, float(r.call(8)))
			f.train_secs = lerpf(90.0, 180.0, float(r.call(9)))
			f.pieces = 3 + mini(3, int(float(r.call(10)) * 4.0))


## The point `s` of the way along a fall's lit path (0 where it lights up, 1
## where it goes out), km from the observer.
static func point(f: Dictionary, s: float) -> Vector3:
	var d: Vector3 = f.dir
	var a := anchor_s(f)
	var h := lerpf(float(f.entry_km), float(f.end_km), a)
	var az := deg_to_rad(float(f.azimuth))
	var at := Vector3(cos(az) * float(f.range_km), h, sin(az) * float(f.range_km))
	return at + d * (s - a) * path_km(f)


## The share of the path a fall is placed by: where it breaks up (the moment
## the eye is drawn to), or the middle of a dust streak.
static func anchor_s(f: Dictionary) -> float:
	return break_s(f) if int(f.pieces) > 0 else 0.5


## The lit path's length, km.
static func path_km(f: Dictionary) -> float:
	return (float(f.entry_km) - float(f.end_km)) / maxf(-(f.dir as Vector3).y, 0.05)


## The share of the path at which it breaks up (1 for dust, which does not).
static func break_s(f: Dictionary) -> float:
	var e: float = f.entry_km
	return clampf((e - float(f.break_km)) / maxf(e - float(f.end_km), 0.01), 0.0, 1.0)


## Real seconds from its lighting up until a mass fall's boom reaches the
## observer. The shock comes off the whole of the flight where the air is thick
## enough to carry one (under BOOM_UNDER km), a line of sound; what is heard
## first is the nearest point of it, carried at the air's speed
## (src/core/sky/rumble.gd AIR_SPEED) from the moment the fall passed it.
const BOOM_UNDER := 50.0
const BOOM_STEPS := 48


static func boom_secs(f: Dictionary) -> float:
	var best := INF
	for i in BOOM_STEPS + 1:
		var s := float(i) / float(BOOM_STEPS)
		var p := point(f, s)
		if p.y > BOOM_UNDER:
			continue
		best = minf(best, s * float(f.secs) + p.length() * 1000.0 / Rumble.AIR_SPEED)
	return best


## ONE FALL STAGED BY NAME (`--fall=CLASS@MINUTE[/BEARING]`): the class asked
## for, lighting up at `minute`, its path's middle on `bearing` and crossing the
## view (its heading square to the bearing, not the radiant's), at a range that
## shows the class whole.
const STAGED_RANGE := {&"dust": 90.0, &"fragment": 150.0, &"mass": 32.0}


static func staged(_def: RefCounted, seed_value: int, kind: StringName, minute: float, bearing: float) -> Dictionary:
	var f := _make(seed_value, -1, minute, kind)
	var h := deg_to_rad(bearing + 90.0)
	var e := deg_to_rad(dip(seed_value))
	f.dir = Vector3(cos(h) * cos(e), -sin(e), sin(h) * cos(e))
	f.azimuth = bearing
	f.range_km = float(STAGED_RANGE[kind])
	# Mid values, so the staged one is the class's typical fall.
	var mid := func(_i: int) -> float: return 0.5
	_heights(f, mid)
	f.staged = true
	return f


## "CLASS@AT[/BEARING]" -> {kind, at, bearing (NAN when not given)}, or {} for a
## class there is not.
static func parse_stage(spec: String) -> Dictionary:
	var parts := spec.split("@")
	var kind := StringName(parts[0])
	if not KINDS.has(kind):
		return {}
	var tail := parts[1] if parts.size() > 1 else "0"
	var bearing := NAN
	if tail.contains("/"):
		bearing = tail.split("/")[1].to_float()
		tail = tail.split("/")[0]
	return {"kind": kind, "at": tail.to_float(), "bearing": bearing}


## ---------------------------------------------------------------------------
## A FALL'S SHAPE OVER ITS LIFE, as a pure function of the fall and its AGE --
## real seconds since it lit up. streak.gdshader mirrors the motion (`head_s`,
## `time_at`, `piece_x`, `piece_tau_at`, named the same there); the brightnesses
## are worked out here and handed over, so there is one curve.

const SALT_PIECE := 88106
## How far a piece slows over its life, as a share of its speed.
const PIECE_SLOW := 0.7


## Real seconds from lighting up until the last of its train is gone.
static func life_secs(f: Dictionary) -> float:
	return float(f.secs) + float(f.train_secs)


## How far along its path the head is at share `t` of its flight: slowing as the
## air thickens (a sixth slower at the end than at the start).
static func head_s(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return 1.2 * x - 0.2 * x * x


## The inverse: the share of its flight at which the head passed `s`.
static func time_at(s: float) -> float:
	return (1.2 - sqrt(maxf(1.44 - 0.8 * clampf(s, 0.0, 1.0), 0.0))) / 0.4


## Real seconds from lighting up to the breakup (the whole flight for dust).
static func break_secs(f: Dictionary) -> float:
	return time_at(break_s(f)) * float(f.secs)


## THE PIECES a fragment or a mass breaks into, each flung off its line by a few
## degrees, a little slower than the body was going, burning out on its own
## clock. The first is the biggest (a mass keeps on as it, nearly on its line).
##   dir       unit direction, km frame
##   speed     km a real second at the breakup
##   life      real seconds it burns
##   share     how bright it is against the body at the breakup
##   spin      its tumble, for the flicker
static func pieces_of(f: Dictionary) -> Array:
	var out: Array = []
	var n := int(f.pieces)
	if n <= 0:
		return out
	var d: Vector3 = f.dir
	var side := d.cross(Vector3.UP).normalized()
	var up := side.cross(d).normalized()
	var tb := break_secs(f)
	var secs: float = f.secs
	var v := path_km(f) * (1.2 - 0.4 * tb / secs) / secs
	var mass: bool = f.kind == &"mass"
	var sid: int = f.shape
	for i in n:
		var h := func(k: int) -> float: return Rng.hash01(sid, SALT_PIECE, i, k)
		var turn := float(h.call(0)) * TAU
		var spread := lerpf(0.6, 2.5, float(h.call(1))) if mass else lerpf(1.5, 5.0, float(h.call(1)))
		if i == 0:
			spread *= 0.3
		var off := (side * cos(turn) + up * sin(turn)) * tan(deg_to_rad(spread))
		out.append({"dir": (d + off).normalized(), "speed": v * lerpf(0.75, 1.0, float(h.call(2))),
			"life": (secs - tb) * lerpf(0.5, 1.15, float(h.call(3))) * (1.25 if i == 0 else 1.0),
			"share": 1.0 if i == 0 else lerpf(0.35, 0.8, float(h.call(4))),
			"spin": lerpf(7.0, 19.0, float(h.call(5)))})
	return out


## How far a piece has gone `tau` real seconds after the breakup, km.
static func piece_x(p: Dictionary, tau: float) -> float:
	var t := clampf(tau, 0.0, float(p.life))
	var dec := float(p.speed) * PIECE_SLOW / float(p.life)
	return float(p.speed) * t - 0.5 * dec * t * t


## The inverse: seconds after the breakup at which the piece passed `x` km.
static func piece_tau_at(p: Dictionary, x: float) -> float:
	var v: float = p.speed
	var dec := v * PIECE_SLOW / float(p.life)
	return (v - sqrt(maxf(v * v - 2.0 * dec * x, 0.0))) / dec


## THE HEAD'S LIGHT at `age`, about 1 at a class's usual best: dust swells and
## flares at the end; a fragment or a mass brightens into the thicker air until
## it breaks, and then it is its pieces.
static func head_level(f: Dictionary, age: float) -> float:
	var secs: float = f.secs
	if age < 0.0:
		return 0.0
	if int(f.pieces) <= 0:
		var t := age / secs
		if t > 1.0:
			return 0.0
		return pow(sin(PI * t), 0.8) + 0.5 * exp(-pow((t - 0.82) / 0.07, 2.0))
	var tb := break_secs(f)
	if age > tb:
		return 0.0
	var u := age / tb
	return smoothstep(0.0, 0.25, u) * (0.35 + 0.65 * u)


## THE BREAKUP'S FLASH at `age`: a hard white burst a fifth of a second long and
## a softer glow under it that lasts a second.
static func flash_level(f: Dictionary, age: float) -> float:
	if int(f.pieces) <= 0:
		return 0.0
	var tau := age - break_secs(f)
	if tau < 0.0:
		return 0.0
	return 3.0 * exp(-tau / 0.22) + 0.6 * exp(-tau / 1.2)


## Piece `p`'s light at `age`, against the body's at the breakup: dimming as it
## burns out, flickering as it tumbles.
static func piece_level(f: Dictionary, p: Dictionary, age: float) -> float:
	var tau := age - break_secs(f)
	var life: float = p.life
	if tau < 0.0 or tau > life:
		return 0.0
	return float(p.share) * pow(1.0 - tau / life, 1.3) * (0.75 + 0.25 * sin(tau * float(p.spin)))


## HOW MUCH LIGHT THE FALL GIVES at `age`, before distance: the head, the
## flash and the pieces.
static func glow(f: Dictionary, pieces: Array, age: float) -> float:
	var g := head_level(f, age) + flash_level(f, age)
	for p: Dictionary in pieces:
		g += piece_level(f, p, age)
	return g


## Where the fall's light is coming from at `age`, km from the observer: the
## head until the breakup, then the biggest piece.
static func light_at(f: Dictionary, pieces: Array, age: float) -> Vector3:
	var tb := break_secs(f)
	if pieces.is_empty() or age <= tb:
		return point(f, head_s(age / float(f.secs)))
	var p: Dictionary = pieces[0]
	return point(f, break_s(f)) + (p.dir as Vector3) * piece_x(p, age - tb)
