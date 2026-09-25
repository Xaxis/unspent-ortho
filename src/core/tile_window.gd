class_name TileWindow
extends RefCounted
## A rectangle of a world's tiles, copied out: what a reader that walks many
## tiles holds instead of the world's whole arrays. A streamed world keeps only
## some sections, so a reader asks for the rectangle it needs (at most four
## sections stitched) and reads that; today the copy is taken from the resident
## arrays.
##
## The rectangle is clamped to the map, so a reader that clamps its coordinates
## to the map, as the mesher does, always lands inside it. Index with
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


## The tiles of [x0, x1) x [y0, y1) that lie on the map.
static func of(world: WorldData, ax0: int, ay0: int, ax1: int, ay1: int) -> TileWindow:
	var t := TileWindow.new()
	var size := world.size
	t.x0 = clampi(ax0, 0, size)
	t.y0 = clampi(ay0, 0, size)
	var x1 := clampi(ax1, 0, size)
	var y1 := clampi(ay1, 0, size)
	t.w = maxi(0, x1 - t.x0)
	t.h = maxi(0, y1 - t.y0)
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
