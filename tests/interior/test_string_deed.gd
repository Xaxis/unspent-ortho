extends TestCase
## THE STRING IS EARNED, NEVER SOLD (docs/MIDDENS_ROOMS.md, the rulings). A face
## settlement's reader asks for a filed record; brought one, they take it and
## give the string, once; the map draws its route to a ramp while it is carried;
## and the deed is remembered by a save. Asked through the use key's own talk
## (49_story) of the reader seed 1's first settlement keeps.

const Sx := preload("res://tests/save/save_fixture.gd")
const Recipe := preload("res://src/content/interiors/face_hold.gd")


func _says(story: Node) -> PackedStringArray:
	var t: StoryTalk = story.get(&"talk")
	if t == null or t.made.is_empty():
		return PackedStringArray()
	return (t.made.nodes as Dictionary)[&"open"].says


func _talk_to(g: Game, story: Node, row: Dictionary) -> PackedStringArray:
	g.talking = false
	story.call(&"_start_talk", row)
	return _says(story)


func test_the_reader_gives_the_string_for_a_record_once() -> void:
	Sx.use_root("string-deed")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	var d := Sx.system(g, "21_doors")
	var story := Sx.system(g, "49_story")
	var t: Threshold = null
	for th: Threshold in Interiors.thresholds(g.world):
		if th.kind == &"face_hold":
			t = th
			break
	check(t != null, "seed 1 has a settlement")
	if t == null:
		Sx.end(g)
		Sx.finish()
		return
	await d.call(&"go_in", t)
	var rows: Array = d.call(&"dweller_rows")
	eq(rows.size(), 1, "the reader is home")
	var row: Dictionary = rows[0]
	g.inventory.remove(&"record", g.inventory.count(&"record"))
	g.inventory.remove(&"string", g.inventory.count(&"string"))
	eq(Array(_talk_to(g, story, row)), Array(Recipe.ASKS), "empty-handed, they ask for words")
	eq(g.inventory.count(&"string"), 0, "and give nothing")
	eq(UiMapScreen.strings(g).size(), 0, "no way up on the map")
	g.inventory.add(&"record", 1)
	eq(Array(_talk_to(g, story, row)), Array(Recipe.THANKS), "brought a record, they thank")
	eq(g.inventory.count(&"record"), 0, "and take it")
	eq(g.inventory.count(&"string"), 1, "and give the string")
	var routes := UiMapScreen.strings(g)
	eq(routes.size(), 1, "the map has the way up")
	if not routes.is_empty():
		gt(float((routes[0] as Array).size()), 1.0, "along the slots")
	g.inventory.add(&"record", 1)
	eq(Array(_talk_to(g, story, row)), Array(Recipe.AFTER), "once, not twice")
	eq(g.inventory.count(&"string"), 1, "one string")
	eq(g.inventory.count(&"record"), 1, "and the second record kept")
	var key := t.key
	eq(Sx.system(g, "05_save").call("save_to", 2), "", "saved")
	Sx.end(g)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(2, o), "", "the save boots")
	var b := Sx.game(tree, [], o)
	await frames(10)
	var db := Sx.system(b, "21_doors")
	check(bool(db.call(&"deed_done", key)), "the deed is remembered")
	eq(b.inventory.count(&"string"), 1, "the string is carried after the load")
	eq((db.call(&"string_routes") as Array).size(), 1, "and its route is kept")
	eq(UiMapScreen.strings(b).size(), 1, "and the way up is still on the map")
	b.inventory.remove(&"string", 1)
	eq(UiMapScreen.strings(b).size(), 0, "until the string is gone")
	Sx.end(b)
	Sx.finish()
