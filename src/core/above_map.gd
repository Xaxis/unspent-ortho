class_name AboveMap
extends RefCounted
## WHAT HANGS OVER THE GROUND, AS A PICTURE THE SHADER READS (docs/ABOVE.md S2):
## one texel a tile over the box round every span (WorldData.overhead), so a
## world with a few arches carries a few hundred bytes and one with none
## carries nothing.
##   R  255 where mass hangs over the tile, else 0
##   G, B  the connected mass it belongs to (4-connected over tiles, 16 bits,
##         0 none), spread one tile past the mass, so a rim the warp draws
##         past its tiles is still that mass's
##   A  the level of its underside (0 where none)
## World.gdshader cuts the mass the player stands under at the section plane
## (43_above), and shades the ground under any mass. Pure and derived: built
## once a world's spans are laid, never written after.

## Tiles of margin round the spans' box: the id's spread, and the warp.
const PAD := 2

var x0 := 0
var y0 := 0
var w := 0
var h := 0
## Per tile of the box: the mass it is under (1-based), or 0.
var ids := PackedInt32Array()
var image: Image


static func of(world: WorldData) -> AboveMap:
	var m := AboveMap.new()
	if world.overhead.is_empty():
		return m
	var lo := Vector2i(world.size, world.size)
	var hi := Vector2i(-1, -1)
	for k: int in world.overhead.keys():
		var t := Vector2i(k % world.size, k / world.size)
		lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
		hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))
	m.x0 = lo.x - PAD
	m.y0 = lo.y - PAD
	m.w = hi.x - lo.x + 1 + PAD * 2
	m.h = hi.y - lo.y + 1 + PAD * 2
	var mask := PackedByteArray()
	mask.resize(m.w * m.h)
	for y in m.h:
		for x in m.w:
			if world.overhead_at(m.x0 + x, m.y0 + y).x >= 0:
				mask[y * m.w + x] = 1
	# The box is square for the labeller; it asks for one width.
	var side := maxi(m.w, m.h)
	var sq := PackedByteArray()
	sq.resize(side * side)
	for y in m.h:
		for x in m.w:
			sq[y * side + x] = mask[y * m.w + x]
	var sizes := PackedInt32Array()
	var label := GenFields.components(sq, side, sizes)
	# Labels are representative cells; number the masses 1, 2, ... in order.
	var number := {}
	m.ids.resize(m.w * m.h)
	for y in m.h:
		for x in m.w:
			var l := label[y * side + x]
			if l < 0:
				continue
			if not number.has(l):
				number[l] = number.size() + 1
			m.ids[y * m.w + x] = number[l]
	# Spread each mass one tile out, over tiles no mass holds.
	var spread := m.ids.duplicate()
	for y in m.h:
		for x in m.w:
			if m.ids[y * m.w + x] != 0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < m.w and ny < m.h and m.ids[ny * m.w + nx] != 0:
					spread[y * m.w + x] = m.ids[ny * m.w + nx]
					break
	var rgba := PackedByteArray()
	rgba.resize(m.w * m.h * 4)
	for y in m.h:
		for x in m.w:
			var i := y * m.w + x
			var id := spread[i]
			var o := world.overhead_at(m.x0 + x, m.y0 + y)
			rgba[i * 4] = 255 if mask[i] != 0 else 0
			rgba[i * 4 + 1] = id & 0xFF
			rgba[i * 4 + 2] = (id >> 8) & 0xFF
			rgba[i * 4 + 3] = clampi(o.x, 0, 255) if o.x >= 0 else 0
	m.image = Image.create_from_data(m.w, m.h, false, Image.FORMAT_RGBA8, rgba)
	return m


## The mass over tile (x, y) (1-based), or 0.
func id_at(x: int, y: int) -> int:
	var lx := x - x0
	var ly := y - y0
	if ids.is_empty() or lx < 0 or ly < 0 or lx >= w or ly >= h:
		return 0
	return ids[ly * w + lx]


## The box as the shader's `above_rect`: origin, then size, in tiles.
func rect() -> Vector4:
	return Vector4(x0, y0, w, h)
