extends TestCase
## AN AWAIT MEANS SINCE I LAST ASKED (GameSystem.tour_forget): every system that
## latches an event for a tour spends it when the runner forgets the word, or the
## first scan, hit, harvest or cue of a run answers every later await for free
## (a re-scan refused by its cooldown passed marks.tour's `await ability:scan`).

const Sx := preload("res://tests/save/save_fixture.gd")


func _spent(g: Game, sys_name: String, word: StringName, latch: Callable) -> void:
	var sys := Sx.system(g, sys_name)
	check(sys != null, "%s is loaded" % sys_name)
	if sys == null:
		return
	latch.call(sys)
	check(bool(sys.call("tour_seen", word)), "%s answers %s once it happened" % [sys_name, word])
	sys.call("tour_forget", word)
	check(not bool(sys.call("tour_seen", word)), "%s: asked and answered, %s is spent" % [sys_name, word])


func test_every_latch_a_tour_awaits_is_spent_when_answered() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	_spent(g, "54_gear", &"ability:scan", func(s: Node) -> void: (s.get("_fired") as Dictionary)[&"scan"] = true)
	_spent(g, "54_gear", &"ability", func(s: Node) -> void: (s.get("_fired") as Dictionary)[&"dash"] = true)
	_spent(g, "54_gear", &"jumped:glide", func(s: Node) -> void:
		(s.get("_jumped") as Dictionary)[&"glide"] = true
		(s.get("_jumped") as Dictionary)[&""] = &"glide")
	_spent(g, "47_defences", &"turret_hit", func(s: Node) -> void: s.set("_hit", true))
	_spent(g, "47_defences", &"turret_fired", func(s: Node) -> void: s.set("_fired", true))
	_spent(g, "47_defences", &"turret_kill", func(s: Node) -> void: s.set("_killed", true))
	_spent(g, "46_settlements", &"produced", func(s: Node) -> void: s.set("_produced", true))
	_spent(g, "75_music", &"score_resolve", func(s: Node) -> void: (s.get("cues_played") as Array).append(&"coast_resolve"))
	Sx.end(g)


## One word, one meaning: `ring` is the runner's (a blow rang off plate). The sky's
## ring in view is `ring_drawn`, so a shoulder fight's `await ring` never passes
## on the hull overhead.
func test_the_sky_ring_never_answers_for_a_blow_on_plate() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=23", "--weather=clear:0"])
	await process_frames(2)
	var orbit := Sx.system(g, "19_orbit")
	var layer: Variant = orbit.get("layer")
	check(layer != null, "the sky's ring layer stands")
	if layer != null:
		(layer as Object).set("drawn", true)
		check(bool(orbit.call("tour_seen", &"ring_drawn")), "the ring in view is ring_drawn")
		check(not bool(orbit.call("tour_seen", &"ring")), "and never bare ring")
	Sx.end(g)


## A quiet with no holding to be quiet about proves nothing: `unfiled` and
## `nothing_coming` answer only while a holding stands.
func test_quiet_claims_need_a_holding_to_be_quiet_about() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	var raids := Sx.system(g, "48_raids")
	eq((raids.call("places") as Array).size(), 0, "no holding stands")
	check(not bool(raids.call("tour_seen", "unfiled")), "so nothing is unfiled")
	check(not bool(raids.call("tour_seen", "nothing_coming")), "and nothing is proven not coming")
	Sx.end(g)
