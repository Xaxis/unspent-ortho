extends TestCase
## Whatever name a package emits, it finds a sound: every name the fight,
## survival, sky and ui packages were seen emitting resolves to a row on the
## sheet, patterns map verbs, stations, alerts and takings, and unknown names
## stay silent.


func test_every_emitted_name_resolves_to_a_sound() -> void:
	for n: StringName in SoundNames.EMITTED:
		var s := SoundNames.resolve(n)
		if n in SoundNames.SILENT:
			eq(s, &"", "%s is silent on purpose" % n)
			continue
		check(s != &"" and SoundBank.SHEET.has(s), "%s resolves to %s, which is not on the sheet" % [n, s])


func test_aliases_land_on_the_sheet() -> void:
	for n: StringName in SoundNames.ALIAS:
		var s: StringName = SoundNames.ALIAS[n]
		check(s == &"" or SoundBank.SHEET.has(s), "alias %s -> %s" % [n, s])
	for st: StringName in SoundNames.BUILD:
		check(SoundBank.SHEET.has(SoundNames.BUILD[st]), "station %s" % st)
	for c: StringName in SoundNames.CREATURE_ALERT:
		check(SoundBank.SHEET.has(SoundNames.CREATURE_ALERT[c]), "creature %s" % c)


func test_patterns_map_to_the_right_family() -> void:
	eq(SoundNames.resolve(&"work_tap"), &"tap")
	eq(SoundNames.resolve(&"work_fell"), &"fell")
	eq(SoundNames.resolve(&"work_unheard_of"), &"gather", "an unknown verb is a gather")
	eq(SoundNames.resolve(&"build_kiln"), &"build_kiln")
	eq(SoundNames.resolve(&"build_loom"), &"build_bench", "an unknown station is knocked together")
	eq(SoundNames.resolve(&"alert_harvester"), &"alert_harvester")
	eq(SoundNames.resolve(&"alert_rows.harvester"), &"alert_harvester", "roster ids work too")
	eq(SoundNames.resolve(&"alert_dog"), &"dog_bark")
	eq(SoundNames.resolve(&"alert_dog.feral"), &"dog_bark")
	eq(SoundNames.resolve(&"alert_otter"), &"alert", "an unknown watcher-of-you still registers")
	eq(SoundNames.resolve(&"snatch_gull"), &"snatch_gull")
	eq(SoundNames.resolve(&"snatch_harvester"), &"grip", "a taking with no sound of its own is a grip")
	eq(SoundNames.resolve(&"step_tarmac"), &"step_dirt")
	eq(SoundNames.resolve(&"no_such_thing"), &"", "unknown names are ignored")


func test_every_machine_has_its_own_alert() -> void:
	for kind in SoundMachines.KINDS:
		var key := StringName("alert_" + String(kind))
		check(SoundBank.SHEET.has(key), "no alert for %s" % kind)
		check(SoundSignals.handles(key), "no recipe owner for %s" % key)


func test_a_death_sounds_like_what_died() -> void:
	eq(SoundNames.killed_sound(&"watcher"), &"machine_down")
	eq(SoundNames.killed_sound(&"rows.harvester"), &"machine_down")
	eq(SoundNames.killed_sound(&"dog.yard"), &"beast_down")
	eq(SoundNames.killed_sound(&"bull.field"), &"beast_down")


func test_every_sheet_row_has_exactly_one_recipe_owner() -> void:
	for name: StringName in SoundBank.SHEET:
		var cat := SoundBank.category_of(name)
		if cat in [&"machine", &"bed", &"weather", &"scatter", &"music"]:
			continue
		var owners := 0
		owners += 1 if SoundSignals.handles(name) else 0
		owners += 1 if SoundCreatures.handles(name) else 0
		owners += 1 if SoundWork.handles(name) else 0
		check(owners <= 1, "%s has %d owners" % [name, owners])
