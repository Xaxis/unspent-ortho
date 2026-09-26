extends TestCase
## GROUND ABOVE THE GROUND, DRAWN (TerrainMesher._spans; DESIGN_ABOVE S1): mass
## hung over tiles (WorldData.overhead) is drawn as an underside facing down at
## its underside's height, a top facing up at its top's, and a rim between them,
## on a wandering edge and not the tile grid; nothing is drawn where nothing
## hangs, and a span costs its own chunk little.

const F := preload("res://tests/fight/fixture.gd")
const GROUND := 2
const UNDER := GROUND + 6
const OVER := UNDER + 3


## A flat field with a slab over tiles 10..21 x 10..19.
func _roofed() -> WorldData:
	var w := F.flat_world(64, Ground.GRASS, Country.COAST, GROUND)
	for y in range(10, 20):
		for x in range(10, 22):
			w.set_overhead(x, y, UNDER, OVER)
	return w


func _arrays(w: WorldData) -> Array:
	return TerrainMesher.new(w).build_arrays(0, 0).terrain_arrays


func test_a_slab_is_drawn_as_an_underside_a_top_and_a_rim() -> void:
	var a := _arrays(_roofed())
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var under_y := UNDER * WorldData.STEP
	var over_y := OVER * WorldData.STEP
	var down := 0
	var up := 0
	var rim := 0
	for i in v.size():
		if v[i].y < GROUND * WorldData.STEP + 0.5:
			continue
		# The rim's undercut band faces out and down too, higher up.
		if nn[i].y < -0.5 and absf(v[i].y - under_y) < 0.01:
			down += 1
		elif nn[i].y > 0.5 and absf(v[i].y - over_y) < 0.2:
			up += 1
		elif absf(nn[i].y) < 0.8:
			rim += 1
	gt(float(down), 200.0, "the slab has an underside facing down (%d)" % down)
	gt(float(up), 200.0, "and a top facing up (%d)" % up)
	gt(float(rim), 50.0, "and a rim between them (%d)" % rim)


## THE EDGE IS NOT THE TILE GRID: the top's outline wanders off tile lines, as a
## terrace edge does (docs/LOOK.md), but never far from them (the walk stops a
## body at the tile).
func test_its_edge_wanders_off_the_tile_grid_but_stays_near_it() -> void:
	var a := _arrays(_roofed())
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var over_y := OVER * WorldData.STEP
	var off := 0
	var edge := 0
	for i in v.size():
		if absf(v[i].y - over_y) > 0.02 or nn[i].y < 0.5:
			continue
		# The edge: top vertices off the half-tile lattice are crossings.
		var fx := v[i].x * 2.0 - roundf(v[i].x * 2.0)
		var fz := v[i].z * 2.0 - roundf(v[i].z * 2.0)
		if absf(fx) < 0.01 and absf(fz) < 0.01:
			continue
		edge += 1
		# Its distance from the slab's own tile rectangle.
		var dx := maxf(10.0 - v[i].x, v[i].x - 22.0)
		var dz := maxf(10.0 - v[i].z, v[i].z - 20.0)
		lt(maxf(dx, dz), 0.75, "within the warp of the slab's tiles (%.2f, %.2f)" % [v[i].x, v[i].z])
		# How far it has wandered from the slab's straight sides.
		var side := minf(minf(absf(v[i].x - 10.0), absf(v[i].x - 22.0)), minf(absf(v[i].z - 10.0), absf(v[i].z - 20.0)))
		if side > 0.05:
			off += 1
	gt(float(edge), 40.0, "the top has an edge (%d crossings)" % edge)
	gt(float(off) / float(edge), 0.5, "and most of it has wandered off the slab's straight sides (%d of %d)" % [off, edge])


## NOTHING HANGS, NOTHING IS DRAWN: a chunk with no mass over it or near it
## builds exactly what it did.
func test_a_chunk_with_nothing_over_it_is_unchanged() -> void:
	var w := F.flat_world(96, Ground.GRASS, Country.COAST, GROUND)
	var bare := _arrays(w)
	w.set_overhead(80, 80, UNDER, OVER)
	var far := _arrays(w)
	eq((far[Mesh.ARRAY_VERTEX] as PackedVector3Array), (bare[Mesh.ARRAY_VERTEX] as PackedVector3Array), "the same vertices")


## THE COST: a slab over a third of a chunk, against the same chunk bare. Best
## of five interleaved. Measured +77% to +101% (13 to 19 ms, on the worker):
## an underside, a rim and a top are a second land over that third, drawn by
## the same kind of GDScript. The bound holds it there; a realm roofed over most
## of its chunks (DESIGN_ABOVE S3) is where it must come down.
func test_a_spanned_chunk_costs_little_more() -> void:
	var bare_w := F.flat_world(64, Ground.GRASS, Country.COAST, GROUND)
	var roof_w := _roofed()
	var bare_m := TerrainMesher.new(bare_w)
	var roof_m := TerrainMesher.new(roof_w)
	var bare := 1 << 40
	var roofed := 1 << 40
	for i in 5:
		var t0 := Time.get_ticks_usec()
		bare_m.build_arrays(0, 0)
		bare = mini(bare, Time.get_ticks_usec() - t0)
		t0 = Time.get_ticks_usec()
		roof_m.build_arrays(0, 0)
		roofed = mini(roofed, Time.get_ticks_usec() - t0)
	print("span cost: chunk bare %d us, with a 12x10 slab %d us (+%.0f%%)" % [bare, roofed, 100.0 * (roofed - bare) / bare])
	lt(float(roofed), float(bare) * 2.2, "a slab costs its chunk no more than a second land")


## A HALL'S CHUNK COSTS LITTLE (docs/ABOVE.md S3's target): a chunk wholly under
## one level mass is drawn as one top, underside and section, not sampled
## point by point. Measured +13% (10.1 to 11.5 ms, best of five); it was +204%
## before, and +35% with only the flat stretches merged.
func test_a_chunk_wholly_under_a_roof_costs_little_more() -> void:
	var bare_w := F.flat_world(96, Ground.GRASS, Country.COAST, GROUND)
	var roof_w := F.flat_world(96, Ground.GRASS, Country.COAST, GROUND)
	for y in 96:
		for x in 96:
			roof_w.set_overhead(x, y, UNDER, OVER)
	var bm := TerrainMesher.new(bare_w)
	var rm := TerrainMesher.new(roof_w)
	var bare := 1 << 40
	var roofed := 1 << 40
	for i in 5:
		var t0 := Time.get_ticks_usec()
		bm.build_arrays(1, 1)
		bare = mini(bare, Time.get_ticks_usec() - t0)
		t0 = Time.get_ticks_usec()
		rm.build_arrays(1, 1)
		roofed = mini(roofed, Time.get_ticks_usec() - t0)
	print("span cost: a chunk wholly roofed %d us, bare %d us (+%.0f%%)" % [roofed, bare, 100.0 * (roofed - bare) / bare])
	lt(float(roofed), float(bare) * 1.3, "a roofed hall's chunk costs under a third more than bare")


## THE TOP GROWS A LITTLE (Decor, SPAN_DECOR): pieces of the landscape's own
## decor stand on a slab's level top, only over its tiles, and none of them at
## its warped edge; the ground's own decor is the same with or without it.
func test_a_slab_top_grows_a_little_and_the_ground_is_unchanged() -> void:
	var w := _roofed()
	var ch := TerrainMesher.new(w).build_arrays(0, 0)
	var parts := Decor.new(w).build_parts(ch)
	var solid: Array = parts[0]
	var on_top := 0
	var over_y := OVER * WorldData.STEP
	if not solid.is_empty():
		for v: Vector3 in (solid[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.y > over_y - 0.05:
				on_top += 1
				# Rooted on the inner tiles (11..20, 11..18); a piece reaches a few
				# tenths past its root.
				check(v.x > 10.5 and v.x < 21.5 and v.z > 10.5 and v.z < 19.5, "on the slab's inner tiles (%.2f, %.2f)" % [v.x, v.z])
	gt(float(on_top), 50.0, "the top grows something (%d vertices)" % on_top)
	var bare := F.flat_world(64, Ground.GRASS, Country.COAST, GROUND)
	var bch := TerrainMesher.new(bare).build_arrays(0, 0)
	var bparts := Decor.new(bare).build_parts(bch)
	eq((parts[1] as Array).size() > 0, (bparts[1] as Array).size() > 0, "the grass part is laid alike")
	if not (bparts[1] as Array).is_empty():
		eq((parts[1][Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (bparts[1][Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "and it is the same grass")
