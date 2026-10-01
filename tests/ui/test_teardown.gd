extends TestCase
## The bake must not outlive the process. A sketch is rastered on a
## WorkerThreadPool worker, and if one is still inside `_bake` when the main
## thread tears the scripting language down, the two outcomes are a coin toss:
## the worker reads freed memory and takes signal 11 (seen in a tour, with the
## backtrace naming `_poly_of`, a line that only reads an array), or the main
## thread blocks forever on GDScript's own recursive lock, which the worker
## holds (seen here, every time, before `src/main.gd` and `tests/run.gd` waited).
##
## The second half is a SOURCE test on purpose. A behaviour test cannot prove
## this: the drain runs at `_exit_tree` and at the runner's own quit, after the
## last test has reported, so by the time anything could assert on it the process
## is already going. What can be checked is that the two doors still say so.

## Every place a process running this game can end, and what must drain there.
## Every door out of the process, and the one drain it goes through (main.gd
## drain_pool): both call it, so the two exits cannot drift apart again.
const DRAINS := [
	["res://src/main.gd", "_exit_tree"],
	["res://tests/run.gd", "_run"],
]
const DRAIN := ["res://src/main.gd", "drain_pool"]


func _body(source: String, fn: String) -> String:
	var lines := source.split("\n")
	var out := PackedStringArray()
	var inside := false
	for line in lines:
		var l: String = line
		if l.begins_with("func ") or l.begins_with("static func "):
			inside = l.contains("func %s(" % fn)
			continue
		if inside:
			out.append(l)
	return "\n".join(out)


func test_every_door_out_of_the_process_drains_the_bake() -> void:
	for row: Array in DRAINS:
		var path: String = row[0]
		var fn: String = row[1]
		var source := FileAccess.get_file_as_string(path)
		check(source.length() > 0, "read %s" % path)
		var body := _body(source, fn)
		check(body.length() > 0, "%s still has %s()" % [path, fn])
		check(body.contains("drain_pool"), "%s %s() must go through main.gd drain_pool()" % [path, fn])
	var drain_src := FileAccess.get_file_as_string(DRAIN[0])
	for row: Array in [DRAIN]:
		var path: String = row[0]
		var fn: String = row[1]
		var body := _body(drain_src, fn)
		check(body.length() > 0, "%s still has %s()" % [path, fn])
		check(body.contains("realm_worlds.gd") and body.contains("settle"),
			"%s %s() must wait out a realm's raise, or a worker outlives the tree" % [path, fn])
		# By PATH in both, deliberately: naming UiSketch in either file compiles the
		# UI package before the Events autoload exists and takes game.gd,
		# crafting.gd and survival.gd down as load errors. Both forms are accepted
		# here so a later reader who can safely name the class is not blocked.
		check(body.contains("ui_sketch.gd") or body.contains("UiSketch.wait()"),
			"%s %s() must wait out the sketch bake, or a worker outlives the tree" % [path, fn])
		check(body.contains("ui_slate.gd") or body.contains("UiSlate.wait()"),
			"%s %s() must wait out the slate bake too" % [path, fn])
		check(body.contains("sound_bank.gd") and body.contains("drain"),
			"%s %s() must claim the shared sound bank's bakes, or CI's pool never exits" % [path, fn])


func test_a_bake_left_running_is_waited_out_not_abandoned() -> void:
	# The shape the forcing case had: start a creel, do not wait, and hand back.
	# Whatever the drain is, `wait()` must finish it rather than leave it out —
	# a pool task cannot be cancelled, so "abandon it" is not on the table.
	var ids: Array[StringName] = []
	for id: StringName in Items.DEFS:
		ids.append(id)
		if ids.size() >= 12:
			break
	UiSketch._cache.clear()
	UiSketch.warm(ids, 234)
	check(UiSketch.waiting(), "the pool took the bake")
	UiSketch.wait()
	check(not UiSketch.waiting(), "and wait() left nothing running")
	for id in ids:
		check(UiSketch.item_texture(id, 234) != null, "%s finished rather than being dropped" % id)
	UiSketch.wait()


## The island a title raises behind its coast (RealmWorlds, a whole 1840 world on
## the pool) is the longest job a process can be quitting under. drain_pool halts
## it and waits for it: once the drain returns the raise has handed back what it
## grew, and that stopped at the stage the halt reached, short of the roads. Read
## off the raise's own work, not the clock: a 15 s bar read 16.8 s at load 36 for
## a drain that had halted (6.9 s alone), and a whole world is 30 s or more.
func test_the_island_raised_behind_the_title_is_claimed_at_the_drain() -> void:
	RealmWorlds.forget()
	RealmWorlds.settle()
	# What the raise grew, caught as it hands it back (RealmWorlds throws away a
	# world raised for a game that has ended).
	var grown: Array[WorldData] = []
	RealmWorlds.grower = func(s: int, n: int, k: StringName) -> WorldData:
		var w := BootWorld.world(s, n, k)
		grown.append(w)
		return w
	@warning_ignore("return_value_discarded")
	RealmWorlds.begin(12, Tuning.WORLD_SIZE, Realm.SURFACE, true)
	check(RealmWorlds.going(12, Tuning.WORLD_SIZE, Realm.SURFACE), "the island is being raised")
	OS.delay_msec(300)
	var t0 := Time.get_ticks_msec()
	(load(DRAIN[0]) as GDScript).call(DRAIN[1])
	print("  the drain took %d ms" % (Time.get_ticks_msec() - t0))
	RealmWorlds.grower = Callable()
	eq(grown.size(), 1, "the drain waited for the raise to hand back what it grew")
	if grown.size() == 1:
		check(grown[0] != null and grown[0].road.is_empty(),
			"halted at a stage, not waited out whole: it never reached worldgen's end, where the roads are laid")
	check(WorldGen.halted().is_empty(), "and the stop it was asked to make is lifted")
