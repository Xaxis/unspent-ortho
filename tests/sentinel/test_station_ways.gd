extends TestCase
## THE STATION RULE (Sentinels.ways_closed): a keeper stands only where every way
## its design declares can be done. Asked of every keeper placed on four worlds
## at full size, at the den it was given. Under the old siting seed 1's Reaper
## denned at a sea wall with nothing of the plan in reach to starve it of, and
## every Reaper and lockkeeper off its landscape's biggest region stood at its
## heart the same way: the coast laid one intake and the city one lock a world.

const Worlds := preload("res://tests/core/test_world_gen.gd")
const SEEDS: Array[int] = [1, 7, 42, 90210]
## Designs whose stations nobody lays yet, so their keepers den by their
## regions' hearts where the ground keeps what it can (founder ground in reach),
## as design:way where a den still closes the way (measured at GEN 47; routed
## by cb, 2026-10-02). A way that needs laid works (STARVE's feeds, a SPOOF's
## lamp) waits on its landscape's works; a FOUNDER line stands where no room the
## search tries in a region has its ground in reach (the frost sea's black water,
## the snowfield's ice, a mesa skerry's sand). It only shrinks: the test fails on
## a line that now holds on every seed.
const STANDING: Array[String] = [
	"anchor:founder", "anchor:starve",
	"anvil:starve",
	"listener:founder",
	"plough:founder", "plough:starve",
	"plumb:starve",
	"unbuilder:spoof",
]

static var _seven: WorldData = null


func _world(s: int) -> WorldData:
	if Worlds.WORLD_SEEDS.has(s):
		return Worlds.world(s)
	if _seven == null:
		_seven = WorldGen.generate(s)
	return _seven


func test_every_keeper_can_be_taken_every_way_its_design_declares() -> void:
	var seen := {}
	var kept := 0
	for s: int in SEEDS:
		var w := _world(s)
		for st: SentinelState in Sentinels.states(w):
			var def := Sentinels.by_id(st.design)
			kept += 1
			for way: StringName in Sentinels.ways_closed(w, st.lair, def):
				var key := "%s:%s" % [st.design, way]
				seen[key] = true
				if not STANDING.has(key):
					check(false, "seed %d: the %s keeper of region %d at %s cannot be taken by %s there (founder ground %d, feeds %d)"
						% [s, st.design, st.region, st.lair, way, Sentinels.founder_tiles(w, st.lair, def),
							Sentinels.laid_near(w, st.lair, def.feeds, def.reach * Sentinels.FEED_SHARE)])
	gt(float(kept), 40.0, "four worlds hold their keepers (%d)" % kept)
	for key: String in STANDING:
		check(seen.has(key), "%s holds on every seed now: take it off STANDING" % key)


## The plan's side of the rule: a region big enough to keep a keeper gets its
## keeper's first station, sited where the ground keeps its ways
## (GenWorks._n_station, GenWorks.station_holds). Seed 7's second coast region
## had no intake, and its Reaper stood at its heart with nothing to eat.
func test_a_second_region_of_a_landscape_gets_its_keepers_station() -> void:
	var w := _world(7)
	var dens := {}
	for st: SentinelState in Sentinels.states(w):
		if st.design == &"tide_reaper" or st.design == &"lockkeeper":
			var def := Sentinels.by_id(st.design)
			var at_station := false
			for m: Dictionary in w.landmarks:
				if StringName(str(m.kind)) == def.stations[0] and (m.pos as Vector2).distance_to(st.lair) < 13.0:
					at_station = true
			check(at_station, "seed 7: the %s of region %d dens at its %s" % [st.design, st.region, def.stations[0]])
			dens[st.design] = int(dens.get(st.design, 0)) + 1
	gt(float(dens.get(&"tide_reaper", 0)), 1.0, "seed 7 keeps two Reapers")
	gt(float(dens.get(&"lockkeeper", 0)), 1.0, "and two lockkeepers")


## THE LANDING IS SAFE GROUND: no keeper dens within its reach of where the raft
## from home sets him down, the story's landing (StoryCrossing, from the crew's
## camp to the archive) or where the deal says the water comes ashore (the
## LANDFALL body's `from`). The lock with its keeper stands thirty tiles from
## seed 1's slip; inside its reach, the first thing across the water would be a
## keeper fight at the quay.
func test_no_keeper_covers_the_landing() -> void:
	for s: int in SEEDS:
		var w := _world(s)
		var cast := StoryPlan.cast(w)
		var landings: Array[Vector2] = []
		if cast.has(&"the_camp") and cast.has(&"the_archive"):
			var c := StoryCrossing.of(w, cast)
			if c.has("land"):
				landings.append(c["land"] as Vector2)
		for row: Dictionary in w.continents:
			if bool(row.get("landfall", false)) and row.has("from"):
				landings.append(row["from"] as Vector2)
		check(not landings.is_empty(), "seed %d: a landing to keep clear" % s)
		for st: SentinelState in Sentinels.states(w):
			var reach := Sentinels.by_id(st.design).reach
			for l: Vector2 in landings:
				gt(st.lair.distance_to(l), reach, "seed %d: the %s of region %d dens %.0f tiles from the landing at %s, inside its reach"
					% [s, st.design, st.region, st.lair.distance_to(l), l])
