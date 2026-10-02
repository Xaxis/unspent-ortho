extends TestCase
## THE TREAD-FOLK (docs/STORY.md, the walkers; ROADMAP slice 3 step 7). Tull farms
## the lame walker's craters from the ground between them, at the tread the
## walker lead pins: the slot `the_tread` and the survey's pin are one rule
## (StoryCasting.crater_near), and he stands on the lip of its middle toe's crater,
## where the line comes down (49_cast). Colour: his words never land walker_told, the line he
## has seen comes down only once the warden has said the road up, and his bowl of
## soup is a deal of its own, never the crew's armour (Guide.armour_goal).

const Sx := preload("res://tests/save/save_fixture.gd")
const Treads := preload("res://src/core/colossus/colossus_treads.gd")


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


## The slot is where the survey pins the crater (the ankle, on the Covenant's
## body); Tull stands on the arch-side lip of the middle toe's crater, where the
## cable comes down. Staged with the foot down: on the far side of the arch from
## the cable, and clear of the walk from the climb's lip down to it. Seed 42 has
## no crater on that body, so nobody is there, and the lead pins nothing either.
func test_he_stands_on_the_middle_toe_s_lip_clear_of_the_climb() -> void:
	for seed_value: int in [1, 7, 42]:
		Story.forget()
		Sx.use_root("tull-%d" % seed_value)
		var g := Sx.game(tree, ["--seed=%d" % seed_value, "--hour=11", "--weather=clear:0"])
		await frames(3)
		var placed: Dictionary = Sx.system(g, "49_cast").get("placed")
		var pin := StoryMap.crater_pos(g, &"crater:the_covenant")
		var tull := _row(g, &"tull")
		if seed_value == 42:
			check(not pin.is_finite(), "seed 42: no crater on the Covenant's body to pin")
			check(not placed.has(&"the_tread"), "seed 42: and no tread cast")
			check(tull.is_empty(), "seed 42: and no Tull")
			Sx.end(g)
			continue
		check(placed.has(&"the_tread") and placed[&"the_tread"].pos == pin, "seed %d: the slot is where the survey pins the crater" % seed_value)
		check(not tull.is_empty(), "seed %d: Tull is cast" % seed_value)
		var tread := {}
		var n := 0
		for m: Dictionary in g.world.landmarks:
			if StringName(m.get("kind", &"")) == &"tread":
				n += 1
				if (m.pos as Vector2) == pin:
					tread = m
					break
		if tull.is_empty() or tread.is_empty():
			Sx.end(g)
			continue
		var pad: Vector3 = (tread.pads as Array)[1]
		var centre := Vector2(pad.x, pad.y)
		var at: Vector2 = tull.pos
		var arch := (pin - centre).normalized()
		var off := absf(arch.angle_to(at - centre))
		lt(absf(at.distance_to(centre) - Treads.rim_r(pad)), 6.0, "seed %d: on the middle toe's lip (%.1f m from the pad, rim %.0f)" % [seed_value, at.distance_to(centre), Treads.rim_r(pad)])
		lt(off, 0.4, "seed %d: on its arch side (%.2f rad off it)" % [seed_value, off])
		# The foot down at its own crater, the climb's cable and lip as a player meets them.
		g.clock.minutes = Sx.system(g, "19_colossi").call(&"tour_hour", "tread%d+5" % n)
		g.player.pos = at
		g.player.hero.pos = at
		var climb := Sx.system(g, "43_climb")
		var cable := Vector2.INF
		# The walk is posed for him only once he is by it, a frame or more on;
		# until then the cable is read off a pose from before the clock moved.
		for i in 30:
			await frames(1)
			cable = climb.call(&"tour_place", "climb:cable")
			if cable.distance_to(centre) < Treads.rim_r(pad):
				break
		var lip: Vector2 = climb.call(&"tour_place", "climb:lip")
		check(cable.distance_to(centre) < Treads.rim_r(pad) and lip.is_finite(), "seed %d: the foot is down and its cable hangs into this crater" % seed_value)
		if cable.distance_to(centre) < Treads.rim_r(pad) and lip.is_finite():
			check(signf(arch.cross(at - centre)) != signf(arch.cross(cable - centre)), "seed %d: on the far side of the arch from the cable (%.2f rad off it, the cable %.2f)" % [seed_value, arch.angle_to(at - centre), arch.angle_to(cable - centre)])
			var walk := Geometry2D.get_closest_point_to_segment(at, lip, cable).distance_to(at)
			gt(walk, 8.0, "seed %d: clear of the walk from the lip down to the cable (%.1f m)" % [seed_value, walk])
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
