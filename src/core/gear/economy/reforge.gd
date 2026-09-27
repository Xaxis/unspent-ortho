class_name Reforge
## Taking gear apart again (docs/VISION.md: "Gear can be broken down for its
## materials and its modifiers re-socketed at a bench, at the risk of losing the
## part. Nothing is dead loot.").
##
## The risk is the whole rule, and it is a rule about WHERE you are standing. A
## bound grip unties: you can take it off a haft in the rain and lose nothing. A
## panel drilled into a frame does not: out in the field you are prising it with
## the wrong tool, and sometimes it comes away in pieces. At a bench it never
## does. So a player who wants to change their build for the landscape ahead
## either plans it at a bench or gambles on the road, which is a decision.
##
## Deterministic: the same seed and the same count of pulls always agree, so
## nothing here can be rerolled by loading a save.

## The odds a MENDED or FOUND part does not survive being prised out in the field.
const FIELD_RISK := 0.25
## What a part that did not survive leaves behind.
const SPOIL_ITEM: StringName = &"spoil"


## Whether taking `module` out is free wherever you stand: cord and rag are, a
## drilled panel is not (docs/LOOK.md — the join is the difference).
static func unties(module: StringName) -> bool:
	return Gear.tier(module) == &"made"


## Would pulling this module here risk it at all?
static func risky(module: StringName, at_bench: bool) -> bool:
	return not at_bench and not unties(module)


## Does the part survive? `n` is a count the save keeps, so two pulls in one
## session are two different rolls and a reload is not a reroll.
static func survives(module: StringName, at_bench: bool, seed_value: int, n: int) -> bool:
	if not risky(module, at_bench):
		return true
	return Rng.hash01(seed_value, n, 0x2F0C) >= FIELD_RISK


## What one line of the gear page says before a pull, so the gamble is taken with
## open eyes rather than discovered afterwards.
static func warning(module: StringName, at_bench: bool) -> String:
	if not risky(module, at_bench):
		return ""
	return "%s is drilled in; prising it out here may break it." % Items.display_name(module)


static func broke_line(module: StringName) -> String:
	return "The %s came away in pieces." % Items.display_name(module)


## What breaking a whole piece down gives back: the elite material in it always
## (that is the point — an elite material is never lost to a piece you have
## outgrown), and half of everything else its recipe took, rounded down.
##
## Taken apart at a bench from the making page (`salvage_recipes`).
static func salvage(id: StringName) -> Dictionary:
	var out: Dictionary = {}
	var r := _recipe_making(id)
	if r.is_empty():
		return out
	var elite := GearTree.made_of(id)
	for item: Variant in (r.get("needs", {}) as Dictionary):
		var key := StringName(item)
		var had := int((r["needs"] as Dictionary)[item])
		if key == elite:
			out[key] = maxi(1, had)
		elif had >= 2:
			out[key] = had / 2
	return out


## How long taking a piece apart at the bench takes.
const SALVAGE_MINUTES := 15.0


## A carried piece of gear taken apart, as a row the making page lists at a
## bench: it spends the piece and gives `salvage` back. Only a piece that was
## made from a recipe, and only one whose taking-apart gives something.
static func salvage_recipe(id: StringName) -> Dictionary:
	if not GearTree.PIECES.has(id):
		return {}
	var back := salvage(id)
	if back.is_empty():
		return {}
	return {"id": StringName("salvage_%s" % id), "at": &"bench", "minutes": SALVAGE_MINUTES,
		"needs": {id: 1}, "makes": back, "action": &"salvage", "salvages": id}


## Every piece carried that can be taken apart at a bench.
static func salvage_recipes(inv: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array = inv.items.keys()
	ids.sort()
	for id: Variant in ids:
		if inv.count(StringName(id)) <= 0:
			continue
		var r := salvage_recipe(StringName(id))
		if not r.is_empty():
			out.append(r)
	return out


static func _recipe_making(id: StringName) -> Dictionary:
	for r: Dictionary in Recipes.LIST:
		if (r.get("makes", {}) as Dictionary).has(id):
			return r
	return {}
