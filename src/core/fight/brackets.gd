class_name Brackets
extends RefCounted
## EARNED BRACKETS (owner, 2026-10-14: "the user should be able to earn more
## health brackets and stamina brackets"). Health is drawn in brackets of
## HEALTH_BRACKET points and wind (stamina) in brackets of WIND_BRACKET; he
## starts with FightRules.HEALTH and FightRules.WIND, and earns more by doing
## the thing each is for:
##
##   health  every machine he brings down counts, and the next bracket comes at
##           the next of MACHINES_FOR; every keeper he fells is a bracket of its own
##   wind    every tile he runs counts, and the next bracket comes at the next
##           of RUN_FOR
##
## The counts are the body's (Body.machines_down, keepers_down, run_tiles, saved);
## what they are worth is asked here, so a bracket can never be out of step with
## what earned it. Pure.

const HEALTH_BRACKET := 3
const WIND_BRACKET := 800.0
## Machines brought down, in all, for each health bracket earned that way.
const MACHINES_FOR: Array[int] = [2, 5, 9, 14, 20, 27]
## Tiles run, in all, for each wind bracket.
const RUN_FOR: Array[float] = [250.0, 700.0, 1400.0, 2300.0, 3400.0]
## The most health brackets keepers may add (one each).
const KEEPERS_MOST := 6


## Health brackets earned on top of the ones he started with.
static func health_earned(machines: int, keepers: int) -> int:
	return _passed(MACHINES_FOR, float(machines)) + mini(keepers, KEEPERS_MOST)


## Wind brackets earned on top of the ones he started with.
static func wind_earned(run_tiles: float) -> int:
	return _passed(RUN_FOR, run_tiles)


## Machines still to bring down for the next health bracket earned that way, or
## -1 when none is left to earn by it.
static func machines_to_next(machines: int) -> int:
	for need in MACHINES_FOR:
		if machines < need:
			return need - machines
	return -1


## Tiles still to run for the next wind bracket, or -1.
static func run_to_next(run_tiles: float) -> float:
	for need in RUN_FOR:
		if run_tiles < need:
			return need - run_tiles
	return -1.0


static func _passed(marks: Array, at: float) -> int:
	var n := 0
	for m: float in marks:
		if at >= m:
			n += 1
	return n
