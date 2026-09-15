extends TestCase
## Heard before seen: a machine at work is audible to its racket, the player is
## told once when it is heard and not in view, and never more than one such
## line in a stretch however many are about.

const F := preload("res://tests/fight/fixture.gd")


func test_heard_to_its_racket_and_further_with_an_aerial() -> void:
	var sim := F.make_sim(F.flat_world(96), Vector2(40.5, 40.5))
	var h := sim.add_mob(&"harvester", Vector2(40.5 + 21.0, 40.5))
	check(Racket.audible(h, sim.hero.pos), "22 tiles of racket")
	h.pos = Vector2(40.5 + 24.0, 40.5)
	check(not Racket.audible(h, sim.hero.pos))
	check(Racket.audible(h, sim.hero.pos, true), "an aerial hears 4 further")
	var clerk := sim.add_mob(&"clerk", Vector2(42.5, 40.5))
	check(not Racket.audible(clerk, sim.hero.pos), "a clerk makes no noise at all")
	var dog := sim.add_mob(&"dog.yard", Vector2(41.5, 40.5))
	check(not Racket.audible(dog, sim.hero.pos), "animals are not machines at work")


func test_told_once_only_when_out_of_sight() -> void:
	var sim := F.make_sim(F.flat_world(96), Vector2(40.5, 40.5))
	var h := sim.add_mob(&"harvester", Vector2(55.5, 40.5))
	check(not Racket.should_tell(h, sim.hero.pos, true, false, 1e6, -1e6), "in view: nothing to say")
	check(Racket.should_tell(h, sim.hero.pos, false, false, 1e6, -1e6), "heard, unseen")
	h.heard_told = true
	check(not Racket.should_tell(h, sim.hero.pos, false, false, 1e6, -1e6), "and only once")
	var other := sim.add_mob(&"hauler", Vector2(55.5, 44.5))
	check(not Racket.should_tell(other, sim.hero.pos, false, false, 1000.0, 0.0), "not straight after another")
	check(Racket.line_for(other) != "", "a line to say")
	check(Racket.line_for(other, sim.hero.pos).contains("east"), "and it says which way: %s" % Racket.line_for(other, sim.hero.pos))
	eq(Racket.bearing_words(Vector2.ZERO, Vector2(0, -5)), "north", "y grows south")
	eq(Racket.bearing_words(Vector2.ZERO, Vector2(-3, 3)), "south-west")
