extends TestCase
## The half of reachability `test_obtainable.gd` cannot see: it walks the TABLES
## — this landscape declares that prop, that roster row names this country — and a
## table is a promise about a world nobody has grown yet.
##
## Every elite material is gated on one landscape or one machine kind, and both
## gates are answered by a landscape: a machine keeps to its own country
## (`Roster` `where`), a raw comes off a prop only one landscape scatters. So the
## whole ladder rests on one unwritten assumption — **that the landscape is
## actually in the world this seed grew**. It is not: a world is one realm's, its
## types are laid by climate, and a seed whose island never lays the snowfield has
## no lineman in it and no crottle, so `line_coil` and `frost_varnish` are
## unreachable for that entire save, not merely far away.
##
## This generates real worlds and asks the question of them.

const SEEDS: Array[int] = [1, 3, 7, 12345]
const SIZE := 256


func _declared() -> void:
	GearEconomy.declare(true)
	Sources.clear()


## **WHAT THE WORLD GREW, READ OFF THE GROUND AND NOT OFF THE CHAPTERS.** This
## listed the types that hold a REGION, which is a different question: a run too
## small to be a place is still snowfield, its ore still stands there and a
## player can still walk onto it and take it. Using regions as the proxy made
## this test report that a seed had not grown the snowfield at all, and fail a
## material gated on it, while 1,945 tiles of snowfield lay on the island.
##
## The distinction is the whole of `GenCountries.PLACE_LEAST`: a region is a
## CHAPTER, and whether a landscape is somewhere you can obtain a raw has
## nothing to do with whether the plan keeps a chapter there.
static func _lands_in(w: WorldData) -> Array[StringName]:
	var out: Array[StringName] = []
	var seen := {}
	for i in w.country.size():
		var cc: int = w.country[i]
		if cc == Country.SEA or seen.has(cc):
			continue
		seen[cc] = true
		var d := BiomeRegistry.by_index(cc)
		if d != null and d.id != &"" and not out.has(d.id):
			out.append(d.id)
	return out


## The landscapes one elite material can be gated in: the one it names, or every
## country the machine that carries it keeps to.
static func _wants(id: StringName) -> Array[StringName]:
	var land := EliteStock.land_of(id)
	if land != &"":
		return [land] as Array[StringName]
	var out: Array[StringName] = []
	out.assign(Sources.lands_of_kind(EliteStock.kind_of(id)))
	return out


## The one that matters: an elite material whose every gate landscape is missing
## from this seed's world cannot be had in that game at all.
func test_every_elite_material_has_a_gate_in_the_world_the_seed_grew() -> void:
	_declared()
	for s: int in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var here := _lands_in(w)
		for id: StringName in EliteStock.ids():
			var want := _wants(id)
			var found := false
			for l: StringName in want:
				if here.has(l):
					found = true
					break
			check(found, "seed %d grew %s and nothing in it gates %s (wants one of %s)"
				% [s, here, id, want])


## And the other way round: say out loud how narrow each seed is, so a reader can
## see that "reachable" is a per-save answer rather than a property of the game.
func test_a_seed_says_how_much_of_the_ladder_it_holds() -> void:
	_declared()
	for s: int in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var here := _lands_in(w)
		var reachable: Array[StringName] = []
		for id: StringName in EliteStock.ids():
			for l: StringName in _wants(id):
				if here.has(l):
					reachable.append(id)
					break
		print("seed %d: %d regions over %s; %d of %d elite materials gated in it"
			% [s, w.regions.size(), here, reachable.size(), EliteStock.ids().size()])
		gt(float(reachable.size()), 0.0, "seed %d holds some of the ladder" % s)


## Whether the machine a material is cut out of can really be MET is a harder
## question than this file can answer — counting the tiles its `where` accepts
## says nothing about whether any of them fall inside one spawn ring — so it is
## asked properly, by rolling the real spawner, in
## `tests/gear_economy/test_reachable_in_play.gd`.


## A landscape's own material is refined from a raw, and a raw comes off a PROP
## that has to be standing there. `Sources` reads the landscape's declared prop
## list; worldgen decides what is really scattered. This asks the world.
func test_the_prop_a_landscapes_material_is_refined_from_really_stands_in_it() -> void:
	_declared()
	for s: int in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var here := _lands_in(w)
		for id: StringName in EliteStock.ids():
			var land := EliteStock.land_of(id)
			if land == &"" or not here.has(land):
				continue
			var raw := StringName(EliteStock.material(id).get("raw", &""))
			var kind := Sources.prop_yielding(raw)
			gt(float(kind), -1.0, "%s is refined from %s and nothing yields it" % [id, raw])
			var standing := 0
			for p: WorldProp in w.props:
				if p.kind != kind:
					continue
				var d := BiomeRegistry.at(w, p.pos)
				if d != null and d.id == land:
					standing += 1
			gt(float(standing), 0.0,
				"seed %d: %s wants %s off a %s in the %s, and the %s has none standing in it"
				% [s, id, raw, PropKind.NAMES[kind], land, land])
