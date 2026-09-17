extends TestCase
## The explored record and the map's packed data.


func _island(size: int) -> WorldData:
	# Sea all round, a square of land in the middle.
	var w := WorldData.new(3, size)
	for y in size:
		for x in size:
			var land := x >= size / 4 and x < size * 3 / 4 and y >= size / 4 and y < size * 3 / 4
			w.level[y * size + x] = 2 if land else 0
			w.ground[y * size + x] = Ground.GRASS if land else Ground.WATER
	return w


func test_walking_reveals_a_disc_with_a_soft_rim() -> void:
	var e := UiExplored.new(64)
	check(e.visit(Vector2(32.5, 32.5)), "first visit reveals")
	check(not e.visit(Vector2(32.9, 32.1)), "same tile does nothing")
	check(e.seen(32, 32) and e.seen(32 + UiExplored.RADIUS, 32), "inside the radius")
	check(not e.seen(32 + UiExplored.RADIUS + UiExplored.RIM + 1, 32), "beyond the rim")
	var rim := e.value(32 + UiExplored.RADIUS + 2, 32)
	check(rim > 0 and rim < 255, "the rim fades: %d" % rim)
	check(e.fraction() > 0.0 and e.fraction() < 0.25)


func test_the_trail_keeps_the_journey() -> void:
	var e := UiExplored.new(64)
	for i in 40:
		e.visit(Vector2(10.0 + i * 0.25, 20.0))
	eq(e.trail[0], Vector2(10.0, 20.0), "starts where the walk began")
	check(e.trail.size() >= 6 and e.trail.size() <= 8, "a point every 1.5 tiles: %d" % e.trail.size())
	var many := UiExplored.new(64)
	for i in UiExplored.TRAIL_MAX + 10:
		many.note_trail(Vector2(fposmod(i * 2.0, 60.0), float(i % 50)))
	check(many.trail.size() <= UiExplored.TRAIL_MAX, "bounded")
	eq(many.trail[0], Vector2(0.0, 0.0), "the start survives thinning")


func test_reveal_is_clipped_to_the_world() -> void:
	var e := UiExplored.new(16)
	e.visit(Vector2(0.5, 0.5))
	check(e.seen(0, 0))
	eq(e.value(-1, 0), 0)


func test_wander_stays_on_land_and_sees_more() -> void:
	var w := _island(64)
	var e := UiExplored.new(64)
	e.wander(w, Vector2(32.5, 32.5), 200, 7)
	check(e.fraction() > 0.2, "wandering sees land: %f" % e.fraction())
	check(not e.seen(1, 1), "never walked out to sea in the corner")


func test_shore_distance_grows_away_from_the_coast() -> void:
	var w := _island(32)
	var d := UiMapData.shore_distance(w)
	var at := func(x: int, y: int) -> int: return d[y * 32 + x]
	eq(at.call(8, 16), 8, "land tile on the shore is half a tile away")
	eq(at.call(7, 16), 8, "so is the sea tile beside it")
	check(at.call(3, 16) > at.call(6, 16), "further out to sea is further")
	check(at.call(16, 16) > at.call(9, 16), "inland is further")


func test_marks_put_symbols_on_tiles() -> void:
	var w := _island(32)
	w.props = [
		WorldProp.new(0, PropKind.PINE, Vector2(10.5, 10.5), 0.0, 1.0),
		WorldProp.new(1, PropKind.HOUSE, Vector2(20.5, 20.5), 0.0, 1.0),
		WorldProp.new(2, PropKind.BOULDER, Vector2(20.5, 20.2), 0.0, 1.0),
	]
	var m := UiMapData.mark_bytes(w)
	eq(m[10 * 32 + 10], UiMapData.MARK_CONIFER)
	eq(m[10 * 32 + 11], UiMapData.MARK_WOOD, "wood around a tree")
	eq(m[20 * 32 + 20], UiMapData.MARK_HOUSE, "a house outranks a rock")


func test_countries_are_lettered_once_enough_is_seen() -> void:
	var w := _island(64)
	for i in w.country.size():
		w.country[i] = Country.MOSS if i % 64 < 32 else Country.COAST
	var e := UiExplored.new(64)
	check(UiMapScreen.region_labels(w, e).is_empty(), "nothing seen, nothing named")
	e.visit(Vector2(24.5, 32.5))
	var labels := UiMapScreen.region_labels(w, e)
	var names: Array = labels.map(func(l: Dictionary) -> String: return l.text)
	check(names.has("M O S S"), "moss seen: %s" % str(names))
	for l in labels:
		if l.country == Country.MOSS:
			check((l.at as Vector2).x < 32.0, "lettered over the moss side")


func test_map_data_builds_textures() -> void:
	var w := _island(32)
	var data := UiMapData.new(w)
	data.build_async()
	data.ensure()
	check(data.ready)
	eq(data.ground.get_width(), 32)
	eq(data.level.get_image().get_pixel(16, 16).r8, 2, "level in the red channel")
	eq(data.palette.get_width(), 32)


func test_the_map_opens_on_everything_seen() -> void:
	var e := UiExplored.new(256)
	eq(e.bounds.size, Vector2i.ZERO, "nothing seen, no bounds")
	e.visit(Vector2(40.5, 40.5))
	e.visit(Vector2(40.5, 130.5))
	check(e.bounds.has_point(Vector2i(30, 30)) and e.bounds.has_point(Vector2i(50, 140)), "bounds hold both walks: %s" % e.bounds)
	var window := UiMapScreen.MAP_RECT.size
	var f := UiMapScreen.fit(e.bounds, Vector2(40.5, 130.5), window, UiMapScreen.SCALES)
	# By the STEP it picks, not by a pixel count: the survey is a picture and its
	# steps came across with the rest of the device when the slate moved to the
	# base's own pixels, so a number here would just be the old scale written twice.
	eq(f.scale, UiMapScreen.SCALES[1], "a hundred tiles of height fit at the second step, not the third")
	near((f.centre as Vector2).y, 85.5, 1.0, "centred on the land seen")
	var small := UiExplored.new(256)
	small.visit(Vector2(10.5, 10.5))
	eq(UiMapScreen.fit(small.bounds, Vector2(10.5, 10.5), window, UiMapScreen.SCALES).scale, UiMapScreen.SCALES[-1], "a little seen is drawn large")
	var huge := Rect2i(0, 0, 256, 256)
	var hf := UiMapScreen.fit(huge, Vector2(250.0, 250.0), window, UiMapScreen.SCALES)
	eq(hf.scale, UiMapScreen.SCALES[1], "a whole world at the widest step is a stamp in an empty frame: a step closer")
	var reach: Vector2 = Vector2(window) * 0.5 / float(hf.scale)
	var off: Vector2 = ((hf.centre as Vector2) - Vector2(250, 250)).abs()
	check(off.x < reach.x and off.y < reach.y, "the player stays on the page")
	eq(UiMapScreen.fit(Rect2i(0, 0, 600, 600), Vector2(300, 300), window, UiMapScreen.SCALES).scale, UiMapScreen.SCALES[0], "land that fills the window at the widest step stays there")


## Window x of tile x for a fit.
func _wx(f: Dictionary, x: float, window: Vector2i) -> float:
	return (x - (f.centre as Vector2).x) * int(f.scale) + window.x / 2.0


func test_the_survey_keeps_the_player_and_the_seen_land_in_its_window() -> void:
	var window := UiMapScreen.MAP_RECT.size
	var e := UiExplored.new(256)
	e.visit(Vector2(120.5, 90.5))
	var f := UiMapScreen.fit(e.bounds, Vector2(120.5, 90.5), window, UiMapScreen.SCALES)
	var l := _wx(f, e.bounds.position.x, window)
	var r := _wx(f, e.bounds.end.x, window)
	check(l >= 0 and r <= window.x, "all the seen land is in the window: %d..%d" % [l, r])
	var wide := Rect2i(20, 40, 400, 90)
	var p := Vector2(400.0, 80.0)
	var wf := UiMapScreen.fit(wide, p, window, UiMapScreen.SCALES)
	var at := _wx(wf, p.x, window)
	check(at > 0 and at < window.x, "the player at the far end of wide land is still in the window: %s" % at)


func test_the_survey_is_clear_of_the_glass_flaws() -> void:
	# Its brackets run two pixels outside it.
	var r := UiMapScreen.MAP_RECT.grow(2)
	check(not r.intersects(UiSlate.crack_zone(UiSlate.DEVICE)), "the crack is not over the survey")
	check(r.position.x > UiSlate.dead_column_x(UiSlate.DEVICE), "nor the dead column")
	check(UiSlate.BODY.encloses(UiMapScreen.MAP_RECT), "it sits in the glass's body")


func test_discoveries_are_the_landmarks_seen() -> void:
	var w := _island(64)
	w.landmarks = [
		{"kind": &"stone_circle", "pos": Vector2(20.5, 20.5), "country": 1},
		{"kind": &"wreck", "pos": Vector2(40.5, 40.5), "country": 1},
		{"kind": &"bridge", "pos": Vector2(21.5, 21.5), "country": 1},
	]
	var e := UiExplored.new(64)
	check(UiMapScreen.discoveries(w, e).is_empty(), "nothing seen, nothing found")
	e.visit(Vector2(20.5, 20.5))
	var found := UiMapScreen.discoveries(w, e)
	eq(found.size(), 1, "the circle is found, a bridge is not a discovery")
	eq(found[0].kind, &"stone_circle")
	check(not found[0].machine, "a stone circle is not the machines' work")
	e.visit(Vector2(40.5, 40.5))
	var machine := UiMapScreen.discoveries(w, e).filter(func(d: Dictionary) -> bool: return d.kind == &"wreck")
	check(machine.size() == 1 and machine[0].machine, "a wreck is shown as the machines'")


func test_names_look_for_the_least_ink() -> void:
	var w := _island(32)
	# A cliff runs down x = 12: land at level 2 steps to level 5.
	for y in 32:
		for x in range(12, 24):
			if w.level[y * 32 + x] > 0:
				w.level[y * 32 + x] = 5
	var marks := PackedByteArray()
	marks.resize(32 * 32)
	var table := UiMapData.ink_table(w, marks)
	eq(UiMapData.ink_in(table, 32, Rect2i(0, 0, 32, 32)), UiMapData.ink_in(table, 32, Rect2i(-5, -5, 50, 50)), "clipped to the world")
	var flat := UiMapData.ink_in(table, 32, Rect2i(16, 14, 4, 4))
	var cliff := UiMapData.ink_in(table, 32, Rect2i(10, 14, 4, 4))
	var shore := UiMapData.ink_in(table, 32, Rect2i(6, 14, 4, 4))
	eq(flat, 0, "open ground inside a terrace draws no ink")
	gt(cliff, shore, "a cliff is drawn harder than a shore")
	gt(shore, flat, "and a shore harder than open ground")
	marks[15 * 32 + 17] = UiMapData.MARK_HOUSE
	gt(UiMapData.ink_in(UiMapData.ink_table(w, marks), 32, Rect2i(16, 14, 4, 4)), 0, "a symbol is ink too")


## A name over the survey is cleared outright, not laid on a wash of glass: at
## 0.88 the coastline and the contours came through the letters, and BONELANDS
## read as though the coast were struck through it.
func test_a_name_over_the_survey_clears_the_glass_under_it() -> void:
	# In a real draw pass: `draw_rect` outside one is an engine error, and a test
	# that prints six frames of stack into the gate is not a passing test.
	var ci := Control.new()
	ci.draw.connect(func() -> void: UiMapScreen.clearing(ci, Rect2i(40, 40, 60, 12)))
	tree.root.add_child(ci)
	UiDraw.tape.clear()
	UiDraw.taping = true
	ci.queue_redraw()
	await tree.process_frame
	UiDraw.taping = false
	var alphas: Array[float] = []
	for m in UiDraw.tape:
		alphas.append((m.col as Color).a)
	UiDraw.tape.clear()
	check(not alphas.is_empty(), "the clearing is drawn")
	for a in alphas:
		eq(a, 1.0, "and every part of it is opaque")
	ci.free()
