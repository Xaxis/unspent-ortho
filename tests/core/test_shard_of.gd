extends TestCase
## THE GATE'S SHARDS BY MEASURED TIME (tests/run.gd `shard_of`, tests/shard_times.txt):
## longest first onto the lightest shard, a file not in the table at its median,
## every file in exactly one shard, and the same table always gives the same
## shards. By index alone the shards took 14 to 75 minutes on 1430cd50.

const Run := preload("res://tests/run.gd")


func test_longest_first_onto_the_lightest_shard() -> void:
	var paths: PackedStringArray = ["res://tests/a.gd", "res://tests/b.gd", "res://tests/c.gd", "res://tests/d.gd", "res://tests/e.gd"]
	var times := {"res://tests/a.gd": 60.0, "res://tests/b.gd": 50.0, "res://tests/c.gd": 40.0, "res://tests/d.gd": 30.0, "res://tests/e.gd": 20.0}
	var at: Dictionary = Run.shard_of(paths, 2, times)
	eq(at.size(), paths.size(), "every file has a shard")
	var loads := [0.0, 0.0]
	for p: String in paths:
		loads[int(at[p])] += float(times[p])
	# 60 to 0; 50 to 1; 40 to 1 (50 the lighter); 30 to 0 (60); 20 to 0 on the tie.
	eq(loads, [110.0, 90.0], "longest first, each onto the lighter: within the last file of even")
	eq(at, Run.shard_of(paths, 2, times), "the same table, the same shards")


func test_a_file_not_timed_weighs_the_median() -> void:
	var paths: PackedStringArray = ["res://tests/big.gd", "res://tests/x.gd", "res://tests/y.gd", "res://tests/new.gd"]
	var times := {"res://tests/big.gd": 90.0, "res://tests/x.gd": 10.0, "res://tests/y.gd": 30.0}
	var at: Dictionary = Run.shard_of(paths, 2, times)
	eq(int(at["res://tests/big.gd"]), 0, "the longest goes first, to shard 0")
	for p: String in ["res://tests/x.gd", "res://tests/y.gd", "res://tests/new.gd"]:
		eq(int(at[p]), 1, "%s joins the lighter shard, the new file as a 30 (the median)" % p)


func test_the_table_is_read_by_path_from_the_project_root() -> void:
	var file := "user://shard_times_test.txt"
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string("# a comment\ntests/core/test_one.gd 12\n\ntests/two/test_two.gd 3.5\nnot a row\n")
	f.close()
	var t: Dictionary = Run.read_times(file)
	eq(t, {"res://tests/core/test_one.gd": 12.0, "res://tests/two/test_two.gd": 3.5}, "rows by res:// path; comments, blanks and bad rows skipped")
	eq(Run.read_times("user://no_such_table.txt"), {}, "no table, nothing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
