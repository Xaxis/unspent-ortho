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

# --- countries ---
var cw: int
## Per country id, coarse score (higher wins); index 0 (sea) unused.
var scores: Array[PackedFloat32Array] = []
## Per country id, coarse soft membership (sums to 1 over land countries).
var soft: Array[PackedFloat32Array] = []
## Country id -> Vector2 heart of its largest site.
var hearts: Array[Vector2] = []

# --- relief ---
## Float elevation in levels (land >= 1).
var elev: PackedFloat32Array

## Warp of the Burning's caldera, in crater radii / 0.3, shared by the rim's
## relief and its rock.
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
## ridges positive, dales and hollows negative.
var rise: PackedFloat32Array

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
	cw = GenFields.coarse_width(size, STEP)
	water = _bytes()
	village = _bytes()
	road = _bytes()
	ramp = _bytes()
	site_ground = _bytes()


func _bytes() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(n)
	return b
