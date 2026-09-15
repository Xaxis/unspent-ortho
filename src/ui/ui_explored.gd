class_name UiExplored
extends RefCounted
## The land the player has seen, one byte per tile (0 unseen .. 255 seen), for
## the notebook map. Walking reveals a disc around the player whose rim is a
## soft ramp, so the map's edge of the known world is drawn like a pencil
## fading out rather than a hard circle.

## Tiles fully seen around the player; the rim fades out over RIM more.
const RADIUS := 10
const RIM := 3

var size: int
var mask := PackedByteArray()
var _last := Vector2i(-1000000, -1000000)


func _init(p_size: int) -> void:
	size = p_size
	mask.resize(size * size)


func seen(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size and mask[y * size + x] >= 128


func value(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= size or y >= size:
		return 0
	return mask[y * size + x]


## Record the player at tile-space `p`. Only does work when the tile changes.
func visit(p: Vector2) -> bool:
	var t := Vector2i(floori(p.x), floori(p.y))
	if t == _last:
		return false
	_last = t
	reveal(t, RADIUS)
	return true


func reveal(c: Vector2i, r: int) -> void:
	var outer := r + RIM
	for y in range(maxi(0, c.y - outer), mini(size, c.y + outer + 1)):
		var row := y * size
		for x in range(maxi(0, c.x - outer), mini(size, c.x + outer + 1)):
			var d := Vector2(x - c.x, y - c.y).length()
			if d > outer:
				continue
			var v := 255 if d <= r else int(255.0 * (outer - d) / RIM)
			if v > mask[row + x]:
				mask[row + x] = v


## Share of the world's tiles seen, 0..1.
func fraction() -> float:
	var n := 0
	for v in mask:
		if v >= 128:
			n += 1
	return n / float(mask.size())


## Pretend the player has walked `steps` tiles from `start`: a wandering walk
## that keeps to land and drifts inland and along the coast. For shots and tests.
func wander(world: WorldData, start: Vector2, steps: int, seed: int) -> void:
	var rng := Rng.make(seed, 0x3a9)
	var p := start
	var heading := rng.randf() * TAU
	for i in steps:
		heading += rng.randf_range(-0.5, 0.5)
		var next := p + Vector2.from_angle(heading)
		var tries := 0
		while (world.level_at(floori(next.x), floori(next.y)) <= 0) and tries < 8:
			heading += PI * 0.35
			next = p + Vector2.from_angle(heading)
			tries += 1
		if tries < 8:
			p = next
		visit(p)
