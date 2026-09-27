extends TestCase
## A site's ground patch is the plan's row and a section's stamp (streamed
## worldgen S4i1). The plan keeps every patch it laid (`GenContext.site_patches`);
## a square of the world stamped from those rows, from its own copy of the fields
## a patch stops at, holds the whole world's `site_ground` exactly.
##
## Squares are odd-sized and off the section grid so they cut through patches: a
## patch whose own tile lies outside the square still paints inside it, which is
## why the owning country rides on the row.
##
## It goes red when the country is read from the square instead of the row. Row
## order it cannot show: sites stand `PLACES_APART` apart and a patch reaches ten
## tiles, so no two patches meet on these worlds; the rows keep the order laid.

const SIZE := 512
const SEEDS: Array[int] = [1, 42, 90210]
const SIDE := 97


func test_a_square_stamps_the_plan_s_patches_as_the_whole_world_laid_them() -> void:
	for s in SEEDS:
		var c := WorldGen.plan(s, SIZE)
		var rows := c.site_patches
		gt(float(rows.size() / 5), 10.0, "seed %d: patches to lay" % s)
		var straddling := 0
		var bad := 0
		var oy := -13
		while oy < SIZE:
			var ox := -13
			while ox < SIZE:
				var o := Vector2i(ox, oy)
				var out := PackedByteArray()
				out.resize(SIDE * SIDE)
				GenScatter.patch_square(rows, out, _cut(c.w.country, o), _cut(c.land, o), _cut(c.water, o),
					_cut(c.road, o), _cut(c.village, o), SIDE, o, SIZE)
				bad += _differ(out, _cut(c.site_ground, o))
				for k in range(0, rows.size(), 5):
					var p := Vector2i(int(rows[k]), int(rows[k + 1]))
					var inside := p.x >= o.x and p.y >= o.y and p.x < o.x + SIDE and p.y < o.y + SIDE
					var near := p.x + 10 >= o.x and p.y + 10 >= o.y and p.x - 10 < o.x + SIDE and p.y - 10 < o.y + SIDE
					if near and not inside:
						straddling += 1
				ox += SIDE
			oy += SIDE
		gt(float(straddling), 0.0, "seed %d: some patch paints a square its own tile is outside" % s)
		eq(bad, 0, "seed %d: every square stamps what the whole world laid (tiles differing)" % s)


static func _cut(a: PackedByteArray, o: Vector2i) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SIDE * SIDE)
	for y in SIDE:
		for x in SIDE:
			var wx := o.x + x
			var wy := o.y + y
			if wx >= 0 and wy >= 0 and wx < SIZE and wy < SIZE:
				out[y * SIDE + x] = a[wy * SIZE + wx]
	return out


static func _differ(a: PackedByteArray, b: PackedByteArray) -> int:
	var n := 0
	for i in a.size():
		if a[i] != b[i]:
			n += 1
	return n
