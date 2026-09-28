extends TestCase
## THE LINE BRINGS THE ROOF DOWN (FightSim.hangings, AbilityGrapple): a cracked
## stone hanging from a cave's roof is a hold for the grapple, and the line pulls
## it down instead of the body up. A moment later it lands on what stands under
## it: a machine is hurt and stalls whatever side its plate is on, a player is
## hurt too, a body stood off it is not, and a stone that has fallen is gone.

const F := preload("res://tests/fight/fixture.gd")
const WARDEN := &"sentinel.limestone_caves"


static func _sim() -> FightSim:
	var sim := F.make_sim(F.flat_world(48), Vector2(20.5, 20.5))
	sim.hero.facing = 0.0
	return sim


func test_the_grapple_takes_a_hanging_stone_ahead_and_pulls_it_down() -> void:
	var sim := _sim()
	var id := sim.hang(Vector2(24.5, 20.5), 4.0)
	var a := AbilityGrapple.anchor(sim.world, sim.query, sim.hero.pos, Vector2.RIGHT, sim)
	eq(a.get("what", &""), &"hanging", "the line takes the stone ahead")
	eq(int(a.get("id", -1)), id, "that stone")
	check(AbilityGrapple.anchor(sim.world, sim.query, sim.hero.pos, Vector2.LEFT, sim).get("what", &"") != &"hanging",
		"and not one behind the player")
	check(sim.pull_down(id), "pulled")
	check(not sim.pull_down(id), "a stone already coming down is not pulled again")
	check(AbilityGrapple.anchor(sim.world, sim.query, sim.hero.pos, Vector2.RIGHT, sim).get("what", &"") != &"hanging",
		"and is no hold while it falls")


func test_it_lands_on_the_machine_under_it_whatever_its_plate() -> void:
	var sim := _sim()
	# The warden faces the player: its working part (back) is away from them and
	# the stone comes down on its crown all the same.
	var m := F.still(sim, WARDEN, Vector2(24.5, 20.5), PI)
	var other := F.still(sim, WARDEN, Vector2(30.5, 20.5), PI)
	var id := sim.hang(m.pos, 4.0)
	var hp := m.health
	var hp2 := other.health
	sim.drain()
	sim.pull_down(id)
	F.ms(sim, FightSim.FALL_MS * 0.6)
	eq(m.health, hp, "it has not landed yet: the pull is a moment long")
	F.ms(sim, FightSim.FALL_MS)
	var ev := sim.drain()
	eq(F.count(ev, &"hanging_fell"), 1, "it fell")
	eq(F.count(ev, &"fell_on"), 1, "on one body")
	lt(m.health, hp, "the body under it is hurt (%d of %d)" % [m.health, hp])
	check(m.stunned(sim.now), "and stalls")
	F.ms(sim, FightSim.FALL_STALL_MS - 300.0)
	check(m.stunned(sim.now), "for the fall's whole stall")
	eq(other.health, hp2, "a body stood off it is not touched")
	eq(sim.hangings.size(), 0, "and the stone is gone")


func test_it_lands_on_the_player_too() -> void:
	var sim := _sim()
	var id := sim.hang(sim.hero.pos + Vector2(0.2, 0.0), 4.0)
	var hp := sim.hero.health
	sim.pull_down(id)
	F.ms(sim, FightSim.FALL_MS + 200.0)
	lt(float(sim.hero.health), float(hp), "a player under it is hurt")
