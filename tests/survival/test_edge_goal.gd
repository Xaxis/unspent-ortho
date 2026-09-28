extends TestCase
## THE EDGE A KEEPER TAKES, AS THE GOAL (Guide.edge_goal, SurvivalState.plates):
## once the reaper's steel plating has rung the knife off, the goal line asks
## for a steel edge with the reason, step by step as the home coast makes one --
## a kiln, charcoal, the knife tempered in it -- then sends the steel to the
## reaper, until it falls (40_fight lets it go). Saved.

const Fx := preload("res://tests/survival/fixture.gd")
const Sx := preload("res://tests/save/save_fixture.gd")


func test_the_goal_walks_the_steel_edge() -> void:
	var g := Fx.flat()
	g.inventory.add(&"knife")
	g.inventory.set_held(&"knife")
	var before := Guide.goal(g)
	check(not before.contains("reaper"), "before it rings, the goal is the coast's own (%s)" % before)
	SurvivalState.of(g).plates[&"steel"] = &"coast"
	var line := Guide.goal(g)
	check(line.contains("reaper") and line.contains("kiln") and line.contains("eight stones"), "rung: a kiln, and why (%s)" % line)
	g.inventory.add(&"stone", 8)
	check(Guide.goal(g).contains("Lay the kiln"), "with the stones: lay it (%s)" % Guide.goal(g))
	var kiln := Fx.put(g, PropKind.KILN, Vector2(1.5, 0.0))
	SurvivalState.of(g).built.append(kiln)
	var fire := Fx.put(g, PropKind.FIRE, Vector2(-1.5, 0.0))
	SurvivalState.of(g).built.append(fire)
	check(Guide.goal(g).contains("Four charcoal"), "the kiln laid: charcoal (%s)" % Guide.goal(g))
	g.inventory.add(&"charcoal", 4)
	check(Guide.goal(g).contains("Temper the knife"), "the charcoal in hand: temper it (%s)" % Guide.goal(g))
	g.inventory.add(&"knife_shear")
	check(Guide.goal(g).contains("Take it to the reaper"), "the steel knife carried: to the reaper (%s)" % Guide.goal(g))


func test_the_plating_rung_is_saved() -> void:
	Sx.use_root("edge-goal")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	SurvivalState.of(g).plates[&"steel"] = &"coast"
	var d := SaveCore.save_survival(g)
	SurvivalState.of(g).plates.clear()
	SaveCore.load_survival(g, JSON.parse_string(JSON.stringify(d)))
	eq(SurvivalState.of(g).plates.get(&"steel", &""), &"coast", "the plating rung comes back from a save")
	# The keeper down (44_sentinels says so; the fight system hears it): the
	# plating is no longer a reason, and the goal moves on.
	Events.sentinel_fell.emit(0, &"coast", &"force")
	check(not SurvivalState.of(g).plates.has(&"steel"), "its keeper fallen, the plating is let go")
	check(not Guide.goal(g).contains("reaper"), "and the goal moves on (%s)" % Guide.goal(g))
	Sx.end(g)
