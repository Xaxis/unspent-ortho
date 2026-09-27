extends TestCase
## WHAT YOU BUILD, AND WHERE YOU FALL, IS NOTICED (SETTLE.md S2).
##   - Each piece built raises the region's interference (`&"built"`), by how
##     loud the piece is (StructureKind.loudness): a turret more than a lean-to.
##   - Put down or carried off within Outcomes.CARRIED_HOME of your own holding,
##     the machine that had you read the place: the holding's attention rises by
##     one notice -- ONCE. A reading of it already in flight is that same
##     reading, and files over the lost hours on its own; the carry adds nothing
##     on top of it.

const Sx := preload("res://tests/save/save_fixture.gd")


func _game() -> Game:
	Sx.use_root("noticed")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11",
		"--give=driftwood:12,rag:4,stone:6,deadwood:4,scrap:12,copper:4,iron:2,rep_light:2,timber:4"])
	Sx.system(g, "30_mobs").get("coast").set("spawning", false)
	g.player.sim.clear_mobs()
	return g


func test_a_louder_piece_is_noticed_more() -> void:
	gt(StructureKind.loudness(StructureKind.TURRET), StructureKind.loudness(StructureKind.LEAN_TO) * 2.0, "a turret is louder than a lean-to")
	var lean: float = await _built(StructureKind.LEAN_TO)
	var turret: float = await _built(StructureKind.TURRET)
	gt(lean, 0.0, "building a lean-to is noticed (%.3f), and still is when the work is done" % lean)
	gt(turret, lean * 2.0, "a turret more than twice as much (%.3f against %.3f)" % [turret, lean])


## The region's interference once `kind` has gone up on a fresh coast, with the
## hours the work took already gone by and the game run on a few frames: the
## hours of the work must not cool away the news of the work that took them.
func _built(kind: int) -> float:
	var g := _game()
	var inter: Interference = Sx.system(g, "32_disposition").get("interference")
	var net := Interference.network(g.world, g.player.pos)
	var v0 := inter.value(net)
	var r: String = Sx.system(g, "46_settlements").call("build_here", kind)
	check(not r.begins_with("!"), "%s went up: %s" % [StructureKind.display_name(kind), r])
	await frames(20)
	var v := inter.value(net) - v0
	Sx.end(g)
	Sx.finish()
	return v


func test_taken_near_your_holding_it_is_read_once() -> void:
	var g := _game()
	var set := Sx.system(g, "46_settlements")
	var raids := Sx.system(g, "48_raids")
	var home: Settlement = set.call("found", set.call("realm_here"), g.player.pos + Vector2(3, 0))
	var a0 := home.attention
	Events.fight_ended.emit(&"downed")
	var a1 := home.attention
	near(a1 - a0, Attention.NOTICE_FULL * float(raids.call("pace")), 1e-4, "downed beside it: one notice")
	# A reading of it already on its way home is that same reading.
	var n := Notice.new()
	n.settlement_id = home.id
	(raids.get("notices") as Array).append(n)
	Events.fight_ended.emit(&"carried")
	near(home.attention, a1, 1e-4, "with a reading in flight the carry adds nothing on top")
	Sx.end(g)
	Sx.finish()


func test_taken_far_from_your_holding_it_is_not_read() -> void:
	var g := _game()
	var set := Sx.system(g, "46_settlements")
	var home: Settlement = set.call("found", set.call("realm_here"), g.player.pos + Vector2(Outcomes.CARRIED_HOME + 5.0, 0))
	Events.fight_ended.emit(&"carried")
	eq(home.attention, 0.0, "nothing past reach")
	Sx.end(g)
	Sx.finish()
