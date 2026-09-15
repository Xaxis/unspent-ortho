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
var level: PackedInt32Array
var ground: PackedByteArray
var country: PackedByteArray
## Landscape transitions: the nearest OTHER country and how far toward it this
## tile has turned (0 = pure `country`, 0.5 = on the border). Renderers blend by it.
var country2: PackedByteArray
var blend: PackedFloat32Array
var moisture: PackedFloat32Array
var temperature: PackedFloat32Array
var props: Array[WorldProp] = []
var villages: Array[Dictionary] = []
var spawn: Vector2
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


## Height in world units of the ground surface under a point (sea floor clamps to 0).
func height_at(p: Vector2) -> float:
	return maxi(0, level_at(floori(p.x), floori(p.y))) * STEP


## Tile position to 3D position on the ground surface.
func to_3d(p: Vector2) -> Vector3:
	return Vector3(p.x, height_at(p), p.y)
