extends TestCase
## The bank: sounds baked on demand, and kept on disk between runs under a
## folder named for the recipes, so a second start plays at once and an edited
## recipe is never served stale.

const Fixture := preload("res://tests/audio/audio_fixture.gd")


func _root() -> String:
	return "user://sound_cache_test_%d" % Time.get_ticks_usec()


func _wipe(root: String) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	for d in dir.get_directories():
		var sub := DirAccess.open(root.path_join(d))
		for f in sub.get_files():
			sub.remove(f)
		DirAccess.remove_absolute(root.path_join(d))
	DirAccess.remove_absolute(root)


func test_a_baked_sound_comes_back_from_disk_identical() -> void:
	var root := _root()
	var first := SoundBank.new()
	first.threaded = false
	first.use_disk_cache(root)
	var made := first.bake_now(&"ui_move")
	check(not made.from_disk, "made the first time")
	var second := SoundBank.new()
	second.threaded = false
	second.use_disk_cache(root)
	var loaded := second.bake_now(&"ui_move")
	check(loaded.from_disk, "loaded the second time")
	eq(loaded.stream.data, made.stream.data, "the same PCM")
	near(loaded.gain_db, made.gain_db, 1e-5, "the same gain")
	eq(loaded.stream.loop_mode, made.stream.loop_mode, "the same loop")
	eq(loaded.bus, &"UI", "bus from the sheet")
	_wipe(root)


func test_the_cache_folder_is_the_recipes_fingerprint() -> void:
	var v := SoundBank.recipe_version()
	eq(v, SoundBank.recipe_version(), "stable")
	eq(v.length(), 16, "a short hex name")
	var root := _root()
	var bank := SoundBank.new()
	bank.use_disk_cache(root)
	check(DirAccess.dir_exists_absolute(root.path_join(v)), "folder made")
	# A file from another recipe version, or a torn one, is not trusted.
	var torn := root.path_join(v).path_join("ui_accept.usnd")
	var f := FileAccess.open(torn, FileAccess.WRITE)
	f.store_buffer("USND".to_ascii_buffer())
	f.close()
	check(SoundBank.load_cached(&"ui_accept", torn) == null, "a torn file is ignored")
	_wipe(root)


func test_old_recipe_folders_are_pruned() -> void:
	var root := _root()
	for i in SoundBank.CACHE_KEEP + 2:
		var d := root.path_join("old%02d" % i)
		DirAccess.make_dir_recursive_absolute(d)
		var f := FileAccess.open(d.path_join("x.usnd"), FileAccess.WRITE)
		f.store_8(i)
		f.close()
	var bank := SoundBank.new()
	bank.use_disk_cache(root)
	var dir := DirAccess.open(root)
	check(dir.get_directories().size() <= SoundBank.CACHE_KEEP + 1, "at most %d folders kept, found %d" % [SoundBank.CACHE_KEEP + 1, dir.get_directories().size()])
	check(DirAccess.dir_exists_absolute(root.path_join(SoundBank.recipe_version())), "this build's folder survives")
	_wipe(root)


func test_the_fingerprint_works_in_an_export_and_refuses_when_blind() -> void:
	gt(float(SoundBank.recipe_digests().size()), 5.0, "every recipe script is read")
	eq(SoundBank.version_from(PackedStringArray()), "", "no recipes read: no fingerprint")
	check(SoundBank.version_from(PackedStringArray(["a"])) != SoundBank.version_from(PackedStringArray(["b"])), "a recipe edit is a new folder")
	eq(SoundBank.remap_target('[remap]\n\npath="res://.godot/exported/1/export-abc-synth.gdc"\n'), "res://.godot/exported/1/export-abc-synth.gdc", "a tokenised export's script is found through its remap")
	eq(SoundBank.remap_target("nothing here"), "")
	# A folder the build keeps scripts in as remaps is hashed through them.
	var root := _root()
	DirAccess.make_dir_recursive_absolute(root)
	DirAccess.make_dir_recursive_absolute(root.path_join("exported"))
	var target := root.path_join("exported").path_join("compiled.gdc")
	var f := FileAccess.open(target, FileAccess.WRITE)
	f.store_string("tokens v1")
	f.close()
	f = FileAccess.open(root.path_join("recipe.gd.remap"), FileAccess.WRITE)
	f.store_string('[remap]\npath="%s"\n' % target)
	f.close()
	var one := SoundBank.recipe_digests(root)
	eq(one.size(), 1, "the remap's target is read")
	f = FileAccess.open(target, FileAccess.WRITE)
	f.store_string("tokens v2")
	f.close()
	check(SoundBank.recipe_digests(root) != one, "a changed compiled recipe changes the digest")
	DirAccess.remove_absolute(target)
	DirAccess.remove_absolute(root.path_join("exported"))
	DirAccess.remove_absolute(root.path_join("recipe.gd.remap"))
	DirAccess.remove_absolute(root)


func test_without_threads_only_quick_sounds_bake_and_a_frame_bakes_one() -> void:
	var bank := SoundBank.new()
	bank.threaded = false
	bank.request(&"bed_moss")
	bank.request(&"machine_hauler")
	eq(bank.pending(), 0, "beds and machines are not baked on the main thread")
	bank.request(&"ui_move")
	bank.request(&"ui_back")
	eq(bank.pending(), 2, "one-shots are")
	bank._pumped_frame = -1
	bank.pump()
	eq(bank.pending(), 1, "one a frame")
	check(bank.is_ready(&"ui_move"), "the first one is ready")
	bank.flush()
	check(bank.is_ready(&"ui_back"), "flush finishes what may bake")
	check(not bank.is_ready(&"bed_moss"), "a bed stays silent without a worker")
