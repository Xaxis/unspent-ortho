extends TestCase
## JUNE (ROADMAP slice 3, step 3). Imre, who left the Covenant, says the Speaker's
## name (june_named); once it has settled she is home, at her table in the house
## nearest the Covenant (StoryRooms.KEEPERS, 21_doors dwellers), and never out in
## its square. There the one `use` key opens her words: younger than her
## (june_met), the voice she always knew (june_knew), what it kept her from
## (echo_kept), and, once the Before has told him of the play, her mother
## (hannah_died). The goal line walks it from the archive: the Covenant's seat, her
## name, June, then back to her for the voice, each pinned on the survey.

const Sx := preload("res://tests/save/save_fixture.gd")
const Doors := preload("res://src/systems/21_doors.gd")
## Rolls of each plan per landscape.
const ROLLS := 40
const SIZE := 256


func _lead(key: StringName) -> String:
	return String(StoryContent.LEAD.get(key, "<no %s line>" % key))


func _hers(w: WorldData) -> Threshold:
	var tenants := StoryRooms.tenants(w)
	for t: Threshold in Interiors.thresholds(w):
		if tenants.get(t.key, &"") == StoryRooms.SPEAKER:
			return t
	return null


## Every house a Speaker's can be, in every landscape, a few hundred rolls of its
## plan: June is laid in it, once, at her table all but always, where a body a step in front of her is
## nearer her than any of the room's words and out of reach of all the room answers
## the key for first. On seed 1 she faced the way in so near it that `use` in
## front of her walked him out of the door.
func test_her_house_lays_her_at_the_table_where_the_key_finds_her_first() -> void:
	var lands: Array[int] = [-1]
	lands.append_array(Array(BiomeRegistry.land_indices()))
	for kind: StringName in StoryRooms.SPEAKER_KINDS:
		var k := Interiors.kind(kind)
		var bad := 0
		var laid := 0
		var at_table := 0
		for land: int in lands:
			for roll in ROLLS:
				var rng := Rng.make(Rng.hash_ints(roll, land + 7, 0x5EA7))
				var l: InteriorLayout = k.recipe.call(&"lay", rng, land) if k.by_land else k.recipe.call(&"lay", rng)
				StoryRooms.furnish(l, StoryRooms.SPEAKER)
				var hers: Array[Dictionary] = []
				for r: Dictionary in l.residents:
					if StringName(str(r.get("character", &""))) == &"june":
						hers.append(r)
				if hers.size() != 1:
					bad += 1
					continue
				laid += 1
				at_table += 1 if (hers[0].at as Vector2).distance_to(l.table) <= 2.1 else 0
				var why := _unheard(l, hers[0])
				if why != "":
					bad += 1
					if bad <= 3:
						check(false, "%s, land %d, roll %d: %s" % [kind, land, roll, why])
		eq(bad, 0, "%s: every one of %d rolls lays her where the key finds her (%d laid)" % [kind, lands.size() * ROLLS, laid])
		# At her table in all but the most crowded plans.
		gt(float(at_table), 0.97 * float(laid), "%s: %d of %d at the table" % [kind, at_table, laid])


## Why `use` a step in front of her would not answer her, or "".
func _unheard(l: InteriorLayout, r: Dictionary) -> String:
	var at: Vector2 = r.at
	var inside := false
	for room: Rect2i in l.rooms:
		inside = inside or Rect2(room).has_point(at)
	if not inside:
		return "she is not in the house"
	var front := at + (r.face as Vector2) * StoryRooms.KEEPER_STEP
	for sl: Dictionary in l.slots:
		if (sl.at as Vector2).distance_to(front) - StoryRooms.SOLID <= StoryRooms.KEEPER_STEP:
			return "the %s is nearer than she is" % sl.slot
	# The door, and the room's own takers, answer the key first within their reach.
	if front.distance_to(l.door) <= Doors.REACH:
		return "the door is in reach (%.2f)" % front.distance_to(l.door)
	for t: Dictionary in l.things:
		var takes: bool = t.kind == &"strongbox" or t.kind == &"shelf" or t.has("serves") or t.has("fuel") or bool(t.get("exit", false))
		if takes and (t.at as Vector2).distance_to(front) <= KeptBy.REACH:
			return "the %s is in reach" % t.kind
	return ""


## The house nearest the Covenant holds her, and no other.
func test_only_the_speakers_house_holds_her() -> void:
	for s: int in [1, 7]:
		var w := WorldGen.generate(s, SIZE)
		var t := _hers(w)
		check(t != null, "seed %d: the Speaker has a house" % s)
		if t == null:
			continue
		var n := 0
		for r: Dictionary in InteriorGen.grow(s, t, StoryRooms.SPEAKER).layout.residents:
			n += 1 if StringName(str(r.get("character", &""))) == &"june" else 0
		eq(n, 1, "seed %d: June is laid in hers" % s)
		var tenants := StoryRooms.tenants(w)
		for other: Threshold in Interiors.thresholds(w):
			if other == t or not StoryRooms.SPEAKER_KINDS.has(other.kind):
				continue
			for r: Dictionary in InteriorGen.grow(s, other, tenants.get(other.key, &"")).layout.residents:
				check(StringName(str(r.get("character", &""))) != &"june", "seed %d: %s is not hers" % [s, other.key])


## The whole of her, played in a running game through the one key: Imre names
## her, she is home only once that has settled, and at her table she says each
## thing in turn, with a quiet between the revelations.
func test_imre_names_her_and_she_is_met_at_her_table() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % SIZE, "--hour=11", "--weather=clear:0"])
	await frames(3)
	var cast := Sx.system(g, "49_cast")
	var story := Sx.system(g, "49_story")
	var doors := Sx.system(g, "21_doors")
	for row: Dictionary in cast.get("people"):
		check(row.character != &"june", "June is not stood out in the Covenant's square")
	# IMRE, beside the Covenant, once the Speaker has been heard of.
	Story.beat(&"covenant_speaker", -INF)
	var imre := _stand_at_cast(g, cast, &"imre")
	await frames(40)
	check(bool(cast.call("tour_seen", &"cast:imre")), "Imre is there, drawn")
	await _press_use()
	var t: StoryTalk = story.get("talk")
	eq(t.id if t != null else &"", &"imre", "the key opens Imre's words")
	_say(t, ["Why did you leave?", "Who is the Speaker?"])
	check(Story.landed(&"june_named"), "and he says her name")
	story.call("_close")
	check(not imre.is_empty(), "Imre was cast")
	# HER HOUSE, before her name has settled: her things, and nobody.
	var house := _hers(g.world)
	check(house != null, "the Speaker's house is on this world")
	if house == null:
		Sx.end(g)
		Story.forget()
		return
	await doors.call(&"go_in", house)
	eq(_june_rows(doors).size(), 0, "she has not sent for him yet: the house is empty of her")
	await doors.call(&"go_out")
	g.clock.minutes += StoryPacing.SETTLE + 1.0
	await process_frames(2)
	check(StoryCast.get_def(&"june").present(), "her name has settled")
	await doors.call(&"go_in", house)
	await _in_through_the_door(g)
	var rows := _june_rows(doors)
	eq(rows.size(), 1, "and she is home")
	if rows.size() != 1:
		Sx.end(g)
		Story.forget()
		return
	var june: Dictionary = rows[0]
	check(is_instance_valid(june.model) and (june.model as Node3D).is_inside_tree(), "drawn at her table")
	var look: Dictionary = (june.model as PersonModel).look
	var said: Dictionary = StoryCast.get_def(&"june").look
	for k: Variant in said:
		eq(look.get(k), said[k], "dressed as she is written (%s)" % k)
	# THE KEY, from a step in front of her.
	_face(g, june)
	await _press_use()
	t = story.get("talk")
	eq(t.id if t != null else &"", &"june", "the key opens her own words")
	check(Story.met(&"june"), "and he has met her")
	check(Story.landed(&"june_met"), "younger than her")
	_say(t, ["Do you know who I am?"])
	check(Story.landed(&"june_knew"), "she always knew the voice was his")
	check(not _offers(t, "What does the voice say?"), "and what the voice did waits until that has been felt")
	story.call("_close")
	g.clock.minutes += StoryPacing.SETTLE + 1.0
	await process_frames(2)
	await _press_use()
	t = story.get("talk")
	_say(t, ["Do you know who I am?", "What does the voice say?"])
	check(Story.landed(&"echo_kept"), "the voice has kept her alive, and it is his")
	story.call("_close")
	# HER MOTHER is the Before's to open: asked only once Hannah has told him of the play.
	g.clock.minutes += StoryPacing.SETTLE + 1.0
	await process_frames(2)
	await _press_use()
	t = story.get("talk")
	_say(t, ["Do you know who I am?"])
	check(not _offers(t, "What happened to your mother?"), "nobody asks after a mother he does not remember")
	story.call("_close")
	Story.beat(&"hannah_play", -INF)
	await _press_use()
	t = story.get("talk")
	_say(t, ["Do you know who I am?", "What happened to your mother?"])
	check(Story.landed(&"hannah_died"), "the winter of thirty-four, the north road")
	story.call("_close")
	await doors.call(&"go_out")
	Sx.end(g)
	Story.forget()


## The goal line from the archive to June (Guide.WAY): each hop said until what
## ends it, keyed so a tour can claim it, and the survey marks the Covenant.
func test_the_goal_line_walks_from_the_archive_to_june() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % SIZE, "--hour=10", "--weather=clear:0"])
	await frames(3)
	_past_the_holdfast(g)
	Story.beat(&"war_archive")
	@warning_ignore("return_value_discarded")
	Story.hear(StoryCrossing.CROSSED)
	@warning_ignore("return_value_discarded")
	Story.meet(&"otto")
	# The archive's own hop (test_archive walks it): shown an order, long since felt.
	Story.beat(&"tradecraft", -INF)
	_hop(g, &"covenant", "the archive's man met: the Covenant's seat")
	Story.beat(&"covenant_speaker")
	_hop(g, &"speaker", "the Speaker heard of: her name")
	Story.beat(&"june_named")
	@warning_ignore("return_value_discarded")
	Guide.goal(g)
	check(Guide.last_goal_key != &"june", "her name just said: she has not sent for him yet")
	g.clock.minutes += StoryPacing.SETTLE + 1.0
	await process_frames(2)
	_hop(g, &"june", "her name felt: June, at home")
	@warning_ignore("return_value_discarded")
	Story.meet(&"june")
	Story.beat(&"june_met")
	Story.beat(&"june_knew")
	@warning_ignore("return_value_discarded")
	Guide.goal(g)
	check(Guide.last_goal_key != &"june" and Guide.last_goal_key != &"june_voice", "met, and what she knew still settling")
	g.clock.minutes += StoryPacing.SETTLE + 1.0
	await process_frames(2)
	_hop(g, &"june_voice", "felt: back to her, for what the voice says")
	Story.beat(&"echo_kept")
	@warning_ignore("return_value_discarded")
	Guide.goal(g)
	check(Guide.last_goal_key != &"june_voice", "and once she has said it, that want is met")
	Sx.end(g)
	Story.forget()


func _hop(g: Game, key: StringName, what: String) -> void:
	eq(Guide.goal(g), _lead(key), what)
	eq(Guide.last_goal_key, key, "%s: keyed, so a tour can claim it" % key)
	var pin: Dictionary = StoryContent.TOLD_WHILE.get(key, {})
	check(not pin.is_empty(), "%s: the survey has a mark for it" % key)
	if pin.is_empty():
		return
	eq(pin.place, &"the_covenant", "%s: at the Covenant" % key)
	var marked := false
	for m: Dictionary in UiMapScreen.told(g):
		marked = marked or String(m.word) == String(pin.word)
	check(marked, "%s: and the survey marks it" % key)


## The crew paid and the armour made, the yard read, Rook and Vera: slice 2 done.
func _past_the_holdfast(g: Game) -> void:
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	Story.choose(&"rook.iron", &"paid")
	if not g.inventory.has(&"kit_plate"):
		g.inventory.add(&"kit_plate", 1)
	for b: StringName in [&"reaper_down", &"built_halcyon", &"holdfast_hope"]:
		Story.beat(b, -INF)


func _june_rows(doors: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in doors.call(&"dweller_rows"):
		if StringName(str(row.get("character", &""))) == &"june":
			out.append(row)
	return out


func _stand_at_cast(g: Game, cast: Node, id: StringName) -> Dictionary:
	var spot: Vector2 = cast.call("tour_place", "cast:%s" % id)
	for row: Dictionary in cast.get("people"):
		if row.character == id:
			g.player.pos = spot
			g.player.hero.pos = spot
			g.player.facing = ((row.pos as Vector2) - spot).angle()
			g.player.hero.facing = g.player.facing
			return row
	return {}


func _face(g: Game, row: Dictionary) -> void:
	var at: Vector2 = row.pos
	var spot := at + Vector2.from_angle(float(row.facing)) * StoryRooms.KEEPER_STEP
	g.player.pos = spot
	g.player.hero.pos = spot
	g.player.facing = (at - spot).angle()
	g.player.hero.facing = g.player.facing


## The press that crossed a door is spent for a moment (20_realms `use_spent`),
## as it is for a player: wait it out, as a player walking in does.
func _in_through_the_door(g: Game) -> void:
	var realms := Sx.system(g, "20_realms")
	for i in 600:
		if not bool(realms.call(&"use_spent")):
			return
		await process_frames(1)


## The real key, as a player presses it: whatever answers `use` first (a door
## within its reach, the card on the table) answers it here too.
func _press_use() -> void:
	Input.action_press(&"use")
	await process_frames(3)
	Input.action_release(&"use")
	await process_frames(3)


func _offers(t: StoryTalk, text: String) -> bool:
	if t == null:
		return false
	for r: Dictionary in t.replies():
		if str(r.text) == text:
			return true
	return false


func _say(t: StoryTalk, picks: Array) -> void:
	if t == null:
		check(false, "a conversation is open")
		return
	for want: String in picks:
		var i := -1
		var rs := t.replies()
		for k in rs.size():
			if str(rs[k].text) == want:
				i = k
		check(i >= 0, "%s offers \"%s\" at %s" % [t.id, want, t.node])
		if i < 0:
			return
		@warning_ignore("return_value_discarded")
		t.pick(i)
