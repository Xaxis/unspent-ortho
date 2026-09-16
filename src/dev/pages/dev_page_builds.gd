class_name DevPageBuilds
extends DevPage
## Builds, on the machine the game is built on: make one from a configuration
## (its `builds` settings say what for), watch the job, and every build on the
## shelf. Elsewhere the page says what this build is and why builds are not made here.

var _config := ""
var _shelf: Array[Dictionary] = []
var _read_at := -INF


func heading() -> String:
	return "BUILDS"


func rows() -> Array[Dictionary]:
	DevJobs.poll()
	var now := Time.get_ticks_msec() / 1000.0
	if now - _read_at > 2.0:
		_read_at = now
		_shelf = DevBuilds.shelf()
	if _config == "" and GameConfig.active != "" and GameConfig.source != &"stamp":
		_config = GameConfig.active
	var out: Array[Dictionary] = [header("make")]
	out.append(local_only(item(&"config", "from", _config if _config != "" else "no configuration", {"steps": true, "tone": "dev"})))
	var settings := _settings()
	out.append(local_only(item(&"makes", "makes", ConfigChoices.show("builds.targets", settings.targets))))
	out.append(local_only(item(&"template", "template", str(settings.template))))
	var make := local_only(item(&"make", "make it", "", {"tone": "dev"}))
	if DevJobs.running():
		make["enabled"] = false
		make["why"] = "Still %s." % str(DevJobs.job.label)
	out.append(make)
	if not DevJobs.job.is_empty():
		out.append(header("the job"))
		out.append(item(&"job", str(DevJobs.job.label), _job_value()))
		out.append(item(&"stop", "stop it", "", {"enabled": DevJobs.running(), "why": "It is not running.", "tone": "warn"}))
	out.append(header("the shelf"))
	if _shelf.is_empty():
		out.append(item(&"empty", "nothing built yet", "", {"enabled": false, "why": DevMode.why_not_local() if not DevMode.local() else "Make one above."}))
	for b: Dictionary in _shelf:
		out.append(item(StringName("build:" + str(b.id)), DevBuilds.describe(b), DevBuilds.age_text(b, Time.get_unix_time_from_system()),
			{"tone": "" if not bool(b.kept) else "dev"}))
	if not DevJobs.serving.is_empty():
		out.append(header("served"))
		out.append(item(&"unserve", "stop serving", str(DevJobs.serving.url)))
	return out


## The chosen configuration's build settings: {targets, template}; a
## configuration in use is read with its edits.
func _settings() -> Dictionary:
	if _config == "":
		return {"targets": ConfigSchema.default_of("builds.targets"), "template": ConfigSchema.default_of("builds.template")}
	if _config == GameConfig.active and GameConfig.source != &"stamp":
		return {"targets": GameConfig.value("builds.targets"), "template": GameConfig.value("builds.template")}
	var r := GameConfig.resolve(_config)
	var s: Dictionary = r.get("settings", {})
	return {"targets": s.get("builds.targets", ConfigSchema.default_of("builds.targets")), "template": s.get("builds.template", ConfigSchema.default_of("builds.template"))}


func _job_value() -> String:
	if DevJobs.running():
		return "%ds" % roundi(DevJobs.seconds())
	return "done in %ds" % roundi(DevJobs.seconds()) if int(DevJobs.job.code) == 0 else "failed"


func confirm(row: Dictionary) -> void:
	var id := String(row.id)
	if id.begins_with("build:"):
		var b := _build(id.trim_prefix("build:"))
		if not b.is_empty():
			screen.push_page(DevPageBuild.new().with(b))
		return
	match row.id:
		&"config":
			side(row, 1)
		&"makes", &"template":
			refuse("Set on the configuration's own page.")
		&"make":
			_make()
		&"stop":
			if screen.ask("stop", "Again: the job is stopped where it is."):
				DevJobs.stop()
				report("Stopped.")
		&"unserve":
			DevJobs.stop_serving()
			report("Not serving.")


func side(row: Dictionary, dir: int) -> void:
	if row.id != &"config":
		return
	var names := Array(GameConfig.names())
	names.push_front("")
	_config = str(names[posmod(names.find(_config) + dir, names.size())])
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func _make() -> void:
	if _config == GameConfig.active and not GameConfig.edits.is_empty():
		refuse("Keep or forget the configuration's edits first: a build is made from the file.")
		return
	if _config != "":
		var r := GameConfig.resolve(_config)
		if not r.ok:
			refuse(r.why)
			return
		var problems := ConfigChoices.problems(r.settings)
		if not problems.is_empty():
			refuse(problems[0])
			return
	var m := DevJobs.machine()
	if bool(m.busy) and not screen.ask("make", "Again, though the machine is busy: %s." % DevJobs.machine_line(m)):
		return
	var s := _settings()
	var cmd := DevBuilds.make_command(_config, s.targets, str(s.template))
	var why := DevJobs.start("making %s" % (_config if _config != "" else "a build"), cmd, &"make")
	if why != "":
		refuse(why)
		return
	report("Making %s." % ConfigChoices.show("builds.targets", s.targets))


func _build(id: String) -> Dictionary:
	for b: Dictionary in _shelf:
		if str(b.id) == id:
			return b
	return {}


func step(_delta: float) -> void:
	DevJobs.open_when_served()


func keys(row: Dictionary) -> Array:
	if String(row.get("id", "")).begins_with("build:"):
		return [["e", "open"], ["esc", "back"]]
	return super(row)


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var row := screen.menu.selected()
	var y := r.position.y + 8
	var id := String(row.get("id", ""))
	if id.begins_with("build:"):
		DevPageBuild.manifest(ci, r, y, _build(id.trim_prefix("build:")))
		return
	if not DevJobs.job.is_empty():
		y = panel_heading(ci, r, y, str(DevJobs.job.label), true)
		y = panel_line(ci, r, y, _job_value(), UiTheme.TEXT if int(DevJobs.job.code) <= 0 else UiTheme.WARN)
		panel_log(ci, r, y + 2, DevJobs.job.lines, r.end.y - 6)
		return
	y = panel_heading(ci, r, y, "this build", true)
	y = panel_pair(ci, r, y, "build", DevReadout.build_line())
	y = panel_pair(ci, r, y, "runs as", DevMode.host())
	y += 8
	if not DevMode.local():
		panel_wrapped(ci, r, y, "Builds are made, kept and deployed on the machine the game is built on. Notes and configurations copied out of this one are how they get there.")
		return
	var m := DevJobs.machine()
	y = panel_heading(ci, r, y, "the machine")
	y = panel_line(ci, r, y, DevJobs.machine_line(m), UiTheme.WARN if bool(m.busy) else UiTheme.TEXT)
	y = panel_wrapped(ci, r, y + 2, "Another session may be building on it too: a busy machine is asked about twice.")
	var s := _settings()
	y += 6
	y = panel_heading(ci, r, y, "make it runs")
	panel_wrapped(ci, r, y, DevBuilds.make_command(_config, s.targets, str(s.template)).replace(" && ", ", then "), UiTheme.TEXT)
