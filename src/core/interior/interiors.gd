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
	&"bunker": "res://src/content/interiors/bunker.gd",
	&"roundhouse": "res://src/content/interiors/roundhouse.gd",
	&"stilt_room": "res://src/content/interiors/stilt_room.gd",
	&"tower_lobby": "res://src/content/interiors/tower_lobby.gd",
	&"cliff_room": "res://src/content/interiors/cliff_room.gd",
	&"hulk_hold": "res://src/content/interiors/hulk_hold.gd",
	&"rooted_floor": "res://src/content/interiors/rooted_floor.gd",
	&"tenement": "res://src/content/interiors/tenement.gd",
	&"maintenance_bay": "res://src/content/interiors/maintenance_bay.gd",
	&"foundry": "res://src/content/interiors/foundry.gd",
	&"data_hall": "res://src/content/interiors/data_hall.gd",
	&"laid_table": "res://src/content/interiors/laid_table.gd",
	&"saw_hall": "res://src/content/interiors/saw_hall.gd",
	&"frozen_hold": "res://src/content/interiors/frozen_hold.gd",
	&"home": "res://src/content/interiors/home.gd",
	&"squat": "res://src/content/interiors/squat.gd",
}

## Which of a sparse landscape's houses have somebody in them (`home.open`).
const OPEN_SALT := 0x5C0A7
static var _kinds: Dictionary = {}
## Per world OBJECT (never its seed: a test grows one seed twice): its doors.
static var _doors: Dictionary = {}


static func kind(id: StringName) -> InteriorKind:
	if not _kinds.has(id):
		if not RECIPES.has(id):
			return null
		_kinds[id] = (load(RECIPES[id]) as Script).call(&"make")
	return _kinds[id]


## Every door on `w`: each house whose landscape declares a kind for its form or
## for houses at all, and
## each works depot whose landscape declares one for `works:depot`.
## Derived from the finished island, so it never moves a thing on it, and kept
## for the life of that world.
static func thresholds(w: WorldData) -> Array[Threshold]:
	var id := w.get_instance_id()
	if _doors.has(id):
		return _doors[id]
	var out: Array[Threshold] = []
	if w.realm != Realm.INTERIOR:
		for p: WorldProp in w.each_prop():
			if p.kind != PropKind.HOUSE:
				continue
			var land := w.country_at(floori(p.pos.x), floori(p.pos.y))
			var d := BiomeRegistry.by_index(land)
			if d == null:
				continue
			var form := form_of(p, w.seed_value, land)
			var k := house_kind(d, form)
			if k == &"" or kind(k) == null:
				continue
			# A landscape may keep somebody in only some of its houses
			# (`home.open`, a share, dealt by where the house stands); its own
			# forms' rooms are always open.
			if not d.interiors.has(StringName("form:%s" % form)) and d.home.has("open") \
					and Rng.hash01(w.seed_value, floori(p.pos.x * 4.0), floori(p.pos.y * 4.0), OPEN_SALT) >= float(d.home.open):
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
		# And each landmark whose landscape keeps something under it
		# (`landmark:KIND` -> a kind of room).
		for site: LandmarkSite in Landmarks.sites(w):
			var land := w.country_at(floori(site.pos.x), floori(site.pos.y))
			var d := BiomeRegistry.by_index(land)
			if d == null:
				continue
			var k: StringName = d.interiors.get(StringName("landmark:%s" % site.kind), &"")
			if k == &"" or kind(k) == null:
				continue
			out.append(Threshold.of_landmark(site, k, land))
	_doors[id] = out
	return out


## Which form of its landscape's building stock a house was dealt: the one its
## model draws (PropModels.variant_of), so the room behind it is that form's.
static func form_of(p: WorldProp, seed_value: int, land: int) -> StringName:
	var stock := BiomeForms.of(land).stock
	if stock.is_empty():
		return &""
	return stock[clampi(PropModels.variant_of(p, seed_value, land), 0, stock.size() - 1)]


## The kind of room behind a house of form `form` here: the landscape's own for
## that form (`form:ID`) when it has one, which is how one landscape's roundhouse
## is not another's cottage, else its kind for every house, else none.
static func house_kind(d: BiomeDef, form: StringName) -> StringName:
	if form != &"":
		var own: StringName = d.interiors.get(StringName("form:%s" % form), &"")
		if own != &"":
			return own
	return d.interiors.get(&"house", &"")


## WHICH DOOR A PLAYER MEANS: of the doors within `reach` of `at`, the one whose
## house they are facing, before the nearest. Two houses can face each other
## across a channel with their doors half a tile apart (GEN 28's drowned city:
## a stilt house and a hulk, 0.59): nearest-first opened the house behind the
## player. Returns null when no door is in reach.
static func door_for(doors: Array[Threshold], at: Vector2, facing: float, reach: float) -> Threshold:
	var look := Vector2.from_angle(facing)
	var best: Threshold = null
	var score := INF
	for t: Threshold in doors:
		var d := t.door.distance_to(at)
		if d > reach:
			continue
		var to_house := t.host - at
		var faced := maxf(0.0, look.dot(to_house.normalized())) if to_house.length() > 0.01 else 0.0
		var sc := d - 1.5 * faced
		if sc < score:
			score = sc
			best = t
	return best


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
	# What the burning's foundry casts and keeps at the end of its line: its own
	# landscape's glass, always, and the lance body it was pouring, always -- the
	# reason to go down past the warden -- and the scrap of the pour.
	&"foundry": [
		{"item": &"cinder_glass", "count": Vector2i(1, 2)},
		{"item": &"lance_casting"},
		{"item": &"scrap", "count": Vector2i(3, 6)},
		{"item": &"blade_seal", "chance": 0.3},
		{"item": &"record", "chance": 0.2},
	],
	# What the machines keep where they think: their own files, always, and now
	# and then a damper -- a hall where the hum hides a body is where the thing
	# that hides a blow is found.
	&"data_hall": [
		{"item": &"record", "count": Vector2i(2, 3)},
		{"item": &"scrap", "count": Vector2i(1, 3)},
		{"item": &"mod_damp", "chance": 0.3, "rarity": Rarity.RARE},
	],
	# What the pinewood's saw hall dried in its kiln: seasoned timber, always, as
	# much as a settlement's cellar or tower wants -- the reason to go in -- and
	# the scrap of the saw.
	&"saw_hall": [
		{"item": &"seasoned_timber", "count": Vector2i(6, 10)},
		{"item": &"scrap", "count": Vector2i(1, 3)},
		{"item": &"record", "chance": 0.15},
	],
	# What a trawler's crew kept in their sea chest their last winter: the lamp's
	# oil and its rags, fish smoked against it, and now and then a record.
	&"frozen_hold": [
		{"item": &"smoked", "count": Vector2i(1, 3)},
		{"item": &"oil", "count": Vector2i(1, 2), "chance": 0.8},
		{"item": &"rag", "count": Vector2i(1, 3), "chance": 0.7},
		{"item": &"record", "chance": 0.3},
	],
	# What somebody kept who knew what was coming: their own records first, the
	# makings of light, and the odd thing they took off a machine to study.
	&"bunker": [
		{"item": &"record", "chance": 0.7},
		{"item": &"oil", "count": Vector2i(1, 2), "chance": 0.8},
		{"item": &"wick", "chance": 0.6},
		{"item": &"rag", "count": Vector2i(1, 3), "chance": 0.7},
		{"item": &"scrap", "count": Vector2i(1, 3)},
		{"item": &"kit_lens", "chance": 0.3, "rarity": Rarity.RARE},
		{"item": &"mod_hush", "chance": 0.25, "rarity": Rarity.RARE},
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
