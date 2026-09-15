class_name Fighter
extends RefCounted
## A body in the fight: the hero or a mob. Positions are tiles (float); time is
## the simulation's own milliseconds (FightSim.now), which runs with the one
## world clock but is never skipped by it.

var pos := Vector2.ZERO
## Radians. 0 = east (+x), PI/2 = south (+y).
var facing := 0.0
var radius := 0.28
var health := 1
var max_health := 1
var invuln_until := 0.0
var stun_until := 0.0
## The current throw (knockback): initial velocity decaying linearly to 0 at throw_until.
var throw_vel := Vector2.ZERO
var throw_from := 0.0
var throw_until := 0.0
## The blow being thrown (null = none) and when it was thrown.
var blow: Blow = null
var blow_at := -100000.0
## Bodies already struck by the current blow (one hit per target per blow).
var struck: Dictionary = {}
## Who hit this body last and when; for effects and outcome tolls. Only the
## hero keeps it: a mob pointing back at the hero would make a reference cycle.
var last_hit_by: Fighter = null
var last_hit_at := -100000.0
## Anything the view layer wants to hang on the body (its node). Untyped on purpose.
var node: Object = null


func alive_now() -> bool:
	return health > 0


func stunned(now: float) -> bool:
	return now < stun_until


func invulnerable(now: float) -> bool:
	return now < invuln_until


## Knockback along dir: `knock` tiles/s decaying to 0 over ms; also stuns for ms.
func throw(dir: Vector2, knock: float, ms: int, now: float, stun: bool = true) -> void:
	if knock <= 0.0 or ms <= 0:
		return
	throw_vel = dir.normalized() * knock
	throw_from = now
	throw_until = now + ms
	if stun:
		stun_until = maxf(stun_until, now + ms)


func throw_velocity(now: float) -> Vector2:
	if now >= throw_until:
		return Vector2.ZERO
	var k := 1.0 - (now - throw_from) / maxf(1.0, throw_until - throw_from)
	return throw_vel * clampf(k, 0.0, 1.0)


## Phase of the current blow at `now` (&"" when none or over).
func blow_phase(now: float) -> StringName:
	if blow == null:
		return &""
	return blow.phase(now - blow_at)


## Locked into a blow: facing fixed, movement x creep.
func committed(now: float) -> bool:
	return blow != null and now - blow_at < blow.committed()


func locked_out(now: float) -> bool:
	return blow != null and now - blow_at < blow.lockout()


func start_blow(b: Blow, now: float) -> void:
	blow = b
	blow_at = now
	struck.clear()
