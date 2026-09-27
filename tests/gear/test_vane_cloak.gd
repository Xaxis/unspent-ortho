extends TestCase
## THE VANE CLOAK (GEAR.md §6, G8): a sweeper's trued vane cut into a cloak's
## shoulders. Its hook is FightSim._dodge: in a wind stronger than VANE_WIND, a
## dodge within VANE_ARC of downwind (FightSim.downwind) carries VANE_CARRY as
## far. Against the wind, across it, or in a light one, a dodge is a dodge. It
## is worn on the back, where the glide wing goes: one or the other.

const F := preload("res://tests/fight/fixture.gd")
const G := preload("res://tests/fight/test_crowd_reader.gd")


func test_the_vane_cloak_is_a_prime_cloak_of_the_sweepers_vane() -> void:
	eq(Gear.slot_of(&"cloak_vane"), &"back", "worn on the back, where the wing goes")
	eq(GearTree.row(&"cloak_vane").get("grade", &""), &"prime", "a prime piece")
	eq(GearTree.made_of(&"cloak_vane"), &"vane_true", "made of the sweeper's trued vane")
	check(Crafting.recipe(&"cloak_vane").get("at", &"") == &"bench", "made at a bench")
	check(FightKit.of([&"cloak_vane"]).vane, "the kit reads it")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


## How far one dodge carries, from standing, the way `dir` says (a unit vector,
## or a turn off downwind in radians when `off` is given).
func _dodge(kit: Array[StringName], wind: float, off: float) -> float:
	var sim := F.make_sim(F.flat_world(64))
	sim.hero.kit = FightKit.of(kit)
	sim.moment.wind = wind
	var down := Weather.bearing(sim.moment.seed_value) * (signf(wind) if wind != 0.0 else 1.0)
	var start := sim.hero.pos
	sim.hero.move = down.rotated(off)
	sim.press_dodge()
	F.ms(sim, FightRules.DODGE_MS + 40.0)
	return sim.hero.pos.distance_to(start)


func test_a_dodge_downwind_carries_twice_as_far() -> void:
	var bare := _dodge([], 0.8, 0.0)
	var v: Array[StringName] = [&"cloak_vane"]
	near(_dodge(v, 0.8, 0.0) / bare, FightKit.VANE_CARRY, 0.15, "in a strong wind, downwind, twice as far (%.2f against %.2f)" % [_dodge(v, 0.8, 0.0), bare])
	near(_dodge(v, -0.8, 0.0) / bare, FightKit.VANE_CARRY, 0.15, "whichever way the wind blows")
	near(_dodge(v, 0.8, deg_to_rad(40.0)) / bare, FightKit.VANE_CARRY, 0.15, "and a little off it")
	near(_dodge(v, 0.8, PI) / bare, 1.0, 0.05, "upwind, as ever")
	near(_dodge(v, 0.8, PI * 0.5) / bare, 1.0, 0.05, "across it, as ever")
	near(_dodge(v, 0.2, 0.0) / bare, 1.0, 0.05, "and in a light wind, as ever")
	near(_dodge([], 0.8, 0.0) / bare, 1.0, 0.05, "and bare, as ever")


## THE BOUT, standing to fight: the shoulder reader in a strong wind (0.8), 16
## bouts a crowd, bare and in the cloak. The reader does not choose its dodges
## by the wind, and a dodge carried twice as far carries it out of the opening
## it dodged to take: this is the cloak's cost, worn in a fight it was not
## made for.
func _gate(kind: StringName, n: int, kit: Array[StringName]) -> Dictionary:
	var won := 0
	var lost := 0
	for i in 16:
		var r := G.gate(true, i % 8, kind, n, kit, 120.0, &"knife", 0, 1000 + i / 8, true, 0.8)
		won += int(r.won)
		lost += int(r.lost)
	return {"won": won, "lost": float(lost) / 16.0}


func test_the_vane_cloak_bout() -> void:
	var c: Array[StringName] = [&"cloak_vane"]
	for pair: Array in [[&"runner", 3], [&"cutter", 2], [&"harvester", 1]]:
		var b := _gate(pair[0], pair[1], [])
		var w := _gate(pair[0], pair[1], c)
		print("  info wind 0.8, %d %s: bare won %d/16 losing %.2f; cloak won %d/16 losing %.2f" % [pair[1], pair[0], b.won, b.lost, w.won, w.lost])
		gt(float(w.won), float(b.won) - 1.5, "the cloak costs no bouts (%s)" % pair[0])


## THE ESCAPE, what it is for: a harvester roused four tiles off and the player
## running downwind in a strong wind, dodging on along the run whenever its
## tell comes (a runner does not keep up with a running player; a charge does). How far ahead after five seconds (inside its tether), and how many bites, over
## eight starts.
func _flee(kit: Array[StringName]) -> Vector2:
	var gap := 0.0
	var bites := 0
	for i in 8:
		MobState._next_id = 3000 + i
		var sim := F.make_sim(F.flat_world(128), Vector2(30.5, 64.5))
		sim.hero.kit = FightKit.of(kit)
		sim.moment.wind = 0.8
		var down := Weather.bearing(sim.moment.seed_value)
		sim.hero.pos = Vector2(64.5, 64.5) - down * 30.0
		var m := sim.add_mob(&"harvester", sim.hero.pos - down.rotated(float(i) * 0.1 - 0.35) * 4.0)
		m.facing = (sim.hero.pos - m.pos).angle()
		m.aim = m.facing
		m.disturbed = true
		m.set_mood(MobState.CHASING, sim.now)
		var answered := -INF
		for k in 600:
			sim.hero.move = down
			sim.hero.run = true
			if m.blow != null and m.blow_phase(sim.now) == &"windup" and m.blow_at != answered and sim.now - m.blow_at > 200.0:
				answered = m.blow_at
				sim.press_dodge()
			sim.slices(1)
			for e in sim.drain():
				bites += int(e.type == &"hurt")
		gap += m.pos.distance_to(sim.hero.pos)
	return Vector2(gap / 8.0, float(bites) / 8.0)


func test_the_vane_cloak_escape() -> void:
	var bare := _flee([])
	var cloak := _flee([&"cloak_vane"] as Array[StringName])
	print("  info running downwind from a harvester in a strong wind: bare %.1f tiles ahead, bitten %.2f; cloak %.1f ahead, bitten %.2f" % [bare.x, bare.y, cloak.x, cloak.y])
	check(cloak.y <= bare.y, "no more bites")
	gt(cloak.x, bare.x + 1.0, "and further ahead of it")
