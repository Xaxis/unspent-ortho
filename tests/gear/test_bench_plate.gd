extends TestCase
## THE BENCH PLATE (kit_plate, Rook's pay; slice 2 step 4): worn, it turns a
## share of every blow a hunter or a raider lands (FightRules.PLATE_TURNS), the
## fractions carried so a run of small blows is turned as surely as one large
## one. A keeper's bite is not its business: that is the keeper's fight.

const F := preload("res://tests/fight/fixture.gd")


## Health lost to each of `n` blows of `dmg` from a `kind`, plated or not.
func _lost(kind: StringName, plated: bool, n: int, dmg: int, raider: bool = false) -> Array[int]:
	var sim := F.make_sim()
	sim.hero.plated = plated
	sim.hero.health = 100
	var m := F.still(sim, kind, sim.hero.pos + Vector2(3.0, 0.0), PI)
	m.raider = raider
	sim._begin()
	var out: Array[int] = []
	for i in n:
		var before := sim.hero.health
		sim._hurt_hero(m, dmg, Vector2.RIGHT, 0.0, 0)
		out.append(before - sim.hero.health)
		sim.now += 2000.0
	return out


func _sum(a: Array[int]) -> int:
	var t := 0
	for x in a:
		t += x
	return t


func test_plate_turns_a_quarter_of_a_hunters_blows() -> void:
	var bare := _sum(_lost(&"longlegs", false, 8, 3))
	var plated := _sum(_lost(&"longlegs", true, 8, 3))
	eq(bare, 24, "eight blows of three, bare")
	eq(plated, 24 - roundi(24.0 * FightRules.PLATE_TURNS), "a quarter of it turned by the plate")


func test_plate_turns_a_raiders_blows_too() -> void:
	var bare := _sum(_lost(&"hauler", false, 8, 3, true))
	var plated := _sum(_lost(&"hauler", true, 8, 3, true))
	lt(float(plated), float(bare), "a raider's blows land less on plate")


func test_plate_is_nothing_to_a_keeper() -> void:
	var bare := _sum(_lost(&"sentinel.coast", false, 4, 4))
	var plated := _sum(_lost(&"sentinel.coast", true, 4, 4))
	eq(plated, bare, "the keeper's bite is its own fight")


## What it is for: standing in a live raid, how many blows of a hunter's three
## he takes before he falls, bare and in plate (plate's own health counted).
func test_an_armoured_man_stands_noticeably_longer() -> void:
	var bare := FightRules.max_health(false)
	var plated := FightRules.max_health(true)
	var hits_bare := ceili(float(bare) / 3.0)
	var sim := F.make_sim()
	sim.hero.plated = true
	sim.hero.health = plated
	var m := F.still(sim, &"longlegs", sim.hero.pos + Vector2(3.0, 0.0), PI)
	sim._begin()
	var hits := 0
	while sim.hero.health > 0 and hits < 50:
		sim._hurt_hero(m, 3, Vector2.RIGHT, 0.0, 0)
		sim.now += 2000.0
		hits += 1
	gt(float(hits), float(hits_bare) * 1.5, "plated he takes %d blows where bare he takes %d" % [hits, hits_bare])
