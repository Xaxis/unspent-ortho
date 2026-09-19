class_name Landmarks
## The places worth the walk (docs/VISION.md §3, §8), and the pure rules about
## where they stand and what they hold.
##
##   Landmarks.for_land(id)       the kinds that landscape holds
##   Landmarks.sites(world)       every landmark in a world, in a fixed order
##   Landmarks.declare_loot()     pour their tables into src/core/loot
##   Landmarks.problems()         everything wrong with them, as lines
##
## A landmark is not scenery. It is the other half of the reason to cross a
## landscape — the machines' works are why the land is dangerous, and these are
## why it is worth being in anyway. Each one carries the evidence of what was
## lost (a lighthouse with a dead lamp; a fire tower whose stair has gone; the
## tall stack blinking over the snow; stones somebody cast in concrete round
## rebar; a clerk's post with its files blown out over the ground) and each one
## holds something the gear economy declared and nothing else in the world hands
## over.
##
## Nothing here places a prop or writes to a world: `22_landmarks` draws them and
## remembers what has been opened. Placement is DERIVED from the island, so the
## lighthouse a player walked to on seed 1 is on the same rock on seed 1 forever.

## Landmarks wanted per region, before the ground has its say. A region usually
## yields fewer: a kind whose ground is not in it is simply not placed.
const PER_REGION := 3
## The smallest run of a landscape that is a PLACE and not a corner. Below this a
## region is a scrap of one landscape caught in the side of another, and a tower
## put in it is a tower standing in somebody else's frame — and, because the
## rounds give the least room the first word, a fifty-tile spur was taking a
## landmark off the three-thousand-tile landscape beside it.
const REGION_TILES := 400
## Tiles between the candidates a region is searched on. The COARSE sweep is
## tried first and almost always answers — a region only wants three places out
## of thousands of tiles — and the fine one is run again only over a region the
## coarse sweep could not fill, which on a 512-tile world is the difference
## between 60 ms on the loading page and a quarter of a second.
const STRIDE := 5
const COARSE := 11
## Candidates below which a region is swept again at the fine stride: a thin pool
## means the coarse sweep walked past the region's ground, and a fat one means it
## found plenty and the picking is what ran out.
const FINE_BELOW := 12
## Tiles a landmark keeps from where the player wakes. Not a wall — the first
## one should be a morning's walk, not a week's.
const CLEAR_HOME := 26.0
const CLEAR_VILLAGE := 18.0
## And off the machines' own works, which are everywhere the survey line goes. A
## landmark twelve tiles from a pipeline is a scene; one on top of it is a mess.
##
## IT GIVES WAY TO THE DENSITY, because a landscape can BE their works. Held at
## twelve everywhere, the scrapwood — whose whole ground is what the machines
## left — held no landmark at all on seed 1 and one on seed 7, and the test
## passed because it only asked regions over two thousand tiles for two. So the
## rule a region really keeps is "not on top of one", and twelve is only what it
## keeps where there is room for twelve.
const CLEAR_WORKS := 12.0
const CLEAR_WORKS_FLOOR := 4.0
## Tiles the player has to come within before a landmark goes on their map, and
## before they are told what it is. Well inside the nearest thing any kind claims
## to be readable from, so every one of them is a shape on the horizon first and
## a named place second — which is the whole order a landmark is experienced in.
##
## Nine, and not sixteen, because the frame is only so big: see `read_reach`.
const FOUND_AT := 9.0
## Tiles from the cache at which it can be opened, and how far in FRONT of the
## silhouette the cache lies: every landmark is approached from its own face, so
## a player who can see what a place is can also see where its hands go.
const OPEN_REACH := 2.8
const CACHE_OUT := 1.9
## Where a guarded landmark's keeper comes out, in tiles from the cache.
const GUARD_RING := 7.0
## Islands whose places are remembered at once. A game holds one realm's world
## and raises another when the player walks toward a shaft; past that, the oldest
## answers are no longer anybody's.
const CACHE_MOST := 6
## However hard the siting has to loosen, two landmarks never come closer than
## this: nearer than about twenty tiles they are in each other's frame, and two
## silhouettes in one frame is one silhouette and half the reason for either.
const MIN_APART := 24.0

## THE FRAME IS THE LIMIT, NOT THE MODEL. The play camera is orthographic, 15
## world units of view height at 16:9 and pitched 57 degrees, so it shows about
## 26.7 tiles across and 17.9 tiles of ground up and down — and a tower thirty
## tiles away is not dim or small, it is OFF THE PICTURE. The first version of
## this package wrote `sees` at 20-34 tiles because that is what VISION §3 asks
## for, and every far-read line it said was said about a thing the player could
## not see; the only frames that showed the silhouettes were shot at twice the
## play camera's zoom.
##
## So a kind's reach is derived from the camera and its own height, and
## `tests/landmarks/test_models.gd` holds every kind to it:
##
##   - up the screen, a thing goes off the TOP: its base is in frame only to
##     `half_height / sin(pitch)`, about 8.9 tiles;
##   - down the screen, height BUYS distance, because the top of the thing rises
##     in frame as its base falls out of it: `(half_height + high * cos(pitch)) /
##     sin(pitch)`, which is 13.7 tiles for a lighthouse and 16 for the stack;
##   - across the screen there is no height to spend: `half_height * aspect`,
##     about 13.3 tiles, whatever is standing there.
##
## The honest reach is the smaller of the last two: the distance at which a kind
## is in frame over most of the compass. Going taller past that buys nothing —
## which is why the stack, at eleven and a half units, reads no further than the
## lighthouse at seven, and why growing these models is not how the twenty-tile
## read of VISION §3 is won (docs/ROADMAP.md).
static func read_reach(view_height: float, pitch_deg: float, aspect: float, high: float) -> float:
	var half := view_height * 0.5
	var p := deg_to_rad(pitch_deg)
	var down := (half + high * cos(p)) / maxf(sin(p), 1e-3)
	return minf(half * aspect, down)


## The kinds. Each is a silhouette of its own, and each stands in three to five
## landscapes so that every landscape holds three or more without the game
## needing forty drawings before it holds any (docs/ROADMAP.md, M3 grows them).
static var _defs: Dictionary = {}
static var _order: Array[LandmarkDef] = []
static var _declared := false
## Where they stand, per world. Siting is a sweep of the island and the answer
## never changes for one island, so it is worked out once: the system, the map
## and a shot's `--place` all ask for the same list.
static var _cache: Dictionary = {}


static func _build() -> void:
	if not _order.is_empty():
		return
	var out: Array[LandmarkDef] = []

	var light := LandmarkDef.make(&"lighthouse", "the drowned light")
	light.lands = [&"coast"]
	light.wants = &"shore"
	light.sees = 13.0
	light.far = "A tower out on the rocks, and no light in it."
	light.near = "The lamp room is open to the weather. The lens is still in its cradle."
	light.mark = &"light"
	out.append(light)

	var mast := LandmarkDef.make(&"leaning_mast", "the leaning mast")
	mast.lands = [&"moss", &"snowfield", &"pinewood", &"slums", &"frost_sea", &"drowned_city"]
	mast.wants = &"water"
	mast.sees = 13.0
	mast.far = "A mast, leaning, with its guys down."
	mast.near = "It went over years ago and nobody came. The head cabinet is still shut."
	mast.mark = &"mast"
	mast.guarded = true
	out.append(mast)

	var tower := LandmarkDef.make(&"firewatch", "the fire tower")
	tower.lands = [&"pinewood", &"coast", &"scrapwood"]
	tower.wants = &"high"
	tower.sees = 13.0
	tower.far = "A tower on the rise, and its stair is gone."
	tower.near = "Somebody lived up there after the stair went. Their kit is still on the deck."
	tower.mark = &"tower"
	out.append(tower)

	var stack := LandmarkDef.make(&"blinking_stack", "the tall stack")
	stack.lands = [&"snowfield", &"bonelands", &"burning", &"scrapwood", &"slums", &"mesas", &"glass_desert", &"frost_sea", &"server_fields", &"grey_orchards", &"ruined_metropolis"]
	stack.wants = &"open"
	stack.sees = 13.0
	stack.far = "A stack, blinking, a long way off."
	stack.near = "It is still lit and nothing is burning under it. The flue door is unbolted."
	stack.mark = &"stack"
	stack.guarded = true
	out.append(stack)

	var stones := LandmarkDef.make(&"cast_stones", "the cast stones")
	stones.lands = [&"bonelands", &"moss", &"coast", &"salt_flats", &"pinewood", &"snowfield", &"mesas", &"glass_desert", &"frost_sea", &"ruined_metropolis"]
	stones.wants = &"high"
	stones.sees = 12.0
	stones.far = "Stones standing in a ring, and one of them is not stone."
	stones.near = "They recast the fallen ones in concrete, round rebar, and set them back up."
	stones.mark = &"stones"
	out.append(stones)

	var pans := LandmarkDef.make(&"evaporator", "the evaporator")
	pans.lands = [&"salt_flats", &"burning", &"glass_desert"]
	pans.wants = &"open"
	pans.sees = 12.0
	pans.far = "A hulk out on the flat, white to the shoulder."
	pans.near = "The rake arm came down and stopped. Everything it touched is crusted over."
	pans.mark = &"evaporator"
	out.append(pans)

	var hulk := LandmarkDef.make(&"grown_hulk", "the grown hulk")
	hulk.lands = [&"coast", &"moss", &"pinewood", &"scrapwood"]
	hulk.wants = &"open"
	hulk.sees = 13.0
	hulk.far = "Something big is standing in the clearing, and it is not a tree."
	hulk.near = "The land came up through it. It has been dead long enough to be a place."
	hulk.mark = &"hulk"
	out.append(hulk)

	var office := LandmarkDef.make(&"clerks_office", "the clerk's post")
	office.lands = [&"bonelands", &"salt_flats", &"burning", &"snowfield", &"scrapwood", &"limestone_caves", &"moss", &"slums", &"mesas", &"server_fields", &"drowned_city", &"grey_orchards", &"ruined_metropolis"]
	office.wants = &"rough"
	office.sees = 12.0
	office.far = "A post, and the ground round it is pale with paper."
	office.near = "Every file it ever took is out here in the weather, and still in order."
	office.mark = &"files"
	office.guarded = true
	out.append(office)

	# UNDER THE GROUND, NOTHING OF THE SKY. The caves had a ring of standing
	# stones and a machine with a tree growing out of its back in them, because
	# both kinds named every landscape that would take them. A landmark is the
	# evidence of what was lost HERE: there is no weather down a limestone cave
	# and nothing grows, so what is left is what the working left.
	var pillar := LandmarkDef.make(&"poured_pillar", "the poured pillar")
	pillar.lands = [&"limestone_caves", &"mesas", &"glass_desert", &"server_fields", &"drowned_city", &"grey_orchards", &"ruined_metropolis"]
	pillar.wants = &"rough"
	pillar.sees = 12.0
	pillar.far = "One of the columns holding the roof up is the wrong colour."
	pillar.near = "They robbed the limestone one out and poured this in its place, round rebar, while the roof was still on it."
	pillar.mark = &"pillar"
	out.append(pillar)

	var sump := LandmarkDef.make(&"sump_pump", "the sump")
	sump.lands = [&"limestone_caves", &"frost_sea", &"server_fields", &"drowned_city", &"grey_orchards"]
	sump.wants = &"water"
	sump.sees = 12.0
	sump.far = "A gantry over black water, and the float is down."
	sump.near = "It kept this level dry for somebody. Whatever it was keeping out is in here now."
	sump.mark = &"sump"
	sump.guarded = true
	out.append(sump)

	for d in out:
		_defs[d.id] = d
	_order = out


static func all() -> Array[LandmarkDef]:
	_build()
	return _order.duplicate()


static func by_id(id: StringName) -> LandmarkDef:
	_build()
	return _defs.get(id, null)


## Every landscape that really holds a kind: `for_land` read backwards, not the
## row's own `lands`. A landscape's file is the authority over what stands in it,
## so a kind's row can say one thing and the world do another — and what the
## economy needs is where a player will actually find one.
static func lands_of(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: BiomeDef in BiomeRegistry.land():
		for k: LandmarkDef in for_land(d.id):
			if k.id == kind and not out.has(d.id):
				out.append(d.id)
	return out


## The kinds a landscape holds: what its own file declares (`BiomeDef.landmarks`),
## else every kind that names it. A landscape's file is the authority, which is
## what lets a new landscape carry an existing kind without this file changing.
static func for_land(land: StringName) -> Array[LandmarkDef]:
	_build()
	var out: Array[LandmarkDef] = []
	var def := BiomeRegistry.get_def(land)
	if def != null and not def.landmarks.is_empty():
		for id: StringName in def.landmarks:
			var d := by_id(id)
			if d != null:
				out.append(d)
		return out
	for d in _order:
		if d.lands.has(land):
			out.append(d)
	return out


# --- what they hold -------------------------------------------------------------

## Their drop tables, poured into the one economy (`src/core/loot`). Safe to call
## as often as anything likes. Nothing here invents a material: a landmark hands
## over what the gear package already declared, and a landscape's own elite is
## gated with `only_in` so the same kind of place gives something different in
## each landscape that holds it — which is what makes a second one worth the walk.
##
## Every table goes in as a PLACE (`Drops.declare_place`), with the landscapes
## that hold that kind. The economy walks an ordinary table back to the body it
## comes off, and a place is not a body — so until places existed, a wick in a
## lighthouse failed `tests/gear_economy/test_obtainable.gd` instead of being a
## find, and the fine axe sat in the tree with no way to it. Now the landscapes
## come with the table and the walker can answer "open it".
static func declare_loot(force: bool = false) -> void:
	_build()
	if _declared and not force and not Drops.table(&"landmark_lighthouse").is_empty():
		return
	_declared = true
	Drops.declare_place(&"landmark_lighthouse", [
		{"item": &"scrap", "count": Vector2i(3, 6)},
		{"item": &"oil", "count": Vector2i(1, 2), "chance": 0.8},
		# The one thing a lighthouse obviously holds, and the thing this table had
		# to give up before places existed: spare wick, in the store under a lamp
		# nobody has lit in years.
		{"item": &"wick", "count": Vector2i(1, 2), "chance": 0.7},
		{"item": &"kit_lens", "chance": 0.45, "rarity": Rarity.RARE},
		{"item": &"mod_foil", "chance": 0.3, "rarity": Rarity.RARE},
	], lands_of(&"lighthouse"))
	Drops.declare_place(&"landmark_leaning_mast", [
		{"item": &"scrap", "count": Vector2i(2, 4)},
		{"item": &"mod_signet", "chance": 0.7, "rarity": Rarity.RARE},
		{"item": &"mod_foil", "chance": 0.35, "rarity": Rarity.RARE},
		{"item": &"bog_iron", "chance": 0.5, "rarity": Rarity.RARE, "only_in": [&"moss"]},
		{"item": &"frost_varnish", "chance": 0.5, "rarity": Rarity.RARE, "only_in": [&"snowfield"]},
		{"item": &"resin", "count": Vector2i(1, 2), "chance": 0.5, "only_in": [&"pinewood"]},
	], lands_of(&"leaning_mast"))
	# THE FINE AXE, and the one place in the game it is. Its own row in the gear
	# tree has said since the economy was written that the landmarks own it, and
	# a fire tower is where a person who cut their own firebreaks kept one: the
	# last tenant's sacking is still on the deck. Uncommon enough to be a find
	# and not a reward, because nothing about the tower is a fight.
	Drops.declare_place(&"landmark_firewatch", [
		{"item": &"timber", "count": Vector2i(1, 3)},
		{"item": &"rag", "count": Vector2i(1, 3), "chance": 0.8},
		{"item": &"oil", "chance": 0.6},
		{"item": &"hone", "chance": 0.4, "rarity": Rarity.UNCOMMON},
		{"item": &"pitch", "chance": 0.5},
		{"item": &"axe_works", "chance": 0.35, "rarity": Rarity.RARE},
	], lands_of(&"firewatch"))
	Drops.declare_place(&"landmark_blinking_stack", [
		{"item": &"scrap", "count": Vector2i(2, 5)},
		{"item": &"shield_plate", "chance": 0.5, "rarity": Rarity.RARE},
		{"item": &"charcoal", "count": Vector2i(1, 3), "chance": 0.7},
		{"item": &"cinder_glass", "chance": 0.5, "rarity": Rarity.RARE, "only_in": [&"burning"]},
		{"item": &"clint_spar", "chance": 0.5, "rarity": Rarity.RARE, "only_in": [&"bonelands"]},
		{"item": &"frost_varnish", "chance": 0.5, "rarity": Rarity.RARE, "only_in": [&"snowfield"]},
	], lands_of(&"blinking_stack"))
	Drops.declare_place(&"landmark_cast_stones", [
		{"item": &"stone", "count": Vector2i(2, 4)},
		{"item": &"dye", "chance": 0.5},
		{"item": &"limestone", "count": Vector2i(1, 2), "chance": 0.6, "only_in": [&"bonelands", &"limestone_caves"]},
		{"item": &"clint_spar", "chance": 0.4, "rarity": Rarity.RARE, "only_in": [&"bonelands"]},
		{"item": &"mod_spring", "chance": 0.25, "rarity": Rarity.RARE},
	], lands_of(&"cast_stones"))
	Drops.declare_place(&"landmark_evaporator", [
		{"item": &"salt", "count": Vector2i(2, 5)},
		{"item": &"scrap", "count": Vector2i(2, 4)},
		{"item": &"lime", "chance": 0.5},
		{"item": &"shield_plate", "chance": 0.35, "rarity": Rarity.RARE},
		{"item": &"cinder_glass", "chance": 0.45, "rarity": Rarity.RARE, "only_in": [&"burning"]},
	], lands_of(&"evaporator"))
	Drops.declare_place(&"landmark_grown_hulk", [
		{"item": &"scrap", "count": Vector2i(4, 8)},
		{"item": &"iron", "count": Vector2i(1, 2), "chance": 0.6},
		{"item": &"mod_clamp", "chance": 0.35, "rarity": Rarity.RARE},
		{"item": &"mod_spring", "chance": 0.35, "rarity": Rarity.RARE},
		{"item": &"bog_iron", "chance": 0.4, "rarity": Rarity.RARE, "only_in": [&"moss"]},
	], lands_of(&"grown_hulk"))
	Drops.declare_place(&"landmark_clerks_office", [
		{"item": &"rag", "count": Vector2i(2, 4)},
		{"item": &"dye", "count": Vector2i(1, 2), "chance": 0.7},
		{"item": &"mod_filter", "chance": 0.4, "rarity": Rarity.RARE},
		{"item": &"mod_shade", "chance": 0.4, "rarity": Rarity.RARE},
		{"item": &"scanner_lens", "chance": 0.2, "rarity": Rarity.RARE},
		{"item": &"cinder_glass", "chance": 0.4, "rarity": Rarity.RARE, "only_in": [&"burning"]},
		{"item": &"clint_spar", "chance": 0.4, "rarity": Rarity.RARE, "only_in": [&"bonelands"]},
	], lands_of(&"clerks_office"))
	Drops.declare_place(&"landmark_poured_pillar", [
		{"item": &"stone", "count": Vector2i(2, 5)},
		{"item": &"limestone", "count": Vector2i(1, 3), "chance": 0.8},
		{"item": &"scrap", "count": Vector2i(1, 3), "chance": 0.7},
		{"item": &"mod_clamp", "chance": 0.35, "rarity": Rarity.RARE},
		{"item": &"mod_spring", "chance": 0.3, "rarity": Rarity.RARE},
	], lands_of(&"poured_pillar"))
	Drops.declare_place(&"landmark_sump_pump", [
		{"item": &"scrap", "count": Vector2i(3, 6)},
		{"item": &"iron", "count": Vector2i(1, 2), "chance": 0.6},
		{"item": &"oil", "count": Vector2i(1, 2), "chance": 0.7},
		{"item": &"mod_filter", "chance": 0.45, "rarity": Rarity.RARE},
		{"item": &"mod_clamp", "chance": 0.3, "rarity": Rarity.RARE},
	], lands_of(&"sump_pump"))


## Where the hands go at a landmark: in front of its face, clear of its own mass.
static func cache_of(site: LandmarkSite) -> Vector2:
	return site.pos + Vector2.from_angle(site.facing) * CACHE_OUT


## What one landmark holds, rolled once and for good: the same seed and the same
## site always give the same things, so a cache cannot be rerolled by loading.
static func loot(site: LandmarkSite, seed_value: int) -> Array:
	declare_loot()
	var d := by_id(site.kind)
	if d == null:
		return []
	return Drops.roll(d.drops, seed_value, _instance(site), site.land)


## The number that separates one site of a kind from the next on one seed.
static func _instance(site: LandmarkSite) -> int:
	return maxi(0, site.region) * 31 + site.nth * 7 + int(site.pos.x) % 97


## What is wrong with the kinds, as lines, so one test can fail with the list.
static func problems(land_ids: Array) -> PackedStringArray:
	_build()
	declare_loot()
	var out := PackedStringArray()
	for d in _order:
		var w := "landmark %s: " % d.id
		if d.display_name == "":
			out.append(w + "has no name")
		if d.lands.is_empty():
			out.append(w + "stands in no landscape")
		for one: StringName in d.lands:
			if not land_ids.has(one):
				out.append(w + "names a landscape that does not exist: %s" % one)
		if d.far == "" or d.near == "":
			out.append(w + "says nothing when it is seen or reached")
		if d.sees < FOUND_AT:
			out.append(w + "cannot be read from further than it is found at (%.0f)" % d.sees)
		if Drops.table(d.drops).is_empty():
			out.append(w + "is not worth walking to: nothing on its table")
		if d.mark == &"":
			out.append(w + "has no mark for the map")
	for land: StringName in land_ids:
		var def := BiomeRegistry.get_def(land)
		if def != null and def.sea:
			continue
		if for_land(land).size() < 3:
			out.append("%s holds %d landmark kinds; VISION §3 asks for three or more" % [land, for_land(land).size()])
		# A landscape's OWN FILE is the authority (`BiomeDef.landmarks`), and a
		# kind's `lands` is what it claims. Both are real fields, so they have to
		# agree or one of them is a lie nobody would trip over: the tables were
		# added to `BiomeDef` and nothing wrote them for a whole wave.
		if def == null or def.landmarks.is_empty():
			out.append("%s declares no landmarks of its own; write its table in src/content/biomes" % land)
			continue
		for id: StringName in def.landmarks:
			var d := by_id(id)
			if d == null:
				out.append("%s claims a landmark kind that does not exist: %s" % [land, id])
			elif not d.lands.has(land):
				out.append("%s claims %s, which does not name %s among its lands" % [land, id, land])
		for d in _order:
			if d.lands.has(land) and not def.landmarks.has(d.id):
				out.append("%s names %s among its lands, and %s does not claim it" % [d.id, land, land])
	return out


# --- where they stand -----------------------------------------------------------

## Every landmark in a world, biggest region first and in kind order inside a
## region, so the list is the same list every time and `nth` never shifts.
##
## ONE SCAN PER REGION. Asking the region's bounds again for every kind and every
## loosening pass is a dozen sweeps of the island, which cost 1.2 SECONDS on a
## 512-tile world and would have been another second on the loading page
## (docs/ROADMAP.md's start budget). The sweep gathers every tile with room on it
## once, scoring it for each thing the region's own kinds want, and the picking
## afterwards is a walk over a few hundred candidates.
static func sites(world: WorldData) -> Array[LandmarkSite]:
	var out: Array[LandmarkSite] = []
	if world == null:
		return out
	# Keyed on the WORLD ITSELF, not on its seed: a test that narrows the registry
	# grows a different island from the same seed, and a seed-keyed cache would
	# hand it the old island's places. The game and `--place` ask about the same
	# object, so this is exact, and a handful of entries is every realm a game
	# holds at once.
	var key := world.get_instance_id()
	if _cache.has(key):
		return (_cache[key] as Array[LandmarkSite]).duplicate()
	var counts := {}
	# Two lists, and they are not the same rule. What people and the machines
	# already built only has to be kept OFF — a landmark beside a works is a
	# scene, not a mistake. Another landmark has to be kept far, because two
	# silhouettes within sight of each other is one silhouette, and that distance
	# is a share of the island: `apart` is written for a 512-tile world, and held
	# whole on a 256-tile one it excluded every tile of every region, which is how
	# a world came to hold no landmarks at all without one line of it erroring.
	var greens: Array[Vector2] = []
	var built: Array[Vector2] = []
	var placed_at: Array[Vector2] = []
	for v: Dictionary in world.villages:
		greens.append(v.get("pos", Vector2.ZERO))
	var works_in := {}
	for m: Dictionary in world.landmarks:
		if not (m.has("mark") or m.get("kind") == &"works"):
			continue
		var p: Vector2 = m.get("pos", Vector2.ZERO)
		built.append(p)
		var r := world.region_at(floori(p.x), floori(p.y))
		works_in[r] = int(works_in.get(r, 0)) + 1
	var solid := _solid_tiles(world)
	var apart_scale := clampf(float(world.size) / 512.0, 0.4, 1.0)
	# EVERY REGION GETS ITS FIRST BEFORE ANY GETS ITS SECOND, and the smallest
	# region chooses first inside each round.
	#
	# `WorldData.regions` is biggest first, and filling one region right up before
	# starting the next put the island's landmarks down where the big landscapes
	# wanted them and left the small ones with nowhere: on seed 1 the scrapwood's
	# two regions could not put down one landmark between them, and the furthest
	# tile in either of them from something already standing was 23.3 tiles
	# against a floor of 24 (MIN_APART). Going smallest-first instead only moved
	# the hole — the bonelands, at 3272 tiles, then got none. A small region has
	# one place to stand and a big one has a thousand, so the rounds go round
	# them all and the one with least room speaks first.
	#
	# The OUTPUT is still in region order, so `nth` and every id are what they
	# always were, and a save's remembered ids still mean the same places.
	var order: Array[Dictionary] = []
	for region: Dictionary in world.regions:
		if int(region.get("tiles", 0)) >= REGION_TILES and not for_land(StringName(str(region.get("type", &"")))).is_empty():
			order.append(region)
	var by_region := {}
	var pools := {}
	var left := {}
	for region: Dictionary in order:
		var id := int(region.get("id", -1))
		var kinds := for_land(StringName(str(region.get("type", &""))))
		var wanted: Array[StringName] = [&"open"]
		for d in kinds:
			if not wanted.has(d.wants):
				wanted.append(d.wants)
		left[id] = kinds
		by_region[id] = []
		var clear := works_clear(int(region.get("tiles", 0)), int(works_in.get(id, 0)))
		var pool := _candidates(world, region, greens, built, solid, wanted, clear, COARSE)
		# A THIN POOL IS SWEPT AGAIN BEFORE ANYBODY CHOOSES, never after everybody
		# has. Eleven tiles between candidates is most of a small region's whole
		# width, and on a big region that villages and works have eaten it can come
		# back EMPTY: pinewood on seed 1 is 3466 tiles holding 288 places a landmark
		# could stand, thirty of them far enough from everything, and the coarse
		# sweep found none of them. The second sweep used to run at the end, by which
		# time the neighbours had taken the room — ten of the eleven it found were
		# then refused by MIN_APART against landmarks in OTHER regions, and a
		# landscape big enough to want crossing twice held one thing worth the walk.
		# Only a thin pool is swept again, so the cost is what it was: doing it
		# everywhere took the siting of a 512-tile world from 55 ms to 159.
		if pool.size() < FINE_BELOW:
			pool = _candidates(world, region, greens, built, solid, wanted, clear, STRIDE)
		pools[id] = pool
	# LEAST ROOM FIRST — AND ROOM IS THE POOL, not the tile count. Sorting on tiles
	# stands in for room only while a region's places are spread evenly through it,
	# and villages, works and solid ground are not spread evenly. The biggest
	# landscape on the island can be the one with nowhere to stand, and sorted by
	# tiles it speaks last and gets what is left, which is nothing.
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := (pools[int(a.get("id", -1))] as Array).size()
		var pb := (pools[int(b.get("id", -1))] as Array).size()
		if pa != pb:
			return pa < pb
		var ta := int(a.get("tiles", 0))
		var tb := int(b.get("tiles", 0))
		return ta < tb if ta != tb else int(a.get("id", -1)) < int(b.get("id", -1)))
	for round_index in PER_REGION:
		for region: Dictionary in order:
			var id := int(region.get("id", -1))
			if (by_region[id] as Array).size() > round_index:
				continue
			var row := _pick_one(pools[id], placed_at, left[id], apart_scale)
			if row.is_empty():
				continue
			placed_at.append(row.at)
			(by_region[id] as Array).append(row)
	for region: Dictionary in world.regions:
		var id := int(region.get("id", -1))
		var land := StringName(str(region.get("type", &"")))
		for row: Dictionary in by_region.get(id, []):
			var d: LandmarkDef = row.def
			var at: Vector2 = row.at
			var n := int(counts.get(d.id, 0)) + 1
			counts[d.id] = n
			var s := LandmarkSite.new()
			s.kind = d.id
			s.land = land
			s.region = id
			s.pos = at
			s.nth = n
			s.id = StringName("%s#%d" % [d.id, n])
			# Turned to face the region's heart, so its front is the side a
			# player walking in from the land it belongs to actually sees.
			s.facing = _facing(region.get("centre", at), at).angle()
			out.append(s)
	if _cache.size() >= CACHE_MOST:
		_cache.clear()
	_cache[key] = out.duplicate()
	return out


## Tests and a new game start from nothing remembered.
static func forget() -> void:
	_cache.clear()


## How far a landmark in this region keeps off the machines' works: twelve where
## there is room for twelve, and no more than half the ground each work has to
## itself where there is not. Pure, so a test can read it off a region's own
## numbers rather than guessing why a landscape came out empty.
static func works_clear(region_tiles: int, works_in_region: int) -> float:
	if works_in_region <= 0 or region_tiles <= 0:
		return CLEAR_WORKS
	var room := sqrt(float(region_tiles) / float(works_in_region)) * 0.5
	return clampf(room, CLEAR_WORKS_FLOOR, CLEAR_WORKS)


## Every tile in a region a landmark could stand on, scored for each thing this
## region's kinds want: `{p: Vector2, s: {want -> float}}`.
static func _candidates(world: WorldData, region: Dictionary, greens: Array[Vector2], built: Array[Vector2], solid: Dictionary, wanted: Array[StringName], off_works: float, stride: int) -> Array:
	var out: Array = []
	var id := int(region.get("id", -1))
	var bounds: Rect2 = region.get("bounds", Rect2())
	var heart: Vector2 = region.get("centre", Vector2.ZERO)
	var home := world.spawn
	var y := floori(bounds.position.y)
	while y < int(bounds.end.y):
		var x := floori(bounds.position.x)
		while x < int(bounds.end.x):
			if world.region_at(x, y) != id or not _room_at(world, x, y):
				x += stride
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_squared_to(home) < CLEAR_HOME * CLEAR_HOME or _too_near(p, greens, CLEAR_VILLAGE) or _too_near(p, built, off_works):
				x += stride
				continue
			# And a player has to be able to STAND at its cache. A lighthouse on a
			# spit whose front two tiles are surf is a place that cannot be opened,
			# and the search that puts a body "near" it then walks twelve tiles
			# inland looking for dry ground, which is where the first picture of
			# one was taken from: an empty field with a tower on the skyline.
			var front := p + _facing(heart, p) * CACHE_OUT
			var fx := floori(front.x)
			var fy := floori(front.y)
			if not _room_at(world, fx, fy) or solid.has(fy * world.size + fx):
				x += stride
				continue
			# Ties break on the tile's own hash, never on scan order, so a
			# lighthouse is not always on the north-west corner of its coast.
			var jitter := Rng.hash01(world.seed_value, x, y, 0x1AD) * 0.4
			var scores := {}
			for want: StringName in wanted:
				var v := _wants(world, x, y, want)
				scores[want] = -INF if v <= -1000.0 else v + jitter
			out.append({"p": p, "s": scores})
			x += stride
		y += stride
	return out


## The best candidate for one kind. Three passes, loosening in the order that
## costs the least: a kind wants its own ground (a lighthouse on a shore, a tower
## on a rise), and a landscape with none of it would hold nothing at all — which
## is a landscape with no reason to be crossed, the one thing this package exists
## to prevent. So the last pass takes any ground with room on it.
static func _pick(pool: Array, placed: Array[Vector2], d: LandmarkDef, apart: float) -> Vector2:
	for pass_index in 3:
		var want: StringName = d.wants if pass_index < 2 else &"open"
		var keep := apart if pass_index == 0 else maxf(apart * 0.55, MIN_APART)
		var best := Vector2.INF
		var best_score := -INF
		for c: Dictionary in pool:
			var score: float = (c.s as Dictionary).get(want, -INF)
			if score == -INF or score <= best_score:
				continue
			if _too_near(c.p, placed, keep):
				continue
			best_score = score
			best = c.p
		if best.is_finite():
			return best
	return Vector2.INF


## ONE more landmark for a region, out of a pool already swept: the first of the
## kinds it has left that can find ground, as `{def, at}` or `{}`. The kind it
## takes is struck off `kinds`, so the next round asks for a different silhouette
## and a region never holds two of the same thing.
static func _pick_one(pool: Array, placed: Array[Vector2], kinds: Array[LandmarkDef], apart_scale: float) -> Dictionary:
	if pool.is_empty():
		return {}
	for i in kinds.size():
		var d: LandmarkDef = kinds[i]
		var at := _pick(pool, placed, d, d.apart * apart_scale)
		if not at.is_finite():
			continue
		kinds.remove_at(i)
		return {"def": d, "at": at}
	return {}


## Tiles a body cannot walk onto, as a set. A landmark's cache has to be clear of
## them or a player cannot get their hands on it: the first pinewood tower put
## its locker inside a pine, and the `use` key went to the tree every time.
## The tile a solid prop stands ON, and not the square round it: a world holds
## tens of thousands of them, and marking a three-by-three for each was half a
## million dictionary writes on the loading page for an answer that is "is there
## a trunk where the locker goes".
static func _solid_tiles(world: WorldData) -> Dictionary:
	var out := {}
	for p: WorldProp in world.props:
		if p.solid <= 0.0:
			continue
		out[floori(p.pos.y) * world.size + floori(p.pos.x)] = true
	return out


## Which way a landmark at `p` is turned: toward its region's heart, so its face
## and its cache are on the side a player walks in from. The one place this is
## worked out, because the siting has to check the cache's ground before the site
## exists to be asked.
static func _facing(heart: Vector2, p: Vector2) -> Vector2:
	var d := heart - p
	return d.normalized() if d.length() > 1.0 else Vector2.RIGHT


## Is `p` within `apart` of anything in the list? Squared, because this is asked
## of every candidate against every village and every work the machines laid, and
## a square root per pair is most of the sweep.
static func _too_near(p: Vector2, taken: Array[Vector2], apart: float) -> bool:
	var limit := apart * apart
	for q in taken:
		if q.distance_squared_to(p) < limit:
			return true
	return false


## How well a tile answers what a kind wants. -1000 means it does not at all.
static func _wants(world: WorldData, x: int, y: int, wants: StringName) -> float:
	match wants:
		&"shore":
			var d := _water_within(world, x, y, 5, true)
			return -1000.0 if d < 0 else 4.0 - float(d) * 0.5
		&"water":
			var d := _water_within(world, x, y, 4, false)
			return -1000.0 if d < 0 else 3.0 - float(d) * 0.4
		&"high":
			var lift := _lift(world, x, y, 5)
			return -1000.0 if lift < 1 else float(lift)
		&"rough":
			return float(_relief(world, x, y, 4))
		_:
			# Open: the flattest, emptiest ground it can find, which is what makes
			# a silhouette stand alone against the sky instead of in a thicket.
			return 4.0 - float(_relief(world, x, y, 4))


## Chebyshev tiles to the nearest water within `r`, or -1. `salt` asks for the
## sea's own ground rather than any water, so a lighthouse is not built on a pond.
## Sampled every other tile, because this runs over every candidate in every
## region and a full ring walk out to five tiles is a hundred and twenty reads
## apiece: the difference between the sweep costing 40 ms and costing 250 ms on
## a 512-tile world, for an answer that is "is there water about" either way.
static func _water_within(world: WorldData, x: int, y: int, r: int, salt: bool) -> int:
	for ring in range(2, r + 1, 2):
		for dy in range(-ring, ring + 1, 2):
			for dx in range(-ring, ring + 1, 2):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var g := world.ground_at(x + dx, y + dy)
				if not Ground.is_water(g):
					continue
				if salt and world.level_at(x + dx, y + dy) > 0:
					continue
				return ring
	return -1


## How many levels this tile stands above the ground round it (0 if anything
## near is higher).
static func _lift(world: WorldData, x: int, y: int, r: int) -> int:
	var level := world.level_at(x, y)
	var below := 0
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			var n := world.level_at(x + dx, y + dy)
			if n > level:
				return 0
			if n < level:
				below += 1
	return mini(level, below)


## How broken the ground round a tile is: levels of spread over a square.
static func _relief(world: WorldData, x: int, y: int, r: int) -> int:
	var low := 99
	var high := -99
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			var n := world.level_at(x + dx, y + dy)
			low = mini(low, n)
			high = maxi(high, n)
	return high - low


## Room for a landmark: dry, on the map, off a road people LAID, and level within
## a step over the ground it stands on.
##
## "Off a road" asks `WorldData.road` — the mask the access stage wrote — and not
## `ground == Ground.ROAD`. The two were the same question for the project's
## whole life, because nothing but the access stage painted ROAD. A landscape may
## now pave its own streets, and the Slums does: its lanes run on the zero line of
## the mass field, a few tiles apart, over the whole city. This function wants FIVE
## tiles clear in a cross four wide, so with the ground read as the answer, almost
## no point in a city ever had room — the Slums held nothing worth the walk at all
## on seed 7, and one place on seed 1, while declaring three kinds.
##
## For every landscape that does not pave, the two questions still give the same
## answer: measured on seed 1 with the Slums muted, all 2955 tiles of ROAD ground
## are laid road. The mask is a shade wider at a village square (a road runs in and
## becomes GRAVEL), which is right — a landmark does not stand in a square either.
static func _room_at(world: WorldData, x: int, y: int) -> bool:
	if not world.in_bounds(x - 2, y - 2) or not world.in_bounds(x + 2, y + 2):
		return false
	var level := world.level_at(x, y)
	if level < 1:
		return false
	# Dry and off the road over its own footprint, and within a STEP of the level
	# it stands on over the tile it stands on. Two tiles of dead flat in every
	# direction is a parade ground, and on a terraced snowfield there is none — a
	# whole landscape held nothing because of it.
	for d: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		if Ground.is_water(world.ground_at(x + d.x, y + d.y)) or world.on_road(x + d.x, y + d.y):
			return false
		if absi(world.level_at(x + d.x, y + d.y) - level) > 1:
			return false
	return true
