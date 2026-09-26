class_name AboveStage
extends RefCounted
## DEV STAGING of ground above the ground (DESIGN_ABOVE S1): `--above=KIND[@PLACE]`
## hangs a synthetic span over the start, or over a named place (GenPlaces.find),
## before a chunk is drawn and without touching worldgen, so what hangs overhead
## can be drawn, walked under and looked at on any seed. Planting twice plants
## the same tiles.
##   roof  a slab twelve tiles by nine with its corners cut, 3.0 over the highest
##         ground under it; its west edge is two tiles west of the place, so
##         standing there is standing under it, near its edge.
##   arch  a band two tiles wide and fifteen long running east-west through the
##         place, its underside a curve from the highest ground under it at each
##         foot to 4.0 over it at the middle, 1.5 thick.

const ROOF := 1
const ARCH := 2
## Levels of room under the roof, and of mass in it.
const ROOF_ROOM := 6
const ROOF_THICK := 3
## Levels an arch's middle stands over its feet, and its thickness.
const ARCH_RISE := 8
const ARCH_THICK := 3


static func plant(w: WorldData, spec: String, start: Vector2) -> void:
	var parts := spec.split("@")
	var at := start
	if parts.size() > 1 and parts[1] != "":
		at = GenPlaces.find(w, parts[1])
		if at.x < 0:
			push_warning("--above: no place '%s'" % parts[1])
			return
	var ax := floori(at.x)
	var ay := floori(at.y)
	match parts[0]:
		"roof":
			var tiles := _tiles(w, ax - 2, ay - 4, ax + 9, ay + 4, true)
			var under := _highest(w, tiles) + ROOF_ROOM
			for t in tiles:
				w.set_overhead(t.x, t.y, under, under + ROOF_THICK, ROOF)
		"arch":
			var tiles := _tiles(w, ax - 7, ay - 1, ax + 7, ay, false)
			var foot := _highest(w, tiles)
			for t in tiles:
				var under := foot + roundi(ARCH_RISE * sin(PI * float(t.x - (ax - 7)) / 14.0))
				w.set_overhead(t.x, t.y, under, under + ARCH_THICK, ARCH)
		_:
			push_warning("--above: no kind '%s' (roof, arch)" % parts[0])


## The tiles of the rectangle x0..x1, y0..y1 inside the world, with its four
## corner tiles left out when `cut`.
static func _tiles(w: WorldData, x0: int, y0: int, x1: int, y1: int, cut: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or y < 0 or x >= w.size or y >= w.size:
				continue
			if cut and (x == x0 or x == x1) and (y == y0 or y == y1):
				continue
			out.append(Vector2i(x, y))
	return out


static func _highest(w: WorldData, tiles: Array[Vector2i]) -> int:
	var top := 0
	for t in tiles:
		top = maxi(top, w.level_at(t.x, t.y))
	return top
