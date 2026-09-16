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


func test_a_held_strike_stands_where_the_light_and_the_works_both_read() -> void:
	# A shot of a strike (--weather=kind:s:bolt) freezes one moment. It must be
	# one where the cloud is lit AND the machines' power is back, or every still
	# of a storm shows a dark grid and an afterglow that has let go.
	gt(SkySystem.afterglow(SkySystem.HELD_STRIKE), 0.5, "the held moment is the cloud at its brightest")
	gt(SkySystem.machine_power(SkySystem.HELD_STRIKE), 0.9, "and the machines are back between two dips")


func test_a_drawn_strike_lands_on_the_page() -> void:
	# The bolt is drawn where it lands; a strike that walks off the screen to
	# find a tall prop is only thunder.
	var o := BootOptions.new()
	o.size = 96
	o.hour = 20.2
	o.weather = "dry_storm:1:bolt"
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	# Long enough for the sky to have composed a frame of its own after the strike.
	await frames(12)
	var sky_sys: Node = null
	for s in g.systems:
		if s.get_script() == SkySystem:
			sky_sys = s
	check(sky_sys != null, "sky system loaded")
	eq(sky_sys.strikes, 1, "a forced bolt strikes once")
	var v: WeatherView = sky_sys.view
	check(v.bolt.visible, "and the bolt is drawn")
	var here := Vector2(g.camera.target.x, g.camera.target.z)
	var at := Vector2(v.bolt.ground.x, v.bolt.ground.z)
	lt(absf(at.x - here.x), SkySystem.STRIKE_REACH.x + 0.01, "east-west, on the page")
	lt(absf(at.y - here.y), SkySystem.STRIKE_REACH.y + 0.01, "north-south, on the page")
	gt(g.sky.bolt.z, 0.1, "the cloud carries its afterglow")
	gt(g.sky.bolt.w, 0.9, "and the machines are lit in the same frame")
	g.queue_free()
	await frames(1)
	Weather.unforce()


func test_a_held_bolt_asked_for_mid_play_is_struck_and_not_only_flagged() -> void:
	# A tour asks for a held bolt with `weather dry_storm:1:bolt` in the middle of
	# a game. Setting the flag alone holds the sky at the brightest moment of a
	# strike with no lightning drawn anywhere in it, which is a still of nothing.
	var o := BootOptions.new()
	o.size = 96
	o.hour = 20.2
	o.weather = "clear:0"
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	await frames(6)
	var sky_sys: Node = null
	for s in g.systems:
		if s.get_script() == SkySystem:
			sky_sys = s
	check(sky_sys != null, "sky system loaded")
	eq(sky_sys.strikes, 0, "a clear sky throws none")
	check(bool(sky_sys.call("apply_weather", "dry_storm:1:bolt")), "the storm is forced")
	await frames(6)
	eq(sky_sys.strikes, 1, "and a bolt is struck for the still")
	check((sky_sys.view as WeatherView).bolt.visible, "drawn, and held while the hold lasts")
	gt(g.sky.bolt.z, 0.1, "the cloud carries its afterglow")
	gt(g.sky.bolt.w, 0.9, "and the machines are lit in the same frame")
	# Asking again for the same held sky does not throw a second bolt.
	check(bool(sky_sys.call("apply_weather", "dry_storm:1:bolt")), "asked again")
	await frames(3)
	eq(sky_sys.strikes, 1, "one held bolt, however often it is asked for")
	# And the moment the hold goes, the lightning goes with it: a bolt left drawn
	# would hang over the next weather, the next hour and the next landscape.
	check(bool(sky_sys.call("apply_weather", "glare:1")), "the storm gives way to a hard noon")
	await frames(3)
	check(not (sky_sys.view as WeatherView).bolt.visible, "no lightning left standing in the glare")
	check(bool(sky_sys.call("apply_weather", "rules")), "and the sky is handed back")
	await frames(3)
	check(not (sky_sys.view as WeatherView).bolt.visible, "still none")
	g.queue_free()
	await frames(1)
	Weather.unforce()


func test_every_machine_light_shader_runs_on_machine_power() -> void:
	for path: String in ["res://src/render/found.gdshader", "res://src/models/machines/part_glow.gdshader"]:
		var code := FileAccess.get_file_as_string(path)
		check(code.contains("sky_power()"), "%s stutters with the machines after a strike" % path.get_file())


## A tube of neon somebody cut off a machine and wired into their wall is the
## machines' light, wherever it ends up: a strike has to stutter the TUBE, not
## only the pool it throws. It gets a ground mark of its own so that a hearth or
## a window in the same wall — drawn by the lamp codes — goes on burning.
func test_stolen_neon_stutters_with_the_machines_and_a_hearth_does_not() -> void:
	var code := FileAccess.get_file_as_string("res://src/render/world.gdshader")
	var neon := code.find("m == %d" % GroundColors.NEON)
	gt(float(neon), 0.0, "world.gdshader draws the neon mark")
	var branch := code.substr(neon, 900)
	check(branch.contains("sky_power()"), "and runs it on the machines' power")
	var lamps := code.find("m >= 17 && m <= 32")
	gt(float(lamps), 0.0, "the lamp codes are still drawn")
	check(not code.substr(lamps, 300).contains("sky_power()"), "and a hearth keeps burning")
	check(GroundColors.NEON != GroundColors.GLINT and GroundColors.NEON > GroundColors.LAMP + 16,
		"the neon mark is its own code, clear of the lamps and the glint")
	# And the pool it lays on the ground stutters with it, or the same light
	# would disagree with itself on one wall.
	var lights := load("res://src/systems/15_lights.gd") as GDScript
	var powered: Array = lights.get_script_constant_map()["POWERED_SOURCES"]
	check(powered.has(PropKind.SHACK), "a shack's stolen neon is on the machines' power")


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


func test_in_real_dust_a_devil_is_always_in_sight() -> void:
	var focus := Vector2(200, 200)
	var homes: Array = []
	var spawned := 0
	var minute := 5000.0
	for step in 240:
		# Walk a while, then stand, then walk back: a devil stays on screen.
		if step < 80:
			focus += Vector2(1.6, 0.4)
		elif step > 160:
			focus -= Vector2(0.9, 1.3)
		var list := DustDevils.at(3, minute, focus, 0.7, Vector2.RIGHT)
		var kept := DustDevils.keep_one(list, homes, 3, minute, focus, 0.7, Vector2.RIGHT, step == 0)
		if kept.homes.size() > homes.size() or (kept.homes.size() > 0 and homes.size() > 0 and kept.homes[-1] != homes[-1]):
			spawned += 1
		homes = kept.homes
		var in_sight := false
		for d: Dictionary in kept.list:
			if DustDevils.on_screen(d.pos, focus) and float(d.life) > 0.0:
				in_sight = true
		check(in_sight, "a devil in sight at step %d" % step)
		lt(float(kept.list.size()), DustDevils.MAX + 1.0, "never more than a few drawn")
		minute += 1.0
	lt(float(spawned), 60.0, "a home devil lives its life rather than being replaced every step")
	var calm := DustDevils.keep_one(DustDevils.at(3, minute, focus, 0.3, Vector2.RIGHT), [], 3, minute, focus, 0.3, Vector2.RIGHT)
	eq((calm.homes as Array).size(), 0, "light dust raises no devil just to be seen")
	check(DustDevils.on_screen(focus + Vector2(2, 2), focus), "just below the player is on screen")
	check(not DustDevils.on_screen(focus + Vector2(-12, -12), focus), "far up the screen is not")


func test_a_dry_storm_reads_before_its_first_strike() -> void:
	var dry := WeatherLook.compose([{"kind": &"dry_storm", "strength": 1.0, "weight": 1.0}])
	gt(float(dry.dust), DustDevils.DUSTY / 1.2, "blown dust enough to see, and to raise a devil in sight")
	# Sheet lightning: faint stepped flickers in the cloud, no bolt.
	var lit := 0
	var levels := {}
	var windows := {}
	for i in 6000:
		var t := i * 0.01
		var sh := SkySystem.sheet(9, t, 1.0)
		var level := float(sh.level)
		check(level >= 0.0 and level <= 1.0, "level in range")
		if level > 0.0:
			lit += 1
			levels[snappedf(level, 0.01)] = true
			windows[floori(t / SkySystem.SHEET_SECONDS)] = true
			var at: Vector2 = sh.at
			check(at.length() >= 3.9 and at.length() <= 12.1, "the lit cloud is in view, off the player")
	gt(float(windows.size()), 8.0, "most windows of a minute flicker in a full storm")
	lt(float(lit), 6000.0 * 0.2, "a flicker, never a glow that stays")
	gt(float(levels.size()), 1.0, "stepped, not one flash")
	var calm := 0
	for i in 6000:
		if float(SkySystem.sheet(9, i * 0.01, 0.0).level) > 0.0:
			calm += 1
	eq(calm, 0, "no sheet lightning with no storm")


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


static func _mood_lum(v: Vector3) -> float:
	return v.x * 0.3 + v.y * 0.59 + v.z * 0.11


## docs/ART.md section 3 promises each landscape its own evening by name, and a
## SkyLight.MOOD row is where that promise is kept. Now that there is a dusk to
## keep it in (Weather.DUSK_START), each row has to say what its dusk is.
func test_every_landscape_keeps_its_own_promise_about_the_evening() -> void:
	# WHEN each row goes, measured at seven, which is the hour the difference
	# between an early dusk and a long one is most of the picture.
	# Measured against each row's OWN afternoon, because an early dusk is about
	# WHEN a row falls, not how far below its own night it dips (SkyLight.MOOD).
	var left := func(id: StringName, h: float) -> float:
		return _mood_lum(SkyLight.mood_light(id, h)) / _mood_lum(SkyLight.mood_light(id, 14.0))
	var coast_left: float = left.call(&"coast", 19.0)
	lt(left.call(&"pinewood", 19.0), coast_left - 0.05, "an early dusk under the pines")
	lt(left.call(&"moss", 19.0), coast_left - 0.02, "and in the moss, whose gloom is mostly in its washes rather than its light")
	gt(left.call(&"snowfield", 19.0), left.call(&"pinewood", 19.0) + 0.03, "the snowfield's evening is longer: at seven it still has more of its own afternoon than the pines do")
	# HOW FAR each one goes, measured at its own darkest key rather than at a
	# shared hour: a row that reached its floor at half six is not a row that has
	# not fallen by eight.
	var snow := SkyLight.mood_light(&"snowfield", 19.5)
	gt(snow.z - snow.x, 0.2, "and its last hour is hard blue")
	var bone_day := _mood_lum(SkyLight.mood_light(&"bonelands", 16.0))
	gt(bone_day, 0.96, "the bonelands keep a hard white afternoon")
	lt(_mood_lum(SkyLight.mood_light(&"bonelands", 19.4)), bone_day - 0.085, "and fall hard off the end of it")
	var burn_eve := SkyLight.mood_light(&"burning", 19.6)
	var burn_night := SkyLight.mood_light(&"burning", 23.0)
	gt(burn_eve.x - burn_eve.z, 0.3, "the burning's dusk is a furnace")
	gt(burn_night.x - burn_night.z, 0.12, "and its night is still warm where every other land has gone blue")
	for id: StringName in SkyLight.MOOD:
		if id == &"burning" or id == &"bonelands":
			continue
		var night := SkyLight.mood_light(id, 23.0)
		lt(night.x - night.z, 0.0, "%s's night is not warm" % id)
	# Every row SETTLES at nine and does not move again until the morning: a mood
	# that climbs back to a bright midnight key after the light has stopped
	# falling is a land brightening through the small hours (art review finding 2
	# in slow motion). What that does to a whole frame is pinned on the composed
	# picture in tests/sky/test_night_readable.gd; here it is pinned on the rows.
	for id: StringName in SkyLight.MOOD:
		var keys: Array = SkyLight.MOOD[id]
		var settle: float = float((keys[keys.size() - 1] as Array)[0])
		lt(settle, 21.0, "%s settles while the sun is still going, not after" % id)
		gt(settle, 20.0, "%s settles after the worst of the fall, not before it" % id)
		var settled := _mood_lum(SkyLight.mood_light(id, settle))
		var h := settle
		while h <= 24.0001:
			lt(_mood_lum(SkyLight.mood_light(id, h)), settled + 0.005,
				"%s's own light climbs at %.2f h, after the sun has stopped falling" % [id, fposmod(h, 24.0)])
			h += 0.25


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
	lt(SkyLight.mood_light(&"pinewood", 18.0).y / SkyLight.mood_light(&"pinewood", 15.5).y, SkyLight.mood_light(&"coast", 18.0).y / SkyLight.mood_light(&"coast", 15.5).y - 0.05, "dusk comes early under the pines")
	var moss := SkyLight.mood_light(&"moss", 6.0)
	gt(moss.y, moss.x, "the moss's gloom is green")
	eq(SkyLight.mood_light(&"salt_flats", 9.0), Vector3.ONE, "a type with no mood keeps the plain hour")


func test_the_sky_reads_landscape_types_through_the_registry_not_countries() -> void:
	# A Salt Flats or Scrapwood row in CLIMATES, MOOD, CAST or CANOPY_DRIP must be
	# read the moment BiomeRegistry names that type: the sky never goes through
	# Country or the legacy at_place.
	var text := FileAccess.get_file_as_string("res://src/systems/10_sky.gd")
	for banned: String in ["Country.", "at_place(", "type_of(", "Weather.settled("]:
		eq(text.find(banned), -1, "10_sky does not use %s" % banned)
	var salt := BiomeDef.new()
	salt.id = &"salt_flats"
	salt.light_tint = Color(0.9, 0.8, 0.7)
	var l := SkyLight.type_light(salt, 12.0)
	lt((l - Vector3(0.9, 0.8, 0.7)).length(), 1e-4, "a new type's own light_tint is its light until it has rows")
	var burn := SkyLight.type_light(BiomeRegistry.get_def(&"burning"), 19.8)
	gt(burn.x, burn.z + 0.3, "the burning's dusk light is a furnace")
	eq(SkyLight.type_light(null, 9.0), Vector3.ONE, "nothing named, nothing added")
	var o := BootOptions.new()
	o.size = 64
	o.hour = 12.0
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	var sky_sys: Node = null
	for s in g.systems:
		if s.get_script() == SkySystem:
			sky_sys = s
	await frames(2)
	var f := g.camera.target
	eq(sky_sys.get("here"), BiomeRegistry.at(g.world, Vector2(f.x, f.z)).id, "the weather that falls is the registry's type under the focus")
	var shares: Dictionary = g.sky.neon_shares
	for k: Variant in shares:
		check(k is StringName, "light and mood blend by type id: %s" % [k])
	g.queue_free()
	await frames(1)
