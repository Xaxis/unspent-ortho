extends TestCase
## A LAIR IS WORKED OUT ONCE PER WORLD (Sentinels.lair): it is a pure function of
## the world and the region, and its search (stand_near, the rays of gets_out,
## _room_nearest) is dear. The depot sweep asks it for every region, and so do
## the keepers' states, the spawner and the tours; every ask after the first for
## the same world and region is answered from memory.


func test_the_second_ask_for_a_lair_does_no_new_work() -> void:
	var w := WorldGen.generate(1, 512)
	var asked := 0
	var before := Sentinels.lairs_worked
	var first: Array[Vector2] = []
	for r: Dictionary in w.regions:
		var def := Sentinels.for_land(StringName(str(r.get("type", &""))))
		if def == null:
			continue
		asked += 1
		first.append(Sentinels.lair(w, r, def))
	gt(float(asked), 0.0, "seed 1 holds keepers' lands")
	var cold := Sentinels.lairs_worked - before
	eq(cold, asked, "each region's lair is worked out once, cold")
	var again := Sentinels.lairs_worked
	var i := 0
	for r: Dictionary in w.regions:
		var def := Sentinels.for_land(StringName(str(r.get("type", &""))))
		if def == null:
			continue
		eq(Sentinels.lair(w, r, def), first[i], "the same answer")
		i += 1
	eq(Sentinels.lairs_worked - again, 0, "and asked again, none is worked out")
	# The depot sweep's keepers read the same memory.
	Works.forget()
	@warning_ignore("return_value_discarded")
	Works.sites(w)
	eq(Sentinels.lairs_worked - again, 0, "the depot sweep works none out afresh")
	# A different world is not handed another's answers.
	var w2 := WorldGen.generate(1, 512)
	var fresh := Sentinels.lairs_worked
	for r: Dictionary in w2.regions:
		var def := Sentinels.for_land(StringName(str(r.get("type", &""))))
		if def != null:
			@warning_ignore("return_value_discarded")
			Sentinels.lair(w2, r, def)
	eq(Sentinels.lairs_worked - fresh, asked, "a new world works its own out")
