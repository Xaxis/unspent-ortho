extends TestCase

const Lights := preload("res://src/systems/15_lights.gd")
const SkySystem := preload("res://src/systems/10_sky.gd")


func test_lamps_are_lit_from_dusk_to_first_light_only() -> void:
	near(Lights.lamps_wanted(12.0), 0.0, 1e-6, "noon")
	near(Lights.lamps_wanted(22.0), 1.0, 1e-6, "night")
	near(Lights.lamps_wanted(3.0), 1.0, 1e-6, "small hours")
	near(Lights.lamps_wanted(7.0), 0.0, 1e-6, "morning")
	gt(Lights.lamps_wanted(20.0), 0.3, "lit before full dark")
	lt(Lights.lamps_wanted(20.0), 1.0, "still lighting up")
	near(Lights.lamps_wanted(24.0), Lights.lamps_wanted(0.0), 1e-6, "wraps")


func test_windows_light_one_by_one_and_most_go_dark_after_midnight() -> void:
	var lit_at_2030 := 0
	var lit_at_2200 := 0
	var lit_at_0300 := 0
	var lit_at_noon := 0
	for i in 200:
		var s := {"kind": PropKind.HOUSE, "h": Rng.hash01(1, i, 1), "h2": Rng.hash01(1, i, 2)}
		lit_at_2030 += 1 if Lights.source_lit(s, 20.0) else 0
		lit_at_2200 += 1 if Lights.source_lit(s, 22.0) else 0
		lit_at_0300 += 1 if Lights.source_lit(s, 3.0) else 0
		lit_at_noon += 1 if Lights.source_lit(s, 12.0) else 0
	eq(lit_at_noon, 0, "no lit windows at noon")
	gt(lit_at_2200, lit_at_2030, "more windows as the night comes on")
	gt(lit_at_2200, 150, "most houses lit in the evening")
	lt(lit_at_0300, lit_at_2200 * 0.6, "most go dark after midnight")
	gt(lit_at_0300, 10, "a few keep a light all night")


func test_fires_always_burn() -> void:
	var s := {"kind": PropKind.FIRE, "h": 0.3, "h2": 0.3}
	check(Lights.source_lit(s, 12.0), "fire at noon")
	check(Lights.source_lit(s, 2.0), "fire at night")


func test_lamplight_stays_warm_under_a_blue_night() -> void:
	var night := SkyLight.tint_at(1.0)
	var add := Lights.compensate(Lights.WARM, night)
	# What the eye sees at the centre of the pool is albedo * tint * (moon + lamp).
	var seen := night * (Vector3.ONE * Weather.light_level(1.0) + add)
	gt(seen.x, seen.z, "the pool is warm, not blue")
	gt(seen.x, 0.8, "the pool is bright")


func test_sky_system_blends_countries_at_a_border() -> void:
	var w := WorldData.new(1, 16)
	for i in w.country.size():
		w.country[i] = Country.COAST if (i % 16) < 8 else Country.SNOWFIELD
	var sys := SkySystem.new()
	var g := Game.new()
	g.world = w
	sys.game = g
	var inside := sys.sample_countries(Vector2(2, 8))
	near(float(inside.get(Country.COAST, 0.0)), 5.0 / 6.0, 1e-6, "mostly coast near the west edge")
	var border := sys.sample_countries(Vector2(8, 8))
	gt(float(border.get(Country.SNOWFIELD, 0.0)), 0.5, "snowfield once over the line")
	gt(float(border.get(Country.COAST, 0.0)), 0.0, "coast still in the mix")
	w.blend[8 * 16 + 8] = 0.5
	w.country2[8 * 16 + 8] = Country.COAST
	var soft := sys.sample_countries(Vector2(8, 8))
	gt(float(soft.get(Country.COAST, 0.0)), float(border.get(Country.COAST, 0.0)), "ecotone blend shares the tile")
	sys.free()
	g.free()


func test_boot_option_forces_weather() -> void:
	var o := BootOptions.parse(PackedStringArray(["--weather=fog:0.6", "--lamp"]))
	eq(o.weather, "fog:0.6", "weather option")
	check(o.lamp, "lamp option")
