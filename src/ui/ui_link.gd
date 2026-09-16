class_name UiLink
## The slate's one door into rules other packages own: Survival (targets,
## stations, eating, holding), Crafting (what is short, why not, making) and
## Inventory (the creel, worn kit). Body is only ever read. A page shown without
## a running game (gallery, tests) gets the plain Crafting contract instead.


# --- the world around the player ---------------------------------------------

## Stations whose recipes can be made where the player stands, nearest first,
## ending with &"hand" when any hand recipe exists.
static func stations_here(game: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	if game != null:
		out.assign(Survival.stations_near(game))
	else:
		out.append(&"hand")
	if out.has(&"hand") and Crafting.recipes_at(&"hand").is_empty():
		out.erase(&"hand")
	return out


## What `use` would do now ("pine - fell"), or "" with nothing in front.
static func use_hint(game: Game) -> String:
	return Survival.describe_target(game)


# --- carrying ------------------------------------------------------------------

## The heading a thing is listed under on the slate.
static func group_of(id: StringName) -> StringName:
	var d := Items.def(id)
	match d.get("group", &""):
		&"tool": return &"tools"
		&"found": return &"found"
		&"kit": return &"to wear"
		&"food": return &"food"
		&"material", &"good": return &"goods"
	if d.get("stuff", &"") == &"found" or id == &"wick":
		return &"found"
	if d.get("tool", false):
		return &"tools"
	if d.has("kit"):
		return &"to wear"
	if float(d.get("feeds", 0.0)) > 0.0:
		return &"food"
	return &"goods"


## Load carried before it tells.
static func creel(inv: Inventory, body: Body) -> float:
	if inv != null:
		return inv.creel()
	return UiRules.creel(body) if body != null else UiRules.CREEL


## The worn piece of kit, or &"".
static func worn(inv: Inventory) -> StringName:
	return inv.worn


static func can_wear(inv: Inventory) -> bool:
	return inv != null


## Put on (or take off, with &"") a piece of kit.
static func wear(inv: Inventory, id: StringName) -> bool:
	return inv.wear_kit(id)


## Hold a carried thing (&"" = bare hands). Survival also puts it in the figure's hand.
static func hold(game: Game, inv: Inventory, id: StringName) -> void:
	if game != null and game.inventory == inv:
		Survival.hold(game, id)
	else:
		inv.set_held(id)


## Put down `n` of a carried thing through survival, which owns the heap it
## goes on, the refusals (a hostile close, nowhere to lay it) and the line
## said. Returns how many were put down; 0 without a running game to lay it in.
static func drop(game: Game, inv: Inventory, id: StringName, n: int = 1) -> int:
	if game == null or game.inventory != inv:
		return 0
	return Survival.drop(game, id, n)


## True when eating can be done from the slate: survival owns hunger, so
## only its `eat` feeds the body. The slate never writes Body itself.
static func can_eat(game: Game, inv: Inventory) -> bool:
	return game != null and game.inventory == inv


## Eat one through survival. Returns true if it was eaten.
static func eat(game: Game, inv: Inventory, id: StringName) -> bool:
	return can_eat(game, inv) and Survival.eat(game, id)


# --- making ----------------------------------------------------------------------

## {item: n short} for a recipe, counting kept tools as needed.
static func missing(inv: Inventory, r: Dictionary) -> Dictionary:
	return Crafting.missing(inv, r)


## "" if the recipe can be made here now, else one plain sentence why not.
static func why_not(game: Game, inv: Inventory, r: Dictionary) -> String:
	if game != null and game.inventory == inv:
		var why := Crafting.why_not(game, r)
		# Survival says "Not without what it needs."; the page can say exactly what.
		if why != "" and not missing(inv, r).is_empty():
			return short_line(inv, r)
		return why
	if Crafting.can_make(inv, r):
		return ""
	if not missing(inv, r).is_empty():
		return short_line(inv, r)
	var tool := StringName(r.get("tool", &""))
	if tool != &"":
		return "Not without something to %s with." % tool
	return "Not now."


## "Short of two charcoal." for the first thing short.
static func short_line(inv: Inventory, r: Dictionary) -> String:
	var m := missing(inv, r)
	for id: StringName in m:
		return "Short of %s." % UiRules.counted(UiRules.item_name(id), int(m[id]))
	return "Not now."


## Make it. In a game Crafting.make_in charges the clock, plays the work and
## builds stations; without one the plain contract only moves goods.
static func make(game: Game, inv: Inventory, r: Dictionary) -> bool:
	if game != null and game.inventory == inv:
		return Crafting.make_in(game, r)
	return Crafting.make(inv, r)


static func count_word(n: int) -> String:
	const WORDS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	return WORDS[n] if n >= 0 and n < WORDS.size() else str(n)
