class_name Gear
## Gear is modular (docs/VISION.md §6): six slots on the body take one piece
## each, a piece has sockets, and modules go in the sockets. A piece and a module
## both declare resistances and may grant an ability. The tables are in
## `src/content/items.gd` with everything else the player can carry, so a new
## piece of kit is one row there and nothing here changes.
##
## Item fields this package reads (Items schema):
##   slot: StringName     head body hands back tool craft (a wearable piece)
##   sockets: int         modules it takes
##   module: true         it is a module; `fits` lists the slots it may sit in
##   resist: {hazard: 0..1}
##   ability: StringName  the ability it grants while it is fitted
##   tier: StringName     made | mended | found (docs/ART.md §12)
##
## Slots, and what each means:
##   head   what is over your face and eyes: masks, hats, lenses
##   body   what is over your chest: wraps, oilskins, vests
##   hands  what you grip and stand with: braces, gauntlets, boots
##   back   what you carry on it: rigs, wings, plate
##   tool   the thing in your hand (Inventory.held owns it; the loadout only
##          sockets modules onto it)
##   craft  the vehicle you are on (M2 wave B; empty until crafts land)

const SLOTS: Array[StringName] = [&"head", &"body", &"hands", &"back", &"tool", &"craft"]
## The slot the thing in hand fills: the inventory owns it, not the loadout.
const HAND_SLOT: StringName = &"tool"
const TIERS: Array[StringName] = [&"made", &"mended", &"found"]


static func slot_of(id: StringName) -> StringName:
	return Items.def(id).get("slot", &"")


static func is_wearable(id: StringName) -> bool:
	return slot_of(id) != &""


static func is_module(id: StringName) -> bool:
	return bool(Items.def(id).get("module", false))


static func tier(id: StringName) -> StringName:
	var d := Items.def(id)
	if d.has("tier"):
		return d["tier"]
	# Anything else reads from what it is made of: machine tech taken whole is found.
	return &"found" if d.get("stuff", &"") == &"found" else &"made"


## Mended things are FOUND parts bound with MADE cord and must be drawn as both
## (docs/ART.md §12). The slate's icons and the world models ask this.
static func is_mended(id: StringName) -> bool:
	return tier(id) == &"mended"


static func sockets(id: StringName) -> int:
	var d := Items.def(id)
	if d.has("sockets"):
		return int(d["sockets"])
	# Anything with a haft takes one binding, so the hand's slot is never a slot
	# that answers nothing: the tool itself is chosen in carrying, but what is
	# bound to it is chosen here.
	return 1 if bool(d.get("tool", false)) else 0


## A wearable piece goes in its own slot; a module goes in any slot it `fits`.
static func fits(id: StringName, slot: StringName) -> bool:
	if id == &"":
		return false
	if is_module(id):
		var f: Array = Items.def(id).get("fits", [])
		return f.has(slot)
	return slot_of(id) == slot


static func resist_of(id: StringName) -> Dictionary:
	return Items.def(id).get("resist", {})


static func ability_of(id: StringName) -> StringName:
	return Items.def(id).get("ability", &"")


## Every wearable piece for `slot`, in a stable order (the loadout page cycles them).
static func wearables_for(slot: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Items.DEFS:
		if not is_module(id) and slot_of(id) == slot:
			out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## Two pieces that each keep half the cold off keep three quarters of it off, not
## all of it: each takes its share of what is left. Never reaches 1.
static func combine(into: Dictionary, add: Dictionary) -> void:
	for id: Variant in add:
		var have := clampf(float(into.get(id, 0.0)), 0.0, 1.0)
		var more := clampf(float(add[id]), 0.0, 1.0)
		into[StringName(id)] = 1.0 - (1.0 - have) * (1.0 - more)


## The whole loadout's resistances: hazard id -> 0..1, for Body.resist.
##
## The last step is the modules arguing: a part that pays for another's heat, a
## part that shouts through another's hush (`Modifiers`, docs/VISION.md §6.1).
## It is here because this is the ONE place the kit is added up, so the body, the
## hazards system, the slate and every test see the same answer.
static func resist_total(loadout: Loadout) -> Dictionary:
	var out: Dictionary = {}
	for id in loadout.all_ids():
		combine(out, resist_of(id))
	Modifiers.settle(loadout.all_ids(), out)
	return out


## The ability ids the loadout grants, in slot order, without repeats. A conflict
## can smother one — a signature spoofed by a part that shouts is no signature —
## so the last word is `Modifiers` (docs/VISION.md §6.1).
static func abilities_of(loadout: Loadout) -> Array[StringName]:
	var out: Array[StringName] = []
	for slot in SLOTS:
		for id in loadout.ids_in(slot):
			var a := ability_of(id)
			if a != &"" and not out.has(a):
				out.append(a)
	return Modifiers.allow(loadout.all_ids(), out)


## What the slate calls a slot.
static func label(slot: StringName) -> String:
	return String(slot)
