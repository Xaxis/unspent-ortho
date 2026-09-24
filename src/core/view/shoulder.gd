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
## Under a lock the eye stands this far right instead of `RIGHT`, and it aims
## from there: looking from the head, the player's own back stood square in
## front of what was locked and hid it (lockon_top.tour frame 07, 2026-09-24).
## From a shoulder this wide what is held sits clear of the body at any range a
## lock is taken at, and the pair are framed together, the player left of centre.
const LOCK_RIGHT := 1.15

## THE CAMERA MAY NOT GO INTO THE LAND OR A HOUSE (docs/LOOK.md law 3: "The land
## itself never opens"). The line from the point it looks at (over the right
## shoulder) back to where the eye wants to stand is walked in `STEPS` steps; the
## first one that is under the ground, or inside something that stops a body and
## stands higher than the step, is where the eye stops, less a step. `CLEAR` is
## the room kept round the eye so the near plane never slices the thing it
## stopped at.
##
## The line runs from the SHOULDER POINT, not the head, so a pulled-in eye comes
## in along the very line it looks down: the frame keeps its aim and the head
## stays off to the left of it. Walked from the head, the eye came in beside the
## skull and looked across it, and the whole picture was the side of a face
## (`--place=pinewood --view=shoulder --put=pipe,barricade,pole`).
const HEAD_UP := 1.45
const STEPS := 28
const CLEAR := 0.3
## Never nearer the shoulder point than this. At 0.8 the head, 0.62 to the left,
## is a quarter of the frame's height; nearer, it is the frame.
const LEAST_BACK := 0.8
## A solid narrower than this is SEEN PAST, not stood in front of: a pole, a
## lamp, a pine's trunk. It moves the eye only when the eye itself would stand
## inside it. Pulled in by every trunk, a walk through a wood was a camera that
## jumped at the back of the player's head at every tree. A boulder (0.45) and
## anything built still stop it.
const THIN := 0.38
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


## HOW FAR THE EYE MAY STAND from `from` (the shoulder point) along the line to
## where it wants to be, as a share 0..1 of that line.
##
## `ground` answers the drawn height of the land under a tile point. `solids` are
## what stops a body, as (x, z, radius, top) in tile space and world height:
## a house is its footprint up to its roof, a tower its mass up to the sky. A
## point is blocked when it is under the land, or inside a solid's circle (grown
## by CLEAR) below its top; a THIN solid blocks only the eye's own place.
static func room(from: Vector3, eye: Vector3, ground: Callable, solids: Array[Vector4]) -> float:
	var span := from.distance_to(eye)
	if span < 0.001:
		return 1.0
	var least := minf(1.0, LEAST_BACK / span)
	var clear := 0.0
	for i in range(1, STEPS + 1):
		var t := float(i) / float(STEPS)
		var q := from.lerp(eye, t)
		if _blocked(q, ground, solids, false):
			# One step short of the first blocked point, and CLEAR short of that.
			return maxf(least, clear - CLEAR / span)
		clear = t
	# The eye's own place, against the thin things too: walked back toward the
	# shoulder until it is out of them, which is their near side.
	if not _blocked(eye, ground, solids, true):
		return 1.0
	for i in range(STEPS - 1, 0, -1):
		var t := float(i) / float(STEPS)
		if not _blocked(from.lerp(eye, t), ground, solids, true):
			return maxf(least, t)
	return least


static func _blocked(q: Vector3, ground: Callable, solids: Array[Vector4], thin: bool) -> bool:
	if float(ground.call(Vector2(q.x, q.z))) + CLEAR > q.y:
		return true
	for s: Vector4 in solids:
		if s.z < THIN and not thin:
			continue
		var dx := q.x - s.x
		var dz := q.z - s.y
		var r := s.z + CLEAR
		if dx * dx + dz * dz < r * r and q.y < s.w + CLEAR:
			return true
	return false


## Degrees a second the arrow keys turn the view (docs/CONTROLS.md, C6): the one
## look a keyboard alone has. About a third of a turn a second, which crosses a
## screen's width of sky in the time a key is comfortably held.
const KEY_TURN_DEG := 110.0


## The arrow keys as a look: `keys` is -1..1 on each axis, right and down
## positive as `Input.get_vector` gives them, spent at `KEY_TURN_DEG` a second
## through the mouse's own rule (`look`), so the two cannot disagree about which
## way is up or where the gaze stops.
static func key_look(yaw_deg: float, pitch_deg: float, keys: Vector2, delta: float, least := PITCH_LEAST) -> Vector2:
	return look(yaw_deg, pitch_deg, keys * (KEY_TURN_DEG / MOUSE_DEG) * delta, least)


## PEOPLE ON THE LINE TO A LOCK (teammate1, 2026-09-24: two villagers covering
## the right third of a locked view). The room check keeps the eye out of land
## and walls, and a person is neither, so one who walks between the eye and the
## locked body stands square in front of it. The answer is to look over them:
## the view tips down by `CLEAR_TIP`, which lifts the eye (it stands on the
## focus's own line, `back` out along it) while the focus -- and so the lock --
## stays exactly where it was in the frame.
##
## How near the line a person counts, in tiles: a body's own width and a little.
const CLEAR_WIDTH := 0.6
## Degrees the view tips down while a person is on the line. At the shoulder's
## own distance this puts the eye about a metre higher, over a grown head.
const CLEAR_TIP := 16.0
## Eased at these rates (a second): in quickly enough to look over someone as
## they step in, out gently so a crowd walking past does not bob the camera.
const CLEAR_IN := 4.0
const CLEAR_OUT := 1.5


## Whether any of `people` stands on the line from `eye` to `target` (tile space,
## on the ground), within `width` of it and between the two -- not behind the
## eye, and not at or past the target, who is what is being looked at.
static func in_line(eye: Vector2, target: Vector2, people: Array[Vector2], width := CLEAR_WIDTH) -> bool:
	var d := target - eye
	var len2 := d.length_squared()
	if len2 < 0.01:
		return false
	for p: Vector2 in people:
		var t := (p - eye).dot(d) / len2
		if t <= 0.05 or t >= 0.92:
			continue
		if p.distance_to(eye + d * t) < width:
			return true
	return false


## One frame of the tip toward `want` degrees.
static func clear_step(now: float, want: float, delta: float) -> float:
	var rate := CLEAR_IN if want > now else CLEAR_OUT
	return lerpf(now, want, 1.0 - exp(-rate * delta))
