class_name GenSlots
extends RefCounted
## SLOT CANYONS: a plateau cut by a labyrinth of narrow floors, for a landscape
## whose relief asks for `slots` (BiomeDef.relief, in levels: how high the
## plateau stands over the floors). GenRelief adds `slots * up(x, y)` to the
## land, where `up` is 0 on a floor, 1 on the plateau, and climbs between them
## only on a ramp.
##
## THE MAZE IS DRAWN, NOT FOUND. Canyons along the zero-sets of noise read as a
## contour map and promise nothing about getting anywhere. Here a lattice of
## nodes `PITCH` tiles apart is cut into blocks of `BLOCK` x `BLOCK` nodes; each
## block is a perfect maze (a spanning tree dug by a seeded walk, so every floor
## in it reaches every other and it ends in dead ends), and each pair of
## neighbouring blocks is joined by a door or two on their shared side. So the
## whole network is connected, it has the dead ends a maze needs, and every
## block is dealt from its own seed: a streamed section can dig its own blocks.
##
## Floors are 3 to 6 tiles wide; where three or more meet the node opens into a
## room. The tile position is warped before it is read, so the walls wander and
## no floor runs straight along a grid line. The wall is the step from floor to
## plateau in one tile: a single face.
##
## THE ONLY WAYS UP are ramps: a share of the dead ends rise along their one
## floor from the junction they leave, through where the dead end was and on
## into the plateau, a scree run long enough that a body climbs it a level at a
## time however the warp squeezes it.

## Tiles between lattice nodes. With floors 3-6 wide this lays about 35-40% of
## the land as floor.
const PITCH := 12
## Nodes on a side of one block: one perfect maze.
const BLOCK := 5
## A node may sit this far off its lattice point, in tiles.
const JITTER := 2.2
## Half a floor's width, in tiles: floors are 2 * this wide.
const HALF_MIN := 1.5
const HALF_SPAN := 1.0
## A room's radius where three or more floors meet.
const ROOM_MIN := 3.0
const ROOM_SPAN := 1.6
## The share of dead ends that ramp up to the plateau.
const RAMP_SHARE := 1.0
## How far past its dead end a ramp runs on into the plateau, in node spacings.
const RAMP_RUN := 0.7
## A blind alley: where two neighbouring nodes are not joined, a floor dug from
## one of them part of the way toward the other and stopped, this often. The
## tree's own dead ends are too few for a maze on their own.
const STUB := 0.3
## How far toward the other node a blind alley runs.
const STUB_MIN := 0.4
const STUB_SPAN := 0.25
## A second door between two blocks, this often.
const SECOND_DOOR := 0.35
## How far a tile's position wanders before the maze is read, in tiles.
const WARP := 2.5

var width := 0
## Per node: its centre in tiles, and its radius on the floor.
var centre := PackedVector2Array()
var radius := PackedFloat32Array()
## Per node: 1 where the floor east of it (to node + 1) / south of it (to node +
## width) is dug, and that floor's half width.
var east := PackedByteArray()
var south := PackedByteArray()
var east_half := PackedFloat32Array()
var south_half := PackedFloat32Array()
## Per node: 1 at a dead end that ramps up to the plateau, and that ramp: from
## the junction it leaves to its top in the plateau, and its half width.
var ramp := PackedByteArray()
var ramp_from := PackedVector2Array()
var ramp_to := PackedVector2Array()
var ramp_half := PackedFloat32Array()
## Per node: how many floors meet at it.
var degree := PackedByteArray()
## Per node: a blind alley on the undug floor east / south of it, as the share
## of the way it runs; positive from this node, negative from the other one, 0
## for none.
var east_stub := PackedFloat32Array()
var south_stub := PackedFloat32Array()


## The labyrinth for a world `size` tiles square.
static func plan(s: int, size: int) -> GenSlots:
	var m := GenSlots.new()
	var w := ceili(float(size) / PITCH) + 1
	m.width = w
	var nn := w * w
	m.centre.resize(nn)
	m.radius.resize(nn)
	m.east.resize(nn)
	m.south.resize(nn)
	m.east_half.resize(nn)
	m.south_half.resize(nn)
	m.ramp.resize(nn)
	m.ramp_from.resize(nn)
	m.ramp_to.resize(nn)
	m.ramp_half.resize(nn)
	m.degree.resize(nn)
	m.east_stub.resize(nn)
	m.south_stub.resize(nn)
	for gy in w:
		for gx in w:
			var k := gy * w + gx
			var jx := (Rng.hash01(s, gx, gy, 3401) - 0.5) * 2.0 * JITTER
			var jy := (Rng.hash01(s, gx, gy, 3402) - 0.5) * 2.0 * JITTER
			m.centre[k] = Vector2((gx + 0.5) * PITCH + jx, (gy + 0.5) * PITCH + jy)
			m.east_half[k] = HALF_MIN + Rng.hash01(s, gx, gy, 3403) * HALF_SPAN
			m.south_half[k] = HALF_MIN + Rng.hash01(s, gx, gy, 3404) * HALF_SPAN
	var blocks := ceili(float(w) / BLOCK)
	for by in blocks:
		for bx in blocks:
			for key in _block(s, w, bx, by):
				if key & 1 == 0:
					m.east[key >> 1] = 1
				else:
					m.south[key >> 1] = 1
			# The doors to the next block east and south.
			for side in 2:
				for k in _doors(s, w, bx, by, side):
					if side == 0:
						m.east[k] = 1
					else:
						m.south[k] = 1
	for gy in w:
		for gx in w:
			var k := gy * w + gx
			for side in 2:
				if (side == 0 and gx >= w - 1) or (side == 1 and gy >= w - 1):
					continue
				if (m.east[k] if side == 0 else m.south[k]) != 0:
					continue
				if Rng.hash01(s, gx, gy, 3450 + side) >= STUB:
					continue
				var f := STUB_MIN + Rng.hash01(s, gx, gy, 3452 + side) * STUB_SPAN
				if Rng.hash01(s, gx, gy, 3454 + side) < 0.5:
					f = -f
				if side == 0:
					m.east_stub[k] = f
				else:
					m.south_stub[k] = f
	for gy in w:
		for gx in w:
			var k := gy * w + gx
			var deg := 0
			var widest := 0.0
			if gx < w - 1 and m.east[k] != 0:
				deg += 1
				widest = maxf(widest, m.east_half[k])
			if gy < w - 1 and m.south[k] != 0:
				deg += 1
				widest = maxf(widest, m.south_half[k])
			if gx > 0 and m.east[k - 1] != 0:
				deg += 1
				widest = maxf(widest, m.east_half[k - 1])
			if gy > 0 and m.south[k - w] != 0:
				deg += 1
				widest = maxf(widest, m.south_half[k - w])
			m.degree[k] = deg
			m.radius[k] = widest
			if deg >= 3:
				m.radius[k] = ROOM_MIN + Rng.hash01(s, gx, gy, 3405) * ROOM_SPAN
			elif deg == 1 and Rng.hash01(s, gx, gy, 3406) < RAMP_SHARE:
				m.ramp[k] = 1
	for gy in w:
		for gx in w:
			var k := gy * w + gx
			if m.ramp[k] == 0:
				continue
			var j := k
			var half := HALF_MIN
			if gx < w - 1 and m.east[k] != 0:
				j = k + 1
				half = m.east_half[k]
			elif gy < w - 1 and m.south[k] != 0:
				j = k + w
				half = m.south_half[k]
			elif gx > 0 and m.east[k - 1] != 0:
				j = k - 1
				half = m.east_half[k - 1]
			else:
				j = k - w
				half = m.south_half[k - w]
			var d := m.centre[k]
			var a := m.centre[j]
			m.ramp_from[k] = a
			m.ramp_to[k] = d + (d - a) * RAMP_RUN
			m.ramp_half[k] = half
			# A blind alley off a ramp would be a pit half way up it.
			m.east_stub[k] = 0.0
			m.south_stub[k] = 0.0
			if gx > 0:
				m.east_stub[k - 1] = 0.0
			if gy > 0:
				m.south_stub[k - w] = 0.0
	return m


## One block's perfect maze: its node-to-node floors taken in a seeded order,
## each dug unless the two nodes are already joined (Kruskal's). A tree, so
## every node reaches every other one way; and a random tree rather than a
## walk's, so it branches often and ends often: rooms and dead ends. Returns the
## dug floors as `node * 2 + side` (side 0 east, 1 south), node = gy * w + gx.
static func _block(s: int, w: int, bx: int, by: int) -> PackedInt32Array:
	var x0 := bx * BLOCK
	var y0 := by * BLOCK
	var x1 := mini(x0 + BLOCK, w)
	var y1 := mini(y0 + BLOCK, w)
	var r := Rng.make(Rng.hash_ints(s, bx, by), 3430)
	var edges: Array = []
	for gy in range(y0, y1):
		for gx in range(x0, x1):
			if gx + 1 < x1:
				edges.append(Vector3i(gx, gy, 0))
			if gy + 1 < y1:
				edges.append(Vector3i(gx, gy, 1))
	Rng.shuffle(r, edges)
	var root := {}
	for gy in range(y0, y1):
		for gx in range(x0, x1):
			root[gy * w + gx] = gy * w + gx
	var dug := PackedInt32Array()
	for e: Vector3i in edges:
		var a := e.y * w + e.x
		var b := a + 1 if e.z == 0 else a + w
		var ra := _root(root, a)
		var rb := _root(root, b)
		if ra == rb:
			continue
		root[ra] = rb
		dug.append(a * 2 + e.z)
	return dug


## The doors from block (bx, by) to the next block east (side 0) or south (1):
## the nodes whose floor east / south crosses the shared side. One, and
## sometimes a second; none on the world's last blocks.
static func _doors(s: int, w: int, bx: int, by: int, side: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var nbx := bx + 1 if side == 0 else bx
	var nby := by if side == 0 else by + 1
	if nbx * BLOCK >= w or nby * BLOCK >= w:
		return out
	var doors := 2 if Rng.hash01(s, bx, by, 3410 + side) < SECOND_DOOR else 1
	for d in doors:
		var along := int(Rng.hash01(s, bx, by, 3420 + side * 4 + d) * BLOCK)
		if side == 0:
			out.append(mini(by * BLOCK + along, w - 1) * w + bx * BLOCK + BLOCK - 1)
		else:
			out.append((by * BLOCK + BLOCK - 1) * w + mini(bx * BLOCK + along, w - 1))
	return out


## Whether the floor east (side 0) or south (1) of node (gx, gy) is dug, asking
## only the one block it lies in (or the doors between two). `cache` keeps a
## block's floors for the next ask.
static func _open(s: int, w: int, gx: int, gy: int, side: int, cache: Dictionary) -> bool:
	if gx < 0 or gy < 0 or gx >= w or gy >= w:
		return false
	if (side == 0 and gx >= w - 1) or (side == 1 and gy >= w - 1):
		return false
	var k := gy * w + gx
	var bx := gx / BLOCK
	var by := gy / BLOCK
	var crosses := (gx % BLOCK == BLOCK - 1) if side == 0 else (gy % BLOCK == BLOCK - 1)
	if crosses:
		return _doors(s, w, bx, by, side).has(k)
	var key := Vector2i(bx, by)
	if not cache.has(key):
		cache[key] = _block(s, w, bx, by)
	return (cache[key] as PackedInt32Array).has(k * 2 + side)


## ONE NODE, WITHOUT THE WORLD: what `plan` says of lattice node (gx, gy) in a
## world `size` square, worked from its own block and its neighbours' doors, so
## a reader that wants a node or two (an interior siting a threshold) never
## builds the whole labyrinth. Answers as `plan` does (tests/biome/test_slots):
##   centre   Vector2, in tiles, before the warp moves the ground under it
##   open     [east, south, west, north]: a dug floor to that neighbour
##   degree   how many are dug; 0 is a node left as plateau
##   dead_end one floor in; room: three or more meet; ramp: a dead end that
##            climbs to the plateau
##   radius   the floor's radius round the node, in tiles
static func node(s: int, size: int, gx: int, gy: int) -> Dictionary:
	var w := ceili(float(size) / PITCH) + 1
	var cache := {}
	var open: Array[bool] = [
		_open(s, w, gx, gy, 0, cache), _open(s, w, gx, gy, 1, cache),
		_open(s, w, gx - 1, gy, 0, cache), _open(s, w, gx, gy - 1, 1, cache),
	]
	var halves: Array[float] = [
		HALF_MIN + Rng.hash01(s, gx, gy, 3403) * HALF_SPAN, HALF_MIN + Rng.hash01(s, gx, gy, 3404) * HALF_SPAN,
		HALF_MIN + Rng.hash01(s, gx - 1, gy, 3403) * HALF_SPAN, HALF_MIN + Rng.hash01(s, gx, gy - 1, 3404) * HALF_SPAN,
	]
	var deg := 0
	var widest := 0.0
	for q in 4:
		if open[q]:
			deg += 1
			widest = maxf(widest, halves[q])
	var jx := (Rng.hash01(s, gx, gy, 3401) - 0.5) * 2.0 * JITTER
	var jy := (Rng.hash01(s, gx, gy, 3402) - 0.5) * 2.0 * JITTER
	var room := deg >= 3
	return {
		"centre": Vector2((gx + 0.5) * PITCH + jx, (gy + 0.5) * PITCH + jy),
		"open": open,
		"degree": deg,
		"dead_end": deg == 1,
		"room": room,
		"ramp": deg == 1 and Rng.hash01(s, gx, gy, 3406) < RAMP_SHARE,
		"radius": ROOM_MIN + Rng.hash01(s, gx, gy, 3405) * ROOM_SPAN if room else widest,
	}


static func _root(root: Dictionary, k: int) -> int:
	while int(root[k]) != k:
		root[k] = root[root[k]]
		k = root[k]
	return k


## The labyrinth's `up` over the whole world, 0 on a floor and 1 on the plateau,
## computed only where `amp` (the landscape's `slots`) is above zero and left 0
## elsewhere. Each tile's position is warped up to `WARP` tiles first.
func field(s: int, size: int, amp: PackedFloat32Array) -> PackedFloat32Array:
	const F := GenFields.FIELD
	var warp := GenFields.batch(size, [
		[F, GenFields.noise(s, 3440, 1.0 / 22.0, 2), 2],
		[F, GenFields.noise(s, 3441, 1.0 / 22.0, 2), 2],
	])
	var wx := warp[0]
	var wy := warp[1]
	var out := PackedFloat32Array()
	out.resize(size * size)
	var w := width
	var cen := centre
	var rad := radius
	var ea := east
	var so := south
	var eh := east_half
	var sh := south_half
	var rp := ramp
	var es := east_stub
	var ss := south_stub
	var rf := ramp_from
	var rt := ramp_to
	var rh := ramp_half
	const P := float(PITCH)
	GenFields.rows(size, func(ya: int, yb: int) -> void:
		for y in range(ya, yb):
			for x in size:
				var i := y * size + x
				if amp[i] <= 0.01:
					continue
				var px := float(x) + 0.5 + wx[i] * WARP
				var py := float(y) + 0.5 + wy[i] * WARP
				var cx := clampi(floori(px / P), 0, w - 1)
				var cy := clampi(floori(py / P), 0, w - 1)
				var up := 1.0
				for oy in range(maxi(cy - 1, 0), mini(cy + 2, w)):
					for ox in range(maxi(cx - 1, 0), mini(cx + 2, w)):
						var k := oy * w + ox
						var a := cen[k]
						var dx := px - a.x
						var dy := py - a.y
						var rr := rad[k]
						if rp[k] == 0 and rr > 0.0 and dx * dx + dy * dy <= rr * rr:
							up = 0.0
						for side in 2:
							if (side == 0 and ox >= w - 1) or (side == 1 and oy >= w - 1):
								continue
							var j := k + 1 if side == 0 else k + w
							var open := (ea[k] if side == 0 else so[k]) != 0
							if open and (rp[k] != 0 or rp[j] != 0):
								continue
							var f := 1.0
							if not open:
								f = es[k] if side == 0 else ss[k]
								if f == 0.0:
									continue
							var hw := eh[k] if side == 0 else sh[k]
							var b := cen[j]
							# The floor runs from `base` a share `f` of the way along.
							var base := a if f > 0.0 else b
							var ux := (b.x - a.x) * f
							var uy := (b.y - a.y) * f
							var qx := px - base.x
							var qy := py - base.y
							var len2 := ux * ux + uy * uy
							var t := clampf((qx * ux + qy * uy) / len2, 0.0, 1.0)
							var ex := qx - ux * t
							var ey := qy - uy * t
							if ex * ex + ey * ey > hw * hw:
								continue
							up = 0.0
				# The ramps near: each a floor from its junction rising the whole
				# way to its top in the plateau.
				for oy in range(maxi(cy - 2, 0), mini(cy + 3, w)):
					for ox in range(maxi(cx - 2, 0), mini(cx + 3, w)):
						var k := oy * w + ox
						if rp[k] == 0:
							continue
						var a := rf[k]
						var ux := rt[k].x - a.x
						var uy := rt[k].y - a.y
						var qx := px - a.x
						var qy := py - a.y
						var t := clampf((qx * ux + qy * uy) / (ux * ux + uy * uy), 0.0, 1.0)
						var ex := qx - ux * t
						var ey := qy - uy * t
						var hw := rh[k]
						if ex * ex + ey * ey <= hw * hw:
							up = minf(up, t)
				out[i] = up
	)
	return out
