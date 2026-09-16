class_name StealthQuery
## The one door for "can that machine tell I am here". Senses keeps the source's
## geometry (how far a kind sees and hears, the dark, the weather, the filings,
## a clear line); this is everything the player can do about it:
##
##   crouch   seen about half as far, heard a third as far, slower
##   cover    what you are standing in and the night shorten sight, never hearing
##   lamp     undoes the dark AND the cover, both ways: it is the one light that
##            gives a body away
##   cone     a machine looks where its body looks; behind it, only close up.
##            A watcher's cone is narrow and sweeps: the gap in its round is
##            learnable, and that is the point
##   spoof    a misread signature: it sees something and takes it for one of
##            its own until you are almost touching it
##
## Every sense in the game goes through here: `Senses.notices` calls it, so
## brains, the coast and the tests all read the same rules.

## Crouched: how much of its sight is left. What crouching does to hearing is
## in StealthNoise (the body is quieter), so it is counted in one place only.
const CROUCH_SIGHT := 0.55
## Full cover takes this share of a machine's sight range.
const COVER_SIGHT := 0.8
## Behind its cone it still catches movement, at this share of its range.
const BEHIND := 0.28
## Misread as one of their own: this share of sight, until you are on top of it.
const SPOOF_SIGHT := 0.18

## Half the angle a role sees in, radians. A watcher reads a narrow strip and
## sweeps it; a hunter has almost none of a blind side.
const CONES := {
	Roles.WATCHER: 0.62,
	Roles.WORKER: 1.15,
	Roles.KEEPER: 1.0,
	Roles.RECYCLER: 1.2,
	Roles.HUNTER: 1.6,
}
## Seconds an observant machine takes to sweep its cone across and back.
const SWEEP_PERIOD := 9.0
## Radians each way it sweeps.
const SWEEP_SPAN := 1.15


static func cone_half(row: Dictionary) -> float:
	return float(CONES.get(Roles.of_row(row), 1.3))


## Is `target` inside the cone a body at `from` facing `facing` reads?
static func in_cone(from: Vector2, facing: float, target: Vector2, half: float) -> bool:
	if half >= PI:
		return true
	var to := target - from
	if to.length_squared() < 1e-6:
		return true
	return absf(wrapf(to.angle() - facing, -PI, PI)) <= half


## How far this kind sees the player now: Senses' range, cut by what the player
## is doing about it. `m.cover` and `m.crouched` are the player's; the lamp
## has already undone both in Moment.
static func sight_range(row: Dictionary, m: Moment) -> float:
	var r := Senses.sight_range(row, m)
	if r <= 0.0:
		return 0.0
	if m.crouched:
		r *= CROUCH_SIGHT
	r *= 1.0 - COVER_SIGHT * clampf(m.cover, 0.0, 1.0)
	if m.spoofed:
		r *= SPOOF_SIGHT
	return r


## How far it hears the player. Cover and the dark are nothing to hearing; how
## loud the player is (StealthNoise: crouching, the ground, the load, standing still)
## is everything.
static func hearing_range(row: Dictionary, m: Moment) -> float:
	return Senses.hearing_range(row, m) * clampf(m.loudness, 0.0, StealthNoise.LOUDEST)


## Seen: in range, in the cone (or close behind it), with a clear line.
## `facing` NAN means the body is not turned anywhere in particular (tests and
## the callers that only ask about range), and the cone does not apply.
static func sees(row: Dictionary, from: Vector2, target: Vector2, m: Moment, world: WorldData,
		query: WorldQuery, facing: float = NAN) -> bool:
	var r := sight_range(row, m)
	if r <= 0.0:
		return false
	if not is_nan(facing) and not in_cone(from, facing, target, cone_half(row)):
		r *= BEHIND
	return Senses.chebyshev(from, target) <= r and Senses.line_clear(world, query, from, target)


static func hears(row: Dictionary, from: Vector2, target: Vector2, m: Moment) -> bool:
	var r := hearing_range(row, m)
	return r > 0.0 and Senses.chebyshev(from, target) <= r


static func notices(row: Dictionary, from: Vector2, target: Vector2, m: Moment, world: WorldData,
		query: WorldQuery, facing: float = NAN) -> bool:
	return hears(row, from, target, m) or sees(row, from, target, m, world, query, facing)


## A noise of `radius` tiles at `at`: does the body at `from` hear it? A kind
## that hears further than most hears it further away; one that is deaf (a
## watcher reads by eye) hears nothing at all.
static func hears_noise(row: Dictionary, from: Vector2, at: Vector2, radius: float, m: Moment) -> bool:
	if radius <= 0.0 or row.get("sight_only", false):
		return false
	var scale := 1.0
	var base: float = row.get("hears", 0)
	if base > 0.0:
		scale = clampf(base / 9.0, 0.5, 1.6)
	return Senses.chebyshev(from, at) <= radius * scale


## Where an observant machine is looking at time `t` seconds, given the bearing
## it keeps: exact and repeating, so a player can learn the gap and walk it.
static func sweep(base: float, t: float, phase: float = 0.0) -> float:
	return base + sin(TAU * fposmod(t + phase, SWEEP_PERIOD) / SWEEP_PERIOD) * SWEEP_SPAN


## Does this role sweep its cone rather than hold it?
static func sweeps(row: Dictionary) -> bool:
	return Roles.of_row(row) == Roles.WATCHER
