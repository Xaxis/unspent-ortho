class_name Roles
## What a machine is FOR, in the machines' plan (docs/VISION.md §2). A role is
## the one thing that decides how a machine takes the player before anything
## happens: its default disposition, what turns it, and whether it fights at
## all. Roster rows carry `role`; a row without one is read from its
## disposition, so a new kind can say either.
##
## | Role     | Default     | What it does                        | Turns when          |
## |----------|-------------|-------------------------------------|---------------------|
## | worker   | indifferent | build, carry, mine, maintain        | in the way, damaged, robbed |
## | keeper   | wary        | hold plan sites and routes          | trespass, curfew, damaged |
## | watcher  | observant   | see and file; raise interference    | never: it reports   |
## | hunter   | hostile     | remove humans                       | always              |
## | recycler | indifferent | take the dead and the broken        | you are downed near it |

const WORKER := &"worker"
const KEEPER := &"keeper"
const WATCHER := &"watcher"
const HUNTER := &"hunter"
const RECYCLER := &"recycler"

const ALL: Array[StringName] = [WORKER, KEEPER, WATCHER, HUNTER, RECYCLER]

const DEFAULT := {
	WORKER: &"indifferent",
	KEEPER: &"wary",
	WATCHER: &"observant",
	HUNTER: &"hostile",
	RECYCLER: &"indifferent",
}

## What the player can do that a role takes personally (VISION §2, right column).
## Causes: blocked (stood in its way), damaged (struck it or broke its work),
## theft (took its parts), trespass (stood on the site it keeps), curfew (out
## in its hours), downed (lying hurt where a recycler works).
const TURNS := {
	WORKER: [&"blocked", &"damaged", &"theft"],
	KEEPER: [&"blocked", &"damaged", &"theft", &"trespass", &"curfew"],
	WATCHER: [],
	HUNTER: [],
	RECYCLER: [&"damaged", &"downed"],
}

## Roles that never throw a blow: they read the player and file them. The
## interference their filing raises is what does the harm.
const FILES: Array[StringName] = [WATCHER]

## Fallback when a row says only what it thinks of the player.
const BY_DISPOSITION := {
	&"indifferent": WORKER, &"wary": KEEPER, &"observant": WATCHER, &"hostile": HUNTER,
}


## The role of a roster kind.
static func of(kind: StringName) -> StringName:
	return of_row(Roster.row(kind))


static func of_row(row: Dictionary) -> StringName:
	var r: StringName = row.get("role", &"")
	if ALL.has(r):
		return r
	if not row.get("machine", false):
		# A creature has no place in the plan: it is a hunter or it is nothing.
		return HUNTER
	return BY_DISPOSITION.get(row.get("disposition", &"hostile"), HUNTER)


static func default_disposition(role: StringName) -> StringName:
	return DEFAULT.get(role, &"hostile")


## Does this cause turn a machine of this role on the player?
static func turns(role: StringName, cause: StringName) -> bool:
	if role == HUNTER:
		return true
	return (TURNS.get(role, []) as Array).has(cause)


## It reports rather than fights: a watcher or clerk.
static func files(role: StringName) -> bool:
	return FILES.has(role)


static func fights(role: StringName) -> bool:
	return not files(role)
