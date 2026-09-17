class_name StealthNoise
## How far what the player just did carries, in tiles. Machines hear whatever
## the dark and the weather (Senses), so noise is the one thing a player can
## always do something about: go slower, get down, choose the ground.
##
## A noise is an event at a place, not a state: the disposition system puts it
## in the simulation and every body near enough turns its optics to it.

## Tiles the bare act carries on plain ground.
const ACTS := {
	&"walk": 5.0,
	&"run": 13.0,
	&"dodge": 7.0,
	&"swing": 9.0,
	&"hit": 12.0,
	&"work": 10.0,
	&"break": 16.0,
	&"fell": 14.0,
	&"make": 8.0,
	&"build": 12.0,
	&"kill": 20.0,
	&"drop": 4.0,
	&"eat": 2.0,
}

## The ground underfoot, as a share of the act (art and design both: shingle
## rattles, snow and moss swallow, a road carries a long way).
const GROUNDS := {
	Ground.SHINGLE: 1.4,
	Ground.GRAVEL: 1.3,
	Ground.SCREE: 1.35,
	Ground.CLINKER: 1.3,
	Ground.BONE: 1.2,
	Ground.ROAD: 1.15,
	Ground.FLOOR: 1.15,
	Ground.LIMESTONE: 1.1,
	Ground.ROCK: 1.1,
	Ground.ICE: 1.05,
	Ground.SAND: 0.85,
	Ground.GRASS: 0.85,
	Ground.HEATH: 0.75,
	Ground.NEEDLES: 0.7,
	Ground.MOSS: 0.6,
	Ground.PEAT: 0.7,
	Ground.SNOW: 0.65,
	Ground.MUD: 0.8,
	# Swimming is the loudest way anybody travels: there is no crouching in open
	# water and nothing to be behind (Cover gives the deep nothing either).
	Ground.DEEP_WATER: 1.6,
	Ground.WATER: 1.5,
	Ground.RIVER: 1.5,
	Ground.BLACKWATER: 1.45,
}

## Crouched, everything the body itself does is this share as loud. Working a
## prop or a blow landing is the tool, not the body: it is only a little quieter.
const CROUCH_BODY := 0.35
const CROUCH_TOOL := 0.85
## The acts that are the body moving (crouch quietens these most).
const BODY_ACTS: Array[StringName] = [&"walk", &"run", &"dodge", &"drop", &"eat"]
## Carrying a load: each tier adds this share (the same tiers Senses hears by).
const LADEN := 0.2
## A noise is fresh for this long (sim ms): long enough to turn to, short
## enough that a machine does not stand looking at nothing.
const FRESH_MS := 2600.0


static func ground_factor(ground: int) -> float:
	return float(GROUNDS.get(ground, 1.0))


## Tiles the act carries from where it happened.
static func radius(act: StringName, ground: int, crouched: bool = false, laden_tier: int = 0) -> float:
	var base: float = ACTS.get(act, 0.0)
	if base <= 0.0:
		return 0.0
	var r := base * ground_factor(ground) * (1.0 + LADEN * maxi(0, laden_tier))
	if crouched:
		r *= CROUCH_BODY if BODY_ACTS.has(act) else CROUCH_TOOL
	return r


## The walking noise a body going at `speed` tiles/s makes: almost nothing
## standing still, a walk's worth at walking pace, a run's beyond it.
static func moving(speed: float, ground: int, crouched: bool, laden_tier: int) -> float:
	if speed < 0.4:
		return radius(&"walk", ground, crouched, laden_tier) * STILL
	var act := &"run" if speed > Tuning.WALK_SPEED + 0.4 else &"walk"
	var r := radius(act, ground, crouched, laden_tier)
	return r * clampf(speed / Tuning.WALK_SPEED, 0.5, 1.4)


## A body standing still is still a body: this share of its walking noise.
const STILL := 0.3
## Loudest a player is ever counted as, against a plain walk.
const LOUDEST := 2.5


## How loud the player is now, against a walk on plain ground (1.0). This is
## the one number that shortens how far a machine hears: crouching, the ground
## underfoot, the load and standing still are all in it.
static func loudness(speed: float, ground: int, crouched: bool, laden_tier: int) -> float:
	return clampf(moving(speed, ground, crouched, laden_tier) / float(ACTS[&"walk"]), 0.0, LOUDEST)
