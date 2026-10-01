extends TestCase
## MENDED GEAR (slice 3 step 5): living on what the machines leave. The bench
## plate is spent by the blows it turns; spent, it turns nothing. Mended at the
## bench from scrap it turns again, and patched with a harvester's iron it is the
## mended plate, which turns more and wears slower.

const F := preload("res://tests/fight/fixture.gd")
const Sx := preload("res://tests/save/save_fixture.gd")


## A sim with the hero wearing `plate` (as a player does, in the bag and worn).
func _plated(plate: StringName) -> FightSim:
	var sim := F.make_sim()
	sim.hero.inventory.add(plate)
	check(sim.hero.inventory.wear_kit(plate), "%s worn" % plate)
	sim.hero.read_body()
	sim.hero.health = 1000
	sim._begin()
	return sim


## Blows of three from a hunter until the plate turns nothing, or `cap`. Returns
## [blows it turned any of, points it turned in all].
func _until_spent(sim: FightSim, cap: int = 400) -> Array[int]:
	var m := F.still(sim, &"longlegs", sim.hero.pos + Vector2(3.0, 0.0), PI)
	var turned_blows := 0
	var turned := 0
	var quiet := 0
	for i in cap:
		var before := sim.hero.health
		sim._hurt_hero(m, 3, Vector2.RIGHT, 0.0, 0)
		sim.now += 2000.0
		var off := 3 - (before - sim.hero.health)
		turned += off
		if off > 0:
			turned_blows += 1
			quiet = 0
		else:
			quiet += 1
			# Fractions are carried: a quarter plate turns one blow in four.
			if quiet >= 8:
				break
	return [turned_blows, turned]


func test_the_plate_is_spent_by_the_blows_it_turns_and_then_turns_none() -> void:
	var sim := _plated(&"kit_plate")
	var inv := sim.hero.inventory
	eq(inv.edge(&"kit_plate"), 10000, "new plate is whole")
	var got := _until_spent(sim)
	gt(float(got[1]), 0.0, "it turned blows while it held")
	eq(inv.edge(&"kit_plate"), 0, "and it is spent")
	var spent := F.count(sim.drain(), &"plate_spent")
	eq(spent, 1, "said once as it goes")
	var m := F.still(sim, &"longlegs", sim.hero.pos + Vector2(3.0, 0.0), PI)
	var before := sim.hero.health
	for i in 4:
		sim._hurt_hero(m, 3, Vector2.RIGHT, 0.0, 0)
		sim.now += 2000.0
	eq(before - sim.hero.health, 12, "spent, it turns nothing")


func test_scrap_at_the_bench_mends_it() -> void:
	var sim := _plated(&"kit_plate")
	var inv := sim.hero.inventory
	@warning_ignore("return_value_discarded")
	_until_spent(sim)
	var r := Crafting.recipe(&"mend_plate")
	check(not r.is_empty(), "there is a way to mend it")
	eq(r.get("at", &""), &"bench", "at the bench")
	check(not Crafting.can_make(inv, r), "not from nothing")
	inv.add(&"scrap", 2)
	inv.add(&"rag", 1)
	check(Crafting.can_make(inv, r), "from what the machines leave")
	check(Crafting.make(inv, r), "mended")
	eq(inv.edge(&"kit_plate"), 10000, "whole again")
	check(not inv.has(&"scrap"), "the scrap went into it")
	var again := _until_spent(sim)
	gt(float(again[1]), 0.0, "and it turns blows again")


func test_the_mended_plate_turns_more_and_lasts_longer() -> void:
	var inv := Inventory.new()
	inv.add(&"kit_plate")
	inv.add(&"tide_iron")
	inv.add(&"scrap", 2)
	var r := Crafting.recipe(&"plate_mended")
	check(Crafting.can_make(inv, r), "the plate patched with a harvester's iron")
	check(Crafting.make(inv, r), "made")
	check(inv.has(&"plate_mended") and not inv.has(&"kit_plate"), "the plate became the mended plate")
	eq(Gear.tier(&"plate_mended"), &"mended", "and it is the mended tier")
	var base := _until_spent(_plated(&"kit_plate"))
	var mended := _until_spent(_plated(&"plate_mended"))
	gt(float(mended[1]), float(base[1]) * 2.0, "it turns more, for longer (%d against %d points)" % [mended[1], base[1]])


## THE HOP: fed at the Covenant, the goal line asks for the mended plate until he
## carries one (Guide.WAY `mend`, StoryContent.LEAD mend).
func test_the_covenant_sends_him_to_mend_the_plate() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=10", "--weather=clear:0"])
	await process_frames(2)
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	g.inventory.add(&"pick", 1)
	Story.choose(Guide.CAMP_PAID, &"paid")
	g.inventory.add(&"kit_plate", 1)
	g.body.fed_until = g.clock.minutes + 600.0
	# Where the story stands by the Covenant: slice 1 and 2 done, the archive's man
	# met and an order shown, June met, what the voice kept her from said, and the
	# old soldier spoken to since. The way's hops before this one are behind him,
	# long since felt.
	for b: StringName in [&"reaper_named", &"reaper_down", &"built_halcyon", &"holdfast_hope", &"war_archive",
			&"tradecraft", &"covenant_speaker", &"june_named", &"june_knew", &"echo_kept"]:
		@warning_ignore("return_value_discarded")
		Story.beat(b, -INF)
	for who: StringName in [&"otto", &"june", &"dace"]:
		@warning_ignore("return_value_discarded")
		Story.meet(who)
	var mend := String(StoryContent.LEAD[&"mend"])
	check(Guide.goal(g) != mend, "not before the Covenant")
	@warning_ignore("return_value_discarded")
	Story.beat(&"covenant_fed")
	eq(Guide.goal(g), mend, "fed at the Covenant: the mended plate")
	eq(Guide.last_goal_key, &"mend", "keyed, so the prompt can list what it wants")
	# Made as a player makes it, from the plate it replaces: the plate armour Rook
	# paid for goes into it, and the want for that plate must not come back.
	g.inventory.add(&"tide_iron", 1)
	g.inventory.add(&"scrap", 2)
	check(Crafting.make(g.inventory, Crafting.recipe(&"plate_mended")), "mended at the bench")
	check(not g.inventory.has(&"kit_plate"), "out of the plate he wore")
	var made := Guide.goal(g)
	check(made != mend, "carried: that want is met")
	check(Guide.last_goal_key != &"armour", "and the plate it was made from is not wanted again (%s)" % made)
	Sx.end(g)
	Story.forget()


## THE REASON, SAID AT THE COVENANT: the hawker's "What's that iron?", once the
## Covenant has fed him, and the line about harvester iron behind it.
func test_the_hawker_says_why_harvester_iron() -> void:
	Story.forget()
	var ask := "What's that iron?"
	var t := StoryTalk.start(&"the_hawker")
	check(not _texts(t).has(ask), "not asked before the Covenant has fed him")
	@warning_ignore("return_value_discarded")
	Story.beat(&"covenant_fed")
	t = StoryTalk.start(&"the_hawker")
	check(_texts(t).has(ask), "asked once it has")
	var said: Array = StoryContent.TALKS[&"the_hawker"]["nodes"][&"iron"]["says"]
	check(String(said[0]).begins_with("Harvester iron."), "and it says what the iron is for")
	Story.forget()


func _texts(t: StoryTalk) -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in t.replies():
		out.append(str(r.text))
	return out


## IN THE RUNNING GAME: the blow that spends the plate is said, once, by the
## fight (40_fight on the sim's `plate_spent`), in the wright's words.
func test_the_game_says_the_plate_is_spent() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=64", "--hour=10", "--give=kit_plate:1"])
	await frames(3)
	var inv := g.inventory
	eq(inv.worn, &"kit_plate", "worn as it came into the bag")
	inv.set_edge(&"kit_plate", 100)
	var said: Array[String] = []
	var hear := func(text: String) -> void: said.append(text)
	Events.message.connect(hear)
	var sim: FightSim = g.player.sim
	sim.clear_mobs()
	var m := F.still(sim, &"longlegs", sim.hero.pos + Vector2(3.0, 0.0), PI)
	for i in 3:
		sim._hurt_hero(m, 3, Vector2.RIGHT, 0.0, 0)
		sim.now += 2000.0
	await frames(3)
	Events.message.disconnect(hear)
	eq(inv.edge(&"kit_plate"), 0, "spent")
	eq(said.count(StoryContent.MENDED["spent"]), 1, "and said, once: %s" % [said])
	Sx.end(g)
	Sx.finish()

