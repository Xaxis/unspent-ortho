extends TestCase
## THE CLIMB IS A SET PIECE IN TIME (43_climb's contract, #98): from the first
## hand-on to the cable until he steps off at the hub the world clock runs at
## SET_PIECE of its rate and the walkers at the whole of it, so the climb's gait
## stays in real seconds and the day does not pass under it. Measured on the
## physics clock the world is driven by (Game._physics_process), a climb's world
## minutes and its walkers' minutes against its real seconds; the lead the
## walkers gained comes back with a save made mid-climb.

const Sx := preload("res://tests/save/save_fixture.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")
const Route := preload("res://src/core/colossus/colossus_route.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")

const SEED := 1
const SIZE := 48
## Physics frames each measure runs.
const FRAMES := 120


## A walk minute from which leg 0 of the small world's walker stands for a while.
func _planted_minute() -> float:
	var d: RefCounted = Def.walkers(SIZE)[0]
	var r: RefCounted = Route.make(d, SEED, SIZE)
	var m := 0.0
	while m < 2000.0:
		var ok := true
		var t := 0.0
		while t < 240.0 and ok:
			ok = int(Walk.pose(d, r, m + t).swinging) != 0
			t += 5.0
		if ok:
			return m
		m += 10.0
	return 0.0


## World minutes and walk minutes that pass over FRAMES physics frames, and the
## real seconds those frames are.
func _measure(g: Game, colossi: Node) -> Vector3:
	var w0 := g.clock.minutes
	var k0: float = colossi.call(&"minutes")
	for i in FRAMES:
		await tree.physics_frame
	var secs := float(FRAMES) / float(Engine.physics_ticks_per_second)
	return Vector3(g.clock.minutes - w0, float(colossi.call(&"minutes")) - k0, secs)


func test_up_the_leg_the_world_runs_at_an_eighth_and_the_walkers_at_full() -> void:
	Sx.use_root("climb-time")
	var g := Sx.game(tree, ["--seed=%d" % SEED, "--size=%d" % SIZE, "--hour=11", "--colossus=0@%.0f" % _planted_minute()])
	g.player.sim.clear_mobs()
	await process_frames(4)
	var sys := Sx.system(g, "43_climb")
	var colossi := tree.get_first_node_in_group(&"colossi")
	var rate := g.clock.rate
	var share: float = sys.get("SET_PIECE")
	var ground := await _measure(g, colossi)
	near(ground.x, ground.z * rate, 0.05, "on the ground the world keeps its rate")
	near(ground.y, ground.x, 0.05, "and the walkers keep the world's")
	sys.set("walker", 0)
	sys.call(&"_begin", WalkerClimb.begin(0, SEED))
	var up := await _measure(g, colossi)
	near(up.x, up.z * rate * share, 0.05, "up the leg the world runs at the set piece's share (%.2f world min in %.1f s)" % [up.x, up.z])
	near(up.y, up.z * rate, 0.05, "and the walkers at the whole of the rate (%.2f walk min)" % up.y)
	var lead := g.clock.walk_lead
	gt(lead, 0.0, "the walkers are ahead of the world by what it held back")
	# Saved mid-climb and loaded: the walkers stand where they stood.
	var saver := Sx.system(g, "05_save")
	eq(String(saver.call("save_to", 2)), "", "saved mid-climb")
	var walk_then: float = colossi.call(&"minutes")
	var world_then := g.clock.minutes
	Sx.end(g)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(2, o), "", "slot 2 boots")
	var b := Sx.game(tree, [], o)
	near(b.clock.walk_lead, lead, 0.5, "the walkers' lead comes back with the save")
	var colossi_b := tree.get_first_node_in_group(&"colossi")
	near(float(colossi_b.call(&"minutes")) - b.clock.minutes, b.clock.walk_lead, 0.01, "and the walks read it: they are that far ahead of the world")
	near(b.clock.minutes, world_then, 2.0, "at the world minute it was saved at")
	check(is_finite(walk_then), "(the walk minute when saved, %.1f, staged)" % walk_then)
	Sx.end(b)
	Sx.finish()


func test_stepping_off_at_the_hub_gives_the_world_its_rate_back() -> void:
	var g := Sx.game(tree, ["--seed=%d" % SEED, "--size=%d" % SIZE, "--hour=11", "--colossus=0@%.0f" % _planted_minute()])
	g.player.sim.clear_mobs()
	await process_frames(4)
	var sys := Sx.system(g, "43_climb")
	var colossi := tree.get_first_node_in_group(&"colossi")
	var rate := g.clock.rate
	var share: float = sys.get("SET_PIECE")
	sys.set("walker", 0)
	sys.call(&"_begin", WalkerClimb.begin(0, SEED))
	await process_frames(2)
	var w0 := g.clock.minutes
	var lead0 := g.clock.walk_lead
	sys.call(&"_end")
	var down := 0.0
	for row: Dictionary in WalkerClimb.PITCHES:
		down += float(row.ride)
	near(g.clock.minutes - w0, down * rate * share, 0.01, "the lifts down pass the world's share of the time the rides took")
	near(g.clock.walk_lead - lead0, down * rate * (1.0 - share), 0.01, "and the walkers walk the whole of it")
	var after := await _measure(g, colossi)
	near(after.x, after.z * rate, 0.05, "off the leg the world has its rate back")
	near(after.y, after.x, 0.05, "and the walkers keep it with the world again")
	Sx.end(g)
