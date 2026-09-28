class_name KeptBy
## A LIVED-IN ROOM'S KEPT-BY SHELF (docs/GEAR.md §7). A room somebody lives in
## (InteriorKind.seats) keeps what it holds (Interiors.LOOT) on one of its own
## pieces, the recipe's `KEPT_BY` (the first of them it laid). It is theirs: it is
## never taken. A stranger is told whose it is. Somebody the region has cause to
## thank -- it asked him for something and has thanked him for doing it
## (StorySubarc, Story.heard "REGION:goal:said") -- is given it, once a door.
##
## PURE: 21_doors asks, stands the player at it and saves what was given.

## How near the hands must be to the shelf.
const REACH := 1.4
## What the shelf says, by line id (StoryContent.KEPT_BY).
const THEIRS := &"kept_by_theirs"
const GIVEN := &"kept_by_given"
const GAVE := &"kept_by_gave"
## Salt for a door's gift roll.
const SALT := 0x6E17


## The index in `l.things` of a lived-in room's shelf, or -1.
static func shelf(l: InteriorLayout, k: InteriorKind) -> int:
	if k == null or not k.lived():
		return -1
	for want: StringName in k.kept_by:
		for i in l.things.size():
			if l.things[i].kind == want:
				return i
	return -1


## Whether a body at `pos` has its hands at the shelf: in reach of it, and nearer
## it than any story slot, so a press meant for words beside it is the words'.
static func at_hand(l: InteriorLayout, k: InteriorKind, pos: Vector2) -> bool:
	var i := shelf(l, k)
	if i < 0:
		return false
	var d := (l.things[i].at as Vector2).distance_to(pos)
	if d >= REACH:
		return false
	for slot: Dictionary in l.slots:
		if (slot.at as Vector2).distance_to(pos) <= d:
			return false
	return true


## Whether the people of `region` have cause to thank him.
static func on_terms(region: int) -> bool:
	if region < 0:
		return false
	for goal: StringName in StorySubarc.GOALS:
		if Story.heard(StringName("%d:%s:said" % [region, goal])):
			return true
	return false


## The door's own gift, the same every time that world is grown.
static func instance(seed_value: int, key: String) -> int:
	return Rng.hash_ints(seed_value, key.hash(), SALT)
