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
const FarModels := preload("res://src/models/far_models.gd")
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

## WHAT STANDS ON THE FAR LAND IS THE MODEL ITSELF, SEEN FROM FAR OFF. From eye
## level the near chunks end about a hundred tiles out, and past them a forest was
## bare ground and a city was a plain: the line where every tree stopped was the
## edge of the near square drawn across the horizon. So anything standing at least
## `STANDS` tall is carried out here as its own near model with what is too small
## to see at that range left out (`far_models.gd`): a tower keeps its setbacks, its
## balconies, its roof clutter and the lit windows that make a far city a field of
## lights at night, and a pylon keeps its lattice. It used to be one plain solid of
## the model's height, width and colour, and from eye level that read as exactly
## what it was -- a city of grey prisms.
const STANDS := 1.1
## Two far levels on every block (FarModels.NEAR_FAR, FarModels.FAR), handed over
## at this distance from the camera to the block's middle. A block is 128 tiles
## across, so its near edge can be ninety tiles closer than that: the coarse level
## is two pixels coarse at 170 tiles, which is where it can first be seen.
const FAR_AT := 260.0
## 0 for the reason world_view's LOD_MARGIN is: a margin on both halves of a
## hand-over leaves a band where neither is drawn.
const FAR_MARGIN := 0.0

## A FAR CITY AT NIGHT IS ITS LIGHTS, and a window is far smaller than anything a
## far model keeps. So a lit building (`summary` lit > 0) standing `WINDOWS_FROM`
## tall carries windows laid on its far model's own walls: every wall face of it
## at least `WALL_LEAST` in area gets a grid of them, `WINDOW_ROW` apart up and
## `WINDOW_COL` along, `WINDOW_LIT` of them lit, dealt by the prop's own id so a
## skyline is the same skyline every night and no two towers of one model agree.
## Mark `WINDOW` is dark glass by day and burns when the light goes.
const WINDOWS_FROM := 2.0
const WALL_LEAST := 0.8
const WINDOW_ROW := 1.3
const WINDOW_COL := 0.8
const WINDOW_TALL := 0.42
const WINDOW_WIDE := 0.3
const WINDOW_LIT := 0.4
const WINDOW := 19

## The height, reach and lit share of one model (kind, variant, country): [top,
## radius, lit, lit r, lit g, lit b], read off its own template -- `lit` the share of its made faces
## that are a lamp, a window or stolen neon (GroundColors 17..34), and their colour,
## so a far window is lit the colour the near ones are. Shared by the
## far workers, hence the lock.
static var _sums: Dictionary = {}
static var _sum_lock := Mutex.new()


static func summary(kind: int, variant: int, country: int) -> PackedFloat32Array:
	var key := (kind * PropModels.MAX_VARIANTS + variant) * BiomeRegistry.SLOTS + country
	_sum_lock.lock()
	var got: Variant = _sums.get(key)
	_sum_lock.unlock()
	if typeof(got) != TYPE_NIL:
		return got
	var t := PropModels.template(kind, variant, country)
	var top := 0.0
	var rad := 0.0
	for arr: PackedVector3Array in [t.made_v, t.found_v, t.leaf_v]:
		for v in arr:
			top = maxf(top, v.y)
			rad = maxf(rad, Vector2(v.x, v.z).length())
	var lit := 0
	var glow := Color(0, 0, 0)
	for i in range(0, t.made_c.size(), 3):
		var c := t.made_c[i]
		var m := int(c.a * 255.0 + 0.5)
		if m >= 17 and m <= 34:
			lit += 1
			glow += Color(c.r, c.g, c.b, 0.0)
	var ln := maxf(1.0, float(lit))
	var out := PackedFloat32Array([top, rad, float(lit) * 3.0 / maxf(1.0, float(t.made_c.size())),
		glow.r / ln, glow.g / ln, glow.b / ln])
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
static func build_arrays(w: WorldData, bx: int, by: int, tabs: Array) -> Array:
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
			# Whole levels, inline: a GDScript call is about ten times an index, and
			# through clampi/maxf/level_height this loop tripled a block's build.
			var sum := 0
			var most := 0
			for dy in STEP:
				var y := ty + dy
				if y < 0:
					y = 0
				elif y >= size:
					y = size - 1
				var row := y * size
				for dx in STEP:
					var x := tx + dx
					if x < 0:
						x = 0
					elif x >= size:
						x = size - 1
					var l := lvl[row + x]
					if l > 0:
						sum += l
						if l > most:
							most = l
			# Half way from the mean to the highest: a ridge narrower than a cell
			# still stands on the skyline, and a valley keeps most of its depth.
			h[cj * side + ci] = lerpf(sum * per, float(most), PEAK) * WorldData.STEP - DROP

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


## Every prop standing at least `STANDS` tall, as its far models on the far land:
## [] when nothing there stands that tall, else one entry per far level
## (`LEVELS`), each [made arrays, found arrays, leaf arrays] with [] for a surface
## the level has nothing in. Pure, so a worker may run it; `props` is snapshotted
## on the main thread.
##
## A PASS OF ITS OWN, AND ONLY ONCE THE HORIZON HAS BEEN SEEN (WorldView). It
## asks every model the far land holds for its template, which is most of the
## world's models built once: measured on seed 7 that took a far block from 9 ms
## to 172, contending with the near chunks' own worker for the template lock, for
## silhouettes the orthographic camera never shows.
const LEVELS: Array[int] = [FarModels.NEAR_FAR, FarModels.FAR]
## Level masks: bit i is LEVELS[i]. CLOSE is drawn only to FAR_AT at eye level,
## COARSE past it and from above.
const CLOSE := 1
const COARSE := 2
const BOTH := 3


## Each level asked for in `want` (bit i for LEVELS[i]); a level not asked for
## comes back as three empty surfaces. [] when nothing here stands tall enough.
static func stand_arrays(w: WorldData, props: Array, want: int = BOTH) -> Array:
	var outs: Array = []
	for level: int in LEVELS:
		outs.append([MeshKit.new(), MeshKit.new(), MeshKit.new()])
	var any := false
	for p: WorldProp in props:
		var country := maxi(Country.COAST, w.country[mini(floori(p.pos.y), w.size - 1) * w.size + mini(floori(p.pos.x), w.size - 1)])
		var variant := PropModels.variant_of(p, w.seed_value, country)
		if summary(p.kind, variant, country)[0] * p.scale < STANDS:
			continue
		any = true
		var tx := clampi(floori(p.pos.x), 0, w.size - 1)
		var ty := clampi(floori(p.pos.y), 0, w.size - 1)
		var base := maxf(0.0, TerrainMesher.level_height(w.level[ty * w.size + tx]))
		# Turned and cast exactly as the near chunk bakes it, so the hand-over at
		# the edge of the near square moves nothing but what is too small to see.
		var xf := WorldView.prop_xform(p, country, w.seed_value, base)
		var nx := Transform3D(xf.basis.orthonormalized(), Vector3.ZERO)
		var sm := summary(p.kind, variant, country)
		for i in LEVELS.size():
			if not want & (1 << i):
				continue
			var t := FarModels.template(p.kind, variant, country, LEVELS[i])
			var kits: Array = outs[i]
			_put(kits[0], xf * t.made_v, nx * t.made_n, t.made_c, t.made_uv, t.made_uv2)
			if sm[2] > 0.0 and sm[0] * p.scale >= WINDOWS_FROM:
				_windows(kits[0], t, xf, nx, w.seed_value, p.id, Color(sm[3], sm[4], sm[5], WINDOW / 255.0))
			_put(kits[1], xf * t.found_v, nx * t.found_n, t.found_c, PackedVector2Array(), PackedVector2Array())
			_put(kits[2], xf * t.leaf_v, nx * t.leaf_n, t.leaf_c, t.leaf_uv, t.leaf_uv2)
	if not any:
		return []
	var out: Array = []
	for kits: Array in outs:
		out.append([_arrays(kits[0], true), _arrays(kits[1], false), _arrays(kits[2], true)])
	return out


## Windows on the walls of far model `t` into `k`, placed through `xf`. A cell's
## middle lies in exactly one of the two triangles of a quad wall, so a wall is
## windowed once however it was cut into faces.
static func _windows(k: MeshKit, t: PropModels.Template, xf: Transform3D, nx: Transform3D, seed_value: int, id: int, col_c: Color) -> void:
	var v := t.made_v
	for i in range(0, v.size(), 3):
		var a := v[i]
		var b := v[i + 1]
		var d := v[i + 2]
		var f := (b - a).cross(d - a)
		var area := f.length() * 0.5
		if area < WALL_LEAST * 0.5:
			continue
		# The model's own normal says which way is out, whatever the winding.
		var n := t.made_n[i]
		if absf(n.y) > 0.2 or n.length() < 0.5:
			continue
		n = Vector3(n.x, 0.0, n.z).normalized()
		var along := Vector3.UP.cross(n).normalized()
		var lo := minf(a.y, minf(b.y, d.y))
		var hi := maxf(a.y, maxf(b.y, d.y))
		var u0 := minf(a.dot(along), minf(b.dot(along), d.dot(along)))
		var u1 := maxf(a.dot(along), maxf(b.dot(along), d.dot(along)))
		var plane := a.dot(n)
		for row in range(floori(lo / WINDOW_ROW), ceili(hi / WINDOW_ROW)):
			var y := (row + 0.5) * WINDOW_ROW
			if y < 0.6:
				continue
			for col in range(floori(u0 / WINDOW_COL), ceili(u1 / WINDOW_COL)):
				var u := (col + 0.5) * WINDOW_COL
				var c := along * u + Vector3.UP * y + n * plane
				if not _inside(c, a, b, d, f):
					continue
				if Rng.hash01(seed_value, id, row * 131 + col, roundi(plane * 7.0)) > WINDOW_LIT:
					continue
				var lift := n * 0.04
				var sx := along * WINDOW_WIDE * 0.5
				var sy := Vector3.UP * WINDOW_TALL * 0.5
				var q := PackedVector3Array([c - sx - sy + lift, c + sx - sy + lift, c + sx + sy + lift, c - sx + sy + lift])
				# Wound the way the wall it lies on is.
				var order: Array = [0, 2, 1, 0, 3, 2] if (q[2] - q[0]).cross(q[1] - q[0]).dot(f) > 0.0 else [0, 1, 2, 0, 2, 3]
				for j: int in order:
					k.verts.append(xf * (q[j] as Vector3))
					k.normals.append(nx * n)
					k.colors.append(col_c)
					k.uvs.append(Vector2.ZERO)
					k.uv2s.append(Vector2.ZERO)


## Whether `p`, on the triangle's plane, lies inside it (`f` its cross product).
static func _inside(p: Vector3, a: Vector3, b: Vector3, d: Vector3, f: Vector3) -> bool:
	return (b - a).cross(p - a).dot(f) >= 0.0 and (d - b).cross(p - b).dot(f) >= 0.0 \
		and (a - d).cross(p - d).dot(f) >= 0.0


static func _put(k: MeshKit, v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		uv: PackedVector2Array, uv2: PackedVector2Array) -> void:
	if v.is_empty():
		return
	k.verts.append_array(v)
	k.normals.append_array(n)
	k.colors.append_array(c)
	k.uvs.append_array(uv)
	k.uv2s.append_array(uv2)


static func _arrays(k: MeshKit, uvs: bool) -> Array:
	if k.verts.is_empty():
		return []
	var a: Array = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = k.verts
	a[Mesh.ARRAY_NORMAL] = k.normals
	a[Mesh.ARRAY_COLOR] = k.colors
	if uvs and k.uvs.size() == k.verts.size():
		a[Mesh.ARRAY_TEX_UV] = k.uvs
		a[Mesh.ARRAY_TEX_UV2] = k.uv2s
	return a


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


## Block -> the levels of its silhouettes that are in (CLOSE, COARSE), whether
## or not anything stood there. A level is BUILT ONLY WHERE IT CAN BE SEEN and
## let go when it cannot (WorldView._stand_want, _stand_keep): the close level
## of the whole island was 331 MB of mesh and is drawn only within FAR_AT of an
## eye (the streaming design's far tiers).
var _stood: Dictionary = {}
## Block -> [close bytes, coarse bytes] of what it holds; and their sum.
var _bytes: Dictionary = {}
var stand_bytes := 0


## The levels block `key` holds.
func stood(key: Vector2i) -> int:
	return int(_stood.get(key, 0))


## Every block that holds any level.
func stood_keys() -> Array:
	return _stood.keys()


## Whether every built block holds every level `want` asks of it.
func stands_settled(want: Callable) -> bool:
	for key: Vector2i in _blocks.keys():
		var need: int = want.call(key)
		if need & ~stood(key):
			return false
	return true


## The nearest block with its land in and a level `want` asks for missing, or
## (-1, -1).
func next_stand(want: Callable, focus: Vector2, busy: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for key: Vector2i in _blocks.keys():
		if busy.has(key):
			continue
		var need: int = want.call(key)
		if not need & ~stood(key):
			continue
		var mid := Vector2((key.x + 0.5) * BLOCK, (key.y + 0.5) * BLOCK)
		var d := mid.distance_squared_to(focus)
		if d < best_d:
			best_d = d
			best = key
	return best


## Let block `key`'s level (CLOSE or COARSE) go: its meshes, anything of it still
## queued, and its bytes. Built again, the same, when it is wanted again.
func drop_level(key: Vector2i, level: int) -> void:
	if not stood(key) & level:
		return
	var i := 0 if level == CLOSE else 1
	_stood[key] = stood(key) & ~level
	if stood(key) == 0:
		_stood.erase(key)
	_pending = _pending.filter(func(e: Array) -> bool: return not (e[0] == key and int(e[1]) == i))
	var node: Node3D = _blocks.get(key)
	if node != null:
		for mi: Node in node.get_children():
			if mi.has_meta(&"far_level") and int(mi.get_meta(&"far_level")) == i:
				node.remove_child(mi)
				mi.queue_free()
	var b: Array = _bytes.get(key, [0, 0])
	stand_bytes -= int(b[i])
	b[i] = 0
	_bytes[key] = b


## Put a block's far models in: each level's made, found and leaf surfaces under
## the far world's own copies of the three materials (`mats`, in that order), the
## close level drawn until `FAR_AT` and the coarse one after it.
##
## QUEUED, AND PUT IN ONE SURFACE A FRAME BY `pump`. A forest block's far models
## are six uploads of up to seventy thousand triangles, and made all at once they
## were a 17.7 ms frame on the main thread where the plain solids had cost 9.7. The
## coarse level goes first, so a block that is only partly in is still whole.
var _pending: Array = []


func add_stands(key: Vector2i, levels: Array, mats: Array, built: int = BOTH) -> void:
	if not _blocks.has(key):
		return
	built &= ~stood(key)
	if built == 0:
		return
	_stood[key] = stood(key) | built
	if levels.is_empty():
		return
	var b: Array = _bytes.get(key, [0, 0])
	for i in range(levels.size() - 1, -1, -1):
		if not built & (1 << i):
			continue
		var surf: Array = levels[i]
		for j in 3:
			if not (surf[j] as Array).is_empty():
				_pending.append([key, i, j, surf[j], mats[j]])
				var n := _surface_bytes(surf[j])
				b[i] = int(b[i]) + n
				stand_bytes += n
	_bytes[key] = b


static func _surface_bytes(a: Array) -> int:
	var n := 0
	for v: Variant in a:
		if v is PackedVector3Array:
			n += (v as PackedVector3Array).size() * 12
		elif v is PackedVector2Array:
			n += (v as PackedVector2Array).size() * 8
		elif v is PackedColorArray:
			n += (v as PackedColorArray).size() * 16
		elif v is PackedFloat32Array:
			n += (v as PackedFloat32Array).size() * 4
		elif v is PackedInt32Array:
			n += (v as PackedInt32Array).size() * 4
	return n


## Put the next queued far surface in; false when none is left.
func pump() -> bool:
	if _pending.is_empty():
		return false
	var e: Array = _pending.pop_front()
	var names := ["stands", "stands_found", "stands_leaf"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, e[3])
	var mi := MeshInstance3D.new()
	mi.name = names[e[2]] + ("" if e[1] == 0 else "_far")
	mi.mesh = mesh
	mi.material_override = e[4]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta(&"far_level", e[1])
	_range(mi)
	(_blocks[e[0]] as Node3D).add_child(mi)
	return true


## Whether an eye-level camera is drawing. From eye level the close level draws
## to FAR_AT and the coarse one past it; from above, where a far block is only
## ever seen with the whole island under the camera, the coarse level draws at
## every range and the close one not at all, so the top-down game pays for the
## far models no more than it paid for the plain solids they replaced.
var _eye := false


func set_eye(on: bool) -> void:
	if on == _eye:
		return
	_eye = on
	for node: Node in get_children():
		for mi: Node in node.get_children():
			if mi.has_meta(&"far_level"):
				_range(mi as GeometryInstance3D)


## Whether the far models are drawn at all (WorldView: always at eye level, and
## from above only once the camera takes in more than the near square).
var _shown := true


func set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	for node: Node in get_children():
		for mi: Node in node.get_children():
			if mi.has_meta(&"far_level"):
				_range(mi as GeometryInstance3D)


func _range(mi: GeometryInstance3D) -> void:
	var close := int(mi.get_meta(&"far_level")) == 0
	mi.visible = _shown and (_eye or not close)
	mi.visibility_range_end = FAR_AT if _eye and close else 0.0
	mi.visibility_range_end_margin = FAR_MARGIN if _eye and close else 0.0
	mi.visibility_range_begin = FAR_AT if _eye and not close else 0.0
	mi.visibility_range_begin_margin = FAR_MARGIN if _eye and not close else 0.0
