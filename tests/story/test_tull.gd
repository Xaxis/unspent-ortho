extends TestCase
## THE TREAD-FOLK (docs/STORY.md, the walkers; ROADMAP slice 3 step 7). Tull farms
## the lame walker's craters from the ground between them, at the crater the
## walker lead pins, its middle toe's, where the line comes down: the slot
## `the_tread` and the survey's pin are one rule (StoryCasting.crater_near), and he
## stands on the arch-side lip of it (49_cast). Colour: his words never land walker_told, the line he
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


## The slot is where the survey pins the crater (a tread's middle toe's, on the
## Covenant's body, where the cable comes down); Tull stands on its arch-side lip. Staged with the foot down: on the far side of the arch from
## the cable, and clear of the walk from the climb's lip down to it. A world with
## no crater on that body has nobody there, and the lead pins nothing either.
## Which seeds have one moves with worldgen, so each is asked.
func test_he_stands_on_the_middle_toe_s_lip_clear_of_the_climb() -> void:
	var pinned := 0
	for seed_value: int in [1, 7, 42]:
		Story.forget()
		Sx.use_root("tull-%d" % seed_value)
		var g := Sx.game(tree, ["--seed=%d" % seed_value, "--hour=11", "--weather=clear:0"])
		await frames(3)
		var placed: Dictionary = Sx.system(g, "49_cast").get("placed")
		var pin := StoryMap.crater_pos(g, &"crater:the_covenant")
		var tull := _row(g, &"tull")
		if not pin.is_finite():
			check(not placed.has(&"the_tread"), "seed %d: no crater pinned, and no tread cast" % seed_value)
			check(tull.is_empty(), "seed %d: and no Tull" % seed_value)
			Sx.end(g)
			continue
		pinned += 1
		# The pin is read off the walks, the slot off the world's list: one yaw
		# kept in single precision, so they agree to a hair, not to the bit.
		check(placed.has(&"the_tread") and (placed[&"the_tread"].pos as Vector2).distance_to(pin) < 0.01, "seed %d: the slot is where the survey pins the crater" % seed_value)
		check(not tull.is_empty(), "seed %d: Tull is cast" % seed_value)
		var tread := {}
		var n := 0
		for m: Dictionary in g.world.landmarks:
			if StringName(m.get("kind", &"")) == &"tread":
				n += 1
				var toe: Vector3 = (m.pads as Array)[Treads.MIDDLE_TOE]
				if Vector2(toe.x, toe.y).distance_to(pin) < 0.01:
					tread = m
					break
		check(not tread.is_empty(), "seed %d: the pin is a tread's middle toe's crater" % seed_value)
		if tull.is_empty() or tread.is_empty():
			Sx.end(g)
			continue
		var pad: Vector3 = (tread.pads as Array)[Treads.MIDDLE_TOE]
		var centre := Vector2(pad.x, pad.y)
		var at: Vector2 = tull.pos
		var arch := ((tread.pos as Vector2) - centre).normalized()
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
	gt(float(pinned), 0.0, "some seed has a crater pinned, or nothing above was asked")
	Story.forget()


## THEIR HOLDING STANDS ROUND HIS LIP (GenTreads.dress): a shack, a fire and a
## bench round Treads.folk_lip of the tread cast to `the_tread`, laid as that
## tread's own (its `props`, which its foot never crushes), at no other tread, and
## none of them where Tull stands. Seed-agnostic, as the lip test is.
func test_their_holding_stands_round_his_lip() -> void:
	const HOLDING: Array[int] = [PropKind.SHACK, PropKind.FIRE, PropKind.BENCH]
	var held := 0
	for seed_value: int in [1, 7, 42]:
		Story.forget()
		Sx.use_root("tull-holding-%d" % seed_value)
		var g := Sx.game(tree, ["--seed=%d" % seed_value, "--hour=11", "--weather=clear:0"])
		await frames(3)
		var placed: Dictionary = Sx.system(g, "49_cast").get("placed")
		var row: Dictionary = placed.get(&"the_tread", {})
		var lip := Treads.folk_lip(row.ankle, row.pads, float(row.yaw)) if not row.is_empty() else Vector2.INF
		var tull := _row(g, &"tull")
		for m: Dictionary in g.world.landmarks:
			if StringName(m.get("kind", &"")) != &"tread":
				continue
			# The tread's own, by id (GenIds turns dress's span into them).
			var own := {}
			for id: int in PackedInt32Array(m.get("props", PackedInt32Array())):
				own[id] = true
			# Read by sections round the lip a holding would stand on (WorldSections).
			var near := Treads.folk_lip(m.pos, m.pads, float(m.yaw))
			var props: Array[WorldProp] = []
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					props.append_array(WorldSections.props_in(g.world, WorldSections.of(near) + Vector2i(dx, dy)))
			var kinds: Array[int] = []
			for p: WorldProp in props:
				if own.has(p.id) and HOLDING.has(p.kind):
					kinds.append(p.kind)
					check(not tull.is_empty() and (tull.pos as Vector2).distance_to(p.pos) > 1.0, "seed %d: Tull does not stand in his own %s" % [seed_value, PropKind.NAMES[p.kind]])
					if lip.is_finite():
						lt(p.pos.distance_to(lip), 9.0, "seed %d: the %s stands round his lip (%.1f off it)" % [seed_value, PropKind.NAMES[p.kind], p.pos.distance_to(lip)])
			if not row.is_empty() and (m.pos as Vector2) == (row.ankle as Vector2):
				held += 1
				for k: int in HOLDING:
					check(kinds.has(k), "seed %d: the tread's people keep a %s at his tread" % [seed_value, PropKind.NAMES[k]])
			else:
				eq(kinds.size(), 0, "seed %d: and nothing of theirs at a tread nobody is cast to" % seed_value)
		Sx.end(g)
	gt(float(held), 0.0, "some seed has the tread cast, or nothing above was asked")
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
