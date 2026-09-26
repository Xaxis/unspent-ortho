extends TestCase
## The pinned promise: **a grade buys modifiers, not damage** (docs/VISION.md
## §6.1). Everything here exists so that the moment somebody gives a prime piece
## a bigger number, the gate says so — because on the day that lands, every
## earlier piece becomes litter and the landscapes stop being worth crossing for
## their own sake.


func _implements() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Items.DEFS:
		if bool(Items.def(id).get("tool", false)):
			out.append(id)
	return out


func test_every_implement_and_module_has_a_grade_declared() -> void:
	for id in _implements():
		check(GearTree.has(id), "%s is something you can hold and it has no grade" % id)
	for id: StringName in Items.DEFS:
		if Gear.is_module(id):
			check(GearTree.has(id), "%s is a module with no grade" % id)


func test_the_tree_is_as_wide_as_the_roadmap_says() -> void:
	var mended_implements := 0
	var mended_modules := 0
	for id: StringName in GearTree.ids():
		if Gear.tier(id) != &"mended":
			continue
		if Gear.is_module(id):
			mended_modules += 1
		elif bool(Items.def(id).get("tool", false)):
			mended_implements += 1
	gt(float(mended_implements), 19.0, "the mended tree carries 20+ implements (has %d)" % mended_implements)
	# The mended modules plus the made and found ones already there: 15+ modifiers.
	var modules := 0
	for id: StringName in Items.DEFS:
		modules += 1 if Gear.is_module(id) else 0
	gt(float(modules), 14.0, "15+ modules (has %d, %d of them mended)" % [modules, mended_modules])
	for g: int in [Rarity.COMMON, Rarity.UNCOMMON, Rarity.RARE, Rarity.PRIME, Rarity.RELIC]:
		gt(float(GearTree.at_grade(g).size()), 0.0, "something is %s" % Rarity.name_of(g))


## The load-bearing one. Every rung of a family is the same weapon: it hits for
## the same, reaches as far, swings in the same milliseconds and works at the same
## speed. If any of that ever differs, the ladder has become a power ladder.
func test_every_rung_of_a_family_does_exactly_what_the_first_rung_does() -> void:
	for f in GearTree.ladders():
		var rungs := GearTree.rungs(f)
		var first := rungs[0]
		for other: StringName in rungs.slice(1):
			for field in GearTree.SAME_ACROSS_A_FAMILY:
				var a: Variant = Items.def(first).get(String(field), null)
				var b: Variant = Items.def(other).get(String(field), null)
				eq(b, a, "%s is a %s and its %s is not the %s's" % [other, f, field, first])


func test_what_a_grade_buys_is_sockets_and_nothing_else() -> void:
	for f in GearTree.ladders():
		var rungs := GearTree.rungs(f)
		for i in range(1, rungs.size()):
			var lower := Gear.sockets(rungs[i - 1])
			var higher := Gear.sockets(rungs[i])
			check(higher >= lower, "%s (%s) has fewer sockets than %s (%s)"
				% [rungs[i], Rarity.name_of(GearTree.grade(rungs[i])),
					rungs[i - 1], Rarity.name_of(GearTree.grade(rungs[i - 1]))])
	# And a mended rung carries exactly the sockets its grade is worth, so the
	# ladder is `Rarity`'s and not a number somebody typed into an item row.
	for id: StringName in GearTree.ids():
		if Gear.tier(id) != &"mended" or Gear.is_module(id):
			continue
		var want := Rarity.slots(GearTree.grade(id))
		eq(Gear.sockets(id), want, "%s is %s, which is worth %d sockets"
			% [id, Rarity.name_of(GearTree.grade(id)), want])


## The trap this whole design is arranged against: the best thing in the game
## being the rarest thing in the game.
func test_the_top_grades_do_not_hold_the_hardest_hit() -> void:
	var top: Dictionary = {}
	var everything := 0.0
	for id: StringName in GearTree.ids():
		var dmg := float(Items.def(id).get("dmg", 0))
		var g := GearTree.grade(id)
		top[g] = maxf(float(top.get(g, 0.0)), dmg)
		everything = maxf(everything, dmg)
	for g: int in [Rarity.PRIME, Rarity.RELIC]:
		lt(float(top.get(g, 0.0)), everything,
			"the hardest hit in the game is %s and a %s piece should not hold it"
			% [everything, Rarity.name_of(g)])
	gt(float(top.get(Rarity.UNCOMMON, 0.0)), float(top.get(Rarity.RELIC, 0.0)),
		"something ordinary still hits harder than the relic")


## One relic you hold in the hand, so it reads as one; every other relic is a
## keeper's power (GEAR.md §5), made of that keeper's core, and each says what
## only it does.
func test_the_relic_is_one_thing_and_it_does_something_nothing_else_does() -> void:
	var relics := GearTree.at_grade(Rarity.RELIC)
	var held: Array[StringName] = []
	for id in relics:
		if bool(Items.def(id).get("tool", false)):
			held.append(id)
			continue
		check(Gear.is_module(id), "%s: a relic not held is a keeper's power, a module" % id)
		check(Sources.keeper_of_core(GearTree.made_of(id)) != &"", "%s is made of a keeper's core" % id)
		check(GearTree.unique(id) != "", "%s says what only it does" % id)
	eq(held.size(), 1, "one relic in the hand, so it reads as one: %s" % [held])
	var relic: StringName = held[0]
	check(Rarity.unique(GearTree.grade(relic)), "a relic carries a unique")
	check(GearTree.unique(relic) != "", "%s says what only it does" % relic)
	# And the thing it does is really only its: nothing else you can HOLD grants it.
	var ability := Gear.ability_of(relic)
	check(ability != &"", "%s's unique is something the body can use" % relic)
	for id: StringName in Items.DEFS:
		if id == relic or not bool(Items.def(id).get("tool", false)):
			continue
		check(Gear.ability_of(id) != ability,
			"%s grants %s too, so the relic's unique is not unique" % [id, ability])


func test_a_mended_rung_costs_more_to_carry_than_the_tool_it_was() -> void:
	# The one number a grade may raise is what it weighs. Machine parts weigh.
	for f in GearTree.ladders():
		var rungs := GearTree.rungs(f)
		for i in range(1, rungs.size()):
			if Gear.tier(rungs[i]) != &"mended":
				continue
			gt(Items.bulk(rungs[i]), Items.bulk(rungs[i - 1]) - 1e-6,
				"%s should not be lighter than %s" % [rungs[i], rungs[i - 1]])
