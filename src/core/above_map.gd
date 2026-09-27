class_name AboveMap
extends RefCounted
## WHAT HANGS OVER THE GROUND, AS A PICTURE THE SHADER READS (docs/ABOVE.md S2):
## one texel a tile over the box round every span (WorldData.overhead), so a
## world with a few arches carries a few hundred bytes and one with none
## carries nothing.
##   R  255 where mass hangs over the tile, else 0
##   G, B  the connected mass it belongs to (4-connected over tiles, 16 bits,
##         0 none), spread one tile past the mass, so a
##         rim the warp draws past its tiles is still that mass's
##   A  the level of its underside (0 where none)
## World.gdshader cuts the mass the player stands under at the section plane
## (43_above), and shades the ground under any mass. Pure and derived; over a
## window round the player where the spans are wide (a roofed cave), rebuilt
## as the player moves (43_above).

## Tiles of margin round the spans' box: the id's spread, and the warp.
const PAD := 2

var x0 := 0
var y0 := 0
var w := 0
var h := 0
## Per tile of the box: the mass it is under (1-based), or 0.
var ids := PackedInt32Array()
var image: Image


static func of(world: WorldData, centre := Vector2.INF, half := 0) -> AboveMap:
	var m := AboveMap.new()
	if not world.has_overhead():
		return m
	# The spans' own box, cut to the window round `centre` when one is asked:
	# a cave roofed over its whole world is millions of tiles, and only what is
	# round the player is ever cut.
	var box := world.overhead_box.grow(PAD)
	if half > 0:
		box = box.intersection(Rect2i(floori(centre.x) - half, floori(centre.y) - half, half * 2 + 1, half * 2 + 1))
	if box.size.x <= 0 or box.size.y <= 0:
		return m
	m.x0 = box.position.x
	m.y0 = box.position.y
	m.w = box.size.x
	m.h = box.size.y
	var mask := PackedByteArray()
	mask.resize(m.w * m.h)
	var under := PackedInt32Array()
	under.resize(m.w * m.h)
	for y in m.h:
		for x in m.w:
			var o := world.overhead_at(m.x0 + x, m.y0 + y)
			if o.x >= 0:
				mask[y * m.w + x] = 1
				under[y * m.w + x] = o.x
	# A MASS is tiles joined 4-ways, whatever their underside: a roof stepping
	# between plateaus is ONE mass, cut together. Split by plateau, the cut
	# opened only the step over the player, and the steps round it, uncut,
	# stood between the camera and the player (cave-roofs.tour, frame 01).
	m.ids.resize(m.w * m.h)
	var next := 0
	var stack := PackedInt32Array()
	for start in m.w * m.h:
		if mask[start] == 0 or m.ids[start] != 0:
			continue
		next += 1
		m.ids[start] = next
		stack.append(start)
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var ix := i % m.w
			var iy := i / m.w
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := ix + d.x
				var ny := iy + d.y
				if nx < 0 or ny < 0 or nx >= m.w or ny >= m.h:
					continue
				var j := ny * m.w + nx
				if mask[j] != 0 and m.ids[j] == 0:
					m.ids[j] = next
					stack.append(j)
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
