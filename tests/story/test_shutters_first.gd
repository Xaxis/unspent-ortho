extends TestCase
## PEOPLE AT RISK BEFORE HIS OWN KIT (owner, via teammate1). A raid warned on
## his holding puts the shutters on the goal line whatever else he is short of:
## no pick, no plate, the crew not paid. It used to wait behind all three, so a
## player warned early heard "coming for" and nothing about what to do.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_a_raid_warned_on_his_holding_asks_for_shutters_before_anything_of_his() -> void:
	Sx.use_root("shutters_first")
	var g := Sx.game(tree, ["--seed=4", "--size=64", "--hour=10", "--held=axe_felling", "--holding=lean-to,hearth"])
	await frames(3)
	Story.beat(Guide.LEAD_BEAT)
	g.body.fed_until = g.clock.minutes + 600.0
	check(not Guide.has_pick(g.inventory), "no pick")
	check(Story.chose(Guide.CAMP_PAID) == &"", "the crew not paid")
	var raids := g.get_node("48_raids")
	var hold: Settlement = g.get_node("46_settlements").call("here")
	check(hold != null, "his holding stands")
	check(Guide.goal(g) != String(StoryContent.LEAD[&"shutters"]), "nothing warned yet: no shutters asked for")
	var said: Array[String] = []
	var hear := func(text: String) -> void: said.append(text)
	Events.message.connect(hear)
	raids.call("_warn", hold, RaidStage.RAID)
	Events.message.disconnect(hear)
	check(said.has(StoryContent.DEFEND["warned"] % hold.name), "the warning says what to do: %s" % [said])
	eq(Guide.goal(g), String(StoryContent.LEAD[&"shutters"]), "warned: the shutters, ahead of the pick")
	eq(Guide.last_goal_key, &"shutters", "keyed, so a tour can claim it")
	Sx.end(g)
	Sx.finish()
