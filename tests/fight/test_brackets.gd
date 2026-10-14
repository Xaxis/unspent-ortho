extends TestCase
## EARNED BRACKETS (Brackets, 57_brackets; owner, 2026-10-14: "the user should
## be able to earn more health brackets and stamina brackets"). Machines brought
## down and keepers felled earn health brackets; running earns stamina brackets.
## An earned bracket comes full, raises the maximum the fight uses, is said in
## plain words with how the next is earned, and is kept with the save.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_what_earns_a_bracket() -> void:
	eq(Brackets.health_earned(0, 0), 0, "none at the start")
	eq(Brackets.health_earned(Brackets.MACHINES_FOR[0] - 1, 0), 0, "one machine short of the first")
	eq(Brackets.health_earned(Brackets.MACHINES_FOR[0], 0), 1, "the first, for bringing machines down")
	eq(Brackets.health_earned(Brackets.MACHINES_FOR[1], 0), 2, "the second")
	eq(Brackets.health_earned(0, 1), 1, "a keeper felled is a bracket of its own")
	eq(Brackets.health_earned(999, 999), Brackets.MACHINES_FOR.size() + Brackets.KEEPERS_MOST, "and there is a most")
	eq(Brackets.wind_earned(Brackets.RUN_FOR[0] - 1.0), 0, "a run just short of the first")
	eq(Brackets.wind_earned(Brackets.RUN_FOR[0]), 1, "the first stamina bracket, for running")
	eq(Brackets.machines_to_next(0), Brackets.MACHINES_FOR[0], "how many machines to the next")
	eq(Brackets.machines_to_next(999), -1, "none left to earn that way")
	eq(FightRules.max_health(false, 2), FightRules.HEALTH + 2 * Brackets.HEALTH_BRACKET, "two earned brackets on the health maximum")
	near(FightRules.max_wind(false, 1.0, 1), FightRules.WIND + Brackets.WIND_BRACKET, 0.01, "one on the stamina maximum")


func test_bringing_machines_down_earns_health_in_the_game() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"])
	await process_frames(3)
	var said: Array[String] = []
	var listen := func(t: String) -> void: said.append(t)
	Events.message.connect(listen)
	var before := g.body.max_health
	for i in Brackets.MACHINES_FOR[0]:
		Events.killed.emit(&"runner", Vector3.ZERO)
	await process_frames(3)
	eq(g.body.machines_down, Brackets.MACHINES_FOR[0], "each machine brought down is counted")
	eq(g.body.max_health, before + Brackets.HEALTH_BRACKET, "a health bracket earned: the maximum the fight uses")
	eq(g.body.health, g.body.max_health, "and it comes full")
	check(said.any(func(l: String) -> bool: return l.begins_with("Health bracket earned: 5 now.") and l.contains("machines")),
		"said plainly, with how the next is earned: %s" % [said])
	Events.killed.emit(&"dog.yard", Vector3.ZERO)
	await process_frames(2)
	eq(g.body.machines_down, Brackets.MACHINES_FOR[0], "a dog is not a machine")
	Events.message.disconnect(listen)
	Sx.end(g)


func test_running_earns_stamina_in_the_game() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"])
	await process_frames(3)
	var said: Array[String] = []
	var listen := func(t: String) -> void: said.append(t)
	Events.message.connect(listen)
	# The run itself is counted as he goes (57_brackets): a long run already behind him.
	g.body.run_tiles = Brackets.RUN_FOR[0] - 1.0
	# A real run: the run key held and a direction, with the keys a player has.
	Input.action_press(&"run")
	Input.action_press(&"move_right")
	for i in 60:
		await process_frames(1)
	Input.action_release(&"move_right")
	Input.action_release(&"run")
	await process_frames(2)
	gt(g.body.run_tiles, Brackets.RUN_FOR[0], "running is counted")
	# The maximum is scaled by the body's condition (FightRules.max_wind), which a
	# run can change (wet, tired): asked of the rule with the body as it is now.
	eq(Brackets.wind_earned(g.body.run_tiles), 1, "a stamina bracket earned")
	near(g.body.max_wind, FightRules.max_wind(false, g.body.move_factor, 1), 1.0, "and it is in the maximum the fight uses")
	eq(g.hud.wind_brackets, 4, "and drawn as one more segment")
	check(said.any(func(l: String) -> bool: return l.begins_with("Stamina bracket earned: 4 now.")), "said plainly: %s" % [said])
	Events.message.disconnect(listen)
	Sx.end(g)


func test_what_earned_them_is_kept_with_the_save() -> void:
	var b := Body.new()
	b.machines_down = 7
	b.keepers_down = 1
	b.run_tiles = 812.5
	var c := Body.new()
	SaveCore.load_body(c, JSON.parse_string(JSON.stringify(SaveCore.save_body(b))))
	eq(c.machines_down, 7, "machines brought down")
	eq(c.keepers_down, 1, "keepers felled")
	near(c.run_tiles, 812.5, 0.01, "tiles run")


## RUNNING SPENDS WIND, out of a fight too, and down to the floor he is out of
## breath and walks until a whole bracket is back (Hero.winded): a stamina bar
## that never moved while he ran made earning more of it mean nothing.
func test_running_spends_stamina_and_runs_out() -> void:
	var F := preload("res://tests/fight/fixture.gd")
	var sim := F.make_sim(F.flat_world(200), Vector2(20.5, 100.5))
	check(not sim.fight_on, "no fight")
	var full := sim.hero.wind
	sim.hero.run = true
	sim.hero.move = Vector2.RIGHT
	F.ms(sim, 2000)
	lt(sim.hero.wind, full - 300.0, "two seconds' run spends it (%.0f of %.0f)" % [sim.hero.wind, full])
	var t := 2000.0
	while not sim.hero.winded and t < 14000.0:
		F.ms(sim, 100)
		t += 100.0
	check(sim.hero.winded, "run long enough, he is out of breath (at %.1f s)" % (t / 1000.0))
	F.ms(sim, 200)
	lt(sim.hero.speed, sim.hero.run_speed * 0.8, "and walks (%.1f)" % sim.hero.speed)
	var walked := 0.0
	while sim.hero.winded and walked < 3000.0:
		F.ms(sim, 100)
		walked += 100.0
	check(not sim.hero.winded, "a bracket back, he can run again")
	gt(sim.hero.wind, FightRules.WIND_BACK - FightRules.RUN_WIND_COST * 0.1 - 1.0, "with a whole bracket back (less the step it ran since)")


func test_running_into_a_wall_costs_no_breath() -> void:
	var F := preload("res://tests/fight/fixture.gd")
	var w := F.flat_world(64)
	# A cliff two steps up across his way.
	for y in 64:
		for x in range(25, 64):
			w.level[y * 64 + x] = 6
	var sim := F.make_sim(w, Vector2(24.2, 30.5))
	var full := sim.hero.wind
	sim.hero.run = true
	sim.hero.move = Vector2.RIGHT
	F.ms(sim, 3000)
	lt(sim.hero.speed, 0.5, "he is held at the cliff (%.2f)" % sim.hero.speed)
	gt(sim.hero.wind, full - 1.0, "and spends no breath pressing into it (%.0f of %.0f)" % [sim.hero.wind, full])
