extends TestCase
## A landscape's place (`--place=<landscape>`, GenPlaces.country_sample) is where
## a shot, a tour or a tester starts, so it has to be somewhere a thing can be set
## down: on seed 7 the green towers' was the floor of a stepped bowl where no piece
## of a holding fitted within ten tiles.


## A disc of landscape 1 in landscape 2, so only its middle is deep in it, with
## that middle a stepped bowl: level 2 and 3 alternating ring by ring out to ten
## tiles, so no tile there has four neighbours on its own level.
static func _bowl() -> WorldData:
	var w := WorldData.new(3, 128)
	for y in 128:
		for x in 128:
			var i := y * 128 + x
			var c := Vector2(x - 64, y - 64)
			w.country[i] = 1 if c.length() <= 46.0 else 2
			w.country2[i] = w.country[i]
			w.ground[i] = Ground.GRASS
			var ring := maxi(absi(x - 64), absi(y - 64))
			w.level[i] = 2 + (ring & 1) if ring <= 10 else 2
	return w


## A tile and its four neighbours flat on one level, one step of `l`, within `r`.
static func _patch_near(w: WorldData, at: Vector2, r: int) -> bool:
	var x := floori(at.x)
	var y := floori(at.y)
	var l := w.level_at(x, y)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var h := w.level_at(x + dx, y + dy)
			if absi(h - l) > 1:
				continue
			if w.level_at(x + dx - 1, y + dy) == h and w.level_at(x + dx + 1, y + dy) == h \
					and w.level_at(x + dx, y + dy - 1) == h and w.level_at(x + dx, y + dy + 1) == h:
				return true
	return false


func test_a_landscape_s_place_has_room_to_set_something_down() -> void:
	var w := _bowl()
	var at := GenPlaces.country_sample(w, 1)
	check(at.x >= 0.0, "the landscape has a place")
	eq(w.country_at(floori(at.x), floori(at.y)), 1, "in the landscape asked for")
	check(_patch_near(w, at, 4), "with flat ground a step off it within four tiles, at %s" % at)


func test_a_place_with_room_stays_where_it_was() -> void:
	var w := _bowl()
	for i in w.level.size():
		w.level[i] = 2
	var at := GenPlaces.country_sample(w, 1)
	lt(at.distance_to(Vector2(64, 64)), 4.0, "flat all through, the deepest tile still wins: %s" % at)
