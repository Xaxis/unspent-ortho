class_name StoryRooms
## What a room's story slots hold (docs/STORY.md): the story's side of the seam
## a room's recipe opens with `InteriorLayout.slots`. The recipe says where words
## can be found -- a desk, a terminal, a wall -- and nothing about what they are;
## this says what, out of StoryContent.ROOMS, and nothing about where.
##
## A slot names only its kind, so the words are chosen by what it stands at: the
## thing in the room nearest it (`key_of`: `wall:whiteboard`, `desk:kist`). A room
## that moves its whiteboard moves its words with it, and one that adds a slot
## at a thing the story has no row for holds nothing, which `use` passes over.
##
## Pure and derived from the door, like StoryFragments.held_by: the same room on
## the same seed says the same thing every time it is grown.

const SALT := 0x5700A5
## How far in front of a slot a body stands to read it, and how far into the room
## the slot's thing reaches (a desk's depth, a board's nothing): what `use` measures
## a slot's distance from.
const STAND := 0.95
const SOLID := 0.4


## `SLOT:THING`: the slot's kind and the kind of the thing in the room nearest it.
static func key_of(l: InteriorLayout, slot: Dictionary) -> StringName:
	var at: Vector2 = slot.get("at", Vector2.INF)
	var best: StringName = &""
	var bd := INF
	for t: Dictionary in l.things:
		var d := (t.at as Vector2).distance_squared_to(at)
		if d < bd:
			bd = d
			best = t.kind
	return StringName("%s:%s" % [slot.get("slot", &""), best])


## The fragment slot `i` of room `l` holds, behind the door whose key is `door`,
## or &"" when the story has nothing written for it. Where a row offers several,
## the door deals where to start and each further slot of the same key takes the
## next, so one house never holds the same words twice.
static func held(kind: StringName, door: String, l: InteriorLayout, i: int) -> StringName:
	if i < 0 or i >= l.slots.size():
		return &""
	var rows: Dictionary = StoryContent.ROOMS.get(kind, {})
	var key := key_of(l, l.slots[i])
	var ids: Array = rows.get(key, [])
	if ids.is_empty():
		return &""
	var nth := 0
	for j in i:
		if key_of(l, l.slots[j]) == key:
			nth += 1
	var start := int(Rng.hash01(door.hash(), SALT) * float(ids.size()))
	return ids[(start + nth) % ids.size()]


## Whether a fragment belongs to a kind of room and is never dealt anywhere else.
static func placed(id: StringName) -> bool:
	for kind: StringName in StoryContent.ROOMS:
		for key: StringName in StoryContent.ROOMS[kind]:
			if (StoryContent.ROOMS[kind][key] as Array).has(id):
				return true
	return false


## Where a body stands to read slot `i`, and which way it faces then.
static func stand(l: InteriorLayout, i: int) -> Vector2:
	var s: Dictionary = l.slots[i]
	return (s.at as Vector2) + (s.face as Vector2) * STAND


static func facing(l: InteriorLayout, i: int) -> float:
	return (-(l.slots[i].face as Vector2)).angle()
