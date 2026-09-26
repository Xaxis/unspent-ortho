class_name RunnerHome
## The user:// folder one test runner writes everything into: its settings file,
## its saves, dev mode's notes (PlayerSettings.TEST_FILE, SaveSlots.TEST_ROOT,
## DevMode.TEST_ROOT all sit under it).
##
## user:// is one folder per PROJECT, so every checkout and worktree on a machine
## shares it, and two runners at once wrote each other's files: a second runner
## beside the first found an autosave it had not written (test_autosave, 3 runs
## of 3). One home per process, named by its pid. tests/run.gd removes its own
## when it ends and sweeps any left by a runner no longer running when it starts.
##
##   RunnerHome.path()     user://test-runs/<pid>; only a name, nothing is made,
##                         since a game played reads the same constants
##   RunnerHome.open()     sweep, then make this process's (the runner, first)
##   RunnerHome.sweep()    remove every home whose process is gone
##   RunnerHome.remove()   remove this process's own

const PARENT := "user://test-runs"


static func path() -> String:
	return PARENT.path_join(str(OS.get_process_id()))


static func open() -> void:
	sweep()
	DirAccess.make_dir_recursive_absolute(path())


static func sweep() -> void:
	for name: String in DirAccess.get_directories_at(PARENT):
		if name.is_valid_int() and not _alive(name.to_int()):
			_remove_tree(PARENT.path_join(name))


## Asked of the system: OS.is_process_running answers only for this process's
## own children, and said this runner itself was gone.
static func _alive(pid: int) -> bool:
	if pid == OS.get_process_id():
		return true
	return OS.execute("kill", ["-0", str(pid)]) == 0


static func remove() -> void:
	_remove_tree(path())


static func _remove_tree(dir: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
