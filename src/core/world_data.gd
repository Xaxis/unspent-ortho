class_name WorldData
extends RefCounted
## The world as data. Pure: no nodes, no rendering. Views read it; only world
## generation and gameplay rules (mining, building) write to it.
##
## Coordinates: tile (x, y), x east, y south, i = y * size + x. One tile is one
## world unit. Elevation is in integer LEVELS, each STEP units tall. Level 0 is
## shallow sea, below 0 is deep sea. In 3D, tile (x, y) at level l is the
## Vector3(x, l * STEP, y).

const STEP := 0.5

var seed_value: int
var size: int
## Which realm this world IS (Realm.SURFACE, UNDERGROUND, ...). A world is grown
## for one realm and holds only the landscape types registered in it (GenContext),
## so every tile of it is in that realm. Written by WorldGen, read by anything
## that asks Realm.at.
var realm: StringName = &"surface"
var level: PackedInt32Array
var ground: PackedByteArray
## The landscape TYPE of every tile: an index into BiomeRegistry, 0 for the sea.
var country: PackedByteArray
## Landscape transitions: the nearest OTHER type and how far toward it this
## tile has turned (0 = pure `country`, 0.5 = on the border). Renderers blend by it.
var country2: PackedByteArray
var blend: PackedFloat32Array
## Region id + 1 per tile (0 = the sea, or a run too small to be a place).
## Int, not byte: a world of many landscapes can hold hundreds of places, and a
## byte would silently alias the tail of them onto each other's ids — which
## sentinels, works and saves all key on.
var region: PackedInt32Array
## The places this world is made of, biggest first. One landscape type may hold
## several: {id: int, type: StringName, index: int (type index), tiles: int,
## centre: Vector2, bounds: Rect2}. Sentinels, works, subarcs and saves key on
## `id` (docs/VISION.md).
var regions: Array[Dictionary] = []
var moisture: PackedFloat32Array
var temperature: PackedFloat32Array
var props: Array[WorldProp] = []
## {pos: Vector2 square centre, country: int, name: String, level: int,
## radius: float (cleared core), reach: float (built extent), id: int}. Village 0
## is the spawn village.
var villages: Array[Dictionary] = []

## How far this settlement's own buildings stand from its square, in tiles —
## RECORDED by GenScatter when it places them, never guessed from a constant.
##
## There were two constants guessing it and both were the same mistake. A ring of
## eight one-storey houses fits inside about nine tiles, so `props_near(p, 10.0)`
## counted a village's houses and `Survival.VILLAGE_RADIUS` (11) decided you were
## standing in one. Then a landscape could declare a `row` plan, and the city's
## street runs four ranks out: its furthest towers stand 19 tiles from the square.
## The test then counted two of six buildings and called the city broken, and the
## live game told a player standing among the towers that they were in open
## country and could not sleep. The placer had done nothing wrong; nothing had
## asked it how far it went (docs/DESIGN.md).
const VILLAGE_LEAST_REACH := 11.0


func village_reach(v: Dictionary) -> float:
	return maxf(float(v.get("reach", 0.0)), VILLAGE_LEAST_REACH)


## Where a player staged into this settlement is put down (`--village=N`, the
## tour's `place`, dev mode's warp). Recorded by GenScatter once its buildings are
## up, because only it knows where they went.
##
## This was `pos + Vector2(3, 3)` written out in four places and two tests. On a
## green with houses round the edge that spot is always clear; on a street it is
## a doorway, and the moment a landscape could declare a `row` plan all four
## copies started putting the player inside a building at once.
const STAND_OFFSET := Vector2(3, 3)


func village_stand(v: Dictionary) -> Vector2:
	return v.get("stand", (v.pos as Vector2) + STAND_OFFSET)
var spawn: Vector2
## Radians the player faces on waking (0 = east, -PI/2 = north): toward open land.
var spawn_facing := -PI * 0.5
## Each river as tile-centre points from source to mouth (a tributary ends
## where it joins). Flow runs in point order.
var rivers: Array[PackedVector2Array] = []
## Each road as tile-centre points between two village squares.
var roads: Array[PackedVector2Array] = []
## 1 where the access stage LAID a road, tile by tile (`GenContext.road`).
##
## Not the same question as `ground == Ground.ROAD`, and the difference is why
## this is kept: a landscape may pave its own streets, and the Slums does, so
## most of the ROAD ground in a world with a city in it is lanes nobody laid.
## Every placing stage already asks `c.road` and is right; anything outside
## worldgen that asked the ground instead was reading a proxy that was exact
## until the first city. Measured on seed 1 with the Slums muted, a mask off
## `roads` covers all 2955 tiles of ROAD ground; with it in, 2786 of 5853 are
## the city's own.
var road: PackedByteArray
## Which landscape's RECIPE made each tile (`GenContext.recipe`).
##
## Not the same as `country`, and the difference is the whole of what an ecotone
## is: in the blend band a tile follows its SECOND type's recipe where the warped
## patch says so, and its ground and its scatter both come from there. So the
## driftwood at a slums/coast border really is the coast's driftwood, laid by the
## coast's rules, standing on the coast's grass, on a tile whose `country` says
## slums. Anything asking "whose rules made this?" asks here; `country` answers
## "whose land is this?" and the two are only the same away from a border.
var recipe: PackedByteArray
## Which BODY each tile belongs to: 0 is the void between them (the ocean on the
## surface, solid rock underground, vacuum in orbit), and bodies are numbered from
## 1 (`docs/DESIGN.md`).
##
## The third of a set with `road` and `recipe`, and the same argument: a stage
## decided it, so a stage records it, and nobody downstream infers it. Continent
## is the one of the three most likely to be guessed at — from latitude, or from
## the ocean mask — and a guess would be wrong the first time a continent was not
## where its latitude suggested. `GenBodies` is its only writer
## (`tests/core/test_bodies.gd`).
var continent: PackedByteArray
## What each body was dealt, biggest first: {id: int, tiles: int, centre: Vector2,
## bounds: Rect2}. `docs/DESIGN.md` §4 adds the budget, the climate band and the
## type set when the planning half lands.
var continents: Array[Dictionary] = []
## The machines' grid: {kind: PropKind.PYLON or POLE, props: PackedInt32Array
## of prop ids in stringing order}. Cables run between consecutive ids.
var lines: Array[Dictionary] = []
## Places worth walking to:
## {kind: StringName, pos: Vector2, country: int, region: int}.
##
## `region` IS ON THE ROW AND IS NOT DERIVED AT THE POINT OF USE. It is the same
## rule `WorldData.road` and `WorldData.continent` exist for: a reader that works
## a region out from a position is right until the first thing that straddles a
## border, and this is what a sub-arc, a picket and a chapter's demand all key on.
## -1 where a place stands on land too small to be a region at all.
##
## THIS IS THE SITE RECORD. It was asked for as a new `WorldData.sites` array,
## because `SiteKinds` had nowhere to point and `holds`, `guard` and `behind` were
## all declared and unclaimable. A second array would have been a third answer to
## one question, on the day three of those were written up: these rows already
## carry every site world gen lays, with its kind and its position, and the only
## thing missing was which place it is in.
## Kinds: tip, stone_circle, wreck, ruin, summit, caldera, fumarole; and for renderers
## and sound, bridge (a road over a river; `dir` runs along the road) and
## falls (a river's bed steps down a level; `dir` runs downstream).
var landmarks: Array[Dictionary] = []
## Props taken from the world: prop id -> world minute it grows back (INF = never).
## Owned by survival rules; WorldView and WorldQuery skip depleted props.
var depleted: Dictionary = {}
## Region id -> how many of the region's own ore props stand in it, counted by
## generation (`GenDigest`) so no reader has to walk every prop to ask.
## `ore_counted` is false on a world built by hand, which is counted on first ask.
var ore_standing: Dictionary = {}
var ore_counted := false
## The props and cable spans of each section (`WorldSections`), indexed once
## `sectioned` is set.
var section_props: Dictionary = {}
var section_spans: Dictionary = {}
var sectioned := false
## PROP IDS. A generated prop's id is (section << ORDINAL_BITS) | ordinal,
## the order its section laid it (GenIds): a change in one section renumbers
## no other, and a streamed section rebuilt from the plan gets the same ids.
## A prop set down after generation takes BUILT_BIT | n. `props` holds the
## generated props section by section, then the set-down ones in order, and
## `section_start[s]` is where section s begins in it (its last entry is where
## the set-down ones begin). A world built by hand has no sections and its ids
## are its list positions.
const ORDINAL_BITS := 20
const BUILT_BIT := 1 << 30
var section_start := PackedInt32Array()
## The props as packed columns, row for row with `props` (`PropTable`). Beside
## the objects for now; the truth once readers go through the facade below.
var table := PropTable.new()


func _init(p_seed: int, p_size: int) -> void:
	seed_value = p_seed
	size = p_size
	var n := size * size
	level.resize(n)
	ground.resize(n)
	country.resize(n)
	country2.resize(n)
	region.resize(n)
	blend.resize(n)
	moisture.resize(n)
	temperature.resize(n)
	continent.resize(n)
	spawn = Vector2(size * 0.5, size * 0.5)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size


## Which BODY a tile is on: 0 is the void between them (`GenBodies.VOID`) — the
## ocean on the surface, solid rock underground, vacuum in orbit.
func continent_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return 0
	return continent[y * size + x]


## Do these two stand on the same landmass? THE QUESTION MOST CALLERS ACTUALLY
## HAVE, and the one a distance cannot answer: two points forty tiles apart may
## have an ocean between them, and every "within N tiles" in this game was written
## when they could not. A story slot held near the spawn, a road between villages,
## a survey line, a keeper's feeding ground — all of them mean "and you can walk
## there". Neither point being on a body at all is false, not true: the void is
## not a place two things can share.
func same_body(a: Vector2, b: Vector2) -> bool:
	var ia := continent_at(floori(a.x), floori(a.y))
	return ia != 0 and ia == continent_at(floori(b.x), floori(b.y))


func level_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return -3
	return level[y * size + x]


func ground_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Ground.DEEP_WATER
	return ground[y * size + x]


## Whether a road was LAID here — see `road`. A world grown only as far as
## `--until=tiles` has no roads yet and answers false everywhere.
func on_road(x: int, y: int) -> bool:
	if not in_bounds(x, y) or road.is_empty():
		return false
	return road[y * size + x] != 0


## Whose rules made this tile — see `recipe`. Falls back to whose LAND it is,
## for a world grown only as far as `--until=tiles`.
func recipe_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return 0
	var i := y * size + x
	return recipe[i] if not recipe.is_empty() else country[i]


func country_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Country.SEA
	return country[y * size + x]


## The region holding a tile, or -1 out at sea and on ground too small to be a
## place.
func region_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return -1
	return region[y * size + x] - 1


func region_of(id: int) -> Dictionary:
	return regions[id] if id >= 0 and id < regions.size() else {}


## Height in world units of the ground surface under a point (sea floor clamps to 0).
func height_at(p: Vector2) -> float:
	return maxi(0, level_at(floori(p.x), floori(p.y))) * STEP


## Tile position to 3D position on the ground surface.
func to_3d(p: Vector2) -> Vector3:
	return Vector3(p.x, height_at(p), p.y)


## A prop set down after generation: appended and filed in its section, so a
## reader asking by section sees it. Its id comes from `next_id()`.
func add_prop(p: WorldProp) -> void:
	props.append(p)
	table.append(p)
	WorldSections.file(self, p)


# --- the props facade -------------------------------------------------------
# What a reader asks instead of walking `props`: every prop by row, and the
# three things play changes on one. A streamed world answers these from its
# loaded sections' tables.

## How many props there are.
func prop_count() -> int:
	return props.size()


## The prop at row `i`.
func prop_at(i: int) -> WorldProp:
	return props[i]


## Every prop, in row order: section by section, then the ones set down later.
func each_prop() -> Array[WorldProp]:
	return props


## How much of `p` is left (Harvest.shown), kept on its row too.
func set_shown(p: WorldProp, v: float) -> void:
	p.shown = v
	var at := _row_of(p)
	if at < 0:
		return
	if v < 1.0:
		table.shown[at] = v
	else:
		table.shown.erase(at)


func set_scale(p: WorldProp, v: float) -> void:
	p.scale = v
	var at := _row_of(p)
	if at >= 0:
		table.scale[at] = v


func set_solid(p: WorldProp, v: float) -> void:
	p.solid = v
	var at := _row_of(p)
	if at >= 0:
		table.solid[at] = v


## The table row of `p`, or -1 for a prop the world does not hold (a
## settlement's ghost of a planned building).
func _row_of(p: WorldProp) -> int:
	var at := position_of(p.id)
	return at if at >= 0 and at < table.size() and at < props.size() and props[at] == p else -1


## The id the next prop set down takes.
func next_id() -> int:
	return id_at(props.size())


## How many props generation laid: set-down props stand after them.
func generated() -> int:
	return section_start[section_start.size() - 1] if not section_start.is_empty() else 0


## The prop with this id, or null.
func prop(id: int) -> WorldProp:
	var at := position_of(id)
	return props[at] if at >= 0 and at < props.size() else null


## Where the prop with this id stands in `props`, or -1.
func position_of(id: int) -> int:
	if id < 0:
		return -1
	if id & BUILT_BIT:
		return generated() + (id & ~BUILT_BIT)
	if section_start.is_empty():
		return id
	var s := id >> ORDINAL_BITS
	if s + 1 >= section_start.size():
		return -1
	var at := section_start[s] + (id & ((1 << ORDINAL_BITS) - 1))
	return at if at < section_start[s + 1] else -1


## The id of the prop at this position in `props`.
func id_at(at: int) -> int:
	var gen := generated()
	if at >= gen:
		return BUILT_BIT | (at - gen) if not section_start.is_empty() else at
	var lo := 0
	var hi := section_start.size() - 2
	# The last section starting at or before `at`.
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if section_start[mid] <= at:
			lo = mid
		else:
			hi = mid - 1
	return (lo << ORDINAL_BITS) | (at - section_start[lo])
