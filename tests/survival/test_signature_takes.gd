extends TestCase
## Every prop kind does something when `use` meets it, or says why it does not
## (docs/ROADMAP.md M3: "every signature prop does something to a body").
## Twenty-three kinds had no `Takes` row and no reason, so the key walked past a
## salt heap, a sea wall and a cairn without a word. The rule is held over EVERY
## PropKind, not the twenty-three, so a kind appended later is caught too.

const Fx := preload("res://tests/survival/fixture.gd")

## The kinds the audit found with nothing (docs/ROADMAP.md, "23 signature prop
## kinds have no Takes row"). Named here so each is shown to be DECIDED, one way
## or the other, and not merely swept up by the loop below.
const AUDITED: Array[int] = [PropKind.SALT_RIDGE, PropKind.SALT_HEAP, PropKind.PAN_GATE,
	PropKind.SCRAP_TREE, PropKind.MAGNET_HEAP, PropKind.SEA_WALL, PropKind.TIDE_GAUGE,
	PropKind.GROWTH_TANK, PropKind.PLATFORM, PropKind.CONSOLE, PropKind.MURAL,
	PropKind.SLAG_HEAP, PropKind.STACK, PropKind.WATER_TANK, PropKind.VENT_CAP,
	PropKind.CAIRN, PropKind.STANDING_STONE, PropKind.BONES, PropKind.GRAVE,
	PropKind.MEMORIAL, PropKind.ARCHIVE, PropKind.LAMP, PropKind.BENCH]


func test_every_kind_gives_something_or_says_why_not() -> void:
	eq(PropKind.NAMES.size(), PropKind.COUNT, "one name per kind")
	for kind in PropKind.COUNT:
		var name := PropKind.NAMES[kind]
		var gives := Takes.workable(kind)
		var nothing := Takes.GIVES_NOTHING.has(kind)
		check(gives or nothing, "%s has no take and no reason for having none" % name)
		check(not (gives and nothing), "%s both gives and is said to give nothing" % name)
		if nothing:
			gt(String(Takes.GIVES_NOTHING[kind]).length(), 20, "%s's reason says something" % name)


func test_the_audited_kinds_are_each_decided() -> void:
	eq(AUDITED.size(), 23, "the audit's list, whole")
	for kind: int in AUDITED:
		check(Takes.workable(kind) or Takes.GIVES_NOTHING.has(kind), "%s decided" % PropKind.NAMES[kind])


## A new row may not open a second gate on an elite material: its raw comes off
## the one prop kind it always did, on that kind's own ground (EliteStock).
func test_no_new_row_gives_an_elite_raw() -> void:
	var gates := {&"brimstone": [PropKind.VENT], &"limestone": [PropKind.CLINTS],
		&"peat": [PropKind.PEAT_BANK], &"crottle": [PropKind.BOULDER, PropKind.STONE_ORE],
		# The crags' raw comes off a carved face and nothing else (docs/LANDSCAPES.md §1).
		&"hushstone": [PropKind.CARVED_FACE],
		# The frost sea's raw comes off a pressure block and nothing else (docs/LANDSCAPES.md §2).
		&"lens_ice": [PropKind.PRESSURE_BLOCK],
		# The glass desert's raw comes off a fulgurite and nothing else (docs/LANDSCAPES.md §3).
		&"fulgurite": [PropKind.FULGURITE],
		&"lift_cable": [PropKind.LIFT_SHAFT]}
	for id: StringName in EliteStock.MATERIALS:
		var raw := StringName(str((EliteStock.MATERIALS[id] as Dictionary).get("raw", &"")))
		if raw != &"":
			check(gates.has(raw), "%s's raw %s is known to this test" % [id, raw])
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			for raw: StringName in gates:
				if o.item == raw or (not (o.bonus as Array).is_empty() and o.bonus[0] == raw):
					check((gates[raw] as Array).has(kind), "%s gives %s, an elite gate that is not its own" % [PropKind.NAMES[kind], raw])


## Everything the audit added stands after it is spent: none of them has a
## remnant to leave or a `Broken` cut that suits it, so taking one away or
## working it down would draw a hole or a sawn-off model.
func test_the_audited_rows_leave_the_thing_standing() -> void:
	for kind: int in AUDITED:
		for o: Dictionary in Takes.options(kind):
			check(bool(o.keep), "%s %s keeps it standing" % [PropKind.NAMES[kind], o.verb])


## Every kind the plan lays is one of its works, so taking from any of them is
## filed as theft (32_disposition asks `is_plan_work`). A drill rig was THEIRS and
## not a plan work, so it was the one run of the plan that could not be robbed.
func test_everything_the_plan_lays_is_a_plan_work() -> void:
	for kind: int in GenWorks.THEIRS:
		check(Takes.is_plan_work(kind), "%s is the plan's and robbing it is theft" % PropKind.NAMES[kind])
	for kind: int in Takes.PLAN_WORKS:
		check(Takes.workable(kind), "%s is a plan work that can be robbed" % PropKind.NAMES[kind])
	check(Takes.is_plan_work(PropKind.TIDE_GAUGE), "the tide gauge is the plan's (docs/LANDSCAPES.md: theft)")
	check(not Takes.is_plan_work(PropKind.PAN_GATE), "a pan gate's sandbags are people's")


func test_a_cairn_gives_one_stone_and_stands() -> void:
	var g := Fx.flat()
	Survival.hold(g, &"")
	var cairn := Fx.put(g, PropKind.CAIRN, Vector2(0.9, 0))
	Fx.face(g, cairn)
	eq(Survival.describe_target(g), "cairn - turn")
	check(Fx.take(g), "a stone turned off it")
	eq(g.inventory.count(&"stone"), 1)
	check(not g.world.depleted.has(cairn.id), "the waymark stands")
	eq(Survival.describe_target(g), "cairn - picked over")
	g.clock.skip(30.0 * 24.0 * 60.0)
	Survival.sweep(g, 1.0)
	eq(Survival.describe_target(g), "cairn - picked over", "and a month on, nothing has come back to it")
	Fx.done(g)


## The player's own heap is a CAIRN. A row on the kind must not turn a press at
## the heap into turning one of its stones: what was left comes back first.
func test_the_players_own_heap_still_gives_back_what_was_left() -> void:
	var g := Fx.flat()
	g.inventory.add(&"scrap", 2)
	eq(Survival.drop(g, &"scrap", 2), 2, "two plates left")
	var heap := Survival.heap_near(g)
	check(heap != null and heap.kind == PropKind.CAIRN, "left under a small cairn")
	if heap == null:
		Fx.done(g)
		return
	Fx.face(g, heap)
	eq(Survival.describe_target(g), "your things - take back")
	check(Fx.take(g), "taken back")
	eq(g.inventory.count(&"scrap"), 2, "the plate, not a stone")
	eq(g.inventory.count(&"stone"), 0)
	Fx.done(g)


func test_salt_comes_off_the_flats() -> void:
	var g := Fx.flat()
	Survival.hold(g, &"")
	var heap := Fx.put(g, PropKind.SALT_HEAP, Vector2(1.2, 0))
	Fx.face(g, heap)
	eq(Survival.describe_target(g), "salt heap - gather")
	check(Fx.take(g), "an armful of salt")
	eq(g.inventory.count(&"salt"), 2)
	check(not g.world.depleted.has(heap.id), "the heap stands")
	Fx.done(g)


func test_a_sea_wall_needs_an_edge_and_gives_stone() -> void:
	var g := Fx.flat()
	Survival.hold(g, &"")
	var wall := Fx.put(g, PropKind.SEA_WALL, Vector2(1.4, 0))
	Fx.face(g, wall)
	eq(Survival.describe_target(g), "sea wall - no tool", "cast wall is not broken by hand")
	g.inventory.add(&"pick")
	Survival.hold(g, &"pick")
	check(Fx.take(g), "broken with a pick")
	eq(g.inventory.count(&"stone"), 2)
	check(not g.world.depleted.has(wall.id), "and the wall still stands")
	Fx.done(g)
