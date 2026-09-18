class_name GenContext
extends RefCounted
## Scratch state passed between world generation stages. Only WorldGen makes
## one; stages read what earlier stages wrote and add their own. Nothing here
## outlives generate(): the finished world is WorldData.

## Coarse grid step in tiles for continent-scale fields (countries, relief
## parameters, drainage).
const STEP := 4

var w: WorldData
var size: int
var n: int
var s: int
## Size relative to the 512-tile design world: distances that belong to the
## island's shape scale by it; tile-scale features (ecotone width, river
## width, villages) do not.
var k: float
## `k` for ONE BODY rather than for the square, and it is what nearly every use of
## `k` actually wanted. The floors are quadratic in it — `min_tiles` is
## `REGION_TILES * k * k` — so on a 1024 world `k` is 2 and the smallest thing
## that counts as a place becomes four times what it was. Right for one island
## filling the square; wrong for four continents in it, and it would have left the
## small orbital bodies of docs/WORLD.md §2 holding no region at all: no place, no
## depot, no keeper, no landmark, on a world that generated perfectly and passed
## every test. Every distance, count and noise wavelength in worldgen is about a
## PLACE, so they all ask this. With one body it equals `k` exactly.
var body_k: float = 1.0
## The bodies this world is made of, as `GenBodies.plan` dealt them: each
## {id, at, share, band, home}. Every stage that used to speak about "the island"
## speaks about one of these (docs/WORLD.md §1). One body, centred, at full share
## is the island this game has always had.
var bodies: Array[Dictionary] = []

# --- shape ---
## 1 = land. Final after GenShape except where later stages cut ramps or causeways.
var land: PackedByteArray
## Tiles inland from the sea (land) or out from the land (sea), smooth.
var inland: PackedFloat32Array
var offshore: PackedFloat32Array
## 1 on land that is not the main island: skerries, stacks, tidal islets.
var islet: PackedByteArray
## Share of land within ~24 tiles: < 0.5 on headlands, > 0.5 in bays.
var convex: PackedFloat32Array
var land_rect := Rect2()

# --- landscape types ---
var cw: int
## Every registered type, by index (BiomeRegistry.all()), and the land ones.
var defs: Array[BiomeDef] = []
var land_types: PackedInt32Array = PackedInt32Array()
## How many types this world is made of (the stride of every per-type array).
var types: int
## Per type index, coarse score (higher wins); index 0 (sea) unused.
var scores: Array[PackedFloat32Array] = []
## Per type index, coarse soft membership (sums to 1 over land types).
var soft: Array[PackedFloat32Array] = []
## The same soft memberships end to end: cc * cw * cw + k. Reading a parameter
## out of an Array of packed arrays per element is many times slower.
var soft_flat: PackedFloat32Array = PackedFloat32Array()
## Type index -> Vector2 heart of its largest site.
var hearts: Array[Vector2] = []
## The type that carries a caldera, or -1. Its rim warp is rim_warp.
var caldera_type := -1

# --- relief ---
## Float elevation in levels (land >= 1).
var elev: PackedFloat32Array

## Warp of a caldera's rim, in crater radii / 0.3, shared by the rim's relief
## and its rock.
var rim_warp: PackedFloat32Array

# --- water ---
## 0 none, 1 river, 2 still water (tarn, pool)
var water: PackedByteArray
## River bed elevation where water == 1.
var river_e: PackedFloat32Array
var rivers: Array[PackedVector2Array] = []

# --- settlement ---
## 1 inside a village's cleared core.
var village: PackedByteArray
var road: PackedByteArray
## 1 where a breach was cut through a cliff.
var ramp: PackedByteArray
## Ground override + 1 for special sites (tips, stone circles), 0 = none.
var site_ground: PackedByteArray

# --- shore detail ---
## Exact 4-neighbour steps from the sea, capped (see GenSurface).
var sea_steps: PackedByteArray
## Woodland field shared by grounds and props, so the floor lies under the trees.
var forest: PackedFloat32Array
## Levels a tile stands above the land around it (about 30 tiles): tops and
## ridges positive, dales and hollows negative. From float elevation, so it
## drapes across terrace edges.
var rise: PackedFloat32Array
## The landscape type whose recipe a tile's ground followed (its own, or the
## neighbour's in an ecotone island). Props follow the same recipe.
var recipe: PackedByteArray
## Still pools and tarns: x, y centre (tiles) and radius, in the order laid.
var pools: PackedVector3Array = PackedVector3Array()
## Ground of each still-water tile (the country of the pool's centre decides,
## so one pool is one water).
var pool_ground: PackedByteArray

var timings: Dictionary = {}
var _tick := 0


## Profile marks inside a stage: accumulates microseconds since the last mark.
func mark(label: StringName) -> void:
	var t := Time.get_ticks_usec()
	if _tick > 0:
		timings[label] = timings.get(label, 0.0) + (t - _tick) / 1000.0
	_tick = t


func _init(p_world: WorldData) -> void:
	w = p_world
	size = w.size
	n = size * size
	s = w.seed_value
	k = size / 512.0
	defs = BiomeRegistry.all()
	types = defs.size()
	# Whose landscapes this realm lays, which is its own unless it is another
	# realm at a different time (`Realm.land_realm`).
	var lays := Realm.land_realm(w.realm)
	for d in defs:
		if not d.sea:
			# A world is one REALM's world: only the types registered in it are
			# laid (docs/VISION.md §7.1). `types` is still the whole registry,
			# because every per-type array here is indexed by a type's own index.
			if not d.realms.has(lays):
				continue
			land_types.append(d.index)
		if d.caldera > 0.0 and caldera_type < 0:
			caldera_type = d.index
	cw = GenFields.coarse_width(size, STEP)
	water = _bytes()
	village = _bytes()
	road = _bytes()
	ramp = _bytes()
	site_ground = _bytes()
	pool_ground = _bytes()


func _bytes() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(n)
	return b
