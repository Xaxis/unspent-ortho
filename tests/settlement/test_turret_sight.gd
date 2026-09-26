extends TestCase
## A GUN STANDS ABOVE ITS OWN STAKE WALL (SETTLE.md S7). A turret sees over its
## own holding's palisade, gate and plate wall, so a walled yard's guns fire on
## what the wall holds at the ring. Another holding's wall still blinds it, and
## so does the land.

const Sx := preload("res://tests/save/save_fixture.gd")


func _game() -> Game:
	Sx.use_root("turret_sight")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10",
		"--holding=hut,battery_stack,battery_stack,solar_array"])
	var coast: Coast = Sx.system(g, "30_mobs").get("coast")
	coast.spawning = false
	coast.rounds = false
	g.player.sim.clear_mobs()
	return g


## A raider standing still past a wall, its working part (the back) to the gun.
func _raider(g: Game, at: Vector2) -> MobState:
	var m := g.player.sim.add_mob(&"demolisher", at)
	m.facing = 0.0
	m.aim = 0.0
	m.line_a = at
	m.line_b = at
	m.calm_until = INF
	m.raider = true
	return m


## The gun at `gun`, the wall a step east of it (whose it is: `wall_home`), the
## raider three steps east. Returns the raider's life lost after a few shots.
func _shot_through(own_wall: bool) -> int:
	var g := _game()
	await frames(3)
	var h := Sx.system(g, "46_settlements")
	var s: Settlement = h.call("here")
	var gun_at := s.centre + Vector2(0, 4)
	var gun: Structure = h.call("place_piece", s, StructureKind.TURRET, gun_at, 0.0)
	gun.powered = true
	var wall_home := s
	if not own_wall:
		wall_home = h.call("found", h.call("realm_here"), gun_at + Vector2(1.2, 6.0))
	for dy: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		@warning_ignore("return_value_discarded")
		h.call("place_piece", wall_home, StructureKind.PALISADE, gun_at + Vector2(1.5, dy), PI * 0.5)
	g.player.pos = s.centre + Vector2(-3, -3)
	g.player.hero.pos = g.player.pos
	var m := _raider(g, gun_at + Vector2(3.5, 0))
	var life := m.health
	await frames(240)
	var lost := life - m.health
	Sx.end(g)
	Sx.finish()
	return lost


func test_a_walled_turret_fires_over_its_own_palisade() -> void:
	var lost: int = await _shot_through(true)
	gt(lost, 0, "the gun hit the raider over its own wall (%d)" % lost)


func test_another_holdings_wall_still_blinds_it() -> void:
	var lost: int = await _shot_through(false)
	eq(lost, 0, "a wall that is not its own stands in its way")
