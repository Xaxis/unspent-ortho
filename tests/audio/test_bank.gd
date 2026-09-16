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


func test_without_threads_a_blow_is_never_held_behind_the_score() -> void:
	var bank := SoundBank.new()
	bank.threaded = false
	var pad := ScoreStems.key_for(&"coast", &"pad", 0)
	var pulse := ScoreStems.key_for(&"coast", &"pulse", 1)
	bank.request(pad, true)
	bank.request(&"ui_move")
	bank.request(pulse, true)
	eq(bank.queued(), [&"ui_move", pulse, pad] as Array[StringName], "every score stem, urgent or not, waits behind the world's sounds")
	bank._pumped_frame = -1
	bank.pump()
	check(bank.is_ready(&"ui_move"), "the one-shot first")
	for i in 3:
		bank._pumped_frame = -1
		bank.pump()
	check(bank._slow != null, "then a real stem is building")
	var hit := SoundBank.key_for(&"hit_flesh", 0)
	bank.request(hit, true)
	var frames := 0
	while not bank.is_ready(hit) and frames < 100:
		bank._pumped_frame = -1
		bank.pump()
		frames += 1
	check(bank._slow != null, "the stem is still building")
	lt(float(frames), 2.5, "a blow asked for mid-build is ready on the next frame (%d)" % frames)
	# The score gives way to a burst of the world's sounds and picks up after it.
	for n: StringName in [&"swing", &"whiff", &"dodge"]:
		bank.request(SoundBank.key_for(n, 0), true)
	for i in 3:
		bank._pumped_frame = -1
		bank.pump()
	check([&"swing", &"whiff", &"dodge"].all(func(n: StringName) -> bool: return bank.is_ready(SoundBank.key_for(n, 0))), "a burst of blows, one a frame")
	var cursor := bank._slow._cursor
	for i in 2:
		bank._pumped_frame = -1
		bank.pump()
	gt(float(bank._slow._cursor), float(cursor), "then the stem builds on")
	bank.cancel()


class HeldStem:
	extends ScoreRender
	var gate: Semaphore

	func run() -> void:
		gate.wait()
		super.run()


static func _held(key: StringName, _bars: int, gate: Semaphore) -> ScoreRender:
	var j := HeldStem.new(key, 16000, true, true, 1600)
	j.gate = gate
	j.hold(ScoreVoices.Sine, {"freqs": [440.0], "amps": [0.2]})
	return j


func test_with_threads_a_score_job_never_takes_the_last_free_worker() -> void:
	var bank := SoundBank.new()
	bank.threaded = true
	var gate := Semaphore.new()
	# Not a lambda: the job is made on a worker thread.
	bank.score_job = _held.bind(gate)
	for land: StringName in [&"coast", &"moss", &"pinewood", &"snowfield"]:
		bank.request(ScoreStems.key_for(land, &"pad", 0), true)
	bank._pumped_frame = -1
	bank.pump()
	var idle_score := bank._jobs.size()
	# A machine closes in while every score stem is still held on its worker.
	bank.request(&"alert_runner")
	bank.request(ScoreStems.key_for(&"burning", &"pad", 0), true)
	bank._pumped_frame = -1
	bank.pump()
	var started_alert := bank._jobs.has(&"alert_runner")
	var running := bank._jobs.size()
	var order := bank.queued()
	# Let everything go before judging, so a failure never leaves a worker waiting.
	for i in 8:
		gate.post()
	bank.flush()
	eq(idle_score, SoundBank.SCORE_TASKS + 1, "with nothing else baking the score may use two workers")
	check(started_alert, "a machine's warning starts at once on the worker the score left free")
	eq(running, SoundBank.SCORE_TASKS + 2, "and no second score stem took it first")
	eq(order[0], ScoreStems.key_for(&"burning", &"pad", 0), "an urgent score stem jumps only the other score stems")
	check(bank.is_ready(&"alert_runner") and bank.is_ready(ScoreStems.key_for(&"burning", &"pad", 0)), "all of it is baked in the end")


## Without threads a finished stem is not also written and turned into a
## stream in the frame that finished it: each is a frame of its own.
func test_without_threads_a_finished_stem_is_saved_and_streamed_on_later_frames() -> void:
	var root := _root()
	var bank := SoundBank.new()
	bank.threaded = false
	bank.score_job = func(k: StringName, _bars: int) -> ScoreRender: return _held_free(k)
	bank.use_disk_cache(root)
	var key := ScoreStems.key_for(&"coast", &"grid", 0)
	bank.request(key)
	var path := bank._cache_path(key)
	var finished_at := -1
	var saved_at := -1
	var ready_at := -1
	for frame in 5000:
		bank._pumped_frame = -1
		bank.pump()
		if finished_at < 0 and bank._slow_baked != null:
			finished_at = frame
			check(not FileAccess.file_exists(path), "not written in the frame that finished it")
		if saved_at < 0 and FileAccess.file_exists(path):
			saved_at = frame
			check(not bank.is_ready(key), "not a stream in the frame that wrote it")
		if bank.is_ready(key):
			ready_at = frame
			break
	check(finished_at >= 0 and saved_at > finished_at and ready_at > saved_at, "finished %d, written %d, a stream %d" % [finished_at, saved_at, ready_at])
	var loaded := SoundBank.load_cached(key, path)
	check(loaded != null and loaded.pcm == bank.get_baked(key).stream.data, "what was written is what plays")
	_wipe(root)


static func _held_free(key: StringName) -> ScoreRender:
	var j := ScoreRender.new(key, 16000, true, true, 3200)
	j.highpass = 150.0
	j.hold(ScoreVoices.Sine, {"freqs": [660.0], "amps": [0.2]})
	return j
