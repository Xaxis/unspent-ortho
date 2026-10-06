class_name UiExplored
extends RefCounted
## The land the player has seen, one byte per tile (0 unseen .. 255 seen), for
## the survey map. Walking reveals a disc around the player whose rim is a
## soft ramp, so the map's edge of the known world is drawn like a scan
## fading out rather than a hard circle.

## Tiles fully seen around the player; the rim fades out over RIM more.
const RADIUS := 10
const RIM := 3

## Where the player has walked, a point every TRAIL_STEP tiles: the map draws it
## as a dotted route, the journey so far.
const TRAIL_STEP := 1.5
const TRAIL_MAX := 30000

var size: int
## Read it freely; write it only through `reveal` or `load_mask`, which keep the
## seen count beside it.
var mask := PackedByteArray()
var trail := PackedVector2Array()
## Tiles seen at all, as a bounding box; zero size until something is seen.
var bounds := Rect2i()
var _last := Vector2i(-1000000, -1000000)
## A byte at or over this is a tile seen (`seen`, `fraction`).
const SEEN := 128
## Tiles of `mask` at or over SEEN. Kept by `reveal` and `load_mask` because
## counting the mask is 3.4M bytes at 1840 and cost the pause page 0.6 s a
## time it opened.
var _seen_n := 0
## Bumped by every write that changed `mask`, so a reader that drew it (the
## survey's texture, its lettering) knows whether to draw it again.
var changes := 0

## DEV MODE ONLY: draw the whole island whether it has been walked or not (owner,
## 2026-09-18, "in dev mode you should obviously be able to reveal the full world
## map on the map").
##
## It is a flag on what is SHOWN and never a write into `mask`, which matters for
## three reasons and each of them has bitten this project before. The player's own
## memory is not destroyed, so turning it off puts the real edge of the known
## world back exactly. The save is untouched, so inspecting a seed cannot leak
## into somebody's game. And `fraction()` goes on counting the true mask, so the
## share on the pause page still says how much of the world has actually been
## walked — a readout that reports a cheat as progress is a readout that lies.
##
## Nothing outside the map's drawing reads this: a chapter counts the landmarks
## it has FOUND, not tiles, so revealing the map cannot advance one.
var revealed := false
## The island's own box, worked out once when the map is revealed, so a revealed
## map frames the land and not the sea around it.
var _all := Rect2i()


func _init(p_size: int) -> void:
	size = p_size
	mask.resize(size * size)


func seen(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= size or y >= size:
		return false
	return revealed or mask[y * size + x] >= SEEN


func value(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= size or y >= size:
		return 0
	return 255 if revealed else mask[y * size + x]


## Show the whole island (dev mode). Takes the world because a revealed map should
## frame the LAND: a world is an island in a square of sea, and fitting the square
## draws the island as a stamp in the middle of nothing.
func reveal_all(world: WorldData) -> void:
	revealed = true
	if _all.size != Vector2i.ZERO:
		return
	var lo := Vector2i(size, size)
	var hi := Vector2i(-1, -1)
	for y in size:
		for x in size:
			if world.level_at(x, y) <= 0:
				continue
			lo.x = mini(lo.x, x)
			lo.y = mini(lo.y, y)
			hi.x = maxi(hi.x, x)
			hi.y = maxi(hi.y, y)
	_all = Rect2i(0, 0, size, size) if hi.x < lo.x else Rect2i(lo, hi - lo + Vector2i.ONE)


## What the map draws, which is the whole island under a reveal and the walked
## mask otherwise. The texture is built from this, never from `mask` directly.
func shown_mask() -> PackedByteArray:
	if not revealed:
		return mask
	var full := PackedByteArray()
	full.resize(mask.size())
	full.fill(255)
	return full


## The box the map frames itself to.
func shown_bounds() -> Rect2i:
	return _all if revealed and _all.size != Vector2i.ZERO else bounds


## Record the player at tile-space `p`. Only does work when the tile changes.
func visit(p: Vector2) -> bool:
	note_trail(p)
	var t := Vector2i(floori(p.x), floori(p.y))
	if t == _last:
		return false
	_last = t
	reveal(t, RADIUS)
	return true


## Add `p` to the trail if the player has come far enough from the last point.
func note_trail(p: Vector2) -> void:
	if not trail.is_empty() and trail[trail.size() - 1].distance_to(p) < TRAIL_STEP:
		return
	if trail.size() >= TRAIL_MAX:
		# Keep the whole journey at half the detail rather than lose its start.
		var halved := PackedVector2Array()
		for i in range(0, trail.size(), 2):
			halved.append(trail[i])
		trail = halved
	trail.append(p)


func reveal(c: Vector2i, r: int) -> void:
	var outer := r + RIM
	var wrote := false
	for y in range(maxi(0, c.y - outer), mini(size, c.y + outer + 1)):
		var row := y * size
		for x in range(maxi(0, c.x - outer), mini(size, c.x + outer + 1)):
			var d := Vector2(x - c.x, y - c.y).length()
			if d > outer:
				continue
			var v := 255 if d <= r else int(255.0 * (outer - d) / RIM)
			var was := mask[row + x]
			if v > was:
				mask[row + x] = v
				wrote = true
				if was < SEEN and v >= SEEN:
					_seen_n += 1
	if wrote:
		changes += 1
	var disc := Rect2i(c.x - r, c.y - r, r * 2 + 1, r * 2 + 1).intersection(Rect2i(0, 0, size, size))
	bounds = disc if bounds.size == Vector2i.ZERO else bounds.merge(disc)


## Share of the world's tiles seen, 0..1. Deliberately off the TRUE mask, so a
## revealed map does not report itself as progress on the pause page.
func fraction() -> float:
	return _seen_n / float(mask.size())


## Put a whole mask in place (a save's), counting what it has seen.
func load_mask(m: PackedByteArray) -> void:
	mask = m
	_seen_n = UiExplored.count_seen(m)
	changes += 1


## Bytes of `m` at or over SEEN, eight at a time. SEEN is 128, the high bit, so
## a 64-bit word shifted down by 7 and masked to the low bit of each byte holds
## a 1 in each byte lane that is seen, and words summed lane by lane count eight
## bytes an add. 127 words at most per sum, so no lane carries into the next and
## the top lane never reaches the sign bit. A byte loop took 0.6 s at 1840; this
## is about a twentieth of that.
static func count_seen(m: PackedByteArray) -> int:
	assert(SEEN == 128, "the count reads the high bit")
	const LOW_BITS := 0x0101010101010101
	var whole := m.size() & ~7
	var n := 0
	var acc := 0
	var lanes := 0
	for word in m.slice(0, whole).to_int64_array():
		acc += (word >> 7) & LOW_BITS
		lanes += 1
		if lanes == 127:
			n += _lane_sum(acc)
			acc = 0
			lanes = 0
	n += _lane_sum(acc)
	for i in range(whole, m.size()):
		if m[i] >= SEEN:
			n += 1
	return n


static func _lane_sum(acc: int) -> int:
	var s := 0
	for k in 8:
		s += (acc >> (k * 8)) & 0xFF
	return s


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
