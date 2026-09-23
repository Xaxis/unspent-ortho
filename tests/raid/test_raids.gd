extends TestCase
## The plan against a holding, in a running game (docs/VISION.md to §9.7):
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
	var said: Array[StringName] = []
	Events.sfx.connect(func(sound: StringName, _at: Vector3) -> void: said.append(sound))
	sys.call("pass_now")
	gt(place.attention, 0.0, "it got home, and the holding wears it")
	check(bool(sys.call("tour_seen", "filed")), "and the plan has it on file")
	# And the world SAYS so. It is the one link in the chain the player cannot
	# watch — everything else happens in front of them — so a record getting home
	# is not allowed to be the only silent thing in the system.
	check(said.has(&"raid_filed"), "the yard hears it land: %s" % [str(said)])
	Sx.end(g)


func test_a_record_only_comes_off_a_body_somebody_was_standing_over() -> void:
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
	var clerk := g.player.sim.add_mob(&"clerk", place.centre + Vector2(6, 0))
	sys.call("pass_now")
	check(bool(sys.call("tour_seen", "carrier")), "it has a reading")
	var records := g.inventory.count(RaidSpoils.RECORD_ITEM)
	# Something else puts it down on the far side of the land. A record is a thing
	# lying in the grass where the body fell, not a thing that appears in the
	# creel because a clerk died somewhere.
	clerk.pos = g.player.pos + Vector2(60, 0)
	clerk.alive = false
	clerk.health = 0
	sys.call("pass_now")
	eq(g.inventory.count(RaidSpoils.RECORD_ITEM), records, "nothing came into the creel")
	check(bool(sys.call("tour_seen", "stopped")), "though the reading was still stopped")
	eq(place.attention, 0.0, "and the place is no worse off")
	Sx.end(g)


func test_a_reading_with_nobody_holding_it_still_has_to_walk_home() -> void:
	# A saved game comes back with no body under a reading that was halfway home
	# (Notice.from_dict), and a realm crossing leaves every carrier behind. Filing
	# those on the first frame meant saving the game beside a clerk turned a
	# record the player could have killed into one the plan already has.
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
	var clerk := g.player.sim.add_mob(&"clerk", place.centre + Vector2(6, 0))
	sys.call("pass_now")
	check(bool(sys.call("tour_seen", "carrier")), "a clerk is carrying it")
	# Its body goes: culled, crossed out of the world, or loaded back without one.
	g.player.sim.remove_mob(clerk)
	sys.call("pass_now")
	eq(place.attention, 0.0, "it has not arrived anywhere yet")
	check(not bool(sys.call("tour_seen", "filed")), "and nothing is on file")
	# It is given the walk it would have taken, and then it counts.
	g.clock.skip(Notices.HOME_MINUTES + 5.0)
	sys.call("pass_now")
	gt(place.attention, 0.0, "the walk home is over, and the holding wears it")
	Sx.end(g)


func test_a_record_is_worth_carrying_because_something_is_made_of_it() -> void:
	# It is dropped, it costs bulk and it is proof; it also has to be a thing a
	# player can DO something with, or killing the carrier proves nothing.
	check(not Items.def(RaidSpoils.RECORD_ITEM).is_empty(), "a record is a thing in the creel")
	var into: Array[StringName] = []
	for r: Dictionary in Recipes.LIST:
		if (r.get("needs", {}) as Dictionary).has(RaidSpoils.RECORD_ITEM):
			for made: Variant in (r.get("makes", {}) as Dictionary):
				into.append(StringName(made))
	check(not into.is_empty(), "and it is spent on something: %s" % [str(into)])
	check(into.has(&"copper"),
		"stripped, their own account of the place is the copper a signet is wound from: %s" % [str(into)])
	# It is a FOUND thing, so nothing may ever make one: the only way to a record
	# is off a body that was carrying it (tests/survival/test_crafting.gd).
	eq(Items.def(RaidSpoils.RECORD_ITEM).get("group", &""), &"found", "a record is found, never made")


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


# --- a raid is not something you walk out of --------------------------------------

## Stand a party up in the yard: staged high, read once, and the window run out
## with the player standing where they built. Returns the live bodies.
func party_out(g: Game, s: Settlement) -> Array[MobState]:
	var sys := raids(g)
	read_by_something(g, s)
	for i in 24:
		if bool(sys.call("tour_seen", "party")):
			break
		g.clock.skip(15.0)
		hush_but_the_party(g)
		sys.call("pass_now")
	var out: Array[MobState] = []
	for m in g.player.sim.mobs:
		if m.raider and m.alive and not m.removed:
			out.append(m)
	return out


## The same hush, but it leaves the party where it stands: `hush` clears every
## body off the land, which would take the raid with it.
func hush_but_the_party(g: Game) -> void:
	var mobs := Sx.system(g, "30_mobs")
	if mobs != null:
		var coast: Coast = mobs.get("coast")
		if coast != null:
			coast.spawning = false
			coast.rounds = false


func test_a_party_is_never_culled_out_from_under_a_raid() -> void:
	# The cheapest answer to a raid used to be walking twenty-five tiles: the
	# coast culls at Spawner.CULL and the plan then saw an empty yard, called it
	# held and spent the attention that brought it. A party is the plan's, and
	# only the plan takes it off the land.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,store,radio_mast", "--attention=0.72"])
	await frames(3)
	hush(g)
	var s := here(g)
	var party := party_out(g, s)
	check(not party.is_empty(), "a party is in the yard")
	var mobs := Sx.system(g, "30_mobs")
	var coast: Coast = mobs.get("coast")
	# The player walks off, well past the culling distance.
	g.player.pos = s.centre + Vector2(Spawner.CULL + 8.0, 0.0)
	g.player.hero.pos = g.player.pos
	coast.tick()
	var still := 0
	for m: MobState in party:
		if m.alive and not m.removed:
			still += 1
	eq(still, party.size(), "the coast left every one of them standing")
	Sx.end(g)


func test_walking_away_from_a_raid_settles_it_rather_than_ending_it() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,store,radio_mast", "--attention=0.72"])
	await frames(3)
	hush(g)
	var s := here(g)
	# Nothing loose to pay them with: this is about what walking away costs, not
	# about the store buying them off.
	s.stores.clear()
	var party := party_out(g, s)
	check(not party.is_empty(), "a party is in the yard")
	var whole := 0.0
	for p in s.pieces:
		whole += p.health
	var ended: Array[StringName] = []
	Events.raid_ended.connect(func(_sid: int, o: StringName) -> void: ended.append(o))
	# A day's walk away, which is a legitimate answer and always was — but it is
	# the answer that means coming home to what happened, not the one that makes
	# it not happen.
	g.player.pos = s.centre + Vector2(400, 400)
	g.player.hero.pos = g.player.pos
	raids(g).call("pass_now")
	eq(ended.size(), 1, "the step is over")
	var after := 0.0
	for p in s.pieces:
		after += p.health
	lt(after, whole, "the yard is worse for it: %0.1f -> %0.1f (%s)" % [whole, after, str(ended)])
	Sx.end(g)


func test_a_wall_takes_its_share_of_a_blow_the_player_is_standing_in_front_of() -> void:
	# On paper a holding's defences turn up to MOST_TURNED of everything coming
	# (RaidResolve.turned). A blow thrown by a machine standing in the yard is
	# scaled by the same number, or a second plate wall is only ever worth
	# building before leaving.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var h := holdings(g)
	var s := here(g)
	var m := g.player.sim.add_mob(&"hauler", s.centre + Vector2(2, 0))
	eq(s.defence_total(), 0.0, "nothing is defending it yet")
	var bare := float(sys.call("_blow_of", m, s))
	gt(bare, RaidResolve.LEAST, "a hauler's blow is worth more than the floor")
	@warning_ignore("return_value_discarded")
	h.call("place_piece", s, StructureKind.PLATE_WALL, s.centre + Vector2(3, 0), 0.0)
	gt(s.defence_total(), 0.0, "and now something is")
	var walled := float(sys.call("_blow_of", m, s))
	lt(walled, bare, "the wall takes its share: %0.2f -> %0.2f" % [bare, walled])
	near(walled / bare, 1.0 - RaidResolve.turned(s.defence_total()), 0.02,
		"exactly the share the paper settle takes")
	Sx.end(g)


func test_a_full_store_buys_them_off_with_the_player_standing_there() -> void:
	# docs/DESIGN.md offers paying them as one of the answers. It used to work
	# only for a raid nobody was at: the live harvester walked past the store and
	# started cutting the mast down.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,store,radio_mast"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := here(g)
	s.stores[&"timber"] = 6
	s.stores[&"scrap"] = 6
	var before := s.stored()
	gt(before, RaidRoles.TRIBUTE, "there is a full store lying in the yard")
	var whole := 0.0
	for p in s.pieces:
		whole += p.health
	var plan := RaidPlan.new()
	plan.id = 77
	plan.settlement_id = s.id
	plan.stage = RaidStage.RAID
	plan.state = &"under_way"
	(sys.get("plans") as Array).append(plan)
	var m := g.player.sim.add_mob(&"hauler", s.centre + Vector2(1, 0))
	check(bool(sys.call("_tribute", plan, s, m, g.player.sim)), "the harvester loads up instead")
	lt(s.stored(), before, "the store is poorer: %0.0f -> %0.0f" % [before, s.stored()])
	eq(plan.outcome, &"held", "and the holding held")
	var after := 0.0
	for p in s.pieces:
		after += p.health
	eq(after, whole, "nothing was broken to pay them")
	check(bool(sys.call("tour_seen", "paid")), "the world says they were paid")
	# And a handful in the store is not a tribute: they take it and go on to what
	# they came for, which is what the paper settle does with the same numbers.
	var plan2 := RaidPlan.new()
	plan2.id = 78
	plan2.settlement_id = s.id
	plan2.stage = RaidStage.RAID
	plan2.state = &"under_way"
	(sys.get("plans") as Array).append(plan2)
	s.stores.clear()
	s.stores[&"timber"] = 2
	check(not bool(sys.call("_tribute", plan2, s, m, g.player.sim)), "two of anything buys nobody off")
	eq(plan2.outcome, &"", "the step is not over")
	eq(s.stored(), 0.0, "though what there was went with them")
	Sx.end(g)


# --- what the yard shoots back ----------------------------------------------------

## Stand the player where their swing reaches this body's working part, facing
## it. Where a player has to stand to hurt a machine is the fight's own rule
## (`FightRules.side_of`), and a test about who a body blames afterwards has to
## obey it like anybody else.
func stand_to_strike(g: Game, m: MobState) -> void:
	var turn := 0.0
	match m.part:
		&"back": turn = PI
		&"left": turn = -PI * 0.5
		&"right": turn = PI * 0.5
	var at := m.pos + Vector2.from_angle(m.facing + turn) * (m.radius + g.player.hero.radius * 0.5)
	g.player.pos = at
	g.player.hero.pos = at
	g.player.hero.facing = (m.pos - at).angle()


func live_plan(g: Game) -> RaidPlan:
	for p: RaidPlan in (raids(g).get("plans") as Array):
		if not p.over():
			return p
	return null


func test_a_raider_the_yard_shot_turns_on_what_shot_it() -> void:
	# A turret is the only thing in the game that hurts a machine without the
	# player swinging. A raider that answered it by walking on into the yard would
	# make the piece a tax the plan pays and never notices; one that came for the
	# PLAYER instead would make arming it a way of getting yourself attacked.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--held=axe_felling",
		"--holding=hut,plot,store,radio_mast", "--attention=0.72"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var h := holdings(g)
	var s := here(g)
	var gun: Structure = h.call("place_piece", s, StructureKind.TURRET, s.centre + Vector2(3, 0), 0.0)
	gun.powered = true
	check(TurretRules.armed(gun), "the turret is armed and fed")
	var party := party_out(g, s)
	check(not party.is_empty(), "a party is in the yard")
	var m: MobState = party[0]
	var sim: FightSim = g.player.sim
	# Well away from the turret, so turning on it is a walk and not a coincidence.
	m.pos = s.centre + Vector2(-9, 0)
	var errand := int((sys.get("_raiders") as Dictionary).get(m.id, {}).get("target", -1))
	# The turret's own shot, through the fight's one door for a blow that is not
	# the player's — the same call 47_defences makes.
	eq(sim.strike(m, TurretRules.blow(), gun.pos), &"hit", "the bolt went through")
	eq(m.struck_from, gun.pos, "and the body knows where it came from")
	check(bool(sys.call("_on_the_job", m, sim)),
		"a body the yard shot is still the plan's to steer: nothing else would walk it to a piece")
	sys.call("_drive", live_plan(g), s, m, sim)
	check(bool(sys.call("tour_seen", "raider_turned")), "it has turned on what shot it")
	near(m.line_b.distance_to(gun.pos), 0.0, 0.01,
		"and it is walking at the turret, not at what it was sent for")
	eq(int((sys.get("_raiders") as Dictionary).get(m.id, {}).get("target", -1)), errand,
		"the errand is still on its books, and the tag still hangs on that piece")
	Sx.end(g)


func test_the_player_swinging_after_the_turret_takes_the_raider_back() -> void:
	# There is no rule in the raids package about precedence and there must not
	# be: `FightSim.strike` writes INF for the player's own swing, the last blow
	# overwrites the one before it, and so the body belongs to whoever hit it
	# most recently. This is that sentence, run.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--held=axe_felling",
		"--holding=hut,plot,store,radio_mast", "--attention=0.72"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var h := holdings(g)
	var s := here(g)
	var gun: Structure = h.call("place_piece", s, StructureKind.TURRET, s.centre + Vector2(3, 0), 0.0)
	gun.powered = true
	var party := party_out(g, s)
	check(not party.is_empty(), "a party is in the yard")
	var m: MobState = party[0]
	var sim: FightSim = g.player.sim
	eq(sim.strike(m, TurretRules.blow(), gun.pos), &"hit", "the yard shot it first")
	check(bool(sys.call("_on_the_job", m, sim)), "and it is the plan's")
	# Now the player, on the working part, with a real swing through the real sim.
	# A player walking round to the working part and swinging until one lands,
	# which is `try 25 / walkto part / tap swing` in every tour that fights
	# anything. The first swing is eaten by the bolt's own hit window, and that is
	# the fight's rule, not this one's.
	var before := m.health
	var next_swing := -INF
	for i in 300:
		# A running game drives every raider every physics step, and that is what
		# keeps one off the player while it is about its errand. Driving it here
		# is the honest version of the moment: the plan is still holding it, and
		# the swing has to land anyway.
		@warning_ignore("return_value_discarded")
		sys.call("_on_the_job", m, sim)
		if sim.now >= next_swing and sim.hero.swing_refusal(sim.now) == &"":
			next_swing = sim.now + 60.0
			stand_to_strike(g, m)
			sim.press_swing()
		sim.step(0.016)
		if m.health < before:
			break
	lt(m.health, before, "the player's blow landed")
	check(not is_finite(m.struck_from.x), "and there is no turret on the body to blame any more")
	check(not bool(sys.call("_on_the_job", m, sim)),
		"so it is the fight's, and the fight's quarrel is with whoever swung")
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


func test_a_keeper_taken_here_never_quiets_the_same_region_number_a_realm_down() -> void:
	# Region ids restart at 0 in every realm's world (GenCountries.regions), so a
	# file kept under a bare region id had the keeper of the caves' region 3
	# quieting a surface holding in region 3 — for good, with nothing ever filed
	# there again and no way for the player to see why.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,radio_mast", "--attention=0.6"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var h := holdings(g)
	var up := here(g)
	var region := int(sys.call("region_of", up))
	if region < 0:
		Sx.end(g)
		return
	# A holding a realm down, at the same coordinates: the same region NUMBER.
	var under: Settlement = h.call("found", Realm.UNDERGROUND, g.player.pos, "the deep works")
	under.attention = 0.6
	Events.sentinel_fell.emit(region, &"coast", SentinelWay.KIND_NAMES[SentinelWay.FORCE])
	eq(up.attention, 0.0, "the surface holding is off the books")
	check(bool(sys.call("quieted", up)), "and its network is quiet")
	near(under.attention, 0.6, 1e-4, "the one below is untouched")
	# And it stays untouched when the player walks down the shaft, which is the
	# only moment the leak could ever have been seen.
	g.world.realm = Realm.UNDERGROUND
	eq(int(sys.call("region_of", under)), region, "it stands in the same region number")
	check(not bool(sys.call("quieted", under)), "and the surface's dead keeper says nothing about it")
	var saved := sys.call("_save") as Dictionary
	var books := saved.get("regions", {}) as Dictionary
	check(books.has(sys.call("region_key", Realm.SURFACE, region)), "the file says which realm it is about")
	check(not books.has(str(region)), "and never a bare region number")
	Sx.end(g)


func test_a_prop_taken_here_never_pulls_a_stake_out_of_a_yard_a_realm_away() -> void:
	# Prop ids restart at 0 in every realm's world too (Survival.add_prop counts
	# this world's props), so asking THIS world's depleted set about a stake
	# standing in another one answered for a prop the player took on the surface.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot"])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var h := holdings(g)
	var under: Settlement = h.call("found", Realm.UNDERGROUND, g.player.pos, "the deep works")
	under.attention = 0.4
	var b := sys.call("book", under.id) as Dictionary
	b["stake"] = 7
	b["surveyed"] = true
	# Something taken on the SURFACE that happens to be prop 7 up here.
	g.world.depleted[7] = true
	sys.call("pass_now")
	near(under.attention, 0.4, 1e-4, "the yard below lost nothing")
	check(bool(b["surveyed"]), "and the plan still has its survey of it")
	eq(int(b["stake"]), 7, "the stake is still in the ground where it was driven")
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
