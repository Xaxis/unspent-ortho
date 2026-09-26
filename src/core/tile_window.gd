class_name TileWindow
extends RefCounted
## A rectangle of a world's tiles, copied out: what a reader that walks many
## tiles holds instead of the world's whole arrays. A streamed world keeps only
## some sections, so a reader asks for the rectangle it needs (at most four
## sections stitched) and reads that; today the copy is taken from the resident
## arrays.
##
## The rectangle is clamped to the map tile by tile, so a reader that clamps its
## coordinates to the map, as the mesher does, always lands inside it. Index with
## `(y - y0) * w + (x - x0)` for x in [x0, x0 + w) and y in [y0, y0 + h).

var x0 := 0
var y0 := 0
var w := 0
var h := 0
var level := PackedInt32Array()
var ground := PackedByteArray()
var country := PackedByteArray()
var country2 := PackedByteArray()
var blend := PackedFloat32Array()


## The tiles of [x0, x1) x [y0, y1), each clamped onto the map: what a reader
## that clamps its coordinates reads. A rectangle wholly off the map is the edge
## row or column nearest it, never empty, so a body put far off the map still
## reads the ground at the edge (a height asked there was an index of -1).
static func of(world: WorldData, ax0: int, ay0: int, ax1: int, ay1: int) -> TileWindow:
	var t := TileWindow.new()
	var size := world.size
	t.x0 = clampi(ax0, 0, size - 1)
	t.y0 = clampi(ay0, 0, size - 1)
	var x1 := maxi(clampi(ax1 - 1, 0, size - 1) + 1, t.x0 + 1)
	var y1 := maxi(clampi(ay1 - 1, 0, size - 1) + 1, t.y0 + 1)
	t.w = x1 - t.x0
	t.h = y1 - t.y0
	for y in range(t.y0, t.y0 + t.h):
		var a := y * size + t.x0
		var b := a + t.w
		t.level.append_array(world.level.slice(a, b))
		t.ground.append_array(world.ground.slice(a, b))
		t.country.append_array(world.country.slice(a, b))
		t.country2.append_array(world.country2.slice(a, b))
		t.blend.append_array(world.blend.slice(a, b))
	return t


## Whether (x, y) is inside the window.
func has(x: int, y: int) -> bool:
	return x >= x0 and y >= y0 and x < x0 + w and y < y0 + h


## The index of (x, y), which must be inside.
func at(x: int, y: int) -> int:
	return (y - y0) * w + (x - x0)
