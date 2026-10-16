extends TestCase
## THE FIRE-KEEPER'S FIRE (Survival.keepers_fire; owner, 2026-10-15: "there is
## already a campfire in the town as you start, it doesnt make any sense"). The
## fire in the square of the village he wakes beside is Maren's. It warms him like
## any fire, but it is no station of his and the goal never sends him to it: he
## lays his own, and a fire he lays is his to work.

const Fx := preload("res://tests/survival/fixture.gd")


func test_her_fire_warms_him_but_is_not_his_to_work() -> void:
	Story.forget()
	@warning_ignore("return_value_discarded")
	Story.beat(Guide.LEAD_BEAT)
	var g := Fx.flat(80)
	var hers := Fx.put(g, PropKind.FIRE, Vector2(4, 0))
	# What 49_cast records as it casts her at her fire.
	SurvivalState.of(g).keepers_fire = hers
	check(WorldProp.same(Survival.keepers_fire(g), hers), "the fire the story keeps her at is hers")
	Fx.face(g, hers)
	check(WorldProp.same(Survival.fire_near(g), hers), "it warms him")
	check(not Survival.stations_near(g).has(&"fire"), "but it is no station of his: %s" % str(Survival.stations_near(g)))
	check(Survival.at_keepers_fire(g), "and he is standing at her fire")
	check(Guide.goal(g).contains(String(StoryContent.LEAD[&"fire_gather"]).left(12)) or Guide.goal(g).contains(String(StoryContent.LEAD[&"fire_lay"]).left(12)),
		"the goal still asks for his own fire: %s" % Guide.goal(g))
	var mine := Survival.build(g, &"fire", true)
	check(mine != null and not WorldProp.same(mine, hers), "he lays his own")
	Fx.face(g, mine)
	check(Survival.stations_near(g).has(&"fire"), "and his own is his to work")
	check(not Survival.at_keepers_fire(g), "standing at his own, not hers")
	Fx.done(g)
	Story.forget()


## In a real start the cast records the fire she is kept at, and the
## making page opened at it says why it is not his: in her words while she is by
## it, the game's while she is away.
func test_making_at_her_fire_says_why_not() -> void:
	var Sx := preload("res://tests/save/save_fixture.gd")
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"])
	await process_frames(3)
	var hers := Survival.keepers_fire(g)
	check(hers != null, "seed 1's home village has a fire in its square")
	if hers == null:
		Sx.end(g)
		return
	g.view.ensure_near(hers.pos)
	await process_frames(2)
	# Stood against it from whichever side the land allows, facing it.
	for k in 8:
		var from := Vector2.from_angle(k * TAU / 8.0)
		var at := g.player.place(hers.pos + from * (hers.solid + Tuning.PLAYER_RADIUS + 0.3))
		g.player.facing = (hers.pos - at).angle()
		if Survival.at_keepers_fire(g):
			break
	check(Survival.at_keepers_fire(g), "standing at her fire")
	var ui: Node = null
	for sys in g.systems:
		if sys.name == "90_ui":
			ui = sys
	var said: Array[String] = []
	var hear := func(line: String) -> void: said.append(line)
	Events.message.connect(hear)
	var lines := [String(StoryContent.KEEPERS_FIRE["hers"]), String(StoryContent.KEEPERS_FIRE["away"])]
	if ui.call("open_screen", &"crafting"):
		# Something of his own to make by hand: the page opens, and says it.
		var s: UiScreen = ui.call("top")
		check(s.note in lines, "the page says why her fire is not his: %s" % s.note)
		s.close()
	else:
		# Nothing of his own to make: her fire says why instead of an empty page.
		check(said.any(func(l: String) -> bool: return l in lines), "her fire says why it is not his: %s" % str(said))
	Events.message.disconnect(hear)
	Sx.end(g)
