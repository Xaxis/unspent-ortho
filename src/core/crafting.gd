class_name Crafting
## Recipes and making. The survival package fills Recipes and the rules; the
## UI package calls only these functions.
##
## A recipe: {id: StringName, at: StringName (fire bench kiln wheel loom),
##            minutes: float, needs: {item: count}, makes: {item: count}}


static func recipes_at(_station: StringName) -> Array[Dictionary]:
	return []


static func can_make(inv: Inventory, recipe: Dictionary) -> bool:
	for id: StringName in recipe.get("needs", {}):
		if not inv.has(id, recipe.needs[id]):
			return false
	return true


## Consumes inputs and adds outputs. Time is charged by the caller (clock.skip).
static func make(inv: Inventory, recipe: Dictionary) -> bool:
	if not can_make(inv, recipe):
		return false
	for id: StringName in recipe.needs:
		inv.remove(id, recipe.needs[id])
	for id: StringName in recipe.get("makes", {}):
		inv.add(id, recipe.makes[id])
		Events.made.emit(id, recipe.makes[id])
	return true
