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
		# sky.gdshaderinc scales the graded colour by (1 - grade.x): POSITIVE
		# darkens, negative lifts. A landscape open to the sky may lift its noon
		# as far as SkyLight's clamp, and may not darken it at all — that is what
		# turns a noon frame into dusk and what nobody notices until a shot.
		if d.realms.has(&"surface"):
			check(d.grade.x <= 0.0, "%s: grade.x %.2f darkens the day (positive darkens)" % [w, d.grade.x])
		check(d.grade.x >= -0.6, "%s: grade.x %.2f lifts past the sky's clamp" % [w, d.grade.x])
		gt(d.share_target(), 0.0, "%s: wants some of the land" % w)


## Worlds this asks rather than the one it used to ask. Cheap: 192 is the smallest
## size worldgen is run at anywhere, and six of them cost about a second.
const GROUND_SAMPLE: Array[int] = [11, 1, 42, 7, 90210, 3]


func test_the_grounds_a_landscape_names_are_grounds_it_can_have() -> void:
	# A wash for a ground this landscape never lays is dead paint; the tables
	# are big, so say so rather than let it rot.
	#
	# ASKED OF A SAMPLE, NOT OF ONE WORLD (owner, 2026-09-18). This used to assert
	# against a single 192-tile SURFACE world on seed 11, which made it a question
	# about that one island and not about the game. BONE is the rarest ground the
	# bonelands lays — 98 tiles out of 17,000 on exactly that world — so adding an
	# eleventh landscape, which shrinks every landscape's share of the map, dropped
	# it off that island and four landscapes that had painted BONE for months all
	# failed at once. Not one of them had changed. Every landscape added shrinks
	# the shares again, so one world can only ever get less representative: that is
	# the whole of why this samples.
	#
	# BOTH REALMS, because a world is one realm's world (`GenContext` lays only the
	# types whose `BiomeDef.realms` names it). Asked of a surface world alone, an
	# underground landscape's grounds can never appear at all, and limestone_caves
	# was passing only because the bonelands happened to lay the same ground
	# overhead — a coincidence, and it is what broke when the bonelands' share fell.
	var laid := {}
	for realm: StringName in [Realm.SURFACE, Realm.UNDERGROUND]:
		for s: int in GROUND_SAMPLE:
			var w := WorldGen.generate(s, 192, &"", realm)
			for i in w.ground.size():
				laid[w.country[i] * 256 + w.ground[i]] = true
	for d: BiomeDef in BiomeRegistry.land():
		for g: int in d.grounds:
			# An ecotone can carry a neighbour's ground in, so a wash is only
			# suspect if NO landscape ever lays it.
			var anywhere := false
			for c in BiomeRegistry.count():
				anywhere = anywhere or laid.has(c * 256 + g)
			check(anywhere, "%s paints %s, which no world lays" % [d.id, Ground.NAMES[g]])


## IS THIS LANDSCAPE IN EVERY WORLD? The question a story beat, an economy gate or
## a guided path asks before it rests on a landscape (docs/DESIGN.md). It reads
## `spread.x` and nothing else, so it cannot drift from what the dealer honours.
func test_guaranteed_answers_only_for_a_landscape_with_a_floor() -> void:
	for d: BiomeDef in BiomeRegistry.land():
		eq(BiomeRegistry.guaranteed(d.id), d.spread.x >= 1,
			"%s: guaranteed iff it asks for at least one body" % d.id)
	check(not BiomeRegistry.guaranteed(&"no_such_landscape"), "a name nobody registered is not guaranteed")
	# Nothing declares a floor today and that is deliberate: the story spine rests
	# on per-REGION features and on the coast, which the opening hour guarantees,
	# so the whole variety budget is free for continents to spend.
	var promised := 0
	for d: BiomeDef in BiomeRegistry.land():
		if BiomeRegistry.guaranteed(d.id):
			promised += 1
	lt(float(promised), float(BiomeRegistry.count()) * 0.5,
		"the guaranteed set stays small: every floor is a landscape that can never be rare")


## Every landscape says how a body is spoken of in it: its own preposition and
## its own name, lower case, as the game's flat present voice uses it
## (BiomeDef.spoken_in; Guide's late goal is the first reader). A new landscape
## cannot ship saying "in the coast".
func test_every_landscape_says_how_one_is_spoken_of_in_it() -> void:
	for d: BiomeDef in BiomeRegistry.all():
		var said := d.spoken_in
		check(said != "", "%s declares spoken_in" % d.id)
		eq(said, said.to_lower(), "%s: lower case" % d.id)
		check(said.contains(d.display_name.trim_prefix("the ")), "%s: it names the place (%s / %s)" % [d.id, said, d.display_name])
		check(not said.ends_with("."), "%s: a phrase, not a sentence" % d.id)
