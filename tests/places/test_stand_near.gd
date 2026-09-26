extends TestCase
## Where a staged place puts the body: the standable tile NEAREST the point it
## was asked for (`GenPlaces._stand_near`), not the first one a ring's scan
## meets. A body staged beside a thing to be reached has to be in its reach.


## Level land, sixteen tiles square, grass everywhere, and the tile `p` is in
## made water so the answer has to come from the ring round it.
static func _flat() -> WorldData:
	var w := WorldData.new(1, 16)
	for i in w.level.size():
		w.level[i] = 1
		w.ground[i] = Ground.GRASS
	return w


func test_the_body_stands_on_the_nearest_tile_not_the_first_found() -> void:
	var w := _flat()
	var p := Vector2(7.9, 7.5)
	w.ground[7 * 16 + 7] = Ground.WATER
	var at := GenPlaces._stand_near(w, p)
	eq(at, Vector2(8.5, 7.5), "the tile beside it, 0.6 off, not a corner of the ring")


func test_a_nearer_tile_one_ring_further_out_wins() -> void:
	# Ring 1 all water but its far side; ring 2's nearest side tile is nearer
	# than ring 1's far corners.
	var w := _flat()
	var p := Vector2(7.95, 7.5)
	for y in range(6, 9):
		for x in range(6, 9):
			w.ground[y * 16 + x] = Ground.WATER
	w.ground[6 * 16 + 6] = Ground.GRASS
	var at := GenPlaces._stand_near(w, p)
	eq(at, Vector2(9.5, 7.5), "two tiles east (1.55 off), not the ring-1 corner at (6.5, 6.5) (1.6 off)")
