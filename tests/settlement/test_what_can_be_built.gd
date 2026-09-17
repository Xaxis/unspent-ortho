extends TestCase
## What a player can actually put up, counted, so the distance between the enum
## and the game is a number somebody has to look at rather than something a
## reader discovers by trying to build a greenhouse.
##
## `StructureKind` names far more pieces than it gives rows to. That is by design
## — "a kind in the enum with no row is one the raids package may still name and
## nobody has learnt to build" — but an enum two and a half times the size of the
## game is exactly the shape a system takes when it is called finished and is
## not, so this pins the gap and fails when it moves either way.
##
## The sharp end of it is `SIGNS`: four kinds give off `found_tech` and three of
## them cannot be built. `Attention`'s header called a stolen cell "the loudest
## thing in the game" and no player has ever been able to stand one up.


## The enum's own constant names, read off the script, so the list this prints is
## the list in the file and cannot drift from it.
static func _enum_names() -> Dictionary:
	var out: Dictionary = {}
	var src: GDScript = load("res://src/core/settlement/structure_kind.gd")
	for name: Variant in src.get_script_constant_map():
		var v: Variant = src.get_script_constant_map()[name]
		if v is int and String(name) == String(name).to_upper() and String(name) != "COUNT":
			out[int(v)] = String(name).to_lower()
	return out


static func _families() -> Array[int]:
	return [StructureKind.Family.SHELTER, StructureKind.Family.POWER,
		StructureKind.Family.FOOD, StructureKind.Family.WORK,
		StructureKind.Family.DEFENCE, StructureKind.Family.LIVING]


## The count is the point: it is the size of the debt, and it moves only when
## somebody means it to.
func test_the_enum_is_bigger_than_the_game_and_by_exactly_this_much() -> void:
	var named := int(StructureKind.COUNT)
	var offered := StructureKind.BUILDABLE.size()
	var enum_names := _enum_names()
	var missing: Array[String] = []
	for k: int in named:
		if not StructureKind.buildable(k):
			missing.append(String(enum_names.get(k, StructureKind.display_name(k))))
	print("settlements: %d pieces named, %d a player can put up; nobody can build %s"
		% [named, offered, missing])
	eq(named, 38, "pieces named")
	eq(offered, 15, "pieces a player can put up")
	eq(StructureKind.ROWS.size(), offered,
		"a row nobody can choose, or a choice with no row, is a half-built piece")
	for k: int in StructureKind.BUILDABLE:
		check(not StructureKind.row(k).is_empty(), "%s is offered and has no row" % k)


## Every family should have something in it, or the slate offers a heading with
## nothing under it. LIVING does not, and that is the one that stops a holding
## housing anybody it took in: `BUNK` is the only living piece and it has no row,
## so residents are 35_folk's villagers walking over and never anybody who lives
## there.
func test_which_families_a_player_can_build_nothing_in() -> void:
	var empty: Array[int] = []
	for f: int in _families():
		var n := 0
		for k: int in StructureKind.BUILDABLE:
			if StructureKind.family(k) == f:
				n += 1
		if n == 0:
			empty.append(f)
	eq(empty, [StructureKind.Family.LIVING] as Array[int],
		"LIVING is the one family with nothing in it; these are empty: %s" % [empty])


## A signature nobody can produce. Three of the four `found_tech` kinds cannot be
## built, so the loudest stolen technology a player can actually make the plan
## smell is the turret's half, and `Attention`'s header has to say that.
func test_the_loudest_stolen_technology_a_player_can_stand_up() -> void:
	var loudest := 0.0
	var by := -1
	for k: Variant in StructureKind.SIGNS:
		var kind := int(k)
		var v := float((StructureKind.SIGNS[kind] as Dictionary).get("found_tech", 0.0))
		if v > loudest and StructureKind.buildable(kind):
			loudest = v
			by = kind
	eq(by, int(StructureKind.TURRET), "the turret is the only stolen technology a player can build")
	near(loudest, 0.5, 1e-6, "and it is half a signature, not a whole one")
	for kind: int in [int(StructureKind.STOLEN_CELL), int(StructureKind.SOLAR_ARRAY),
			int(StructureKind.MACHINE_SHOP)]:
		gt(float((StructureKind.SIGNS[kind] as Dictionary).get("found_tech", 0.0)), 0.0,
			"%d is only named here because it declares found_tech" % kind)
		check(not StructureKind.buildable(kind),
			"%d can be built now: say so in Attention's header, which says the cell is unreachable"
			% kind)
