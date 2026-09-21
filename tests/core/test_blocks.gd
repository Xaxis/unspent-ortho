extends TestCase
## What stops a body, and what it costs to change your mind about it.
##
## `WorldQuery.set_blocks(owner, circles)` replaces one owner's mass whole. It
## used to clear the tile grid and restamp EVERY owner to do it, so a chapter
## turning over in `24_holds` restamped the landmarks, the works yards and the
## holdings as well — measured at 6.8 ms of that system's 7.4 ms worst frame,
## all of it spent on circles that had not moved.
##
## Asserted on `blocks_at`, which is what `set_blocks` actually feeds: neither
## `standable` nor `passable` consults the block grid at all (only `move_body`
## does, when it slides a body round a wall), so a test written against those
## would have passed whatever this did.
##
## AND THE COST IS ASSERTED AS A PROPERTY, NOT A MILLISECOND. A millisecond is a
## claim about one laptop on one night, and this repository has spent an evening
## on numbers whose conditions were not written down. The claim that matters is
## structural: setting ONE owner must not get dearer because OTHER owners exist.
## That survives being read on another machine, and it is the exact thing that
## regressed.


func _query(size: int) -> WorldQuery:
	return WorldQuery.new(WorldData.new(1, size))


func _ring(n: int, at: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n:
		out.append(Vector3(at + float(i) * 3.0, at, 1.5))
	return out


func test_a_wall_is_stamped_where_it_stands_and_taking_it_away_clears_the_tile() -> void:
	var q := _query(64)
	var p := Vector2(20.5, 20.5)
	check(q.blocks_at(p).is_empty(), "open ground before anything is put down")
	q.set_blocks(&"holds", [Vector3(20.5, 20.5, 1.5)] as Array[Vector3])
	eq(q.blocks_at(p).size(), 1, "a wall put there is stamped in its tile")
	q.set_blocks(&"holds", [] as Array[Vector3])
	check(q.blocks_at(p).is_empty(), "and taking it away leaves nothing behind")


## The bug an incremental stamp could introduce, and the reason `_unstamp` walks
## the same tiles rather than clearing: one owner's change must not erase
## another's mass, and two owners overlapping must both survive one leaving.
func test_one_owner_changing_leaves_every_other_owner_standing() -> void:
	var q := _query(64)
	var shared := Vector2(10.5, 10.5)
	q.set_blocks(&"landmarks", [Vector3(10.5, 10.5, 1.5)] as Array[Vector3])
	q.set_blocks(&"works", [Vector3(10.5, 10.5, 1.5)] as Array[Vector3])
	q.set_blocks(&"holds", [Vector3(30.5, 30.5, 1.5)] as Array[Vector3])
	eq(q.blocks_at(shared).size(), 2, "two owners on one tile are both stamped")
	q.set_blocks(&"holds", [Vector3(40.5, 40.5, 1.5)] as Array[Vector3])
	eq(q.blocks_at(shared).size(), 2, "a third owner moving does not disturb them")
	check(q.blocks_at(Vector2(30.5, 30.5)).is_empty(), "its old wall is gone")
	eq(q.blocks_at(Vector2(40.5, 40.5)).size(), 1, "and its new one is there")
	q.set_blocks(&"works", [] as Array[Vector3])
	eq(q.blocks_at(shared).size(), 1, "one of two overlapping owners leaving keeps the other")
	q.set_blocks(&"landmarks", [] as Array[Vector3])
	check(q.blocks_at(shared).is_empty(), "and the last one leaving clears the tile")


## Setting one owner is O(that owner), not O(everybody). A RATIO of two
## measurements taken in the same process, so load can only make both arms
## slower, and `cost_lt` declines to judge at all on a box too busy to measure.
func test_setting_one_owner_does_not_get_dearer_because_others_exist() -> void:
	var lonely := _query(256)
	var crowded := _query(256)
	for i in 12:
		crowded.set_blocks(StringName("other_%d" % i), _ring(24, 20.0 + float(i) * 4.0))
	var mine := _ring(24, 100.0)
	var alone := best_of(8, func() -> void: lonely.set_blocks(&"holds", mine)) / 1000.0
	var among := best_of(8, func() -> void: crowded.set_blocks(&"holds", mine)) / 1000.0
	print("set_blocks: alone %.3f ms, with 12 other owners %.3f ms (%.2fx)"
		% [alone, among, among / maxf(alone, 0.0001)])
	# The other owners hold 288 circles between them, which the old code restamped
	# on every call. Anything near 1x proves they are no longer touched.
	cost_lt(among, maxf(alone, 0.01) * 2.5, "twelve other owners do not make this owner dearer")
