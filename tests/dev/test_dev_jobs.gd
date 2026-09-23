extends TestCase
## Jobs and the shelf (docs/DESIGN.md): a job's log is tailed a whole line at a time
## and its end is noticed; one job at a time; the commands are the tools' own; a
## tour runs with the command its own header gives.


func _fake_job(lines: PackedStringArray) -> String:
	DirAccess.make_dir_recursive_absolute(DevJobs.folder())
	var path := ProjectSettings.globalize_path(DevJobs.folder().path_join("test-job.log"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	return path


func test_a_job_is_tailed_and_its_end_noticed() -> void:
	var path := _fake_job(PackedStringArray(["export Web -> build/web in 71.2 s", "[32mcoloured[0m"]))
	DevJobs.launcher = func(_command: String, _log: String) -> int: return 4242
	DevJobs.job = {}
	eq(DevJobs.start("making web", "tools/export.sh web", &"make"), "")
	DevJobs.job.log = path
	check(DevJobs.running())
	eq(DevJobs.start("again", "true", &"make"), "Still making web.", "one job at a time")
	DevJobs.poll()
	eq(DevJobs.job.lines, PackedStringArray(["export Web -> build/web in 71.2 s", "coloured"]), "colour codes cleaned off")
	check(DevJobs.running(), "no exit line yet")
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("half a li")
	f.close()
	DevJobs.poll()
	eq((DevJobs.job.lines as PackedStringArray).size(), 2, "half a line waits for the rest")
	f = FileAccess.open(path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("ne\n== exit 0\n")
	f.close()
	DevJobs.poll()
	check(not DevJobs.running(), "the exit line ends it")
	eq(int(DevJobs.job.code), 0)
	eq(DevJobs.summary(), "half a line", "the last line worth showing")
	eq(str(DevJobs.history.back().label), "making web")
	DevJobs.launcher = Callable()
	DevJobs.job = {}
	DirAccess.remove_absolute(path)


func test_a_real_shell_job_runs_in_the_project() -> void:
	if not DevMode.local():
		return
	DevJobs.job = {}
	eq(DevJobs.start("listing", "ls tools/export.sh && echo done", &"test"), "")
	var until := Time.get_ticks_msec() + int(20000 * TestCase.machine_slack())
	while DevJobs.running() and Time.get_ticks_msec() < until:
		OS.delay_msec(50)
		DevJobs.poll()
	check(not DevJobs.running(), "it finished")
	eq(int(DevJobs.job.code), 0)
	check((DevJobs.job.lines as PackedStringArray).has("tools/export.sh"), "run from the project: %s" % str(DevJobs.job.lines))
	DirAccess.remove_absolute(str(DevJobs.job.log))
	DevJobs.job = {}


func test_the_machine_is_read_before_anything_is_started() -> void:
	var m := DevJobs.machine()
	check(int(m.cores) >= 1)
	check(float(m.load) >= 0.0)
	check(m.has("busy"))
	check(DevJobs.machine_line(m).begins_with("load "))


func test_the_commands_are_the_tools_own() -> void:
	eq(DevBuilds.make_command("playtest", ["web", "mac"], "release"), "tools/export.sh web --config=playtest && tools/export.sh mac --config=playtest")
	eq(DevBuilds.make_command("", ["web-nothreads"], "debug"), "tools/export.sh web-nothreads --debug")
	var b := {"id": "web", "target": "web", "dir": "/p/build/web", "kept": false,
		"manifest": {"stamp": 1, "config": "playtest", "commit": "a1b2c3d", "dirty": false, "built_at": 1789560000, "version": "0.2.0", "label": "playtest"}}
	check(DevBuilds.kept_id(b).begins_with("playtest-a1b2c3d-"), DevBuilds.kept_id(b))
	check(DevBuilds.keep_command(b).contains("cp -R \"/p/build/web\" \"build/kept/playtest-a1b2c3d-"), DevBuilds.keep_command(b))
	eq(DevBuilds.prove_command(b), "tools/web.sh --no-export")
	eq(DevBuilds.deploy_command(b, false), "tools/deploy.sh --no-export --dir=\"/p/build/web\"")
	eq(DevBuilds.deploy_command(b, true), "tools/deploy.sh --no-export --dir=\"/p/build/web\" --prod")
	eq(DevBuilds.throw_command(b), "", "a working build is never thrown away from the shelf")
	var mac := {"id": "mac", "target": "mac", "dir": "/p/build/mac", "kept": true, "manifest": {}}
	eq(DevBuilds.deploy_command(mac, false), "", "a mac app is not deployed")
	eq(DevBuilds.prove_command(mac), "")
	eq(DevBuilds.describe(mac), "mac  made before stamps")


func test_a_tour_runs_by_the_command_its_header_gives() -> void:
	var text := "# Hazards.\n#   tools/tour.sh tours/hazards.tour --seed=1 --hour=19 \\\n#     --give=wrap_warm:1 \\\n#     --fit=glide_wing\ncoast calm\n"
	eq(DevPageProofs.tour_command(text, "hazards.tour"), "tools/tour.sh tours/hazards.tour --seed=1 --hour=19 --give=wrap_warm:1 --fit=glide_wing")
	eq(DevPageProofs.tour_command("# Score.\n#   TOUR_TIMEOUT=900 tools/tour.sh tours/score.tour\n", "score.tour"), "TOUR_TIMEOUT=900 tools/tour.sh tours/score.tour")
	eq(DevPageProofs.tour_command("wait 1\n", "bare.tour"), "tools/tour.sh tours/bare.tour", "no header, the tour bare")
	if DevMode.local():
		var tours := DevPageProofs.tours()
		check(not tours.is_empty(), "the tours are listed")
		for t: Dictionary in tours:
			check(str(t.command).contains("tools/tour.sh tours/%s.tour" % t.name), "%s runs itself: %s" % [t.name, t.command])
