class_name Haven
extends RefCounted
## The ground round a village that nothing hunts you on (owner, 2026-09-19,
## docs/DESIGN.md §Safe havens and the guided opening).
##
## The owner asked for "safe havens" like towns, to teach the game in. This is
## the SAFETY half, stated as a number a test can fail on. The teaching half is
## the guide's.
##
## **IT WAS ALREADY TRUE AND NOBODY HAD SAID SO.** A roster row declares
## `where.green_min`, how far from a village green the spawner may stand that
## kind, and sixteen of nineteen already declare one. So a village was quietly
## the safest ground in the game, by accumulation rather than by decision -- and
## a guarantee nobody wrote down is one the next roster row silently repeals.
## Measured before it was written: the nearest a hunter of the plan may stand is
## the runner's 14 tiles, and the nearest a beast that hunts may stand is the
## field bull's 10.
##
## Two kinds are exempt on purpose and both say so in their own row:
##
##   A NEAR-VILLAGE KIND declares `green_max` instead. The yard dog belongs at
##   the yard; keeping it 14 tiles off one is not safety, it is a missing dog.
##   A KEEPER is not placed by this rule at all -- a sentinel stands at its own
##   lair and keeps `Sentinels.CLEAR_OF_HOME` off the spawn, so a `green_min` on
##   its row would be a number nothing reads.
##
## **NOTHING HERE MAKES A PLACE COMPULSORY.** A haven is safe, not a corridor: a
## player who walks out in the first minute and learns the game the hard way is
## playing it correctly. This file is a floor under the ground they can stand on,
## and never a wall round it.
##
## A system that reads this must `preload` it rather than name it -- a
## `class_name` resolves out of a cache the tools refresh and a hand-run does
## not, which cost the owner a session (CLAUDE.md, `class_name`).

## How far the plan's hunters keep off a village green. The runner's own number,
## because the runner is the first hunter a player ever meets and the one the
## guide teaches a dodge against: a haven is exactly as safe as the nearest
## thing that would hunt you in it.
const PLAN_REACH := 14.0

## How far a beast that hunts keeps off. Nearer than the plan on purpose -- a
## field bull is livestock gone wrong rather than something sent, and a village
## that never had one at the fence would be a village with nothing living near
## it.
const BEAST_REACH := 10.0


## Whether a roster row is held to the floor at all, and to which one.
## `&""` for a row the rule does not reach, with the reason in this file's
## header rather than in a caller's branch.
static func held_to(kind: StringName) -> StringName:
	var row := Roster.row(kind)
	if row.is_empty():
		return &""
	# What does not HUNT does not make a place unsafe.
	if Roster.disposition(kind) != &"hostile" or not bool(row.get("hostile", true)):
		return &""
	var where: Dictionary = row.get("where", {})
	# A kind that belongs near a village says so with `green_max`.
	if where.has("green_max"):
		return &""
	# A keeper stands at its lair, not by the green rule.
	if String(row.get("role", "")) == "keeper":
		return &""
	return &"plan" if bool(row.get("machine", true)) else &"beast"


## The floor a kind is held to, or 0.0 where none reaches it.
static func reach_for(kind: StringName) -> float:
	match held_to(kind):
		&"plan": return PLAN_REACH
		&"beast": return BEAST_REACH
	return 0.0
