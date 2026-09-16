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

var t := 0.0
var lift := 0.0
var finished := false


static func dash(direction: Vector2, p_speed: float, p_seconds: float) -> AbilityMotion:
	var m := AbilityMotion.new()
	m.kind = &"dash"
	m.dir = direction.normalized()
	m.speed = p_speed
	m.seconds = p_seconds
	return m


static func glide(direction: Vector2, p_speed: float, p_fall: float, p_seconds: float, start_height: float) -> AbilityMotion:
	var m := AbilityMotion.new()
	m.kind = &"glide"
	m.dir = direction.normalized()
	m.speed = p_speed
	m.fall = p_fall
	m.seconds = p_seconds
	m.height = start_height
	m.from_height = start_height
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
			if world != null and not _inside(world, next):
				next = pos
				finished = true
			height -= fall * delta
			var ground := world.height_at(next) if world != null else 0.0
			lift = maxf(0.0, height - ground)
			if lift <= DONE_LIFT or t >= seconds:
				lift = 0.0
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
