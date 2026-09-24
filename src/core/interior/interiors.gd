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


## Every door on `w`: each house whose landscape declares a kind for houses.
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
	_doors[id] = out
	return out


## The door whose key is `key` on `w`, or null.
static func by_key(w: WorldData, key: String) -> Threshold:
	for t: Threshold in thresholds(w):
		if t.key == key:
			return t
	return null


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
