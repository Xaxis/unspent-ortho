extends TestCase
## Revelations one at a time (docs/STORY.md §9, StoryPacing): the next waits until
## the last has been felt. What is held back is what the story OFFERS — a reply, a
## person walking in — and never what the player has already done.


## The §9 table, by the beat each revelation lands as. A revelation that loses its
## flag lands on top of the last one, and nothing else would say so.
const TABLE: Array[StringName] = [&"body_new", &"built_halcyon", &"was_cia", &"threshold",
	&"singularity", &"tradecraft", &"june_named", &"june_knew", &"ants", &"standoff",
	&"gap", &"seeker"]


func _offers(t: StoryTalk, text: String) -> bool:
	for r: Dictionary in t.replies():
		if str(r.text) == text:
			return true
	return false


func test_every_revelation_in_the_table_is_marked_one() -> void:
	Story.forget()
	for b: StringName in TABLE:
		check(StoryPacing.is_reveal(b), "%s is a revelation" % b)
	check(not StoryPacing.is_reveal(&"long_quiet"), "the quiet is only a fact")
	check(not StoryPacing.is_reveal(&"nonsense"), "and nothing undeclared is one")


func test_a_revelation_holds_the_next_until_it_is_felt() -> void:
	Story.forget()
	Story.now = 1000.0
	Story.beat(&"was_cia", -INF)
	Story.beat(&"threshold")
	check(StoryPacing.settling(), "the table is still being felt")
	var t := StoryTalk.start(&"the_digger")
	t.pick(1) # What was the building?
	check(not _offers(t, "Who wrote the orders that started the war?"),
		"the next revelation is not offered on top of it")
	check(not _offers(t, "It woke up with somebody in it."), "nor any other")
	check(_offers(t, "[leave]"), "and the way out is still there")
	Story.now += StoryPacing.SETTLE
	check(not StoryPacing.settling(), "felt")
	t = StoryTalk.start(&"the_digger")
	t.pick(1)
	check(_offers(t, "Who wrote the orders that started the war?"), "so the same person can be asked it now")


func test_a_revelation_already_landed_is_not_held() -> void:
	Story.forget()
	Story.now = 500.0
	Story.beat(&"body_new")
	# Maren says what Sabine will say: the second person is not a second revelation.
	var t := StoryTalk.start(&"sabine")
	check(_offers(t, "[open it]"), "a reply that tells what is already known is offered")


func test_a_person_who_waits_on_a_revelation_waits_for_it_to_settle() -> void:
	Story.forget()
	Story.now = 2000.0
	Story.beat(&"june_named")
	var june := StoryCast.get_def(&"june")
	check(not june.present(), "she does not walk in the minute her name is said")
	Story.now += StoryPacing.SETTLE - 1.0
	check(not june.present(), "not quite yet")
	Story.now += 1.0
	check(june.present(), "and then she is there")
	# A beat that is not a revelation is waited on for no time at all.
	Story.beat(&"holdfast_hope")
	check(StoryCast.get_def(&"vera").present(), "Vera comes as soon as Rook sends word")


func test_something_staged_as_long_ago_is_felt_at_once() -> void:
	Story.forget()
	Story.now = 0.0
	Story.beat(&"june_named", -INF)
	check(StoryPacing.felt(&"june_named"), "a writer's --beats is a story that happened")
	check(not StoryPacing.settling(), "and holds nothing back")


func test_a_page_is_never_held() -> void:
	Story.forget()
	# Reading is knowing, even in the middle of feeling something else.
	Story.now = 100.0
	Story.beat(&"body_new")
	Story.now = 150.0
	check(Story.read(&"passwords"), "read")
	check(Story.landed(&"built_halcyon"), "and what it says has landed")
	eq(StoryPacing.last_reveal(), &"built_halcyon", "and is now what everything else waits on")


func test_no_conversation_is_ever_left_with_nothing_to_say() -> void:
	Story.forget()
	# While anything is settling, every node must still offer a reply that neither
	# waits on a beat nor lands a revelation, or the pacing would strand a talk.
	for talk: StringName in StoryContent.TALKS:
		var nodes: Dictionary = StoryContent.TALKS[talk].nodes
		for n: StringName in nodes:
			var free := false
			for r: Dictionary in nodes[n].get("replies", []):
				if StringName(str(r.get("when", &""))) != &"":
					continue
				var lands: Array = r.get("beats", []).duplicate()
				var to := StringName(str(r.get("to", &"")))
				lands.append_array(nodes.get(to, {}).get("beats", []))
				var reveals := false
				for b: StringName in lands:
					reveals = reveals or StoryPacing.is_reveal(b)
				free = free or not reveals
			check(free, "%s.%s always has something to say that is not a revelation" % [talk, n])


func test_when_a_beat_landed_comes_back_through_a_save() -> void:
	Story.forget()
	Story.now = 700.0
	Story.beat(&"threshold")
	Story.beat(&"june_named", -INF)
	var d := Story.save_state()
	var json: Dictionary = JSON.parse_string(JSON.stringify(d))
	Story.forget()
	Story.load_state(json)
	Story.now = 700.0
	eq(Story.landed_at(&"threshold"), 700.0, "the minute it landed")
	check(StoryPacing.settling(), "so a revelation still being felt is still being felt after loading")
	check(StoryPacing.felt(&"june_named"), "and one staged as long ago is still long ago")


func test_a_save_from_before_beats_kept_their_minute_opens_as_long_ago() -> void:
	Story.forget()
	Story.load_state({"beats": ["june_named"], "read": [], "choices": {}})
	Story.now = 0.0
	check(Story.landed(&"june_named"), "it landed")
	check(StoryPacing.felt(&"june_named"), "and nothing is held back on a game somebody already played")
