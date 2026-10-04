extends TestCase
## A WHOLE ISLAND'S WALLS STAMPED A CELL AT A TIME stop the same bodies as when
## they were stamped at once (WorldQuery.set_blocks_by_cell): every tile holds the
## same circles, beside another owner's, and again after the set changes with
## some cells already stamped. The ruins of seed 7 at 512.


func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.x < q.x or (p.x == q.x and (p.y < q.y or (p.y == q.y and p.z < q.z))))
	return out


func _same_everywhere(w: WorldData, eager: WorldQuery, lazy: WorldQuery, what: String) -> void:
	var differ := 0
	var held := 0
	for y in w.size:
		for x in w.size:
			var p := Vector2(x + 0.5, y + 0.5)
			var a := eager.blocks_at(p)
			held += a.size()
			if _sorted(a) != _sorted(lazy.blocks_at(p)):
				differ += 1
	gt(float(held), 0.0, "%s: there are walls to compare (%d tile entries)" % [what, held])
	eq(differ, 0, "%s: every tile holds the same walls" % what)


func test_cells_stamped_on_first_ask_hold_what_an_eager_stamp_does() -> void:
	var w := WorldGen.generate(7, 512)
	var ruins := RuinWalls.of_world(w)
	var eager := WorldQuery.new(w)
	var lazy := WorldQuery.new(w)
	# Another owner's walls beside them, set before and after.
	var other: Array[Vector3] = []
	for k in 40:
		other.append(ruins[(k * 97) % ruins.size()] + Vector3(0.7, -0.4, 0.0))
	eager.set_blocks(&"landmarks", other)
	lazy.set_blocks(&"landmarks", other)
	eager.set_blocks(&"ruins", ruins)
	lazy.set_blocks_by_cell(&"ruins", ruins)
	_same_everywhere(w, eager, lazy, "as set")
	# A third of them fall, with every cell of the lazy query already stamped.
	var standing: Array[Vector3] = []
	for i in ruins.size():
		if i % 3 != 0:
			standing.append(ruins[i])
	eager.set_blocks(&"ruins", standing)
	lazy.set_blocks_by_cell(&"ruins", standing)
	_same_everywhere(w, eager, lazy, "after a third fell")


func test_a_cell_nobody_asks_about_is_never_stamped() -> void:
	var w := WorldGen.generate(7, 512)
	var lazy := WorldQuery.new(w)
	lazy.set_blocks_by_cell(&"ruins", RuinWalls.of_world(w))
	eq(lazy.get(&"_blocks").size(), 0, "set, nothing is stamped yet")
	var c: Vector3 = RuinWalls.of_world(w)[0]
	gt(float(lazy.blocks_at(Vector2(c.x, c.y)).size()), 0.0, "asked at a wall, its cell is stamped")
	lt(float(lazy.get(&"_blocks").size()), float(WorldQuery.BLOCK_CELL * WorldQuery.BLOCK_CELL + 1), "and only its cell's tiles")
