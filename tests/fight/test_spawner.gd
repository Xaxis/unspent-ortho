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
