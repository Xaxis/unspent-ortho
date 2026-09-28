extends TestCase
## A KEEPER GOES THROUGH A WOOD (Roster `breaks`). A body three tiles wide is
## moved at the player's radius (FightSim.move_radius), so without this it drew
## straight through the trees it walked among. What its drawn body walks into of
## the kinds its row declares goes down: taken for good (`world.depleted`, saved as
## any taken prop is), and said (`felled`), so the view throws it over. A machine's
## rule and a declared one: a harvester goes round, and so does the player.

const F := preload("res://tests/fight/fixture.gd")


func _walk_into_a_pine(kind: StringName) -> Dictionary:
	# A pine of the world's own, in its table before the sim's query is built
	# from it, as every scattered tree is.
	var w := F.flat_world(64)
	w.add_prop(WorldProp.new(9001, PropKind.PINE, Vector2(30.5, 20.5), 0.0, 1.0))
	var sim := F.make_sim(w, Vector2(40.5, 20.5))
	# Roused at the player standing past the pine: it comes the straight way.
	var m := sim.add_mob(kind, Vector2(26.5, 20.5))
	m.facing = 0.0
	m.aim = 0.0
	m.disturbed = true
	m.last_seen = sim.hero.pos
	m.set_mood(MobState.CHASING, sim.now)
	var felled := []
	for i in 400:
		sim.slices(1)
		for e in sim.drain():
			if e.type == &"felled":
				felled.append(e)
		if m.pos.x > 33.0:
			break
	return {"down": w.depleted.has(9001), "felled": felled, "past": m.pos.x > 31.5}


func test_a_keeper_fells_the_trees_it_walks_into() -> void:
	var r := _walk_into_a_pine(&"sentinel.snowfield")
	check(r.down, "the pine is taken, for good")
	eq((r.felled as Array).size(), 1, "and said, once")
	if not (r.felled as Array).is_empty():
		var e: Dictionary = r.felled[0]
		eq(int(e.kind), PropKind.PINE, "a pine")
		gt(float((e.dir as Vector2).x), 0.5, "thrown the way the keeper was going")
	check(r.past, "and the keeper went on through where it stood")
	check(Sentinels.is_keeper(Roster.row(&"sentinel.snowfield")) and not (Roster.row(&"sentinel.snowfield").get("breaks", []) as Array).is_empty(),
		"because its row declares it")


func test_a_body_that_does_not_declare_it_goes_round() -> void:
	var r := _walk_into_a_pine(&"harvester")
	check(not r.down, "a harvester leaves the pine standing")
	eq((r.felled as Array).size(), 0, "and nothing is felled")


func test_every_keeper_declares_the_wood_it_breaks() -> void:
	for kind: StringName in Roster.kinds():
		var row := Roster.row(kind)
		if not Sentinels.is_keeper(row):
			continue
		var breaks: Array = row.get("breaks", [])
		check(breaks.has("pine") and breaks.has("bush"), "%s breaks trees and shrubs" % kind)
		for name: Variant in breaks:
			check(PropKind.NAMES.has(str(name)), "%s breaks %s, a prop kind" % [kind, name])
