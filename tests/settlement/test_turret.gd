extends TestCase
## The turret (owner, 2026-09-17): what it shoots, that its blow is the fight's
## own, that it is a decision to switch on, and that a kill it makes is not the
## player's.

const Sx := preload("res://tests/save/save_fixture.gd")


func _body(kind: StringName, at: Vector2) -> MobState:
	var m := MobState.new(kind, at, 7)
	return m


# --- what it shoots ------------------------------------------------------------

func test_it_answers_what_comes_for_the_place_and_nothing_that_walks_past() -> void:
	var from := Vector2.ZERO
	var worker := _body(&"harvester", Vector2(3, 0))
	var pressing := _body(&"runner", Vector2(4, 0))
	pressing.mood = MobState.ATTACKING
	var raider := _body(&"harvester", Vector2(6, 0))
	raider.raider = true
	eq(TurretRules.wants(worker), 0, "a machine going about its round is let be")
	eq(TurretRules.wants(pressing), 1, "a body pressing a fight is shot at")
	eq(TurretRules.wants(raider), 2, "a raider most of all")
	var picked := TurretRules.pick([worker, pressing, raider], from)
	check(picked == raider, "a raider further off is still picked before a nearer fight")
	raider.alive = false
	check(TurretRules.pick([worker, pressing, raider], from) == pressing, "a dead one is not")


func test_it_reaches_a_yard_and_no_further() -> void:
	var near_one := _body(&"runner", Vector2(TurretRules.REACH - 0.5, 0))
	near_one.mood = MobState.CHASING
	var far_one := _body(&"runner", Vector2(TurretRules.REACH + 0.5, 0))
	far_one.mood = MobState.CHASING
	check(TurretRules.pick([far_one], Vector2.ZERO) == null, "out of reach is out of reach")
	check(TurretRules.pick([far_one, near_one], Vector2.ZERO) == near_one, "in reach is shot")
	check(TurretRules.pick([near_one], Vector2.ZERO, func(_m: MobState) -> bool: return false) == null,
		"and nothing it cannot see")


func test_its_bolt_burns_through_plate() -> void:
	var b := TurretRules.blow()
	check(b.cuts, "a machine's own gun reaches past plate")
	gt(float(b.dmg), 0.0, "and hurts")


# --- a decision to switch on -----------------------------------------------------

func test_it_is_switched_by_hand_and_draws_nothing_switched_off() -> void:
	check(StructureKind.switched(StructureKind.TURRET), "a turret is switched, not staffed")
	check(StructureKind.switched(StructureKind.SPOOFER), "and so is a spoofer")
	check(not StructureKind.switched(StructureKind.RADIO_MAST), "a mast is switched by taking the hands off it")
	var s := Settlement.new(1, Realm.SURFACE, Vector2(100, 100))
	s.worked_at = 0.0
	s.add(StructureKind.BATTERY_STACK, Vector2(101, 100))
	var gun := s.add(StructureKind.TURRET, Vector2(102, 100))
	s.charge = 5.0
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 30.0, {"seed": 4, "land": &""})
	check(gun.powered and TurretRules.armed(gun), "fed, it is armed")
	var loud := s.signature().found_tech
	gun.off = true
	var banked := s.charge
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 60.0, {"seed": 4, "land": &""})
	check(not TurretRules.armed(gun), "switched off, it is not")
	near(s.charge, banked, 1e-4, "and it draws nothing from the bank")
	lt(s.signature().found_tech, loud, "and the stolen thing in the walls is that much quieter")
	var back := Structure.from_dict(JSON.parse_string(JSON.stringify(gun.as_dict())))
	check(back.off, "and it is still off after a save")


func test_switched_on_it_has_power_this_minute_and_nothing_is_spent_asking() -> void:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(100, 100))
	s.worked_at = 0.0
	s.add(StructureKind.BATTERY_STACK, Vector2(101, 100))
	var gun := s.add(StructureKind.TURRET, Vector2(102, 100))
	gun.off = true
	s.charge = 3.0
	@warning_ignore("return_value_discarded")
	SettlementRules.catch_up(s, 30.0, {"seed": 4, "land": &""})
	check(not gun.powered, "off, it has none")
	gun.off = false
	SettlementRules.wire_now(s, 40.0, {"seed": 4, "land": &""})
	check(gun.powered, "switched on, it has power at once, not at the next half hour")
	SettlementRules.wire_now(s, 41.0, {"seed": 4, "land": &""})
	near(s.charge, 3.0, 1e-5, "and asking twice spent nothing")


# --- in a running game ---------------------------------------------------------

func _holdings(g: Game) -> Node:
	return Sx.system(g, "46_settlements")


func _defences(g: Game) -> Node:
	return Sx.system(g, "47_defences")


## A turret with a bank behind it, and the half hour it takes the bank to be
## wired to it (power is settled by the slice, never by the frame).
func _armed_holding(g: Game) -> Array:
	var sys := _holdings(g)
	var s: Settlement = sys.call("found", Realm.SURFACE, g.player.pos)
	s.add(StructureKind.BATTERY_STACK, g.player.pos + Vector2(-2, 2))
	s.charge = 6.0
	var gun: Structure = sys.call("place_piece", s, StructureKind.TURRET, g.player.pos + Vector2(0, 3))
	g.clock.skip(SettlementRules.SLICE + 1.0)
	sys.call("settle_up")
	return [s, gun]


## Somewhere within reach of the gun it can see: the ground round a spawn is not
## all level, so the test asks the world.
func _in_sight(g: Game, gun: Structure) -> Vector2:
	for far: float in [3.0, 4.0, 5.0]:
		for i in 12:
			var at := gun.pos + Vector2.from_angle(TAU * float(i) / 12.0) * far
			if g.query.standable(floori(at.x), floori(at.y)) and Senses.line_clear(g.world, g.query, gun.pos, at):
				return at
	return Vector2.INF


func test_a_raider_in_reach_is_shot_through_the_fight_and_the_kill_is_not_the_player_s() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=11"])
	await frames(3)
	var made: Array = _armed_holding(g)
	var gun: Structure = made[1]
	check(TurretRules.armed(gun), "the turret is armed")
	var sim: FightSim = g.player.sim
	var spot := _in_sight(g, gun)
	check(is_finite(spot.x), "somewhere the gun can see")
	var m := sim.add_mob(&"runner", spot)
	check(m != null, "a body to shoot at")
	m.raider = true
	var health := m.health
	var hits: Array[int] = []
	var hear := func(_a: Object, _t: Object, _d: int, _p: bool, _at: Vector3) -> void: hits.append(1)
	Events.hit.connect(hear)
	var scrap := g.inventory.count(&"scrap")
	var budget := int(240.0 * TestCase.machine_slack())
	for i in budget:
		if not m.alive or m.health < health:
			break
		await frames(1)
	Events.hit.disconnect(hear)
	check(bool(_defences(g).call("tour_seen", &"turret_fired")), "it fired")
	lt(float(m.health), float(health), "and the bolt took health off the body, through the fight")
	eq(hits.size(), 0, "and not one Events.hit was said, because the player struck nothing")
	check(is_finite(m.struck_from.x), "the body knows where the shot came from")
	# Finish it with the turret's own blows and look at what the player was given.
	var guard := 0
	while m.alive and guard < 40:
		guard += 1
		m.hurt_by.clear()
		@warning_ignore("return_value_discarded")
		sim.strike(m, TurretRules.blow(), gun.pos)
	check(not m.alive, "struck enough, it is down")
	await frames(3)
	eq(g.inventory.count(&"scrap"), scrap, "and nothing off a kill the player did not make is in their creel")
	Sx.end(g)


func test_a_machine_walking_past_is_not_shot() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=128", "--hour=11"])
	await frames(3)
	var made: Array = _armed_holding(g)
	var gun: Structure = made[1]
	var sim: FightSim = g.player.sim
	var spot := _in_sight(g, gun)
	var m := sim.add_mob(&"harvester", spot if is_finite(spot.x) else gun.pos + Vector2(3.0, 0.0))
	m.mood = MobState.WORKING
	await frames(90)
	check(not bool(_defences(g).call("tour_seen", &"turret_fired")) or m.roused(),
		"a calm machine at its work is let be")
	Sx.end(g)

