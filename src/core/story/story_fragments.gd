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


## What it says: the lines, in the order they are read.
static func lines(id: StringName) -> PackedStringArray:
	var f: Dictionary = StoryContent.FRAGMENTS.get(id, {})
	# The world writing him down: composed from what he has done, not written once.
	if f.has("ledger"):
		return StoryLedger.lines(StringName(str(f.ledger)))
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
