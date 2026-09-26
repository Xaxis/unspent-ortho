extends TestCase
## The spawner keeps each body to its country, ground, hour, day and weather,
## puts it in the ring 11-18 tiles out where the camera cannot see, and never
## lets more than six live.

const F := preload("res://tests/fight/fixture.gd")


func _moment(hour: float, day: int = 1) -> Moment:
	var m := Moment.new()
	m.seed_value = 3
	m.minutes = (day - 1) * 1440.0 + hour * 60.0
	return m


func test_harvester_keeps_to_coast_fields() -> void:
	var row := Roster.row(&"harvester")
	var coast := F.flat_world(48, Ground.GRASS, Country.COAST)
	check(Spawner.place_fits(row, coast, WorldQuery.new(coast), 20, 20), "coast grass")
	var burning := F.flat_world(48, Ground.GRASS, Country.BURNING)
	check(not Spawner.place_fits(row, burning, WorldQuery.new(burning), 20, 20), "never in the burning country")
	var sand := F.flat_world(48, Ground.SAND, Country.COAST)
	check(not Spawner.place_fits(row, sand, WorldQuery.new(sand), 20, 20), "not on the sand")
	coast.villages.append({"pos": Vector2(25.5, 25.5), "country": Country.COAST, "name": "v"})
	check(not Spawner.place_fits(row, coast, WorldQuery.new(coast), 20, 20), "not within 22 of a village")


func test_each_country_has_its_own() -> void:
	var clerk := Roster.row(&"clerk")
	var ash := F.flat_world(32, Ground.ASH, Country.BURNING)
	check(Spawner.place_fits(clerk, ash, null, 10, 10))
	var ash_coast := F.flat_world(32, Ground.ASH, Country.COAST)
	check(not Spawner.place_fits(clerk, ash_coast, null, 10, 10), "a clerk only in the burning country")
	var dredger := Roster.row(&"dredger")
	var fen := F.flat_world(32, Ground.BLACKWATER, Country.MOSS)
	check(Spawner.place_fits(dredger, fen, null, 10, 10), "a dredger in fen water")
	var dry := F.flat_world(32, Ground.GRASS, Country.MOSS)
	check(not Spawner.place_fits(dredger, dry, null, 10, 10), "never on dry ground")
	var pine := F.flat_world(32, Ground.NEEDLES, Country.PINEWOOD)
	check(Spawner.place_fits(Roster.row(&"warden"), pine, null, 10, 10))
	check(not Spawner.place_fits(Roster.row(&"warden"), dry, null, 10, 10))


func test_hours_wrap_past_midnight() -> void:
	var warden := Roster.row(&"warden")
	check(Spawner.moment_fits(warden, _moment(22.0)), "curfew at 22:00")
	check(Spawner.moment_fits(warden, _moment(4.5)), "and at 04:30")
	check(not Spawner.moment_fits(warden, _moment(5.0)), "over at 05:00")
	check(not Spawner.moment_fits(warden, _moment(12.0)), "never at noon")
	var sweeper := Roster.row(&"sweeper")
	check(Spawner.moment_fits(sweeper, _moment(6.0)))
	check(not Spawner.moment_fits(sweeper, _moment(11.0)))


func test_days_and_weather() -> void:
	var watcher := Roster.row(&"watcher")
	check(not Spawner.moment_fits(watcher, _moment(12.0, 1)), "no watcher on the first day")
	check(Spawner.moment_fits(watcher, _moment(12.0, 2)))
	check(not Spawner.moment_fits(Roster.row(&"dog.feral"), _moment(12.0, 5)))
	check(Spawner.moment_fits(Roster.row(&"dog.feral"), _moment(12.0, 6)))
	var flock := Roster.row(&"flock")
	var fog := _moment(10.0)
	fog.weather = &"fog"
	fog.weather_strength = 0.8
	check(Spawner.moment_fits(flock, fog), "the flock flies in fog")
	var rain := _moment(10.0)
	rain.weather = &"rain"
	rain.weather_strength = 0.8
	check(not Spawner.moment_fits(flock, rain), "not in rain")
	var windy := _moment(10.0)
	windy.wind = 0.7
	check(not Spawner.moment_fits(flock, windy), "and never in wind")


func test_rolls_land_in_the_ring_out_of_view() -> void:
	var w := F.flat_world(96, Ground.GRASS, Country.COAST)
	var q := WorldQuery.new(w)
	var s := Spawner.new()
	s.rate = 200.0
	var centre := Vector2(48.5, 48.5)
	var m := _moment(12.0, 3)
	var got := 0
	for i in 160:
		var r := s.roll(i, w, q, m, centre, 0)
		if r.is_empty():
			continue
		got += 1
		var d := Senses.chebyshev(r.pos, centre)
		check(d >= Spawner.RING_MIN - 0.01 and d <= Spawner.RING_MAX + 0.01, "in the ring, got %f" % d)
		check(not s.in_view(centre, r.pos), "never where the camera can see: %s" % r.pos)
		check(Spawner.place_fits(Roster.row(r.kind), w, q, floori(r.pos.x), floori(r.pos.y)), "%s fits where it stands" % r.kind)
		check(r.kind != &"clerk" and r.kind != &"warden" and r.kind != &"dredger", "nothing from another country: %s" % r.kind)
	gt(got, 10.0, "it does put things out")
	eq(s.roll(1, w, q, m, centre, Spawner.MAX_LIVING), {}, "six living is the most")


func test_the_source_rate_is_rare() -> void:
	var w := F.flat_world(96, Ground.GRASS, Country.COAST)
	var q := WorldQuery.new(w)
	var s := Spawner.new()
	var got := 0
	for i in 3000: # ten minutes of rolls
		if not s.roll(i, w, q, _moment(12.0, 3), Vector2(48.5, 48.5), 0).is_empty():
			got += 1
	check(got >= 3 and got <= 60, "seen often, met rarely: %d in ten minutes" % got)


func test_cull_past_24() -> void:
	check(not Spawner.should_cull(Vector2(24, 0), Vector2.ZERO))
	check(Spawner.should_cull(Vector2(24.5, 3), Vector2.ZERO))


## A staging token, which boot's `--spawn`, the tour's `spawn` and the test that
## holds tours to their claims all read through one door so they cannot drift.
func test_a_staged_token_may_carry_a_bearing() -> void:
	var plain := Spawner.staged("runner")
	eq(plain.id, Roster.resolve("runner"), "a bare token is just the kind")
	check(is_nan(plain.facing), "and asks for no bearing, so it faces the player")
	eq(Spawner.staged("  runner  ").id, Roster.resolve("runner"), "spaces around it are nothing")
	var turned := Spawner.staged("runner@-112")
	eq(turned.id, Roster.resolve("runner"), "a bearing does not hide the kind")
	near(turned.facing, deg_to_rad(-112.0), 1e-6, "degrees in, radians out")
	near(Spawner.staged("sweeper@-45").facing, deg_to_rad(-45.0), 1e-6)
	near(Spawner.staged("runner@0").facing, 0.0, 1e-6, "zero is a bearing, not an absence")
	eq(Spawner.staged("nothing_by_that_name").id, &"", "an unknown kind is empty, and every reader fails on it")


## The one arithmetic anybody will get wrong. `tests/models/test_machines_silhouette.gd`
## turns a model by `Basis(UP, yaw)` and rasterises it through the GAME camera's
## own basis, and a body in the world is drawn at `rotation.y = -facing`
## (`src/actors/mob.gd`), so reproducing a measured yaw is `facing = -yaw` and
## nothing else — no correction for where the camera stands, because the test is
## already looking down it. A sign error here is a frame labelled "the worst
## bearing" that is of a different one.
func test_a_measured_yaw_is_reproduced_by_its_negation() -> void:
	for yaw: float in [0.6, 0.79, 1.96, 2.3]:
		var token := "runner@%.4f" % -rad_to_deg(yaw)
		near(-Spawner.staged(token).facing, yaw, 1e-4, "yaw %.2f is asked for as %s" % [yaw, token])


## A landscape may make a kind its own (mechanics pass 3a): its roster row's
## `over` rewrites the base row for every body of that kind put down on its
## ground, and the body fights, senses and reads on the slate by the rewritten
## row. The cave hauler works the dark by ear, and it tells longer.
func test_a_landscape_makes_a_kind_its_own() -> void:
	var caves := BiomeRegistry.get_def(&"limestone_caves")
	var over: Dictionary = caves.roster.get(&"hauler", {}).get("over", {})
	check(not over.is_empty(), "the caves declare a hauler of their own")
	var w := F.flat_world(48, Ground.LIMESTONE, caves.index)
	var sim := F.make_sim(w, Vector2(10.5, 10.5))
	var there := sim.add_mob(&"hauler", Vector2(20.5, 20.5))
	var base := Roster.row(&"hauler")
	for k: String in over:
		if k == "bite":
			continue
		eq(there.stat(k), over[k], "the cave hauler's %s is the caves'" % k)
	eq(there.bite.windup, int((over.get("bite", {}).get("swing", base.bite.swing) as Array)[0]), "and so is its tell")
	var home := F.flat_world(48, Ground.LIMESTONE, Country.BONELANDS)
	var sim2 := F.make_sim(home, Vector2(10.5, 10.5))
	var plain := sim2.add_mob(&"hauler", Vector2(20.5, 20.5))
	eq(plain.stat("sees"), base.sees, "a bonelands hauler is the roster's")
	eq(plain.bite.windup, int((base.bite.swing as Array)[0]), "tell and all")
	eq(Roster.row(&"hauler").sees, base.sees, "and the roster row itself is untouched")
	var read := TargetRead.stats(there, there.pos + Vector2(3, 0))
	var tell := ""
	for pair: Array in read:
		if pair[0] == "tell":
			tell = String(pair[1])
	eq(tell, "%d ms" % there.bite.windup, "the slate reads the cave hauler's own tell")
