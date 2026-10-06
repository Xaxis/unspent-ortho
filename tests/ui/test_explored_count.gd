extends TestCase
## THE SHARE OF THE LAND SEEN IS KEPT, NOT COUNTED. The pause page reads
## `UiExplored.fraction()` every time it opens, and counting the mask is a pass
## over 3.4M bytes at 1840: 0.6 s, every time. So `reveal` keeps the count as it
## writes, and `load_mask` counts a save's mask once, in words. The count must be
## the mask's own, whichever way it was written.


## The count the long way: what fraction() used to do.
static func _counted(e: UiExplored) -> int:
	var n := 0
	for v in e.mask:
		if v >= UiExplored.SEEN:
			n += 1
	return n


func test_a_walk_keeps_the_count_the_mask_has() -> void:
	var e := UiExplored.new(97)
	# Overlapping discs, discs cut by every edge, and rims laid over rims.
	for i in 60:
		var c := Vector2i(roundi(Rng.hash01(5, i, 1) * 110.0) - 6, roundi(Rng.hash01(5, i, 2) * 110.0) - 6)
		e.reveal(c, UiExplored.RADIUS if i % 3 else 4)
		eq(roundi(e.fraction() * e.mask.size()), _counted(e), "after reveal %d at %s" % [i, str(c)])
	gt(e.fraction(), 0.2, "the walk saw a good share")


func test_a_wander_keeps_it_too() -> void:
	var w := BootWorld.world(4, 128)
	var e := UiExplored.new(w.size)
	e.wander(w, w.spawn, 400, 9)
	eq(roundi(e.fraction() * e.mask.size()), _counted(e), "the wander's count is the mask's")


func test_a_loaded_mask_is_counted() -> void:
	# Every byte value, at a size that is not a whole number of words, so the
	# tail past the last word is counted too.
	for n: int in [0, 1, 7, 8, 9, 1021, 4099]:
		var m := PackedByteArray()
		m.resize(n)
		for i in n:
			m[i] = int(Rng.hash01(n, i, 3) * 256.0) & 0xFF
		eq(UiExplored.count_seen(m), _count(m), "%d bytes" % n)
	var e := UiExplored.new(61)
	e.reveal(Vector2i(30, 30), UiExplored.RADIUS)
	var walked := e.mask.duplicate()
	var f := UiExplored.new(61)
	f.load_mask(walked)
	eq(f.fraction(), e.fraction(), "a loaded mask says what the walked one did")
	f.reveal(Vector2i(35, 30), UiExplored.RADIUS)
	eq(roundi(f.fraction() * f.mask.size()), _counted(f), "and walking on from it keeps counting")


func test_all_seen_and_none_seen() -> void:
	var m := PackedByteArray()
	m.resize(1840 * 1840)
	eq(UiExplored.count_seen(m), 0, "nothing")
	m.fill(255)
	eq(UiExplored.count_seen(m), m.size(), "everything, every lane full")
	m.fill(127)
	eq(UiExplored.count_seen(m), 0, "just under the line")
	m.fill(128)
	eq(UiExplored.count_seen(m), m.size(), "just on it")


func test_asking_the_share_costs_nothing() -> void:
	var e := UiExplored.new(1840)
	for i in 400:
		e.reveal(Vector2i(200 + i * 3, 300 + (i * 7) % 900), UiExplored.RADIUS)
	var asked := TestCase.best_of(20, func() -> void: e.fraction())
	print("  the share asked at 1840: %.0f us" % asked)
	cost_lt(asked, 50.0, "the pause page's share is kept, not counted (us)")


func test_a_save_is_counted_in_words() -> void:
	var e := UiExplored.new(1840)
	for i in 400:
		e.reveal(Vector2i(200 + i * 3, 300 + (i * 7) % 900), UiExplored.RADIUS)
	var m := e.mask.duplicate()
	var f := UiExplored.new(1840)
	var loaded := TestCase.best_of(3, func() -> void: f.load_mask(m))
	eq(f.fraction(), e.fraction(), "counted right")
	print("  a 1840 mask counted on load: %.1f ms" % (loaded / 1000.0))
	cost_lt(loaded / 1000.0, 60.0, "a save's mask counted on load (ms)")


static func _count(m: PackedByteArray) -> int:
	var n := 0
	for v in m:
		if v >= UiExplored.SEEN:
			n += 1
	return n
