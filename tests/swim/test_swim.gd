extends TestCase
## Swimming (owner, 2026-09-17): who may be in deep water, what it costs them,
## and where the water cuts them. The rules half is pure; what it looks like is
## `tours/swimming.tour` and the frames under shots/tour/swimming.


func test_only_deep_water_is_swum_and_every_shallow_is_waded() -> void:
	check(Ground.is_deep(Ground.DEEP_WATER))
	for g: int in [Ground.WATER, Ground.RIVER, Ground.BLACKWATER]:
		check(not Ground.is_deep(g), "%s is waded, not swum" % Ground.NAMES[g])
		check(Ground.is_shallow(g), "%s is water a body walks through" % Ground.NAMES[g])
	for g: int in [Ground.GRASS, Ground.SAND, Ground.ICE]:
		check(not Ground.is_deep(g) and not Ground.is_shallow(g), "%s is dry" % Ground.NAMES[g])
	check(Ground.is_water(Ground.DEEP_WATER) and Ground.is_water(Ground.RIVER), "both are still water")


func test_a_row_says_what_deep_water_is_to_it() -> void:
	eq(Swim.crosses({}), Swim.NONE, "nothing crosses unless it says so")
	eq(Swim.crosses({"crosses": &"swim"}), Swim.SWIM)
	eq(Swim.crosses({"crosses": &"fly"}), Swim.FLY)
	eq(Swim.crosses({"crosses": &"paddle"}), Swim.NONE, "a word nobody defined is not a licence")
	check(Swim.may_cross({"crosses": &"fly"}) and Swim.may_cross({"crosses": &"swim"}))
	check(Swim.swims({"crosses": &"swim"}) and not Swim.swims({"crosses": &"fly"}), "a flier is never wet")


## The one machine the water does not stop, and the two that go over it. This is
## the owner's ruling written as a test: most of the roster stops at the
## waterline, so swimming away works, and never on everything.
func test_the_roster_crosses_where_the_ruling_says_and_nowhere_else() -> void:
	# Sorted as Strings: a StringName sorts by when it was made, not by its letters.
	var crossing := PackedStringArray()
	for kind: StringName in Roster.DEFS:
		if Swim.may_cross(Roster.row(kind)):
			crossing.append(String(kind))
	crossing.sort()
	# The mesas' kite flies over as the flock and the gulls do: a frame on a
	# line has no business with the water under it (docs/LANDSCAPES.md §6).
	eq(crossing, PackedStringArray(["dog.feral", "dog.yard", "dredger", "flock", "gulls", "kite"]),
		"the beasts, the three that fly, and the one machine built for water: %s" % str(crossing))
	for kind: String in crossing:
		check(Roster.has(StringName(kind)), "%s is not a body that exists" % kind)


func test_a_dredger_may_stay_in_the_deep_it_swims() -> void:
	var row := Roster.row(&"dredger")
	eq(Swim.crosses(row), Swim.SWIM, "it was built to work in water")
	var keeps: Array = row.get("keeps_to", [])
	check(keeps.has("deep water"), "or its own keeps_to pushes it straight back out: %s" % str(keeps))
	var where: Dictionary = row.get("where", {})
	var grounds: Array = where.get("grounds", [])
	check(not grounds.has("deep water"), "it follows you into the deep; it is never put out there")


## The rules and the picture must agree about where the water is, or a body swims
## through the air. Core holds no rendering, so the number is duplicated on
## purpose and this is what keeps the two honest.
func test_the_waterline_is_the_one_the_mesher_draws() -> void:
	near(Swim.WATER_Y, TerrainMesher.WATER_Y, 0.0001,
		"Swim.WATER_Y and TerrainMesher.WATER_Y have drifted apart")


func test_a_swimmer_is_floated_to_the_surface_and_not_sunk_to_the_bed() -> void:
	var w := WorldData.new(7, 8)
	for i in 8 * 8:
		w.level[i] = 1
		w.ground[i] = Ground.GRASS
	w.ground[2 * 8 + 2] = Ground.DEEP_WATER
	w.level[2 * 8 + 2] = 0
	check(Swim.deep(w, Vector2(2.5, 2.5)), "out of its depth")
	check(not Swim.deep(w, Vector2(1.5, 1.5)), "and not on the bank")
	check(not Swim.deep(null, Vector2(2.5, 2.5)), "no world, no water")
	# The bed under deep water is not modelled (height_at clamps at 0), so what a
	# figure needs is a lift toward the surface, never a drop toward the ground.
	near(w.height_at(Vector2(2.5, 2.5)), 0.0, 0.001, "the sea floor is the zero plane")
	gt(Swim.WATER_Y, 0.0, "and the water is drawn above it")


func test_open_water_is_the_loudest_footing_and_hides_nobody() -> void:
	gt(StealthNoise.GROUNDS[Ground.DEEP_WATER], StealthNoise.GROUNDS[Ground.WATER],
		"a stroke is louder than a wade")
	gt(StealthNoise.GROUNDS[Ground.DEEP_WATER], StealthNoise.GROUNDS[Ground.GRASS])
	check(not Cover.GROUNDS.has(Ground.DEEP_WATER), "there is nothing to be behind in open water")
