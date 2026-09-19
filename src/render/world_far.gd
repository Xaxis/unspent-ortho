class_name WorldFar
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
## HEIGHT IS TAKEN AS A FLOOR, NEVER AS A SAMPLE. Every corner is the LOWEST
## land within a cell of it, less `DROP`. The two surfaces overlap wherever the
## near square reaches, and one of them has to lose: a sampled height wins
## sometimes and loses sometimes, which draws a ring of coarse land punching
## through the detailed land at the seam. A floor cannot win, so there is no
## seam to see -- only detail, ending.

## Tiles per block. One mesh, one draw, one frustum test. Big enough that the
## whole island is ~121 of them rather than thousands, small enough that walking
## at play zoom keeps all but a couple out of the frustum entirely.
const BLOCK := 128
## Tiles per sampled cell. A cell is 6 pixels at a full zoom out.
const STEP := 4
## How far under the land the floor is pushed. The lattice the mesher draws dips
## a little below its own terrace at a ground edge; this clears that too.
const DROP := 0.06

## Land and water of each built block, keyed Vector2i(bx, by).
var _blocks: Dictionary = {}


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
	# The lowest land in each cell, over a ring of one cell beyond the block, so
	# a corner on the block's edge is the same number in both of its blocks.
	var wide := cells + 2
	var lo := PackedInt32Array()
	lo.resize(wide * wide)
	for j in wide:
		var ty := y0 + (j - 1) * STEP
		for i in wide:
			var tx := x0 + (i - 1) * STEP
			var m := 0x7FFFFFFF
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
					if l < m:
						m = l
			lo[j * wide + i] = m
	# A corner is the floor of every cell that touches it.
	var side := cells + 1
	var h := PackedFloat32Array()
	h.resize(side * side)
	for cj in side:
		for ci in side:
			var m := mini(mini(lo[cj * wide + ci], lo[cj * wide + ci + 1]),
				mini(lo[(cj + 1) * wide + ci], lo[(cj + 1) * wide + ci + 1]))
			h[cj * side + ci] = maxf(0.0, TerrainMesher.level_height(m)) - DROP

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
