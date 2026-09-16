extends TestCase
## The landscape registry: that it discovers every file under
## src/content/biomes/, that every landscape it finds is sound, and that the
## indices a world writes into every tile are stable.


func test_every_file_under_content_biomes_is_a_landscape() -> void:
	var dir := DirAccess.open(BiomeRegistry.DIR)
	check(dir != null, "src/content/biomes/ exists")
	if dir == null:
		return
	var files := 0
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".gd.remap"):
			files += 1
	eq(BiomeRegistry.count(), files, "one landscape per file")
	gt(float(files), 7.0, "the six M1 landscapes, the sea, and what M2 added")


func test_every_landscape_validates() -> void:
	var problems := BiomeRegistry.problems()
	for p in problems:
		fail(p)
	check(problems.is_empty(), "the registry is sound")


func test_the_sea_is_index_zero_and_the_m1_six_keep_theirs() -> void:
	eq(String(BiomeRegistry.by_index(0).id), "sea", "index 0 is the sea")
	check(BiomeRegistry.by_index(0).sea, "index 0 says it is the sea")
	var want := ["sea", "coast", "moss", "pinewood", "snowfield", "bonelands", "burning"]
	for i in want.size():
		eq(BiomeRegistry.name_of(i), want[i], "index %d" % i)
	eq(BiomeRegistry.index_of(&"coast"), Country.COAST, "Country.COAST still names the coast")
	eq(BiomeRegistry.index_of(&"burning"), Country.BURNING, "Country.BURNING still names the burning")
	check(BiomeRegistry.count() <= BiomeRegistry.SLOTS, "the registry fits its index slots")


func test_lookups_agree_with_each_other() -> void:
	for d: BiomeDef in BiomeRegistry.all():
		eq(BiomeRegistry.get_def(d.id), d, "get_def(%s)" % d.id)
		eq(BiomeRegistry.by_index(d.index), d, "by_index(%d)" % d.index)
		eq(BiomeRegistry.index_of(d.id), d.index, "index_of(%s)" % d.id)
		eq(BiomeRegistry.name_of(d.index), String(d.id), "name_of(%d)" % d.index)
	eq(BiomeRegistry.land().size(), BiomeRegistry.count() - 1, "every type but the sea is land")
	eq(BiomeRegistry.land_indices().size(), BiomeRegistry.land().size(), "land indices match")


func test_a_landscape_that_takes_a_thing_onto_its_roster_says_where_it_walks() -> void:
	# A roster row was written for the landscapes it names; a landscape that
	# borrows it has to say what it walks on there, or it can never spawn.
	for d: BiomeDef in BiomeRegistry.land():
		for k: StringName in d.roster:
			var row := Roster.row(k)
			var where: Dictionary = row.get("where", {})
			var named: Array = where.get("countries", [])
			if named.has(String(d.id)):
				continue
			var mine: Dictionary = d.roster[k]
			var grounds: Array = where.get("grounds", [])
			if grounds.is_empty():
				continue
			check(not (mine.get("grounds", []) as Array).is_empty(),
				"%s borrows %s and must say what it walks on there" % [d.id, k])


func test_every_landscape_declares_what_the_readers_ask_for() -> void:
	for d: BiomeDef in BiomeRegistry.land():
		var w := String(d.id)
		check(d.style_note != "", "%s: a style note" % w)
		check(not d.weather.is_empty(), "%s: its own weather" % w)
		check(SoundBank.has_sound(d.sound_bed), "%s: a bed that exists (%s)" % [w, d.sound_bed])
		check(not d.props.is_empty(), "%s: something grows there" % w)
		check(not d.hazards.is_empty(), "%s: the land presses on you somehow" % w)
		check(not d.roster.is_empty(), "%s: something lives or works there" % w)
		check(not d.village_names.is_empty() or d.villages == 0, "%s: names for its villages" % w)
		check(d.grade.x <= 0.2, "%s: the grade never brightens the day" % w)
		gt(d.share_target(), 0.0, "%s: wants some of the land" % w)


func test_the_grounds_a_landscape_names_are_grounds_it_can_have() -> void:
	# A wash for a ground this landscape never lays is dead paint; the tables
	# are big, so say so rather than let it rot.
	var laid := {}
	var w := WorldGen.generate(11, 192)
	for i in w.ground.size():
		var key := w.country[i] * 256 + w.ground[i]
		laid[key] = true
	for d: BiomeDef in BiomeRegistry.land():
		for g: int in d.grounds:
			# An ecotone can carry a neighbour's ground in, so a wash is only
			# suspect if NO landscape ever lays it.
			var anywhere := false
			for c in BiomeRegistry.count():
				anywhere = anywhere or laid.has(c * 256 + g)
			check(anywhere, "%s paints %s, which no world lays" % [d.id, Ground.NAMES[g]])
