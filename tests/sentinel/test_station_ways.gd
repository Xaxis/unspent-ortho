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
	"listener:founder",
	"plough:founder", "plough:starve",
	"unbuilder:spoof",
]

## The worlds test_world_gen does not keep, made once each.
static var _made := {}


func _world(s: int) -> WorldData:
	if Worlds.WORLD_SEEDS.has(s):
		return Worlds.world(s)
	if not _made.has(s):
		_made[s] = WorldGen.generate(s)
	return _made[s]


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


## EVERY KEEPER-SIZED REGION KEEPS ITS KEEPER AT A STATION. A work its keeper
## dens at is sited for the den the keeper will take (GenWorks.station_holds,
## Sentinels.station_den), and a refused site is tried again elsewhere, never
## dropped. So every region big enough to keep a keeper (Sentinels.MIN_TILES), of
## a design whose stations the plan lays, holds one, and its keeper dens where
## one of them said with every way open. A region that loses its station fails:
## seed 1's region 23 passed a weaker rule because its refused pans were gone,
## and seed 42's only crags region kept no keeper when a bench was sited for
## the room at its own middle. A design's stations are laid when one stands on
## any of the four worlds.
##
## Ground that cannot keep a keeper keeps none: a region that can hold none of
## its keeper's stations (`_kept_out`) is skipped and printed, and held to a
## sliver by the test after this one.
func test_every_keeper_sized_region_keeps_its_keeper_at_a_station() -> void:
	var laid := _laid()
	var asked := 0
	for s: int in SEEDS:
		var w := _world(s)
		var landings: Array[Vector2] = []
		for row: Dictionary in w.continents:
			if bool(row.get("landfall", false)) and row.has("from"):
				landings.append(row["from"] as Vector2)
		var lair_of := {}
		for st: SentinelState in Sentinels.states(w):
			lair_of[st.region] = st.lair
		var dens := {}
		var named := {}
		for m: Dictionary in w.landmarks:
			var def := _design_of(w, m)
			if def == null:
				continue
			var p: Vector2 = m.get("pos", Vector2.ZERO)
			var region := w.region_at(floori(p.x), floori(p.y))
			var half: Vector2 = m.get("half", Vector2.ZERO)
			var got: Array = dens.get(region, [])
			got.append(Sentinels.station_den(w, p, def, landings, region, PackedVector2Array(), false, maxf(half.x, half.y)))
			dens[region] = got
			named[region] = "%s at %s" % [m.kind, p]
		for r: Dictionary in w.regions:
			var def := Sentinels.for_land(StringName(str(r.get("type", &""))))
			var id := int(r.get("id", -1))
			if def == null or not laid.has(def.id) or (int(r.get("tiles", 0)) < Sentinels.MIN_TILES and not dens.has(id)):
				continue
			var where := "seed %d: %s region %d (%d tiles)" % [s, r.get("type", &""), id, int(r.get("tiles", 0))]
			var why := _kept_out(w, r, def, landings) if not dens.has(id) else ""
			if why != "":
				print("       %s: %s; it keeps none" % [where, why])
				continue
			asked += 1
			var at: Vector2 = lair_of.get(id, Vector2.INF)
			if not dens.has(id):
				check(false, "%s holds none of its %s's stations (keeper %s)" % [where, def.id, at])
			elif not at.is_finite():
				check(false, "%s holds a station (%s) and keeps no %s" % [where, named[id], def.id])
			elif not (dens[id] as Array).has(at):
				check(false, "%s: its %s dens at %s, not where a station was sited for (%s)" % [where, def.id, at, dens[id]])
			else:
				var closed := Sentinels.ways_closed(w, at, def)
				check(closed.is_empty(), "%s: its %s at its station cannot be taken by %s" % [where, def.id, closed])
	gt(float(asked), 20.0, "four worlds hold keeper-sized regions of station designs (%d)" % asked)


## A REGION KEPT OUT OF ITS KEEPER IS A SLIVER. The ground of one that can hold
## none of its keeper's stations (`_kept_out`) is the world's to answer for
## past SLIVER_MOST tiles: the salt flats' 448-592 tile flats with no pan in
## reach and seed 7's 752 tiles of crags all peat are slivers, and 90210's
## 9472-tile coast with no sea in it is a coast dealt to land the sea never
## reaches (task #60).
const SLIVER_MOST := 2000


func test_no_region_past_a_sliver_is_kept_out_of_its_keeper() -> void:
	var laid := _laid()
	for s: int in SEEDS:
		var w := _world(s)
		var landings: Array[Vector2] = []
		for row: Dictionary in w.continents:
			if bool(row.get("landfall", false)) and row.has("from"):
				landings.append(row["from"] as Vector2)
		var held := {}
		for m: Dictionary in w.landmarks:
			if _design_of(w, m) != null:
				var p: Vector2 = m.get("pos", Vector2.ZERO)
				held[w.region_at(floori(p.x), floori(p.y))] = true
		for r: Dictionary in w.regions:
			var def := Sentinels.for_land(StringName(str(r.get("type", &""))))
			var id := int(r.get("id", -1))
			var tiles := int(r.get("tiles", 0))
			if def == null or not laid.has(def.id) or tiles < Sentinels.MIN_TILES or held.has(id):
				continue
			var why := _kept_out(w, r, def, landings)
			if why != "":
				lt(float(tiles), float(SLIVER_MOST), "seed %d: %s region %d (%d tiles) is kept out of its %s: %s" % [s, r.get("type", &""), id, tiles, def.id, why])


## Stations that stand only on a sea shore (GenWorks._shore).
const SHORE_STATIONS: Array[StringName] = [&"intake"]


## Why region `r` can hold none of its keeper's stations, read off its ground;
## "" where it can. No room in it keeps its keeper's ground ways
## (Sentinels.ground_den, the search a region whose stations nobody lays dens
## by: its heart may stand outside the region, and a station's den is the
## region's own), or its keeper's stations stand only on a sea shore and it
## has none (GenWorks.has_shore).
static func _kept_out(w: WorldData, r: Dictionary, def: SentinelDef, landings: Array[Vector2]) -> String:
	var den := Sentinels.ground_den(w, r, def, landings)
	if not den.is_finite() or w.region_at(floori(den.x), floori(den.y)) != int(r.get("id", -1)):
		return "no room in it keeps its %s's ground ways" % def.id
	var on_shore := true
	for k: StringName in def.stations:
		on_shore = on_shore and SHORE_STATIONS.has(k)
	if on_shore and not GenWorks.has_shore(w, r):
		return "it has no sea shore for its %s's stations" % def.id
	return ""


## The designs whose stations the plan lays: one stands on any of the four worlds.
func _laid() -> Dictionary:
	var laid := {}
	for s: int in SEEDS:
		for m: Dictionary in _world(s).landmarks:
			var def := _design_of(_world(s), m)
			if def != null:
				laid[def.id] = true
	return laid


## The keeper design whose station landmark `m` is, by its own landscape; null
## when it is no keeper's station.
static func _design_of(w: WorldData, m: Dictionary) -> SentinelDef:
	var p: Vector2 = m.get("pos", Vector2.ZERO)
	var land := BiomeRegistry.by_index(w.country_at(floori(p.x), floori(p.y)))
	var def := Sentinels.for_land(land.id) if land != null else null
	return def if def != null and def.stations.has(StringName(str(m.get("kind", &"")))) else null


## THE SALT FLATS ASK THE RULE TOO. Their pans and brine houses are the rake's
## stations, and they never asked it: seed 1's region 23 held pans and kept no
## rake. Every salt-flats region on five seeds, as the rake stands in it: where
## it dens, how far from its nearest station, and which ways a den there closes.
## 90210's open flats are the hard case: asked of every pan, the rule refused
## them all.
const FLATS_SEEDS: Array[int] = [1, 4, 7, 42, 90210]


func test_every_salt_flats_region_with_a_station_keeps_its_rake() -> void:
	var def := Sentinels.by_id(&"pan_rake")
	for s: int in FLATS_SEEDS:
		var w := _world(s)
		var landings: Array[Vector2] = []
		for row: Dictionary in w.continents:
			if bool(row.get("landfall", false)) and row.has("from"):
				landings.append(row["from"] as Vector2)
		var lair_of := {}
		for st: SentinelState in Sentinels.states(w):
			if st.design == &"pan_rake":
				lair_of[st.region] = st.lair
		for r: Dictionary in w.regions:
			if StringName(str(r.get("type", &""))) != &"salt_flats":
				continue
			var id := int(r.get("id", -1))
			var stations: Array[Vector2] = []
			for m: Dictionary in w.landmarks:
				var p: Vector2 = m.get("pos", Vector2.ZERO)
				if def.stations.has(StringName(str(m.get("kind", &"")))) and w.region_at(floori(p.x), floori(p.y)) == id:
					stations.append(p)
			var lair: Vector2 = lair_of.get(id, Vector2.INF)
			var off := INF
			for p: Vector2 in stations:
				off = minf(off, p.distance_to(lair)) if lair.is_finite() else INF
			var closed: Array = Sentinels.ways_closed(w, lair, def) if lair.is_finite() else ["no den"]
			print("       seed %d salt flats region %d (%d tiles): %d stations, rake %s, %.1f from its nearest station, closed %s"
				% [s, id, int(r.get("tiles", 0)), stations.size(), "at %s" % lair if lair.is_finite() else "stands nowhere", off, closed])
			var why := _kept_out(w, r, def, landings) if stations.is_empty() else ""
			if why != "":
				print("       seed %d salt flats region %d: %s" % [s, id, why])
				continue
			if not stations.is_empty() or int(r.get("tiles", 0)) >= Sentinels.MIN_TILES:
				check(not stations.is_empty() and lair.is_finite() and closed.is_empty(), "seed %d: salt flats region %d holds %d stations and keeps its rake, every way open (%s)" % [s, id, stations.size(), closed])


## ASKED BEFORE IT IS LAID, IT STILL HOLDS AFTER. Where a station's den does
## not hang on its larder (GenWorks.larder_decides: the rake has no STARVE way)
## the rule is asked before the work lays anything (GenWorks.station_first), and
## the den the keeper takes in the finished world, every work and mark laid, is
## the one that was asked: every such station on five worlds still holds.
func test_a_station_asked_before_it_is_laid_still_holds_after() -> void:
	var asked := 0
	for s: int in FLATS_SEEDS:
		var w := _world(s)
		var landings: Array[Vector2] = []
		for row: Dictionary in w.continents:
			if bool(row.get("landfall", false)) and row.has("from"):
				landings.append(row["from"] as Vector2)
		for m: Dictionary in w.landmarks:
			var def := _design_of(w, m)
			if def == null or def.way_of(SentinelWay.STARVE) != null:
				continue
			var p: Vector2 = m.get("pos", Vector2.ZERO)
			var half: Vector2 = m.get("half", Vector2.ZERO)
			var den := Sentinels.station_den(w, p, def, landings, w.region_at(floori(p.x), floori(p.y)), PackedVector2Array(), true, maxf(half.x, half.y))
			asked += 1
			check(den.is_finite(), "seed %d: the %s's %s at %s, asked before it was laid, holds in the finished world" % [s, def.id, m.kind, p])
	gt(float(asked), 10.0, "five worlds hold stations asked before they were laid (%d)" % asked)


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
				# At it is inside its feeding reach of it, as test_world holds:
				# a den with its larder under its feet stands off past the
				# take-refusal radius (Sentinels.larder_robbable).
				if StringName(str(m.kind)) == def.stations[0] and (m.pos as Vector2).distance_to(st.lair) < def.reach * Sentinels.FEED_SHARE:
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
