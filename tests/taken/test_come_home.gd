extends TestCase
## TAKEN PEOPLE COME HOME AS PEOPLE (SETTLE.md S6, docs/STORY.md's proposal on
## what the plan does with those it carries). A raid's snatcher takes a resident
## off the holding's books and the plan holds them at the region's depot. Either
## act that ends the plan there lets them out -- the yard going dark, or the
## region's keeper falling -- and whoever gets back to a holding that still
## stands is on its books again: a raid's loss is something you go and fix.

const Sx := preload("res://tests/save/save_fixture.gd")


func _game() -> Game:
	Sx.use_root("come_home")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11"])
	Sx.system(g, "30_mobs").get("coast").set("spawning", false)
	g.player.sim.clear_mobs()
	return g


## A holding with beds and one resident, and that resident carried off to the
## depot of `region`, the way 48_raids `_take_person` does it.
func _taken_from(g: Game, region: int) -> Dictionary:
	var set := Sx.system(g, "46_settlements")
	var s: Settlement = set.call("found", set.call("realm_here"), g.player.pos + Vector2(3, 0))
	s.add(StructureKind.HUT, s.centre + Vector2(1, 0))
	var who := s.take_person_id()
	s.people.append(who)
	set.call("lose_person", s, who)
	Sx.system(g, "45_taken").call("took", who, "", s.id, s.name, region)
	return {"s": s, "who": who}


func test_the_keeper_falling_lets_them_out_and_they_are_home_again() -> void:
	var g := _game()
	var taken: Taken = Sx.system(g, "45_taken").get("taken")
	var d := _taken_from(g, 5)
	var s: Settlement = d.s
	check(not s.people.has(int(d.who)), "taken, they are off the holding's books")
	eq(taken.held_in(5).size(), 1, "and held at the region's depot")
	Events.sentinel_fell.emit(5, &"", &"force")
	eq(taken.held_in(5).size(), 0, "the keeper down, the depot holds nobody")
	check(s.people.has(int(d.who)), "and they are the holding's own again")
	Sx.end(g)
	Sx.finish()


func test_the_yard_going_dark_brings_them_home_too() -> void:
	var g := _game()
	var d := _taken_from(g, 6)
	Events.works_broken.emit(6, &"")
	check((d.s as Settlement).people.has(int(d.who)), "a dark yard sends them home")
	Sx.end(g)
	Sx.finish()


func test_a_razed_holding_has_nobody_to_take_back() -> void:
	var g := _game()
	var d := _taken_from(g, 7)
	var s: Settlement = d.s
	for p in s.pieces:
		s.destroy_structure(p.id)
	Events.works_broken.emit(7, &"")
	check(not s.people.has(int(d.who)), "a holding with nothing standing takes nobody in")
	Sx.end(g)
	Sx.finish()


## Walked home by the player (`Escort`), they are on the books when the door
## shuts behind them.
func test_walked_to_the_door_they_are_on_the_books() -> void:
	var g := _game()
	var sys := Sx.system(g, "45_taken")
	var taken: Taken = sys.get("taken")
	var d := _taken_from(g, 8)
	var s: Settlement = d.s
	var t: Taken.TakenPerson = taken.free_region(8)[0]
	taken.walk(t, s.centre)
	sys.set("_led_who", t)
	sys.call("_end_walk", true, s.centre, &"")
	check(t.arrived, "they reached the door")
	check(s.people.has(int(d.who)), "and live there again")
	Sx.end(g)
	Sx.finish()
