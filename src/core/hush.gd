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
