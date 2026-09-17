class_name DevPageBuild
extends DevPage
## One build on the shelf: play it, prove it in a browser, keep it, put it on
## the internet (a preview, or production asked twice), use the configuration it
## was made from, open its folder, or throw a kept one away.

var build: Dictionary = {}


func with(b: Dictionary) -> DevPageBuild:
	build = b
	return self


func heading() -> String:
	return "BUILD"


func rows() -> Array[Dictionary]:
	DevJobs.poll()
	var web := str(build.target) != "mac"
	var threaded := str(build.target) == "web"
	var busy := DevJobs.running()
	var job_why := "Still %s." % str(DevJobs.job.get("label", "")) if busy else ""
	var m: Dictionary = build.manifest
	var config := str(m.get("config", ""))
	return [
		item(&"play", "play it", "in the browser" if web else "the app"),
		_job(item(&"prove", "prove it in a browser", "", {"enabled": web, "why": "A mac app has no browser proof."}), job_why),
		_job(item(&"keep", "keep it", "", {"enabled": not bool(build.kept), "why": "It is kept."}), job_why),
		item(&"folder", "open its folder"),
		item(&"use", "use its configuration", config if config != "" else "none", {"enabled": not m.is_empty(), "why": "It was made before builds were stamped."}),
		header("the internet"),
		_job(item(&"preview", "deploy a preview", "", {"enabled": threaded, "why": "Only the threaded web build is deployed."}), job_why),
		_job(item(&"production", "deploy production", "", {"enabled": threaded, "why": "Only the threaded web build is deployed.", "tone": "warn"}), job_why),
		header(""),
		item(&"throw", "throw it away", "", {"enabled": bool(build.kept), "why": "The working builds are replaced by the next make.", "tone": "warn"}),
	]


static func _job(r: Dictionary, why: String) -> Dictionary:
	if why != "" and UiMenu.enabled(r):
		r["enabled"] = false
		r["why"] = why
	return r


func confirm(row: Dictionary) -> void:
	match row.id:
		&"play":
			if str(build.target) == "mac":
				OS.shell_open(str(build.dir).path_join("UNSPENT.app"))
				report("Opening the app.")
			else:
				var why := DevJobs.serve(str(build.dir))
				report("!" + why if why != "" else "Serving it; the browser opens when it is up.")
		&"prove":
			_run("proving %s" % build.target, DevBuilds.prove_command(build), &"prove")
		&"keep":
			_run("keeping %s" % build.target, DevBuilds.keep_command(build), &"keep")
		&"folder":
			OS.shell_open(str(build.dir))
		&"use":
			var name := str(build.manifest.get("config", ""))
			if not GameConfig.edits.is_empty():
				refuse("Keep or forget the configuration's edits first.")
				return
			var why := GameConfig.use(name)
			if why != "":
				refuse(why)
				return
			DevMode.write_state()
			report("Using %s." % (name if name != "" else "no configuration"))
		&"preview":
			_run("deploying a preview", DevBuilds.deploy_command(build, false), &"deploy")
		&"production":
			var m := DevJobs.machine(true)
			var busy := " The machine is busy: %s." % DevJobs.machine_line(m) if bool(m.busy) else ""
			if not screen.ask("production", "Again: this is what the domain serves to everyone.%s" % busy):
				return
			_run("deploying production", DevBuilds.deploy_command(build, true), &"deploy", true)
		&"throw":
			if screen.ask("throw", "Again: the kept build is deleted."):
				_run("throwing away %s" % build.id, DevBuilds.throw_command(build), &"keep")
				screen.back()


## `asked`: the row has asked its own question already, the machine's load in it.
func _run(label: String, command: String, kind: StringName, asked: bool = false) -> void:
	if command == "":
		refuse("Nothing to run for this build.")
		return
	var m := DevJobs.machine(true)
	if kind != &"keep" and not asked and bool(m.busy) and not screen.ask("busy:" + label, "Again, though the machine is busy: %s." % DevJobs.machine_line(m)):
		return
	var why := DevJobs.start(label, command, kind)
	report("!" + why if why != "" else label.capitalize() + ".")


func step(_delta: float) -> void:
	DevJobs.open_when_served()


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.position.y + 16
	if DevJobs.running() or (not DevJobs.job.is_empty() and screen.menu.selected().get("id", &"") in [&"prove", &"keep", &"preview", &"production"]):
		y = panel_heading(ci, r, y, str(DevJobs.job.label), true)
		panel_log(ci, r, y, DevJobs.job.lines, r.end.y - 12)
		return
	manifest(ci, r, y, build)


## What a build's build.json says, on the panel.
static func manifest(ci: CanvasItem, r: Rect2i, y: int, b: Dictionary) -> void:
	if b.is_empty():
		return
	var m: Dictionary = b.manifest
	y = panel_heading(ci, r, y, DevBuilds.describe(b), bool(b.kept))
	if m.is_empty():
		panel_wrapped(ci, r, y, "Made before builds were stamped: nothing says what it was made from.")
		return
	y = panel_pair(ci, r, y, "config", str(m.get("config", "")) if str(m.get("config", "")) != "" else "none")
	y = panel_pair(ci, r, y, "channel", str(m.get("channel", "")))
	y = panel_pair(ci, r, y, "commit", str(m.get("commit", "")) + (" + edits" if bool(m.get("dirty", false)) else ""))
	y = panel_pair(ci, r, y, "built", str(m.get("built", "")).replace("T", " "))
	y = panel_pair(ci, r, y, "template", str(m.get("template", "")))
	y = panel_pair(ci, r, y, "took", "%s s" % str(m.get("seconds", "")))
	y = panel_pair(ci, r, y, "size", DevBuilds.size_text(b))
	var access := str((m.get("settings", {}) as Dictionary).get("dev.access", "off"))
	y = panel_pair(ci, r, y, "dev mode", access, UiTheme.MACHINE[3] if access != "off" else UiTheme.TEXT)
	var d := DevBuilds.last_deploy(b)
	if not d.is_empty():
		y += 12
		y = panel_heading(ci, r, y, "last deployed")
		y = panel_line(ci, r, y, str(d.get("url", "")))
		y = panel_line(ci, r, y, "production" if bool(d.get("production", false)) else "a preview", UiTheme.WARN if bool(d.get("production", false)) else UiTheme.TEXT_DIM)
	y += 12
	panel_wrapped(ci, r, y, str(b.dir).replace(DevMode.project_path(""), ""), UiTheme.TEXT_DIM)
