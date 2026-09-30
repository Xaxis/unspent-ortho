extends TestCase
## THE FIRST ENCLAVE (ROADMAP slice 3 step 7e): at the hub of the half-broken
## walker, one panel is read (StoryContent.FRAGMENTS `enclave_panel`), and reading
## it is being answered: a machine talk (`the_enclave`, like the channel) in his
## cadence, faintly, that lands `enclave_met` for a player who listens, and nothing
## for one who walks off.


func _talk() -> StoryTalk:
	return StoryTalk.start(&"the_enclave")


func test_the_panel_at_the_hatch_opens_the_enclaves_talk() -> void:
	var f: Dictionary = StoryContent.FRAGMENTS.get(&"enclave_panel", {})
	check(not f.is_empty(), "there is a panel at the hatch")
	eq(StringName(f.get("talk", &"")), &"the_enclave", "and reading it is being answered")
	check(not (f.get("lines", []) as Array).is_empty(), "it says something before it answers")
	eq(f.get("dealt", true), false, "and it is never dealt to a sign anywhere else")
	var def: Dictionary = StoryContent.TALKS.get(&"the_enclave", {})
	check(bool(def.get("machine", false)), "the one answering is a machine")


func test_listening_meets_the_enclave() -> void:
	Story.forget()
	var t := _talk()
	check(not t.over, "the talk opens")
	# The first reply at every node: a player who listens.
	for i in 8:
		if t.over:
			break
		t.pick(0)
	check(Story.landed(&"enclave_met"), "listening to it, he has met the enclave")
	Story.forget()


func test_walking_off_meets_nothing() -> void:
	Story.forget()
	var t := _talk()
	# The last reply at every node: a player who leaves.
	for i in 8:
		if t.over:
			break
		t.pick(t.replies().size() - 1)
	check(not Story.landed(&"enclave_met"), "walking off, nothing is met")
	Story.forget()


func test_the_meeting_is_a_thread_of_the_story() -> void:
	var b: Dictionary = StoryContent.BEATS.get(&"enclave_met", {})
	check(not b.is_empty(), "enclave_met is a beat")
	var arc := StringName(b.get("arc", &""))
	check(StoryContent.ARCS.has(arc) and (StoryContent.ARCS[arc].beats as Array).has(&"enclave_met"), "and its thread lists it: %s" % arc)
