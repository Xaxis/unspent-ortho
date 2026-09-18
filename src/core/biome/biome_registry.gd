class_name BiomeRegistry
## Every landscape type the game knows, discovered from src/content/biomes/.
## There is no central list: a file that declares `static func make() -> BiomeDef`
## in that directory IS a landscape type (docs/VISION.md §7.2).
##
##   BiomeRegistry.at(world, tile_pos) -> BiomeDef     the type at a place
##   BiomeRegistry.get_def(id)         -> BiomeDef     by id, null if unknown
##   BiomeRegistry.by_index(i)         -> BiomeDef     by the byte stored per tile
##   BiomeRegistry.all() / land()      -> Array[BiomeDef]
##
## Types are ordered by `BiomeDef.order` then by id, and handed indices in that
## order. The sea is always index 0; the M1 six carry orders 0..5 so they keep
## indices 1..6 whatever else is registered, and a world generated with only
## those six is the world M1 generated.
##
## Indices are stored in one byte per tile and PACKED IN PAIRS across a border
## (GenCountries), so the registry holds at most SLOTS types in one realm.

## Index slots. Border pairs pack two indices into one byte as lo * SLOTS + hi.
const SLOTS := 16
const DIR := "res://src/content/biomes"

static var _defs: Dictionary = {}
static var _by_index: Array[BiomeDef] = []
static var _land: Array[BiomeDef] = []
static var _names: PackedStringArray = PackedStringArray()
## The registry is first read from whichever thread gets there first: world gen
## on the boot worker, or a chunk being built on the pool (Ink.hand_of,
## Decor.kit). Only one of them may build it, and none may see it half built.
static var _lock := Mutex.new()
## Type ids to leave out of world generation (tests that prove parity with the
## M1 six set this; empty in a real game).
static var _muted: Dictionary = {}


static func all() -> Array[BiomeDef]:
	_ensure()
	return _by_index.duplicate()


## Every type but the sea, in index order.
static func land() -> Array[BiomeDef]:
	_ensure()
	return _land.duplicate()


static func count() -> int:
	_ensure()
	return _by_index.size()


## Every land type that can be laid in `realm`, in index order: what a world of
## that realm is MADE of. GenContext narrows the same way, so a world only ever
## holds these — which means a reader with a world in hand asks with `w.realm`,
## and anything that holds a world to "every landscape" must, or it holds a
## surface island to a landscape that exists only under the world.
static func land_in(realm: StringName) -> Array[BiomeDef]:
	_ensure()
	var out: Array[BiomeDef] = []
	for d in _land:
		if d.realms.has(realm):
			out.append(d)
	return out


## The same, as the indices a world's tiles carry.
static func land_indices_in(realm: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for d in land_in(realm):
		out.append(d.index)
	return out


## Every land type's index, in index order.
static func land_indices() -> PackedInt32Array:
	_ensure()
	var out := PackedInt32Array()
	for d in _land:
		out.append(d.index)
	return out


## The id of the type at index i, as a String (for a message).
static func name_of(i: int) -> String:
	_ensure()
	return _names[clampi(i, 0, _names.size() - 1)]


## Type ids in index order, so index i is names()[i].
static func names() -> PackedStringArray:
	_ensure()
	return _names


static func get_def(id: StringName) -> BiomeDef:
	_ensure()
	return _defs.get(id, null)


static func by_index(i: int) -> BiomeDef:
	_ensure()
	return _by_index[clampi(i, 0, _by_index.size() - 1)]


static func index_of(id: StringName) -> int:
	var d := get_def(id)
	return d.index if d != null else -1


static func at(w: WorldData, p: Vector2) -> BiomeDef:
	_ensure()
	return _by_index[clampi(w.country_at(floori(p.x), floori(p.y)), 0, _by_index.size() - 1)]


## The sea's def (index 0).
static func sea() -> BiomeDef:
	_ensure()
	return _by_index[0]


## Generate worlds from only these type ids (plus the sea). Empty restores the
## whole registry. Tests use it to prove a six-type world is the M1 world;
## nothing in a running game calls it.
static func mute_to(ids: Array) -> void:
	_muted.clear()
	_defs.clear()
	if not ids.is_empty():
		var keep := {}
		for id: StringName in ids:
			keep[id] = true
		# Read the whole registry once to learn what there is to mute.
		for d: BiomeDef in all():
			if not d.sea and not keep.has(d.id):
				_muted[d.id] = true
		_defs.clear()
	_ensure()


## Every type's problems, as lines. Empty means the registry is sound; the
## registry test fails on anything here.
static func problems() -> PackedStringArray:
	_ensure()
	var out := PackedStringArray()
	var seen_sea := 0
	for d: BiomeDef in _by_index:
		var w := "biome %s: " % d.id
		if d.id == &"":
			out.append("a biome has no id")
		if d.display_name == "":
			out.append(w + "no display name")
		if d.realms.is_empty():
			out.append(w + "no realm")
		if d.sea:
			seen_sea += 1
			continue
		if d.share_target() <= 0.0:
			out.append(w + "target share must be positive")
		if d.share.x > d.share.y:
			out.append(w + "share range is back to front")
		if d.hatch < Ink.NONE or d.hatch > Ink.LAST:
			out.append(w + "hatch %d is not an Ink hand" % d.hatch)
		if d.surface.is_null():
			out.append(w + "no surface recipe")
		if d.scatter.is_null():
			out.append(w + "no scatter recipe")
		for g: int in d.grounds:
			if g < 0 or g >= Ground.COUNT:
				out.append(w + "wash for ground %d, which is not a ground" % g)
			var col: Color = d.grounds[g]
			if col.r < 0.0 or col.g < 0.0 or col.b < 0.0 or col.r > 1.0 or col.g > 1.0 or col.b > 1.0:
				out.append(w + "wash for %s is off the palette" % Ground.NAMES[g])
		for g: int in d.decor:
			if g < 0 or g >= Ground.COUNT:
				out.append(w + "decor for ground %d, which is not a ground" % g)
		for g: int in [d.plain_ground, d.bank_ground, d.village_ground, d.pool_rim_ground, d.rock_ground, d.tip_ground]:
			if g < 0 or g >= Ground.COUNT:
				out.append(w + "ground %d is not a ground" % g)
		for k: int in d.props:
			if k < 0 or k >= PropKind.COUNT:
				out.append(w + "prop kind %d is not a kind" % k)
		for row: Array in d.ore:
			if int(row[0]) < 0 or int(row[0]) >= PropKind.COUNT:
				out.append(w + "ore kind %d is not a kind" % int(row[0]))
		for k: StringName in d.roster:
			if not Roster.DEFS.has(k):
				out.append(w + "roster has no %s" % k)
		for k: StringName in d.hazards:
			var s := float(d.hazards[k])
			if s <= 0.0 or s > 1.0:
				out.append(w + "hazard %s is %.2f, not a strength in (0, 1]" % [k, s])
		if not d.weather.is_empty():
			var total := 0.0
			for row: Array in d.weather:
				total += float(row[1])
				if not Weather.KINDS.has(row[0]):
					out.append(w + "weather has no kind %s" % row[0])
			if absf(total - 100.0) > 0.01:
				out.append(w + "weather weights sum to %.1f, not 100" % total)
		if d.music_motif != &"" and not _defs.has(d.music_motif):
			out.append(w + "music motif names no type: %s" % d.music_motif)
		for other: StringName in d.adjacency:
			if not _defs.has(other):
				out.append(w + "adjacency names no type: %s" % other)
		for other: StringName in d.tongues:
			if not _defs.has(other):
				out.append(w + "tongue names no type: %s" % other)
		out.append_array(BiomeDressing.problems(d))
		out.append_array(BiomeForms.problems(d))
	if seen_sea != 1:
		out.append("the registry needs exactly one sea, it has %d" % seen_sea)
	if _by_index.size() > SLOTS:
		out.append("%d types but only %d index slots" % [_by_index.size(), SLOTS])
	return out


static func _ensure() -> void:
	if not _defs.is_empty():
		return
	_lock.lock()
	# Another thread may have built it while this one waited for the lock.
	if not _defs.is_empty():
		_lock.unlock()
		return
	var made: Array[BiomeDef] = []
	for path: String in _files():
		var script: GDScript = load(path)
		if script == null or not script.has_method(&"make"):
			continue
		var d: BiomeDef = script.call(&"make")
		if d == null or _muted.has(d.id):
			continue
		made.append(d)
	made.sort_custom(func(a: BiomeDef, b: BiomeDef) -> bool:
		if a.order != b.order:
			return a.order < b.order
		return a.id < b.id)
	var by_index: Array[BiomeDef] = []
	var land: Array[BiomeDef] = []
	var names := PackedStringArray()
	var defs := {}
	for d in made:
		if d.sea and not by_index.is_empty():
			push_error("BiomeRegistry: the sea must sort first (order %d)" % d.order)
		d.index = by_index.size()
		by_index.append(d)
		names.append(String(d.id))
		if not d.sea:
			land.append(d)
		defs[d.id] = d
	_by_index = by_index
	_land = land
	_names = names
	# Published LAST: a non-empty _defs is what every reader tests without the
	# lock, so it may not be set while the index arrays are still being filled.
	_defs = defs
	_lock.unlock()


## Every landscape's file. A world cannot be made without compiling all of
## them, so whoever starts a world can ask for them early and compile them
## beside everything else instead of stopping to do it (BootPage).
static func scripts() -> PackedStringArray:
	return _files()


## Every biome file, sorted so discovery does not depend on the filesystem.
static func _files() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_error("BiomeRegistry: no %s" % DIR)
		return out
	for f in dir.get_files():
		# Exported builds serve .gd as .gd; the editor may list .gd.remap.
		if f.ends_with(".gd.remap"):
			f = f.trim_suffix(".remap")
		if not f.ends_with(".gd"):
			continue
		out.append(DIR + "/" + f)
	out.sort()
	return out
