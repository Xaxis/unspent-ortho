extends SceneTree
## The playtest reviewer's blocking finding 1, measured before and after.
##
## BEFORE: adding salt_flats and scrapwood to the registry moves every seed's
## island, and nothing noticed. Reproduces the reviewer's probe3 table (seed 1,
## 3, 7, 42: six != all) and adds the tile counts behind it.
##
## AFTER: a save written on the six-type registry, read by this build, is
## refused by name.
##
##   godot --headless --path . -s <this>

const SIX: Array[StringName] = [&"coast", &"moss", &"pinewood", &"snowfield", &"bonelands", &"burning"]
const SEEDS: Array[int] = [1, 3, 7, 42]
const SIZE := 256


func _initialize() -> void:
	_run()
	_cost()
	quit()


func _run() -> void:
	print("== the cause: does adding a landscape move the island? (size %d)" % SIZE)
	print("%-6s  %-10s %-10s  %-8s  %s" % ["seed", "six", "all", "verdict", "tiles moved"])
	var moved_land := 0.0
	var moved_high := 0.0
	for s: int in SEEDS:
		BiomeRegistry.mute_to(SIX)
		var a := _island(s)
		BiomeRegistry.mute_to([])
		var b := _island(s)
		var land := 0
		var high := 0
		for i: int in a.land.size():
			if a.land[i] != b.land[i]:
				land += 1
			if a.high[i] != b.high[i]:
				high += 1
		var n := float(a.land.size())
		moved_land += 100.0 * float(land) / n
		moved_high += 100.0 * float(high) / n
		print("%-6d  %-10s %-10s  %-8s  %.1f%% to another landscape, %.1f%% to another height" % [
			s, a.digest, b.digest, "SAME" if a.digest == b.digest else "DIFFERENT",
			100.0 * float(land) / n, 100.0 * float(high) / n])
	print("  mean: %.1f%% of tiles change landscape, %.1f%% change height" % [
		moved_land / float(SEEDS.size()), moved_high / float(SEEDS.size())])

	print("")
	print("== the detection: a save written before the registry moved")
	SaveSlots.root = "user://probe-stamp"
	var dir := ProjectSettings.globalize_path("user://probe-stamp")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := SaveSlots.path(1)

	# Written on the M1 six, exactly as a player before wave A did.
	BiomeRegistry.mute_to(SIX)
	var six_stamp := WorldStamp.current()
	var head := {"clock": "day 2  14:30", "place": "moss", "landscape": "moss", "saved_at": 100.0,
		"seed": 3, "size": 64, "pos": [10.5, 20.25], "minutes": 2310.0, "play_seconds": 4000.0}
	SaveFile.write(path, head, {"world": {"seed": 3, "size": 64, "stamp": six_stamp}})
	print("  written on the six-type registry, stamp %s" % six_stamp)
	print("  it opens on the build that wrote it: %s" % SaveFile.read(path).ok)

	# The two landscapes join. The file is whole; the island is not.
	BiomeRegistry.mute_to([])
	print("  this build's registry stamps %s (%d types)" % [WorldStamp.current(), BiomeRegistry.count()])
	var r := SaveFile.read(path)
	print("")
	print("  BEFORE (version 1, no stamp in the header): the header carried seed and size only,")
	print("          so nothing in the file could be compared and the save opened in silence.")
	print("  AFTER : ok=%s  code=%s" % [r.ok, r.code])
	print("          why: %s" % r.why)
	print("          the header still reads: place=%s  clock=%s  (the game is shown, not blanked)" % [
		str((r.header as Dictionary).get("place")), str((r.header as Dictionary).get("clock"))])
	var o := BootOptions.new()
	print("          options_for -> %s" % SaveSlots.options_for(1, o))
	print("          load_slot after the refusal: %d (nothing booted)" % o.load_slot)
	print("          slot row says: %s / %s" % [SaveSlots.problem(1, r.code), SaveSlots.short_problem(r.code)])

	# And the v1 file every player already has on disk.
	var v1 := {"clock": "day 1  09:00", "place": "coast", "landscape": "coast", "saved_at": 90.0,
		"seed": 3, "size": 64, "pos": [8.0, 8.0], "minutes": 540.0, "play_seconds": 100.0,
		"format": SaveFile.FORMAT, "version": 1}
	var body := JSON.stringify({"world": {"seed": 3, "size": 64}}, "", false, true)
	v1["data_md5"] = body.md5_text()
	v1["thumb_md5"] = "".md5_text()
	v1["head_md5"] = SaveFile.header_md5(v1)
	var p2 := SaveSlots.path(2)
	SaveFile.store(p2, PackedStringArray([JSON.stringify(v1, "", false, true), body]))
	var r2 := SaveFile.read(p2)
	print("")
	print("  a version-1 file (what is on every player's disk today):")
	print("          version read back: %d, migrated stamp: %s" % [
		r2.version, str(SaveFile.migrate_header(v1.duplicate(), 1).get("stamp"))])
	print("          ok=%s  code=%s" % [r2.ok, r2.code])
	print("          SaveFile.VERSION is now %d, OLDEST %d" % [SaveFile.VERSION, SaveFile.OLDEST])


func _island(s: int) -> Dictionary:
	var w := WorldGen.generate(s, SIZE)
	var land := PackedByteArray()
	var high := PackedByteArray()
	land.resize(w.size * w.size)
	high.resize(w.size * w.size)
	for y: int in w.size:
		for x: int in w.size:
			var i := y * w.size + x
			land[i] = w.country[i]
			high[i] = clampi(w.level[i] + 8, 0, 255)
	return {"digest": (land.get_string_from_ascii() if false else _md5(land) + _md5(high)).substr(0, 8),
		"land": land, "high": high}


func _md5(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(b)
	return h.finish().hex_encode()


## What the stamp costs where it is read most: a slot list, four files deep.
func _cost() -> void:
	print("")
	print("== the cost: WorldStamp.current() is spelled out, never held")
	var defs := BiomeRegistry.all()
	WorldStamp.of(defs)
	var n := 100
	var t0 := Time.get_ticks_usec()
	for i in n:
		WorldStamp.of(defs)
	var one := float(Time.get_ticks_usec() - t0) / float(n)
	print("  one stamp (%d types): %.0f us" % [BiomeRegistry.count(), one])
	# Four slots, filled, as the saves app and the title read them.
	SaveSlots.root = "user://probe-stamp"
	var head := {"clock": "day 2  14:30", "place": "moss", "landscape": "moss", "saved_at": 100.0,
		"seed": 3, "size": 64, "pos": [10.5, 20.25], "minutes": 2310.0, "play_seconds": 4000.0}
	for slot: int in SaveSlots.COUNT:
		SaveFile.write(SaveSlots.path(slot), head, {"world": {"seed": 3, "size": 64, "stamp": WorldStamp.current()}})
	var mine := WorldStamp.current()
	var t1 := Time.get_ticks_usec()
	for i in 20:
		SaveSlots.list()
	var now := float(Time.get_ticks_usec() - t1) / 20.0
	var t2 := Time.get_ticks_usec()
	for i in 20:
		for slot: int in SaveSlots.COUNT:
			SaveFile.read_header(SaveSlots.path(slot))
	var each := float(Time.get_ticks_usec() - t2) / 20.0
	var t3 := Time.get_ticks_usec()
	for i in 20:
		for slot: int in SaveSlots.COUNT:
			SaveFile.read_header(SaveSlots.path(slot), mine)
	var files := float(Time.get_ticks_usec() - t3) / 20.0
	print("  SaveSlots.list() as it stands (one stamp for four slots): %.2f ms" % (now / 1000.0))
	print("  a stamp per slot, the way a read alone works it out       : %.2f ms" % (each / 1000.0))
	print("  the files alone (the stamp handed in)                     : %.2f ms" % (files / 1000.0))
