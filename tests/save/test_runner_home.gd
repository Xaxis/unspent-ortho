extends TestCase
## Two test runners at once never share a file. user:// is one folder per
## PROJECT, so every checkout and worktree on a machine writes the same one, and
## a runner beside another read the other's autosave and settings as its own:
## test_autosave found "an autosave file already" 3 runs of 3 with a second
## runner started beside it. Everything a runner writes lives in a folder named
## by its process (RunnerHome).

const Sx := preload("res://tests/save/save_fixture.gd")


func test_everything_a_runner_writes_is_its_own() -> void:
	var home := RunnerHome.path()
	check(home.begins_with("user://") and home.contains(str(OS.get_process_id())), "a runner's home is named by its process: %s" % home)
	check(DirAccess.dir_exists_absolute(home), "and stands ready to be written into")
	check(SaveSlots.TEST_ROOT.begins_with(home), "its saves: %s" % SaveSlots.TEST_ROOT)
	check(PlayerSettings.TEST_FILE.begins_with(home), "its settings: %s" % PlayerSettings.TEST_FILE)
	check(DevMode.TEST_ROOT.begins_with(home), "dev mode's notes: %s" % DevMode.TEST_ROOT)
	check(Sx.use_root("home").begins_with(home), "and a save test's own folder")
	Sx.finish()


func test_a_home_left_by_a_runner_that_is_gone_is_swept() -> void:
	# A pid no process holds: the runner that made it was killed before it could
	# clear up after itself.
	var gone := RunnerHome.PARENT.path_join("999999999")
	DirAccess.make_dir_recursive_absolute(gone)
	var f := FileAccess.open(gone.path_join("settings.json"), FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	RunnerHome.sweep()
	check(not DirAccess.dir_exists_absolute(gone), "a dead runner's home is taken away")
	check(DirAccess.dir_exists_absolute(RunnerHome.path()), "and a live one's is left")
