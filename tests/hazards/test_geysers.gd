extends TestCase
## A geyser's cycle (src/core/geysers.gd): what 16_vents draws and what a hazard
## reads are the same answer.


func test_a_geyser_rests_warns_then_erupts_and_sprays_only_then() -> void:
	var row := {"share": 1.0, "period": 40.0, "height": 7.0}
	check(Geysers.is_geyser(row, 7, 3), "share 1 makes every vent a geyser")
	check(not Geysers.is_geyser({}, 7, 3), "a land with no row has none")
	var seen := {}
	var sprayed_resting := 0.0
	var sprayed_erupting := 0.0
	var first_eruption := -1.0
	for i in 400:
		var m := float(i) * 0.1
		var st := Geysers.state(row, 7, 3, m)
		seen[int(st.stage)] = true
		var sp := Geysers.spray_at(row, 7, 3, m, 0.5)
		if int(st.stage) == Geysers.ERUPTING:
			sprayed_erupting = maxf(sprayed_erupting, sp)
			if first_eruption < 0.0:
				first_eruption = m
		else:
			sprayed_resting = maxf(sprayed_resting, sp)
	eq(seen.size(), 3, "one period holds all three stages")
	gt(sprayed_erupting, 0.8, "an erupting mouth sprays hard close in")
	eq(sprayed_resting, 0.0, "and nothing sprays at rest or in the warning")
	eq(Geysers.spray_at(row, 7, 3, first_eruption + 2.0, Geysers.SPRAY + 1.0), 0.0, "no spray past its reach")
	gt(float(BiomeRegistry.get_def(&"sulphur_jungle").geysers.get("share", 0.0)), 0.0, "the sulphur jungle has geysers")
