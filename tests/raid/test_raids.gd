extends TestCase
## The plan against a holding, in a running game (docs/VISION.md §9.2 to §9.7):
## read, warned, come for, and everything that is really lost when it is.
##
## The rule every one of these is written to protect is the owner's own: **a raid
## a player could not have seen coming is a bug, however well it is drawn.**

const Sx := preload("res://tests/save/save_fixture.gd")

## Enough of everything for any piece in the table.
const FULL := "--give=driftwood:12,rag:12,timber:12,scrap:12,stone:12,deadwood:12,reeds:12,pitch:4,iron:4,copper:4,berries:6"


func raids(g: Game) -> Node:
	return Sx.system(g, "48_raids")


func holdings(g: Game) -> Node:
	return Sx.system(g, "46_settlements")


## Nothing on the coast, and nothing new coming: a test about a holding is never
## about whatever the land happened to put out beside it.
func hush(g: Game) -> void:
	var mobs := Sx.system(g, "30_mobs")
	if mobs != null:
		var coast: Coast = mobs.get("coast")
		if coast != null:
			coast.spawning = false
			coast.rounds = false
	g.player.sim.clear_mobs()


func here(g: Game) -> Settlement:
	return holdings(g).call("here") as Settlement


## Something has read this place. Nothing is ever sent for a holding nothing has
## read (48_raids._escalate), so a test that stages attention and then waits for
## a step has to say who noticed — which is the rule, not a way round it.
func read_by_something(g: Game, s: Settlement) -> void:
	(raids(g).call("book", s.id) as Dictionary)["last_read"] = g.clock.minutes


# --- the system is there, and it is the only writer ---------------------------

func test_the_plan_keeps_a_book_on_every_holding_in_a_normal_game() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot"])
	await frames(3)
	check(raids(g) != null, "48_raids is loaded by a normal game start")
	var s := here(g)
	check(s != null, "the staged holding is there")
	eq(s.attention, 0.0, "and nothing has been filed about it yet")
	check(SaveGame.registered(&"raids"), "the plan's own books are saved")
	Sx.end(g)


# --- the ruling: nothing is caused by a clock ---------------------------------

func test_hours_alone_never_put_a_holding_on_the_plans_books() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,store"])
	await frames(3)
	hush(g)
	var s := here(g)
	var sys := raids(g)
	# Two whole days of world time with nothing about to read the place.
	for i in 12:
		g.clock.skip(240.0)
		hush(g)
		sys.call("pass_now")
	eq(s.attention, 0.0, "forty-eight hours of nothing is still nothing")
	check(RaidStage.due_at(s.attention) < 0, "and no step is due")
	Sx.end(g)


func test_a_stolen_cell_humming_in_the_walls_is_what_time_costs() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", FULL])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var h := holdings(g)
	# The loudest thing in the game, put up where the player stands. It is not a
	# piece anybody can build yet (StructureKind.buildable), and that is the
	# point: what it costs is written down before there is a way to earn it.
	var place: Settlement = h.call("found", g.world.realm, g.player.pos, "the works")
	var cell: Structure = h.call("place_piece", place, StructureKind.STOLEN_CELL, g.player.pos + Vector2(2, 0), 0.0)
	cell.powered = true
	gt(place.signature().found_tech, 0.9, "the slate hears it before the plan does")
	for i in 8:
		g.clock.skip(180.0)
		hush(g)
		sys.call("pass_now")
	gt(place.attention, 0.0, "leaving it running costs")
	check(place.attention > RaidStage.AT[0] * 0.5, "and it costs in a day, not a season: %0.3f" % place.attention)
	Sx.end(g)


# --- the notice ----------------------------------------------------------------

func test_a_machine_that_reads_a_holding_says_so_and_walks_off_with_it() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=22", FULL])
	await frames(3)
	hush(g)
	var h := holdings(g)
	var sys := raids(g)
	var place: Settlement = h.call("found", g.world.realm, g.player.pos, "the works")
	var mast: Structure = h.call("place_piece", place, StructureKind.RADIO_MAST, g.player.pos + Vector2(2, 0), 0.0)
	mast.powered = true
	mast.staffed_by = 1
	place.night = 1.0
	var said: Array[StringName] = []
	Events.settlement_noticed.connect(func(_sid: int, _mid: int, kind: StringName) -> void: said.append(kind))
	# A clerk, put down where it can read the place.
	var clerk := g.player.sim.add_mob(&"clerk", place.centre + Vector2(6, 0))
	sys.call("pass_now")
	eq(said.size(), 1, "one reading, announced the moment it was taken")
	eq(said[0], &"clerk", "and the world says what took it")
	check(bool(sys.call("tour_seen", "carrier")), "the clerk is carrying it now")
	eq(place.attention, 0.0, "nothing is filed while it is still in the yard")
	# Killed before it gets clear: the record comes off the body and the place is
	# no worse off than before it was read.
	var records := g.inventory.count(RaidSpoils.RECORD_ITEM)
	clerk.alive = false
	clerk.health = 0
	sys.call("pass_now")
	check(not bool(sys.call("tour_seen", "carrier")), "nothing is carrying it any more")
	eq(g.inventory.count(RaidSpoils.RECORD_ITEM), records + 1, "the record is in the creel")
	eq(place.attention, 0.0, "and a record that was stopped raised nothing")
	Sx.end(g)


func test_a_reading_that_gets_away_is_the_thing_that_raises_it() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=22", FULL])
	await frames(3)
	hush(g)
	var h := holdings(g)
	var sys := raids(g)
	var place: Settlement = h.call("found", g.world.realm, g.player.pos, "the works")
	var mast: Structure = h.call("place_piece", place, StructureKind.RADIO_MAST, g.player.pos + Vector2(2, 0), 0.0)
	mast.powered = true
	mast.staffed_by = 1
	var clerk := g.player.sim.add_mob(&"clerk", place.centre + Vector2(6, 0))
	sys.call("pass_now")
	check(bool(sys.call("tour_seen", "carrier")), "it has a reading")
	# Let it go: it walks out past where anything could catch it.
	clerk.pos = place.centre + Vector2(Notices.GOT_AWAY + 4.0, 0.0)
	sys.call("pass_now")
	gt(place.attention, 0.0, "it got home, and the holding wears it")
	check(bool(sys.call("tour_seen", "filed")), "and the plan has it on file")
	Sx.end(g)


# --- every step is warned first ------------------------------------------------

func test_no_step_ever_begins_without_its_warning() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot", "--attention=0.5"])
	# Listening from before the first frame: the plan is allowed to warn on the
	# frame the game opens, and a test that missed that warning would read the
	# step that followed it as one that arrived out of nowhere.
	var log: Array[String] = []
	Events.raid_warned.connect(func(sid: int, stage: StringName) -> void: log.append("warned %d %s" % [sid, stage]))
	Events.raid_began.connect(func(sid: int, stage: StringName) -> void: log.append("began %d %s" % [sid, stage]))
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	near(s.attention, 0.5, 1e-4, "staged halfway to a raid")
	read_by_something(g, s)
	# Run the plan forward a day, a quarter of an hour at a time.
	for i in 96:
		g.clock.skip(15.0)
		hush(g)
		sys.call("pass_now")
	check(not log.is_empty(), "something came of it")
	var warned: Dictionary = {}
	for line: String in log:
		var parts := line.split(" ")
		var key := "%s %s" % [parts[1], parts[2]]
		if parts[0] == "warned":
			warned[key] = true
			continue
		check(warned.has(key), "'%s' began and nothing warned of it first (%s)" % [key, log])
	Sx.end(g)


func test_nothing_is_ever_sent_for_a_place_nothing_has_read() -> void:
	# The first cause of everything is a machine noticing. A holding at the top of
	# the scale that nothing has ever read is a holding nothing comes for, which
	# is what makes running dark an answer rather than a delay.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot", "--attention=1.0"])
	var warned: Array[StringName] = []
	Events.raid_warned.connect(func(_sid: int, stage: StringName) -> void: warned.append(stage))
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	near(s.attention, 1.0, 1e-4, "at the top of the scale")
	eq(RaidStage.due_at(s.attention), RaidStage.ORDER.size() - 1, "a siege is what it has earned")
	for i in 12:
		g.clock.skip(30.0)
		hush(g)
		sys.call("pass_now")
	check(warned.is_empty(), "and nothing has been sent, because nothing has read the place")
	check(not bool(sys.call("tour_seen", "nothing_coming")), "though a step is plainly due")
	# One reading, and the same holding is warned on the next pass.
	read_by_something(g, s)
	sys.call("pass_now")
	eq(warned.size(), 1, "read once, and the plan acts")
	Sx.end(g)


func test_a_place_made_worse_in_the_warning_is_warned_again_for_a_bigger_step() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot", "--attention=0.5"])
	var said: Array[StringName] = []
	Events.raid_warned.connect(func(_sid: int, stage: StringName) -> void: said.append(stage))
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	(sys.call("book", s.id) as Dictionary)["last_read"] = g.clock.minutes
	sys.call("pass_now")
	eq(said, [RaidStage.PROBE] as Array[StringName], "a probe was announced")
	# The player makes the afternoon worse before it lands.
	s.attention = 0.95
	sys.call("pass_now")
	eq(said.size(), 2, "and the world says so again")
	eq(said[1], RaidStage.RAID, "for the bigger step: %s" % [str(said)])
	eq((sys.get("plans") as Array).size(), 1, "still one party on the way, not two")
	Sx.end(g)


func test_bringing_the_place_down_in_the_warning_turns_them_back() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot", "--attention=0.5"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	var began: Array[StringName] = []
	var ended: Array[StringName] = []
	Events.raid_began.connect(func(_sid: int, stage: StringName) -> void: began.append(stage))
	Events.raid_ended.connect(func(_sid: int, outcome: StringName) -> void: ended.append(outcome))
	read_by_something(g, s)
	sys.call("pass_now")
	check(bool(sys.call("tour_seen", "raid_coming")), "a step is on its way")
	check(began.is_empty(), "and it has not arrived")
	# The player answers it: the place goes quiet enough that the plan drops it.
	s.attention = 0.1
	sys.call("pass_now")
	check(began.is_empty(), "nothing ever set out")
	eq(ended, [&"left"] as Array[StringName], "and the plan let it go")
	check(not bool(sys.call("tour_seen", "marked")), "the tags come off the pieces")
	Sx.end(g)


func test_the_warning_hangs_a_tag_on_the_thing_they_are_coming_for() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,palisade,radio_mast", "--attention=0.5"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	read_by_something(g, s)
	sys.call("pass_now")
	check(bool(sys.call("tour_seen", "marked")), "a piece is wearing the plan's tag")
	# And it is on the piece the holding's own signature points at.
	var plan: RaidPlan = null
	for p: RaidPlan in sys.get("plans"):
		if not p.over():
			plan = p
	check(plan != null, "there is a plan")
	var wanted: Array[int] = []
	for row: Dictionary in plan.party:
		if int(row.get("target", -1)) >= 0:
			wanted.append(int(row.get("target", -1)))
	check(not wanted.is_empty(), "the party wants something")
	for id: int in wanted:
		var piece := s.piece(id)
		check(piece != null, "and it is a piece of this holding")
	Sx.end(g)


# --- what is really lost --------------------------------------------------------

func test_a_raid_nobody_came_home_for_really_breaks_the_yard() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,store,radio_mast", "--attention=0.72"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	var yard := s.centre
	read_by_something(g, s)
	var whole := 0.0
	for p in s.pieces:
		whole += p.health
	# The player walks away. Not being there is a legitimate answer, and what
	# happens is settled on the same arithmetic as a raid they stood in.
	g.player.pos = yard + Vector2(200, 200)
	g.player.hero.pos = g.player.pos
	var outcome: Array[StringName] = []
	Events.raid_ended.connect(func(_sid: int, o: StringName) -> void: outcome.append(o))
	for i in 40:
		g.clock.skip(15.0)
		hush(g)
		sys.call("pass_now")
	check(not outcome.is_empty(), "they came while nobody was there")
	var after := 0.0
	for p in s.pieces:
		after += p.health
	lt(after, whole, "and the yard is worse than it was: %s" % [str(outcome)])
	Sx.end(g)


func test_a_raid_takes_the_people_off_the_books_for_good() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=plot,radio_mast,store"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	if s.people.is_empty():
		s.people.append(s.take_person_id())
	var before := s.people.size()
	var plan := RaidPlan.new()
	plan.id = 99
	plan.settlement_id = s.id
	plan.stage = RaidStage.SIEGE
	plan.state = &"under_way"
	sys.get("plans").append(plan)
	sys.call("_settle_raid", plan, s, 1.0)
	lt(float(s.people.size()), float(before), "somebody was carried off")
	for p in s.pieces:
		check(p.staffed_by < 0 or s.people.has(p.staffed_by),
			"and nobody is still down as working who is not there")
	Sx.end(g)


func test_a_razed_holding_is_left_as_ruins_with_what_they_could_not_carry() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=lean-to"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	for p in s.pieces:
		s.destroy_structure(p.id)
	var plan := RaidPlan.new()
	plan.id = 98
	plan.settlement_id = s.id
	plan.stage = RaidStage.RAID
	plan.state = &"under_way"
	sys.get("plans").append(plan)
	sys.call("_end", plan, s, &"razed")
	check(not s.pieces.is_empty(), "the wrecks stay standing where they fell")
	check(s.standing().is_empty(), "and none of them is a piece any more")
	gt(s.stored(), 0.0, "what they could not carry is lying in the yard")
	check(bool(sys.call("tour_seen", "razed")), "the plan says it razed one")
	Sx.end(g)


# --- per realm ------------------------------------------------------------------

func test_a_machine_in_one_realm_never_senses_a_holding_in_another() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=22", FULL])
	await frames(3)
	hush(g)
	var h := holdings(g)
	var sys := raids(g)
	eq(g.world.realm, Realm.SURFACE, "the game is on the surface")
	# The same coordinates, a realm down: a holding the machines up here stand
	# on top of and can never hear.
	var under: Settlement = h.call("found", Realm.UNDERGROUND, g.player.pos, "the deep works")
	var mast: Structure = h.call("place_piece", under, StructureKind.RADIO_MAST, g.player.pos + Vector2(2, 0), 0.0)
	mast.powered = true
	mast.staffed_by = 1
	under.attention = 0.6
	gt(under.signature().total(), 0.2, "it is shouting")
	var noticed := 0
	var warned := 0
	Events.settlement_noticed.connect(func(_s: int, _m: int, _k: StringName) -> void: noticed += 1)
	Events.raid_warned.connect(func(_s: int, _stage: StringName) -> void: warned += 1)
	@warning_ignore("return_value_discarded")
	g.player.sim.add_mob(&"clerk", g.player.pos + Vector2(4, 0))
	for i in 8:
		g.clock.skip(60.0)
		sys.call("pass_now")
	eq(noticed, 0, "nothing up here reads it")
	eq(warned, 0, "and nothing up here is sent for it: attention is per realm, or it is one number for the world")
	eq(sys.call("network_of", under), Interference.REGIONLESS, "a holding a realm away stands in no network of this one")
	Sx.end(g)


# --- the keeper ------------------------------------------------------------------

func test_taking_the_regions_keeper_quiets_its_network_for_good() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,radio_mast", "--attention=0.6"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	var region := int(sys.call("region_of", s))
	if region < 0:
		# This seed put the start outside any region: nothing to take.
		Sx.end(g)
		return
	gt(s.attention, 0.0, "the holding is on the books")
	Events.sentinel_fell.emit(region, &"coast", SentinelWay.KIND_NAMES[SentinelWay.FORCE])
	eq(s.attention, 0.0, "and it is off them")
	check(bool(sys.call("quieted", s)), "the network is quiet")
	var warned: Array[StringName] = []
	Events.raid_warned.connect(func(_sid: int, stage: StringName) -> void: warned.append(stage))
	s.attention = 1.0
	read_by_something(g, s)
	for i in 20:
		g.clock.skip(60.0)
		hush(g)
		sys.call("pass_now")
	check(warned.is_empty(), "and nothing is ever sent there again")
	Sx.end(g)


# --- saving ----------------------------------------------------------------------

func test_the_whole_thing_saves_and_comes_back_mid_escalation() -> void:
	Sx.use_root("raids")
	var a := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,radio_mast", "--attention=0.5"])
	await frames(3)
	hush(a)
	read_by_something(a, here(a))
	raids(a).call("pass_now")
	var before: Settlement = here(a)
	var plans: Array = raids(a).get("plans")
	check(not plans.is_empty(), "a step is on its way")
	var was: RaidPlan = plans[0]
	var stage := was.stage
	var begins := was.begins_at
	var attention := before.attention
	var saver := Sx.system(a, "05_save")
	eq(String(saver.call("save_to", 1)), "", "saved")
	check(SaveGame.registered(&"raids"), "under its own key")
	Sx.end(a)

	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), "", "slot 1 boots")
	var b := Sx.game(tree, [], o)
	await frames(3)
	var after: Settlement = here(b)
	check(after != null, "the holding came back")
	near(after.attention, attention, 0.05, "with the plan's attention on it")
	var back: Array = raids(b).get("plans")
	check(not back.is_empty(), "and the step still on its way")
	var now: RaidPlan = back[0]
	eq(now.stage, stage, "the same step")
	near(now.begins_at, begins, 1.0, "due at the same minute")
	check(now.coming(), "still warned and not yet arrived")
	check(bool(raids(b).call("tour_seen", "marked")), "and the tag is back on the piece")
	Sx.end(b)
	Sx.finish()
