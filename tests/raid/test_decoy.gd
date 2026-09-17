extends TestCase
## The raids half of the decoy mast (docs/VISION.md §9.3): what a machine does
## when a pole in a field shouts louder than the yard behind it.
##
## The decoy has no mask row. It does not hide the holding — it is read INSTEAD
## of it — so everything these hold is about ONE reading going somewhere else:
## where it was taken, where it has to be caught, and what it is worth when it
## lands. The rule they are written to protect is the one the piece could break:
## **a decoy is a decision, not a discount**. Five cheap masts round a yard have
## to be worth exactly one.

const Sx := preload("res://tests/save/save_fixture.gd")

const FULL := "--give=driftwood:12,rag:12,timber:12,scrap:12,stone:12,deadwood:12,reeds:12,pitch:4,iron:4,copper:4"


func raids(g: Game) -> Node:
	return Sx.system(g, "48_raids")


func holdings(g: Game) -> Node:
	return Sx.system(g, "46_settlements")


## Nothing on the coast: a test about a decoy is never about whatever the land
## happened to put out beside it.
func hush(g: Game) -> void:
	var mobs := Sx.system(g, "30_mobs")
	if mobs != null:
		var coast: Coast = mobs.get("coast")
		if coast != null:
			coast.spawning = false
			coast.rounds = false
	g.player.sim.clear_mobs()


## A holding loud enough to be worth reading: a mast with power and hands on it,
## which is the decision the whole system hangs off.
func loud_place(g: Game) -> Settlement:
	var h := holdings(g)
	var s: Settlement = h.call("found", g.world.realm, g.player.pos, "the works")
	var mast: Structure = h.call("place_piece", s, StructureKind.RADIO_MAST, g.player.pos + Vector2(2, 0), 0.0)
	mast.powered = true
	mast.staffed_by = 1
	s.night = 0.0
	return s


## A decoy standing out past the yard, where it is somewhere else.
func decoy_out(g: Game, s: Settlement, turn: float = 0.0, far: float = 3.0) -> Structure:
	var at := s.centre + Vector2.from_angle(turn) * (Settlement.LURE_APART + far)
	return holdings(g).call("place_piece", s, StructureKind.DECOY_MAST, at, 0.0) as Structure


## The reading a body is holding right now, or null.
func held_by(sys: Node, m: MobState) -> Notice:
	for n: Notice in (sys.get("notices") as Array):
		if n.mob_id == m.id:
			return n
	return null


## One whole reading, taken and carried over the horizon: a body stands where it
## is put, reads whatever is loudest from there, and walks away with it.
func one_reading(g: Game, sys: Node, from: Vector2) -> Notice:
	var m := g.player.sim.add_mob(&"clerk", from)
	sys.call("pass_now")
	var n := held_by(sys, m)
	if n == null:
		g.player.sim.remove_mob(m)
		return null
	m.pos = n.at + Vector2(Notices.GOT_AWAY + 4.0, 0.0)
	sys.call("pass_now")
	g.player.sim.remove_mob(m)
	return n


# --- what is read ---------------------------------------------------------------

func test_a_machine_at_the_decoy_reads_the_decoy_and_walks_off_with_that() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", FULL])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := loud_place(g)
	var mast := decoy_out(g, s)
	# A clerk standing under the pole. It can hear the yard from here — the mast
	# carries the whole way — and the pole is louder, so the pole is what it files.
	var m := g.player.sim.add_mob(&"clerk", mast.pos + Vector2(1, 0))
	sys.call("pass_now")
	var n := held_by(sys, m)
	check(n != null, "it read something")
	eq(n.lure, mast.id, "and what it read was the decoy")
	eq(n.at, mast.pos, "the reading was taken where the decoy stands, not where the people are")
	eq((sys.get("notices") as Array).size(), 1, "one reading, not one per thing it could hear")
	check(bool(sys.call("tour_seen", "lured")), "the plan says the decoy was read")
	# And it does not walk on and read the yard as well: the READ_AGAIN key is the
	# holding's, so this body has had its look at this place.
	sys.call("pass_now")
	eq((sys.get("notices") as Array).size(), 1, "still one")
	Sx.end(g)


func test_the_yard_is_still_read_by_anything_that_is_not_standing_at_the_decoy() -> void:
	# A decoy is elsewhere, and elsewhere only helps where it is. A machine that
	# walks past the fence reads the fence, which is what keeps the piece a
	# decision about WHERE rather than a switch that turns the holding off.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", FULL])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := loud_place(g)
	var mast := decoy_out(g, s)
	var m := g.player.sim.add_mob(&"clerk", s.centre + Vector2(2, 0))
	sys.call("pass_now")
	var n := held_by(sys, m)
	check(n != null, "it read something")
	eq(n.lure, -1, "under the holding's nose it is the holding that is read")
	eq(n.at, s.centre, "and the record is of the yard")
	check(mast.standing(), "with the decoy still standing out in the field")
	Sx.end(g)


func test_five_decoys_are_read_exactly_as_the_one_best_of_them_is() -> void:
	# The cap, and the reason for it. `Settlement.lures()` hands over every
	# standing decoy on purpose; if they added up, or if the weakest could win, a
	# ring of five cheap masts would drive the plan's attention into a field for
	# the price of six timber and the loudest answer in the game would be the one
	# that costs least.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", FULL])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := loud_place(g)
	var best := decoy_out(g, s)
	var stand := best.pos + Vector2(1, 0)
	# Four more, half broken, all round the same yard and all within reach of the
	# same machine.
	for i in 4:
		var p := decoy_out(g, s, 0.5 + float(i) * 0.4, 4.0)
		p.damage(p.max_health * 0.6)
	eq(s.lures().size(), 5, "five of them are standing")
	var five := one_reading(g, sys, stand)
	check(five != null, "the ring was read")
	eq(five.lure, best.id, "and it was read off the whole one")
	var with_five := s.attention
	gt(with_five, 0.0, "it got home")
	# Now the same holding with only the best of them, read by another body from
	# exactly the same spot.
	s.attention = 0.0
	for p in s.lures():
		if p.id != best.id:
			s.destroy_structure(p.id)
	eq(s.lures().size(), 1, "one of them is standing")
	var one := one_reading(g, sys, stand)
	check(one != null, "and it was read")
	eq(one.lure, best.id, "off the same pole")
	gt(five.strength, one.strength - 1e-5,
		"five are read no more weakly than one: %0.4f against %0.4f" % [five.strength, one.strength])
	near(s.attention, with_five, 1e-5,
		"and they cost the plan exactly the same: %0.4f against %0.4f" % [with_five, s.attention])
	Sx.end(g)


# --- what it is worth ------------------------------------------------------------

func test_a_record_off_a_decoy_files_a_quarter_of_what_the_yard_would_have() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", FULL])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := loud_place(g)
	var mast := decoy_out(g, s)
	var lured := one_reading(g, sys, mast.pos + Vector2(1, 0))
	check(lured != null and lured.lure == mast.id, "a reading was taken off the decoy")
	var decoyed := s.attention
	gt(decoyed, 0.0, "the plan heard something: a decoy is not a place nobody files")
	# The same holding, read straight, with nothing standing in the field.
	s.attention = 0.0
	s.destroy_structure(mast.id)
	var straight := one_reading(g, sys, mast.pos + Vector2(1, 0))
	check(straight != null and straight.lure == -1, "and now the yard itself")
	var plain := s.attention
	gt(plain, decoyed, "a pole in a field is worth less than the place: %0.4f against %0.4f" % [decoyed, plain])
	Sx.end(g)


## The soonest one body reads one place again (48_raids.READ_AGAIN): the pace a
## holding really heats up at, and the pace these measurements are taken in.
const READ_PACE := 120.0


func test_a_decoy_is_what_stands_between_a_holding_and_a_siege() -> void:
	# The measurement the piece is built for: a loud holding read over and over
	# from the same spot, once with a mast in the field and once without, and how
	# much WORLD TIME each takes to reach the top of the scale. Nothing in it is a
	# clock — every step is a machine that came, read and got away — and the hours
	# only appear because attention also cools while nothing is looking, which is
	# the thing a decoy makes the plan spend its time against.
	#
	# Nothing is SENT while this runs (`rules.raids`): a probe arriving would spend
	# the very attention being counted, and this is about what a reading is worth,
	# not about surviving the road to a siege.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", FULL])
	await frames(3)
	hush(g)
	@warning_ignore("return_value_discarded")
	GameConfig.set_value("rules.raids", false)
	var sys := raids(g)
	var s := loud_place(g)
	var mast := decoy_out(g, s)
	var stand := mast.pos + Vector2(1, 0)
	var with_decoy := _hours_to_siege(g, sys, s, stand)
	s.attention = 0.0
	s.destroy_structure(mast.id)
	var without := _hours_to_siege(g, sys, s, stand)
	GameConfig.clear()
	gt(without, 0.0, "a holding read from the same spot reaches a siege at all")
	gt(with_decoy, without * 2.0,
		"and a decoy standing buys more than twice the time: %0.1f world hours against %0.1f"
			% [with_decoy, without])
	Sx.end(g)


## World hours of readings taken from `stand` before the holding is due a siege,
## one reading every READ_PACE minutes. -1 if it never gets there.
func _hours_to_siege(g: Game, sys: Node, s: Settlement, stand: Vector2) -> float:
	var began := g.clock.minutes
	for i in 900:
		if RaidStage.due_at(s.attention) >= RaidStage.ORDER.size() - 1:
			return (g.clock.minutes - began) / 60.0
		if one_reading(g, sys, stand) == null:
			return -1.0
		g.clock.skip(READ_PACE)
	return -1.0


# --- it is still a thing in the world --------------------------------------------

func test_a_lured_record_is_caught_at_the_decoy_and_nowhere_else() -> void:
	# Killing, jamming and taking the record still work, and they work AT THE
	# DECOY: that is where the body stood, so that is the yard it has to get clear
	# of. A player who built one and then guarded their own fence is guarding the
	# wrong ground, and that is the trade the piece makes.
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", FULL])
	await frames(3)
	hush(g)
	var sys := raids(g)
	var s := loud_place(g)
	var mast := decoy_out(g, s)
	var m := g.player.sim.add_mob(&"clerk", mast.pos + Vector2(1, 0))
	sys.call("pass_now")
	var n := held_by(sys, m)
	check(n != null and n.lure == mast.id, "a reading was taken off the decoy")
	check(not Notices.clear_of_holding(n, mast.pos + Vector2(2, 0)), "beside the pole it is still catchable")
	check(Notices.clear_of_holding(n, mast.pos + Vector2(Notices.CLEAR_OF + 1.0, 0)),
		"and out past the pole it is gone, whatever the fence is doing")
	# Put it down where it stands, with somebody there to pick the record up.
	g.player.pos = mast.pos
	g.player.hero.pos = g.player.pos
	var records := g.inventory.count(RaidSpoils.RECORD_ITEM)
	m.alive = false
	m.health = 0
	sys.call("pass_now")
	check(bool(sys.call("tour_seen", "stopped")), "the reading was stopped")
	eq(g.inventory.count(RaidSpoils.RECORD_ITEM), records + 1, "and the record is in the creel")
	eq(s.attention, 0.0, "the holding is no worse off than before the pole was read")
	Sx.end(g)


func test_a_lured_record_comes_back_off_the_disc_still_about_the_decoy() -> void:
	var n := Notice.new()
	n.id = 9
	n.settlement_id = 3
	n.lure = 17
	n.at = Vector2(88.5, 12.25)
	n.channel = &"light"
	n.strength = 0.4
	var back := Notice.from_dict(JSON.parse_string(JSON.stringify(n.as_dict())) as Dictionary)
	eq(back.lure, 17, "which piece was read instead of the place")
	eq(back.at, Vector2(88.5, 12.25), "and the ground it was read on")
	# A save from before the piece existed is a reading of the yard, which is what
	# every reading in every old game was.
	var old := Notice.from_dict({"id": 1, "settlement": 1})
	eq(old.lure, -1, "an older save carries a record of the place itself")
