extends TestCase
## The whole map in dev mode (owner, 2026-09-18).
##
## The failure worth failing on is not "the map is blank" — you would see that.
## It is a cheat that quietly becomes part of somebody's game: a reveal written
## into the mask is saved, is counted as progress, and cannot be undone, so an
## afternoon spent reading a seed costs the player the edge of their known world.
## Everything below holds the line between what is SHOWN and what was WALKED.


func _walked() -> UiExplored:
	var e := UiExplored.new(64)
	e.reveal(Vector2i(10, 10), UiExplored.RADIUS)
	return e


func test_a_revealed_map_shows_ground_nobody_has_walked() -> void:
	var e := _walked()
	check(not e.seen(50, 50), "the far corner is unwalked to begin with")
	e.revealed = true
	check(e.seen(50, 50), "and the reveal shows it")
	eq(e.value(50, 50), 255, "fully, not as a rim")
	check(not e.seen(-1, 0), "and never outside the world, which would read a byte that is not there")


func test_the_reveal_is_shown_and_never_walked() -> void:
	# THE ONE THAT MATTERS. The mask is what the save carries and what the pause
	# page counts, so a reveal that writes into it is a cheat the player keeps.
	var e := _walked()
	var before := e.mask.duplicate()
	var share := e.fraction()
	e.reveal_all(_world())
	eq(e.mask, before, "not one byte of what was walked has changed")
	eq(e.fraction(), share, "so the share on the pause page still says what was really seen")
	lt(share, 0.2, "and that share is still small, which is the whole point")


func test_it_goes_back_exactly() -> void:
	# A dev who reveals the map to read a seed has to be able to put the fog back,
	# or the next thing they test is a map they have already spoiled.
	var e := _walked()
	e.reveal_all(_world())
	e.revealed = false
	check(not e.seen(50, 50), "the far corner is unknown again")
	check(e.seen(10, 10), "and what was walked is still walked")


func test_a_revealed_map_frames_the_island_and_not_the_sea() -> void:
	# A world is an island in a square of water. Fitting the square draws the
	# island as a stamp in the middle of nothing, which is a worse picture than
	# the one being replaced.
	var w := _world()
	var e := UiExplored.new(w.size)
	e.reveal_all(w)
	var b := e.shown_bounds()
	gt(float(b.size.x), 0.0, "there is a box")
	lt(float(b.size.x), float(w.size), "narrower than the whole square")
	# Every tile of land is inside it, which is what makes it the island's box.
	for y in range(0, w.size, 7):
		for x in range(0, w.size, 7):
			if w.level_at(x, y) > 0:
				check(b.has_point(Vector2i(x, y)), "land at %d,%d is on the map" % [x, y])


func test_the_shown_mask_is_what_the_map_draws_from() -> void:
	var e := _walked()
	eq(e.shown_mask(), e.mask, "as walked, the map draws the walked mask itself")
	e.revealed = true
	var shown := e.shown_mask()
	eq(shown.size(), e.mask.size(), "revealed, it is the same shape")
	for v in shown:
		eq(v, 255, "and every tile of it is known")


func _world() -> WorldData:
	return BootWorld.world(4, 128)
