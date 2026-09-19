extends TestCase
## Walking somebody home (`src/core/taken/escort.gd`).
##
## The two things most worth failing on are the two that would make the words
## written for this a lie: a destination that moves while somebody walks toward
## it, and a rescue that cannot be lost.


func _person(home: int = -1, home_name: String = "Oyster Row") -> Taken.TakenPerson:
	var t := Taken.new()
	var p := t.take(1, "", home, home_name, 7, 0.0)
	var _f := t.free_region(7)
	return p


func test_they_walk_to_their_own_roof_when_it_still_stands() -> void:
	var holdings := [
		{"index": 0, "pos": Vector2(10, 10), "standing": true},
		{"index": 3, "pos": Vector2(90, 90), "standing": true},
	]
	eq(Escort.destination(holdings, [], _person(3)), Vector2(90, 90), "their own, not the nearest")


func test_a_razed_roof_sends_them_to_the_nearest_that_stands() -> void:
	var holdings := [
		{"index": 3, "pos": Vector2(90, 90), "standing": false},
		{"index": 0, "pos": Vector2(10, 10), "standing": true},
	]
	eq(Escort.destination(holdings, [], _person(3)), Vector2(10, 10), "somewhere with a roof on it")


func test_the_village_they_came_out_of_is_the_last_rung_and_the_one_that_matters() -> void:
	# WITHOUT THIS THE WHOLE FEATURE IS UNREACHABLE. A person the world starts out
	# already holding has no holding index at all (`--carried` files -1 and a
	# village NAME), and a fresh game has no player holdings to fall back to — so
	# every rung above this one is empty in exactly the world anybody would test
	# the rescue in.
	var villages := [{"name": "Tidesend", "pos": Vector2(5, 5)}, {"name": "Oyster Row", "pos": Vector2(40, 12)}]
	eq(Escort.destination([], villages, _person(-1)), Vector2(40, 12), "back to the village that lost them")
	eq(Escort.destination([], villages, _person(-1, "Nowhere")), Vector2.INF,
		"and a village this island does not have is nowhere, not the wrong village")


func test_nowhere_to_take_them_is_nowhere_and_never_a_guess() -> void:
	# The same rule the yard keeps: never raise what cannot be answered. A walk
	# offered with no destination is a promise the game cannot keep.
	eq(Escort.destination([], [], _person(-1)), Vector2.INF, "no roof anywhere")
	eq(Escort.destination([{"index": 0, "pos": Vector2(1, 1), "standing": false}], [], _person(0)),
		Vector2.INF, "a razed roof and nothing else is still nowhere")
	eq(Escort.destination([], [], null), Vector2.INF, "and nobody at all never crashes a caller")


func test_the_destination_is_fixed_when_the_walk_is_accepted() -> void:
	# If the roof they were walking toward is razed on the way, that happened to
	# them and there are words for it. A target that quietly slides to the next
	# village makes the walk mean nothing.
	var t := Taken.new()
	var p := t.take(1, "", 3, "Oyster Row", 7, 0.0)
	var _f := t.free_region(7)
	t.walk(p, Vector2(90, 90))
	eq(p.home_at, Vector2(90, 90), "written down once")
	check(p.walking, "and they are on the road")
	eq(t.walking_now().size(), 1, "which the record can be asked about")


func test_a_rescue_can_be_lost_and_the_record_is_the_only_witness() -> void:
	var t := Taken.new()
	var p := t.take(1, "", -1, "Oyster Row", 7, 0.0)
	var _f := t.free_region(7)
	t.walk(p, Vector2(40, 12))
	t.lose(p, Vector2(22, 31), &"hunter")
	check(p.lost, "they did not get there")
	check(not p.walking, "and are not still walking")
	check(not p.arrived, "and never arrived")
	check(p.freed, "but they DID come out of the yard, which is a separate fact")
	eq(p.at, Vector2(22, 31), "the tile it happened on, because nobody else saw it")
	eq(p.lost_to, &"hunter", "and what took them, which is a different thing to be told")
	eq(t.waiting_in(7).size(), 0, "they are not waiting to be walked again")


func test_a_freed_person_nobody_walked_is_still_exactly_what_it_used_to_mean() -> void:
	# The story's existing lines key on `freed`. Adding a walk must not quietly
	# change what that word means about the people already written about.
	var t := Taken.new()
	var p := t.take(1, "", -1, "Oyster Row", 7, 0.0)
	var _f := t.free_region(7)
	check(p.freed, "out of the yard")
	check(not p.walking and not p.arrived and not p.lost, "and nothing has happened since")
	eq(t.freed_in(7).size(), 1, "so the thanks still finds them")
	eq(t.waiting_in(7).size(), 1, "and so does the offer of a walk")


func test_they_are_never_lost_while_he_can_still_see_them() -> void:
	# LOSE_TILES is past the frame's own reach on purpose: somebody vanishing on
	# screen reads as a bug however correct the rule behind it is.
	var him := Vector2(50, 50)
	var near := him + Vector2(Escort.LOSE_TILES - 1.0, 0.0)
	eq(Escort.read(near, Vector2(900, 900), him, 999.0), Escort.WALKING, "in reach is walking, however long")
	gt(Escort.LOSE_TILES, 18.0, "and the bar is past what a frame shows tall")


func test_falling_behind_is_a_grace_and_not_a_line() -> void:
	var him := Vector2(50, 50)
	var far := him + Vector2(Escort.LOSE_TILES + 5.0, 0.0)
	eq(Escort.read(far, Vector2(900, 900), him, 0.0), Escort.BEHIND, "too far, but not yet lost")
	eq(Escort.read(far, Vector2(900, 900), him, Escort.LOSE_SECONDS), Escort.LOST, "and then lost")
	# The clock only runs while they are actually behind, and it resets when they
	# are not — or a walk with one bad corner in it is doomed from that corner on.
	eq(Escort.behind_after(far, him, 3.0, 0.5), 3.5, "it counts up while they are behind")
	eq(Escort.behind_after(him, him, 3.0, 0.5), 0.0, "and starts again the moment they are not")


func test_arriving_beats_everything() -> void:
	var door := Vector2(40, 12)
	# Even abandoned at the door, somebody standing on their own step is home.
	eq(Escort.read(door, door, Vector2(500, 500), 999.0), Escort.HOME, "home is home")
	var t := Taken.new()
	var p := t.take(1, "", -1, "Oyster Row", 7, 0.0)
	var _f := t.free_region(7)
	t.walk(p, door)
	t.arrive(p)
	check(p.arrived and not p.walking and not p.lost, "and the record says so once")


func test_it_survives_a_save_with_places_in_it() -> void:
	# `at` and `home_at` are Vector2.INF until something happens at a real tile,
	# and INF is the one number JSON cannot carry.
	var t := Taken.new()
	var a := t.take(1, "Ruth", -1, "Oyster Row", 7, 100.0)
	var b := t.take(2, "", -1, "Oyster Row", 7, 120.0)
	var _f := t.free_region(7)
	t.walk(a, Vector2(40, 12))
	t.lose(b, Vector2(22.5, 31.25), &"hunter")
	var back := Taken.new()
	back.load_from(JSON.parse_string(JSON.stringify(t.save())))
	eq(back.people.size(), 2, "both come back")
	eq(back.people[0].home_at, Vector2(40, 12), "the door they were walking to")
	check(not back.people[0].at.is_finite(), "and nothing happened to them, still")
	eq(back.people[1].at, Vector2(22.5, 31.25), "the tile it happened on, to the fraction")
	eq(back.people[1].lost_to, &"hunter", "and what took them")
	eq(back.walking_now().size(), 1, "one still on the road")
