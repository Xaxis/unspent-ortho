class_name GearEconomy
## The one door into the gear economy (docs/VISION.md). It pours the
## content tables into the contracts the rest of the game reads —
## `Materials` (where an elite material can be got) and `Drops` (what a thing
## yields when it is beaten) — and answers the few questions other packages ask.
##
##   GearEconomy.declare()        fill Materials and Drops; safe to call twice
##   GearEconomy.without_making() everything a player can get with no recipe
##   GearEconomy.spoils(kind, …)  what one kill gives up
##   GearEconomy.problems()       everything wrong with the economy, as lines
##
## Nothing here holds state a save needs: it is the tables, read.

## Charges and elite parts are given out on a kill; this is the salt that keeps
## two kills of the same kind in the same second apart.
const KILL_SALT := 0x9E11
## The row that answers whether the economy is really in the tables. A bool alone
## was not enough: `Materials` and `Drops` are shared with every other package and
## a test (or a reload) may clear them, and a game whose drop tables had been
## emptied under it went on running and handed nothing over.
const CANARY: StringName = &"fab_jig"
## And the body that carries it, so both tables are asked about, not just one.
const CANARY_KIND: StringName = &"longlegs"


## Pour the content into the loot contracts. Safe to call as often as anything
## likes: it does the work again whenever the tables no longer hold it.
static func declare(force: bool = false) -> void:
	if not force and not Materials.where(CANARY).is_empty() and not Drops.table(CANARY_KIND).is_empty():
		return
	for id: StringName in EliteStock.ids():
		var m := EliteStock.material(id)
		var where: Dictionary = {"what": String(m.get("what", "")),
			"rarity": Rarity.of_name(m.get("grade", &"rare"))}
		var land := EliteStock.land_of(id)
		if land != &"":
			where["lands"] = [land]
		var kind := EliteStock.kind_of(id)
		if kind != &"":
			where["sources"] = [kind]
		Materials.declare(id, where)
	for kind: StringName in EliteStock.kinds():
		Drops.declare(kind, EliteStock.table_for(kind))
	# And the places, which are the other half of one economy: what is opened
	# rather than killed. Poured here so that anything asking the economy a
	# question gets the whole of it, rather than whatever happened to be declared
	# by the time it asked.
	Landmarks.declare_loot(force)
	Interiors.declare_loot(force)


## Everything the economy hands a player without a recipe: what a machine gives
## up when it goes down. Computed from roster kinds that really exist, so it can
## never claim a path through a body nobody has built.
##
## `tests/gear/test_gear.gd` widens its idea of "reachable" with this: before the
## economy, the only two ways to hold a thing were taking it off the ground and
## making it, and a drop is now a third.
static func without_making() -> Array[StringName]:
	declare()
	var out: Array[StringName] = []
	for kind: StringName in EliteStock.kinds():
		if not Roster.has(kind):
			continue
		for id: StringName in Drops.can_yield(kind):
			if id != &"" and not out.has(id):
				out.append(id)
	# A keeper's core, off the keeper that is the only body it comes out of.
	for land: StringName in Sentinels.lands():
		var core := Sentinels.for_land(land).core
		if core != &"" and not out.has(core):
			out.append(core)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## What this one body gives up: [{item, count}], deterministic on the world seed
## and which body it was, so a kill cannot be rerolled by loading.
static func spoils(kind: StringName, seed_value: int, body_id: int, land: StringName = &"") -> Array:
	declare()
	return Drops.roll(kind, seed_value, instance_of(kind, body_id), land)


## Which roll this kill is. The COUNT alone is not enough: `Drops.roll` salts by
## the row, not by the table, so a bare count made every kind agree — the second
## harvester and the second warden both gave up their part, and a player would
## have learned "every other one" instead of learning the bodies. The kind goes
## into the number, so each keeps its own run of luck.
static func instance_of(kind: StringName, body_id: int) -> int:
	return Rng.hash_ints(KILL_SALT, body_id, String(kind).hash())


## How many of a kind a player has to put down before its part comes out, walked
## rather than assumed: the number a test asserts is bearable and the slate can
## quote. -1 if no run of kills ever gives it.
static func kills_for(item: StringName, seed_value: int, most: int = 40) -> int:
	declare()
	var kind := EliteStock.kind_of(item)
	if kind == &"":
		return -1
	# Counted from one, the way the system counts kills, so the number this gives
	# back is the number of bodies a player really has to put down.
	for n: int in range(1, most + 1):
		for row: Dictionary in spoils(kind, seed_value, n):
			if StringName(row.get("item", &"")) == item:
				return n
	return -1


## Everything wrong with the economy, as lines a test can fail with. This is the
## list that keeps the two pinned promises true as content is added.
static func problems() -> PackedStringArray:
	declare()
	var out := PackedStringArray()
	out.append_array(Materials.problems(Sources.lands()))
	for id: StringName in EliteStock.ids():
		var m := EliteStock.material(id)
		var land := EliteStock.land_of(id)
		var kind := EliteStock.kind_of(id)
		if (land == &"") == (kind == &""):
			out.append("%s must come from one landscape or one kind of machine, not both or neither" % id)
		if Items.def(id).is_empty():
			out.append("%s is not an item anybody can carry" % id)
		if land != &"":
			var raw := StringName(m.get("raw", &""))
			if not Sources.lands_yielding(raw).has(land):
				out.append("%s is refined from %s, which the %s does not give" % [id, raw, land])
		elif not Roster.has(kind):
			out.append("%s is cut out of %s, which is not in the roster" % [id, kind])
		if not used_by(id).is_empty():
			continue
		out.append("%s is made into nothing: an elite material nobody needs is not a gate" % id)
	for id: StringName in GearTree.ids():
		if Items.def(id).is_empty():
			out.append("%s is in the tree and not in the item table" % id)
		elif String(GearTree.row(id).get("no_source", "")) != "":
			continue
		elif not Sources.reachable(id):
			out.append("%s is in the tree and there is no way to it" % id)
	for id: StringName in ModifierTable.ids():
		if not Gear.is_module(id):
			out.append("%s says what it decides and is not a module" % id)
		elif ModifierTable.decision(id) == "":
			out.append("%s is a module with no decision to change" % id)
	return out


## Every piece the economy makes out of this material.
static func used_by(material_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in GearTree.ids():
		if GearTree.made_of(id) == material_id:
			out.append(id)
	for r: Dictionary in Recipes.LIST:
		# `keeps` counts as much as `needs`: the jig is never spent, and everything
		# on the top rung is made with it in hand, which is exactly what it is for.
		if not ((r.get("needs", {}) as Dictionary).has(material_id)
				or (r.get("keeps", {}) as Dictionary).has(material_id)):
			continue
		for made: Variant in (r.get("makes", {}) as Dictionary):
			var key := StringName(made)
			if not out.has(key):
				out.append(key)
	return out


## What a landscape holds of its own, for the slate: the elite material a player
## can only get here, and the machine parts the bodies here give up.
static func here(land: StringName) -> Dictionary:
	declare()
	var own: Array[StringName] = []
	for id: StringName in Materials.in_land(land):
		own.append(id)
	var parts: Array[StringName] = []
	for kind: StringName in Sources.kinds_in(land):
		for id: StringName in EliteStock.from_kind(kind):
			if not parts.has(id):
				parts.append(id)
	own.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	parts.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return {"own": own, "parts": parts}
