class_name Rarity
## What a piece of gear's grade means (docs/VISION.md §6.1).
##
## A grade decides HOW MANY MODIFIERS a piece carries and how strange they are,
## never a flat damage ladder. A common knife stays a useful knife for the whole
## game; a relic plays differently rather than harder. Keep it that way: the
## moment a grade multiplies damage, every earlier piece becomes litter and the
## landscapes stop being worth crossing for their own sake.

enum { COMMON, UNCOMMON, RARE, PRIME, RELIC }

const NAMES: Array[StringName] = [&"common", &"uncommon", &"rare", &"prime", &"relic"]

## Modifier sockets by grade. A relic's fourth is not a socket: it is the one
## thing only that piece does (see `unique`).
const SLOTS: Array[int] = [0, 1, 2, 3, 3]


static func name_of(grade: int) -> StringName:
	return NAMES[clampi(grade, 0, NAMES.size() - 1)]


static func of_name(n: StringName) -> int:
	var i := NAMES.find(n)
	return i if i >= 0 else COMMON


static func slots(grade: int) -> int:
	return SLOTS[clampi(grade, 0, SLOTS.size() - 1)]


## A relic carries something no other piece has, on top of its sockets.
static func unique(grade: int) -> bool:
	return grade == RELIC


## Where a grade can come from at all, so nothing quietly drops a relic from a
## rusted hinge: common and uncommon are everywhere, rare wants a place worth
## walking to, prime a named enemy or a hard recipe, relic a sentinel, the Before
## or the plan's own stock.
static func ordinary(grade: int) -> bool:
	return grade <= UNCOMMON
