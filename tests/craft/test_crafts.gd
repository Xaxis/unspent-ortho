extends TestCase
## The rules of the three crafts, with no game running: what each one crosses and
## what it refuses, how far a launch and a step off may reach, what wears a hull
## out, and what a wreck gives back. Everything a craft decides lives in
## src/core/craft/ and is decided here.


## A shore world: grass at level 2 west, a band of shallow water, open sea east,
## and a rock shelf two levels up — a cliff to a body, a stride to a walker rig.
static func shore(size: int = 24) -> WorldData:
	var w := WorldData.new(7, size)
	for y in size:
		for x in size:
			var i := y * size + x
			if x >= 14:
				w.level[i] = -2
				w.ground[i] = Ground.DEEP_WATER
			elif x >= 12:
				w.level[i] = 0
				w.ground[i] = Ground.WATER
			elif x >= 4 and x < 8:
				w.level[i] = 4
				w.ground[i] = Ground.SCREE
			else:
				w.level[i] = 2
				w.ground[i] = Ground.GRASS
	return w


func test_every_craft_is_described_and_can_be_had() -> void:
	var made := {}
	for r: Dictionary in Recipes.LIST:
		for id: StringName in (r.get("makes", {}) as Dictionary):
			made[id] = r.id
	for kind in CraftKinds.ids():
		var row := CraftKinds.row(kind)
		check(String(row.get("name", "")) != "", "%s has a name" % kind)
		check(String(row.get("opens", "")) != "", "%s says what it opens" % kind)
		gt(CraftKinds.hull(kind), 0.0, "%s has a hull" % kind)
		gt(CraftKinds.launch_reach(kind), 0.0, "%s can be set down" % kind)
		var r := CraftKinds.ride(kind)
		check(r != null, "%s has a ride" % kind)
		gt(r.walk, 0.0, "%s walks" % kind)
		gt(r.run, r.walk, "%s runs faster than it walks" % kind)
		gt(float(r.levels), 0.0, "%s can step" % kind)
		for g: int in r.grounds:
			check(g >= 0 and g < Ground.COUNT, "%s crosses ground %d, which is not a ground" % [kind, g])
		# Reachable: the bundle is an item and something makes it.
		check(not Items.def(kind).is_empty(), "%s is a thing you can carry" % kind)
		check(made.has(kind), "%s can be made in a normal game" % kind)
		# And a wreck gives real materials back.
		var salv := CraftKinds.salvage(kind)
		check(not salv.is_empty(), "%s leaves salvage" % kind)
		for id: StringName in salv:
			check(not Items.def(id).is_empty(), "%s salvages into %s, which is not an item" % [kind, id])


func test_each_craft_crosses_what_it_is_for_and_nothing_else() -> void:
	var raft := CraftKinds.ride(&"raft")
	check(raft.crosses(Ground.DEEP_WATER), "a raft is for open water")
	check(raft.crosses(Ground.WATER) and raft.crosses(Ground.RIVER) and raft.crosses(Ground.BLACKWATER))
	check(not raft.crosses(Ground.GRASS), "and a raft on grass is a beached raft")
	check(not raft.crosses(Ground.SAND), "not even the beach")
	var sled := CraftKinds.ride(&"hover_sled")
	check(sled.crosses(Ground.PEAT) and sled.crosses(Ground.SALT) and sled.crosses(Ground.ICE)
		and sled.crosses(Ground.BLACKWATER), "a sled skims bog, salt, ice and black water")
	check(not sled.crosses(Ground.DEEP_WATER), "the open sea is the raft's")
	gt(sled.walk, Tuning.WALK_SPEED, "and it is faster than walking, which is its point")
	var walker := CraftKinds.ride(&"walker_rig")
	check(not walker.crosses(Ground.DEEP_WATER), "legs are not floats")
	eq(walker.levels, 2, "two levels is a cliff to a body and a stride to the rig")
	eq(CraftRide.walker().levels, 1, "a body's own limit is one")
	check(CraftRide.walker().crosses(Ground.GRASS) and not CraftRide.walker().crosses(Ground.DEEP_WATER),
		"and on foot the rules are unchanged")


func test_the_world_query_lets_a_craft_where_a_body_cannot_go() -> void:
	var w := shore()
	var q := WorldQuery.new(w)
	var raft := CraftKinds.ride(&"raft")
	check(not q.standable(16, 10), "on foot the sea is out")
	check(q.standable(16, 10, raft), "on a raft it is not")
	check(not q.standable(2, 10, raft), "and the raft cannot come up the field")
	# Shallow water is level 0 and the sea two levels under it: a float does not climb.
	check(q.passable(13, 10, 15, 10, raft), "a raft goes from the shallows to the sea")
	# A cliff: level 2 grass to level 4 scree.
	check(not q.passable(3, 10, 5, 10), "a body cannot take a two-level step")
	check(q.passable(3, 10, 5, 10, CraftKinds.ride(&"walker_rig")), "the walker rig can")
	check(not q.passable(3, 10, 5, 10, CraftKinds.ride(&"hover_sled")), "the sled cannot")
	# And the move itself, not only the question about the tile.
	var from := Vector2(15.5, 10.5)
	var moved := q.move_body(from, Vector2(0.6, 0.0), Tuning.PLAYER_RADIUS, raft)
	gt(moved.distance_to(from), 0.5, "the raft moves out to sea")
	eq(q.move_body(from, Vector2(0.6, 0.0), Tuning.PLAYER_RADIUS), from, "a swimmer does not")


func test_a_raft_is_shoved_out_past_the_shallows_and_refuses_dry_land() -> void:
	var w := shore()
	var q := WorldQuery.new(w)
	# Standing in the shallows at the tideline, facing the sea.
	var spot := Crafts.launch_spot(w, q, &"raft", Vector2(13.5, 10.5), 0.0)
	check(spot != Vector2.INF, "there is water to put it in")
	check(Crafts.beyond_a_body(w, spot), "and it goes in deep enough to float: %s" % spot)
	lt(spot.distance_to(Vector2(13.5, 10.5)), CraftKinds.launch_reach(&"raft") + 0.01, "within a shove")
	# Up the field there is nothing to launch into.
	eq(Crafts.launch_spot(w, q, &"raft", Vector2(2.5, 10.5), 0.0), Vector2.INF, "no water, no raft")
	check(Crafts.refusal_line(&"afloat", &"raft").contains("water"), "and it says why")
	# A sled goes down where the body stands.
	var sled := Crafts.launch_spot(w, q, &"hover_sled", Vector2(2.5, 10.5), 0.0)
	check(sled != Vector2.INF, "a sled has room on the field")
	lt(sled.distance_to(Vector2(2.5, 10.5)), 1.5, "right where you are standing")


func test_a_launch_never_jumps_a_headland() -> void:
	var w := shore()
	var q := WorldQuery.new(w)
	# A spit of land between the body and the water: the line is not clear.
	for y in 24:
		for x in range(12, 16):
			if y == 10:
				continue
			w.level[y * 24 + x] = 2
			w.ground[y * 24 + x] = Ground.GRASS
	check(not Crafts.clear_line(w, &"raft", Vector2(11.5, 9.5), Vector2(15.5, 9.5)), "the spit is in the way")
	check(Crafts.clear_line(w, &"raft", Vector2(12.5, 10.5), Vector2(15.5, 10.5)), "the channel is not")
	var spot := Crafts.launch_spot(w, q, &"raft", Vector2(11.5, 9.5), 0.0)
	eq(spot, Vector2.INF, "and nothing is launched over dry ground")


func test_a_body_steps_off_only_onto_ground_it_could_have_waded_to() -> void:
	var w := shore()
	var q := WorldQuery.new(w)
	# Nosed into the shallows: the shore is a step away.
	var off := Crafts.step_off_spot(w, q, &"raft", Vector2(13.2, 10.5))
	check(off != Vector2.INF, "there is somewhere to step")
	check(q.standable(floori(off.x), floori(off.y)), "and it is ground a body can stand on")
	lt(off.distance_to(Vector2(13.2, 10.5)), CraftKinds.launch_reach(&"raft") + 0.01, "within a step")
	# Out at sea there is nowhere, and that is the whole point.
	eq(Crafts.step_off_spot(w, q, &"raft", Vector2(20.5, 10.5)), Vector2.INF, "you cannot get off in the middle of the sea")
	check(Crafts.refusal_line(&"ashore", &"raft").contains("nowhere"), "and it says so")


func test_a_hull_wears_where_it_grinds_and_a_wreck_gives_its_parts_back() -> void:
	gt(Crafts.wear_for(&"raft", Ground.WATER), Crafts.wear_for(&"raft", Ground.DEEP_WATER),
		"the shallows grind a raft's drums; open water does not")
	gt(Crafts.wear_for(&"hover_sled", Ground.SCREE), Crafts.wear_for(&"hover_sled", Ground.GRASS),
		"scree tears at a skirt")
	gt(Crafts.wear_per_step(&"walker_rig"), 0.0, "and every cliff costs the rig something")
	var c := Craft.make(1, &"raft", Vector2(2, 2))
	near(c.condition(), 1.0, 1e-6, "new")
	check(not c.damage(CraftKinds.hull(&"raft") * 0.5), "half gone is not wrecked")
	near(c.condition(), 0.5, 0.01, "and it shows")
	check(c.damage(CraftKinds.hull(&"raft")), "the rest of it wrecks it")
	check(c.wrecked and c.hull == 0.0)
	check(not c.damage(10.0), "a wreck cannot be wrecked twice")
	eq(Crafts.board_refusal(c, Vector2(2, 2)), &"wrecked", "and nothing will carry you on it")


func test_boarding_is_refused_out_of_reach() -> void:
	var c := Craft.make(1, &"raft", Vector2(10, 10))
	eq(Crafts.board_refusal(c, Vector2(10.5, 10.5)), &"", "in reach")
	eq(Crafts.board_refusal(c, Vector2(20, 10)), &"far", "ten tiles off")
	eq(Crafts.board_refusal(null, Vector2(10, 10)), &"none")
	var list: Array = [c]
	check(Crafts.nearest(list, Vector2(10.4, 10.2)) == c, "and `ride` finds the one at your feet")
	check(Crafts.nearest(list, Vector2(30, 30)) == null)


func test_a_craft_comes_back_through_a_save() -> void:
	var c := Craft.make(4, &"walker_rig", Vector2(12.25, 8.5), 1.25)
	c.damage(30.0)
	var text := JSON.stringify(c.to_save())
	var back := Craft.from_save(JSON.parse_string(text))
	check(back != null, "it came back")
	eq(back.id, 4)
	eq(back.kind, &"walker_rig")
	eq(back.pos, Vector2(12.25, 8.5))
	near(back.facing, 1.25, 1e-5)
	near(back.hull, c.hull, 1e-4, "with the same wear on it")
	check(not back.wrecked)
	check(Craft.from_save({"kind": "flying_machine"}) == null, "a craft this build has never heard of is dropped")
