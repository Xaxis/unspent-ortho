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
