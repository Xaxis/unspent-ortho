extends TestCase
## The Drowned City's things (docs/LANDSCAPES.md §5), held to the claims their
## own file makes: stone somebody cut is CUTSTONE and piles are TIMBER under
## ROPE, no made mark reaches the FOUND pen (where an alpha is a blinking lamp),
## and each does what the spec says it does to a body.

const PROPS: Array[int] = [PropKind.STAIR_TO_WATER, PropKind.DROWNED_TRAM, PropKind.MOORING_POST, PropKind.LOCK_GATE]


static func _land() -> int:
	return BiomeRegistry.index_of(&"drowned_city")


static func _marked(cols: PackedColorArray, code: int) -> int:
	var n := 0
	for col in cols:
		if roundi(col.a * 255.0) == code:
			n += 1
	return n


func test_every_kind_is_built_in_its_own_materials() -> void:
	var land := _land()
	for kind: int in PROPS:
		for v in PropModels.variants(kind, land):
			var t := PropModels.template(kind, v, land)
			gt(float(t.made_v.size() + t.found_v.size()), 100.0, "%s %d is built" % [PropKind.NAMES[kind], v])
			for col in t.found_c:
				check(col.a >= 0.98, "%s %d has a FOUND face at alpha %.3f: a made mark there is a blinking lamp" % [PropKind.NAMES[kind], v, col.a])
	for v in 2:
		gt(float(_marked(PropModels.template(PropKind.STAIR_TO_WATER, v, land).made_c, GroundColors.CUTSTONE)), 0.0, "a quay's stair is cut stone")
		gt(float(_marked(PropModels.template(PropKind.LOCK_GATE, v, land).made_c, GroundColors.CUTSTONE)), 0.0, "and so is a lock's recess")
		gt(float(_marked(PropModels.template(PropKind.DROWNED_TRAM, v, land).made_c, GroundColors.ROPE)), 0.0, "the net over a tram is people's cord")
	var post := PropModels.template(PropKind.MOORING_POST, 0, land)
	gt(float(_marked(post.made_c, GroundColors.TIMBER)), 0.0, "piles are timber")
	gt(float(_marked(post.made_c, GroundColors.ROPE)), 0.0, "lashed with rope")
	# The tram and the gate are the ruler's; the stair and the piles the hand's.
	for kind: int in [PropKind.DROWNED_TRAM, PropKind.LOCK_GATE]:
		var t := PropModels.template(kind, 0, land)
		gt(float(t.found_v.size()), float(t.made_v.size()), "%s is mostly ruled" % PropKind.NAMES[kind])


func test_the_trams_copper_is_the_citys_gate_and_wants_steel_in_the_shallows() -> void:
	var opts: Array = Takes.options(PropKind.DROWNED_TRAM)
	var copper: Dictionary = {}
	for o: Dictionary in opts:
		if o.item == &"sea_copper":
			copper = o
		check(bool(o.keep), "a tram stands however it is stripped: it is cover (%s)" % o.verb)
	check(not copper.is_empty(), "a tram gives sea copper")
	eq(StringName(str(copper.get("stuff", &""))), &"steel", "and only to a steel edge")
	eq(copper.get("ground", []), [Ground.MUD], "and only where it stands in the tide")
	check(Cover.PROPS.has(PropKind.DROWNED_TRAM), "cover in the shallows")
	check(Cover.PROPS.has(PropKind.SEA_WALL), "and so is a sea wall")


func test_each_does_what_its_landscape_says_to_a_body() -> void:
	check(Takes.GIVES_NOTHING.has(PropKind.STAIR_TO_WATER), "a stair is a crossing, not a quarry")
	near(PropKind.SOLID[PropKind.STAIR_TO_WATER], 0.0, 1e-6, "and it is walked down, not stood against")
	check(Takes.is_plan_work(PropKind.LOCK_GATE), "robbing a lock gate is theft")
	check(Sentinels.by_id(&"lockkeeper").feeds.has(PropKind.LOCK_GATE), "and its gates are what feed the lockkeeper")
	var rope: Array = Takes.options(PropKind.MOORING_POST)
	check(not rope.is_empty() and bool(rope[0].keep), "a post's lashing comes off and the post stands for a raft to tie to")
	for kind: int in PROPS:
		check(BiomeRegistry.get_def(&"drowned_city").props.has(kind), "%s is the drowned city's own" % PropKind.NAMES[kind])
