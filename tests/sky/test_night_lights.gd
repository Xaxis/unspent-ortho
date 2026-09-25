extends TestCase

const Lights := preload("res://src/systems/15_lights.gd")
const SkySystem := preload("res://src/systems/10_sky.gd")


func test_lamps_are_lit_from_dusk_to_first_light_only() -> void:
	near(Lights.lamps_wanted(12.0), 0.0, 1e-6, "noon")
	near(Lights.lamps_wanted(22.0), 1.0, 1e-6, "night")
	near(Lights.lamps_wanted(3.0), 1.0, 1e-6, "small hours")
	near(Lights.lamps_wanted(7.0), 0.0, 1e-6, "morning")
	# People light up AS the light fails (SkyLight.day_gone), so the village
	# glows through the dusk rather than coming on after it has gone.
	lt(Lights.lamps_wanted(18.0), 0.05, "six o'clock is still the day")
	gt(Lights.lamps_wanted(19.5), 0.5, "the village is lit by half past seven")
	lt(Lights.lamps_wanted(19.0), Lights.lamps_wanted(19.5), "and was lighting up through it")
	var prev_want := Lights.lamps_wanted(16.0)
	var h := 16.1
	while h <= 23.0:
		var w := Lights.lamps_wanted(h)
		gt(w, prev_want - 1e-6, "no lamp goes out in the evening at %.1f" % h)
		prev_want = w
		h += 0.1
	near(Lights.lamps_wanted(24.0), Lights.lamps_wanted(0.0), 1e-6, "wraps")


func test_windows_light_one_by_one_and_most_go_dark_after_midnight() -> void:
	# Mid-way through the lamps' curve (Lights.LAMPS_FROM..LAMPS_ALL of the light
	# gone, SkyLight.day_gone), which is seven o'clock: people light up as it fails.
	var lit_at_1900 := 0
	var lit_at_2200 := 0
	var lit_at_0300 := 0
	var lit_at_noon := 0
	for i in 200:
		var s := {"kind": PropKind.HOUSE, "h": Rng.hash01(1, i, 1), "h2": Rng.hash01(1, i, 2)}
		lit_at_1900 += 1 if Lights.source_lit(s, 19.0) else 0
		lit_at_2200 += 1 if Lights.source_lit(s, 22.0) else 0
		lit_at_0300 += 1 if Lights.source_lit(s, 3.0) else 0
		lit_at_noon += 1 if Lights.source_lit(s, 12.0) else 0
	eq(lit_at_noon, 0, "no lit windows at noon")
	gt(lit_at_2200, lit_at_1900, "more windows as the night comes on")
	gt(lit_at_1900, 20, "and some are already lit as the light goes")
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


func test_sky_system_blends_landscape_types_at_a_border() -> void:
	var w := WorldData.new(1, 16)
	for i in w.country.size():
		w.country[i] = Country.COAST if (i % 16) < 8 else Country.SNOWFIELD
	var sys := SkySystem.new()
	var g := Game.new()
	g.world = w
	sys.game = g
	var inside := sys.sample_types(Vector2(2, 8))
	gt(float(inside.get(&"coast", 0.0)), 0.8, "mostly coast near the west edge")
	var total := 0.0
	for id: StringName in inside:
		total += float(inside[id])
	near(total, 1.0, 1e-6, "shares sum to one")
	var border := sys.sample_types(Vector2(8, 8))
	gt(float(border.get(&"snowfield", 0.0)), 0.5, "snowfield once over the line")
	gt(float(border.get(&"coast", 0.0)), 0.0, "coast still in the mix")
	var nearer := sys.sample_types(Vector2(6, 8))
	gt(float(nearer.get(&"snowfield", 0.0)), 0.0, "the far ring sees the snowfield coming")
	lt(float(nearer.get(&"snowfield", 0.0)), float(border.get(&"snowfield", 0.0)), "and it grows as the border is walked")
	sys.free()
	g.free()


func test_boot_option_forces_weather() -> void:
	var o := BootOptions.parse(PackedStringArray(["--weather=fog:0.6", "--lamp"]))
	eq(o.weather, "fog:0.6", "weather option")
	check(o.lamp, "lamp option")


func test_a_pool_of_lamplight_only_shows_once_it_is_dark() -> void:
	near(Lights.pool_dark(12.0), 0.0, 1e-6, "noon")
	near(Lights.pool_dark(18.0), 0.0, 1e-6, "a lamp lit in the afternoon lays nothing")
	# The pool follows the dusk now that there is one (Weather.DUSK_START): half
	# way through the evening a hearth has begun to lay light on the ground, which
	# is the whole of docs/LOOK.md section 10 — a settlement is most beautiful, and
	# most worth defending, at dusk.
	gt(Lights.pool_dark(19.5), 0.2, "the light begins to tell as the evening comes on")
	lt(Lights.pool_dark(19.5), 0.7, "but it is nowhere near a night pool")
	gt(Lights.pool_dark(20.5), 0.5, "pool as the dark comes")
	near(Lights.pool_dark(23.0), 1.0, 1e-6, "full at night")
	near(Lights.pool_dark(6.5), 0.0, 1e-6, "gone after dawn")
	var prev := Lights.pool_dark(0.0)
	for i in 24 * 60:
		var d := Lights.pool_dark(i / 60.0)
		lt(absf(d - prev), 0.03, "no jump at %.2f" % (i / 60.0))
		prev = d


func test_wisps_only_over_the_moss_on_a_still_dry_night() -> void:
	gt(SkySystem.wisp_amount(1.0, 1.0, 0.0, 0.0), 0.9, "a still night on the moss")
	near(SkySystem.wisp_amount(0.0, 1.0, 0.0, 0.0), 0.0, 1e-6, "not on the coast")
	near(SkySystem.wisp_amount(1.0, 0.0, 0.0, 0.0), 0.0, 1e-6, "not by day")
	near(SkySystem.wisp_amount(1.0, 1.0, 1.0, 0.0), 0.0, 1e-6, "not in rain")
	near(SkySystem.wisp_amount(1.0, 1.0, 0.0, 0.8), 0.0, 1e-6, "not in a wind")
	lt(SkySystem.wisp_amount(0.5, 1.0, 0.0, 0.0), SkySystem.wisp_amount(1.0, 1.0, 0.0, 0.0), "thinner at the moss's edge")
