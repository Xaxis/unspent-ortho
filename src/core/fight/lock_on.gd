class_name LockOn
## WHAT A LOCK DOES TO THE BODY (owner, 2026-09-24: "it needs to lock the
## player's movement so they are facing the target they are locked onto", in
## both views). docs/CONTROLS.md §Lock-on says why each rule is the one chosen;
## this file is the rules, pure, so a test can hold every one without a scene.
##
##   intent(...)   the keys as a direction in the world: over the shoulder the
##                 line to the target is forward; from above the screen is
##   face(...)     the body turned toward the target at TURN a second
##   dodge_way(...) where a dodge goes: the keys, else straight back from it
##
## The target is a point in tile space, or `Vector2.INF` for no lock. Every
## function answers exactly what it did before the lock existed when handed INF,
## so a player who never holds the key plays the game they always played.

## How fast the body comes round onto the target (radians a second): quick enough
## that a lock taken mid-stride reads as a turn and not a snap, slow enough that
## a lock cycled to a body behind you is seen swinging round.
const TURN := 14.0
## Closer than this the line to the target has no direction worth trusting: the
## body keeps whatever facing it had instead of spinning on the spot.
const NEAR := 0.35
## How long the body keeps turning at TURN after a lock is let go, instead of
## snapping to the way it is walking (ms of the fight's own clock).
const RELEASE_MS := 260.0


## The keys (screen-relative, x right, y down, as `Input.get_vector` gives them)
## as a direction in tile space. Over the shoulder a lock makes the line to the
## target the forward axis: up closes, down retreats, left and right circle.
## From above the keys stay the screen's, because the camera there does not turn
## to put the target up the screen, and a key that meant a different screen
## direction depending on where the target stood would contradict the picture.
static func intent(input: Vector2, yaw_deg: float, from: Vector2, target: Vector2,
		target_relative: bool) -> Vector2:
	if not locked(target) or not target_relative:
		return Player.screen_to_world(input, yaw_deg)
	var to := target - from
	if to.length() < NEAR:
		return Player.screen_to_world(input, yaw_deg)
	var fwd := to.normalized()
	# Right of the line to the target, with y south: the forward vector turned a
	# quarter clockwise on the screen.
	var right := Vector2(-fwd.y, fwd.x)
	return right * input.x + fwd * -input.y


## The keys that `intent` reads as `dir`: its inverse, for anything that holds
## keys to walk a WORLD way (a tour steering, a bot), so it goes where it meant
## under whichever view and lock the game is in.
static func keys_for(dir: Vector2, yaw_deg: float, from: Vector2, target: Vector2,
		target_relative: bool) -> Vector2:
	var fwd := Vector2.ZERO
	if locked(target) and target_relative and (target - from).length() >= NEAR:
		fwd = (target - from).normalized()
	else:
		var yaw := deg_to_rad(yaw_deg)
		fwd = Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-fwd.y, fwd.x)
	return Vector2(dir.dot(right), -dir.dot(fwd))


## The facing turned toward the target, at most `TURN * dt`.
static func face(facing: float, from: Vector2, target: Vector2, dt: float) -> float:
	if not locked(target):
		return facing
	var to := target - from
	if to.length() < NEAR:
		return facing
	return FightSim.rotate_toward(facing, to.angle(), TURN * dt)


## Where a dodge goes under a lock: the way the keys point, or with no key held
## straight back from the target -- the facing is the target's, so "back" and
## "away from it" are one direction and the dodge can never roll into it.
static func dodge_way(move: Vector2, from: Vector2, target: Vector2, facing: float) -> Vector2:
	if move.length() > 0.1:
		return move
	if locked(target) and (from - target).length() >= NEAR:
		return (from - target).normalized()
	return -Vector2.from_angle(facing)


static func locked(target: Vector2) -> bool:
	return target.is_finite()
