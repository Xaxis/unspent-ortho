extends TestCase
## The ground round a village that nothing hunts you on (docs/DESIGN.md
## §Safe havens and the guided opening).
##
## Preloaded rather than named: a `class_name` resolves out of a cache the tools
## refresh and a hand-run does not.
const Haven := preload("res://src/core/survival/haven.gd")


func test_nothing_that_hunts_stands_in_a_village() -> void:
	# **THE GUARANTEE WAS TRUE BY ACCUMULATION AND NOBODY HAD WRITTEN IT DOWN.**
	# Sixteen of nineteen roster rows already declared a `green_min`, so a
	# village was quietly the safest ground in the game -- and the next row added
	# without one would have repealed it silently, in the exact place the owner
	# wants to teach the game. This is the line that notices.
	var checked := 0
	for kind: StringName in Roster.DEFS:
		var want := Haven.reach_for(kind)
		if want <= 0.0:
			continue
		checked += 1
		var where: Dictionary = (Roster.row(kind) as Dictionary).get("where", {})
		var got := float(where.get("green_min", 0))
		gt(got + 0.001, want, "%s hunts, so it keeps %.0f tiles off a green (it declares %.0f). If it belongs near a village, say so with `green_max`; if it is a keeper, it is placed at its lair and the rule does not reach it." % [kind, want, got])
	gt(float(checked), 3.0, "the rule reaches the kinds that hunt")


func test_the_floor_is_the_nearest_hunter_and_not_a_wish() -> void:
	# The number is the runner's own, because the runner is the first hunter a
	# player meets and the one the guide teaches a dodge against. If somebody
	# moves the runner in, the floor has moved and this says so rather than
	# letting the constant quietly stop describing the world.
	var nearest := INF
	for kind: StringName in Roster.DEFS:
		if Haven.held_to(kind) != &"plan":
			continue
		var where: Dictionary = (Roster.row(kind) as Dictionary).get("where", {})
		nearest = minf(nearest, float(where.get("green_min", 0)))
	near(nearest, Haven.PLAN_REACH, 0.001,
		"the floor is what the nearest hunter of the plan actually keeps")


func test_a_kind_that_belongs_near_a_village_is_exempt_by_saying_so() -> void:
	# The exemption is DECLARED, in the row, and not a name in a list here --
	# same rule as `FACETED_ON_PURPOSE` and for the same reason: an exception
	# somebody has to come here to find is one the next author repeats.
	var yard := Roster.row(&"dog.yard")
	if yard.is_empty():
		return
	check((yard.get("where", {}) as Dictionary).has("green_max"),
		"the yard dog says it belongs at the yard")
	eq(Haven.held_to(&"dog.yard"), &"", "so the floor does not reach it")
