extends TestCase
## The story's dev pages (docs/STORY_SYSTEM.md §10) in a real game: the people,
## the path and the ledger open off the story page, and each does what it says
## through the game's own doors.

var _was := {}


func _make() -> Game:
	_was = {"tool_run": DevMode.tool_run, "asked": DevMode.asked, "configured": DevMode.configured, "armed": DevMode.armed}
	DevSession.reset()
	Story.forget()
	DevMode.asked = true
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--size=256", "--seed=1", "--hour=11"])))
	return g


func _end(g: Game) -> void:
	g.free()
	DevMode.tool_run = _was.tool_run
	DevMode.asked = _was.asked
	DevMode.configured = _was.configured
	DevMode.armed = _was.armed
	DevSession.reset()
	Story.forget()


func _open(g: Game, sub: StringName) -> UiDevScreen:
	var ui := DevCheats.system(g, "90_ui")
	check(bool(ui.call("open_screen", &"dev")), "the dev app opens")
	var s := ui.call("top") as UiDevScreen
	s.open_at(&"story", sub)
	s.handle(&"confirm")
	return s


func _has_row(s: UiDevScreen, id: StringName) -> bool:
	for r: Dictionary in s.page().rows():
		if r.get("id", &"") == id:
			return true
	return false


func test_the_people_page_stands_him_beside_someone() -> void:
	var g := _make()
	await frames(3)
	var s := _open(g, &"people")
	check(s.page() is DevPageStoryCast, "people opens off the story page")
	check(_has_row(s, &"cast_maren"), "Maren is listed")
	check(_has_row(s, &"cast_oksana"), "and so is someone waiting on another realm")
	s.select(&"cast_maren")
	s.handle(&"confirm")
	var maren: Vector2 = DevCheats.system(g, "49_cast").call("tour_place", "cast:maren")
	check(g.player.pos.distance_to(maren) < 3.0, "he stands beside Maren")
	check(not s.is_open, "and the app shuts so she is what is seen")
	_end(g)


func test_the_path_page_goes_to_any_stop() -> void:
	var g := _make()
	await frames(3)
	var s := _open(g, &"path")
	check(s.page() is DevPageStoryPlan, "the path opens off the story page")
	var placed := StoryPlan.cast(g.world)
	s.select(&"slot_the_camp")
	s.handle(&"confirm")
	check(g.player.pos.distance_to(placed[&"the_camp"].pos) < 6.0, "he stands at the crew's camp")
	# The black site is in the sea: going there puts him on the nearest ground.
	s = _open(g, &"path")
	s.select(&"slot_the_black_site")
	s.handle(&"confirm")
	check(g.query.standable(floori(g.player.pos.x), floori(g.player.pos.y)), "on ground he can stand on")
	_end(g)


func test_the_ledger_page_notes_an_act_the_notebook_has_heard_of() -> void:
	var g := _make()
	await frames(3)
	var s := _open(g, &"ledger")
	check(s.page() is DevPageStoryLedger, "the ledger opens off the story page")
	s.select(&"note_works_dark")
	s.handle(&"confirm")
	eq(Story.ledger().size(), 1, "one act seen")
	var told := "\n".join(StoryLedger.lines(&"people"))
	check(told.contains("put a works yard dark"), "and the people have heard of it already:\n%s" % told)
	_end(g)
