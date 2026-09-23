extends TestCase
## The designs, and the door a landscape claims one through (docs/VISION.md).
## Nothing here runs a fight: this is the shape of the content, which is what a
## new landscape's author will copy.


func _fresh() -> void:
	# The loot tables are static and another test may have cleared them.
	Sentinels.declare_loot()


func test_the_designs_are_sound() -> void:
	_fresh()
	var said := Sentinels.problems()
	eq(said.size(), 0, "the sentinel designs: %s" % ", ".join(said))


func test_a_landscape_claims_its_keeper_by_name_and_that_is_the_only_door() -> void:
	_fresh()
	gt(float(Sentinels.all().size()), 1.0, "there is more than one design")
	for land: StringName in Sentinels.lands():
		var def := Sentinels.for_land(land)
		check(def != null, "%s names a design that exists" % land)
		eq(def.land, land, "%s's keeper keeps %s" % [land, land])
		eq(BiomeRegistry.get_def(land).sentinel, def.id, "the landscape's own file is what says so")
	check(Sentinels.for_land(&"coast") != null, "the coast has a keeper")
	check(Sentinels.for_land(&"salt_flats") != null, "the salt flats have one of their own")
	check(Sentinels.for_land(&"coast").id != Sentinels.for_land(&"salt_flats").id,
		"and it is never the same design reskinned (VISION §3)")
	check(Sentinels.for_land(&"moss") == null, "a landscape that declares none has none")


func test_each_one_can_be_beaten_three_ways_and_none_of_them_is_trading_hits() -> void:
	_fresh()
	for def: SentinelDef in Sentinels.all():
		eq(def.ways.size(), 3, "%s: three ways (VISION §3)" % def.id)
		var kinds := {}
		for w in def.ways:
			kinds[w.kind] = true
			check(w.says != "", "%s: the %s way can be said in a line" % [def.id, w.id()])
		eq(kinds.size(), 3, "%s: three DIFFERENT ways" % def.id)
		check(def.has_way(SentinelWay.FORCE), "%s can be taken apart" % def.id)
		# Its body is guarded somewhere, or spent-only, so force is never standing
		# and trading: every design has at least one phase whose part is guarded or
		# whose bite leaves a real opening.
		var guarded := false
		for p in def.phases:
			guarded = guarded or p.guarded
		check(guarded, "%s guards its working part in some phase" % def.id)


func test_its_phases_move_the_side_a_player_has_to_be_on() -> void:
	_fresh()
	for def: SentinelDef in Sentinels.all():
		gt(float(def.phases.size()), 2.0, "%s has three phases or more" % def.id)
		var sides := {}
		var last := 2.0
		for p in def.phases:
			sides[p.part] = true
			check(p.at <= last, "%s: phase %s comes after the one before it" % [def.id, p.id])
			last = p.at
			check(p.bite.has("swing"), "%s: phase %s bites" % [def.id, p.id])
			var swing: Array = p.bite.swing
			gt(float(swing[0]), 380.0, "%s: phase %s tells for long enough to read (%d ms)" % [def.id, p.id, int(swing[0])])
			gt(float(swing[2] + swing[3]), 600.0, "%s: phase %s leaves a real opening after a miss" % [def.id, p.id])
		gt(float(sides.size()), 2.0, "%s: the working side moves phase to phase" % def.id)
		eq(def.phase_at(1.0), 0, "%s: full health is its first phase" % def.id)
		eq(def.phase_at(0.0), def.phases.size() - 1, "%s: its last phase is the one it dies in" % def.id)
		# The phase for a health is the LAST one whose threshold it is under.
		for i in def.phases.size():
			eq(def.phase_at(def.phases[i].at), i, "%s: phase %d begins at its own threshold" % [def.id, i])


func test_its_body_is_a_roster_row_like_any_other_machine() -> void:
	_fresh()
	for def: SentinelDef in Sentinels.all():
		var row := Roster.row(def.kind)
		check(not row.is_empty(), "%s: %s is in the roster" % [def.id, def.kind])
		check(row.get("machine", false), "%s is a machine" % def.kind)
		eq(Roster.sentinel_of(def.kind), def.id, "%s's row names its design" % def.kind)
		eq(Roles.of(def.kind), Roles.KEEPER, "%s keeps a place, so it is a keeper in the plan" % def.kind)
		eq(Roster.disposition(def.kind), &"wary", "and a keeper starts wary (VISION §2)")
		# Never rolled by the coast: its hours fit no hour of any day.
		var m := Moment.new()
		for h in 24:
			m.minutes = h * 60.0
			check(not Spawner.moment_fits(row, m), "%s is never rolled at %d:00" % [def.kind, h])
		gt(float(Roster.health_of(def.kind)), float(Roster.health_of(&"harvester")), "%s outlasts a worker" % def.kind)
		gt(float(row.get("radius", 0.0)), 1.0, "%s is a big body" % def.kind)


## The palette's rule is that a machine's colour is its ROLE (src/render/palette.gd),
## so a keeper of a landscape wears the keeper ramp and reads as what it is.
func test_it_is_drawn_on_a_keepers_ramp() -> void:
	for def: SentinelDef in Sentinels.all():
		var model := FigureModel.create(StringName(Roster.row(def.kind).get("model", &"")))
		check(model is MachineModel, "%s draws with a machine's body" % def.kind)
		var mm := model as MachineModel
		eq(mm.ramp, Palette.MACHINE["warden"], "%s is on the keeper's ramp" % def.kind)
		eq(mm.disposition, &"wary", "and its plan strip counts a keeper")
		model.free()


func test_what_it_gives_is_on_one_table_and_its_core_comes_from_nowhere_else() -> void:
	_fresh()
	for def: SentinelDef in Sentinels.all():
		check(Drops.can_yield(def.drops).has(def.core), "%s's table holds its core" % def.id)
		check(Materials.can_come_from(def.core, &"", def.drops), "%s: the core comes off this keeper" % def.id)
		check(not Materials.can_come_from(def.core, def.land), "%s: and never off the land itself" % def.id)
		eq(Materials.where(def.core).get("rarity", -1), Rarity.RELIC, "%s: a keeper gives a relic (VISION §6.1)" % def.id)
		eq(Materials.sources(def.core).size(), 1, "%s: one core, one keeper" % def.id)
		# Deterministic: the same region cannot be rerolled by loading the game.
		var a := Drops.roll(def.drops, 7, 3, def.land)
		var b := Drops.roll(def.drops, 7, 3, def.land)
		eq(SaveCodec.canonical(a), SaveCodec.canonical(b), "%s rolls the same twice" % def.id)
		var got := {}
		for row: Dictionary in a:
			got[row.item] = true
		check(got.has(def.core), "%s always gives its core" % def.id)
	# The lands a material may name are the REGISTRY's, asked rather than listed:
	# this was nine names written by hand, true at nine landscapes, and the first
	# elite material declared for a tenth would have failed it with "names a
	# landscape that does not exist" whenever the economy had been poured earlier
	# in the same process (CLAUDE.md: the shared list is older than the landscape).
	var known: Array = []
	for d: BiomeDef in BiomeRegistry.all():
		known.append(d.id)
	var problems := Materials.problems(known)
	eq(problems.size(), 0, "every material declared names somewhere real: %s" % ", ".join(problems))
