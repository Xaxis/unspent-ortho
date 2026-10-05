extends TestCase
## A body at his holding may be a villager's who came with him, and the folk let a
## villager's model go when that village streams out (35_folk `_stream`), whoever
## it stands for now. 46_settlements keeps its book of whom it drew, and it asks
## that book whether each body is still there to draw a new one where it is not:
## asking must not touch a freed model, since even a cast of one is an error.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_a_body_let_go_under_his_holding_is_drawn_again() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"])
	await frames(3)
	var h := Sx.system(g, "46_settlements")
	var at := g.player.pos + Vector2(3, 0)
	var home: Settlement = h.call(&"found", Realm.SURFACE, at)
	@warning_ignore("return_value_discarded")
	h.call(&"place_piece", home, StructureKind.HEARTH, at, 0.0)
	@warning_ignore("return_value_discarded")
	h.call(&"place_piece", home, StructureKind.LEAN_TO, at + Vector2(2, 0), 0.0)
	var who := home.take_person_id()
	home.people.append(who)
	await frames(60)
	var bodies: Dictionary = h.get("_bodies")
	var key := "%d:%d" % [home.id, who]
	var row: Dictionary = bodies.get(key, {})
	check(not row.is_empty() and is_instance_valid(row.get("model")), "his person is drawn while he stands by them")
	if not row.is_empty() and is_instance_valid(row.get("model")):
		# As 35_folk `_stream` lets a villager go when its village streams out: off
		# the folk's list, and its model freed.
		var list: Array = Sx.system(g, "folk").get("folk")
		list.erase(row)
		var gone: Node = row.model
		gone.queue_free()
		await frames(60)
		var now: Dictionary = bodies.get(key, {})
		check(not now.is_empty() and is_instance_valid(now.get("model")), "and drawn again once the folk let the body go")
	Sx.end(g)
