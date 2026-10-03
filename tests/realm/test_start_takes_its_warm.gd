extends TestCase
## THE START'S WORLD IS GOT READY ONCE. A new game's island is raised beside
## the title (RealmWorlds) and RealmWarm builds its once-per-world pieces on the
## raise's worker; the systems that start on that world take them instead of
## building them again on the main thread, where the start is waited on.

const Sx := preload("res://tests/save/save_fixture.gd")
const LIGHTS := preload("res://src/systems/15_lights.gd")


func test_the_light_index_got_ready_beside_the_raise_is_taken() -> void:
	Sx.use_root("start-warm")
	var w := WorldGen.generate(1, 256)
	RealmWarm.prepare(w)
	BootWorld.offer(w)
	var g := Sx.game(tree, ["--seed=1", "--size=256"])
	eq(g.world, w, "the game starts on the world raised for it")
	var lights := Sx.system(g, "15_lights")
	check(LIGHTS._take_prepared(w).is_empty(), "15_lights took the index RealmWarm built, rather than building it again")
	var fresh: Array[Dictionary] = []
	LIGHTS.index_of(w, 0, fresh, {}, {})
	eq((lights.get("sources") as Array).size(), fresh.size(), "the taken index is the whole world's")
	Sx.end(g)
	Sx.finish()


## The world's own list of places is whole once its raise is: no system that used
## to add its rows at setup (20_realms' shafts, 22_landmarks' places, 34_works'
## depots) grows it, so every answer keyed on the list's length (Works.sites,
## every keeper's den, the treads' marks) holds from the raise on, and RealmWarm
## works the dens and depots out there, beside the raise.
func test_no_system_adds_a_row_to_a_world_got_ready() -> void:
	Sx.use_root("start-warm")
	var w := WorldGen.generate(1, 512)
	RealmWarm.prepare(w)
	var rows := w.landmarks.size()
	var lairs := Sentinels.lairs_worked
	BootWorld.offer(w)
	var g := Sx.game(tree, ["--seed=1", "--size=512"])
	eq(g.world, w, "the game starts on the world raised for it")
	eq(w.landmarks.size(), rows, "no setup added a row to the list RealmWarm made whole")
	eq(Sentinels.lairs_worked - lairs, 0, "and no keeper's den was worked out at setup: RealmWarm did")
	Sx.end(g)
	Sx.finish()


## The story's casting searches the whole world once per slot, and its first ask
## is a system's at setup (20_realms' gates, 49_cast), on the main thread: it is
## cast beside the raise instead, and the first ask takes it.
func test_the_casting_got_ready_beside_the_raise_is_taken() -> void:
	Sx.use_root("start-warm")
	var w := WorldGen.generate(1, 512)
	RealmWarm.prepare(w)
	var fresh := StoryCasting.cast(w, StoryPlan.slots())
	var casts := StoryCasting.casts
	BootWorld.offer(w)
	var g := Sx.game(tree, ["--seed=1", "--size=512"])
	eq(StoryCasting.casts - casts, 0, "no casting was worked out at setup")
	eq(var_to_str(StoryPlan.cast(w)), var_to_str(fresh), "and the one taken is the world's")
	Sx.end(g)
	Sx.finish()
