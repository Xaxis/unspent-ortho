class_name Disposition
## How one machine takes the player, now (docs/VISION.md §2). Pure rules; the
## disposition system writes the answer onto a live body and its model's status
## lamps blink it.
##
## Three things decide it, in this order:
##   1. its role's default (Roles.DEFAULT)
##   2. the interference in the plan network it stands in: every level raises
##      the machines that were going about their work one step
##   3. what the player has done to THIS machine (blocked it, struck it, robbed
##      it): disturbed, it is hostile whatever the network thinks
##
## A machine that only reports (a watcher, a clerk) never becomes hostile: it
## files, and the filing is what brings the hunters.

## Cold to hot, for comparing two dispositions. `observant` is a watcher's whole
## trade and never a step on a worker's way up: see BY_LEVEL.
const ORDER: Array[StringName] = [&"indifferent", &"wary", &"observant", &"hostile"]
## What the interference of a region does to a body that would otherwise be
## about its work, by the body's own default (VISION §2: "indifferent machines
## grow wary, then hostile, and hunters are sent"). Indexed by level 0..3.
const BY_LEVEL := {
	&"indifferent": [&"indifferent", &"wary", &"hostile", &"hostile"],
	&"wary": [&"wary", &"wary", &"hostile", &"hostile"],
	&"observant": [&"observant", &"observant", &"observant", &"observant"],
	&"hostile": [&"hostile", &"hostile", &"hostile", &"hostile"],
}


static func rank(d: StringName) -> int:
	return maxi(0, ORDER.find(d))


static func raise_by(d: StringName, steps: int) -> StringName:
	return ORDER[clampi(rank(d) + maxi(0, steps), 0, ORDER.size() - 1)]


## The disposition of a body of `role` in a network at interference `level`
## (0..3, Interference.LEVELS), disturbed or not.
static func of(role: StringName, level: int, disturbed: bool = false) -> StringName:
	if Roles.files(role):
		# It sees and files; nothing makes it fight.
		return &"observant"
	if role == Roles.HUNTER:
		return &"hostile"
	if disturbed:
		return &"hostile"
	var base := Roles.default_disposition(role)
	var ladder: Array = BY_LEVEL.get(base, BY_LEVEL[&"hostile"])
	return ladder[clampi(level, 0, ladder.size() - 1)]


static func hostile(d: StringName) -> bool:
	return d == &"hostile"


## Will a body of this disposition go about its work with the player in sight?
static func works_on(d: StringName) -> bool:
	return d == &"indifferent"


## A machine has taken something amiss (Roles.TURNS): does it turn on the player?
static func turned_by(role: StringName, cause: StringName) -> bool:
	return Roles.fights(role) and Roles.turns(role, cause)
