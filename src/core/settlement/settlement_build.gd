class_name SettlementBuild
## What it takes to put a piece up, and what to say when it cannot go up here
## (docs/VISION.md). Pure: it reads a creel and a kind and nothing else, so
## the slate, a test and a tour all get the same answer, and the system above it
## is the only thing that touches the world.

## Tiles from a holding's centre that a new piece joins it rather than founding
## another one. A holding is a walk across, not a village square.
const JOIN := 26.0
## A piece goes down this far in front of the player, and needs this much room
## around it.
const AHEAD := 1.4
const CLEARANCE := 0.25
## What a piece that wants a keeper's core says without one: what would unlock
## it, not what it is short of (SETTLE.md S5).
const NEEDS_CORE_LINE := "A keeper's core would power it."


## What `inv` is short of for `kind`: {item id: how many more}. Empty means all in
## hand.
static func missing(inv: Inventory, kind: int) -> Dictionary:
	var out := {}
	if inv == null:
		return out
	for id: StringName in StructureKind.cost(kind):
		var want := int(StructureKind.cost(kind)[id])
		var short := want - inv.count(id)
		if short > 0:
			out[id] = short
	return out


static func can_make(inv: Inventory, kind: int) -> bool:
	return StructureKind.buildable(kind) and missing(inv, kind).is_empty() and \
		(StructureKind.needs_one(kind).is_empty() or reward_held(inv, kind) != &"")


## The first of `kind`'s `needs_one` rewards in `inv`, or &"" (none held, or none
## asked for).
static func reward_held(inv: Inventory, kind: int) -> StringName:
	if inv == null:
		return &""
	for id: StringName in StructureKind.needs_one(kind):
		if inv.count(id) > 0:
			return id
	return &""


## "" when it can go up, else one plain line. The words are the player's, not the
## table's: what is short, and how much of it.
static func why_not(inv: Inventory, kind: int) -> String:
	if not StructureKind.buildable(kind):
		return "Nobody knows how to build that yet."
	if not StructureKind.needs_one(kind).is_empty() and reward_held(inv, kind) == &"":
		return NEEDS_CORE_LINE
	var short := missing(inv, kind)
	if short.is_empty():
		return ""
	var parts := PackedStringArray()
	for id: StringName in short:
		parts.append(count_words(id, int(short[id])))
	return "Short %s." % join_words(parts)


## Take a piece's cost out of the creel. Returns false (taking nothing) when it
## cannot be paid for in full.
static func take_cost(inv: Inventory, kind: int) -> bool:
	if not can_make(inv, kind):
		return false
	for id: StringName in StructureKind.cost(kind):
		@warning_ignore("return_value_discarded")
		inv.remove(id, int(StructureKind.cost(kind)[id]))
	var reward := reward_held(inv, kind)
	if reward != &"":
		@warning_ignore("return_value_discarded")
		inv.remove(reward, 1)
	return true


## "2 timber", "a plate" — how the slate and the HUD count a material.
static func count_words(id: StringName, n: int) -> String:
	var name := String(Items.def(id).get("name", String(id).replace("_", " ")))
	if n <= 1:
		return name
	return "%d %s" % [n, name]


static func join_words(parts: PackedStringArray) -> String:
	if parts.size() <= 1:
		return "" if parts.is_empty() else parts[0]
	var head := Array(parts).slice(0, parts.size() - 1)
	return "%s and %s" % [", ".join(head), parts[parts.size() - 1]]


## What a new holding is called. Plain words: the fiction names nothing yet
## (docs/DESIGN.md §Story), and a place the player made should be theirs to think
## of by where it is rather than by what somebody else called it.
static func name_for(n: int) -> String:
	match n:
		1: return "the holding"
		2: return "the second holding"
		3: return "the third holding"
	return "holding %d" % n
