class_name TargetSubject
extends RefCounted
## One thing the slate can be put on. A fight body (a machine or a creature) or a
## person: both can be looked at, so both can be read, and the read says what that
## kind of thing has to say rather than pretending a villager has a working part.
##
## Anything else the player can look at — a works, a station, a sentinel — becomes
## a subject by getting a `from_*` here, and the system, the order and the drawing
## follow without changing.

## The fight's own body, or null for something that is not in the fight.
var body: MobState = null
## A person's row (35_folk), or {}.
var folk: Dictionary = {}
## A PLACE's row (34_works, 22_landmarks), or {}. A thing that stands still and
## can be looked at: a depot, a place worth the walk. The row is built by whoever
## owns the place, so nothing in src/core/target has to know what a depot is.
var place: Dictionary = {}
## A person's ids start here, clear of every fight body's; a place's above those.
const FOLK_ID := 1000000
const PLACE_ID := 2000000
## Tiles a place's ring is drawn at, when its row does not say.
const PLACE_RADIUS := 1.6
var id := 0
var kind: StringName = &""
var name := ""
var pos := Vector2.ZERO
## How tall the thing is, for where its tag and brackets sit.
var height := 1.0
var machine := false
var person := false


static func from_body(m: MobState) -> TargetSubject:
	var s := TargetSubject.new()
	s.body = m
	s.id = m.id
	s.kind = m.kind
	s.name = TargetRead.words(m.kind)
	s.pos = m.pos
	s.height = float(m.row.get("height", 1.0))
	s.machine = m.machine
	return s


## A villager (35_folk holds them as rows, not bodies): no health, no working part,
## nothing that fights. The row's own id is what a lock holds onto, because the
## folk list is streamed — a villager three houses back is erased from it, and an
## index would slide the lock onto somebody else.
static func from_folk(row: Dictionary, index: int) -> TargetSubject:
	var s := TargetSubject.new()
	s.folk = row
	s.id = FOLK_ID + int(row.get("id", index))
	# A person is called by their trade, which is also how they are dressed: "idle"
	# is a state of the walk code, not a thing to call one of the last people.
	s.kind = StringName(str(row.get("trade", &"")))
	if s.kind == &"":
		s.kind = &"one of the last people"
	s.name = TargetRead.words(s.kind)
	s.pos = row.get("pos", Vector2.ZERO)
	s.height = 1.7
	s.person = true
	return s


## A PLACE: a depot, a place worth the walk. It has no health, notices nothing and
## goes nowhere, and what it has to say is what has been DONE to it — which is
## why the row is handed over whole by the system that owns it rather than read
## out of the world here. `rows` are [label, value] pairs and `thinking` is the
## one line the slate ends on, exactly as a body's read is shaped.
##
## The player can break the biggest thing in the game and, until this existed,
## the slate had nothing to say about it.
static func from_place(row: Dictionary) -> TargetSubject:
	var s := TargetSubject.new()
	s.place = row
	s.id = PLACE_ID + int(row.get("id", 0))
	s.kind = StringName(str(row.get("kind", &"place")))
	s.name = str(row.get("name", ""))
	s.pos = row.get("pos", Vector2.ZERO)
	s.height = float(row.get("height", 2.0))
	return s


## Where it is now: a body walks, a villager walks on its own round, and a place
## is the one thing in the list that is where it was.
func here() -> Vector2:
	if body != null:
		return body.pos
	if not folk.is_empty():
		return folk.get("pos", pos)
	return pos


## How wide a ring the slate draws round it.
func radius() -> float:
	if body != null:
		return maxf(0.45, float(body.row.get("radius", 0.5)) + 0.25)
	if not place.is_empty():
		return float(place.get("radius", PLACE_RADIUS))
	return 0.0


func alive() -> bool:
	if body != null:
		return body.alive and not body.removed
	return not folk.is_empty() or not place.is_empty()
