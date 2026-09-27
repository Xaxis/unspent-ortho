extends TestCase
## THE HUSH'S RINGS (HushSites; docs/HUSH.md H0): a circle of stones in a
## landscape that declares `hush` is a ring, its centre where the stones face
## and its radius theirs; a lone stone is no ring, and a circle anywhere else
## is none of the hush's.

const F := preload("res://tests/fight/fixture.gd")


func _crags() -> int:
	return BiomeRegistry.index_of(&"the_crags")


## Stones round `centre`, each facing it, as GenScatter lays a circle.
func _circle(w: WorldData, centre: Vector2, n: int, radius: float) -> void:
	for k in n:
		var q := centre + Vector2.from_angle(float(k) / n * TAU + 0.05 * sin(k)) * radius
		var st := WorldProp.new(w.next_id(), PropKind.STANDING_STONE, q, (centre - q).angle(), 0.6)
		w.add_prop(st)


func _world() -> WorldData:
	var w := F.flat_world(96, Ground.MOSS, _crags(), 2)
	for y in range(0, 96):
		for x in range(60, 96):
			w.country[y * 96 + x] = Country.COAST
	_circle(w, Vector2(30.3, 30.7), 8, 3.7)
	# Stones standing alone and in a pair, as the crags stand them too: two
	# stones' facing lines meet somewhere, and that is still no ring.
	w.add_prop(WorldProp.new(w.next_id(), PropKind.STANDING_STONE, Vector2(45.5, 30.5), 0.0, 0.6))
	w.add_prop(WorldProp.new(w.next_id(), PropKind.STANDING_STONE, Vector2(47.5, 31.0), 2.0, 0.6))
	# A circle on the coast, which is no hush landscape.
	_circle(w, Vector2(75.5, 30.5), 8, 3.5)
	return w


func test_the_crags_declare_the_hush_and_nothing_else_does() -> void:
	for d: BiomeDef in BiomeRegistry.all():
		eq(d.hush, d.id == &"the_crags", "%s's hush" % d.id)


func test_a_circle_of_stones_is_a_ring_with_its_centre_and_radius() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	var rings := HushSites.near(w, q, Vector2(32.0, 32.0), 20.0)
	eq(rings.size(), 1, "one ring near")
	var r: HushSites.Ring = rings[0]
	lt(r.centre.distance_to(Vector2(30.3, 30.7)), 0.15, "its centre where the stones face (%s)" % r.centre)
	lt(absf(r.radius - 3.7), 0.15, "its radius theirs (%.2f)" % r.radius)
	eq(r.stones.size(), 8, "all its stones")
	check(HushSites.inside(r, Vector2(31.0, 31.0)) and not HushSites.inside(r, Vector2(36.0, 31.0)), "inside is within the stones")


func test_a_pair_of_stones_and_a_circle_elsewhere_are_no_ring() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	eq(HushSites.near(w, q, Vector2(46.5, 30.5), 3.0).size(), 0, "a pair of stones is no ring")
	eq(HushSites.near(w, q, Vector2(75.5, 30.5), 10.0).size(), 0, "a circle on the coast is none of the hush's")
	var far := HushSites.nearest(w, q, Vector2(50.0, 50.0), 80.0)
	check(far != null and far.centre.distance_to(Vector2(30.3, 30.7)) < 0.2, "the nearest ring is the crags' own")
