extends Node3D
## The whole world at a distance, so that pulling the camera back is never a
## reason to BUILD anything.
##
## `WorldView` streams chunks around the camera's own footprint, and that is
## right for walking: a chunk is at most six draws and holds every tuft, trunk
## and machine in its 32 tiles. It cannot be right for looking at the island.
## Measured on this world (1300 tiles, seed 4): a chunk costs 46 ms to build and
## carries 46,000 primitives, and the whole world is 1,681 of them -- 77 seconds
## of building and 77 million primitives for one frame. That is not a budget to
## tighten, it is the wrong picture: at a full zoom out a tile is a pixel and a
## half, so every tuft in those 77 million is smaller than the pixel that would
## have drawn it.
##
## So the far world is its own, coarser thing, and the two are drawn TOGETHER:
## the near chunks in their square around the camera, this everywhere else. It is
## sampled every `STEP` tiles into `BLOCK`-tile blocks, one mesh each so the
## frustum can throw away what is behind the camera, built once on the worker and
## **never dropped** -- which is the whole point. A world that is built once can
## be looked at from any height, in any order, for the rest of the game.
##
## **NO `class_name`, AND THAT IS DELIBERATE.** It had one, and it broke the game
## for the owner while every test, shot, tour and gate stayed green: a global
## class resolves out of Godot's class cache, `tools/_import.sh` refreshes that
## cache whenever a script is newer, and so every instrument in this repository
## repairs the very thing it would otherwise be testing. A person running
## `godot --path .` by hand after a pull does not, and this file then fails to
## PARSE -- taking the render boot down with it, which is nearer the bottom than
## the `RoadHold` that found this the same evening. `WorldView` reaches it through
## a `const` preload, which is resolved by PATH and cannot go stale, the way
## `src/models/` has always done it.
##
## HEIGHT IS THE LAND'S OWN, AND THE NEAR CHUNKS WIN BY THE MASK, NOT BY DEPTH.
## It used to be a FLOOR -- every corner the lowest land within a cell of it --
## so the far world could never poke through the near land where the two
## overlapped. That was right while nobody could see the far world except from
## above. At eye level it flattened every ridge on the horizon to the bottom of
## its valleys. So a corner is now the land it stands in (`PEAK`), and where a
## near chunk is in the scene the far world's own material discards itself
## (`near_mask`, world.gdshader and water.gdshader), which cannot lose a fight it
## never has.

## Tiles per block. One mesh, one draw, one frustum test. Big enough that the
## whole island is ~121 of them rather than thousands, small enough that walking
## at play zoom keeps all but a couple out of the frustum entirely.
const BLOCK := 128
## Tiles per sampled cell. A cell is 6 pixels at a full zoom out.
const STEP := 4
## How far under the land the far world is pushed, so where it meets a near
## chunk's edge it tucks under it rather than standing proud of it.
const DROP := 0.06
## How far a corner leans from the mean of its tiles toward the highest of them.
## From eye level the far land IS its skyline, and a ridge three tiles wide fell
## to half its height under the mean alone.
const PEAK := 0.5

## Land and water of each built block, keyed Vector2i(bx, by).
var _blocks: Dictionary = {}

## WHAT STANDS ON THE FAR LAND, AS A SILHOUETTE. From eye level the near chunks
## end about a hundred tiles out, and past them a forest was bare ground and a
## city was a plain: the line where every tree stopped was the edge of the near
## square drawn across the horizon. So anything standing at least `STANDS` tall
## is carried out here as one plain solid of its own height, width and colour --
## a crown for what has leaves, a tapered block for what was built -- which is
## all that a thing a hundred tiles off is to the eye.
const STANDS := 1.1
## A crown's widest point, as a share of the thing's height, and how far down it
## hangs from the top.
const CROWN_AT := 0.62
const CROWN_HANG := 0.42
## Under this many times its own radius tall, a thing is a MOUND and not a block.
const MOUND := 1.6
## A lit building only carries windows once it stands this tall; one every
## WINDOW_ROW up its faces, WINDOW_TALL high, and this share of them lit.
const WINDOWS_FROM := 2.0
const WINDOW_ROW := 1.3
const WINDOW_TALL := 0.42
const WINDOW_LIT := 0.4
## The mark a far window is drawn with: a lamp or a window (GroundColors 17..32),
## dim, so a far city is a field of small lights and not a wall of them.
const WINDOW := 19

## One summary per model (kind, variant, country): [top, radius, r, g, b, leafy,
## lit, lit r, lit g, lit b] -- `lit` the share of its made faces that are a lamp,
## a window or stolen neon (GroundColors marks 17..34), and their colour,
## read off the model's own template so it can never disagree with the near
## drawing. Shared by the far workers, hence the lock.
static var _sums: Dictionary = {}
static var _sum_lock := Mutex.new()


static func summary(kind: int, variant: int, country: int) -> PackedFloat32Array:
	var key := (kind * PropModels.MAX_VARIANTS + variant) * BiomeRegistry.SLOTS + country
	_sum_lock.lock()
	var got: Variant = _sums.get(key)
	_sum_lock.unlock()
	if got != null:
		return got
	var t := PropModels.template(kind, variant, country)
	var top := 0.0
	var rad := 0.0
	for arr: PackedVector3Array in [t.made_v, t.found_v, t.leaf_v]:
		for v in arr:
			top = maxf(top, v.y)
			rad = maxf(rad, Vector2(v.x, v.z).length())
	# The colour it reads as from far off: its leaves if it has any, else what
	# most of it is made of.
	var leafy := not t.leaf_v.is_empty()
	var cols: PackedColorArray = t.leaf_c if leafy else (t.made_c if t.made_c.size() >= t.found_c.size() else t.found_c)
	var sum := Color(0, 0, 0)
	for c in cols:
		sum.r += c.r
		sum.g += c.g
		sum.b += c.b
	var n := maxf(1.0, float(cols.size()))
	var lit := Color(0, 0, 0)
	var lit_n := 0
	for c in t.made_c:
		var m := int(c.a * 255.0 + 0.5)
		if m >= 17 and m <= 34:
			lit.r += c.r
			lit.g += c.g
			lit.b += c.b
			lit_n += 1
	var ln := maxf(1.0, float(lit_n))
	var out := PackedFloat32Array([top, rad, sum.r / n, sum.g / n, sum.b / n, 1.0 if leafy else 0.0,
		float(lit_n) / maxf(1.0, float(t.made_c.size())), lit.r / ln, lit.g / ln, lit.b / ln])
	_sum_lock.lock()
	_sums[key] = out
	_sum_lock.unlock()
	return out


static func across(size: int) -> int:
	return ceili(float(size) / BLOCK)


## Whether every block of this world is built.
func done(size: int) -> bool:
	var n := across(size)
	return _blocks.size() >= n * n


## The block nearest `focus` that is not built yet, or (-1, -1) when none is
## left. Nearest first, so the ground just past the camera fills in before the
## far side of the island.
func next_block(size: int, focus: Vector2, busy: Dictionary) -> Vector2i:
	var n := across(size)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for by in n:
		for bx in n:
			var key := Vector2i(bx, by)
			if _blocks.has(key) or busy.has(key):
				continue
			var mid := Vector2((bx + 0.5) * BLOCK, (by + 0.5) * BLOCK)
			var d := mid.distance_squared_to(focus)
			if d < best_d:
				best_d = d
				best = key
	return best


## What a worker needs to colour a cell without touching the registry: the wash
## (with its mark in alpha) and the hand of every (ground, landscape) pair, taken
## on the main thread exactly as TerrainMesher takes its own.
static func tables() -> Array:
	var types := BiomeRegistry.SLOTS
	var col := PackedColorArray()
	var hand := PackedFloat32Array()
	col.resize(Ground.COUNT * types)
	hand.resize(Ground.COUNT * types)
	for g in Ground.COUNT:
		for c in BiomeRegistry.count():
			var def := BiomeRegistry.by_index(c)
			var w := GroundColors.wash(g, c)
			w.a = GroundColors.mark(g, c) / 255.0
			col[g * types + c] = w
			hand[g * types + c] = def.hatch * 17.0
	return [col, hand]


## One block as mesh arrays: [land, water]. Pure, so a worker may run it.
## `props` is what stands in this block, snapshotted on the main thread.
static func build_arrays(w: WorldData, bx: int, by: int, tabs: Array, props: Array = []) -> Array:
	var col: PackedColorArray = tabs[0]
	var hand: PackedFloat32Array = tabs[1]
	var types := BiomeRegistry.SLOTS
	# Straight at the arrays, never through level_at/ground_at/country_at. A
	# block reads 18,000 tiles and a GDScript call is about ten times an index:
	# through the accessors one block was ~480 ms, which is most of a second of
	# the far world not being there yet.
	var size := w.size
	var lvl := w.level
	var grd := w.ground
	var cty := w.country
	var cells := BLOCK / STEP
	var x0 := bx * BLOCK
	var y0 := by * BLOCK
	# A corner's height is the land AROUND it: the STEP x STEP tiles it stands in
	# the middle of, read the same way from both blocks that share an edge, so the
	# blocks meet without a crack.
	var side := cells + 1
	var h := PackedFloat32Array()
	h.resize(side * side)
	var half := STEP / 2
	var per := 1.0 / float(STEP * STEP)
	for cj in side:
		var ty := y0 + cj * STEP - half
		for ci in side:
			var tx := x0 + ci * STEP - half
			var sum := 0.0
			var most := 0.0
			for dy in STEP:
				var y := clampi(ty + dy, 0, size - 1)
				var row := y * size
				for dx in STEP:
					var x := clampi(tx + dx, 0, size - 1)
					var th := maxf(0.0, TerrainMesher.level_height(lvl[row + x]))
					sum += th
					most = maxf(most, th)
			# Half way from the mean to the highest: a ridge narrower than a cell
			# still stands on the skyline, and a valley keeps most of its depth.
			h[cj * side + ci] = lerpf(sum * per, most, PEAK) - DROP

	# Sized for a full block up front and cut back at the end: an append that
	# grows a PackedArray copies it, and there are 30,000 of them here.
	var most := cells * cells * 6
	var lv := PackedVector3Array()
	var ln := PackedVector3Array()
	var lc := PackedColorArray()
	var luv := PackedVector2Array()
	var luv2 := PackedVector2Array()
	lv.resize(most)
	ln.resize(most)
	lc.resize(most)
	luv.resize(most)
	luv2.resize(most)
	var ln_at := 0
	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	var wc := PackedColorArray()
	wv.resize(most)
	wn.resize(most)
	wc.resize(most)
	var wn_at := 0
	# What the open sea is drawn with (world_view's _add_open_sea): deep, open and
	# clear of any bank. At this range one value is the whole of what water is.
	var sea := Color(0.0, 1.0, 0.5, 1.0)
	for cj in cells:
		var ty := y0 + cj * STEP
		if ty >= w.size:
			break
		for ci in cells:
			var tx := x0 + ci * STEP
			if tx >= w.size:
				break
			# The cell's middle says what it is made of.
			var mi := mini(ty + STEP / 2, size - 1) * size + mini(tx + STEP / 2, size - 1)
			var g := grd[mi]
			var c := clampi(cty[mi], 0, types - 1)
			var slot := g * types + c
			var wash := col[slot]
			# Terraces one level apart alternate a hair in value, as the mesher's
			# own table does, so the contour is felt at this range too.
			if (lvl[mi] & 1) == 1:
				var a2 := wash.a
				wash = wash.darkened(0.03)
				wash.a = a2
			var uv := Vector2(hand[slot], 0.0)
			var xa := float(tx)
			var xb := float(mini(tx + STEP, size))
			var ya := float(ty)
			var yb := float(mini(ty + STEP, size))
			var a := Vector3(xa, h[cj * side + ci], ya)
			var b := Vector3(xb, h[cj * side + ci + 1], ya)
			var d := Vector3(xb, h[(cj + 1) * side + ci + 1], yb)
			var e := Vector3(xa, h[(cj + 1) * side + ci], yb)
			# WOUND LIKE THE OPEN SEA NEXT DOOR (`world_view._add_open_sea`), which
			# is the one upward face in this repo already proved to draw. Wound the
			# other way every triangle here was a backface: the blocks were built,
			# the draw calls went out, the primitives were counted, and the world
			# was not on the screen. Nothing errors and nothing is missing -- the
			# only symptom is that you are looking at the near chunks and think
			# they are the far ones.
			var n1 := (b - a).cross(d - a).normalized()
			var n2 := (d - a).cross(e - a).normalized()
			if n1.y < 0.0:
				n1 = -n1
			if n2.y < 0.0:
				n2 = -n2
			lv[ln_at] = a
			lv[ln_at + 1] = b
			lv[ln_at + 2] = d
			lv[ln_at + 3] = a
			lv[ln_at + 4] = d
			lv[ln_at + 5] = e
			for k in 3:
				ln[ln_at + k] = n1
				ln[ln_at + 3 + k] = n2
			for k in 6:
				lc[ln_at + k] = wash
				luv[ln_at + k] = uv
				luv2[ln_at + k] = Vector2.ZERO
			ln_at += 6
			if Ground.is_water(g):
				# THE WATER IS DROPPED TOO, and forgetting that is the worst thing
				# this file has done. The land is a floor less `DROP` precisely so
				# the near chunks always win where the two overlap -- and then the
				# sea was laid at `WATER_Y` exactly, which is where the near water
				# is laid, so two perfectly flat coplanar surfaces fought across
				# the whole sea. It is the one place the floor trick cannot work by
				# itself: a flat surface has no lowest corner to be lower than.
				# Measured from the frame, not reasoned: the sea came out blocky
				# white noise on the 4-tile cell grid with a hard wedge at the
				# shore, and switching the far mesh off cleared both.
				var y := TerrainMesher.WATER_Y - DROP
				wv[wn_at] = Vector3(xa, y, ya)
				wv[wn_at + 1] = Vector3(xb, y, ya)
				wv[wn_at + 2] = Vector3(xb, y, yb)
				wv[wn_at + 3] = Vector3(xa, y, ya)
				wv[wn_at + 4] = Vector3(xb, y, yb)
				wv[wn_at + 5] = Vector3(xa, y, yb)
				for k in 6:
					wn[wn_at + k] = Vector3.UP
					wc[wn_at + k] = sea
				wn_at += 6

	lv.resize(ln_at)
	ln.resize(ln_at)
	lc.resize(ln_at)
	luv.resize(ln_at)
	luv2.resize(ln_at)
	_stand_props(w, props, lv, ln, lc, luv, luv2)
	wv.resize(wn_at)
	wn.resize(wn_at)
	wc.resize(wn_at)
	var land: Array = []
	if not lv.is_empty():
		land.resize(Mesh.ARRAY_MAX)
		land[Mesh.ARRAY_VERTEX] = lv
		land[Mesh.ARRAY_NORMAL] = ln
		land[Mesh.ARRAY_COLOR] = lc
		land[Mesh.ARRAY_TEX_UV] = luv
		land[Mesh.ARRAY_TEX_UV2] = luv2
	var water: Array = []
	if not wv.is_empty():
		water.resize(Mesh.ARRAY_MAX)
		water[Mesh.ARRAY_VERTEX] = wv
		water[Mesh.ARRAY_NORMAL] = wn
		water[Mesh.ARRAY_COLOR] = wc
	return [land, water]


## Every prop standing at least `STANDS` tall, as one plain solid on the far land.
static func _stand_props(w: WorldData, props: Array, lv: PackedVector3Array, ln: PackedVector3Array,
		lc: PackedColorArray, luv: PackedVector2Array, luv2: PackedVector2Array) -> void:
	var sv := PackedVector3Array()
	var sn := PackedVector3Array()
	var sc := PackedColorArray()
	for p: WorldProp in props:
		var country := maxi(Country.COAST, w.country[mini(floori(p.pos.y), w.size - 1) * w.size + mini(floori(p.pos.x), w.size - 1)])
		var sm := summary(p.kind, PropModels.variant_of(p, w.seed_value, country), country)
		var top := sm[0] * p.scale
		if top < STANDS:
			continue
		var tx := clampi(floori(p.pos.x), 0, w.size - 1)
		var ty := clampi(floori(p.pos.y), 0, w.size - 1)
		var base := maxf(0.0, TerrainMesher.level_height(w.level[ty * w.size + tx]))
		var col := Color(sm[2], sm[3], sm[4], 1.0)
		var r := maxf(0.25, sm[1] * p.scale)
		var at := Vector3(p.pos.x, base, p.pos.y)
		if sm[5] > 0.5:
			_crown(sv, sn, sc, at + Vector3(0, top * CROWN_AT, 0), top * CROWN_HANG, top * (1.0 - CROWN_AT), r * 0.8, p.rot, col)
		elif top < r * MOUND:
			# Lower than it is wide -- a boulder, a wreck, a heap: a faceted mound,
			# never a block, because a squat block is a cube on the skyline.
			_crown(sv, sn, sc, at + Vector3(0, top * 0.38, 0), top * 0.45, top * 0.62, r * 0.85, p.rot, col)
		else:
			_block(sv, sn, sc, at, top, r * 0.72, p.rot, col)
			if sm[6] > 0.0 and top >= WINDOWS_FROM:
				_windows(sv, sn, sc, at, top, r * 0.72, p.rot, Color(sm[7], sm[8], sm[9], WINDOW / 255.0), w.seed_value, p.id)
	lv.append_array(sv)
	ln.append_array(sn)
	for c in sc:
		lc.append(c)
		luv.append(Vector2.ZERO)
		luv2.append(Vector2.ZERO)


## A triangle whose FRONT is `out`: wound the way this file's land is (see the
## note in build_arrays), whichever order the corners came in.
static func _tri(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		a: Vector3, b: Vector3, d: Vector3, out: Vector3, col: Color) -> void:
	var f := (b - a).cross(d - a)
	if f.dot(out) > 0.0:
		var t := b
		b = d
		d = t
		f = -f
	var nn := -f.normalized()
	v.append_array([a, b, d])
	n.append_array([nn, nn, nn])
	c.append_array([col, col, col])


## A crown: a four-sided double cone round `mid`, `down` to its foot and `up` to
## its tip, `r` wide, turned by `rot` so no two stand square to each other.
static func _crown(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		mid: Vector3, down: float, up: float, r: float, rot: float, col: Color) -> void:
	var tip := mid + Vector3(0, up, 0)
	var foot := mid - Vector3(0, down, 0)
	var ring: Array[Vector3] = []
	for i in 5:
		var a := rot + i * TAU / 5.0
		ring.append(mid + Vector3(cos(a) * r, 0.0, sin(a) * r))
	for i in 5:
		var p0 := ring[i]
		var p1 := ring[(i + 1) % 5]
		var side := ((p0 + p1) * 0.5 - mid)
		_tri(v, n, c, p0, p1, tip, (side + Vector3(0, up * 0.5, 0)).normalized(), col)
		_tri(v, n, c, p0, p1, foot, (side - Vector3(0, down * 0.5, 0)).normalized(), col.darkened(0.18))


## A built thing: a block from the ground to `top`, `r` across its half, a
## little narrower at the top than the foot, turned by `rot`.
static func _block(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		at: Vector3, top: float, r: float, rot: float, col: Color) -> void:
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i in 4:
		var a := rot + PI * 0.25 + i * PI * 0.5
		var d := Vector3(cos(a), 0.0, sin(a))
		lo.append(at + d * r - Vector3(0, 0.3, 0))
		hi.append(at + d * r * 0.86 + Vector3(0, top, 0))
	for i in 4:
		var j := (i + 1) % 4
		var out := ((lo[i] + lo[j]) * 0.5 - at)
		out.y = 0.0
		out = out.normalized()
		_tri(v, n, c, lo[i], lo[j], hi[j], out, col)
		_tri(v, n, c, lo[i], hi[j], hi[i], out, col)
	_tri(v, n, c, hi[0], hi[1], hi[2], Vector3.UP, col.lightened(0.06))
	_tri(v, n, c, hi[0], hi[2], hi[3], Vector3.UP, col.lightened(0.06))


## Lit windows on a far building: rows up its four faces, some lit and most
## dark, dealt by the prop's own id so a skyline is the same skyline every night.
## A window mark (GroundColors 17..32) is dark glass by day and burns when the
## light goes, so the far city is a wall of dead glass at noon and a field of
## lights at night, which is the one thing a city is from twenty streets away.
static func _windows(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		at: Vector3, top: float, r: float, rot: float, col: Color, seed_value: int, id: int) -> void:
	var rows := clampi(floori((top - 0.6) / WINDOW_ROW), 1, 24)
	for i in 4:
		var a0 := rot + PI * 0.25 + i * PI * 0.5
		var a1 := a0 + PI * 0.5
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var out := (d0 + d1).normalized()
		var lo0 := at + d0 * r - Vector3(0, 0.3, 0)
		var lo1 := at + d1 * r - Vector3(0, 0.3, 0)
		var hi0 := at + d0 * r * 0.86 + Vector3(0, top, 0)
		var hi1 := at + d1 * r * 0.86 + Vector3(0, top, 0)
		var span := top + 0.3
		for row in rows:
			var t0 := (0.3 + 0.6 + row * WINDOW_ROW) / span
			var t1 := t0 + WINDOW_TALL / span
			for k in 3:
				if Rng.hash01(seed_value, id, i * 97 + row * 7 + k) > WINDOW_LIT:
					continue
				var u0 := 0.16 + k * 0.26
				var u1 := u0 + 0.14
				var q := func(u: float, tt: float) -> Vector3:
					return lo0.lerp(lo1, u).lerp(hi0.lerp(hi1, u), tt) + out * 0.04
				var pa: Vector3 = q.call(u0, t0)
				var pb: Vector3 = q.call(u1, t0)
				var pc: Vector3 = q.call(u1, t1)
				var pd: Vector3 = q.call(u0, t1)
				_tri(v, n, c, pa, pb, pc, out, col)
				_tri(v, n, c, pa, pc, pd, out, col)


## Put a built block into the scene. Nothing here casts a shadow: the sun's one
## split is fitted to what the camera shows, and a coarse floor under the real
## land has no business in it.
func add_block(key: Vector2i, arrays: Array, land_mat: Material, water_mat: Material) -> void:
	if _blocks.has(key):
		return
	var node := Node3D.new()
	node.name = "far_%d_%d" % [key.x, key.y]
	for pair: Array in [[arrays[0], land_mat, "land"], [arrays[1], water_mat, "water"]]:
		var a: Array = pair[0]
		if a.is_empty():
			continue
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var mi := MeshInstance3D.new()
		mi.name = pair[2]
		mi.mesh = mesh
		mi.material_override = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	add_child(node)
	_blocks[key] = node


func block_count() -> int:
	return _blocks.size()
