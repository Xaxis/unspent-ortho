extends RefCounted
## THE VIEW OVER THE SHOULDER, as rules (owner, 2026-09-23: "switch to true third
## person perspective (see from behind the players shoulder) ... seamless just
## like targeting ... a key that player has to hold down along with a perfectly
## integrated setting ... see parts of the sky and the horizon").
##
## Pure: numbers in, numbers out, nothing about a node. `CameraRig` draws the view
## from these and `41_shoulder` drives it; both reach this file through a
## `preload`, never a class_name, so a pull that has not refreshed the import
## cache cannot make the camera fail to parse.
##
## THE POSE. The eye stands `BACK` behind a point `FOCUS_UP` over the player's
## feet and `RIGHT` to their right, looking at it down `PITCH`. That puts the
## player left of the middle of the frame with the ground they are walking to in
## the middle, and at 10 degrees down under a 60-degree field the top of the
## frame is 20 degrees ABOVE the horizon: sky and the far land are in every frame,
## which is the whole of what the owner asked the view for.

## World units back from the focus along the view axis. 4.2 rather than the 3.6
## it opened with, judged on frames at noon, dusk and night on the coast and in
## the pinewood: at 3.6 the player took the lower middle of the frame and the
## ground they walk toward began behind them; at 4.2 they still read at night and
## the land they are walking into has the room.
const BACK := 4.2
## The focus: over the feet by this much (a chest, not a head, so the player's
## own head sits in the upper-middle of the frame instead of under its top edge).
const FOCUS_UP := 1.25
## To the right of the player, so the body is beside the middle and not in it.
const RIGHT := 0.62
## Degrees down.
const PITCH := 10.0
## Vertical field of view, degrees.
const FOV := 60.0
## How far the mouse may tip the view: up to look at the sky, down to look at the
## ground at the feet. Past `PITCH_MOST` the view is the lens again with a worse
## angle; past `PITCH_LEAST` the player is under the bottom edge.
const PITCH_LEAST := -14.0
const PITCH_MOST := 42.0
## THE GAZE: how far up the view may tip while a colossus stands in front of it
## (19_colossi `gaze`, 0..1). A walker fifty kilometres off has its hub 45
## degrees up, and at -14 the player sees two legs going up out of the frame and
## never the machine; at -45 the top of the frame is 75 degrees up and the whole
## of it stands there. The player goes under the bottom edge to see it, which is
## exactly what looking up at something that size is.
const GAZE_LEAST := -45.0
## Degrees a second the view comes back down to `PITCH_LEAST` once nothing
## holds the gaze any more, eased by how far it has to come: never a snap.
const GAZE_RETURN := 25.0
## Degrees of turn per SCREEN pixel of mouse travel (the hand's, not the
## viewport's: the same hand turns the view the same way at any window size).
const MOUSE_DEG := 0.14

## Seconds the glide takes, each way, eased at both ends. Long enough that the
## eye can follow the camera coming down off its perch, short enough that a
## held key is an answer and not a wait.
const BLEND_SECS := 0.36

## Behind the player's facing again, once the mouse has been left alone this long
## and the player is walking AWAY from the camera. Per second, scaled by how much
## of the walk is away: a strafe does not swing the camera and a walk back toward
## it does not spin it round.
const FOLLOW_IDLE := 0.9
const FOLLOW_RATE := 1.7

## A lock (42_target) turns the view onto what it holds at this rate.
const LOCK_RATE := 6.0

## THE CAMERA MAY NOT GO INTO THE LAND OR A HOUSE (docs/LOOK.md law 3: "The land
## itself never opens"). The line from the player's head to where the eye wants
## to stand is walked in `STEPS` steps; the first one that is under the ground,
## or inside something that stops a body and stands higher than the step, is
## where the eye stops, less a step. `CLEAR` is the room kept round the eye so
## the near plane never slices the thing it stopped at.
const HEAD_UP := 1.45
const STEPS := 28
const CLEAR := 0.3
## Never nearer the head than this: a camera inside the skull draws the inside of
## the face, which is worse than a camera in a wall.
const LEAST_BACK := 0.55
## Eased back out at this rate per second when the way is clear again; pulled in
## at once, because a frame drawn from inside a hill is the failure and a camera
## that pulls in quickly is not.
const ROOM_OUT := 3.0

## The near and far clip planes under the view. Near is small because a pulled-in
## camera is half a unit from the head; far is where the horizon's land ends,
## named here so the world streamed round the player can be tuned TO it.
const NEAR := 0.12
const FAR := 1400.0


## A smoothstep of the blend's own linear clock: no corner at either end.
static func smooth(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The most of the glide one frame may take: a frame at 30 Hz. At any rate a
## player plays at the glide keeps real time; a longer frame (a stall, a loaded
## machine) moves it one step and not to the end, which was a pop.
const STEP_MOST := 1.0 / 30.0


## One frame of the linear clock toward `want` (0 top, 1 over the shoulder).
static func blend_step(t: float, want: bool, delta: float) -> float:
	var by := minf(delta, STEP_MOST) / BLEND_SECS
	return clampf(t + by if want else t - by, 0.0, 1.0)


## Which view is asked for: the player's standing choice, flipped while the key
## is held (or latched). A player who starts over the shoulder holds the key to
## look down on the land, which is the same gesture read the other way round.
static func wanted(start_shoulder: bool, key_on: bool) -> bool:
	return start_shoulder != key_on


## The screen's "up" on the ground, for a camera at `yaw_deg`: the same axes
## `Player.screen_to_world` walks by, so a key and the camera cannot disagree.
static func forward(yaw_deg: float) -> Vector2:
	var y := deg_to_rad(yaw_deg)
	return Vector2(-sin(y), -cos(y))


## The yaw that looks along a ground direction.
static func yaw_along(dir: Vector2) -> float:
	return rad_to_deg(atan2(-dir.x, -dir.y))


## The yaw that stands behind a body facing `facing` (radians, tile space).
static func yaw_behind(facing: float) -> float:
	return yaw_along(Vector2.from_angle(facing))


## The facing a swing takes under this view: where the camera looks.
static func aim_of(yaw_deg: float) -> float:
	return forward(yaw_deg).angle()


## Degrees from `from` to `to`, the short way.
static func turn(from: float, to: float) -> float:
	return wrapf(to - from, -180.0, 180.0)


## How much of a walk is AWAY from the camera, 0..1.
static func away_share(move: Vector2, yaw_deg: float) -> float:
	if move.length() < 0.05:
		return 0.0
	return maxf(0.0, move.normalized().dot(forward(yaw_deg)))


## The yaw after one frame of easing in behind a walking player, or unchanged
## while the mouse has been used lately or nobody is walking away from it.
static func follow_yaw(yaw_deg: float, facing: float, move: Vector2, idle_s: float, delta: float) -> float:
	if idle_s < FOLLOW_IDLE:
		return yaw_deg
	var share := away_share(move, yaw_deg)
	if share <= 0.0:
		return yaw_deg
	var k := 1.0 - exp(-FOLLOW_RATE * share * delta)
	return yaw_deg + turn(yaw_deg, yaw_behind(facing)) * k


## The mouse, turned into a yaw and a pitch. `rel` is in screen pixels, right and
## down positive; right turns right (yaw DOWN, Godot's yaw is anticlockwise), down
## looks down.
## `least` is how far up it may go now (`least_for`): the gaze lets it further.
## A pitch already past `least` (the gaze has just let go) is never pulled back
## by the mouse, only held there -- `settle` brings it down.
static func look(yaw_deg: float, pitch_deg: float, rel: Vector2, least := PITCH_LEAST) -> Vector2:
	return Vector2(yaw_deg - rel.x * MOUSE_DEG,
		clampf(pitch_deg + rel.y * MOUSE_DEG, minf(least, pitch_deg), PITCH_MOST))


## How far up the view may tip with `gaze` (0..1) of a colossus in front of it.
static func least_for(gaze: float) -> float:
	return lerpf(PITCH_LEAST, GAZE_LEAST, smoothstep(0.0, 1.0, clampf(gaze, 0.0, 1.0)))


## A pitch tipped further up than `least` allows comes back down to it over
## time, fastest when furthest out, so losing the gaze eases the view home.
static func settle(pitch_deg: float, least: float, delta: float) -> float:
	if pitch_deg >= least:
		return pitch_deg
	var step := GAZE_RETURN * delta * clampf((least - pitch_deg) / 10.0, 0.2, 1.0)
	return minf(least, pitch_deg + step)


## Whether the pointer should be held by the game: only while the view is over
## the shoulder, the keys are the game's (no page, no conversation), the window
## has the player's attention, and the run is a PERSON playing -- a shot or a
## tour must never take the pointer from whoever is at the machine.
static func capture(shoulder: bool, blocked: bool, tool_run: bool, focused: bool) -> bool:
	return shoulder and not blocked and not tool_run and focused


## HOW FAR THE EYE MAY STAND from the head along the line to where it wants to be,
## as a share 0..1 of that line.
##
## `ground` answers the drawn height of the land under a tile point. `solids` are
## what stops a body, as (x, z, radius, top) in tile space and world height:
## a house is its footprint up to its roof, a tower its mass up to the sky. A
## point is blocked when it is under the land, or inside a solid's circle (grown
## by CLEAR) below its top.
static func room(head: Vector3, eye: Vector3, ground: Callable, solids: Array[Vector4]) -> float:
	var span := head.distance_to(eye)
	if span < 0.001:
		return 1.0
	var least := minf(1.0, LEAST_BACK / span)
	var clear := 0.0
	for i in range(1, STEPS + 1):
		var t := float(i) / float(STEPS)
		var q := head.lerp(eye, t)
		if _blocked(q, ground, solids):
			# One step short of the first blocked point, and CLEAR short of that.
			return maxf(least, clear - CLEAR / span)
		clear = t
	return 1.0


static func _blocked(q: Vector3, ground: Callable, solids: Array[Vector4]) -> bool:
	if float(ground.call(Vector2(q.x, q.z))) + CLEAR > q.y:
		return true
	for s: Vector4 in solids:
		var dx := q.x - s.x
		var dz := q.z - s.y
		var r := s.z + CLEAR
		if dx * dx + dz * dz < r * r and q.y < s.w + CLEAR:
			return true
	return false
