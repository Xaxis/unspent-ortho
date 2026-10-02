extends TestCase
## A CONTINENT'S PLACES ARE ITS OWN. What a world lays on one body may depend on
## that body alone, so a landscape moved on another continent can never move home,
## its keeper, or the places the story has already walked through. It did: region
## ids rank every region of the world biggest-first, and tips and works were
## thrown from that id, so a landscape moved anywhere renumbered home's regions
## and laid its tips and works again (seed 1: the camp 190 tiles, the yard 32;
## GenCountries.region_key). Full size, because the story's places are only real
## there: two seeds, each grown three times.

const SEEDS: Array[int] = [1, 7]
## What the home leg holds: a landscape moved on any other body moves none of it.
const HOME: Array[String] = ["home tiles", "spawn", "home", "the_yard", "the_camp", "home's keepers"]
## What leg 1 holds besides: a landscape moved past it moves none of that either.
const LEG_1: Array[String] = ["the_covenant", "the_archive", "landing"]


## Every place the journey has reached by leg 1, and a hash of home's tiles.
func _places(w: WorldData) -> Dictionary:
	StoryPlan.forget()
	var cast := StoryPlan.cast(w)
	var home := w.continent_at(floori(w.spawn.x), floori(w.spawn.y))
	var h := 0
	for i in w.size * w.size:
		if w.continent[i] == home:
			h = hash([h, i, w.ground[i], w.level[i], w.country[i]])
	var out := {"home tiles": h, "spawn": w.spawn}
	for nm: StringName in [&"home", &"the_yard", &"the_camp", &"the_covenant", &"the_archive"]:
		out[String(nm)] = cast[nm].pos if cast.has(nm) else Vector2(-1, -1)
	var cr := StoryCrossing.find(w, out["the_camp"], out["the_archive"])
	out["landing"] = cr.get("land", Vector2(-1, -1))
	var lairs: Array[Vector2] = []
	for st: SentinelState in Sentinels.states(w):
		if w.continent_at(floori(st.lair.x), floori(st.lair.y)) == home:
			lairs.append(st.lair)
	lairs.sort()
	out["home's keepers"] = lairs
	return out


## The world `sd` grows when bodies `a` and `b` each give the other a landscape.
func _traded(sd: int, a: int, b: int) -> WorldData:
	GenBodies.trade = Vector2i(a, b)
	var w := WorldGen.generate(sd)
	GenBodies.trade = Vector2i(-1, -1)
	return w


## The trade really moved a landscape on `body`, so a held place proves something.
func _moved(was: WorldData, now: WorldData, body: int) -> bool:
	for i in was.size * was.size:
		if was.continent[i] == body and was.country[i] != now.country[i]:
			return true
	return false


func test_a_landscape_moved_elsewhere_moves_nothing_before_it() -> void:
	for sd: int in SEEDS:
		var w := WorldGen.generate(sd)
		var order := StoryJourney.bodies(w)
		gt(float(order.size()), 3.0, "seed %d has bodies past leg 1 (%s)" % [sd, order])
		if order.size() < 4:
			continue
		var was := _places(w)
		# On leg 1 itself: home holds.
		var on_1 := _traded(sd, order[1], order[2])
		check(_moved(w, on_1, order[1]), "seed %d: the trade moved a landscape on leg 1's body" % sd)
		var now := _places(on_1)
		for k: String in HOME:
			eq(now[k], was[k], "seed %d: %s holds when a landscape moves on legs 1 and 2" % [sd, k])
		# Past leg 1: home and all of leg 1 hold.
		var past := _traded(sd, order[2], order[3])
		check(_moved(w, past, order[2]), "seed %d: the trade moved a landscape on leg 2's body" % sd)
		now = _places(past)
		for k: String in HOME + LEG_1:
			eq(now[k], was[k], "seed %d: %s holds when a landscape moves on legs 2 and 3" % [sd, k])
