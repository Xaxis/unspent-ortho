class_name DevBuilds
## The shelf: the builds on the machine the game is built on, and the commands
## that make, keep, prove, play and deploy them (docs/DESIGN.md). The commands are
## the tools' own; this only says which to run on what.
##
##   build/web, build/web-nothreads, build/mac   the working builds tools/web.sh and deploy use
##   build/kept/<id>/<target>                    builds set aside, each with its build.json
##
##   DevBuilds.shelf()                  [{id, target, dir, kept, manifest}] newest first
##   DevBuilds.make_command(name)       the export of every target a configuration names
##   DevBuilds.keep_command(b) / prove_command(b) / deploy_command(b, production) / throw_command(b)

const TARGETS := {"web": "build/web", "web-nothreads": "build/web-nothreads", "mac": "build/mac"}
const KEPT := "build/kept"


static func shelf() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DevMode.local():
		return out
	for t: String in TARGETS:
		var b := _entry(DevMode.project_path(TARGETS[t]), t, false)
		if not b.is_empty():
			out.append(b)
	var kept := DevMode.project_path(KEPT)
	if DirAccess.dir_exists_absolute(kept):
		for id in DirAccess.get_directories_at(kept):
			for t: String in TARGETS:
				var b := _entry(kept.path_join(id).path_join(t), t, true)
				if not b.is_empty():
					b.id = id + "/" + t
					out.append(b)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.manifest.get("built_at", 0)) > int(b.manifest.get("built_at", 0)))
	return out


static func _entry(dir: String, target: String, kept: bool) -> Dictionary:
	var marker := "index.html" if target != "mac" else "UNSPENT.app"
	if not (FileAccess.file_exists(dir.path_join(marker)) or DirAccess.dir_exists_absolute(dir.path_join(marker))):
		return {}
	var m := DevStamp.read(dir.path_join("build.json"))
	return {"id": target, "target": target, "dir": dir, "kept": kept, "manifest": m}


## One line for a build on the shelf: "web  playtest 0.2.0 a1b2c3d".
static func describe(b: Dictionary) -> String:
	var m: Dictionary = b.manifest
	var what := DevStamp.label(m) if not m.is_empty() else "made before stamps"
	return "%s  %s" % [ConfigChoices.target_name(str(b.target)), what]


## "12.3 MB": the bytes a build takes (build.json's own count).
static func size_text(b: Dictionary) -> String:
	var bytes := float((b.manifest as Dictionary).get("bytes", 0))
	if bytes <= 0.0:
		return ""
	return "%.1f MB" % (bytes / 1048576.0)


static func age_text(b: Dictionary, now: float) -> String:
	var at := float((b.manifest as Dictionary).get("built_at", 0))
	if at <= 0.0:
		return ""
	var s := maxf(0.0, now - at)
	if s < 90.0:
		return "just now"
	if s < 5400.0:
		return "%d min ago" % roundi(s / 60.0)
	if s < 129600.0:
		return "%d h ago" % roundi(s / 3600.0)
	return "%d days ago" % roundi(s / 86400.0)


# --- commands ------------------------------------------------------------------------

## Every target the configuration's `builds.targets` names, one after the other.
## `settings` are the configuration's as they stand (with this session's edits).
static func make_command(config_name: String, targets: Array, template: String) -> String:
	var steps := PackedStringArray()
	for t: Variant in targets:
		var line := "tools/export.sh %s" % str(t)
		if config_name != "":
			line += " --config=%s" % config_name
		if template == "debug":
			line += " --debug"
		steps.append(line)
	return " && ".join(steps)


## A name for a kept build: its configuration, commit and when it was built.
static func kept_id(b: Dictionary) -> String:
	var m: Dictionary = b.manifest
	var name := str(m.get("config", ""))
	if name == "":
		name = "none"
	var commit := str(m.get("commit", "")) + ("-dirty" if bool(m.get("dirty", false)) else "")
	var at := int(m.get("built_at", Time.get_unix_time_from_system()))
	var when := Time.get_datetime_string_from_unix_time(at).replace("-", "").replace(":", "").replace("T", "-").substr(4, 9)
	var parts := PackedStringArray()
	for part: String in [name, commit, when]:
		if part != "":
			parts.append(part)
	return "-".join(parts)


static func keep_command(b: Dictionary) -> String:
	var dest := "%s/%s/%s" % [KEPT, kept_id(b), b.target]
	return "mkdir -p \"%s\" && rm -rf \"%s\" && cp -R \"%s\" \"%s\" && echo \"kept %s\"" % [dest.get_base_dir(), dest, b.dir, dest, dest]


## The browser proof of a web build (tools/web.sh against what is on the shelf).
static func prove_command(b: Dictionary) -> String:
	if str(b.target) == "mac":
		return ""
	var line := "tools/web.sh --no-export"
	if str(b.target) == "web-nothreads":
		line += " --nothreads"
	if bool(b.kept):
		line += " --dir=\"%s\"" % b.dir
	return line


static func deploy_command(b: Dictionary, production: bool) -> String:
	if str(b.target) != "web":
		return ""
	return "tools/deploy.sh --no-export --dir=\"%s\"%s" % [b.dir, " --prod" if production else ""]


static func throw_command(b: Dictionary) -> String:
	if not bool(b.kept):
		return ""
	return "rm -rf \"%s\" && rmdir \"%s\" 2>/dev/null; echo \"threw away %s\"" % [b.dir, str(b.dir).get_base_dir(), b.id]


## The last deploy recorded in a build's build.json: {url, production, at}, or {}.
static func last_deploy(b: Dictionary) -> Dictionary:
	var d: Variant = (b.manifest as Dictionary).get("deploys", [])
	if d is Array and not (d as Array).is_empty():
		return (d as Array).back()
	return {}
