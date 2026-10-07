extends TestCase
## OPENING THE SURVEY COSTS A FRAME, NOT A SECOND. Every open used to letter the
## regions on the main thread (211k coarse cells at 1840, and a neighbourhood
## for each one seen), count the whole mask for the share, and make a new
## 1840-square texture of what was seen. The lettering is worked out on a worker
## now and drawn when it is in; the share is kept; the texture is one, written
## over only when the walk has moved on; and an open before the world's own
## textures are packed shows the grid until they are, rather than packing them
## then and there.


## A world of `size` with two landscapes side by side, all of it land.
static func _world(size: int) -> WorldData:
	var w := WorldData.new(3, size)
	w.level.fill(2)
	w.ground.fill(Ground.GRASS)
	var row := PackedByteArray()
	row.resize(size)
	row.fill(Country.COAST)
	for x in size / 2:
		row[x] = Country.MOSS
	var c := PackedByteArray()
	for y in size:
		c.append_array(row)
	w.country = c
	w.country2 = c.duplicate()
	w.spawn = Vector2(size * 0.5, size * 0.5)
	return w


static func _game(w: WorldData) -> Game:
	# Nothing told and no goal: the pins come from the story, which this is not about.
	Story.forget()
	Guide.last_goal_key = &""
	var g := Game.new()
	g.world = w
	g.player = Player.new()
	g.player.world = w
	g.player.pos = w.spawn
	return g


static func _screen(g: Game, e: UiExplored, data: UiMapData) -> UiMapScreen:
	var s := UiMapScreen.new()
	s.game = g
	s.explored = e
	s.data = data
	return s


static func _done(g: Game, s: UiMapScreen) -> void:
	s._take_regions(true)
	s.free()
	g.player.free()
	g.free()


## A walk across the middle of the island, over both landscapes.
static func _walk(e: UiExplored, from: Vector2i, steps: int) -> void:
	for i in steps:
		e.reveal(from + Vector2i(i * 6, roundi(sin(i * 0.3) * 40.0)), UiExplored.RADIUS)


func test_opening_the_survey_costs_a_frame() -> void:
	var w := _world(1840)
	var data := UiMapData.new(w)
	# Packed ahead, as 90_ui does it two seconds into a game: not what is timed.
	data.build_async()
	data.ensure()
	var g := _game(w)
	var e := UiExplored.new(w.size)
	_walk(e, Vector2i(300, 900), 200)
	var s := _screen(g, e, data)
	var opens: Array[float] = []
	for i in 4:
		# The walk has moved on since the last open, every time.
		e.reveal(Vector2i(1500, 400 + i * 30), UiExplored.RADIUS)
		var t0 := Time.get_ticks_usec()
		s._on_open()
		var spent := (Time.get_ticks_usec() - t0) / 1000.0
		opens.append(spent)
		s._take_regions(true)
	print("  the survey opened at 1840 in %s ms" % str(opens))
	check(not s._regions.is_empty(), "and it is lettered")
	cost_lt(opens.min(), 4.0, "opening the survey at 1840 (ms)")
	_done(g, s)


func test_the_lettering_comes_from_its_worker_as_it_was_always_worked_out() -> void:
	var w := _world(256)
	var data := UiMapData.new(w)
	data.ensure()
	var g := _game(w)
	var e := UiExplored.new(w.size)
	_walk(e, Vector2i(40, 128), 10)
	var s := _screen(g, e, data)
	s._on_open()
	s._take_regions(true)
	eq(_texts(s._regions), _texts(UiMapScreen.region_labels(w, e)), "the lettering, worked out on a worker")
	eq(s._regions.size(), 1, "one landscape seen so far")
	# Walked on into the second landscape: the next open asks again, and until it
	# is in, what was lettered before is what is drawn.
	_walk(e, Vector2i(140, 128), 12)
	var before := s._regions
	s._on_open()
	check(s._regions == before or s._regions.size() == 2, "the old lettering stands until the new is in")
	s._take_regions(true)
	eq(_texts(s._regions), _texts(UiMapScreen.region_labels(w, e)), "and the new is what it always was")
	eq(s._regions.size(), 2, "both landscapes named")
	_done(g, s)


func test_one_texture_of_the_land_seen_is_kept_and_written_over() -> void:
	var w := _world(256)
	var data := UiMapData.new(w)
	data.ensure()
	var g := _game(w)
	var e := UiExplored.new(w.size)
	e.reveal(Vector2i(60, 60), UiExplored.RADIUS)
	var s := _screen(g, e, data)
	s._on_open()
	var tex := s._seen_tex
	check(tex != null, "the land seen is a texture")
	eq(tex.get_image().get_pixel(60, 60).r8, 255, "showing the walk")
	eq(tex.get_image().get_pixel(200, 200).r8, 0, "and not what was not walked")
	e.reveal(Vector2i(200, 200), UiExplored.RADIUS)
	s._on_open()
	check(s._seen_tex == tex, "opened again, the same texture")
	# Headless, the dummy renderer keeps a texture's first image and drops every
	# update, so the write is read off what the texture was last written from.
	eq(s._seen_for, [e.changes, e.revealed], "written over with the walk as it stands")
	_done(g, s)


func test_an_early_open_does_not_wait_for_the_world_to_be_packed() -> void:
	var w := _world(512)
	var data := UiMapData.new(w)
	var g := _game(w)
	var e := UiExplored.new(w.size)
	e.reveal(Vector2i(256, 256), UiExplored.RADIUS)
	var s := _screen(g, e, data)
	s._on_open()
	check(not data.ready, "opened before the survey's textures were packed")
	check(not s._rect.visible, "so the sheet is not drawn yet")
	# Fed when the worker is done, as the app's own frames would.
	for i in 4000:
		s._feed()
		if s._fed:
			break
		OS.delay_msec(2)
	check(s._fed and data.ready, "fed once they are in")
	check(s._rect.visible, "and drawn")
	eq(s._material.get_shader_parameter("ground_tex"), data.ground, "with the world's own textures")
	eq(s._material.get_shader_parameter("seen_tex"), s._seen_tex, "and the land seen")
	_done(g, s)


static func _texts(labels: Array[Dictionary]) -> Array:
	var out := []
	for l in labels:
		out.append([l.text, l.at, l.country, l.seen])
	return out
