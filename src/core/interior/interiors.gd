class_name Interiors
## The interior kinds, and the doors into them (docs/interiors). A landscape says
## which of its things can be walked into in its own file (`BiomeDef.interiors`:
## a host, `&"house"`, to a kind, `&"cottage"`); nothing here knows a landscape by
## name, and a landscape that declares nothing has no doors.
##
##   Interiors.kind(id)          the kind, or null
##   Interiors.thresholds(world) every door on the island, derived and kept
##   Interiors.problems()        what is wrong with the table, as lines

const RECIPES := {
	&"cottage": "res://src/content/interiors/cottage.gd",
	&"weapons_hall": "res://src/content/interiors/weapons_hall.gd",
}

static var _kinds: Dictionary = {}
## Per world OBJECT (never its seed: a test grows one seed twice): its doors.
static var _doors: Dictionary = {}


static func kind(id: StringName) -> InteriorKind:
	if not _kinds.has(id):
		if not RECIPES.has(id):
			return null
		_kinds[id] = (load(RECIPES[id]) as Script).call(&"make")
	return _kinds[id]


## Every door on `w`: each house whose landscape declares a kind for houses, and
## each works depot whose landscape declares one for `works:depot`.
## Derived from the finished island, so it never moves a thing on it, and kept
## for the life of that world.
static func thresholds(w: WorldData) -> Array[Threshold]:
	var id := w.get_instance_id()
	if _doors.has(id):
		return _doors[id]
	var out: Array[Threshold] = []
	if w.realm != Realm.INTERIOR:
		for p: WorldProp in w.props:
			if p.kind != PropKind.HOUSE:
				continue
			var land := w.country_at(floori(p.pos.x), floori(p.pos.y))
			var d := BiomeRegistry.by_index(land)
			if d == null:
				continue
			var k: StringName = d.interiors.get(&"house", &"")
			if k == &"" or kind(k) == null:
				continue
			out.append(Threshold.of_house(p, k, land))
		# And each depot of the plan whose landscape keeps a hall under its yard.
		for site: WorksSite in Works.sites(w):
			var land := w.country_at(floori(site.pos.x), floori(site.pos.y))
			var d := BiomeRegistry.by_index(land)
			if d == null:
				continue
			var k: StringName = d.interiors.get(&"works:depot", &"")
			if k == &"" or kind(k) == null:
				continue
			out.append(Threshold.of_depot(site, k, land))
	_doors[id] = out
	return out


## The door whose key is `key` on `w`, or null.
static func by_key(w: WorldData, key: String) -> Threshold:
	for t: Threshold in thresholds(w):
		if t.key == key:
			return t
	return null


## WHAT A ROOM'S STRONGBOXES HOLD, as places in the one economy (src/core/loot):
## opened, not killed, and declared for exactly the landscapes whose own files
## make a room of that kind -- asked the way the placer asks, never off a list.
## A weapons hall keeps what the plan arms and plates its machines with.
const LOOT := {
	&"weapons_hall": [
		{"item": &"scrap", "count": Vector2i(4, 8)},
		{"item": &"kit_plate", "chance": 0.5},
		{"item": &"blade_seal", "chance": 0.4},
		{"item": &"mod_capacitor", "chance": 0.35, "rarity": Rarity.RARE},
		{"item": &"mod_harmonic", "chance": 0.3, "rarity": Rarity.RARE},
		{"item": &"record", "chance": 0.25},
	],
}
static var _loot_declared := false


static func declare_loot(force: bool = false) -> void:
	if _loot_declared and not force and not Drops.table(loot_source(&"weapons_hall")).is_empty():
		return
	_loot_declared = true
	for id: StringName in LOOT:
		Drops.declare_place(loot_source(id), LOOT[id], lands_of(id))


## The table a kind's strongboxes roll on.
static func loot_source(id: StringName) -> StringName:
	return StringName("interior_%s" % id)


## Every landscape whose file makes a room of this kind behind any host.
static func lands_of(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: BiomeDef in BiomeRegistry.all():
		for host: Variant in d.interiors:
			if d.interiors[host] == id and not out.has(d.id):
				out.append(d.id)
	return out


static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for id: StringName in RECIPES:
		var k := kind(id)
		if k == null or k.id != id:
			out.append("interior %s does not make itself" % id)
			continue
		if k.recipe == null or not k.recipe.has_method(&"lay"):
			out.append("interior %s has no recipe" % id)
	for d: BiomeDef in BiomeRegistry.all():
		for host: Variant in d.interiors:
			if not RECIPES.has(d.interiors[host]):
				out.append("%s makes its %s into %s, which is no interior" % [d.id, host, d.interiors[host]])
	return out
