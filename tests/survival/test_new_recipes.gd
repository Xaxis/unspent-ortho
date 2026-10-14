extends TestCase
## A NEW RECIPE IS SAID WHEN IT IS FOUND. The make page lists a recipe once all
## it wants has been carried (Crafting.known), and nothing said when that
## happened: new rows were found by chance. The first carry of the last thing a
## recipe wants says what it makes and where, once.

const Sx := preload("res://tests/save/save_fixture.gd")

var _said: Array[String] = []


func _hear(line: String) -> void:
	_said.append(line)


func test_the_first_carry_of_what_a_recipe_wanted_last_says_it() -> void:
	Sx.use_root("new-recipes")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11", "--weather=clear:0"])
	await tree.process_frame
	_said.clear()
	Events.message.connect(_hear)
	check(not g.inventory.has_handled(&"resin"), "no resin carried yet")
	g.inventory.add(&"resin")
	var line := ""
	for l in _said:
		if l.begins_with("Something new to make"):
			line = l
	check(line.contains("oil") and line.contains("at the fire"), "resin found: it says oil, at the fire: %s" % line)
	_said.clear()
	g.inventory.add(&"resin")
	check(not _said.any(func(l: String) -> bool: return l.begins_with("Something new")), "a second resin says nothing new")
	# A load sets what has been carried all at once: a mark, not a find.
	for id: StringName in [&"rag", &"pitch", &"timber", &"scrap"]:
		g.inventory.handled[id] = true
	g.inventory.changed.emit()
	check(not _said.any(func(l: String) -> bool: return l.begins_with("Something new")), "many at once is not a find: %s" % str(_said))
	Events.message.disconnect(_hear)
	Sx.end(g)
