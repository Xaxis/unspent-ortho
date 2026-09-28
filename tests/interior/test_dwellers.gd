extends TestCase
## A PERSON WHO LIVES IN A ROOM (21_doors DWELLER): a resident who is no machine
## but somebody, drawn where the recipe stood them, and talked to by the use key
## as a villager is. Asked of the reader in a face settlement on seed 1: home
## when the player comes in, the one the key answers when faced, home again
## after going out and back in, and after a save made inside and loaded.

const Sx := preload("res://tests/save/save_fixture.gd")


func _face_hold(g: Game) -> Threshold:
	for t: Threshold in Interiors.thresholds(g.world):
		if t.kind == &"face_hold":
			return t
	return null


func _home(d: Node, what: String) -> Dictionary:
	var rows: Array = d.call(&"dweller_rows")
	eq(rows.size(), 1, "one person lives here (%s)" % what)
	if rows.size() != 1:
		return {}
	var row: Dictionary = rows[0]
	var model: Node3D = row.model
	check(is_instance_valid(model) and model.is_inside_tree(), "and is drawn (%s)" % what)
	return row


func test_a_dweller_is_home_is_talked_to_and_stays_home() -> void:
	Sx.use_root("dwellers")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	var d := Sx.system(g, "21_doors")
	var t := _face_hold(g)
	check(t != null, "seed 1 has a face settlement")
	if t == null:
		Sx.end(g)
		Sx.finish()
		return
	eq((d.call(&"dweller_rows") as Array).size(), 0, "nobody is home to the player outside")
	await d.call(&"go_in", t)
	var row := _home(d, "on coming in")
	if row.is_empty():
		Sx.end(g)
		Sx.finish()
		return
	eq(row.household, &"reader", "the reader")
	var at: Vector2 = row.pos
	near(g.world.to_3d(at).distance_to((row.model as Node3D).position), 0.0, 0.01, "drawn where they stand")
	# Faced from a step off, the key answers them.
	var stand := at + Vector2.from_angle(float(row.facing)) * 1.0
	g.player.hero.pos = stand
	g.player.pos = stand
	g.player.facing = (at - stand).angle()
	var story := Sx.system(g, "49_story")
	var met: Dictionary = story.call(&"_person_in_front")
	check(not met.is_empty() and met.get("household", &"") == &"reader", "the use key answers the reader")
	await d.call(&"go_out")
	eq((d.call(&"dweller_rows") as Array).size(), 0, "and nobody outside again")
	await d.call(&"go_in", t)
	var again := _home(d, "on coming back")
	if not again.is_empty():
		near((again.pos as Vector2).distance_to(at), 0.0, 0.01, "home where they were")
	eq(Sx.system(g, "05_save").call("save_to", 2), "", "saved inside")
	Sx.end(g)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(2, o), "", "the save boots")
	var b := Sx.game(tree, [], o)
	await frames(10)
	var db := Sx.system(b, "21_doors")
	var loaded := _home(db, "after a load")
	if not loaded.is_empty():
		near((loaded.pos as Vector2).distance_to(at), 0.0, 0.01, "home where they were")
	Sx.end(b)
	Sx.finish()
