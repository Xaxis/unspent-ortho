class_name StoryProps
## Which things standing in the world can be read, and which person has anything
## to say (owner, 2026-09-17).
##
## This is the STORY's side of the seam only: it says "a sign is a thing with a
## sign's words on it". Where signs stand, what they are made of and how they are
## drawn belongs to whoever put them there — worldgen's works, the landmarks
## package, a settlement's own paperwork — and none of that is known here.
##
## Nothing new is placed for the story. The machines' works already bolt notices
## to their gates, keep archives and stand relays along a survey bearing; until
## today not one of them could be read, because `Takes` has no row for a sign and
## `use` only ever offered what could be worked. That was the whole gap.

## How far a person or a thing can be and still be talked to or read, and how
## close counts whichever way the player is turned. Here rather than in the
## system so the tour runner can ask the same question the game asks.
const REACH := 3.0
const CLOSE := 1.6

## Prop kind -> what kind of readable thing it is. A kind that is not here has
## nothing written on it and `use` passes straight over it as it always did.
const READABLE := {
	PropKind.SIGN: StoryFragments.SIGN,
	PropKind.ARCHIVE: StoryFragments.NOTEBOOK,
	PropKind.RELAY: StoryFragments.TERMINAL,
	PropKind.SURVEY: StoryFragments.TERMINAL,
	PropKind.MEMORIAL: StoryFragments.MARK,
	PropKind.STANDING_STONE: StoryFragments.MARK,
	PropKind.GRAVE: StoryFragments.MARK,
}


static func kind_of(prop_kind: int) -> StringName:
	return READABLE.get(prop_kind, &"")


static func readable(prop_kind: int) -> bool:
	return READABLE.has(prop_kind)


## What this person has to say, or &"". A talk names the trade it belongs to
## (`who`), so the keeper at the fire says the keeper's lines wherever the keeper
## happens to be standing — villagers do not survive being walked away from
## (35_folk streams them), so nothing may hang on this one body being this one
## person. What is remembered is what the PLAYER said, which is theirs and keeps.
static func talk_for(row: Dictionary, _game: Game) -> StringName:
	# A named person says their own words and nobody else's (StoryCast).
	var character := StringName(str(row.get("character", &"")))
	if character != &"":
		var c := StoryCast.get_def(character)
		return c.talk if c != null else &""
	var trade := StringName(str(row.get("trade", &"")))
	if trade == &"":
		return &""
	for id: StringName in StoryContent.TALKS:
		var t: Dictionary = StoryContent.TALKS[id]
		if t.has("cast"):
			continue
		var who := StringName(str(t.get("who", &"")))
		if who == &"" or who == trade:
			return id
	return &""


## Every trade that has anything written for it, for the tests and the dev page.
static func trades_with_talk() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in StoryContent.TALKS:
		var who := StringName(str(StoryContent.TALKS[id].get("who", &"")))
		if who != &"" and not out.has(who):
			out.append(who)
	return out
