class_name DevStamp
## What a build is: the configuration it was made from (resolved, so the build
## never depends on the files it was made from), the commit, when, and for what.
##
##   tools/export.sh web --config=playtest   writes PATH before the export packs it,
##                                           and build/<target>/build.json after
##   DevStamp.current()                      this build's stamp; {} from source
##
## The stamp is trusted only in an exported template: a run from source while an
## export is going would otherwise read the file the export is about to pack and
## believe it was that build.
##
## {"stamp": 1, "config", "chain", "settings", "label", "channel", "version",
##  "commit", "dirty", "built_at" (unix s), "built" (local time), "target",
##  "template", "godot"}; build.json adds "seconds" and "sizes" {name: bytes},
##  and tools/deploy.sh "deploys" [{url, production, at}].

const PATH := "res://stamp/build.json"
const VERSION := 1

static var _current: Variant = null
static var _sha := ""


static func current() -> Dictionary:
	if _current == null:
		_current = read(PATH) if OS.has_feature("template") else {}
	return _current


## A stamp or manifest file; {} when it is missing or not one.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (v is Dictionary) or not (v as Dictionary).has("stamp"):
		return {}
	return v


## A stamp for a build of configuration `name` (or none): pure, so the stamp tool
## and the tests make the same thing.
static func make(name: String, resolved: Dictionary, target: String, template: String, commit: String, dirty: bool, built_at: int) -> Dictionary:
	var settings: Dictionary = resolved.get("settings", {})
	var pick := func(id: String) -> Variant: return settings[id] if settings.has(id) else ConfigSchema.default_of(id)
	return {
		"stamp": VERSION,
		"config": name,
		"chain": Array(resolved.get("chain", PackedStringArray())),
		"settings": settings,
		"label": str(pick.call("build.label")),
		"channel": str(pick.call("build.channel")),
		"version": str(pick.call("build.version")),
		"commit": commit,
		"dirty": dirty,
		"built_at": built_at,
		"built": Time.get_datetime_string_from_unix_time(built_at + _utc_offset(), true),
		"target": target,
		"template": template,
		"godot": Engine.get_version_info().get("string", ""),
	}


## "playtest 0.2.0 a1b2c3d": the configuration's name (or label), version and commit.
static func label(stamp: Dictionary) -> String:
	if stamp.is_empty():
		return ""
	var name := str(stamp.get("label", ""))
	if name == "":
		name = str(stamp.get("config", ""))
	if name == "":
		name = "no config"
	var commit := str(stamp.get("commit", ""))
	if bool(stamp.get("dirty", false)):
		commit += "+"
	var words := PackedStringArray()
	for w: String in [name, str(stamp.get("version", "")), commit]:
		if w != "":
			words.append(w)
	return " ".join(words)


## The commit a run from source is at ("" where there is no git to ask).
static func source_commit() -> String:
	if _sha != "" or OS.has_feature("template") or OS.has_feature("web"):
		return _sha
	var out := []
	if OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"]), out) == 0 and not out.is_empty():
		_sha = str(out[0]).strip_edges()
	return _sha


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
