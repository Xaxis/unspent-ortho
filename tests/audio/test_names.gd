extends TestCase
## Whatever name a package emits, it finds a sound: every name the fight,
## survival, sky and ui packages emit (listed, and read from the source) resolves
## to a row on the sheet, bare alerts, takings and windups find the mob's own
## sound, patterns map verbs and stations, and unknown names stay silent.


func test_every_emitted_name_resolves_to_a_sound() -> void:
	for n: StringName in SoundNames.EMITTED:
		var s := SoundNames.for_mob(n, &"") if n in SoundNames.BY_MOB else SoundNames.resolve(n)
		if n in SoundNames.SILENT:
			eq(s, &"", "%s is silent on purpose" % n)
			continue
		check(s != &"" and SoundBank.SHEET.has(s), "%s resolves to '%s', which is not on the sheet (add it, or list it in SILENT)" % [n, s])


## Reads every emit in src/ (outside the audio package) and holds each literal
## name to the same rule, so a name another package adds after a merge cannot
## fall into silence while the hand-kept list above goes stale.
func test_every_name_emitted_in_the_source_resolves() -> void:
	var found := {}
	_scan("res://src", found)
	for where: String in found:
		for n: StringName in found[where]:
			if n in SoundNames.SILENT:
				continue
			var s := SoundNames.for_mob(n, &"") if n in SoundNames.BY_MOB else SoundNames.resolve(n)
			check(s != &"" and SoundBank.SHEET.has(s), "%s emits '%s', which resolves to nothing (add it to SoundNames, or to SILENT)" % [where, n])
	# The reader itself, on the shapes emitters use.
	eq(_names_in('\tEvents.sfx.emit(&"lamp_on" if lit else &"lamp_off", game.player.position)\nvar x := &"not_a_sound"\n'), [&"lamp_on", &"lamp_off"] as Array[StringName], "reads every literal on an emit line")


static func _names_in(text: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var re := RegEx.create_from_string("&\"([a-z0-9_]+)\"")
	for line in text.split("\n"):
		if line.contains("sfx.emit("):
			for m in re.search_all(line):
				out.append(StringName(m.get_string(1)))
	return out


func _scan(dir_path: String, out: Dictionary) -> void:
	if dir_path.begins_with("res://src/audio"):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for d in dir.get_directories():
		_scan(dir_path.path_join(d), out)
	for f in dir.get_files():
		if f.ends_with(".gd"):
			var names := _names_in(FileAccess.get_file_as_string(dir_path.path_join(f)))
			if not names.is_empty():
				out[dir_path.path_join(f)] = names


func test_names_that_used_to_resolve_wrongly() -> void:
	eq(SoundNames.resolve(&"lamp_out"), &"lamp_off", "the lamp guttering out is heard")
	eq(SoundNames.resolve(&"work_broken"), &"tool_snap", "a tool breaking is not a gather")
	eq(SoundBank.category_of(SoundNames.resolve(&"build_ask")), &"ui", "asking where to build is a quiet page sound")
	eq(SoundNames.resolve(&"snatch"), &"grip", "a taking nobody can be found for")


func test_bare_alert_snatch_and_windup_take_the_mob_that_did_it() -> void:
	eq(SoundNames.for_mob(&"alert", &"watcher"), &"alert_watcher")
	eq(SoundNames.for_mob(&"alert", &"dog.yard"), &"dog_bark")
	eq(SoundNames.for_mob(&"alert", &"bull.field"), &"bull_snort")
	eq(SoundNames.for_mob(&"alert", &"gulls"), &"gull_cry")
	eq(SoundNames.for_mob(&"alert", &""), &"alert", "no mob found: the generic call")
	eq(SoundNames.for_mob(&"snatch", &"flock"), &"snatch_flock")
	eq(SoundNames.for_mob(&"snatch", &"warden"), &"snatch_warden")
	eq(SoundNames.for_mob(&"snatch", &"clerk"), &"snatch_clerk")
	eq(SoundNames.for_mob(&"snatch", &"gulls"), &"snatch_gull")
	eq(SoundNames.for_mob(&"snatch", &""), &"grip")
	eq(SoundNames.for_mob(&"windup", &"harvester"), &"windup_harvester")
	eq(SoundNames.for_mob(&"windup", &"dog.feral"), &"dog_growl")
	eq(SoundNames.for_mob(&"windup", &"bull.field"), &"bull_paw")
	eq(SoundNames.for_mob(&"windup", &""), &"windup")
	for kind in SoundMachines.KINDS:
		for verb: StringName in [&"alert", &"windup"]:
			var s := SoundNames.for_mob(verb, kind)
			eq(s, StringName("%s_%s" % [verb, kind]), "%s by a %s" % [verb, kind])
			check(SoundBank.SHEET.has(s), "%s on the sheet" % s)


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


func test_every_machine_has_its_own_alert_and_windup() -> void:
	for kind in SoundMachines.KINDS:
		for verb: String in ["alert", "windup"]:
			var key := StringName(verb + "_" + String(kind))
			check(SoundBank.SHEET.has(key), "no %s for %s" % [verb, kind])
			check(SoundSignals.handles(key), "no recipe owner for %s" % key)


func test_a_death_sounds_like_what_died() -> void:
	eq(SoundNames.killed_sound(&"watcher"), &"machine_down")
	eq(SoundNames.killed_sound(&"rows.harvester"), &"machine_down")
	eq(SoundNames.killed_sound(&"dog.yard"), &"beast_down")
	eq(SoundNames.killed_sound(&"bull.field"), &"beast_down")
	eq(SoundNames.killed_sound(&"gulls"), &"gull_cry", "a gull is too light to thud")


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
