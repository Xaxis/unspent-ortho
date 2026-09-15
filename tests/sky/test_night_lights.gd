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
	var moon: float = SkyLight.sun_at(1.0).energy
	var add := Lights.compensate(Lights.WARM, night, moon)
	# On screen at the centre of the pool: srgb(lin(tint) * (lin(moon) + lamp)).
	var seen := Vector3.ZERO
	for i in 3:
		seen[i] = pow(pow(night[i], 2.2) * (pow(moon, 2.2) + add[i]), 1.0 / 2.2)
	lt((seen - Lights.WARM).length(), 1e-3, "the pool shows the lamp's own colour: %s" % seen)
	gt(seen.x, seen.z, "the pool is warm, not blue")
	# By day a lamp adds nothing a surface would show.
	var noon := Lights.compensate(Lights.WARM, SkyLight.tint_at(12.0), 1.0)
	lt(noon.length(), 0.05, "no pool at noon")


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


func test_a_pool_of_lamplight_only_shows_once_it_is_dark() -> void:
	near(Lights.pool_dark(12.0), 0.0, 1e-6, "noon")
	near(Lights.pool_dark(19.5), 0.0, 1e-6, "lamps lit at dusk, no pool yet")
	gt(Lights.pool_dark(20.5), 0.5, "pool as the dark comes")
	near(Lights.pool_dark(23.0), 1.0, 1e-6, "full at night")
	near(Lights.pool_dark(6.5), 0.0, 1e-6, "gone after dawn")
	var prev := Lights.pool_dark(0.0)
	for i in 24 * 60:
		var d := Lights.pool_dark(i / 60.0)
		lt(absf(d - prev), 0.03, "no jump at %.2f" % (i / 60.0))
		prev = d
