class_name AbilityMotion
extends RefCounted
## A move an ability takes over the body for a moment: a dash's burst, a glide
## off a ledge, a grapple's pull. Pure, so a test can run one to its end without
## a frame being drawn: `step` returns where the body is now and how far above
## the ground it is, and the gear system writes that onto the hero and the player.
##
## While one of these runs it owns the body's position, which is why it is the
## one place in the package that may put a body where walking could not take it
## (over a cliff, up a ledge). Nothing else moves the player.

const DONE_LIFT := 0.06
## A grapple's rope lifts the body over the lip it is pulling it onto.
const ARC := 0.35
## A glide steps off before the ground falls away: the wing takes this much
## height at the launch, so the run-up to the lip is not read as a landing.
const LAUNCH_LIFT := 0.5
## A glide over water or over something it cannot be set down on carries on past
## its own span for at most this long, looking for ground. It is enough to cross
## any river or inlet the world makes, and no more: whatever it cannot cross, the
## body is put back on the shore it left, and a short way back reads as a wing
## that did not make it where a long one would read as a teleport.
const OVERRUN := 2.5
## ...skimming this far above whatever is under it while it looks.
const SKIM := 0.5
## How far out a flight that has run out of everything will look for a tile to
## land on before falling back to the last good ground it passed over.
const LANDING_SEARCH := 8

var kind: StringName = &""
var dir := Vector2.ZERO
var speed := 0.0
## Longest it may run, real seconds: nothing here goes on forever.
var seconds := 0.0
## Grapple: where the line took hold, and how far short of it the body stops.
var to := Vector2.ZERO
var stop_short := 0.0
## Glide: world units of height lost per second.
var fall := 0.0
## The body's own height in the world while it is off the ground.
var height := 0.0
## Where it started, for the arc of a pull.
var from := Vector2.ZERO
var from_height := 0.0

## Grapple: the height at the anchor, so the pull rises onto the ledge.
var to_height := 0.0
## Jump: the whole arc, planned at the press (Jump.plan) and replayed here, so
## what is drawn and what a test measured are the same jump.
var plan: JumpPlan = null
## Climb: the whole climb, planned at the press (Climb.plan) and replayed here;
## and the level the body is at on the face now (FightSim.hero_level).
var climb: Climb.Plan = null
var at_level := -1

var t := 0.0
var lift := 0.0
## A glide has actually left the ground: the run-up to the lip is not a landing.
var flown := false
var finished := false
## The last tile the flight passed over that a body can stand on. A wing never
## sets anybody down in the sea, so when everything has run out this is where it
## puts them.
var landing := Vector2.ZERO


static func dash(direction: Vector2, p_speed: float, p_seconds: float) -> AbilityMotion:
	var m := AbilityMotion.new()
	m.kind = &"dash"
	m.dir = direction.normalized()
	m.speed = p_speed
	m.seconds = p_seconds
	return m


static func glide(at: Vector2, direction: Vector2, p_speed: float, p_fall: float, p_seconds: float, start_height: float) -> AbilityMotion:
	var m := AbilityMotion.new()
	m.kind = &"glide"
	m.from = at
	m.dir = direction.normalized()
	m.speed = p_speed
	m.fall = p_fall
	m.seconds = p_seconds
	m.height = start_height + LAUNCH_LIFT
	m.from_height = start_height
	# Whoever launches was standing somewhere: that is the landing of last resort
	# until the flight passes over better ground.
	m.landing = m.from
	return m


static func grapple(at: Vector2, target: Vector2, p_speed: float, short: float, start_height: float, end_height: float) -> AbilityMotion:
	var m := AbilityMotion.new()
	m.kind = &"grapple"
	m.from = at
	m.to = target
	m.dir = (target - at).normalized()
	m.speed = p_speed
	m.stop_short = short
	m.from_height = start_height
	m.height = start_height
	m.seconds = maxf(0.2, at.distance_to(target) / maxf(0.1, p_speed) + 0.3)
	m.to = target
	m.lift = 0.0
	m.finished = false
	m.t = 0.0
	m.to_height = end_height
	return m


static func jump(p: JumpPlan) -> AbilityMotion:
	var m := AbilityMotion.new()
	m.kind = &"jump"
	m.plan = p
	m.from = p.from
	m.to = p.to
	m.dir = p.dir
	m.seconds = p.seconds
	m.from_height = p.from_height
	m.to_height = p.to_height
	m.height = p.from_height
	m.landing = p.to
	return m


static func climb_face(p: Climb.Plan) -> AbilityMotion:
	var m := AbilityMotion.new()
	m.kind = &"climb"
	m.climb = p
	m.from = p.from
	m.to = p.on_face if p.slides else p.top
	m.dir = p.dir
	m.seconds = p.seconds
	m.from_height = p.from_height
	m.to_height = p.from_height if p.slides else p.top_height
	m.height = p.from_height
	m.at_level = p.from_level
	m.landing = m.to
	return m


## Move the body on by `delta`. Returns where it now is (tile space).
## A dash is refused by walls (it slides along them like walking does); a glide
## and a grapple pass over ground a walk could not climb, which is the point.
func step(delta: float, pos: Vector2, world: WorldData, query: WorldQuery, radius: float) -> Vector2:
	if finished:
		return pos
	t += delta
	var next := pos
	match kind:
		&"dash":
			next = query.move_body(pos, dir * speed * delta, radius) if query != null else pos + dir * speed * delta
			lift = 0.0
			if t >= seconds or next.distance_to(pos) < speed * delta * 0.15:
				finished = true
		&"glide":
			next = pos + dir * speed * delta
			var edge := world != null and not _inside(world, next)
			if edge:
				# Out of world: the flight ends here rather than off the edge.
				next = pos
			height -= fall * delta
			var ground := world.height_at(next) if world != null else 0.0
			lift = maxf(0.0, height - ground)
			flown = flown or lift > LAUNCH_LIFT * 0.5
			var ok := _standable(query, next)
			if ok:
				landing = next
			# A wing sets a body down on ground it can stand on, and nowhere else:
			# over open water it keeps flying, skimming, until there is something
			# under it. When even the overrun is spent it puts the body on the
			# nearest ground, or on the last it passed over. Never in the sea.
			if (flown and lift <= DONE_LIFT) or t >= seconds or edge:
				if ok:
					lift = 0.0
					finished = true
				elif t >= seconds + OVERRUN or edge:
					next = _ashore(world, query, next, landing)
					lift = 0.0
					finished = true
				else:
					height = maxf(height, ground + SKIM)
					lift = height - ground
		&"jump":
			# Replayed, never re-simulated: the arc was decided whole at the press,
			# and the body is where the plan says. `lift` is honest — the body's
			# height over the ground actually under it this instant — because the
			# shadow a lit world casts is placed from it.
			var here: Array = plan.at(t)
			next = here[0]
			height = float(here[1])
			var ground := world.height_at(next) if world != null else 0.0
			lift = maxf(0.0, height - ground)
			if t >= seconds:
				next = plan.to
				lift = 0.0
				finished = true
		&"climb":
			# Replayed like a jump: up the face at the foot, then over the lip onto
			# the top, or back down it when the breath ran out.
			var here: Array = climb.at(t)
			next = here[0]
			height = float(here[1])
			at_level = int(here[2])
			var ground := world.height_at(next) if world != null else 0.0
			lift = maxf(0.0, height - ground)
			if t >= seconds:
				next = to
				lift = 0.0
				at_level = -1
				finished = true
		&"grapple":
			var left := to.distance_to(pos)
			var stepped := speed * delta
			if left - stop_short <= stepped:
				next = to - dir * stop_short
				finished = true
			else:
				next = pos + dir * stepped
			var span := maxf(0.001, from.distance_to(to) - stop_short)
			var u := clampf(1.0 - maxf(0.0, left - stop_short) / span, 0.0, 1.0)
			var line := lerpf(from_height, to_height, u) + ARC * sin(PI * u)
			var ground := world.height_at(next) if world != null else 0.0
			height = maxf(line, ground)
			lift = maxf(0.0, height - ground)
			if t >= seconds:
				finished = true
			if finished:
				lift = 0.0
	return next


static func _inside(world: WorldData, p: Vector2) -> bool:
	return p.x >= 1.0 and p.y >= 1.0 and p.x <= world.size - 2.0 and p.y <= world.size - 2.0


## Without a query nothing is known about the ground, so a headless test's flight
## is allowed to end where it likes; in a game the water is what this is for.
static func _standable(query: WorldQuery, p: Vector2) -> bool:
	return query == null or query.standable(floori(p.x), floori(p.y))


## Ground to be set down on, nearest first, falling back to the last tile the
## flight passed over that a body could stand on.
static func _ashore(world: WorldData, query: WorldQuery, p: Vector2, last: Vector2) -> Vector2:
	if world == null or query == null:
		return p
	var cx := floori(p.x)
	var cy := floori(p.y)
	for r in range(1, LANDING_SEARCH + 1):
		var best := Vector2.INF
		var best_d := INF
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := Vector2(cx + dx + 0.5, cy + dy + 0.5)
				if not _inside(world, q) or not query.standable(cx + dx, cy + dy):
					continue
				var d := q.distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = q
		if best != Vector2.INF:
			return best
	return last
