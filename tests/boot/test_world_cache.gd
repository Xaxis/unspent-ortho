extends TestCase
## A world loaded from WorldCache is the world generation makes, field for field
## (tests/boot/world_same.gd says how strictly), and the cache keys, keeps,
## loads, refuses and forgets as its header says. Every test here writes to its
## own folder under the runner's home, never to the machine's shared cache.

const WorldSame := preload("res://tests/boot/world_same.gd")


## Muting the registry is global state: put back however the test leaves
## (tests/save/test_world_stamp.gd's guard).
class Muted extends RefCounted:
	func _init(ids: Array[StringName]) -> void:
		BiomeRegistry.mute_to(ids)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			BiomeRegistry.mute_to([])


func _init() -> void:
	WorldCache.root = RunnerHome.path().path_join("world-cache")
	_wipe()


func teardown() -> void:
	_wipe()
	WorldCache.root = ""
	WorldCache.enabled = true


func _wipe() -> void:
	for f in _kept():
		DirAccess.remove_absolute(WorldCache.root.path_join(f))


func _kept() -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(WorldCache.root):
		return PackedStringArray()
	return DirAccess.get_files_at(WorldCache.root)


## THE WORLD EVERY TOUR BOOTS, grown here (never taken from a cache), kept on disk
## and read back: no field of it moves, and what generation leaves held for the
## world outside it (Landmarks' sites in its meta; the works, the threshold site,
## the keepers' lairs and the story's casting, held per world object and worked
## out again for a loaded one) reads the same.
func test_a_kept_world_is_the_world_grown() -> void:
	var grown := WorldGen.generate(1)
	var key := WorldCache.key_for(1, grown.size, grown.realm)
	check(key != "", "the cache is on under the runner")
	var path := WorldCache.root.path_join(WorldCache.file_name(1, grown.size, grown.realm, key))
	eq(WorldCache.write(path, key, grown), OK, "the world is written")
	var kept := WorldCache.read(path, key)
	check(kept != null and kept != grown, "and read back as a world of its own")
	if kept == null:
		return
	var d := WorldSame.differences(grown, kept)
	check(d.is_empty(), "the kept world is the grown one:\n  %s" % "\n  ".join(d))
	check(grown.has_meta(Landmarks.HELD), "generation held the landmarks' sites on the world (and the kept one carries them)")
	d = WorldSame.values(BlackSite.site(grown), BlackSite.site(kept), "the threshold site")
	d.append_array(WorldSame.values(Works.sites(grown), Works.sites(kept), "the works"))
	d.append_array(WorldSame.values(Landmarks.sites(grown), Landmarks.sites(kept), "the landmarks"))
	d.append_array(WorldSame.values(_lairs(grown), _lairs(kept), "the keepers' lairs"))
	d.append_array(WorldSame.values(StoryCasting.cast(grown, StoryPlan.slots()), StoryCasting.cast(kept, StoryPlan.slots()), "the story's casting"))
	check(d.is_empty(), "what is worked out from a world reads the same off the kept one:\n  %s" % "\n  ".join(d))


## Where each keeper stands: generation asks it part way (GenTreads), and a
## kept world works it out again on the finished one.
func _lairs(w: WorldData) -> Array:
	var out := []
	for s: SentinelState in Sentinels.states(w):
		out.append([s.region, s.design, s.land, s.lair])
	return out


## EVERY FIELD IS KEPT. The world is grown, played on (a take, a lamp out, a
## prop set down, a ladder, a span overhead, its sections asked for) and given
## the rest by hand, until no field of WorldData is at its default, so a field the cache dropped would read
## back at its default and differ. A new field generation leaves at its default
## fails the first check until this test gives it a value.
func test_no_field_of_a_world_is_left_behind() -> void:
	var w := WorldGen.generate(1, 192)
	var some := w.prop_at(0)
	w.depleted[some.id] = 600.0
	w.unlit[w.prop_at(1).id] = true
	w.add_prop(WorldProp.new(w.next_id(), PropKind.BENCH, w.spawn, 0.5, 1.0))
	# A grown world holds its props as rows (`packed`); one built by hand holds
	# objects, and the cache keeps either.
	w.props.append(WorldProp.new(w.next_id(), PropKind.BENCH, w.spawn + Vector2.ONE, 0.25, 1.0))
	w.add_ladder(Vector2i(3, 4), Vector2i(3, 5))
	w.set_overhead(10, 12, 3, 6, 1)
	w.spawn_facing = 0.75
	w.realm = &"underground"
	@warning_ignore("return_value_discarded")
	WorldSections.rows_in(w, WorldSections.of(w.spawn))
	w.set_meta(&"probe", [Vector2i(1, 2), &"name", 0.1])
	var blank := WorldData.new(0, 1)
	var idle := PackedStringArray()
	for f in WorldSame.fields(w):
		if WorldSame.values(blank.get(f), w.get(f)).is_empty():
			idle.append(f)
	check(idle.is_empty(), "every field holds something a dropped field would lose: give these a value here: %s" % str(idle))
	check(not w.section_spans.is_empty(), "the sections were asked for, spans and all")
	var kept := WorldCache.decode(WorldCache.encode(w))
	check(kept != null, "the world decodes")
	if kept != null:
		var d := WorldSame.differences(w, kept)
		check(d.is_empty(), "nothing is left behind:\n  %s" % "\n  ".join(d))


## The key names the seed, the size, the realm, the registry and the source:
## any one moved is another world. Off is off.
func test_the_key_is_the_world_and_the_code() -> void:
	var k := WorldCache.key_for(5, 96, &"surface")
	check(k != "", "on")
	for other: String in [WorldCache.key_for(6, 96, &"surface"), WorldCache.key_for(5, 128, &"surface"),
			WorldCache.key_for(5, 96, &"underground")]:
		check(other != "" and other != k, "seed, size and realm each move the key")
	check(k.contains("src " + WorldCache.source_hash()) and WorldCache.source_hash().length() == 32,
		"the source's own hash is in it, not WorldStamp.GEN alone")
	var two: Array[StringName] = [&"coast", &"moss"]
	var guard := Muted.new(two)
	var muted := WorldCache.key_for(5, 96, &"surface")
	guard = null
	check(muted != k, "a registry narrowed in place is another world")
	eq(WorldCache.key_for(5, 96, &"surface"), k, "and the whole registry back is this one")
	OS.set_environment("UNSPENT_WORLD_CACHE", "off")
	eq(WorldCache.key_for(5, 96, &"surface"), "", "UNSPENT_WORLD_CACHE=off turns it off")
	OS.unset_environment("UNSPENT_WORLD_CACHE")
	WorldCache.enabled = false
	eq(WorldCache.key_for(5, 96, &"surface"), "", "and so does `enabled` for a test about a raise in flight")
	WorldCache.enabled = true


## Asked twice, a world is grown once and loaded once; a damaged entry, or one
## under another key, is grown again rather than read.
func test_a_world_is_grown_once_then_loaded() -> void:
	var a := WorldCache.world(5, 96)
	eq(WorldCache.last, &"grown", "first asked, it is grown")
	var b := WorldCache.world(5, 96)
	eq(WorldCache.last, &"loaded", "then loaded")
	check(WorldSame.differences(a, b).is_empty(), "the same world")
	var key := WorldCache.key_for(5, 96, &"surface")
	var path := WorldCache.root.path_join(WorldCache.file_name(5, 96, &"surface", key))
	check(WorldCache.read(path, key + "x") == null, "an entry is read only under its own key")
	var bytes := FileAccess.get_file_as_bytes(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes.slice(0, bytes.size() - 1000))
	f.close()
	check(WorldCache.read(path, key) == null, "a cut-off entry is refused")
	var c := WorldCache.world(5, 96)
	eq(WorldCache.last, &"grown", "and grown again")
	check(WorldSame.differences(a, c).is_empty(), "the same world")
	check(WorldCache.read(path, key) != null, "and kept again, whole")


## A raise halted part way hands back an unfinished world; it is never kept.
func test_a_halted_world_is_not_kept() -> void:
	WorldGen.halt(5, 96, &"surface")
	var w := WorldCache.world(5, 96)
	WorldGen.unhalt(5, 96, &"surface")
	check(not w.packed, "the halted world is unfinished")
	eq(_kept().size(), 0, "and nothing was kept")


## Past the cap the least recently used go; a read counts as a use.
func test_the_least_recently_used_go_past_the_cap() -> void:
	var paths: Array[String] = []
	for s: int in [5, 6, 7]:
		@warning_ignore("return_value_discarded")
		WorldCache.world(s, 64)
		var key := WorldCache.key_for(s, 64, &"surface")
		paths.append(WorldCache.root.path_join(WorldCache.file_name(s, 64, &"surface", key)))
		# mtimes are whole seconds
		OS.delay_msec(1100)
	@warning_ignore("return_value_discarded")
	WorldCache.world(5, 64)
	eq(WorldCache.last, &"loaded", "the oldest is read")
	var sizes: Array[int] = []
	for p: String in paths:
		sizes.append(FileAccess.get_size(p))
	# Room for all but half of the middle one: one has to go, and only one.
	WorldCache.evict(WorldCache.root, sizes[0] + sizes[1] / 2 + sizes[2])
	check(FileAccess.file_exists(paths[0]), "the one just read stays")
	check(not FileAccess.file_exists(paths[1]), "the least recently used goes")
	check(FileAccess.file_exists(paths[2]), "the newest stays")
