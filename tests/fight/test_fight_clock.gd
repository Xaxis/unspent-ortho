extends TestCase
## The hitstop and Shift's tap are counted in the fight's steps (40_fight
## `_clock`), so each is the same number of steps at any frame rate: at 60 fps
## the windows are the milliseconds they always were, and at 20 fps a slow box
## gets the same fight rather than a longer freeze or a tap read as a hold.
## Played on a fixed step (TestCase.stepped_now); run with TEST_FIXED_FPS=20 it
## must count the same.

const Sx := preload("res://tests/save/save_fixture.gd")


func _game() -> Game:
	Sx.use_root("fight-clock")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	(Sx.system(g, "30_mobs").get("coast") as Object).set("spawning", false)
	g.player.sim.clear_mobs()
	return g


func _shift(down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_SHIFT
	e.keycode = KEY_SHIFT
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## Steps the fight is held for by a hitstop of `seconds`.
func _held_steps(g: Game, seconds: float) -> int:
	var f := Sx.system(g, "40_fight")
	await tree.physics_frame
	f.call(&"_stop", seconds)
	var n := 0
	await tree.physics_frame
	while g.player.sim.hold and n < 600:
		n += 1
		await tree.physics_frame
	return n


## Whether Shift held down for `steps` physics steps, out of a fight, dodged.
func _tap_dodges(g: Game, steps: int) -> bool:
	var hero := g.player.sim.hero
	for i in 60:
		await tree.physics_frame
	var was := hero.dodge_at
	_shift(true)
	for i in steps:
		await tree.physics_frame
	_shift(false)
	for i in 3:
		await tree.physics_frame
	return hero.dodge_at != was


func test_the_hitstop_and_the_tap_are_counted_in_steps() -> void:
	if not stepped_now():
		return
	var g := _game()
	var tick := float(Engine.physics_ticks_per_second)
	for s: float in [0.04, 0.05, 0.06, 0.08]:
		var n: int = await _held_steps(g, s)
		print("  info hitstop %.2f s held %d steps" % [s, n])
		check(absf(n - s * tick) <= 1.0, "a hitstop of %.2f s holds %.1f steps give or take one, not %d" % [s, s * tick, n])
	# TAP_MS is 180: ten steps of a sixtieth are a tap, eleven a hold.
	var tap := floori(DodgeInput.TAP_MS / 1000.0 * tick)
	check(await _tap_dodges(g, tap), "Shift down for %d steps is a tap: it dodges" % tap)
	check(not await _tap_dodges(g, tap + 2), "down for %d steps is a hold: it only runs" % (tap + 2))
	Sx.end(g)
