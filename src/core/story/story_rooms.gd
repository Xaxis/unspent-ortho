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
## or &"" when the story has nothing written for it. `room` is the ROOMS row the
## door keeps (`room_of`). Where a row offers several, the door deals where to
## start and each further slot of the same key takes the next, so one house never
## holds the same words twice.
static func held(room: StringName, door: String, l: InteriorLayout, i: int) -> StringName:
	if i < 0 or i >= l.slots.size():
		return &""
	var rows: Dictionary = StoryContent.ROOMS.get(room, {})
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


# --- who each bunker was sunk for (docs/story/UNDER_THE_STONES.md) -------------
#
# Cairn sank a shelter under every ring of cast stones on its coast, one to a
# household. Which household a bunker was for is dealt across the whole island
# at once, because the deal is a count: exactly one is his (No. 4), one Kerr's,
# then Priya's, a household that lived out the war, the Holdfast's cache, and
# ones that waited for families who never came.

const HIS := &"his"
const KERR := &"kerr"
const PRIYA := &"priya"
const HOLDFAST := &"holdfast"
const CAME := &"came"
const NEVER := &"never"
const TENANTS: Array[StringName] = [HIS, KERR, PRIYA, HOLDFAST, CAME, NEVER]
## Past his and Kerr's, the order the rest are dealt in; any left over waited
## for a family that never came.
const FILL: Array[StringName] = [PRIYA, CAME, HOLDFAST, NEVER, CAME, CAME]

static var _tenant_world: WorldData = null
static var _tenants: Dictionary = {}


## The ROOMS row a room keeps: its kind, or `kind:TENANT` for a room whose
## households differ. His bunker is the plain `bunker`.
static func room_of(kind: StringName, tenant: StringName) -> StringName:
	if tenant == &"" or tenant == HIS:
		return kind
	return StringName("%s:%s" % [kind, tenant])


## Door key -> tenant, for every bunker on `world` (a surface world: a pocket has
## no doors of its own). His is the nearest to where he woke; Kerr's is the
## farthest from it; the rest are dealt off their keys, the Holdfast's the one
## nearest its camp.
##
## Not a spine slot, by measurement: a full-sized world keeps three to five rings
## on his coast (GEN 28, seeds 1-12), but at the plan tests' 256 tiles half of seeds 1-24
## hold none, so his bunker is colour and `handler_note` keeps `was_cia`'s other
## door. A slot would also take a landmark the camp may be cast on.
## Held per world object, as StoryPlan.cast is.
static func tenants(world: WorldData) -> Dictionary:
	if world == null:
		return {}
	if world == _tenant_world:
		return _tenants
	_tenant_world = world
	_tenants = _deal(world)
	return _tenants


static func _deal(world: WorldData) -> Dictionary:
	var bunkers: Array[Threshold] = []
	for t: Threshold in Interiors.thresholds(world):
		if t.kind == &"bunker":
			bunkers.append(t)
	var out := {}
	if bunkers.is_empty():
		return out
	var cast := StoryPlan.cast(world)
	var home := world.spawn
	bunkers.sort_custom(func(a: Threshold, b: Threshold) -> bool:
		return a.host.distance_squared_to(home) < b.host.distance_squared_to(home))
	out[bunkers[0].key] = HIS
	if bunkers.size() > 1:
		out[bunkers[-1].key] = KERR
	var rest: Array[Threshold] = []
	for i in range(1, bunkers.size() - 1):
		rest.append(bunkers[i])
	rest.sort_custom(func(a: Threshold, b: Threshold) -> bool:
		return Rng.hash01(a.key.hash(), SALT) < Rng.hash01(b.key.hash(), SALT))
	# A full-sized world keeps three to five rings on his coast (GEN 28, seeds
	# 1-12: half keep three), so the deal goes in the order the story most wants
	# them and a small coast keeps the front of it.
	for want: StringName in FILL:
		if rest.is_empty():
			break
		var t := rest[0]
		if want == HOLDFAST and cast.has(&"the_camp"):
			var camp: Vector2 = cast[&"the_camp"].pos
			for q: Threshold in rest:
				if q.host.distance_squared_to(camp) < t.host.distance_squared_to(camp):
					t = q
		out[t.key] = want
		rest.erase(t)
	for t: Threshold in rest:
		out[t.key] = NEVER
	return out


## Only the tests want this.
static func forget() -> void:
	_tenant_world = null
	_tenants = {}
