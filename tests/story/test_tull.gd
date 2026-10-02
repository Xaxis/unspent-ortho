extends TestCase
## THE TREAD-FOLK (docs/STORY.md, the walkers; ROADMAP slice 3 step 7). Tull farms
## the lame walker's craters from the ground between them, at the crater the
## walker lead pins: the slot `the_tread` and the survey's pin are one rule
## (StoryCasting.crater_near). Colour: his words never land walker_told, the line he
## has seen comes down only once the warden has said the road up, and his bowl of
## soup is a deal of its own, never the crew's armour (Guide.armour_goal).

const Sx := preload("res://tests/save/save_fixture.gd")


## His bowl: salt or fish for a soup. The goal line's armour is Rook's deal's
## alone; Tull's has nothing for it to make, and read as one it broke the line.
func test_the_bowl_is_a_deal_of_its_own_and_never_the_armour() -> void:
	Story.forget()
	Sx.use_root("tull-bowl")
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=10", "--weather=clear:0"])
	await frames(3)
	g.inventory.add(&"fish", 1)
	var soup := g.inventory.count(&"soup")
	Story.choose(&"tull.deal", StringName(StoryContent.PAID[&"tull.deal"].pick))
	await frames(2)
	eq(g.inventory.count(&"fish"), 0, "a fish taken")
	eq(g.inventory.count(&"soup"), soup + 1, "a bowl of soup given")
	eq(Guide.armour_goal(g), "", "Tull's bowl is no deal for the crew's armour")
	Sx.end(g)
	Story.forget()


## The talk: saying nothing is always there; the climb only once the warden has
## said the road up, where Tull has seen the line come down (line_let_down); what
## is up there only once he has met it. Nothing he says is the road up itself.
func test_he_speaks_of_the_line_only_after_the_warden() -> void:
	Story.forget()
	var t := StoryTalk.start(&"tull")
	check(t != null, "Tull has words")
	check(_offers(t, "[say nothing]"), "saying nothing is an answer")
	check(not _offers(t, "The warden says nobody's climbed it."), "before the warden's road up, nothing of the climb")
	check(not _offers(t, "[tell him what is up there]"), "nor of what is up there")
	Story.forget()
	Story.beat(&"walker_told")
	t = StoryTalk.start(&"tull")
	check(_pick(t, "The warden says nobody's climbed it."), "once the warden has said it, the climb")
	check(Story.landed(&"line_let_down"), "and the line he has seen come down")
	Story.forget()
	Story.beat(&"enclave_met")
	t = StoryTalk.start(&"tull")
	check(_pick(t, "[tell him what is up there]"), "once he has met what is up there, he can say so")
	for node: StringName in StoryContent.TALKS[&"tull"].nodes:
		var n: Dictionary = StoryContent.TALKS[&"tull"].nodes[node]
		check(not (n.get("beats", []) as Array).has(&"walker_told"), "%s never lands the road up" % node)
		for r: Dictionary in n.replies:
			check(not (r.get("beats", []) as Array).has(&"walker_told"), "%s's replies never land the road up" % node)
	Story.forget()


## Where he stands is where the survey pins the crater: on seed 1 the crater on
## the Covenant's body nearest it, and Tull is cast there. Seed 42 has no crater
## on that body, so nobody is, and the walker lead pins nothing either.
func test_he_stands_at_the_crater_the_lead_pins() -> void:
	for seed_value: int in [1, 42]:
		Story.forget()
		Sx.use_root("tull-%d" % seed_value)
		var g := Sx.game(tree, ["--seed=%d" % seed_value, "--hour=11", "--weather=clear:0"])
		await frames(3)
		var placed: Dictionary = Sx.system(g, "49_cast").get("placed")
		var pin := StoryMap.crater_pos(g, &"crater:the_covenant")
		if seed_value == 1:
			check(pin.is_finite(), "seed 1: the lead pins a crater")
			check(placed.has(&"the_tread"), "seed 1: the tread is cast")
			if placed.has(&"the_tread"):
				eq(placed[&"the_tread"].pos, pin, "seed 1: where Tull's slot is, the survey's pin is")
			var tull := _row(g, &"tull")
			check(not tull.is_empty(), "seed 1: Tull stands there")
			if not tull.is_empty():
				check((tull.pos as Vector2).distance_to(pin) < 12.0, "seed 1: on the arch, by the ankle (%.1f tiles)" % (tull.pos as Vector2).distance_to(pin))
		else:
			check(not pin.is_finite(), "seed 42: no crater on the Covenant's body to pin")
			check(not placed.has(&"the_tread"), "seed 42: and no tread cast")
			check(_row(g, &"tull").is_empty(), "seed 42: and no Tull")
		Sx.end(g)
	Story.forget()


func _row(g: Game, id: StringName) -> Dictionary:
	for row: Dictionary in Sx.system(g, "49_cast").get("people"):
		if row.character == id:
			return row
	return {}


func _offers(t: StoryTalk, text: String) -> bool:
	if t == null:
		return false
	for r: Dictionary in t.replies():
		if str(r.text) == text:
			return true
	return false


## Picks the reply that reads `text`; false when none does.
func _pick(t: StoryTalk, text: String) -> bool:
	if t == null:
		return false
	var rs := t.replies()
	for i in rs.size():
		if str(rs[i].text) == text:
			@warning_ignore("return_value_discarded")
			t.pick(i)
			return true
	return false
