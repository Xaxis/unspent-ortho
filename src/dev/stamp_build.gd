extends SceneTree
## The stamp a build carries (DevStamp), made before the export packs it.
##   godot --headless --path . -s src/dev/stamp_build.gd -- --config=NAME --target=web \
##       --template=release --commit=a1b2c3d [--dirty] --out=stamp/build.json
## tools/export.sh runs it. --config may be empty (a build of no configuration:
## every default, dev mode off). The configuration is resolved and checked
## against the game's content here, so a build of a broken configuration fails
## before minutes are spent exporting it. Prints `stamp ok <label>` or
## `stamp FAILED: <why>` and exits 0 or 1.


func _initialize() -> void:
	var o := {"config": "", "target": "web", "template": "release", "commit": "", "dirty": false, "out": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		o[kv[0]] = kv[1] if kv.size() > 1 else true
	var name := str(o.config)
	var resolved := {"ok": true, "why": "", "chain": PackedStringArray(), "settings": {}}
	if name != "":
		resolved = GameConfig.resolve(name)
	if not resolved.ok:
		_fail(resolved.why)
		return
	var problems := ConfigChoices.problems(resolved.settings)
	if not problems.is_empty():
		_fail("%s: %s" % [name, problems[0]])
		return
	if str(o.out) == "":
		_fail("no --out")
		return
	var stamp := DevStamp.make(name, resolved, str(o.target), str(o.template), str(o.commit), o.dirty == true, int(Time.get_unix_time_from_system()))
	var path := str(o.out)
	if not path.is_absolute_path():
		path = ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("cannot write %s" % path)
		return
	f.store_string(JSON.stringify(stamp, "\t", true) + "\n")
	f.close()
	print("stamp ok %s (%s %s)" % [DevStamp.label(stamp), stamp.target, stamp.template])
	quit(0)


func _fail(why: String) -> void:
	print("stamp FAILED: %s" % why)
	quit(1)
