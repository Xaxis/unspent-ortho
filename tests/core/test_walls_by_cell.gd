extends TestCase
## A WHOLE ISLAND'S WALLS MADE A CELL AT A TIME stop the same bodies as when they
## are all stamped at once (WorldQuery, PropWalls): every tile holds exactly the
## circles an eager stamp of every walled prop would put there, whichever cell
## was asked first, and again after some of them fall with cells already made.
## Seeds 1, 3 and 7 at 512: seed 7 alone never lays a wall whose own tile stands
## a whole tile past its prop's reach, and filing by the reach alone missed it.


func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.x < q.x or (p.x == q.x and (p.y < q.y or (p.y == q.y and p.z < q.z))))
	return out


## Every tile's circles as `_stamp` lays them, for every standing walled prop.
func _eager(w: WorldData) -> Dictionary:
	var out := {}
	var t := w.table
	for row in t.size():
		if not PropWalls.walled(int(t.kind[row])):
			continue
		for c: Vector3 in PropWalls.of_row(w, row):
			var r := ceili(c.z + WorldQuery.BLOCK_SLACK)
			for ty in range(maxi(0, floori(c.y) - r), mini(w.size - 1, floori(c.y) + r) + 1):
				for tx in range(maxi(0, floori(c.x) - r), mini(w.size - 1, floori(c.x) + r) + 1):
					var k := ty * w.size + tx
					if not out.has(k):
						out[k] = []
					(out[k] as Array).append(c)
	return out


## Asked tile by tile in the order given; how many tiles differ from `want`.
func _differ(w: WorldData, q: WorldQuery, want: Dictionary, backwards: bool) -> int:
	var n := 0
	for i in w.size * w.size:
		var k := (w.size * w.size - 1 - i) if backwards else i
		var got := q.blocks_at(Vector2(k % w.size + 0.5, k / w.size + 0.5))
		if _sorted(got) != _sorted(want.get(k, [])):
			n += 1
	return n


func test_cells_made_on_first_ask_hold_what_an_eager_stamp_does() -> void:
	for s: int in [1, 3]:
		var other := WorldGen.generate(s, 512)
		eq(_differ(other, WorldQuery.new(other), _eager(other), false), 0, "seed %d: every tile holds the eager walls" % s)
	var w := WorldGen.generate(7, 512)
	var want := _eager(w)
	var held := 0
	for k: int in want:
		held += (want[k] as Array).size()
	gt(float(held), 0.0, "there are walls to compare (%d tile entries)" % held)
	var forward := WorldQuery.new(w)
	var backward := WorldQuery.new(w)
	eq(_differ(w, forward, want, false), 0, "asked from the first tile on, every tile holds the eager walls")
	eq(_differ(w, backward, want, true), 0, "asked from the last tile back, the same")
	# A third of the walled props fall, with every cell of `forward` already made.
	var t := w.table
	var walled := 0
	for row in t.size():
		if PropWalls.walled(int(t.kind[row])):
			if walled % 3 == 0:
				w.depleted[t.id[row]] = INF
			walled += 1
	forward.walls_changed()
	backward.walls_changed()
	want = _eager(w)
	eq(_differ(w, forward, want, true), 0, "after a third fell, asked backwards, the standing walls")
	eq(_differ(w, backward, want, false), 0, "and asked forwards, the same")


func test_a_cell_nobody_asks_about_is_never_made() -> void:
	var w := WorldGen.generate(7, 512)
	var lazy := WorldQuery.new(w)
	eq(lazy.get(&"_blocks").size(), 0, "built, nothing is stamped yet")
	var t := w.table
	for row in t.size():
		if PropWalls.walled(int(t.kind[row])):
			var c: Vector3 = PropWalls.of_row(w, row)[0]
			gt(float(lazy.blocks_at(Vector2(c.x, c.y)).size()), 0.0, "asked at a wall, its cell is made")
			lt(float(lazy.get(&"_blocks").size()), float(WorldQuery.BLOCK_CELL * WorldQuery.BLOCK_CELL + 1), "and only its cell's tiles")
			return
	check(false, "seed 7 has a walled prop")
