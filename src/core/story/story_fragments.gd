class_name StoryFragments
## What is WRITTEN on a readable thing, and the one door anything that places one
## knocks on (owner, 2026-09-17).
##
## The seam, which matters because two packages meet here:
##
##   the PLACER owns where a readable thing stands, what it is made of, how it is
##   drawn, its mark on the map and the key that opens it — landmarks, works,
##   scatter, a settlement's own paperwork;
##
##   the STORY owns what it says, which arc it belongs to, what finding it
##   teaches, and whether it has been found — none of which a placer needs to know.
##
##   StoryFragments.kinds()                     what kinds of readable thing exist
##   StoryFragments.pick(kind, land, seed, n)   which text THIS one holds, deterministically
##   StoryFragments.lines(id)                   what it says
##   Story.read(id)                             the player has read it (true the first time)
##
## `pick` is pure and deterministic: the same landmark in the same world says the
## same thing every time that world is grown, or a save would open onto a sign
## that had changed its mind.
##
## A placer declares which kind it can hold and nothing else:
##   {"kind": PropKind.SIGN, "holds": StoryFragments.SIGN}

## The kinds of readable thing. A placer picks the one its object is: a gate sign
## is a SIGN, a dead worker's book is a NOTEBOOK, a machine's own screen is a
## TERMINAL, and a thing somebody scratched is a MARK.
const SIGN := &"sign"
const NOTEBOOK := &"notebook"
const TERMINAL := &"terminal"
const MARK := &"mark"

const KINDS: Array[StringName] = [SIGN, NOTEBOOK, TERMINAL, MARK]


static func kinds() -> Array[StringName]:
	return KINDS


## Which fragment this thing holds. `land` is the landscape id it stands in,
## `seed_value` the world's, `instance` whatever makes this one different from
## the next of its kind (a landmark's index, a prop's id). Returns &"" when the
## story has nothing of that kind for that landscape, and a placer that gets &""
## puts down a thing with nothing written on it, which is its own kind of true.
static func pick(kind: StringName, land: StringName, seed_value: int, instance: int) -> StringName:
	var fits: Array[StringName] = []
	for id: StringName in StoryContent.FRAGMENTS:
		# A place's own words are never dealt anywhere else, nor is a page only
		# something else opens (`dealt: false`: the end).
		if placed(id) or not bool(StoryContent.FRAGMENTS[id].get("dealt", true)):
			continue
		var f: Dictionary = StoryContent.FRAGMENTS[id]
		if StringName(str(f.get("kind", &""))) != kind:
			continue
		var lands: Array = f.get("lands", [])
		if not lands.is_empty() and not lands.has(String(land)):
			continue
		fits.append(id)
	if fits.is_empty():
		return &""
	# Deterministic, and spread: the same instance always draws the same one, and
	# two landmarks in a row do not say the same thing.
	var at := int(Rng.hash01(seed_value, instance, 0x5709) * float(fits.size()))
	return fits[clampi(at, 0, fits.size() - 1)]


## The n'th of a story place's own words, or &"" past the end of them. `kind`,
## when given, counts only that place's words of that kind, so the n'th terminal
## on the platform holds the n'th terminal's words and a binder never shows a
## screen's (StoryContent.PLACED).
static func pick_at(place: StringName, n: int, kind: StringName = &"") -> StringName:
	var i := 0
	for id: StringName in StoryContent.PLACED.get(place, []):
		if kind != &"" and kind_of(id) != kind:
			continue
		if i == n:
			return id
		i += 1
	return &""


## Whether a fragment belongs to one place and is never dealt.
static func placed(id: StringName) -> bool:
	for place: StringName in StoryContent.PLACED:
		if (StoryContent.PLACED[place] as Array).has(id):
			return true
	return false


## Which words THIS standing thing holds: a story place's own, counted among the
## readable things of its kind that stand there in id order, or else the words its
## kind deals. Pure and derived, like `pick`, so a save opens onto the same words.
## A placer stands a readable prop at the place; it never names the words.
static func held_by(world: WorldData, prop: WorldProp) -> StringName:
	var kind := StoryProps.kind_of(prop.kind)
	if kind == &"":
		return &""
	var place := StoryWorld.place_of(world, prop.pos)
	if place != &"":
		var n := 0
		for q: WorldProp in world.props:
			if q.id < prop.id and StoryProps.kind_of(q.kind) == kind and StoryWorld.place_of(world, q.pos) == place:
				n += 1
		var own := pick_at(place, n, kind)
		if own != &"":
			return own
	var d := BiomeRegistry.at(world, prop.pos)
	return pick(kind, d.id if d != null else &"", world.seed_value, prop.id)


## What it says: the lines, in the order they are read.
static func lines(id: StringName) -> PackedStringArray:
	var f: Dictionary = StoryContent.FRAGMENTS.get(id, {})
	# The world writing him down: composed from what he has done, not written once.
	if f.has("ledger"):
		return StoryLedger.lines(StringName(str(f.ledger)))
	# How it ended: composed from everything he chose.
	if bool(f.get("ending", false)):
		return StoryEnding.lines()
	var out := PackedStringArray()
	for l: String in f.get("lines", []):
		out.append(l)
	return out


## What kind of thing it is (for a placer that has an id and wants the model).
static func kind_of(id: StringName) -> StringName:
	return StringName(str(StoryContent.FRAGMENTS.get(id, {}).get("kind", &"")))


## A short name for a list: what the player would call it afterwards.
static func title_of(id: StringName) -> String:
	return String(StoryContent.FRAGMENTS.get(id, {}).get("title", ""))


## Everything declared, for the tests and for dev mode's story page.
static func all() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in StoryContent.FRAGMENTS:
		out.append(id)
	return out
