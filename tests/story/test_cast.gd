extends TestCase
## The named people (docs/STORY_SYSTEM.md §8): declared soundly, cast into worlds
## that were really grown, stood where a body can stand, and reached through the
## one `use` key in a running game.

const Sx := preload("res://tests/save/save_fixture.gd")
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
