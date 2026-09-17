class_name Attention
## What the plan thinks a holding is worth doing something about
## (docs/VISION.md §9.3), as pure rules. `Settlement.attention` is the number;
## this file is the only thing that decides what moves it.
##
## **The unit.** Attention is 0..1 on ONE scale, and the scale is the escalation:
## 0 is a place nothing has ever reported, and 1.0 is a siege led by the region's
## keeper. Everything else is stated as a share of that, so a number is always
## answerable — 0.45 is "a probe is due", not "forty-five points". The unit it is
## counted in is ONE NOTICE THAT GOT AWAY at a full-strength reading
## (`NOTICE_FULL`): twelve of those, unanswered, bring the keeper — eleven make
## 0.99 and a siege wants `RaidStage.AT[3]`, 1.0, which
## `tests/raid/test_attention.gd` holds to.
##
## **Nothing here is a timer.** Every rise is caused by something the player did
## or built and could have seen: a record that got home, a network they stirred,
## stolen technology they chose to run inside their own walls, a machine that
## went there and never came back. A holding that gives off nothing and is never
## read gains nothing, however many days pass — `tests/raid/test_attention.gd`
## names that rule. Time only ever takes attention AWAY, and only while the place
## is quiet, which is the thing a quiet week is for.

## What one filed record at full strength is worth: the unit everything else is
## measured in.
const NOTICE_FULL := 0.09

## What a reading taken off a DECOY is worth against one taken of the yard: a
## quarter. A decoy hides nothing — it is read INSTEAD of the holding
## (`Settlement.lures`) — so the plan still learns the place is there, and this is
## the whole of what the piece buys. It cannot be nothing, or a mast in a field
## would be a place that is never filed at all and the answer to being read would
## be to build one and stop thinking; and it cannot be much, or building one
## would not be worth the timber. Four decoyed records are one real one.
const LURED := 0.25

## Every cause that moves it, and by how much. Positive raises.
##
##   notice        a reading got home (scaled by how good it was: Notices.worth)
##   lured         the same, taken off a decoy standing out past the yard: the
##                 plan has an account of a pole in a field, and it is worth
##                 `LURED` of an account of the place (48_raids `_file`)
##   lost          a machine the plan sent to this place never came home
##   interference  the plan's network round the holding went up a level (§2)
##   found_tech    stolen FOUND technology running in the walls, per world hour
##                 at full strength (a stolen cell is 1.0: the loudest thing in
##                 the game, and it is meant to cost)
##   stopped       a record destroyed before it travelled
##   quiet         a quiet world hour: nothing read the place and nothing came
##   raided        what a step spends when it has been paid (RaidStage.spends)
##   keeper_fell   the region's keeper is gone; its network is quiet for good
const CAUSES := {
	&"notice": NOTICE_FULL,
	&"lured": NOTICE_FULL * LURED,
	&"lost": 0.14,
	&"interference": 0.07,
	&"found_tech": 0.030,
	&"stopped": -0.05,
	&"quiet": -0.012,
	&"raided": -0.30,
	&"keeper_fell": -1.0,
}

## A holding whose whole signature is under this is dark, and cools at
## DARK_COOL times the rate while the sun is down. Running dark is not free —
## it is a lamp out, a hearth cold and a mast off — so it is worth something.
const DARK_UNDER := 0.16
const DARK_COOL := 2.4
## The player's own spoofed signature, standing in the place: the plan reads the
## holding as one of their own for as long as the signet holds.
const SPOOF_COOL := 3.0
## What a piece that masks (a spoofer, netting, shutters) does to the cooling: the
## holding's own `mask` is already inside its Signature, so this is the part that
## goes on working when nobody is reading it at all. A DECOY is not one of them
## and never was: it hides nothing where the holding stands, it is read in its
## place, and what it buys is `LURED` at the moment a reading lands.
const MASK_COOL := 1.8

## Attention never sits at exactly 0 once a place has been filed: the plan does
## not forget a holding, it only stops caring. Under this it is treated as none.
const NOTHING := 0.004


static func of(cause: StringName) -> float:
	return float(CAUSES.get(cause, 0.0))


## What `cause` does to `attention`, clamped to the scale. Returns the new value.
static func raised(attention: float, cause: StringName, scale: float = 1.0) -> float:
	return clampf(attention + of(cause) * maxf(0.0, scale), 0.0, 1.0)


## What a quiet stretch takes off. `hours` world hours; `dark` the place is under
## DARK_UNDER with the sun down; `spoofed` the player's signature is answering
## for it; `masked` 0..1 the strongest mask standing in it.
static func cooled(attention: float, hours: float, dark: bool, spoofed: bool, masked: float = 0.0) -> float:
	if hours <= 0.0 or attention <= 0.0:
		return maxf(0.0, attention)
	var rate := 1.0
	if dark:
		rate *= DARK_COOL
	if spoofed:
		rate *= SPOOF_COOL
	if masked > 0.0:
		rate *= lerpf(1.0, MASK_COOL, clampf(masked, 0.0, 1.0))
	var v := attention + of(&"quiet") * rate * hours
	return 0.0 if v < NOTHING else clampf(v, 0.0, 1.0)


## What stolen technology humming inside the walls adds over `hours`. `found`
## is the holding's own found_tech channel, which is what the slate already
## shows the player: the one line they can read and then go and bury.
static func from_found_tech(attention: float, found: float, hours: float) -> float:
	if hours <= 0.0 or found <= 0.0:
		return attention
	return clampf(attention + of(&"found_tech") * clampf(found, 0.0, 1.0) * hours, 0.0, 1.0)


## A one-line reading of where a holding stands, for a message and for a test.
## Never a bar and never a percentage: the holding app already draws what a
## machine HEARS, and a second readout of what it THINKS would turn a system
## about reading the world into a number to optimise (owner, docs/VISION.md §9).
static func pressure(attention: float) -> StringName:
	if attention < RaidStage.AT[0] * 0.5:
		return &"unknown"
	if attention < RaidStage.AT[0]:
		return &"read"
	if attention < RaidStage.AT[1]:
		return &"surveyed"
	if attention < RaidStage.AT[2]:
		return &"wanted"
	if attention < RaidStage.AT[3]:
		return &"marked"
	return &"condemned"
