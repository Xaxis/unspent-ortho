extends TestCase
## The ruling the whole package stands on: **a settlement is engaged because of
## what it did, never because of a clock** (docs/VISION.md, owner).
##
## These tests name that rule rather than testing round it. Every rise has a
## cause a player could have seen; time on its own only ever makes a place
## safer; and a record that was stopped raises nothing at all.


func _holding(pieces: Array[int]) -> Settlement:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(50, 50), "the holding")
	for kind: int in pieces:
		s.add(kind, Vector2(50, 50)).powered = true
	return s


# --- the ruling ---------------------------------------------------------------

func test_hours_alone_never_raise_attention() -> void:
	# A place that gives off nothing a machine wants and is never read: a week
	# of world time may not put a single point on it.
	var quiet := Attention.cooled(0.0, 24.0 * 7.0, false, false)
	eq(quiet, 0.0, "a week of nothing is still nothing")
	# And a place that IS loud, but with nothing running that the player stole:
	# the hours still take attention off rather than putting it on.
	var was := 0.5
	var after := Attention.cooled(was, 12.0, false, false)
	lt(after, was, "twelve quiet hours cool a holding")
	gt(after, 0.0, "and do not wipe it: the plan forgets slowly")


func test_the_only_thing_hours_can_add_is_technology_the_player_chose_to_run() -> void:
	# No stolen technology in the walls: hours add nothing whatever.
	eq(Attention.from_found_tech(0.3, 0.0, 48.0), 0.3, "nothing found running, nothing added")
	# The stolen cell is found_tech 1.0, the loudest thing in the game.
	var cell := Attention.from_found_tech(0.0, 1.0, 10.0)
	gt(cell, 0.0, "a stolen cell costs by the hour it is left on")
	near(cell, Attention.of(&"found_tech") * 10.0, 1e-5, "exactly what the table says")
	# And it is a thing the player built, which the slate already draws: a
	# holding with a cell in it is one line on its own page.
	var loud := _holding([StructureKind.STOLEN_CELL] as Array[int])
	gt(loud.signature().found_tech, 0.9, "the slate says so before the plan does")


func test_every_rise_is_one_of_the_declared_causes() -> void:
	for cause: StringName in Attention.CAUSES:
		var v := Attention.raised(0.4, cause)
		if Attention.of(cause) > 0.0:
			gt(v, 0.4, "%s raises" % cause)
		else:
			lt(v, 0.4001, "%s never raises" % cause)
	# Anything nobody declared moves nothing. There is no default cause, so a
	# typo in another package can never quietly file a holding.
	eq(Attention.raised(0.4, &"tuesday"), 0.4, "an undeclared cause does nothing")
	eq(Attention.of(&"tuesday"), 0.0, "and is worth nothing")


func test_the_unit_is_one_notice_and_the_scale_ends_at_the_keeper() -> void:
	eq(Attention.of(&"notice"), Attention.NOTICE_FULL, "the unit is one filed record")
	eq(RaidStage.AT[RaidStage.AT.size() - 1], 1.0, "and 1.0 is the keeper coming")
	var n := ceili(1.0 / Attention.NOTICE_FULL)
	eq(n, 12, "twelve full records, unanswered, reach the top of the scale")
	# Every step of the scale is reachable from below and in order.
	var last := -1.0
	for at: float in RaidStage.AT:
		gt(at, last, "the steps come in order")
		last = at


func test_a_record_that_was_stopped_raises_nothing() -> void:
	var s := _holding([StructureKind.RADIO_MAST] as Array[int])
	s.attention = 0.3
	# What a reading is worth if it gets home.
	var n := Notice.new()
	n.strength = 1.0
	n.carrier = &"clerk"
	gt(Notices.worth(n), 0.0, "a clerk's reading is worth something")
	# Stopped is the opposite of filed, and it is worth LESS than nothing: the
	# plan has lost what it thought it knew.
	lt(Attention.of(&"stopped"), 0.0, "stopping one takes attention off")
	var after := Attention.raised(s.attention, &"stopped")
	lt(after, 0.3, "a record destroyed before it travelled brings the place down")


# --- what brings it down ------------------------------------------------------

func test_a_dark_night_cools_faster_than_a_lit_one() -> void:
	var lit := Attention.cooled(0.6, 8.0, false, false)
	var dark := Attention.cooled(0.6, 8.0, true, false)
	lt(dark, lit, "a holding running dark is forgotten faster")


func test_a_spoofed_signature_and_a_mask_both_cool_it() -> void:
	# A DECOY is not one of these and never was: it masks nothing where the
	# holding stands (StructureKind.SIGNS has no mask row for it), it is read in
	# the holding's place, and what it buys is `Attention.LURED` at the moment a
	# reading lands. What cools a place while nobody is reading it is a spoofer,
	# netting or shutters.
	var plain := Attention.cooled(0.6, 6.0, false, false)
	var spoofed := Attention.cooled(0.6, 6.0, false, true)
	var masked := Attention.cooled(0.6, 6.0, false, false, 1.0)
	lt(spoofed, plain, "the signet answers for the place")
	lt(masked, plain, "a mask standing in it goes on working")
	lt(spoofed, masked, "and the signet is the stronger of the two")


func test_a_reading_taken_off_a_decoy_is_worth_a_quarter_of_a_real_one() -> void:
	# The decoy's whole bargain: the plan still hears that something is out here,
	# and what it has an account of is a pole in a field.
	gt(Attention.LURED, 0.0, "a decoy is not a place that is never filed")
	lt(Attention.LURED, 1.0, "and it is not the real thing either")
	near(Attention.of(&"lured"), Attention.of(&"notice") * Attention.LURED, 1e-6,
		"the cause is the notice cause, at a quarter")
	# So four decoyed records are one real one, which is what the piece costs the
	# plan in walking and what it buys the player in time.
	var real := Attention.raised(0.0, &"notice")
	var decoyed := 0.0
	for i in 4:
		decoyed = Attention.raised(decoyed, &"lured")
	near(decoyed, real, 1e-6, "four off a mast in a field are one off the yard")


func test_a_raid_spends_what_brought_it() -> void:
	gt(RaidStage.spends(RaidStage.RAID), 0.0, "a raid spends attention")
	gt(RaidStage.spends(RaidStage.SIEGE), RaidStage.spends(RaidStage.RAID), "a siege spends more")
	eq(RaidStage.spends(RaidStage.SURVEY), 0.0,
		"a survey spends nothing: a place that has been looked at goes on heating up")


func test_pressure_is_words_and_never_a_number_to_optimise() -> void:
	# The holding app already draws what a machine HEARS; this is the only other
	# reading and it is deliberately coarse (owner, docs/VISION.md).
	var said: Array[StringName] = []
	for v: float in [0.0, 0.15, 0.3, 0.5, 0.8, 1.0]:
		var p := Attention.pressure(v)
		check(p != &"", "%0.2f reads as something" % v)
		if not said.has(p):
			said.append(p)
	gt(float(said.size()), 3.0, "and it says more than two things")
	eq(Attention.pressure(1.0), &"condemned", "the top of the scale has a name")
