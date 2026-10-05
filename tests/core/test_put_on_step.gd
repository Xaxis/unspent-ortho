extends TestCase
## A SOLID ON A STEP (GenWorks.put_on_step): it stands where its tile is no more
## than one level off any of its four neighbours, across that step, or on the
## nearest such tile of the cross round it; never on a tile a cliff of two levels
## runs past, and nowhere when every tile of the cross is one. On a stepped patch
## of moss with the survey bearing along +X.

const SIZE := 24
const Q := Vector2(12.5, 12.5)


## A patch whose level at (x, y) is `levels`, all of it moss, land and one
## landscape, with the spawn far off.
func _lay(levels: Callable) -> GenWorks.Lay:
	var w := WorldData.new(1, SIZE)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			w.level[i] = int(levels.call(x, y))
			w.ground[i] = Ground.MOSS
			w.country[i] = 1
	w.spawn = Vector2(-1000.0, -1000.0)
	var c := GenContext.new(w)
	c.land = PackedByteArray()
	c.land.resize(c.n)
	c.land.fill(1)
	var occ := PackedByteArray()
	occ.resize(c.n)
	var L := GenWorks.Lay.new(c, occ, Vector2.RIGHT)
	L.own = 1
	return L


func _tile_steep(L: GenWorks.Lay, p: Vector2) -> bool:
	var i := floori(p.y) * SIZE + floori(p.x)
	for k: int in [1, -1, SIZE, -SIZE]:
		if absi(L.w.level[i + k] - L.w.level[i]) > 1:
			return true
	return false


func test_on_a_one_level_step_it_stands_where_it_was_put() -> void:
	var L := _lay(func(x: int, _y: int) -> int: return 1 if x < 12 else 2)
	var p := GenWorks.put_on_step(L, PropKind.THEODOLITE_MAST, Q, 0.0)
	check(p != null, "a mast stands across a one-level step")
	if p != null:
		eq(p.pos, Q, "on the very tile it was put on")
	# Where `_put_footed` keeps a solid to one level, so the step's own tile refuses it.
	var L2 := _lay(func(x: int, _y: int) -> int: return 1 if x < 12 else 2)
	var f := GenWorks._put_footed(L2, PropKind.THEODOLITE_MAST, Q, 0.0, 0.0, true)
	check(f == null or f.pos != Q, "a one-level foothold is refused on the step itself")


func test_beside_a_two_level_cliff_it_takes_the_nearest_step_off_it() -> void:
	var L := _lay(func(x: int, _y: int) -> int: return 1 if x < 12 else 3)
	check(_tile_steep(L, Q), "the tile it was put on has a cliff beside it")
	var p := GenWorks.put_on_step(L, PropKind.THEODOLITE_MAST, Q, 0.0)
	check(p != null, "a mast stands near the cliff")
	if p != null:
		check(not _tile_steep(L, p.pos), "on a tile no more than a level off its neighbours (%s)" % p.pos)
		lt(p.pos.distance_to(Q), 1.6 + 0.01, "within its reach of where it was put")


func test_where_every_tile_of_the_cross_is_a_cliff_nothing_stands() -> void:
	var L := _lay(func(x: int, y: int) -> int: return 2 if (x + y) % 2 == 0 else 0)
	eq(GenWorks.put_on_step(L, PropKind.THEODOLITE_MAST, Q, 0.0), null, "every tile two levels off its neighbours: no mast")
