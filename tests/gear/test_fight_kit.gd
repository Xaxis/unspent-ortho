extends TestCase
## The fight reads the kit (FightKit, mechanics pass 2a): three modules each do
## in a fight what ModifierTable says they decide, with and without the module.
##   harmonic  a blow that rings off plate still does 1, and is louder for it
##   phase     the first blow on a body reaches its part from any side, guard and all
##   damp      a blow is half as loud

const F := preload("res://tests/fight/fixture.gd")


func test_the_kit_is_read_off_what_is_fitted() -> void:
	var none := FightKit.of([])
	check(not none.harmonic and not none.phase and not none.damp, "nothing fitted, nothing changed")
	check(FightKit.of([&"knife", &"mod_harmonic"]).harmonic, "harmonic")
	check(FightKit.of([&"mod_phase"]).phase, "phase")
	check(FightKit.of([&"mod_damp"]).damp, "damp")
	var lo := Loadout.new()
	lo.hold(&"knife")
	check(lo.socket(Gear.HAND_SLOT, &"mod_harmonic"), "the knife takes the harmonic edge")
	check(FightKit.from_loadout(lo).harmonic, "and the loadout's kit has it")


func test_a_blow_is_as_loud_as_the_kit_makes_it() -> void:
	near(FightKit.of([]).blow_noise(false), 1.0, 1e-6, "bare")
	near(FightKit.of([&"mod_damp"]).blow_noise(false), 0.5, 1e-6, "damped")
	gt(FightKit.of([&"mod_harmonic"]).blow_noise(true), 1.0, "a harmonic ring is louder")
	near(FightKit.of([&"mod_harmonic"]).blow_noise(false), 1.0, 1e-6, "and a real hit no louder")


## A still harvester facing west, its front the working part; the hero behind it,
## on its plate.
func _behind(kit: Array[StringName]) -> Array:
	var sim := F.make_sim()
	var m := F.still(sim, &"harvester", Vector2(30.5, 20.5), PI)
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	sim.hero.kit = FightKit.of(kit)
	sim.hero.pos = m.pos + Vector2(m.radius + sim.hero.radius + 0.3, 0.0)
	sim.hero.facing = PI
	return [sim, m]


func _swing(sim: FightSim) -> Dictionary:
	sim.press_swing()
	F.ms(sim, 300)
	var hit := F.first(sim.drain(), &"hit")
	F.ms(sim, 700)
	sim.drain()
	return hit


func test_harmonic_does_one_through_plate() -> void:
	var r := _behind([])
	var m: MobState = r[1]
	var hp := m.health
	var hit := _swing(r[0])
	eq(hit.get("plate", null), true, "bare: its back is plate")
	eq(m.health, hp, "and the ring does nothing")
	r = _behind([&"mod_harmonic"])
	m = r[1]
	hp = m.health
	hit = _swing(r[0])
	eq(hit.get("plate", null), true, "harmonic: still a ring")
	eq(m.health, hp - 1, "and it takes one")
	eq(int(hit.get("damage", -1)), 1, "the hit says so")


func test_phase_reads_the_part_through_plate_for_the_first_blow_only() -> void:
	var r := _behind([&"mod_phase"])
	var sim: FightSim = r[0]
	var m: MobState = r[1]
	var hp := m.health
	var first := _swing(sim)
	eq(first.get("plate", null), false, "phase: the first blow reaches the part from its back")
	lt(float(m.health), float(hp), "and hurts it")
	var second := _swing(sim)
	eq(second.get("plate", null), true, "the second is a blow on plate again")
	r = _behind([])
	eq(_swing(r[0]).get("plate", null), true, "bare: the first blow from its back is plate")


func test_phase_reads_through_a_closed_guard_once() -> void:
	for coil: bool in [false, true]:
		var sim := F.make_sim()
		var m := F.still(sim, &"harvester", Vector2(30.5, 20.5), PI)
		sim.hero.inventory.add(&"knife")
		sim.hero.inventory.set_held(&"knife")
		sim.hero.kit = FightKit.of([&"mod_phase"] if coil else [])
		sim.hero.pos = m.pos + Vector2(-(m.radius + sim.hero.radius + 0.3), 0.0)
		sim.hero.facing = 0.0
		m.disturbed = true
		m.set_mood(MobState.ATTACKING, sim.now)
		check(not sim.reaches_part(m, sim.hero.pos), "roused, its guard is closed")
		var hp := m.health
		var hit := _swing(sim)
		if coil:
			eq(hit.get("plate", null), false, "coil: the first blow reads through the guard")
			lt(float(m.health), float(hp), "and hurts it")
			check(not m.stunned(sim.now), "and does not stop its work")
		else:
			eq(hit.get("plate", null), true, "bare: the closed guard throws it off")
			eq(m.health, hp)


## In a running game: what is fitted on the gear page is the kit the fight reads
## (54_gear hands it over), and a blow's noise is the kit's (32_disposition).
func test_the_running_game_fights_with_what_is_fitted() -> void:
	var game := Game.new()
	tree.root.add_child(game)
	game.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=96", "--give=knife:1,mod_damp:1", "--held=knife"])))
	await frames(2)
	var gear: Node = game.get_node("54_gear")
	var lo: Loadout = gear.get("loadout")
	var hero := game.player.hero
	check(not hero.kit.damp, "bare at the start")
	var bare := _hit_noise(game)
	check(lo.socket(Gear.HAND_SLOT, &"mod_damp"), "the damper goes on the knife")
	check(hero.kit.damp, "and the fight has it")
	var damped := _hit_noise(game)
	gt(bare, 0.0, "a blow makes a noise")
	near(damped, bare * FightKit.DAMP_NOISE, 0.01, "and a damped one half of it (%.2f against %.2f)" % [damped, bare])
	game.queue_free()
	await frames(1)


func _hit_noise(game: Game) -> float:
	var sim := game.player.sim
	sim.noise_radius = 0.0
	sim.noise_ms = -INF
	Events.hit.emit(game.player, null, 1, false, game.player.position)
	return sim.noise_radius
