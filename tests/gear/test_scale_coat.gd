extends TestCase
## THE SCALE COAT (GEAR.md §6, G8): harvester tide iron scaled over a long coat.
## Its hook is FightSim._hurt_hero: the first blow of a fight that lands from
## behind (within SCALE_ARC of straight back) is turned and does no harm. It is
## never spent: the next fight, the scales turn one again. A blow from the front
## is not turned, and neither is a second one at the back.

const F := preload("res://tests/fight/fixture.gd")
const G := preload("res://tests/fight/test_crowd_reader.gd")


func test_the_scale_coat_is_a_rare_coat_of_tide_iron() -> void:
	eq(Gear.slot_of(&"coat_scale"), &"body", "worn on the body")
	eq(GearTree.row(&"coat_scale").get("grade", &""), &"rare", "a rare piece")
	eq(GearTree.made_of(&"coat_scale"), &"tide_iron", "made of the harvester's tide iron")
	check(Crafting.recipe(&"coat_scale").get("at", &"") == &"bench", "made at a bench")
	check(FightKit.of([&"coat_scale"]).scale, "the kit reads it")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


## What each blow does, in order, to a body facing east: `from` is where the
## attacker stands relative to the player.
func _blows(kit: Array[StringName], froms: Array[Vector2]) -> Array[int]:
	var sim := F.make_sim()
	sim.hero.kit = FightKit.of(kit)
	sim.hero.facing = 0.0
	sim.hero.health = 100
	var m := F.still(sim, &"cutter", sim.hero.pos + Vector2(3.0, 0.0), PI)
	sim._begin()
	var out: Array[int] = []
	for from in froms:
		m.pos = sim.hero.pos + from
		var before := sim.hero.health
		sim._hurt_hero(m, 3, -from.normalized(), 0.0, 0)
		out.append(before - sim.hero.health)
		sim.now += 2000.0
	return out


func test_the_first_blow_at_the_back_is_turned() -> void:
	var back := Vector2(-1.5, 0.3)
	var front := Vector2(1.5, 0.0)
	var side := Vector2(0.0, 1.5)
	eq(_blows([], [back]), [3] as Array[int], "bare, a blow at the back hurts")
	eq(_blows([&"coat_scale"], [back, back]), [0, 3] as Array[int], "the coat turns the first at the back, not the second")
	eq(_blows([&"coat_scale"], [front, back]), [3, 0] as Array[int], "a blow from the front is not turned, and does not spend it")
	eq(_blows([&"coat_scale"], [side]), [3] as Array[int], "nor one square at the side")


func test_it_turns_one_a_fight_and_is_never_spent() -> void:
	var sim := F.make_sim()
	sim.hero.kit = FightKit.of([&"coat_scale"])
	sim.hero.health = 100
	var m := F.still(sim, &"cutter", sim.hero.pos + Vector2(-1.5, 0.0), 0.0)
	var took: Array[int] = []
	for fight in 2:
		sim._begin()
		for k in 2:
			var before := sim.hero.health
			sim._hurt_hero(m, 3, Vector2.RIGHT, 0.0, 0)
			took.append(before - sim.hero.health)
			sim.now += 2000.0
		sim.fight_on = false
		sim.now += 60000.0
	eq(took, [0, 3, 0, 3] as Array[int], "one turned in each fight")


## THE BOUT: the shoulder reader (a player who does not see behind them), 16
## bouts a crowd, bare and in the coat. Its identity: it takes one blow out of a
## fight where bodies get round the player, and costs nothing where they do not.
func _gate(kind: StringName, n: int, kit: Array[StringName]) -> Dictionary:
	var won := 0
	var lost := 0
	for i in 16:
		var r := G.gate(true, i % 8, kind, n, kit, 120.0, &"knife", 0, 1000 + i / 8, true)
		won += int(r.won)
		lost += int(r.lost)
	return {"won": won, "lost": float(lost) / 16.0}


func test_the_scale_coat_bout() -> void:
	var c: Array[StringName] = [&"coat_scale"]
	var paid := 0.0
	for pair: Array in [[&"runner", 3], [&"cutter", 2], [&"harvester", 1]]:
		var b := _gate(pair[0], pair[1], [])
		var w := _gate(pair[0], pair[1], c)
		print("  info %d %s: bare won %d/16 losing %.2f; coat won %d/16 losing %.2f" % [pair[1], pair[0], b.won, b.lost, w.won, w.lost])
		check(w.lost <= b.lost + 0.01, "the coat never costs health (%s)" % pair[0])
		gt(float(w.won), float(b.won) - 1.5, "nor bouts (%s)" % pair[0])
		paid = maxf(paid, b.lost - w.lost)
	gt(paid, 0.5, "and saves health where bodies get round the player")
