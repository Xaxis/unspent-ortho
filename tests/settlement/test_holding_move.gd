extends TestCase
## THE HOLDING (ROADMAP slice 2 step 2), in a real game and by the player's own
## keys: at a village that has seen him, with a holding of his standing, `use` on
## any of its people offers them his beds; as many as there are free beds come,
## and the rest are named as staying. The night the plan comes for that village
## it takes one of those who stayed, and if none stayed it finds nobody at all.

const Sx := preload("res://tests/save/save_fixture.gd")
const SEEDS: Array[int] = [1, 7, 3]


func _stand(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)


## A game with a staged holding of `pieces` and a village in a region with a
## working yard: [game, village], or [].
func _game(pieces: String) -> Array:
	for s in SEEDS:
		var g := Sx.game(tree, ["--seed=%d" % s, "--size=256", "--hour=11", "--weather=clear:0", "--holding=%s" % pieces])
		await frames(3)
		var works := g.get_node("34_works")
		for i in g.world.villages.size():
			var at: Vector2 = g.world.villages[i].get("pos", Vector2.INF)
			var region := g.world.region_at(floori(at.x), floori(at.y))
			if works.call(&"state", region) != null:
				return [g, i]
		Sx.end(g)
		await frames(1)
	return []


func _press_use() -> void:
	Input.action_press(&"use")
	await process_frames(3)
	Input.action_release(&"use")
	await process_frames(3)


## Stand among village `v` until they have seen him, then face one of them and
## ask: returns what their answer said, or [] when no offer was made.
func _ask(g: Game, v: int) -> PackedStringArray:
	var folk := g.get_node("folk")
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	_stand(g, at)
	for i in 90:
		await frames(1)
	check(is_finite(folk.call(&"seen_at", v)), "they have seen him")
	var rows: Array = folk.call(&"out_of", v, at)
	check(not rows.is_empty(), "somebody of the village is out")
	if rows.is_empty():
		return PackedStringArray()
	# One of them standing clear of a door: a door at his elbow takes the key
	# (21_doors), which is right in play and not what this asks.
	var doors := g.get_node("21_doors")
	var clear := false
	for row: Dictionary in rows:
		row["role"] = &"idle"
		row["wait"] = 99.0
		_stand(g, (row.pos as Vector2) + Vector2(1.0, 0.0))
		Survival.face(g, PI)
		await frames(2)
		if not bool(doors.call(&"use_spent")) and doors.get("door_near") == null:
			clear = true
			break
	check(clear, "one of them stands clear of a door")
	var story := g.get_node("49_story")
	await _press_use()
	var talk: StoryTalk = story.get("talk")
	check(talk != null, "`use` on one of them opens a talk")
	if talk == null:
		return PackedStringArray()
	var offered := false
	for r: Dictionary in talk.replies():
		offered = offered or str(r.text) == StoryContent.HOLDING_MOVE["offer"]
	check(offered, "and he can offer them his beds")
	if not offered:
		return PackedStringArray()
	await _press_use()
	var said := talk.says()
	await _press_use()
	return said


func test_as_many_as_there_are_beds_come_and_the_rest_are_named() -> void:
	Story.forget()
	var got := await _game("bunk")
	check(not got.is_empty(), "a village in a region with a yard")
	if got.is_empty():
		return
	var g: Game = got[0]
	var v: int = got[1]
	var folk := g.get_node("folk")
	var holdings := g.get_node("46_settlements")
	var s: Settlement = (holdings.get("places") as Array)[0]
	var before := s.people.size()
	var beds := s.beds() - before
	var said := await _ask(g, v)
	var came := int((folk.get("moved") as Dictionary).get(v, 0))
	eq(came, mini(beds, 6), "as many as there are free beds come")
	eq(s.people.size(), before + came, "and they live at the holding now")
	eq(int(folk.call(&"people_of", v)), 6 - came, "the village is that many short")
	check(said.has(StoryContent.HOLDING_MOVE["yes"]), "they say they will walk")
	var stay := StoryContent.HOLDING_MOVE["short"] % Holding.stay_words(6 - came, str(g.world.villages[v].name))
	check(said.has(stay), "and who stays is named: %s" % stay)
	Sx.end(g)
	await frames(1)
	Story.forget()


## His offer is beds and a roof over them, so with no bed standing at his holding
## (a march burned them, 48_raids `_burn_his`) a village that has seen him is not
## asked to come to what is not there.
func test_with_no_bed_standing_he_offers_none() -> void:
	Story.forget()
	var got := await _game("bunk")
	check(not got.is_empty(), "a village in a region with a yard")
	if got.is_empty():
		return
	var g: Game = got[0]
	var v: int = got[1]
	var holdings := g.get_node("46_settlements")
	var s: Settlement = (holdings.get("places") as Array)[0]
	for p: Structure in s.pieces:
		if StructureKind.sleeps(p.kind) > 0:
			@warning_ignore("return_value_discarded")
			holdings.call(&"damage", s.id, p.id, p.health + 1.0)
	eq(s.beds(), 0, "no bed stands at his holding")
	var folk := g.get_node("folk")
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	_stand(g, at)
	for i in 90:
		await frames(1)
	check(is_finite(folk.call(&"seen_at", v)), "they have seen him")
	var rows: Array = folk.call(&"out_of", v, at)
	check(not rows.is_empty(), "somebody of the village is out")
	if not rows.is_empty():
		var offer: Dictionary = holdings.call(&"holding_offer", rows[0])
		check(offer.is_empty(), "and nobody is offered beds that are not there")
	Sx.end(g)
	await frames(1)
	Story.forget()


func test_a_village_all_gone_to_the_holding_is_not_taken_from() -> void:
	Story.forget()
	var got := await _game("bunk,bunk")
	check(not got.is_empty(), "a village in a region with a yard")
	if got.is_empty():
		return
	var g: Game = got[0]
	var v: int = got[1]
	var folk := g.get_node("folk")
	var raids := g.get_node("48_raids")
	var said: Array[String] = []
	var hear := func(t: String) -> void: said.append(t)
	Events.message.connect(hear)
	@warning_ignore("return_value_discarded")
	await _ask(g, v)
	eq(int(folk.call(&"people_of", v)), 0, "every one of them came")
	var due := SnatchNight.due(float(folk.call(&"seen_at", v)), g.world.seed_value, v)
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	_stand(g, at + Vector2(SnatchNight.AWAY + 10.0, 0.0))
	g.clock.minutes = due + 300.0
	raids.call(&"sweep")
	eq((g.get_node("45_taken").get("taken") as Taken).people.size(), 0, "the night comes for the village and takes nobody")
	check(said.has(StoryContent.HOLDING_MOVE["gone"]), "and finds nobody behind the doors")
	Events.message.disconnect(hear)
	Sx.end(g)
	await frames(1)
	Story.forget()
