extends TestCase
## The slate's edge overlay: readouts show and hide by the rules. Health, the
## clock and the thing in hand always; wind only while some is spent; charges
## only with something in hand that spends them; a pressure only while it is
## felt; the use hint never near a hostile; no text in a fight.


func _hud() -> Hud:
	var hud := Hud.new()
	tree.root.add_child(hud)
	return hud


func _run(hud: Hud, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		hud._process(1.0 / 30.0)
		t += 1.0 / 30.0


func test_the_always_readouts_and_the_quiet_ones() -> void:
	var hud := _hud()
	hud.set_body(12, 12, 2400.0, 2400.0)
	hud.set_held(&"knife")
	hud.set_charge(UiRules.charge_shown(&"knife"), 3)
	hud.settle()
	var s := hud.shown()
	eq(s[&"health"], 1.0)
	eq(s[&"clock"], 1.0)
	eq(s[&"held"], 1.0)
	eq(s[&"wind"], 0.0, "full wind is not shown")
	eq(s[&"charge"], 0.0, "a knife spends no charges: none shown")
	hud.set_body(12, 12, 1200.0, 2400.0)
	_run(hud, 0.5)
	eq(hud.shown()[&"wind"], 1.0, "spent wind comes up")
	hud.set_body(12, 12, 2400.0, 2400.0)
	_run(hud, 1.0)
	eq(hud.shown()[&"wind"], 0.0, "and goes once it is back")
	hud.set_held(&"las_hand")
	hud.set_charge(UiRules.charge_shown(&"las_hand"), 2)
	_run(hud, 0.4)
	eq(hud.shown()[&"charge"], 1.0, "a found weapon in hand shows its charges")
	hud.free()


func test_pressures_come_and_go_as_gauges() -> void:
	var hud := _hud()
	var b := Body.new()
	b.fed_until = 1000.0
	hud.set_pressures(UiRules.pressures(b, 900.0, 5.0))
	hud.settle()
	check(not hud.shown().has(&"cold"), "nothing felt, no gauge")
	b.pressure = {&"cold": 0.8}
	hud.set_pressures(UiRules.pressures(b, 900.0, 5.0))
	_run(hud, 1.0)
	eq(hud.shown().get(&"cold", 0.0), 1.0, "the cold comes up as a gauge")
	b.pressure = {}
	hud.set_pressures(UiRules.pressures(b, 900.0, 5.0))
	_run(hud, 1.0)
	check(not hud.shown().has(&"cold"), "and goes when it no longer presses")
	hud.free()


func test_the_hint_fades_and_the_ping_hushes_in_a_fight() -> void:
	var hud := _hud()
	hud.set_hint("pine - fell")
	_run(hud, 0.3)
	eq(hud.shown()[&"hint"], 1.0, "a hint shows")
	hud.set_hint("")
	_run(hud, 0.3)
	eq(hud.shown()[&"hint"], 0.0, "and fades out")
	hud.show_place("moss")
	_run(hud, 1.0)
	eq(hud.shown()[&"place"], 1.0, "the location ping holds in calm")
	hud.set_quiet(true)
	_run(hud, Hud.PLACE_HUSH + 0.05)
	eq(hud.shown()[&"place"], 0.0, "and is gone in a fight")
	hud.free()


func test_every_hazard_the_land_names_has_a_gauge_glyph() -> void:
	for d in BiomeRegistry.all():
		for h: Variant in d.hazards:
			check(UiIcons.NEEDS.has(StringName(h)), "%s (from %s) has its own glyph" % [h, d.id])
	for id: StringName in [&"cold", &"heat", &"fumes", &"toxins", &"radiation", &"wet", &"dark", &"vacuum", &"pressure", &"em", &"resonance", &"time_shear"]:
		check(UiIcons.NEEDS.has(id), "%s from VISION §6 has a glyph" % id)
	for k: StringName in UiIcons.NEEDS:
		var rows: Array = UiIcons.NEEDS[k]
		eq(rows.size(), 9, "%s is 9 rows" % k)
		for r: String in rows:
			eq(r.length(), 9, "%s is 9 wide" % k)
	eq(UiIcons.pressure_rows(&"no_such_hazard"), UiIcons.PRESSURE_ANY, "an unknown pressure still has a gauge")

