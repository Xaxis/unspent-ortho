extends TestCase
## THE RAFT COMES ASHORE IN THE DROWNED CITY (docs/ROADMAP.md slice 3 step 6). The
## city declares `BiomeDef.LANDFALL`: it is dealt to the body the shortest water
## from home reaches, its heart stands where that water comes ashore, and the
## story's leg 1 is cast there. Under the old deal it lay on the journey's last
## body on seeds 1 and 7, 800 tiles off slice 3's route. Moving it there moves
## nothing on home (tests/biome/test_body_independence.gd says why it can't).
## Full size: two seeds grown with the rule and without, and a third's plan.

const SEEDS: Array[int] = [1, 7]
const CITY := &"drowned_city"
## He steps off the raft into the city: a city tile this near where he lands.
const ASHORE := 3


## What the home leg holds, as test_body_independence reads it.
func _home(w: WorldData) -> Dictionary:
	StoryPlan.forget()
	var cast := StoryPlan.cast(w)
	var home := w.continent_at(floori(w.spawn.x), floori(w.spawn.y))
	var h := 0
	for i in w.size * w.size:
		if w.continent[i] == home:
			h = hash([h, i, w.ground[i], w.level[i], w.country[i]])
	var out := {"home tiles": h, "spawn": w.spawn}
	for nm: StringName in [&"home", &"the_yard", &"the_camp"]:
		out[String(nm)] = cast[nm].pos if cast.has(nm) else Vector2(-1, -1)
	var lairs: Array[Vector2] = []
	for st: SentinelState in Sentinels.states(w):
		if w.continent_at(floori(st.lair.x), floori(st.lair.y)) == home:
			lairs.append(st.lair)
	lairs.sort()
	out["home's keepers"] = lairs
	return out


## Where the raft lands: StoryCrossing between the camp and the archive.
func _landing(w: WorldData) -> Vector2:
	StoryPlan.forget()
	var cast := StoryPlan.cast(w)
	if not cast.has(&"the_camp") or not cast.has(&"the_archive"):
		return Vector2(-1, -1)
	return StoryCrossing.find(w, cast[&"the_camp"].pos, cast[&"the_archive"].pos).get("land", Vector2(-1, -1))


func _in_city(w: WorldData, p: Vector2) -> bool:
	for dy in range(-ASHORE, ASHORE + 1):
		for dx in range(-ASHORE, ASHORE + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if w.in_bounds(x, y) and BiomeRegistry.by_index(w.country[y * w.size + x]).id == CITY:
				return true
	return false


## The old deal for the length of the scope: the city declares no spread and
## lies wherever the balance put it. Restored however the test leaves.
class NoLandfall extends RefCounted:
	var was: Vector2i

	func _init() -> void:
		was = BiomeRegistry.get_def(CITY).spread
		BiomeRegistry.get_def(CITY).spread = Vector2i(0, 0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			BiomeRegistry.get_def(CITY).spread = was


func test_the_raft_comes_ashore_in_the_drowned_city() -> void:
	eq(BiomeRegistry.get_def(CITY).spread, BiomeDef.LANDFALL, "the drowned city is the landfall")
	for sd: int in SEEDS:
		var w := WorldGen.generate(sd)
		var leg_1 := StoryJourney.body_for(w, 1)
		var land := _landing(w)
		check(land.x >= 0.0, "seed %d: the raft has a landing" % sd)
		eq(w.continent_at(floori(land.x), floori(land.y)), leg_1, "seed %d: it lands on leg 1's body" % sd)
		check(_in_city(w, land), "seed %d: he steps off the raft at %s into the drowned city" % [sd, land])
		var was := _home(w)
		var guard := NoLandfall.new()
		var off := WorldGen.generate(sd)
		guard = null
		check(not _in_city(off, _landing(off)), "seed %d: without the rule he lands somewhere else" % sd)
		var now := _home(off)
		for k: String in was:
			eq(now[k], was[k], "seed %d: %s holds with the landfall rule and without" % [sd, k])


## THE PORT STANDS WHERE THE RAFT COMES ASHORE: one stair down into the open sea
## on the quay nearest the landfall's `from` (GenBodies.ashore), recorded as the
## `port` row the story lands the raft at, and the clock tower, the one tall line
## a raft steers by, over it. Darted anywhere along the city's shore, seed 1's
## nearest stair stood 66 tiles off the landing and its clock 49 from any stair.
const PORT_SEEDS: Array[int] = [1, 4, 7, 42]
const PORT_OFF := 12.0
## In the frame of a player stepping off the raft (Landmarks LANDFALL_OVER).
const CLOCK_OFF := 20.0


func test_the_port_stands_where_the_raft_comes_ashore() -> void:
	for sd: int in PORT_SEEDS:
		var w := WorldGen.generate(sd, Tuning.WORLD_SIZE)
		var from := GenBodies.ashore(w)
		check(from.is_finite(), "seed %d: the raft has somewhere to come ashore" % sd)
		var ports: Array[Dictionary] = []
		for m: Dictionary in w.landmarks:
			if StringName(str(m.get("kind", &""))) == &"port":
				ports.append(m)
		eq(ports.size(), 1, "seed %d: one port" % sd)
		if not from.is_finite() or ports.size() != 1:
			continue
		var port: Vector2 = ports[0].pos
		var clock := INF
		for site: LandmarkSite in Landmarks.sites(w):
			if site.kind == &"clock_tower":
				clock = minf(clock, site.pos.distance_to(port))
		# The water it goes down into is the sea's (its level, not a canal's).
		var below := port + (ports[0].dir as Vector2) * 1.2
		var sea := Ground.is_water(w.ground_at(floori(below.x), floori(below.y))) and w.level_at(floori(below.x), floori(below.y)) <= 0
		print("  seed %d: the port %.1f from where the raft comes ashore, the clock %.1f from the port, open sea below it: %s" % [sd, port.distance_to(from), clock, sea])
		check(port.distance_to(from) <= PORT_OFF, "seed %d: the port within %.0f of the landing, got %.1f" % [sd, PORT_OFF, port.distance_to(from)])
		check(clock <= CLOCK_OFF, "seed %d: the clock within %.0f of the port, got %.1f" % [sd, CLOCK_OFF, clock])
		check(sea, "seed %d: the port's stair goes down into the open sea at %s" % [sd, below])


## EVERY BODY THE LANDFALL DID NOT TRADE HOLDS ITS LAND, read off the plan (the
## cheaper half of the world): its land, its roads and its climate. Seed 90210's
## landing lies outside the city, and its roads were one tree over every village
## in the world (GenSettle `_road_groups`); on seed 42 the trade shifted the
## stream every climate type's site was jittered from, and moved the scrapwood's
## heart on a third body 200 tiles (GenCountries `_envelope_sites`).
func test_every_body_the_landfall_did_not_trade_holds_its_land() -> void:
	var city := BiomeRegistry.get_def(CITY).index
	# Seed: how many bodies held the city between the two worlds. On 42 the rule
	# traded it across; on 90210 the balance had put it there, and only its heart
	# moves.
	var trades := {42: 2, 90210: 1}
	for sd: int in trades:
		var a := WorldGen.plan(sd)
		var guard := NoLandfall.new()
		var b := WorldGen.plan(sd)
		guard = null
		# The two bodies the city was dealt, with the rule and without, and the
		# continents (a skerry was dealt nothing).
		var traded := {}
		var dealt := {}
		for w: WorldData in [a.w, b.w]:
			for row: Dictionary in w.continents:
				if row.has("types"):
					dealt[int(row.id)] = true
				if (row.get("types", PackedInt32Array()) as PackedInt32Array).has(city):
					traded[int(row.id)] = true
		eq(traded.size(), int(trades[sd]), "seed %d: the bodies that held the city" % sd)
		var moved := {}
		var held := 0
		for i in a.n:
			var body := a.w.continent[i]
			if traded.has(body) or not dealt.has(body):
				continue
			held += 1
			if a.w.level[i] != b.w.level[i] or a.w.ground[i] != b.w.ground[i] or a.w.country[i] != b.w.country[i] or a.w.country2[i] != b.w.country2[i] or a.road[i] != b.road[i] or a.w.moisture[i] != b.w.moisture[i]:
				moved[body] = int(moved.get(body, 0)) + 1
		gt(float(held), 100000.0, "seed %d: bodies the trade did not touch" % sd)
		eq(moved, {}, "seed %d: tiles that move with the landfall rule, by body" % sd)
		eq(a.w.spawn, b.w.spawn, "seed %d: the spawn holds" % sd)
