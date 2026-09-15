extends TestCase
## Mood per landscape and hour (docs/VISION.md section 8, docs/ART.md section
## 6): squalls that come and go, dawn mist lying in the moss, lightning with its
## afterglow and the machines' stutter, drips after rain, dust devils on hot
## ground. Every rule pure, so shots and play agree.

const SkySystem := preload("res://src/systems/10_sky.gd")


func test_coast_rain_comes_in_squalls_that_sweep_in_and_pass() -> void:
	Weather.unforce()
	# Find a coast rain spell and walk it: its strength rises and falls in bands.
	var found := false
	for spell in 300:
		if Weather.kind_for(1, spell, Country.COAST) != Weather.RAIN:
			continue
		found = true
		var start := Weather.spell_start(1, spell)
		var mid := start + Weather.SPELL_MINUTES * 0.5
		var lo := INF
		var hi := 0.0
		var prev := -1.0
		var turns := 0
		var rising := true
		var m := mid - 180.0
		while m < mid + 180.0:
			var st := float(Weather.at_place(1, m, Country.COAST).strength)
			lo = minf(lo, st)
			hi = maxf(hi, st)
			if prev >= 0.0:
				var up := st > prev
				if up != rising and absf(st - prev) > 1e-4:
					turns += 1
					rising = up
			prev = st
			m += 2.0
		gt(hi, 0.8, "a squall comes through at full")
		lt(lo, hi * 0.45, "and between squalls it eases right off")
		gt(float(turns), 3.0, "several squalls in six hours")
		break
	check(found, "the coast gets rain")
	# Steady kinds do not pulse.
	near(Weather.squall_gain(1, 500.0, 0.0), 1.0, 1e-6, "a steady kind is its envelope")
	for i in 200:
		var g := Weather.squall_gain(7, i * 13.0, 0.75)
		check(g >= Weather.SQUALL_FLOOR - 1e-6 and g <= 1.0 + 1e-6, "gain in range")


func test_dawn_mist_lies_in_the_moss_and_burns_off() -> void:
	Weather.unforce()
	var day := 3 * 1440.0
	var moss_dawn := Weather.mist(4, day + 5.8 * 60.0, &"moss")
	gt(moss_dawn, 0.35, "the moss lies in mist at dawn")
	near(Weather.mist(4, day + 12.0 * 60.0, &"moss"), 0.0, 1e-6, "gone by noon")
	near(Weather.mist(4, day + 22.0 * 60.0, &"moss"), 0.0, 1e-6, "none at night's start")
	near(Weather.mist(4, day + 5.8 * 60.0, &"bonelands"), 0.0, 1e-6, "no mist on dry stone")
	near(Weather.mist(4, day + 5.8 * 60.0, &"burning"), 0.0, 1e-6, "none over the burning")
	lt(Weather.mist(4, day + 5.8 * 60.0, &"coast"), moss_dawn, "the coast's sea fret is thinner")
	lt(Weather.mist(4, day + 5.8 * 60.0, &"moss", Weather.CLEAR, 0.0, 0.9), moss_dawn * 0.2, "a wind blows it off")
	var prev := Weather.mist(4, day, &"moss")
	for i in 1441:
		var mm := Weather.mist(4, day + i, &"moss")
		lt(absf(mm - prev), 0.02, "mist never jumps (minute %d)" % i)
		prev = mm
	check(Weather.at_place(4, day + 5.8 * 60.0, Country.MOSS).has("mist"), "at_place says the mist")


func test_afterglow_and_stutter_are_a_beat_then_steady() -> void:
	near(SkySystem.machine_power(-1.0), 1.0, 1e-6, "steady before")
	near(SkySystem.machine_power(INF), 1.0, 1e-6, "steady long after")
	near(SkySystem.machine_power(1.5), 1.0, 1e-6, "back within a second and a half")
	var dropped := false
	var came_back_between := false
	var was_down := false
	for i in 100:
		var p := SkySystem.machine_power(i * 0.01)
		check(p >= 0.0 and p <= 1.0, "power in range")
		if p < 0.2:
			dropped = true
			was_down = true
		elif was_down and p > 0.5:
			came_back_between = true
	check(dropped, "the lights drop out")
	check(came_back_between, "and catch again before steadying: a stutter, not a fade")
	near(SkySystem.afterglow(0.0), 0.0, 1e-6, "the flash itself is the first frames")
	gt(SkySystem.afterglow(0.2), 0.5, "the cloud catches")
	near(SkySystem.afterglow(3.0), 0.0, 1e-6, "and lets go")
	var levels := {}
	for i in 160:
		levels[snappedf(SkySystem.afterglow(i * 0.01), 0.01)] = true
	gt(float(levels.size()), 4.0, "it rolls: several steps, not one")


func test_drips_run_with_rain_and_after_it_while_the_ground_is_wet() -> void:
	near(Drips.amount(0.0, 0.0), 0.0, 1e-6, "dry and still: nothing drips")
	gt(Drips.amount(0.8, 0.2), 0.7, "rain drips")
	gt(Drips.amount(0.0, 0.9), 0.3, "a wet world keeps dripping after the rain")
	var props: Array[WorldProp] = [
		WorldProp.new(0, PropKind.HOUSE, Vector2(10, 10), 0.3, 1.0),
		WorldProp.new(1, PropKind.PYLON, Vector2(12, 10), 0.0, 1.0),
		WorldProp.new(2, PropKind.BOULDER, Vector2(11, 11), 0.0, 1.0),
		WorldProp.new(3, PropKind.PINE, Vector2(40, 40), 0.0, 1.0),
	]
	var ground := func(p: Vector2) -> Vector3: return Vector3(p.x, 1.0, p.y)
	var pts := Drips.points(props, Vector2(10, 10), 1, ground)
	eq(pts.size(), int(Drips.SOURCES[PropKind.HOUSE][2]) + int(Drips.SOURCES[PropKind.PYLON][2]), "eaves and arms drip; a boulder and a far pine do not")
	for p in pts:
		gt(p.y, 1.5, "drips fall from above the ground")
	var taken := Drips.points(props, Vector2(10, 10), 1, ground, {0: true})
	eq(taken.size(), int(Drips.SOURCES[PropKind.PYLON][2]), "a taken house drips no more")
	eq(Drips.points(props, Vector2(10, 10), 1, ground), pts, "seeded: the same points twice")


func test_dust_devils_rise_on_dusty_ground_and_wander() -> void:
	eq(DustDevils.at(1, 100.0, Vector2(50, 50), 0.0, Vector2.RIGHT).size(), 0, "no devils in still clean air")
	var seen := 0
	var moved := false
	for i in 60:
		var list := DustDevils.at(1, i * 3.0, Vector2(50, 50), 1.0, Vector2.RIGHT)
		lt(float(list.size()), DustDevils.MAX + 1.0, "never more than a few")
		seen += list.size()
		for d: Dictionary in list:
			check(float(d.life) > 0.0 and float(d.life) <= 1.0, "alive")
			var later := DustDevils.at(1, i * 3.0 + 2.0, Vector2(50, 50), 1.0, Vector2.RIGHT)
			for e: Dictionary in later:
				if int(e.seed) == int(d.seed) and (e.pos as Vector2).distance_to(d.pos) > 0.05:
					moved = true
	gt(float(seen), 20.0, "devils come and go through three minutes of dust")
	check(moved, "a devil wanders")


func test_new_weathers_draw_their_own_airs() -> void:
	var drizzle := WeatherLook.compose([{"kind": &"drizzle", "strength": 1.0, "weight": 1.0}])
	gt(float(drizzle.drizzle), 0.5, "drizzle falls as drizzle")
	lt(float(drizzle.rain), 0.01, "not as rain strokes")
	var white := WeatherLook.compose([{"kind": &"whiteout", "strength": 1.0, "weight": 1.0}])
	gt(float(white.whiteout), 0.9, "a whiteout whites out")
	gt(float(white.snow), 0.5, "in snow")
	var glare := WeatherLook.compose([{"kind": &"glare", "strength": 1.0, "weight": 1.0}])
	gt(float(glare.glare), 0.9, "glare bleaches")
	lt(float(glare.overcast), 0.1, "under an open sky, so shadows are hard")
	var dry := WeatherLook.compose([{"kind": &"dry_storm", "strength": 1.0, "weight": 1.0}])
	gt(float(dry.bolt), 0.9, "dry lightning")
	lt(float(dry.rain), 0.01, "with no rain in it")
	var haze := WeatherLook.compose([{"kind": &"haze", "strength": 1.0, "weight": 1.0}])
	gt(WeatherLook.haze_share(haze), 0.9, "furnace haze is drawn warm")
	near(WeatherLook.haze_share(WeatherLook.compose([{"kind": &"fog", "strength": 1.0, "weight": 1.0}])), 0.0, 1e-6, "a mist is pale")


func test_a_running_game_throws_dry_lightning_with_afterglow_and_stutter() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 21.5
	o.weather = "dry_storm:1"
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	var sky_sys: Node = null
	for s in g.systems:
		if s.get_script() == SkySystem:
			sky_sys = s
	check(sky_sys != null, "sky system")
	var dipped := false
	var glowed := false
	# Run the clock fast so strikes come within a few frames.
	for i in 240:
		g.clock.minutes += 2.0
		await frames(1)
		if g.sky.bolt.w < 0.5:
			dipped = true
		if g.sky.bolt.z > 0.1:
			glowed = true
		if dipped and glowed:
			break
	gt(float(sky_sys.get("strikes")), 0.0, "dry lightning strikes in a running game")
	check(glowed, "the cloud glows after")
	check(dipped, "and the machines' power dips")
	var mix: Dictionary = sky_sys.get("look")
	lt(float(mix.rain), 0.01, "no rain in it")
	g.queue_free()
	await frames(1)
	Weather.unforce()


func test_each_landscape_leans_its_own_way_by_hour_and_noon_stays_day() -> void:
	for id: StringName in SkyLight.MOOD:
		var noon := SkyLight.mood_light(id, 12.5)
		gt((noon.x + noon.y + noon.z) / 3.0, 0.93, "%s keeps its noon" % id)
		var prev := SkyLight.mood_light(id, 0.0)
		for i in 24 * 12 + 1:
			var m := SkyLight.mood_light(id, i / 12.0)
			lt((m - prev).length(), 0.03, "%s never jumps at %.2f h" % [id, i / 12.0])
			check(m.x <= 1.0 and m.y <= 1.0 and m.z <= 1.0, "%s is a multiply, never a lift" % id)
			prev = m
	var burn_dusk := SkyLight.mood_light(&"burning", 19.8)
	var burn_noon := SkyLight.mood_light(&"burning", 12.0)
	gt(burn_noon.z - burn_dusk.z, 0.2, "the burning's dusk is a furnace")
	var snow_eve := SkyLight.mood_light(&"snowfield", 19.5)
	gt(snow_eve.z - snow_eve.x, 0.15, "the snowfield's evening is long and blue")
	lt(SkyLight.mood_light(&"pinewood", 18.0).y, SkyLight.mood_light(&"coast", 18.0).y - 0.1, "dusk comes early under the pines")
	var moss := SkyLight.mood_light(&"moss", 6.0)
	gt(moss.y, moss.x, "the moss's gloom is green")
	eq(SkyLight.mood_light(&"salt_flats", 9.0), Vector3.ONE, "a type with no mood keeps the plain hour")
