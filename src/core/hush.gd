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
