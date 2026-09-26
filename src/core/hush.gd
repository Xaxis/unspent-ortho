class_name Hush
extends RefCounted
## THE HUSH ITSELF, as rules (docs/HUSH.md H3): when a ring falls quiet and how
## the quiet comes and goes. Pure: 23_hush asks it, the tests ask it, and
## nothing here reads the scene.
##
## A ring answers a visit at dusk, at night or in fog, and then only when the
## visit's hash says so: about one visit in two, and never the same way twice
## for a ring on a day. The quiet waits a moment after the player comes in,
## falls over FALL, holds a while, and lifts over FALL again.

const SALT := 0x4054
## Seconds the world takes to fall silent, and to come back.
const FALL := 1.5
## At least this dark (Weather.night_fall), or this much fog, for a ring to answer.
const DARK := 0.3
const FOG := 0.4


## Whether a ring answers this visit: `night` is Weather.night_fall of the hour,
## `fog` the sky's fog density.
static func answers(seed_value: int, ring: int, day: int, visit: int, night: float, fog: float) -> bool:
	if night < DARK and fog < FOG:
		return false
	return Rng.hash01(seed_value, ring, day, visit, SALT) < 0.5


## (seconds after coming in that the quiet begins, seconds it holds).
static func span(seed_value: int, ring: int, day: int, visit: int) -> Vector2:
	var h := Rng.hash01(seed_value, ring, day, visit, SALT + 1)
	var k := Rng.hash01(seed_value, ring, day, visit, SALT + 2)
	return Vector2(0.5 + 1.5 * h, 4.0 + 5.0 * k)


## How quiet it is `t` seconds after coming in: 0 none, 1 silent.
static func level(t: float, wait: float, hold: float) -> float:
	if t <= wait:
		return 0.0
	var u := t - wait
	if u < FALL:
		return smoothstep(0.0, FALL, u)
	u -= FALL
	if u < hold:
		return 1.0
	u -= hold
	return 1.0 - smoothstep(0.0, FALL, u) if u < FALL else 0.0


## Seconds from coming in until the quiet has lifted.
static func ends(wait: float, hold: float) -> float:
	return wait + FALL * 2.0 + hold



## THE STONES THAT STAND DIFFERENTLY (H2): world minutes an epoch lasts. In each
## epoch one stone of a ring stands turned, by TURN_MIN to TURN_MAX degrees
## either way; the rest stand as they were laid. 23_hush only lets a stone take
## the stance its epoch wants while nobody is looking at it. Under nine degrees
## a turned stone read as no change at all from above (hush-stones.tour): the
## point is a stone the player doubts, not one they cannot see.
const EPOCH := 25.0
const TURN_MIN := 9.0
const TURN_MAX := 18.0


## (which stone of `stones` stands turned in `epoch`, by how much in radians).
static func turned(seed_value: int, ring: int, stones: int, epoch: int) -> Vector2:
	var which := mini(stones - 1, int(Rng.hash01(seed_value, ring, epoch, SALT + 3) * stones))
	var by := deg_to_rad(lerpf(TURN_MIN, TURN_MAX, Rng.hash01(seed_value, ring, epoch, SALT + 4)))
	if Rng.hash01(seed_value, ring, epoch, SALT + 5) < 0.5:
		by = -by
	return Vector2(which, by)



## NOBODY'S LIGHTS (H4): on a hush landscape's night in fog, one to three steady
## lights stand low in the fog NEAR to FAR tiles from the player, drifting slowly
## round them: walk toward one and it is always that far. Never inside a ring
## (its stones and RING_CLEAR more). Pale grey-green: neither a person's warm
## unsteady flame nor a machine's cold ruled beam (LOOK law 2).
## Near enough to stand at the edge of the top view's frame (about 13 tiles
## either side of the player), far enough to be deep in the fog over the shoulder.
const NEAR := 11.0
const FAR := 20.0
const RING_CLEAR := 2.0
## At least this dark, in at least this much fog, for them to stand.
const LIT_DARK := 0.5
const LIT_FOG := 0.25
## Radians a world minute a light drifts round the player.
const DRIFT := 0.015
const LIGHT_COLOR := Color(0.70, 0.82, 0.72)


## Whether they stand at all: dark enough, foggy enough.
static func lit(dark: float, fog: float) -> bool:
	return dark >= LIT_DARK and fog >= LIT_FOG


## Where they stand tonight at world minute `minutes`, round the player at `at`:
## one to three points, each its own distance and drift for the night. `rings`
## are (centre x, centre y, radius) of the rings near; a light that would stand
## in one does not stand.
static func nobody(seed_value: int, night: int, minutes: float, at: Vector2, rings: PackedVector3Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := 1 + mini(2, int(Rng.hash01(seed_value, night, SALT + 10) * 3.0))
	for i in n:
		var d := lerpf(NEAR, FAR, Rng.hash01(seed_value, night, i, SALT + 11))
		var turn := DRIFT * (1.0 if Rng.hash01(seed_value, night, i, SALT + 12) < 0.5 else -1.0)
		var a := TAU * Rng.hash01(seed_value, night, i, SALT + 13) + turn * minutes
		var p := at + Vector2.from_angle(a) * d
		var clear := true
		for r: Vector3 in rings:
			if Vector2(r.x, r.y).distance_to(p) <= r.z + RING_CLEAR:
				clear = false
				break
		if clear:
			out.append(p)
	return out


## Which night world minute `minutes` falls in (a night runs noon to noon, so
## it never changes in the dark).
static func night_of(minutes: float) -> int:
	return floori((minutes + 12.0 * 60.0) / (24.0 * 60.0))
