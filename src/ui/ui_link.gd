class_name UiLink
## The notebook's one door into rules other packages own. Survival, Crafting
## and Inventory grow richer helpers in parallel with this package; every call
## here uses the richer helper when it exists and falls back to the plain
## contract (Crafting.can_make/make, Inventory.add/remove, Body fields) when it
## does not, so the notebook works before, during and after those packages land.
##
## Classes that may not exist yet are reached by global class name, never by
## identifier, so this file parses without them.

static var _scripts := {}


## A script by its class_name, or null if no such class is registered.
static func script_named(n: StringName) -> Script:
	if _scripts.has(n):
		return _scripts[n]
	var found: Script = null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c.class == n:
			found = load(String(c.path)) as Script
			break
	_scripts[n] = found
	return found


## True if class `n` exists and has static `method`.
static func offers(n: StringName, method: StringName) -> bool:
	var s := script_named(n)
	return s != null and s.has_method(method)


static func _call(n: StringName, method: StringName, args: Array) -> Variant:
	return script_named(n).callv(method, args)


# --- the world around the player ---------------------------------------------

## Stations whose recipes can be made where the player stands, nearest first,
## ending with &"hand" when any hand recipe exists.
static func stations_here(game: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	if game != null and offers(&"Survival", &"stations_near"):
		out.assign(_call(&"Survival", &"stations_near", [game]))
	else:
		if game != null:
			var s := UiRules.station_near(game.query, game.player.pos)
			if s != &"":
				out.append(s)
		out.append(&"hand")
	if out.has(&"hand") and Crafting.recipes_at(&"hand").is_empty():
		out.erase(&"hand")
	return out


## What `use` would do now ("pine - fell"), or null when survival does not say.
static func use_hint(game: Game) -> Variant:
	if offers(&"Survival", &"describe_target"):
		return String(_call(&"Survival", &"describe_target", [game]))
	return null


# --- carrying ------------------------------------------------------------------

## The heading a thing is listed under in the notebook.
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
	if inv != null and inv.has_method("creel"):
		return float(inv.call("creel"))
	return UiRules.creel(body) if body != null else UiRules.CREEL


## The worn piece of kit, or &"".
static func worn(inv: Inventory) -> StringName:
	var w: Variant = inv.get("worn")
	return w if w is StringName else &""


static func can_wear(inv: Inventory) -> bool:
	return inv.has_method("wear_kit")


## Put on (or take off, with &"") a piece of kit.
static func wear(inv: Inventory, id: StringName) -> bool:
	return can_wear(inv) and bool(inv.call("wear_kit", id))


## Hold a carried thing (&"" = bare hands). Survival also puts it in the figure's hand.
static func hold(game: Game, inv: Inventory, id: StringName) -> void:
	if game != null and game.inventory == inv and offers(&"Survival", &"hold"):
		_call(&"Survival", &"hold", [game, id])
	else:
		inv.set_held(id)


## Eat one. Returns true if it was eaten. Survival charges the clock and the
## body; without it the notebook feeds the body by the item's hours.
static func eat(game: Game, inv: Inventory, body: Body, id: StringName) -> bool:
	if game != null and game.inventory == inv and offers(&"Survival", &"eat"):
		return bool(_call(&"Survival", &"eat", [game, id]))
	if not inv.remove(id):
		return false
	var now := game.clock.minutes if game != null else 0.0
	if body != null:
		body.fed_until = maxf(body.fed_until, now) + float(Items.def(id).get("feeds", 0.0)) * 60.0
	Events.sfx.emit(&"eat", Vector3.ZERO)
	return true


# --- making ----------------------------------------------------------------------

## {item: n short} for a recipe, counting kept tools as needed.
static func missing(inv: Inventory, r: Dictionary) -> Dictionary:
	if offers(&"Crafting", &"missing"):
		return _call(&"Crafting", &"missing", [inv, r])
	var out := {}
	for group: String in ["needs", "keeps"]:
		var d: Dictionary = r.get(group, {})
		for id: StringName in d:
			var short := int(d[id]) - inv.count(id)
			if short > 0:
				out[id] = maxi(int(out.get(id, 0)), short)
	return out


## "" if the recipe can be made here now, else one plain sentence why not.
static func why_not(game: Game, inv: Inventory, r: Dictionary) -> String:
	if game != null and game.inventory == inv and offers(&"Crafting", &"why_not"):
		var why := String(_call(&"Crafting", &"why_not", [game, r]))
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
		return "Short of %s %s." % [count_word(int(m[id])), UiRules.item_name(id)]
	return "Not now."


## Make it. Survival's make_in charges the clock, plays the work and builds
## stations; the plain contract moves goods and the page charges the clock.
static func make(game: Game, inv: Inventory, r: Dictionary) -> bool:
	if game != null and game.inventory == inv and offers(&"Crafting", &"make_in"):
		return bool(_call(&"Crafting", &"make_in", [game, r]))
	if not Crafting.make(inv, r):
		return false
	var minutes := float(r.get("minutes", 0.0))
	if game != null and minutes > 0.0:
		game.clock.skip(minutes)
		Events.time_skipped.emit(minutes, &"make")
	return true


static func count_word(n: int) -> String:
	const WORDS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	return WORDS[n] if n >= 0 and n < WORDS.size() else str(n)
