extends TestCase
## THE STATION RULE (Sentinels.ways_closed): a keeper stands only where every way
## its design declares can be done. Asked of every keeper placed on four worlds
## at full size, at the den it was given. Under the old siting seed 1's Reaper
## denned at a sea wall with nothing of the plan in reach to starve it of, and
## every Reaper and lockkeeper off its landscape's biggest region stood at its
## heart the same way: the coast laid one intake and the city one lock a world.

const Worlds := preload("res://tests/core/test_world_gen.gd")
const SEEDS: Array[int] = [1, 7, 42, 90210]
## Designs whose stations nobody lays yet, so their keepers stand at their
## regions' hearts, as design:way where one of those hearts closes the way
## (measured at GEN 47; routed by cb, 2026-10-01). Laying a design's stations
## where its ways hold (GenWorks.station_holds) takes its lines off. It only
## shrinks: the test fails on a line that now holds on every seed.
const STANDING: Array[String] = [
	"anchor:founder", "anchor:starve",
	"anvil:founder", "anvil:starve",
	"listener:founder",
	"plough:founder", "plough:starve",
	"plumb:founder", "plumb:starve",
	"unbuilder:founder", "unbuilder:spoof",
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
