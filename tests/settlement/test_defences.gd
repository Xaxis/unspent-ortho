extends TestCase
## The two answers to being read that a player can BUILD (owner, 2026-09-17,
## docs/VISION.md): a spoofer that hides the whole place while it has power,
## and a decoy that hides nothing but is read in the place's stead from out past
## the yard. One piece buys one thing each, and these hold them to it.
##
## What a machine then does with a decoy's reading — whether it files it, and
## what it is worth — is the raids package's, and is tested there.

const Sx := preload("res://tests/save/save_fixture.gd")

const FULL := "--give=driftwood:12,rag:12,timber:12,scrap:12,stone:12,deadwood:12,reeds:12,pitch:4,iron:4,copper:4,record:2"


func _loud_place() -> Settlement:
	var s := Settlement.new(1)
	var mast := s.add(StructureKind.RADIO_MAST, Vector2.ZERO)
	mast.powered = true
	s.add(StructureKind.FORGE, Vector2(2, 0))
	return s


# --- the spoofer ---------------------------------------------------------------

func test_a_spoofer_with_power_in_it_hides_every_channel() -> void:
	var s := _loud_place()
	var seen := s.signature()
	var box := s.add(StructureKind.SPOOFER, Vector2(4, 0))
	box.powered = true
	var hidden := s.signature()
	lt(hidden.total(), seen.total() * 0.7, "the same town reads much quieter")
	for c: StringName in Signature.CHANNELS:
		check(hidden.get_channel(c) <= seen.get_channel(c) + 1e-5, "%s is never made louder by it" % c)


func test_a_spoofer_with_no_power_in_it_is_a_box_on_a_stake() -> void:
	var s := _loud_place()
	var seen := s.signature().total()
	s.add(StructureKind.SPOOFER, Vector2(4, 0))
	near(s.signature().total(), seen, 1e-5, "dark, it hides nothing at all")


func test_the_spoofer_wants_power_and_a_record_to_be_built() -> void:
	gt(StructureKind.draw_power(StructureKind.SPOOFER), 0.0, "it runs on a machine's power")
	check(StructureKind.cost(StructureKind.SPOOFER).has(&"record"),
		"and nobody can build one who has not taken a record off a carrier")
	check(StructureKind.buildable(StructureKind.SPOOFER), "and it is on the slate")
	var inv := Inventory.new()
	inv.add(&"copper", 4)
	inv.add(&"scrap", 4)
	var why := SettlementBuild.why_not(inv, StructureKind.SPOOFER)
	check(why.contains("filed record"), "short of the record, it says so by name: %s" % why)


func test_a_broken_spoofer_hides_nothing() -> void:
	var s := _loud_place()
	var seen := s.signature().total()
	var box := s.add(StructureKind.SPOOFER, Vector2(4, 0))
	box.powered = true
	s.destroy_structure(box.id)
	near(s.signature().total(), seen, 1e-5, "wrecked, the place answers for itself again")


# --- the decoy -----------------------------------------------------------------

func test_a_decoy_hides_nothing_where_the_holding_stands() -> void:
	var s := _loud_place()
	var seen := s.signature().total()
	s.add(StructureKind.DECOY_MAST, Vector2(16, 0))
	near(s.signature().total(), seen, 1e-5, "one piece buys one thing, and this one is not a mask")
	check(not StructureKind.masks(StructureKind.DECOY_MAST), "it declares no mask")
	check(StructureKind.buildable(StructureKind.DECOY_MAST), "and it is on the slate")


func test_a_decoy_in_the_yard_is_the_yard() -> void:
	var s := _loud_place()
	s.add(StructureKind.DECOY_MAST, Vector2(Settlement.LURE_APART * 0.5, 0))
	eq(s.lures().size(), 0, "inside the yard it lures nothing")
	var out := s.add(StructureKind.DECOY_MAST, Vector2(Settlement.LURE_APART + 2.0, 0))
	eq(s.lures().size(), 1, "out past it, it does")
	eq(s.lures()[0].id, out.id, "and it is the one out past it")


func test_a_decoy_shouts_what_the_holding_gives_away() -> void:
	var s := _loud_place()
	var decoy := s.add(StructureKind.DECOY_MAST, Vector2(16, 0))
	var loud := s.signature().loudest()
	var shout := s.lure_signature(decoy)
	eq(shout.loudest(), loud, "the same account of the place")
	near(shout.get_channel(loud), StructureKind.lure(StructureKind.DECOY_MAST), 1e-4,
		"at the decoy's own strength, whatever the place itself reads")
	for c: StringName in Signature.CHANNELS:
		if c != loud:
			near(shout.get_channel(c), 0.0, 1e-6, "and on no other channel (%s)" % c)


func test_a_decoy_for_a_place_giving_nothing_away_shouts_by_the_hour() -> void:
	var s := Settlement.new(1)
	s.add(StructureKind.HUT, Vector2.ZERO)
	var decoy := s.add(StructureKind.DECOY_MAST, Vector2(16, 0))
	s.night = 1.0
	eq(s.lure_signature(decoy).loudest(), &"light", "by night it is a light")
	s.night = 0.0
	eq(s.lure_signature(decoy).loudest(), &"noise", "by day a rattle, since a light at noon is nothing")


func test_a_decoy_nobody_keeps_up_shouts_quieter_and_a_fallen_one_not_at_all() -> void:
	var s := _loud_place()
	var decoy := s.add(StructureKind.DECOY_MAST, Vector2(16, 0))
	var whole := s.lure_signature(decoy).total()
	@warning_ignore("return_value_discarded")
	s.damage_structure(decoy.id, decoy.max_health * 0.6)
	lt(s.lure_signature(decoy).total(), whole, "torn, it is less of a lure")
	s.destroy_structure(decoy.id)
	eq(s.lures().size(), 0, "down, it is nowhere")
	near(s.lure_signature(decoy).total(), 0.0, 1e-6, "and says nothing")


# --- drawn ---------------------------------------------------------------------

func test_both_are_drawn_whole_and_wrecked() -> void:
	for kind: int in [StructureKind.DECOY_MAST, StructureKind.SPOOFER]:
		check(StructureModel.drawn(kind), "%s is drawn" % StructureKind.display_name(kind))
		for broken: bool in [false, true]:
			for lit: bool in [false, true]:
				var meshes := StructureModel._meshes(kind, 5, broken, lit)
				var made := meshes[0] as ArrayMesh
				var found := meshes[1] as ArrayMesh
				check(made != null and made.get_surface_count() > 0,
					"%s%s has a hand's half" % [StructureKind.display_name(kind), " wrecked" if broken else ""])
				check(found != null and found.get_surface_count() > 0,
					"%s%s has a machine's half" % [StructureKind.display_name(kind), " wrecked" if broken else ""])


# --- in a running game ---------------------------------------------------------

func holdings(g: Game) -> Node:
	return Sx.system(g, "46_settlements")


## Walk the player out from the holding until a decoy could go up: the ground
## round a spawn is not all level, so the test asks the world rather than naming
## a tile.
func _walk_out(g: Game, from: Vector2) -> bool:
	var sys := holdings(g)
	for far: float in [14.0, 16.0, 18.0, 20.0]:
		for i in 16:
			var a := TAU * float(i) / 16.0
			var at := from + Vector2.from_angle(a) * far
			if not g.query.standable(floori(at.x), floori(at.y)):
				continue
			g.player.pos = at
			g.player.hero.pos = at
			if String(sys.call("why_not_here", StructureKind.DECOY_MAST)) == "":
				return true
	return false


func test_a_decoy_goes_up_only_out_past_a_place_that_exists() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var sys := holdings(g)
	var why := String(sys.call("why_not_here", StructureKind.DECOY_MAST))
	check(why.contains("stand for somewhere"), "with no holding it is refused by name: %s" % why)
	@warning_ignore("return_value_discarded")
	sys.call("build_here", StructureKind.HUT)
	var place: Settlement = sys.call("here")
	why = String(sys.call("why_not_here", StructureKind.DECOY_MAST))
	check(why.contains("yard"), "in the yard it is refused by name: %s" % why)
	var centre := place.centre
	check(_walk_out(g, centre), "somewhere out past the yard it can go up")
	var said := String(sys.call("build_here", StructureKind.DECOY_MAST))
	check(not said.begins_with("!"), "and it does: %s" % said)
	eq(place.pieces.size(), 2, "it joined the holding it stands for")
	near(place.centre.x, centre.x, 1e-4, "and the centre did not follow it out into the field")
	near(place.centre.y, centre.y, 1e-4, "on either axis")
	eq(place.lures().size(), 1, "it is a lure")
	Sx.end(g)


func test_a_fallen_decoy_is_said_because_nothing_else_would_say_it() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var sys := holdings(g)
	@warning_ignore("return_value_discarded")
	sys.call("build_here", StructureKind.HUT)
	var place: Settlement = sys.call("here")
	check(_walk_out(g, place.centre), "room for a decoy")
	@warning_ignore("return_value_discarded")
	sys.call("build_here", StructureKind.DECOY_MAST)
	var decoy: Structure = place.lures()[0] if not place.lures().is_empty() else null
	check(decoy != null, "a decoy stands")
	var said: Array[String] = []
	var hear := func(text: String) -> void: said.append(text)
	Events.message.connect(hear)
	place.destroy_structure(decoy.id)
	await frames(4)
	Events.message.disconnect(hear)
	check(said.any(func(t: String) -> bool: return t.contains("decoy is down")), "the glass says it fell: %s" % str(said))
	Sx.end(g)


func test_somebody_lost_to_an_outside_hand_leaves_the_books_through_one_door() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var sys := holdings(g)
	var place: Settlement = sys.call("found", Realm.SURFACE, g.player.pos)
	var plot: Structure = sys.call("place_piece", place, StructureKind.PLOT, g.player.pos + Vector2(2, 0))
	var who := place.take_person_id()
	place.people.append(who)
	place.looks[who] = 99
	plot.staffed_by = who
	sys.call("lose_person", place, who)
	check(not place.people.has(who), "off the holding's people")
	check(not place.looks.has(who), "their look forgotten")
	eq(plot.staffed_by, -1, "and the plot they were on stands empty")
	Sx.end(g)
