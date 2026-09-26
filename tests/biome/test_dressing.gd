extends TestCase
## What a landscape's built things are made of (`BiomeDressing`).
##
## The bug this package closed: `src/models/props/` matched on `Country`, names
## for the first seven registry slots, so every landscape registered after the
## M1 six got the COAST'S houses, boulders, wrecks, signs and shore dressing.
## Nothing said so — a model drew, in somebody else's clothes — and it is what
## stopped M3 being started honestly.
##
## So the tests here are mostly about landscapes NOBODY WROTE A LINE FOR: that
## one is dressed out of what its own file already said, and that no file under
## src/models/props/ can quietly start naming a landscape again.

const PROPS := "res://src/models/props/"
## Kinds whose model is the landscape's own, so two landscapes must not draw
## them the same: a boulder, a bone, a house, a wreck, a fence, a shelter, the
## machines' sign, a car, a grave.
const DRESSED: Array[int] = [PropKind.BOULDER, PropKind.BONES, PropKind.HOUSE, PropKind.WRECK,
	PropKind.FENCE, PropKind.SHACK, PropKind.SIGN, PropKind.VEHICLE, PropKind.GRAVE, PropKind.RUIN]


# --- the thing that was broken -------------------------------------------------

func test_no_model_builder_names_a_landscape_any_more() -> void:
	# The regression guard. A `Country` constant in a builder is a landscape
	# dressed by name, which is exactly what stopped a new one being itself.
	var dir := DirAccess.open(PROPS)
	check(dir != null, "src/models/props/ exists")
	if dir == null:
		return
	var named := PackedStringArray()
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(PROPS + f)
		var n := 1
		for line in text.split("\n"):
			if line.contains("Country."):
				named.append("%s:%d %s" % [f, n, line.strip_edges()])
			n += 1
	eq("\n".join(named), "", "a model builder may not branch on a landscape by name")


func test_every_landscape_dresses_its_own_things() -> void:
	# Every land type but the coast must draw at least one of these its own way.
	# Before this package the answer for salt_flats, scrapwood and the caves was
	# "none of them": they were the coast, down to the last vertex.
	for d: BiomeDef in BiomeRegistry.land():
		if d.index == Country.COAST:
			continue
		var own := 0
		for kind: int in DRESSED:
			if _colours(kind, d.index) != _colours(kind, Country.COAST):
				own += 1
		gt(float(own), 2.0, "%s dresses its own things (%d of %d differ from the coast's)" % [d.id, own, DRESSED.size()])


func test_a_landscape_that_declares_no_dressing_is_still_not_the_coast() -> void:
	# The whole promise: a four-line landscape is dressed out of what it HAS
	# said about itself — its rock, its grass, its plain ground — and never out
	# of somebody else's file.
	var d := BiomeDef.new()
	d.id = &"nowhere"
	d.index = Country.COAST
	d.rock_color = Palette.RUST[2]
	d.grass_colors = [Palette.BLOOM[3], Palette.BLOOM[2]]
	var r := BiomeDressing.resolve(d)
	eq(r.stone[0], Palette.RUST[2], "its boulders are cut from the rock it declared")
	eq(r.stone[2], Palette.BLOOM[3], "and what grows on them is what grows on it")
	eq(r.turf[0], Palette.BLOOM[3], "its sods are cut from its own ground")
	var coast := BiomeDressing.of(Country.COAST)
	check(r.stone != coast.stone, "not the coast's stone")
	check(r.turf != coast.turf, "not the coast's turf")
	check(r.drift != coast.drift, "and what banks against a thing here is its own ground, not the coast's sand")
	eq(r.drift[0], GroundColors.wash(d.plain_ground, d.index), "which is the wash of the ground it said it was")


func test_what_a_landscape_says_about_itself_decides_the_rest() -> void:
	# The four levers everything else hangs off, each proved on its own.
	var burnt := BiomeDef.new()
	burnt.id = &"cinders"
	burnt.scorched = true
	var b := BiomeDressing.resolve(burnt)
	eq(String(b.shelter), "dugout", "nothing green survives, so people dig in")
	eq(String(b.covers), "ash", "and ash is what banks against anything left out")
	eq(String(b.crown), "bare", "nothing keeps a leaf")
	eq(b.concrete, Palette.STONE[1], "its cast concrete is scorched")

	var cold := BiomeDef.new()
	cold.id = &"drifts"
	cold.dressing = BiomeDressing.new()
	cold.dressing.snow = [Palette.RIME[5], Palette.RIME[4], Palette.RIME[3], Palette.RIME[2]]
	var s := BiomeDressing.resolve(cold)
	check(s.cold(), "snow lies here")
	eq(String(s.shelter), "pod", "so the shelter is a shell half under it")
	eq(String(s.covers), "snow")
	eq(String(s.crown), "bare", "and a broadleaf is bare")

	var fen := BiomeDef.new()
	fen.id = &"sump"
	fen.wet = 0.55
	var f := BiomeDressing.resolve(fen)
	eq(String(f.shelter), "stilt", "standing water: the hut goes up on stilts")
	eq(String(f.covers), "weed")
	check(BiomeDressing.reedy(Country.MOSS), "reeds come up through a fence in the fen")
	check(not BiomeDressing.reedy(Country.COAST), "and not on the coast")
	check(BiomeDressing.grassy(Country.COAST), "but grass grows round what is left on it")


# --- what every reader indexes -------------------------------------------------

func test_every_resolved_ramp_is_as_long_as_its_readers_index_it() -> void:
	# A short ramp is a crash in a chunk worker, not a wrong colour.
	for d: BiomeDef in BiomeRegistry.all():
		var r := BiomeDressing.of(d.index)
		eq(r.stone.size(), 3, "%s stone" % d.id)
		eq(r.pale.size(), 3, "%s pale" % d.id)
		eq(r.timber.size(), 2, "%s timber" % d.id)
		eq(r.drift.size(), 2, "%s drift" % d.id)
		eq(r.turf.size(), 4, "%s turf" % d.id)
		eq(r.walling.size(), 4, "%s walling" % d.id)
		eq(r.sign.size(), 2, "%s sign" % d.id)
		check(r.concrete.a > 0.0, "%s has cast concrete" % d.id)
		check(r.growth.a > 0.0, "%s has something that greens a wall foot" % d.id)
		check(BiomeDressing.COVERS.has(r.covers), "%s is covered in something real: %s" % [d.id, r.covers])
		check(BiomeDressing.SHELTERS.has(r.shelter), "%s builds a real shelter: %s" % [d.id, r.shelter])
		check(BiomeDressing.CROWNS.has(r.crown), "%s grows a real crown: %s" % [d.id, r.crown])
		check(BiomeDressing.WINDOWS.has(r.windows), "%s lights a real window: %s" % [d.id, r.windows])
		check(BiomeDressing.SIGNAGE.has(r.signage), "%s powers its signs a real way: %s" % [d.id, r.signage])
		check(r.facets >= 4 and r.facets <= 9, "%s rock breaks into %d sides" % [d.id, r.facets])
		if r.covers == &"snow":
			eq(r.snow.size(), 4, "%s says what colour its snow is" % d.id)


func test_the_registry_is_still_sound_with_every_landscape_dressed() -> void:
	var problems := BiomeRegistry.problems()
	for p in problems:
		fail(p)
	check(problems.is_empty(), "no landscape declared a dressing nobody can wear")


func test_a_dressing_nobody_can_wear_is_caught() -> void:
	# The validator earns its place: these are all silent otherwise.
	var d := BiomeDef.new()
	d.id = &"wrong"
	d.dressing = BiomeDressing.new()
	d.dressing.shelter = &"palace"
	d.dressing.covers = &"glitter"
	d.dressing.crown = &"topiary"
	d.dressing.windows = &"chandelier"
	d.dressing.signage = &"hologram"
	d.dressing.facets = 40
	d.dressing.stone = [Palette.INK[1]]
	d.tree_tints = {&"branches": [Palette.MOSS[2]], &"leaf": [Palette.MOSS[2]]}
	var said := "\n".join(BiomeDressing.problems(d))
	check(said.contains("palace"), "a shelter nobody builds: %s" % said)
	check(said.contains("glitter"), "a covering nobody has")
	check(said.contains("topiary"), "a crown nobody grows")
	check(said.contains("chandelier"), "a window nobody lights")
	check(said.contains("hologram"), "a sign nobody powers")
	check(said.contains("40 sides"), "rock that breaks into forty")
	check(said.contains("stone wants 3"), "a ramp of the wrong length")
	check(said.contains("branches"), "a tint key nothing grows")
	check(said.contains("leaf wants 4"), "a tint ramp of the wrong length")


# --- what the builders actually draw --------------------------------------------

func test_snow_is_drawn_only_where_a_landscape_says_snow_lies() -> void:
	# A cap of rime on a boulder, a pylon and a house, and none of the three
	# anywhere that never said it was cold.
	var rime := Palette.RIME[5]
	for kind: int in [PropKind.BOULDER, PropKind.PYLON, PropKind.HOUSE]:
		check(_has(kind, Country.SNOWFIELD, rime), "%s carries snow in the snowfield" % PropKind.NAMES[kind])
		check(not _has(kind, Country.COAST, rime), "%s carries none on the coast" % PropKind.NAMES[kind])
		check(not _has(kind, Country.BURNING, rime), "%s carries none in the burning" % PropKind.NAMES[kind])


func test_the_shelter_people_build_is_the_one_its_landscape_declares() -> void:
	# The FORM decides the shape — a pod is the same shell wherever it is buried
	# — and the landscape decides what it is walled with, what banks against it,
	# and the hand that laid it (the seed carries the landscape, so two dry-stone
	# lean-tos are the same lean-to with its stones set down differently). So two
	# landscapes on one form build the same hut to within a stone or two, and two
	# on different forms cannot be the same model at all. The light wired into it
	# follows the form too, or a stilt hut's tube is drawn on a wall the pod keeps.
	var shapes := {}
	var built := {}
	for d: BiomeDef in BiomeRegistry.land():
		var form := BiomeDressing.of(d.index).shelter
		var n := PropModels.template(PropKind.SHACK, 0, d.index).made_v.size()
		if shapes.has(form):
			var was: int = shapes[form]
			check(absf(float(n - was)) / maxf(1.0, float(was)) < 0.05,
				"%s builds the same %s as the landscape before it (%d against %d)" % [d.id, form, n, was])
		shapes[form] = n
		built[d.index] = form
		var tube: Array = PropModels.glow_points(PropKind.SHACK, 1, d.index)
		eq(tube.size(), 1, "%s wired a light into its %s" % [d.id, form])
	gt(float(shapes.size()), 3.0, "more than three shelter forms are actually built")
	# And two landscapes that declare different forms do not build one hut twice.
	for a: int in built:
		for b: int in built:
			if a >= b or built[a] == built[b]:
				continue
			check(_colours(PropKind.SHACK, a) != _colours(PropKind.SHACK, b),
				"a %s is not a %s" % [built[a], built[b]])


## The colours of one model, as a digest: two landscapes that dress a kind the
## same way hash the same.
func _colours(kind: int, country: int) -> String:
	var t := PropModels.template(kind, 0, country)
	var bytes := PackedByteArray()
	for c: Color in t.made_c:
		bytes.append(roundi(c.r * 255.0))
		bytes.append(roundi(c.g * 255.0))
		bytes.append(roundi(c.b * 255.0))
	for c: Color in t.found_c:
		bytes.append(roundi(c.r * 255.0))
		bytes.append(roundi(c.g * 255.0))
		bytes.append(roundi(c.b * 255.0))
	return "%d:%s" % [t.made_v.size(), bytes.compress().hex_encode().md5_text()]


## Whether a model is drawn with `col` anywhere in it.
func _has(kind: int, country: int, col: Color) -> bool:
	for v in PropModels.variants(kind):
		var t := PropModels.template(kind, v, country)
		for c: Color in t.made_c:
			if absf(c.r - col.r) < 0.004 and absf(c.g - col.g) < 0.004 and absf(c.b - col.b) < 0.004:
				return true
	return false
