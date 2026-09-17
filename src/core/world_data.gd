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
## `id` (docs/VISION.md §3).
var regions: Array[Dictionary] = []
var moisture: PackedFloat32Array
var temperature: PackedFloat32Array
var props: Array[WorldProp] = []
## {pos: Vector2 square centre, country: int, name: String, level: int,
## radius: float (cleared core), id: int}. Village 0 is the spawn village.
var villages: Array[Dictionary] = []
var spawn: Vector2
## Radians the player faces on waking (0 = east, -PI/2 = north): toward open land.
var spawn_facing := -PI * 0.5
## Each river as tile-centre points from source to mouth (a tributary ends
## where it joins). Flow runs in point order.
var rivers: Array[PackedVector2Array] = []
## Each road as tile-centre points between two village squares.
var roads: Array[PackedVector2Array] = []
## The machines' grid: {kind: PropKind.PYLON or POLE, props: PackedInt32Array
## of prop ids in stringing order}. Cables run between consecutive ids.
var lines: Array[Dictionary] = []
## Places worth walking to: {kind: StringName, pos: Vector2, country: int}.
## Kinds: tip, stone_circle, wreck, ruin, summit, caldera, fumarole; and for renderers
## and sound, bridge (a road over a river; `dir` runs along the road) and
## falls (a river's bed steps down a level; `dir` runs downstream).
var landmarks: Array[Dictionary] = []
## Props taken from the world: prop id -> world minute it grows back (INF = never).
## Owned by survival rules; WorldView and WorldQuery skip depleted props.
var depleted: Dictionary = {}


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
	spawn = Vector2(size * 0.5, size * 0.5)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size


func level_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return -3
	return level[y * size + x]


func ground_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Ground.DEEP_WATER
	return ground[y * size + x]


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
