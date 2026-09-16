class_name DevPageProofs
extends DevPage
## Proofs, on the machine the game is built on: the gate, the tests, the canon
## sheet and every tour, run as a job with the command its own header gives, and
## the frames of the last run to look at (CLAUDE.md: a green test says nothing
## about how the game looks).

const TOURS := "tours"

var _tours: Array[Dictionary] = []


func heading() -> String:
	return "PROOFS"


func rows() -> Array[Dictionary]:
	DevJobs.poll()
	if _tours.is_empty() and DevMode.local():
		_tours = tours()
	var out: Array[Dictionary] = [header("the loop")]
	out.append(_proof(item(&"gate", "the gate", "check.sh")))
	out.append(_proof(item(&"gate_web", "the gate and both web builds", "check.sh --web")))
	out.append(_proof(item(&"tests", "the tests alone", "test.sh")))
	out.append(_proof(item(&"canon", "the canon sheet", "canon.sh")))
	if not DevJobs.job.is_empty():
		out.append(header("the job"))
		out.append(item(&"job", str(DevJobs.job.label), "%ds" % roundi(DevJobs.seconds()) if DevJobs.running() else ("ok" if int(DevJobs.job.code) == 0 else "failed"),
			{"tone": "warn" if not DevJobs.running() and int(DevJobs.job.code) != 0 else ""}))
		out.append(item(&"frames", "its frames", "", {"enabled": not _frames_dir().is_empty(), "why": "This job shoots no frames."}))
		if DevJobs.running():
			out.append(item(&"stop", "stop it", "", {"tone": "warn"}))
	out.append(header("tours"))
	for t: Dictionary in _tours:
		out.append(_proof(item(StringName("tour:" + str(t.name)), str(t.name), "")))
	return out


func _proof(r: Dictionary) -> Dictionary:
	r = local_only(r)
	if DevJobs.running() and UiMenu.enabled(r):
		r["enabled"] = false
		r["why"] = "Still %s." % str(DevJobs.job.label)
	return r


## Every tour, with the command its header says to run it by.
static func tours() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DevMode.project_path(TOURS)
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var files := DirAccess.get_files_at(dir)
	files.sort()
	for f in files:
		if f.ends_with(".tour"):
			out.append({"name": f.get_basename(), "command": tour_command(FileAccess.get_file_as_string(dir.path_join(f)), f)})
	return out


## The command a tour's header gives (continued over `\` lines), or the tour bare.
static func tour_command(text: String, file: String) -> String:
	var lines := text.split("\n")
	for i in lines.size():
		var l := lines[i].trim_prefix("#").strip_edges()
		if not l.contains("tools/tour.sh"):
			continue
		var cmd := l
		var j := i
		while cmd.ends_with("\\") and j + 1 < lines.size():
			j += 1
			cmd = cmd.trim_suffix("\\").strip_edges() + " " + lines[j].trim_prefix("#").strip_edges()
		if cmd.contains(file):
			return cmd.trim_suffix("\\").strip_edges()
	return "tools/tour.sh tours/%s" % file


func confirm(row: Dictionary) -> void:
	var id := String(row.id)
	if id.begins_with("tour:"):
		var name := id.trim_prefix("tour:")
		for t: Dictionary in _tours:
			if t.name == name:
				_run("touring %s" % name, str(t.command), &"tour", name)
		return
	match row.id:
		&"gate":
			_run("the gate", "tools/check.sh", &"gate")
		&"gate_web":
			_run("the gate and the web", "tools/check.sh --web", &"gate")
		&"tests":
			_run("the tests", "tools/test.sh", &"tests")
		&"canon":
			_run("the canon sheet", "tools/canon.sh", &"canon")
		&"frames":
			var dir := _frames_dir()
			if dir != "":
				screen.push_page(DevPageFrames.new().at(dir))
		&"stop":
			if screen.ask("stop", "Again: the job is stopped where it is."):
				DevJobs.stop()
				report("Stopped.")


func _run(label: String, command: String, kind: StringName, tour: String = "") -> void:
	var m := DevJobs.machine(true)
	if bool(m.busy) and not screen.ask("busy:" + label, "Again, though the machine is busy: %s." % DevJobs.machine_line(m)):
		return
	var why := DevJobs.start(label, command, kind)
	if why != "":
		refuse(why)
		return
	if tour != "":
		DevJobs.job["frames"] = DevMode.project_path("shots/tour").path_join(tour)
	report(label.capitalize() + ".")


## Where the last job's frames land: a tour's own folder, the gate's shots/check.
func _frames_dir() -> String:
	if DevJobs.job.is_empty():
		return ""
	if DevJobs.job.has("frames"):
		return str(DevJobs.job.frames)
	match StringName(str(DevJobs.job.kind)):
		&"gate":
			return DevMode.project_path("shots/check")
		&"canon":
			return DevMode.project_path("shots/canon")
	return ""


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.position.y + 8
	var id := String(screen.menu.selected().get("id", ""))
	if not DevJobs.job.is_empty() and (DevJobs.running() or id in ["job", "stop", "frames"]):
		y = panel_heading(ci, r, y, str(DevJobs.job.label), true)
		y = panel_line(ci, r, y, str(DevJobs.job.command), UiTheme.TEXT_DIM)
		panel_log(ci, r, y + 2, DevJobs.job.lines, r.end.y - 6)
		return
	if not DevMode.local():
		panel_wrapped(ci, r, y, "Proofs run on the machine the game is built on, with its tools.")
		return
	if id.begins_with("tour:"):
		var name := id.trim_prefix("tour:")
		y = panel_heading(ci, r, y, name)
		var text := FileAccess.get_file_as_string(DevMode.project_path(TOURS).path_join(name + ".tour"))
		for t: Dictionary in _tours:
			if t.name == name:
				y = panel_wrapped(ci, r, y, str(t.command), UiTheme.TEXT)
		y += 4
		for l in text.split("\n"):
			if not l.begins_with("#") or l.contains("tools/tour.sh") or l.strip_edges().begins_with("#   --") or l.strip_edges().begins_with("#     --"):
				if not l.begins_with("#"):
					break
				continue
			y = panel_line(ci, r, y, l.trim_prefix("#").strip_edges(), UiTheme.TEXT_DIM)
			if y > r.end.y - 14:
				break
		return
	var m := DevJobs.machine()
	y = panel_heading(ci, r, y, "the machine")
	y = panel_line(ci, r, y, DevJobs.machine_line(m), UiTheme.WARN if bool(m.busy) else UiTheme.TEXT)
	y = panel_wrapped(ci, r, y + 2, "A timing failure while the machine is this busy is re-run alone before it is believed.")
	if not DevJobs.history.is_empty():
		y += 6
		y = panel_heading(ci, r, y, "this session")
		for i in range(DevJobs.history.size() - 1, maxi(-1, DevJobs.history.size() - 8), -1):
			var h: Dictionary = DevJobs.history[i]
			y = panel_pair(ci, r, y, str(h.label), "%s  %ds" % ["ok" if int(h.code) == 0 else "failed", roundi(float(h.seconds))], UiTheme.TEXT if int(h.code) == 0 else UiTheme.WARN)
