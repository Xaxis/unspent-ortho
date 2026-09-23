extends TestCase
## The holding as a running game has it (docs/VISION.md): put up from what is
## carried, felt by a body that walks into it, broken by a hand this package
## knows nothing about, mended, and still standing after a save and a load.

const Sx := preload("res://tests/save/save_fixture.gd")


func holdings(g: Game) -> Node:
	return Sx.system(g, "46_settlements")


## Enough of everything for any piece in the table, so a test is never about the
## creel unless it says it is.
const FULL := "--give=driftwood:12,rag:12,timber:12,scrap:12,stone:12,deadwood:12,reeds:12,pitch:4,iron:4,copper:4,berries:6"


func test_a_piece_goes_up_out_of_the_creel_and_founds_a_place() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var sys := holdings(g)
	var founded: Array[int] = []
	var built: Array[int] = []
	Events.settlement_founded.connect(func(id: int) -> void: founded.append(id))
	Events.structure_built.connect(func(_sid: int, pid: int) -> void: built.append(pid))
	var timber := g.inventory.count(&"timber")
	var clock := g.clock.minutes
	var said := String(sys.call("build_here", StructureKind.PALISADE))
	check(not said.begins_with("!"), "it went up: %s" % said)
	eq(founded.size(), 1, "the first piece founds the holding")
	eq(built.size(), 1, "and says a piece was built")
	eq(g.inventory.count(&"timber"), timber - 1, "the timber came out of the creel")
	gt(g.clock.minutes - clock, 20.0, "and it took the best part of half an hour")
	var place: Settlement = sys.call("here")
	check(place != null, "the player is standing in it")
	eq(place.pieces.size(), 1, "one piece standing")
	# A second piece joins the same holding rather than founding another.
	@warning_ignore("return_value_discarded")
	sys.call("build_here", StructureKind.LEAN_TO)
	eq(founded.size(), 1, "still one holding")
	eq((sys.call("here") as Settlement).pieces.size(), 2, "with two pieces in it")
	Sx.end(g)


func test_a_piece_nobody_can_pay_for_is_refused_by_name() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128"])
	await frames(3)
	var said := String(holdings(g).call("build_here", StructureKind.HUT))
	check(said.begins_with("!"), "refused")
	check(said.contains("timber"), "and says what is short: %s" % said)
	check((holdings(g).call("here") as Settlement) == null, "nothing was founded on a refusal")
	Sx.end(g)


func test_a_wall_stops_a_body_and_a_machine_s_eye() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var said := String(holdings(g).call("build_here", StructureKind.PLATE_WALL))
	check(not said.begins_with("!"), "the wall went up: %s" % said)
	var place: Settlement = holdings(g).call("here")
	var wall := place.pieces[0]
	# The footprint is in the collision grid without being a prop of the world.
	var blockers := 0
	for q in g.query.props_near(wall.pos, 1.0):
		if q.id < 0 and q.solid > 0.0:
			blockers += 1
	eq(blockers, 1, "one footprint where the wall stands")
	check(not g.world.props.any(func(p: WorldProp) -> bool: return p.id < 0), "and it is no part of the world's props")
	# Walking into it from outside never reaches the middle of it.
	var from := wall.pos + Vector2(2.0, 0.0)
	var to := g.query.move_body(from, (wall.pos - from).normalized() * 4.0, Tuning.PLAYER_RADIUS)
	gt(to.distance_to(wall.pos), StructureKind.solid(StructureKind.PLATE_WALL) * 0.9, "a body is stopped by it")
	gt(StructureKind.solid(StructureKind.PLATE_WALL), Senses.BLOCKING_SOLID, "and it is thick enough to see through")
	Sx.end(g)


func test_a_blow_from_outside_this_package_is_noticed_and_said_once() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var sys := holdings(g)
	@warning_ignore("return_value_discarded")
	sys.call("build_here", StructureKind.PALISADE)
	var place: Settlement = sys.call("here")
	var wall := place.pieces[0]
	var hurt: Array[float] = []
	var gone: Array[int] = []
	Events.structure_damaged.connect(func(_s: int, _p: int, amount: float) -> void: hurt.append(amount))
	Events.structure_destroyed.connect(func(_s: int, pid: int) -> void: gone.append(pid))
	# The raids package holds a Settlement, not this system: it calls straight
	# through, and the settlement package still has to notice.
	check(not place.damage_structure(wall.id, 4.0), "four is not the end of a palisade")
	await frames(4)
	eq(hurt.size(), 1, "the blow was noticed")
	near(hurt[0], 4.0, 0.2, "and measured")
	check(place.damage_structure(wall.id, 20.0), "that finishes it")
	await frames(4)
	eq(gone.size(), 1, "destroyed, once")
	await frames(4)
	eq(gone.size(), 1, "and never again")
	Sx.end(g)


func test_a_wreck_is_cleared_for_half_of_what_it_cost() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var sys := holdings(g)
	@warning_ignore("return_value_discarded")
	sys.call("build_here", StructureKind.PLATE_WALL)
	var place: Settlement = sys.call("here")
	var wall := place.pieces[0]
	place.destroy_structure(wall.id)
	await frames(4)
	var scrap := g.inventory.count(&"scrap")
	var said := String(sys.call("tend", wall.id))
	check(not said.begins_with("!"), "cleared: %s" % said)
	eq(place.pieces.size(), 0, "the wreck is gone from the yard")
	eq(g.inventory.count(&"scrap"), scrap + 1, "and half its plate came back")
	Sx.end(g)


func test_a_piece_is_mended_by_hand_out_of_what_is_carried() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var sys := holdings(g)
	@warning_ignore("return_value_discarded")
	sys.call("build_here", StructureKind.PALISADE)
	var place: Settlement = sys.call("here")
	var wall := place.pieces[0]
	@warning_ignore("return_value_discarded")
	place.damage_structure(wall.id, 6.0)
	var was := wall.health
	var timber := g.inventory.count(&"timber")
	var said := String(sys.call("tend", wall.id))
	check(not said.begins_with("!"), "mended: %s" % said)
	gt(wall.health, was, "it stands better than it did")
	eq(g.inventory.count(&"timber"), timber - 1, "and a length of timber went into it")
	Sx.end(g)


func test_a_hearth_is_the_world_s_own_fire_and_goes_out_when_it_is_broken() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var sys := holdings(g)
	var said := String(sys.call("build_here", StructureKind.HEARTH))
	check(not said.begins_with("!"), "laid: %s" % said)
	var place: Settlement = sys.call("here")
	var hearth := place.pieces[0]
	var fire := g.query.nearest_prop(hearth.pos, 1.0, [PropKind.FIRE] as Array[int])
	check(fire != null, "a fire stands where the hearth is")
	check(Survival.stations_near(g).has(&"fire") or fire.pos.distance_to(g.player.pos) > Survival.STATION_REACH,
		"and it is the game's own fire, so it can be worked at")
	place.destroy_structure(hearth.id)
	await frames(4)
	check(g.world.depleted.has(fire.id), "broken, the fire is out")
	Sx.end(g)


func test_a_holding_comes_back_from_a_save_with_its_pieces_and_its_people() -> void:
	Sx.use_root("holding")
	var a := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,palisade"])
	await frames(3)
	var before: Settlement = holdings(a).call("here")
	check(before != null, "the staged holding is there")
	var pieces := before.pieces.size()
	gt(float(pieces), 2.0, "with its pieces")
	before.stores[&"berries"] = 4
	@warning_ignore("return_value_discarded")
	before.damage_structure(before.pieces[0].id, 2.0)
	var health := before.pieces[0].health
	var people := before.people.size()
	var saver := Sx.system(a, "05_save")
	eq(String(saver.call("save_to", 1)), "", "saved")
	check(SaveGame.registered(&"settlements"), "under its own key")
	Sx.end(a)

	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), "", "slot 1 boots")
	var b := Sx.game(tree, [], o)
	await frames(3)
	var after: Settlement = holdings(b).call("here")
	check(after != null, "the holding came back")
	eq(after.pieces.size(), pieces, "with every piece")
	near(after.pieces[0].health, health, 0.2, "still dented where it was dented")
	eq(int(after.stores.get(&"berries", 0)), 4, "and what it had laid by")
	eq(after.people.size(), people, "and the people who live there")
	# Its footprints are back in the grid, or a loaded wall would be a picture.
	var ghosts := 0
	for p in after.pieces:
		for q in b.query.props_near(p.pos, 0.6):
			if q.id < 0:
				ghosts += 1
	gt(float(ghosts), 0.0, "the footprints came back with the drawings")
	Sx.end(b)
	Sx.finish()


func test_the_holding_app_opens_on_its_own_key_and_builds_from_it() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var ui := Sx.system(g, "90_ui")
	Input.action_press(&"holding")
	await frames(4)
	Input.action_release(&"holding")
	await frames(4)
	var top: UiScreen = ui.call("top")
	check(top != null and top.screen_name == &"holding", "h opens the holding app")
	var screen := top as UiSettlementScreen
	screen.select(UiSettlementScreen.row_id(StructureKind.PALISADE))
	@warning_ignore("return_value_discarded")
	screen.handle(&"confirm")
	await frames(4)
	var place: Settlement = holdings(g).call("here")
	check(place != null and place.pieces.size() == 1, "a row on the page put a piece in the world")
	check(not screen.note.begins_with("Short"), "and said so rather than refusing: %s" % screen.note)
	Input.action_press(&"holding")
	await frames(4)
	Input.action_release(&"holding")
	await frames(4)
	check(ui.call("top") == null, "and h closes it again")
	Sx.end(g)


func test_time_away_reaches_the_holding_through_the_running_game() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=8", "--holding=plot,catchment,store"])
	await frames(3)
	var sys := holdings(g)
	var place: Settlement = sys.call("here")
	check(place != null and not place.people.is_empty(), "somebody came over to work the plot")
	place.stores.clear()
	# Six world hours, the way sleeping or a long walk buys them.
	g.clock.skip(360.0)
	sys.call("settle_up")
	gt(place.stored(), 0.0, "the plot was worked while nobody was watching")
	check(bool(sys.call("tour_seen", &"produced")), "and the holding says so")
	Sx.end(g)


func test_a_holding_belongs_to_the_realm_it_was_built_in() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", FULL])
	await frames(3)
	var sys := holdings(g)
	@warning_ignore("return_value_discarded")
	sys.call("build_here", StructureKind.PALISADE)
	var place: Settlement = sys.call("here")
	eq(place.realm, Realm.SURFACE, "put up on the surface, and it says so")
	eq((sys.call("all", Realm.SURFACE) as Array).size(), 1, "one holding in this realm")
	eq((sys.call("all", Realm.UNDERGROUND) as Array).size(), 0, "and none under it")
	check(sys.call("nearest", Realm.UNDERGROUND, g.player.pos) == null,
		"standing on the same coordinates a realm down finds nothing: a holding does not follow anybody through a shaft")
	Sx.end(g)
