extends TestCase
## Valleys are a section's to carve (streamed worldgen S4g). The valley field is
## capped (`GenWater.VALLEY_CAP`), so a section's own tiles are carved from what
## lies within `GenWater.valley_window` of them exactly as the whole world
## carves them -- from the same elevation, rivers and their beds.
##
## What it can and cannot see: with the reach cut to 0 (two tiles each side) nine
## tiles of seed 42's differ, so it bites. The reach it holds (78 half-cells) is
## the proven bound, not the measured one -- valleys at 512 lie within 22 tiles
## of their river. And the cap it cannot show red on these worlds: uncapped, no
## far value happens to reach a tile's spread; it is there so the bound holds at
## all, and it moves no world (level and parity unchanged).

const SIZE := 512
const SEEDS: Array[int] = [1, 42, 90210]
## Cores tiling the whole world, so every valley near any section's edge is
## carved by a section that cannot see all of it.
const CORE := 64


func test_a_section_carves_its_valleys_as_the_whole_world_does() -> void:
	for s in SEEDS:
		GenWater.keeping = true
		WorldGen.plan(s, SIZE)
		GenWater.keeping = false
		var b: Dictionary = GenWater.before
		GenWater.before = {}
		check(not b.is_empty(), "seed %d: the valleys' inputs were kept" % s)
		if b.is_empty():
			continue
		var before_elev: PackedFloat32Array = b.elev
		var whole: PackedFloat32Array = GenFields.snapshot(before_elev)
		GenWater.carve(whole, b.water, b.land, b.river_e, b.cost, b.cw, SIZE, Rect2i(0, 0, SIZE, SIZE))
		var carved := 0
		for i in whole.size():
			if whole[i] != before_elev[i]:
				carved += 1
		gt(carved, 500, "seed %d: the rivers carved valleys (%d tiles)" % [s, carved])
		var bad_all := 0
		for gy in SIZE / CORE:
			for gx in SIZE / CORE:
				var core := Rect2i(gx * CORE, gy * CORE, CORE, CORE)
				var part: PackedFloat32Array = GenFields.snapshot(before_elev)
				GenWater.carve(part, b.water, b.land, b.river_e, b.cost, b.cw, SIZE, core)
				for y in core.size.y:
					for x in core.size.x:
						var i := (core.position.y + y) * SIZE + core.position.x + x
						if part[i] != whole[i]:
							bad_all += 1
		eq(bad_all, 0, "seed %d: every section carves its valleys as the whole world does" % s)
