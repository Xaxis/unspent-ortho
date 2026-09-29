extends TestCase
## A LIGHT SEEN AT NIGHT is filed (Interference `seen_light`): the lamp key
## pressed after dark, inside a region whose plant still runs, raises that
## region's file a little, and not again for RARE_GAP. By day nobody marks a
## lamp, and a region with no plant left files nothing for it.


func _game(hour: int) -> Game:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=1", "--size=128", "--hour=%d" % hour, "--weather=clear:0"])))
	# He carries a lamp and a flask for it, as anyone out after dark does.
	g.inventory.add(&"lamp", 1)
	g.inventory.add(&"oil", 1)
	return g


func _file(g: Game) -> float:
	var d := g.get_node("32_disposition")
	return (d.get("interference") as Interference).value(Interference.network(g.world, g.player.pos))


## The lamp key, pressed and let go. The lamp is polled in `_process`
## (15_lights), so the press is held over process frames, not physics ones.
func _lamp(g: Game) -> void:
	Input.action_press(&"lamp")
	await process_frames(3)
	Input.action_release(&"lamp")
	await process_frames(3)
	check(g.body.lamp_lit, "the lamp key lit the lamp")


func _end(g: Game) -> void:
	g.queue_free()
	await frames(1)


func test_a_lamp_lit_at_night_is_filed_once_in_a_while() -> void:
	var g := _game(23)
	await frames(4)
	check(Interference.network(g.world, g.player.pos) != Interference.REGIONLESS, "he stands in a region")
	var before := _file(g)
	await _lamp(g)
	await frames(90)
	near(_file(g) - before, Interference.CAUSES[&"seen_light"], 0.01, "a light after dark is filed")
	var once := _file(g)
	g.clock.skip(30.0)
	await frames(90)
	lt(_file(g), once + 0.01, "and not again half an hour on: it stays rare")
	await _end(g)


func test_by_day_a_lamp_is_nothing() -> void:
	var g := _game(12)
	await frames(4)
	var before := _file(g)
	await _lamp(g)
	await frames(90)
	lt(_file(g), before + 0.005, "nobody marks a lamp at noon")
	await _end(g)


func test_a_region_with_no_plant_files_no_light() -> void:
	var g := _game(23)
	await frames(4)
	var i: Interference = g.get_node("32_disposition").get("interference")
	i.lose(Interference.network(g.world, g.player.pos))
	var before := _file(g)
	await _lamp(g)
	await frames(90)
	lt(_file(g), before + 0.005, "a dark yard sends nobody to look at a light")
	await _end(g)


func test_a_fire_he_stands_at_after_dark_is_filed_too() -> void:
	var g := _game(23)
	await frames(4)
	var before := _file(g)
	@warning_ignore("return_value_discarded")
	Survival.add_prop(g, PropKind.FIRE, g.player.pos + Vector2(1.5, 0))
	await frames(90)
	check(not g.body.lamp_lit, "no lamp of his own")
	near(_file(g) - before, Interference.CAUSES[&"seen_light"], 0.01, "a fire he stands at after dark is filed")
	await _end(g)
