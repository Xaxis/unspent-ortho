extends TestCase
## The named people (docs/DESIGN.md): declared soundly, cast into worlds
## that were really grown, stood where a body can stand, and reached through the
## one `use` key in a running game.

const Sx := preload("res://tests/save/save_fixture.gd")
const Doors := preload("res://src/systems/21_doors.gd")
const SEEDS: Array[int] = [1, 7]
const SIZE := 256


func test_the_cast_holds_up() -> void:
	var bad := StoryCast.problems()
	check(bad.is_empty(), "\n  ".join(bad))
	gt(float(StoryCast.all().size()), 5.0, "the cast is more than a handful")


func test_elias_is_never_one_of_them() -> void:
	# He is the only main character (docs/STORY.md): nobody in the cast is him.
	for c: StoryCharacter in StoryCast.all():
		check(c.id != &"elias" and c.name != "Elias", "%s is somebody else" % c.id)


func test_everyone_is_cast_somewhere_a_body_can_stand() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var placed := StoryPlan.cast(w)
		for c: StoryCharacter in StoryCast.all():
			# Somebody whose place is in another realm is cast when that realm's
			# world is grown, and not in this one.
			if _slot(c.at).realm != w.realm:
				check(not placed.has(c.at), "seed %d: %s's place is not on the surface" % [s, c.id])
				continue
			# A local is colour: a world not dealt their land has no such person.
			if not _slot(c.at).require:
				continue
			check(placed.has(c.at), "seed %d: %s's place, %s, is in this world" % [s, c.id, c.at])


func test_whoever_waits_on_an_unreached_realm_waits_as_colour() -> void:
	# Oksana's ring is declared before the orbital realm is grown. It may not be
	# load until it can be reached, or every world fails the spine.
	var ring := _slot(StoryCast.get_def(&"oksana").at)
	eq(ring.realm, Realm.ORBITAL, "she is on the ring")
	check(not ring.require, "which is colour until the orbital realm is grown")


func _slot(id: StringName) -> StorySlot:
	for sl: StorySlot in StoryPlan.slots():
		if sl.id == id:
			return sl
	return null


func test_home_is_the_village_he_wakes_beside() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var home: Vector2 = StoryPlan.cast(w)[&"home"].pos
		for v: Dictionary in w.villages:
			var p: Vector2 = v.pos
			if BiomeRegistry.at(w, p).id != &"coast":
				continue
			check(home.distance_to(w.spawn) <= p.distance_to(w.spawn) + 0.001,
				"seed %d: Maren's fire is the nearest coast village to where he wakes" % s)


## Two named people never stand on one tile, or within 49_cast.APART of each
## other: the key answers the nearest of the cast, and a tour or a player put
## beside Vera must be able to be nearer her than anybody. At the Holdfast's
## camp on seed 1 (the shipped size) Vera, Sabine and Teague stood on one tile.
func test_no_two_of_the_cast_stand_in_each_other() -> void:
	var g := Sx.game(tree, ["--seed=1", "--hour=11"])
	await frames(3)
	var cast: Node = Sx.system(g, "49_cast")
	var people: Array = cast.get("people")
	var apart: float = cast.get("APART")
	for i in people.size():
		for j in range(i + 1, people.size()):
			var a: Dictionary = people[i]
			var b: Dictionary = people[j]
			gt((a.pos as Vector2).distance_to(b.pos), apart - 1e-3,
				"%s and %s stand apart" % [a.character, b.character])
	Sx.end(g)



## NOBODY NAMED STANDS INSIDE WHAT IS DRAWN THERE (owner, playtest 2026-10-09:
## people stood in walls). Every named person is put down clear of every prop's
## disc, footprint and walls (WorldQuery.clear_of_props), on both seeds.
func test_no_one_named_stands_inside_a_wall() -> void:
	for s: int in SEEDS:
		var g := Sx.game(tree, ["--seed=%d" % s, "--hour=11"])
		await frames(3)
		var inside := PackedStringArray()
		for row: Dictionary in Sx.system(g, "49_cast").get("people"):
			if not g.query.clear_of_props(row.pos, Tuning.PLAYER_RADIUS):
				inside.append("%s at %s" % [row.character, row.pos])
		eq(inside.size(), 0, "seed %d: nobody named inside a prop (%s)" % [s, ", ".join(inside)])
		Sx.end(g)

func test_a_named_person_is_there_and_answers_the_use_key() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % SIZE, "--hour=11"])
	await frames(3)
	var cast: Node = Sx.system(g, "49_cast")
	var people: Array = cast.get("people")
	gt(float(people.size()), 3.0, "the cast is stood in the world")
	var maren: Dictionary = {}
	for row: Dictionary in people:
		if row.character == &"maren":
			maren = row
		var at: Vector2 = row.pos
		check(g.query.standable(floori(at.x), floori(at.y)), "%s stands on ground a body can stand on" % row.character)
		# The one `use` key answers the NEAREST thing: a person standing inside a
		# terminal's reach is a person the key reads the terminal instead of.
		for q: WorldProp in g.query.props_near(at, StoryProps.REACH + 2.0):
			if StoryProps.readable(q.kind):
				gt(q.pos.distance_to(at) - q.solid, StoryProps.REACH,
					"%s stands clear of the %s beside them, so the key reaches them" % [row.character, StoryProps.kind_of(q.kind)])
	check(not maren.is_empty(), "Maren is at her fire")
	# Stand beside her the way a tour does, and let her be drawn.
	var spot: Vector2 = cast.call("tour_place", "cast:maren")
	check(spot != Vector2.INF, "a tour can find her by name")
	g.player.pos = spot
	g.player.hero.pos = spot
	await frames(40)
	check(bool(cast.call("tour_seen", &"cast:maren")), "near her, she is drawn")
	var story: Node = Sx.system(g, "49_story")
	story.call("_start_talk", maren)
	eq(story.get("talk").id, &"maren", "and the key opens her own words")
	check(Story.met(&"maren"), "and he has met her")
	Sx.end(g)
	Story.forget()


## In a street of thirty, a passer-by with nothing to say who steps between him
## and a named person must not take the key: somebody with words wins.
func test_the_key_reaches_someone_with_words_before_a_nearer_stranger_without() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % SIZE, "--hour=11"])
	await frames(3)
	var cast: Node = Sx.system(g, "49_cast")
	var spot: Vector2 = cast.call("tour_place", "cast:maren")
	g.player.pos = spot
	g.player.hero.pos = spot
	await frames(10)
	var maren := Vector2.INF
	for row: Dictionary in cast.get("people"):
		if row.character == &"maren":
			maren = row.pos
	g.player.facing = (maren - spot).angle()
	var folk: Node = Sx.system(g, "folk")
	var rows: Array = folk.get("folk")
	var stranger := {"pos": spot + (maren - spot) * 0.4, "trade": &"child", "state": &"out"}
	rows.append(stranger)
	var story: Node = Sx.system(g, "49_story")
	var picked: Dictionary = story.call("_person_in_front")
	eq(StringName(str(picked.get("character", &""))), &"maren", "Maren, not the child standing nearer with nothing to say")
	rows.erase(stranger)
	Sx.end(g)
	Story.forget()


## Somebody the story has not brought in yet, or has taken away, is not there to
## be spoken to: `use` where they would stand answers nobody. Dace stood at the
## camp after he had left it, and a named person's row is cast whether or not
## they are present (49_cast draws them only while they are).
func test_somebody_who_is_not_there_does_not_answer_the_key() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=%d" % SIZE, "--hour=11"])
	await frames(3)
	var cast: Node = Sx.system(g, "49_cast")
	var story: Node = Sx.system(g, "49_story")
	for id: StringName in [&"vera", &"dace"]:
		if id == &"dace":
			Story.beat(&"dace_left", -INF)
		check(not StoryCast.get_def(id).present(), "%s is not at the camp" % id)
		var spot: Vector2 = cast.call("tour_place", "cast:%s" % id)
		check(spot != Vector2.INF, "%s is cast in this world" % id)
		var at := Vector2.INF
		for row: Dictionary in cast.get("people"):
			if row.character == id:
				at = row.pos
		g.player.pos = spot
		g.player.hero.pos = spot
		g.player.facing = (at - spot).angle()
		await frames(2)
		var picked: Dictionary = story.call("_person_in_front")
		check(StringName(str(picked.get("character", &""))) != id, "the key does not open %s's words where %s is not" % [id, id])
	Sx.end(g)
	Story.forget()


## Where a door was nearer some of the cast than the key's reach (measured on
## main at this size: four people on seed 1, five on 42).
const DOOR_SEEDS: Array[int] = [1, 42]
## Where he stands to speak to someone: in the key's reach of them, on every side.
const SPEAK_FROM: Array[float] = [1.2, 1.6, 2.2, 2.8]


## A DOOR TAKES THE KEY BEFORE THE PERSON STANDING AT IT. 21_doors gives `use` to
## a door he faces within its REACH of him (`_door_wins`), so someone cast nearer
## a door than the key's reach is someone the key opens that door instead of,
## from some of the places he would speak to them from: on seed 1, Hollis, Lark,
## Liss and Sabine, 1.4 to 2.5 off a door, lost it from one or two stands in 33;
## on the frost sea, Dace stood on a frozen hull's hatch. From every stand in the
## key's reach round each of the cast who is there, and round each thing the
## story stands, facing them, the door never takes the key.
func test_no_door_takes_the_key_meant_for_the_cast() -> void:
	for s: int in DOOR_SEEDS:
		Story.forget()
		var g := Sx.game(tree, ["--seed=%d" % s, "--size=%d" % SIZE, "--hour=11"])
		await frames(3)
		var cast: Node = Sx.system(g, "49_cast")
		var doors: Node = Sx.system(g, "21_doors")
		var all: Array[Threshold] = []
		all.assign(doors.get("doors"))
		gt(float(all.size()), 20.0, "seed %d has doors to keep off (%d)" % [s, all.size()])
		var stands := 0
		for row: Dictionary in cast.get("people"):
			# Somebody not there yet answers nothing, and a press beside where
			# they will stand rightly opens the door behind him (`_door_wins`
			# defers only to words in front): Vera, before she comes to the camp.
			if not StoryCast.get_def(row.character).present():
				continue
			stands += await _door_never_takes(g, doors, all, row.pos, "seed %d: %s" % [s, row.character])
		var things := 0
		for slot: StringName in StoryContent.STOOD:
			if not (cast.get("placed") as Dictionary).has(slot):
				continue
			var at: Vector2 = cast.get("placed")[slot].pos
			g.player.pos = at
			g.player.hero.pos = at
			await _until(func() -> bool: return cast.call("_stood_at", slot) != null)
			var thing: WorldProp = cast.call("_stood_at", slot)
			if thing == null:
				# 49_cast found no spot for it (`_thing_spot`): nothing there to reach.
				var spot: Vector2 = cast.call("_thing_spot", at, absi(int(slot.hash())))
				check(not spot.is_finite(), "seed %d: the %s's thing has a spot at %s and is stood" % [s, slot, spot])
				print("       seed %d: the %s has no spot for its thing" % [s, slot])
				continue
			things += 1
			stands += await _door_never_takes(g, doors, all, thing.pos, "seed %d: the %s's %s" % [s, slot, StoryProps.kind_of(thing.kind)])
		gt(float(things), 0.0, "seed %d stands a thing of the story's" % s)
		gt(float(stands), 300.0, "seed %d: asked from %d stands" % [s, stands])
		Sx.end(g)
	Story.forget()


## From every standable spot in SPEAK_FROM round `at`, facing it, whether a door
## takes the key (21_doors' own choice of door and its own `_door_wins`): a fail
## for each. The stands asked.
func _door_never_takes(g: Game, doors: Node, all: Array[Threshold], at: Vector2, who: String) -> int:
	var asked := 0
	for r: float in SPEAK_FROM:
		for i in 8:
			var p := at + Vector2.from_angle(TAU * i / 8.0) * r
			if not g.query.standable(floori(p.x), floori(p.y)):
				continue
			asked += 1
			var facing := (at - p).angle()
			var meant := Interiors.door_for(all, p, facing, Doors.REACH)
			if meant == null:
				continue
			g.player.pos = p
			g.player.hero.pos = p
			g.player.facing = facing
			g.player.hero.facing = facing
			await frames(1)
			check(not bool(doors.call("_door_wins", meant.door)),
				"%s: from %s facing them, the door at %s takes the key (%.2f off them)" % [who, p, meant.door, meant.door.distance_to(at)])
	return asked


## Until `ok` holds, or ten seconds: what is stood is settled twice a second
## (49_cast RECHECK).
func _until(ok: Callable) -> void:
	var end := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < end and not bool(ok.call()):
		await process_frames(1)
