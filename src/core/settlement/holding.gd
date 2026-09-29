class_name Holding
extends RefCounted
## THE HOLDING (ROADMAP slice 2, step 2): the people who have seen him, kept
## where a yard cannot reach them. A village that has seen him is asked once to
## come to his holding (46_settlements `holding_offer`); as many as the holding
## has free beds walk there with him and live there; a snatch night for that
## village takes nobody who went (48_raids `_come_for_the_seen`). Beds are the
## stake: what a holding cannot house stays by its own fire.
##
## What the goal line asks of (Guide.way_goal) and what the offer is sized by.
## Reads the systems by name at call time: core never preloads a system.

## Marked (Story.hear) the first time he comes in sight of roofs a broken yard's
## hunters burned (49_story). Not the beat `holdfast_price`, which a talk can
## land too, where he has only been told.
const SEEN_BURNED := &"seen:burned_roofs"


## Once the holding matters: the plan has taken somebody out of a village that
## had seen him, or he has seen roofs a broken yard's hunters burned.
static func wanted(game: Game) -> bool:
	return Story.heard(SEEN_BURNED) or taken_from_seen(game)


## Somebody out of a village that saw him is, or was, in a yard. A village he has
## never been near is never meant: the line promises beds to people he has met.
static func taken_from_seen(game: Game) -> bool:
	if game == null or game.world == null:
		return false
	var folk := game.get_node_or_null(^"folk")
	var taken_sys := game.get_node_or_null(^"45_taken")
	if folk == null or taken_sys == null:
		return false
	var record: Taken = taken_sys.get("taken")
	var seen: Dictionary = folk.get("seen_by")
	if record == null or seen == null:
		return false
	var names := {}
	for v: int in seen:
		if v >= 0 and v < game.world.villages.size():
			names[str(game.world.villages[v].get("name", ""))] = true
	for t in record.people:
		if t.home < 0 and t.home_name != "" and names.has(t.home_name):
			return true
	return false


## A holding of his stands in the realm he is in.
static func stands(game: Game) -> bool:
	var holdings := game.get_node_or_null(^"46_settlements") if game != null else null
	if holdings == null:
		return false
	var places: Array = holdings.get("places")
	var realm: StringName = game.world.realm if game.world != null else &""
	for s: Settlement in places:
		if s.realm == realm:
			return true
	return false


## The beds a holding has that nobody sleeps in.
static func free_beds(s: Settlement) -> int:
	return maxi(0, s.beds() - s.people.size())


## Of `people` asked, how many go (x) and how many stay (y) with `free` beds.
static func split(people: int, free: int) -> Vector2i:
	var go := clampi(free, 0, maxi(people, 0))
	return Vector2i(go, maxi(people, 0) - go)


## Who stays, in words: they are nobody's names yet, only a village's people.
static func stay_words(n: int, village: String) -> String:
	if n <= 0:
		return ""
	if n == 1:
		var t := Taken.TakenPerson.new()
		t.home_name = village
		return Taken.say(t)
	const COUNT := ["", "one", "two", "three", "four", "five", "six", "seven", "eight"]
	return "%s of them" % (COUNT[n] if n < COUNT.size() else str(n))
