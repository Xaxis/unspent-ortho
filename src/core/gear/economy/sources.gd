class_name Sources
## Where a thing really comes from, walked back to the world (docs/VISION.md
## §6.1: "Every weapon, armour and power is obtainable"). Nothing here is
## content: it reads the landscape registry, `Takes`, `Roster`, `Recipes` and the
## economy's own tables and answers one question — is there a path a player can
## actually walk to this, and what is it?
##
## `path_to(id)` is the answer, as steps:
##   {how: &"take", item, prop, lands}      pick it up where that prop stands
##   {how: &"kill", item, kind, lands}      cut it out of one kind of machine
##   {how: &"make", item, recipe, at, tier} make it, and then its own steps
##
## A test walks these (`tests/gear_economy/test_obtainable.gd`) and the slate can
## say them out loud, which is the same thing said twice on purpose: a promise
## that only a test believes is a promise a player never sees.

## How deep a recipe chain may go before something is wrong with the data.
const DEPTH := 12

static var _lands_by_item: Dictionary = {}
static var _made_by: Dictionary = {}


## Every landscape type a player walks on (the sea is not one).
static func lands() -> Array[StringName]:
	var out: Array[StringName] = []
	for d: BiomeDef in BiomeRegistry.land():
		out.append(d.id)
	return out


## Prop kinds a landscape puts on the ground: what it scatters, and its ore.
static func props_of(d: BiomeDef) -> Array[int]:
	var out: Array[int] = []
	out.append_array(d.props)
	for row: Variant in d.ore:
		var pair := row as Array
		if pair != null and not pair.is_empty() and not out.has(int(pair[0])):
			out.append(int(pair[0]))
	return out


## Landscape id -> every item that can be taken from something standing in it.
## Built once; a landscape's own material is the difference between these lists.
static func lands_by_item() -> Dictionary:
	if not _lands_by_item.is_empty():
		return _lands_by_item
	for d: BiomeDef in BiomeRegistry.land():
		for kind: int in props_of(d):
			for o: Dictionary in Takes.options(kind):
				_add_land(StringName(o.get("item", &"")), d.id)
				for b: Variant in (o.get("bonus", []) as Array):
					if b is StringName or b is String:
						_add_land(StringName(b), d.id)
	return _lands_by_item


static func _add_land(item: StringName, land: StringName) -> void:
	if item == &"":
		return
	if not _lands_by_item.has(item):
		var list: Array[StringName] = []
		_lands_by_item[item] = list
	var at: Array[StringName] = _lands_by_item[item]
	if not at.has(land):
		at.append(land)


## The landscapes a raw material can be taken in, in registry order.
##
## A prop kind NO landscape declares is one the world lays itself — the ruin, what
## people left behind, the plan's works — and those are laid across the whole
## island, so what comes off them can be had anywhere. Without this, plate is
## unreachable and therefore so is the knife, which is how the first version of
## this walker decided the entire game was unobtainable.
static func lands_yielding(item: StringName) -> Array[StringName]:
	var known: Array[StringName] = lands_by_item().get(item, [] as Array[StringName])
	if not known.is_empty():
		return known
	var kind := prop_yielding(item)
	if kind >= 0 and not _scattered_by_a_landscape(kind):
		return lands()
	return [] as Array[StringName]


## Whether any landscape puts this prop kind on the ground itself.
static func _scattered_by_a_landscape(kind: int) -> bool:
	for d: BiomeDef in BiomeRegistry.land():
		if props_of(d).has(kind):
			return true
	return false


## The prop a raw material comes off, and the take option that gives it, so a
## path can say "off a vent" rather than "somewhere in the burning". A thing that
## only ever comes up as a `bonus` counts: a charge is never the thing you went to
## a relay for, and it is still the only way to hold one.
static func prop_yielding(item: StringName) -> int:
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			if _gives(o, item):
				return kind
	return -1


## The take option that yields `item`, {} if nothing does. A `ground` gate on it
## is how a landscape keeps something to itself without a prop of its own.
static func option_yielding(item: StringName) -> Dictionary:
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			if _gives(o, item):
				return o
	return {}


static func _gives(o: Dictionary, item: StringName) -> bool:
	if StringName(o.get("item", &"")) == item:
		return true
	for b: Variant in (o.get("bonus", []) as Array):
		if (b is StringName or b is String) and StringName(b) == item:
			return true
	return false


## Roster kinds that can be met in a landscape: the ones it names, and the ones
## that keep to no country at all.
static func kinds_in(land: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var d := BiomeRegistry.get_def(land)
	if d != null:
		for k: Variant in d.roster:
			out.append(StringName(k))
	for id: StringName in Roster.kinds():
		if out.has(id):
			continue
		var where: Dictionary = Roster.row(id).get("where", {})
		var countries: Array = where.get("countries", [])
		if countries.is_empty() or countries.has(String(land)):
			out.append(id)
	return out


## Every landscape one kind of machine can be met in.
static func lands_of_kind(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for land: StringName in lands():
		if kinds_in(land).has(kind):
			out.append(land)
	return out


## item -> the recipe that makes it (the first, which is the cheapest rung).
static func made_by() -> Dictionary:
	if not _made_by.is_empty():
		return _made_by
	for r: Dictionary in Recipes.LIST:
		for id: Variant in (r.get("makes", {}) as Dictionary):
			var key := StringName(id)
			if not _made_by.has(key):
				_made_by[key] = r
	return _made_by


## Every recipe that makes `id`, cheapest rung first.
static func recipes_making(id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in Recipes.LIST:
		if (r.get("makes", {}) as Dictionary).has(id):
			out.append(r)
	return out


## How a player gets `id`, as one step plus whatever that step needs first.
## Empty means nothing in the world leads to it.
static func path_to(id: StringName, depth: int = DEPTH) -> Array[Dictionary]:
	if depth <= 0:
		return []
	# Off the ground.
	var here := lands_yielding(id)
	if not here.is_empty():
		return [{"how": &"take", "item": id, "prop": prop_yielding(id), "lands": here}]
	# Out of one kind of machine: an elite material cut out of it, or a thing it
	# was carrying (a charge, its own tool).
	var kind := EliteStock.dropped_by(id)
	if kind != &"" and Roster.has(kind):
		return [{"how": &"kill", "item": id, "kind": kind, "lands": lands_of_kind(kind)}]
	# Made, if everything it takes can itself be got.
	for r: Dictionary in recipes_making(id):
		var under: Array[Dictionary] = []
		var ok := true
		for want: Variant in _inputs(r):
			var sub := path_to(StringName(want), depth - 1)
			if sub.is_empty():
				ok = false
				break
			under.append_array(sub)
		if not ok:
			continue
		var out: Array[Dictionary] = under
		out.append({"how": &"make", "item": id, "recipe": StringName(r.get("id", &"")),
			"at": StringName(r.get("at", &"hand")), "tier": CraftTiers.of_recipe(r)})
		return out
	return []


## Everything a recipe wants in hand: what it spends, and what it keeps.
static func _inputs(r: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in (r.get("needs", {}) as Dictionary):
		out.append(StringName(id))
	for id: Variant in (r.get("keeps", {}) as Dictionary):
		out.append(StringName(id))
	return out


static func reachable(id: StringName) -> bool:
	return not path_to(id).is_empty()


## The path said the way a person would say it, for the slate and for a failing
## test that has to tell somebody what is missing.
static func said(id: StringName) -> String:
	var steps := path_to(id)
	if steps.is_empty():
		return "%s: no way to it" % id
	var words := PackedStringArray()
	for s: Dictionary in steps:
		match StringName(s.get("how", &"")):
			&"take":
				var prop := int(s.get("prop", -1))
				var where: Array = s.get("lands", [])
				words.append("take %s off a %s in the %s" % [s.get("item"),
					PropKind.NAMES[prop] if prop >= 0 and prop < PropKind.NAMES.size() else "prop",
					" or ".join(_strings(where))])
			&"kill":
				words.append("cut %s out of a %s in the %s" % [s.get("item"), s.get("kind"),
					" or ".join(_strings(s.get("lands", [])))])
			&"make":
				words.append("make %s %s" % [s.get("item"), CraftTiers.words(int(s.get("tier", 0)))])
	return ", then ".join(words)


static func _strings(xs: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for x: Variant in xs:
		out.append(String(x))
	return out


## Tests and a reloaded world start from a fresh reading of the tables.
static func clear() -> void:
	_lands_by_item.clear()
	_made_by.clear()
