class_name DevJobs
## Work dev mode hands to the machine the game is built on: a build, a proof, a
## deploy, the gate, a tour. One job at a time, run by the shell in the project
## with its output in a log that the slate tails; a job outlives the game that
## started it. A served web build is a process of its own beside the job.
##
##   DevJobs.start(label, command, kind)  "" or why not; `command` is run in the project
##   DevJobs.poll()                       read the log, notice the end
##   DevJobs.job                          {label, kind, command, pid, log, started, ended, code, lines}
##   DevJobs.machine()                    {load, cores, runs, busy}: before anything is started
##   DevJobs.serve(dir) / stop_serving()  a web build on http://127.0.0.1:SERVE_PORT/
##
## Another session may be running tours and builds on this machine (CLAUDE.md,
## "Another session may be running right now"), so a page reads machine() first
## and asks again on a busy machine rather than piling on.

const SERVE_PORT := 8060
## Lines of a log kept in memory for the slate.
const KEEP_LINES := 400
## A machine is busy past this much load per core, or with this many other runs of Godot going.
const BUSY_LOAD := 1.25
const BUSY_RUNS := 4
## The shell a job runs in may not have the owner's PATH (the game started from Finder).
const PATH_PREFIX := "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

static var job: Dictionary = {}
## Jobs this session, newest last: {label, kind, code, seconds, ended}.
static var history: Array[Dictionary] = []
static var serving: Dictionary = {}
## For tests: run commands through this instead of the shell (-> pid, or -1).
static var launcher: Callable
static var _read_at := 0


## Where job logs are written on this device.
static func folder() -> String:
	return DevMode.user_root().path_join("jobs")


static func running() -> bool:
	return not job.is_empty() and int(job.get("ended", 0)) == 0


## Start `command` (a line of shell, run in the project). "" or why not.
static func start(label: String, command: String, kind: StringName = &"job") -> String:
	poll()
	if running():
		return "Still %s." % str(job.label)
	var why := DevMode.why_not_local()
	if why != "" and not launcher.is_valid():
		return why
	DirAccess.make_dir_recursive_absolute(folder())
	var stamp := Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "-")
	var log_path := ProjectSettings.globalize_path(folder().path_join("%s-%s.log" % [stamp, String(kind)]))
	var pid := _launch(command, log_path)
	if pid <= 0:
		return "It would not start."
	job = {"label": label, "kind": kind, "command": command, "pid": pid, "log": log_path,
		"started": Time.get_ticks_msec(), "ended": 0, "code": -1, "lines": PackedStringArray()}
	_read_at = 0
	return ""


static func _launch(command: String, log_path: String) -> int:
	if launcher.is_valid():
		return int(launcher.call(command, log_path))
	var line := "export PATH=\"%s:$PATH\"; cd \"%s\" && { %s\n} > \"%s\" 2>&1; echo \"== exit $?\" >> \"%s\"" % [
		PATH_PREFIX, DevMode.project_path(""), command, log_path, log_path]
	return OS.create_process("/bin/sh", PackedStringArray(["-c", line]))


## Read what the job has written since the last read, and notice when it ends.
static func poll() -> void:
	if job.is_empty():
		return
	# Whether it was alive is taken before the log is read: a shell that writes its
	# exit line and goes between the two is then read with its exit line in.
	var alive := int(job.ended) != 0 or launcher.is_valid() or OS.is_process_running(int(job.pid))
	var lines: PackedStringArray = job.lines
	var f := FileAccess.open(str(job.log), FileAccess.READ)
	if f != null:
		if f.get_length() > _read_at:
			f.seek(_read_at)
			var text := f.get_buffer(f.get_length() - _read_at).get_string_from_utf8()
			# Only whole lines; the rest is read next time.
			var cut := text.rfind("\n")
			if cut >= 0:
				_read_at += text.substr(0, cut + 1).to_utf8_buffer().size()
				for l in text.substr(0, cut).split("\n"):
					lines.append(_plain(l))
		f.close()
	while lines.size() > KEEP_LINES:
		lines.remove_at(0)
	job.lines = lines
	if int(job.ended) != 0:
		return
	for i in range(lines.size() - 1, maxi(-1, lines.size() - 4), -1):
		if lines[i].begins_with("== exit "):
			_end(lines[i].trim_prefix("== exit ").to_int())
			return
	if not alive:
		# The shell went without saying how: it was killed.
		_end(int(job.code) if int(job.code) >= 0 else 143)


static func _end(code: int) -> void:
	job.code = code
	job.ended = Time.get_ticks_msec()
	history.append({"label": job.label, "kind": job.kind, "code": code, "seconds": seconds(), "ended": Time.get_unix_time_from_system()})


## Stop the job and everything it started.
static func stop() -> void:
	if not running():
		return
	if not launcher.is_valid():
		_kill_tree(int(job.pid))
	var lines: PackedStringArray = job.lines
	lines.append("== stopped")
	job.lines = lines
	_end(143)


## The whole tree is collected BEFORE anything is signalled, because a child whose
## parent dies is handed to launchd and `pgrep -P` stops finding it. TERM first, so
## a run that can still hear it closes its log; then KILL, because a hung engine does
## not hear TERM — twenty-four exit-test runs were found idling for a day, parent
## pid 1, having ignored exactly that. The KILL runs in a subshell with its output
## sent to /dev/null: OS.execute waits for the pipe to close, not for the shell to
## exit, so a subshell still holding it would block the page for the whole second.
static func _kill_tree(pid: int) -> void:
	OS.execute("/bin/sh", PackedStringArray(["-c", "t() { echo $1; for c in $(pgrep -P $1); do t $c; done; }; p=$(t %d); kill -TERM $p 2>/dev/null; (sleep 1; kill -KILL $p) >/dev/null 2>&1 & true" % pid]))


## Real seconds the job has run (or ran).
static func seconds() -> float:
	if job.is_empty():
		return 0.0
	var end := int(job.ended) if int(job.ended) != 0 else Time.get_ticks_msec()
	return (end - int(job.started)) / 1000.0


## The last line worth showing: the tools print their own summaries last.
static func summary() -> String:
	if job.is_empty():
		return ""
	var lines: PackedStringArray = job.lines
	for i in range(lines.size() - 1, -1, -1):
		var l := lines[i].strip_edges()
		if l != "" and not l.begins_with("== exit"):
			return l
	return ""


## Lines a colour code or a carriage return would garble on the glass, cleaned.
static func _plain(l: String) -> String:
	var out := RegEx.create_from_string("\\[[0-9;]*[A-Za-z]").sub(l, "", true)
	var cr := out.rfind("\r")
	return out.substr(cr + 1) if cr >= 0 else out


# --- the machine -------------------------------------------------------------------

static var _machine: Dictionary = {}
static var _machine_at := -INF
## Seconds a reading of the machine stands for a panel (reading it starts two processes).
const MACHINE_EVERY := 2.0


## The machine's load and the runs of Godot already going (this one not counted).
## A panel may take a reading up to MACHINE_EVERY old; anything about to start a
## job asks `fresh`.
static func machine(fresh: bool = false) -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	if not fresh and not _machine.is_empty() and now - _machine_at < MACHINE_EVERY:
		return _machine
	_machine = _read_machine()
	_machine_at = now
	return _machine


static func _read_machine() -> Dictionary:
	var cores := maxi(1, OS.get_processor_count())
	var load := 0.0
	var runs := 0
	if not DevMode.web():
		var out := []
		if OS.execute("/bin/sh", PackedStringArray(["-c", "sysctl -n vm.loadavg 2>/dev/null || cat /proc/loadavg"]), out) == 0 and not out.is_empty():
			var nums := RegEx.create_from_string("[0-9]+\\.[0-9]+").search_all(str(out[0]))
			if not nums.is_empty():
				load = nums[0].get_string().to_float()
		out.clear()
		if OS.execute("/bin/sh", PackedStringArray(["-c", "pgrep -i -x godot | wc -l"]), out) == 0 and not out.is_empty():
			runs = maxi(0, str(out[0]).strip_edges().to_int() - 1)
	return {"load": load, "cores": cores, "runs": runs, "busy": load / cores > BUSY_LOAD or runs >= BUSY_RUNS}


static func machine_line(m: Dictionary) -> String:
	var runs := int(m.runs)
	return "load %s on %d cores, %d other Godot run%s" % [str(snappedf(float(m.load), 0.1)), int(m.cores), runs, "" if runs == 1 else "s"]


# --- a web build served for play ---------------------------------------------------------

static func serve(dir: String) -> String:
	stop_serving()
	var why := DevMode.why_not_local()
	if why != "":
		return why
	DirAccess.make_dir_recursive_absolute(folder())
	var log_path := ProjectSettings.globalize_path(folder().path_join("serve.log"))
	var line := "export PATH=\"%s:$PATH\"; cd \"%s\" && exec node tools/web/web.mjs --dir=\"%s\" --serve=%d > \"%s\" 2>&1" % [
		PATH_PREFIX, DevMode.project_path(""), dir, SERVE_PORT, log_path]
	var pid := OS.create_process("/bin/sh", PackedStringArray(["-c", line]))
	if pid <= 0:
		return "It would not serve."
	serving = {"dir": dir, "pid": pid, "url": "", "log": log_path, "opened": false}
	return ""


## Open the browser once the server says where it is. True when it has.
static func open_when_served() -> bool:
	if serving.is_empty() or bool(serving.opened):
		return false
	var m := RegEx.create_from_string("web serving (http://\\S+)").search(FileAccess.get_file_as_string(str(serving.log)))
	if m == null or not OS.is_process_running(int(serving.pid)):
		return false
	serving.url = m.get_string(1)
	serving.opened = true
	OS.shell_open(str(serving.url))
	return true


## "" while the server is up or starting; otherwise what its last line said.
static func serve_problem() -> String:
	if serving.is_empty() or OS.is_process_running(int(serving.pid)):
		return ""
	var lines := FileAccess.get_file_as_string(str(serving.log)).strip_edges().split("\n")
	return "The server stopped: %s" % (lines[lines.size() - 1] if not lines.is_empty() else "it said nothing")


static func stop_serving() -> void:
	if serving.is_empty():
		return
	if OS.is_process_running(int(serving.pid)):
		_kill_tree(int(serving.pid))
	serving = {}
