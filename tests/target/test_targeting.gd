extends TestCase
## Targeting (owner, 2026-09-16): what may be locked and in what order, cycling
## and sweeping, and what a body reads as. All of it is read off the simulation
## the fight already runs, so none of it can say something the world does not.


func _mob(kind: StringName, at: Vector2, id_hint: int = 0) -> MobState:
	var m := MobState.new(kind, at, id_hint)
	m.health = m.max_health
	return m


func test_what_can_be_locked_is_what_is_alive_and_within_reach() -> void:
	var near := _mob(&"runner", Vector2(3, 0))
	var far := _mob(&"runner", Vector2(26, 0))
	var dead := _mob(&"runner", Vector2(2, 0))
	dead.alive = false
	var gone := _mob(&"runner", Vector2(2, 2))
	gone.removed = true
	var list := Targeting.candidates([near, far, dead, gone], Vector2.ZERO)
	eq(list.size(), 1, "only the living body within reach")
	eq(list[0], near)
	eq(Targeting.candidates([far], Vector2.ZERO).size(), 0, "past the slate's reach it is not read")
	eq(Targeting.candidates([far], Vector2.ZERO, Targeting.LENS_REACH).size(), 1, "a scanner lens reads further")
	eq(Targeting.reach_with(true), Targeting.LENS_REACH)


func test_the_order_is_what_a_person_would_look_at_first() -> void:
	var coming := _mob(&"runner", Vector2(9, 0))
	coming.mood = MobState.CHASING
	var striking := _mob(&"runner", Vector2(6, 0))
	striking.mood = MobState.ATTACKING
	var stirred := _mob(&"runner", Vector2(2, 0))
	stirred.suspicion = 0.4
	var working := _mob(&"cutter", Vector2(1, 0))
	working.mood = MobState.WORKING
	var list := Targeting.candidates([working, stirred, coming, striking], Vector2.ZERO)
	eq(list[0], striking, "what is striking comes first, though it is not nearest")
	eq(list[1], coming)
	eq(list[2], stirred, "then what has half noticed you")
	eq(list[3], working, "a worker at its round is last")


func test_a_lock_holds_and_cycles_round() -> void:
	var a := _mob(&"runner", Vector2(2, 0))
	var b := _mob(&"runner", Vector2(4, 0))
	var c := _mob(&"runner", Vector2(6, 0))
	var list := Targeting.candidates([a, b, c], Vector2.ZERO)
	eq(Targeting.pick(list), list[0], "a fresh hold takes the first")
	eq(Targeting.pick(list, list[1]), list[1], "a lock already held stays")
	eq(Targeting.cycle(list, list[0], 1), list[1])
	eq(Targeting.cycle(list, list[2], 1), list[0], "and wraps")
	eq(Targeting.cycle(list, list[0], -1), list[2])
	var gone := _mob(&"runner", Vector2(3, 3))
	eq(Targeting.pick(list, gone), list[0], "a body that left the list is not held")
	eq(Targeting.cycle([], null, 1), null)
	eq(Targeting.pick([]), null)


func test_a_sweep_reads_a_field_not_a_census() -> void:
	var bodies: Array = []
	for i in 12:
		bodies.append(_mob(&"runner", Vector2(i + 1, 0)))
	var list := Targeting.candidates(bodies, Vector2.ZERO)
	eq(list.size(), 12)
	eq(Targeting.sweep(list).size(), Targeting.SWEEP_MOST)
	eq(Targeting.sweep(list)[0], list[0], "the front of the list")


func test_the_frame_leans_between_the_player_and_what_they_read() -> void:
	var at := Targeting.focus_between(Vector2.ZERO, Vector2(10, 0), 0.35, 3.0)
	near(at.x, 3.0, 0.01, "never further than it is allowed")
	at = Targeting.focus_between(Vector2.ZERO, Vector2(4, 0), 0.5, 9.0)
	near(at.x, 2.0, 0.01, "half way to a body close by")
	eq(Targeting.centre_of([], Vector2(5, 5)), Vector2(5, 5), "an empty field is the player")
	var a := _mob(&"runner", Vector2(0, 0))
	var b := _mob(&"runner", Vector2(4, 2))
	eq(Targeting.centre_of([a, b], Vector2.ZERO), Vector2(2, 1))


func test_a_read_says_what_the_body_is_and_what_it_can_do() -> void:
	var m := _mob(&"runner", Vector2(3, 0))
	m.health = maxi(1, m.max_health / 2)
	var r := TargetRead.of(m, Vector2.ZERO, Moment.new(), null, null, 0.0)
	eq(r.name, "runner")
	eq(r.role, "hunter")
	check(r.machine)
	near(r.distance, 3.0, 0.01)
	eq(r.health, m.health)
	check(float(r.fraction) < 0.6 and float(r.fraction) > 0.4)
	var labels := PackedStringArray()
	for s: Array in r.stats:
		labels.append(str(s[0]))
	for want: String in ["blow", "speed", "part", "senses"]:
		check(labels.has(want), "the read says its %s: %s" % [want, labels])
	check(str(r.stats[0][1]).begins_with("2 at "), "the runner's own blow, off the roster: %s" % str(r.stats[0][1]))
	eq(r.part, "back", "the runner's working part")


func test_powers_are_only_what_the_roster_declares() -> void:
	var warden := _mob(&"warden", Vector2(2, 0))
	var powers := TargetRead.powers(warden)
	check(not powers.is_empty(), "a warden does something to you")
	for p in powers:
		check(p != "", "no empty line")
	var gull := _mob(&"gulls", Vector2(2, 0))
	var gull_powers := TargetRead.powers(gull)
	check(gull_powers.has("comes to take and go") or gull_powers.has("takes what you carry"), "a gull takes and goes: %s" % gull_powers)
	check(not gull_powers.has("carries you off"), "and never carries you off")


func test_what_it_is_thinking_is_its_own_mood() -> void:
	var m := _mob(&"runner", Vector2(2, 0))
	m.mood = MobState.CHASING
	eq(TargetRead.thinking(m), "coming for you")
	m.mood = MobState.FLEEING
	eq(TargetRead.thinking(m), "making for home")
	m.mood = MobState.ALERTED
	m.look_until = 100.0
	eq(TargetRead.thinking(m, 50.0), "looking where the noise was")
	eq(TargetRead.thinking(m, 200.0), "up on its feet, looking")
	var worker := _mob(&"cutter", Vector2(2, 0))
	worker.disposition = &"indifferent"
	worker.mood = MobState.WORKING
	eq(TargetRead.thinking(worker), "at its work, not minding you")
	worker.crowded_since = 1.0
	eq(TargetRead.thinking(worker), "held up on its round")
	worker.crowded_since = -1.0
	worker.disturbed = true
	eq(TargetRead.thinking(worker), "it took that badly")
	m.alive = false
	eq(TargetRead.thinking(m), "down")


func test_the_wordless_tag_says_health_and_how_much_it_has_noticed() -> void:
	var m := _mob(&"runner", Vector2(2, 0))
	var t := TargetRead.tag(m)
	eq(t.notice, 0, "nothing noticed")
	eq(t.pips[0], TargetRead.PIPS, "a whole body is every pip")
	check(not bool(t.hurt))
	m.suspicion = 0.5
	eq(TargetRead.tag(m).notice, 1, "stirring")
	m.mood = MobState.ALERTED
	eq(TargetRead.tag(m).notice, 2, "sure")
	m.mood = MobState.CHASING
	eq(TargetRead.tag(m).notice, 3, "coming")
	m.health = 1
	var hurt := TargetRead.tag(m)
	check(bool(hurt.hurt))
	lt(float(hurt.pips[0]), float(TargetRead.PIPS), "and fewer pips")
	eq(TargetRead.pips(0.0), [0, 0.0], "nothing left is no pips")
	eq(TargetRead.pips(1.0), [TargetRead.PIPS, 0.0])


func test_awareness_comes_through_the_one_door() -> void:
	# Without a world to look through, the read still says how sure it is and
	# never claims to see: the fight's own suspicion is the truth it has.
	var m := _mob(&"runner", Vector2(3, 0))
	var a := TargetRead.awareness(m, Vector2.ZERO, Moment.new(), null, null)
	eq(a.word, "has not noticed you")
	check(not bool(a.sees) and not bool(a.hears))
	m.suspicion = 0.5
	eq(TargetRead.awareness(m, Vector2.ZERO, Moment.new(), null, null).word, "wondering")
	m.mood = MobState.CHASING
	var sure := TargetRead.awareness(m, Vector2.ZERO, Moment.new(), null, null)
	check(bool(sure.sure))
	eq(sure.word, "sure of you")
